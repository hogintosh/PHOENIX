# Parallel Thermal-Mechanical Solver

## Objective

Decouple the thermal and mechanical solvers to run concurrently via OpenMP sections with file-based communication. Mechanical solver currently accounts for >50% of total wall time; running both in parallel should achieve ~2x speedup.

## Execution Tracking

- **`log.md`**: Execution log with system timestamps.
- **`results.md`**: Timing comparison vs serial baseline (multimechAMR case).

---

## Architecture

```
Thermal Section (N1 threads)          Mechanical Section (N2 threads)
─────────────────────────             ───────────────────────────────
step 1..25: thermal solve             wait for temp file...
step 25: write mech_input_00025.bin → detect file, read, solve_mechanical
step 26..50: thermal solve            (still solving step 25...)
step 50: write mech_input_00050.bin   finish step 25, start step 50...
...                                   ...
step N: write DONE sentinel           process remaining files, finalize
```

**Communication**: binary files in result directory.
**Thread split**: `bash run.sh <case> <thermal_threads> <mech_threads> &`

---

## Phase 1: Binary Temp File I/O

### Task 1.1: Write mechanical input file (thermal side)

In `main.f90`, at each `mech_interval` step (where `solve_mechanical` used to be called):

```fortran
call write_mech_input(step_idx, time, temp, solidfield)
```

**File format**: `<case_name>_mech_input_NNNNN.bin` (binary, unformatted)

Contents:
| Field | Type | Size | Notes |
|-------|------|------|-------|
| step_idx | integer | 1 | Thermal step number |
| time | real(wp) | 1 | Simulation time |
| ni, nj, nk | integer | 3 | Grid dimensions (for AMR validation) |
| temp | real(wp) | ni×nj×nk | Temperature field |
| solidfield | real(wp) | ni×nj×nk | Solidification field |
| x | real(wp) | ni | X coordinates (needed for AMR) |
| y | real(wp) | nj | Y coordinates (needed for AMR) |

Write a `.ready` sentinel after closing the data file (atomic signal):
```fortran
open(..., file='mech_input_00025.ready'); close(...)
```

**Location**: new subroutine in `mod_mech_io.f90`.

### Task 1.2: Read mechanical input file (mechanical side)

```fortran
call read_mech_input(step_idx, time, temp_buf, sf_buf, x_buf, y_buf, found)
```

- Poll for `.ready` files in step order
- Read binary data, then delete `.ready` and `.bin` files
- Return `found=.false.` if no file available (caller retries)

### Task 1.3: Done sentinel

Thermal writes `<case_name>_mech_DONE` file after time loop ends.
Mechanical checks for this file to know when to stop polling.

---

## Phase 2: OpenMP Parallel Sections

### Task 2.1: Top-level parallel structure in main.f90

```fortran
if (mechanical_flag == 1) then
    !$OMP PARALLEL SECTIONS NUM_THREADS(2)
    !$OMP SECTION
        call omp_set_num_threads(n_thermal_threads)
        call run_thermal_loop()      ! existing time loop
    !$OMP SECTION
        call omp_set_num_threads(n_mech_threads)
        call run_mechanical_loop()   ! new: polls files, solves
    !$OMP END PARALLEL SECTIONS
else
    call run_thermal_loop()          ! no mechanical, all threads for thermal
endif
```

Requires: `OMP_NESTED=TRUE` or `OMP_MAX_ACTIVE_LEVELS=2` (set in run.sh).

### Task 2.2: Mechanical loop (new subroutine)

```fortran
subroutine run_mechanical_loop()
    call init_mechanical()
    do
        call read_mech_input(step, time, temp_buf, sf_buf, x_buf, y_buf, found)
        if (.not. found) then
            if (done_file_exists()) exit
            call sleep(1)  ! or shorter
            cycle
        endif
        ! Check if grid changed (AMR) and update
        if (grid_changed(x_buf, y_buf)) call update_mech_grid()
        call solve_mechanical(temp_buf, sf_buf, ...)
        call write_mech_vtk(...)   ! if output interval
        call write_mech_history(...)
    enddo
    call finalize_mechanical_io()
    call cleanup_mechanical()
end subroutine
```

