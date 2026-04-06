# Parallel Thermal-Mechanical Solver

## Objective

Decouple the thermal and mechanical solvers to run concurrently as separate OS processes with file-based communication. Mechanical solver accounts for >50% of total wall time; running both in parallel achieves ~1.6x speedup.

## Execution Tracking

- **`results.md`**: Timing comparison vs serial baseline.

---

## Architecture (as implemented)

```
run.sh launches two cluster_main processes:

Process 1: PHOENIX_RUN_MODE=thermal     Process 2: PHOENIX_RUN_MODE=mechanical
────────────────────────────────────     ──────────────────────────────────────
OMP_NUM_THREADS=N1                       OMP_NUM_THREADS=N2
Full thermal initialization              generate_grid + init_mechanical
                                         Compute last_mech_step from timax/delt
step 1..25: thermal solve                wait for temp file...
step 25: write mech_input_00025.bin  →   detect .ready, read, solve_mechanical
step 26..50: thermal solve               (still solving step 25...)
step 50: write mech_input_00050.bin      finish step 25, start step 50...
...                                      ...
step N: thermal done, exit               process until next_step > last_mech_step
```

**Communication**: binary files in result directory (deleted after read).
**Termination**: mechanical computes `last_mech_step = (timax/delt/mech_interval) * mech_interval` from shared input parameters. No sentinel files needed.
**Thread split**: `bash run.sh <case> <thermal_threads> <mech_threads> &`

---

## Phase 1: Binary Temp File I/O ✅

### Task 1.1: write_mech_input (thermal side) ✅

- `mod_mech_io.f90`: `write_mech_input(step_idx, time, temp, solidfield)`
- Binary stream format: step_idx, time, ni/nj/nk, temp, solidfield, x, y
- `.ready` sentinel written after data file closed

### Task 1.2: read_mech_input (mechanical side) ✅

- `mod_mech_io.f90`: `read_mech_input(step_expect, step_out, time_out, temp_buf, sf_buf, x_buf, y_buf, found)`
- Polls for `.ready` file, reads binary, deletes both files

### Task 1.3: Termination signal ✅

- ~~mech_DONE sentinel~~ Removed. Mechanical computes `last_mech_step` from `timax`, `delt`, `mech_interval` (all read from input_param.txt). Exits when `next_step > last_mech_step`. No sentinel = no stale file bugs.

---

## Phase 2: Dual-Process Architecture ✅

### Task 2.1: Process role selection ✅

- `PHOENIX_RUN_MODE` environment variable: `'thermal'` or `'mechanical'`
- `run_mode == 'mechanical'`: skip thermal init, call `run_mechanical_loop()`, stop
- `run_mode == 'thermal'` or empty: normal thermal path
- `mech_parallel = (mechanical_flag == 1 .and. n_mech_threads > 0)`

### Task 2.2: run_mechanical_loop() ✅

- Polls for binary input files in step order
- Detects AMR grid changes by comparing x,y arrays → calls `update_mech_grid()`
- Writes VTK and history output at appropriate intervals
- Prints `[MECH]` progress to stdout

### Task 2.3: Process every file ✅

Files processed in order, no skipping. If mechanical falls behind thermal, files buffer on disk.

### Task 2.4: Thermal process modifications ✅

- At each `mech_interval`: `write_mech_input()` instead of `solve_mechanical()` when `mech_parallel`
- AMR `update_mech_grid()` skipped in thermal process (`mech_parallel` guard)
- `t_mech` stays 0 in parallel mode → mechanical absent from thermal timing report

---

## Phase 3: Run Script and Thread Management ✅

### Task 3.1: run.sh ✅

```bash
bash run.sh <case_name> [thermal_threads] [mech_threads]
# mech_threads=0 (default): serial in-loop mechanical
# mech_threads>0: parallel dual-process
```

- Launches `PHOENIX_RUN_MODE=mechanical ./cluster_main &` in background
- Launches `PHOENIX_RUN_MODE=thermal ./cluster_main` in foreground
- `wait $MECH_PID` to ensure both complete

### Task 3.2: compile.sh usage updated ✅

---

## Phase 4: Timing Report Update ✅

### Task 4.1: Mechanical absent from thermal timing report ✅

- `t_mech` only accumulated in serial mode
- Parallel mode: `t_mech = 0` → shows `mechanical | 0.000 | 0.00%` in thermal report
- Mechanical has its own `_mech_timing_report.txt` with mode, thread counts, wall time

### Task 4.2: Parallel info in mech timing report ✅

- Shows mode (serial/parallel), thread counts
- Wall time tracked via `omp_get_wtime()` in parallel, `t_mech` in serial
- Avg CPU and wall per solve

---

## Phase 5: Validation ✅

### Task 5.1: Parallel vs serial comparison ✅

- Same case (timax=0.002, AMR=1), 24-core machine
- Von Mises stress within <1% between serial and parallel
- See results.md for full data

### Task 5.2: Thread allocation sweep ✅

Tested 5+5, 8+2, 10+10, 12+12. See results.md.

---

## Key Design Decisions

1. **Dual OS processes** (not OpenMP sections): simpler, avoids nested parallelism issues, each process has independent OMP runtime
2. **File-based IPC**: binary files in result directory, deleted after read. Simple, debuggable, no shared memory complexity
3. **Step-count termination**: mechanical computes last step from `timax/delt/mech_interval`. No sentinel files = no stale file bugs, no race conditions
4. **Process every file**: no skipping — ensures stress history captures all thermal transients
5. **Environment variables for threads**: `PHOENIX_THERMAL_THREADS`, `PHOENIX_MECH_THREADS`, `PHOENIX_RUN_MODE` set by run.sh
6. **Serial fallback**: `mech_threads=0` falls back to serial in-loop solve (backward compatible)
7. **One-way coupling**: thermal never reads mechanical output → no synchronization needed

## Bugs Found and Fixed

1. **Double init_mechanical**: mechanical process called init twice → "already allocated". Fixed by keeping init inside `run_mechanical_loop` only.
2. **update_mech_grid in thermal process**: AMR called `update_mech_grid` in parallel mode where mechanical arrays don't exist → segfault. Fixed with `mech_parallel` guard.
3. **Stale mech_DONE sentinel**: leftover file from previous run caused mechanical to exit immediately. Fixed by removing sentinel entirely — mechanical uses step count instead.
