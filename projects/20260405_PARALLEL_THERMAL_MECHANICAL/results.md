# Parallel Thermal-Mechanical — Results

## Test Case

- **Grid**: 200×100×52 thermal, 100×50×25 FEM (mech_mesh_ratio=2)
- **timax**: 0.002 s (100 thermal steps, 4 mechanical solves)
- **AMR**: adaptive_flag=1
- **Machine**: 24 cores (verified no residual processes before each test)

## Timing Comparison

| Configuration | Thermal wall (s) | Mech wall (s) | Total (s) | Speedup |
|--------------|------------------|---------------|-----------|---------|
| Serial 10 | 131.5 (includes mech) | 647 (CPU) | **131.5** | 1.00x |
| Parallel 5+5 | 67.3 | 90.2 | **90.2** | **1.46x** |
| Parallel 8+2 | 63.6 | 144.6 | **144.6** | 0.91x |
| Parallel 10+10 | 55.6 | 80.5 | **80.5** | **1.63x** |
| Parallel 12+12 | 121.2 | 135.9 | **135.9** | 0.97x |

## Analysis

- **10+10 is optimal**: 1.63x speedup. 20 total threads on 24 cores leaves room for OS.
- **12+12 is worse**: 24 threads saturate all cores → contention with OS → both solvers slow down.
- **8+2 is bottlenecked by mech**: only 2 mech threads → mech takes 145s while thermal finishes in 64s. Total = mech time.
- **Serial 10 baseline**: mechanical is 52% of total time, making parallelization worthwhile.

## Result Validation

Von Mises stress comparison (serial vs parallel):

| Mech Solve | Serial max_vm (MPa) | Parallel 10+10 max_vm (MPa) |
|-----------|---------------------|----------------------------|
| 1 | 174.1 | 172.6 |
| 2 | 179.0 | 179.0 |
| 3 | 184.4 | 184.4 |
| 4 | 188.9 | 188.7 |

Results within <1% — parallel mode produces correct physics.

## Bugs Fixed During Implementation

1. **Double init_mechanical**: mechanical process called `init_mechanical` twice → "already allocated" crash. Fixed by removing outer call.
2. **update_mech_grid in thermal process**: AMR remesh called `update_mech_grid` in parallel mode where mechanical arrays don't exist → segfault. Fixed by adding `mech_parallel` guard.
3. **Residual process interference**: initial 10+10 test showed 388s due to a lingering `cluster_main` process from previous run consuming CPU. Lesson: always `kill $(pgrep -f cluster_main)` before benchmarking.