### Task 2.3: Skip mechanism

If mechanical is slower than thermal, temp files accumulate.
Option: process every file (safe, slight lag) or skip to latest (faster, may miss transient stress peaks).

**Decision**: process every file. Mechanical should keep up if given enough threads. If it falls behind, files buffer naturally.

### Task 2.4: Extract thermal loop into subroutine

Refactor `main.f90` time loop into `run_thermal_loop()`:
- Move the `do step_idx = 1, nstep` block into a subroutine
- Replace `call solve_mechanical(...)` with `call write_mech_input(...)` when parallel
- Keep serial mode as fallback (mechanical_flag=1 but single-process mode)

---

## Phase 3: Run Script and Thread Management

### Task 3.1: Update run.sh

```bash
# Usage: bash run.sh <case_name> [thermal_threads] [mech_threads]
# Example: bash run.sh baseline 10 10 &
CASE=$1
N_THERMAL=${2:-10}
N_MECH=${3:-0}  # 0 = serial mode (no parallel mechanical)

export OMP_NUM_THREADS=$((N_THERMAL + N_MECH))
export OMP_MAX_ACTIVE_LEVELS=2
export PHOENIX_THERMAL_THREADS=$N_THERMAL
export PHOENIX_MECH_THREADS=$N_MECH
```

Read environment variables in `main.f90` or `mod_param.f90`:
```fortran
call get_environment_variable('PHOENIX_THERMAL_THREADS', val)
read(val, *) n_thermal_threads
call get_environment_variable('PHOENIX_MECH_THREADS', val)
read(val, *) n_mech_threads
```

### Task 3.2: Update compile.sh

Add note about thread allocation in usage message.

---

## Phase 4: Timing Report Update

### Task 4.1: Remove mechanical from thermal timing report

When parallel mode is active, mechanical time should NOT be counted in the thermal timing report (it runs concurrently). Only report thermal solve, AMR, I/O, etc.

Mechanical has its own `_mech_timing_report.txt`.

### Task 4.2: Add parallel efficiency metrics

In `_mech_timing_report.txt`, add:
- Thermal wall time vs mechanical wall time (overlap %)
- File I/O time (read + write)
- Idle/polling time

---

## Phase 5: Validation

### Task 5.1: Compare parallel vs serial results

Run same case (multimechAMR) with:
1. Serial: `bash run.sh multimech 20 &` (all 20 threads for serial thermal+mech)
2. Parallel: `bash run.sh multimechPar 10 10 &` (10+10 split)

Compare:
- Von Mises stress field (should be identical or very close)
- Displacement magnitude (should match)
- Wall time (parallel should be ~2x faster)

### Task 5.2: Thread allocation sweep

Test different thread splits to find optimum:
- 15+5, 10+10, 5+15
- Measure total wall time for each

---

## Key Design Decisions

1. **File-based IPC**: simpler than shared memory, avoids race conditions, files can be inspected for debugging
2. **OpenMP sections**: uses existing OpenMP infrastructure, no external dependencies (MPI, pthreads)
3. **Process every file**: no skipping — ensures stress history captures all thermal transients
4. **Environment variables for threads**: avoids modifying input_param.txt, keeps compile-time parameters separate from runtime
5. **Serial fallback**: mechanical_flag=1 with mech_threads=0 falls back to serial in-loop solve (backward compatible)
6. **One-way coupling**: thermal never reads mechanical output → no synchronization needed for correctness

## Risks

1. **OpenMP nested parallelism**: may need careful thread affinity (`OMP_PROC_BIND`, `OMP_PLACES`) to avoid core sharing
2. **File I/O bottleneck**: binary writes should be <1ms per file (ni×nj×nk×8 bytes ≈ few MB), negligible
3. **Mechanical falling behind**: if mech takes >25 thermal steps worth of time, files accumulate → memory/disk usage grows. Monitor in timing report.
4. **AMR grid changes**: mechanical needs grid coordinates → included in binary file
