# Parallel Thermal-Mechanical — Results

## Test Case

- **Grid**: 200×100×52 thermal, 100×50×25 FEM (mech_mesh_ratio=2)
- **timax**: 0.002 s (100 thermal steps, 4 mechanical solves at mech_interval=25)
- **AMR**: adaptive_flag=1, remesh_interval=10
- **Machine**: 24 cores (verified no residual processes before each test)

## Timing Comparison

| Configuration | Thermal wall (s) | Mech wall (s) | Total wall (s) | Speedup |
|--------------|------------------|---------------|----------------|---------|
| Serial 10 | 131.5 (includes mech) | 647 (CPU) | **131.5** | 1.00x |
| Parallel 5+5 | 67.3 | 90.2 | **90.2** | **1.46x** |
| Parallel 8+2 | 63.6 | 144.6 | **144.6** | 0.91x |
| Parallel 10+10 | 55.6 | 80.5 | **80.5** | **1.63x** |
| Parallel 12+12 | 121.2 | 135.9 | **135.9** | 0.97x |

**Optimal: 10+10 (1.63x speedup)**

## Analysis

- **10+10 optimal**: 20 total threads on 24 cores leaves room for OS overhead
- **12+12 worse**: 24 threads saturate all cores → contention → both solvers slow down
- **8+2 bottlenecked**: 2 mech threads too few → mech takes 145s while thermal finishes in 64s
- **Serial baseline**: mechanical is 52.5% of total CPU → parallelization worthwhile
- **Total wall = max(thermal_wall, mech_wall)**: whichever process takes longer determines total time

## Result Validation

Von Mises stress comparison (serial vs parallel):

| Mech Solve | Serial max_vm (MPa) | Parallel 10+10 (MPa) | Diff |
|-----------|---------------------|----------------------|------|
| 1 | 174.1 | 172.6 | <1% |
| 2 | 179.0 | 179.0 | 0% |
| 3 | 184.4 | 184.4 | 0% |
| 4 | 188.9 | 188.7 | <1% |

Physics results identical within <1%.

## Timing Report Examples

### Serial mode (thermal timing report includes mechanical)
```
mechanical|     659.587  |   52.52%
mod_discret|     175.328  |   13.96%
mod_sour|     160.651  |   12.79%
```

### Parallel mode (mechanical absent from thermal report)
```
mod_sour|     857.562  |   28.99%
mod_discret|     706.526  |   23.88%
mod_solve|     497.693  |   16.82%
...
mechanical|       0.000  |    0.00%
```

### Parallel mode (separate mech timing report)
```
Mode:                parallel (separate process)
Thermal threads:     10
Mechanical threads:  10
Solves performed:    4
Total wall time:     80.538 s
Avg wall per solve:  20.135 s
```

## Bugs Fixed

| Bug | Symptom | Fix | Commit |
|-----|---------|-----|--------|
| Double init_mechanical | "already allocated" crash | Remove outer init call | a3481d2 |
| update_mech_grid in thermal | Segfault in parallel AMR | Add mech_parallel guard | 21c5cf7 |
| Stale mech_DONE sentinel | Mechanical exits at step 0 | Remove sentinel, use step count | 466c279 |
| Residual process interference | 10+10 showed 388s instead of 80s | Always kill before benchmarking | dda3459 |
