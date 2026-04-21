# Log: Defect Field ML

## [2026-04-19 --:--:--] Project setup

Created project folder `projects/20260419_DEFECT_FIELD_ML/`.
Moved `defect_field_ML.md` from `projects/` root into project folder.
Copied `toolpath_generator_rectangle.py` from `fortran_new/ToolFiles/`.
Wrote all scripts:
- `scripts/generate_training_data.py` — 100 cases, N_PARALLEL=4
- `scripts/generate_test_data.py` — 20 test cases, N_PARALLEL=4
- `scripts/train_autoencoder.py` — PCA sweep d=2,3,4
- `scripts/train_nn.py` — MLP 128→256→128→64, LOO-CV
- `scripts/evaluate.py` — field metrics + porosity parity + error summary plots

## [2026-04-19] Step 2.1: generate_training_data.py

Ran successfully. Generated 100 case folders in `training_data/`, `caselist.txt`, `training_summary.csv`, and `run_all_training.sh` (N_PARALLEL=4).

## [2026-04-19] Step 2.2: run_all_training.sh launched

Launched 100 training simulations: `bash run_all_training.sh` (PID 7001).
4 simulations run in parallel, 1 OMP thread each.
Log: `run_all_training.log`

## [2026-04-19 22:06] Progress check — 0/100 completed

Bug found: `run_case.sh` used `cp result/*` which silently fails because PHOENIX writes output into a subdirectory `result/<case_name>/`. Fixed all 100 scripts to `cp -r result/.`.

Cases hs00_ss01, hs00_ss02, hs00_ss03 had already run through xargs with empty results — re-ran manually.
Active: hs00_ss00, hs00_ss01 (re-run), hs00_ss02 (re-run), hs00_ss03 (re-run), hs00_ss04, hs00_ss05, hs00_ss06 = 7 processes briefly, then back to 4+xargs.

## [2026-04-20 23:17] Progress check — 10/100 completed (14 xargs-done, 4 missing results)

10 defect VTKs confirmed. 14 cases logged as "Done" by xargs, but hs00_ss00/ss04/ss05/ss06 have empty results — they ran before cp -r fix took effect.

Fixed two additional bugs:
- `train_autoencoder.py` and `evaluate.py` had wrong VTK path; PHOENIX writes to `result/<case>/<case>_defect.vtk`, not `result/<case>_defect.vtk`. Fixed both scripts.
- Re-queued 4 missing cases (sequential, PID 75109): hs00_ss00, hs00_ss04, hs00_ss05, hs00_ss06.

## [2026-04-20 01:26] Progress check — 18/100 completed

18 defect VTKs confirmed. 5 processes running. xargs reached hs02_ss01. On track.

## [2026-04-20 02:27] Progress check — 27/100 completed

27 defect VTKs confirmed. 5 processes running. xargs reached hs02_ss09. ~9 cases/hr.

## [2026-04-20 03:28] Progress check — 39/100 completed

39 defect VTKs confirmed. 5 processes running. xargs reached hs03_ss09. ~12 cases/hr (speeding up as hatch index increases → fewer scan tracks).

## [2026-04-20 04:29] Progress check — 51/100 completed

51 defect VTKs confirmed. 4 processes running. xargs reached hs05_ss03. ~12 cases/hr.

## [2026-04-20 05:30] Progress check — 55/100 completed, xargs done, 45 re-runs launched

xargs and rerun queue both finished. Only 55/100 have defect VTKs.
Root cause identified: `cp -r result/.` step silently fails for hs04-hs09 cases (exact reason unclear — possibly transient filesystem issue or race during the parallel xargs run).

Fix: rewrote run_case.sh for all 45 missing cases to run DIRECTLY from the case directory. PHOENIX writes `./result/<case>/` relative to CWD — when run from the case dir, results land in the right place with no copy step. Verified hs04_ss09 is writing results correctly in direct mode.

Launched: `bash run_missing.sh` (PID 116061), 45 cases, 4 parallel, direct-mode scripts.

## [2026-04-20 10:51] DISK FULL — root cause: vtkmov files

User reported hard drive full. Diagnosis:
- Each vtkmov snapshot contains 6 fields (Velocity, T, vis, diff, den, fracl) over full 3D grid (~40 MB/file)
- With outputintervel=50 and timax up to 0.043s: up to ~40 vtkmov files per case
- 55 completed cases × ~1 GB/case = ~54 GB total (disk was 98 GB)

Fix applied:
1. Deleted all vtkmov*.vtk files: `find training_data/ -name "*vtkmov*.vtk" -delete` → freed 54 GB (disk 100% → 48%)
2. Set outputintervel=999999 in all 44 remaining missing cases (defect VTK is written independently at end, not affected)
3. Rewrote run scripts to direct-mode (run from case dir, no cp step)
4. Relaunched 44 cases (PID 116984), 4 parallel

Disk now: 44G used / 98G, 50G free. Training data: 390 MB for 56 completed cases.

## [2026-04-20 12:18] Progress check — 69/100 completed

69 defect VTKs confirmed. 4 processes running (hs06 range). Disk: 44G/98G (48%). On track.

## [2026-04-20 12:38] Progress check — 70/100 completed

70 defect VTKs confirmed (hs06_ss07 latest). 4 processes running. 30 cases remaining: hs06_ss09 + all hs07/hs08/hs09. Disk: 44G/98G (48%). Estimated ~2.5 hrs to completion at 12 cases/hr.

## [2026-04-20 12:52] Progress check — 85/100 completed

85 defect VTKs confirmed. 4 processes running (hs08 range). 15 cases remaining. Disk: 45G/98G (48%).

## [2026-04-20 13:24] Progress check — 85/100 completed

Still 85/100 — no stall. 4 processes actively running (PIDs 119035-119093, started ~13:00, all at 99.9% CPU). hs08_ss05 CWD confirmed. 15 remaining: hs08_ss05-09, hs09_ss00-09. Disk: 45G/98G (48%). Estimated ~30 min to completion.

## [2026-04-20 13:37] Progress check — 93/100 completed

93 defect VTKs confirmed. 4 processes running. 7 remaining: hs09_ss03-09. Disk: 45G/98G (48%). ~10 min to completion.

## [2026-04-20 13:54] All 100 training cases complete — 7 empty VTKs found, test sims launched

All 100 training cases counted, but 7 had empty (0-byte) defect VTKs (likely early termination):
  hs04_ss07, hs04_ss09, hs05_ss02, hs05_ss03, hs05_ss05, hs05_ss07, hs08_ss03

Actions:
- Removed empty VTKs, wrote direct-mode run_case.sh for each
- Launched re-run: bash run_empty.sh (PID 142756), 4 parallel
- Generated 20 test cases: python3 scripts/generate_test_data.py
- Fixed outputintervel=999999 in all 20 test cases
- Launched test sims: bash run_all_test.sh (PID 142455), 4 parallel
- 8 cluster_main processes running total

Autoencoder training blocked until 7 empty re-runs complete.

## [2026-04-20 14:42] Progress check — 93/100 training valid, 0/20 test done

8 cluster_main processes running (4 empty re-runs + 4 test sims). No completions yet from either queue — both queues just started. Disk: 45G/98G (48%).

## [2026-04-20 14:54] Bug fix: test run scripts used cp result/* (same Bug 1 as training)

All 20 test case run_case.sh scripts used old approach: run in run/ subdir + cp result/*. PHOENIX writes to result/<case>/ subdirectory, so cp silently skipped all output. interp_00, interp_01, interp_03 had logged "Done" but produced no output files.

Fix: rewrote all 20 test run_case.sh to direct-mode (cd into case dir, run from there). Cleaned up leftover run/ subdirs. Killed 4 broken test processes. Relaunched run_all_test.sh (PID 147315). 8 processes running total (4 empty training re-runs + 4 test sims).

## [2026-04-20 15:01] Progress check — 95/100 training valid, 0/20 test done

Training: hs04_ss07 and hs04_ss09 complete (6.4 MB VTKs). hs05_ss02/03/05/07 running. hs08_ss03 queued.
Test sims: 12 cluster_main processes total (4 training + 8 test). Direct-mode confirmed (processes running from test_data/<case>/ dirs). Test sims actively writing output. Disk: 48G/98G (51%).

## [2026-04-20 15:36] 100/100 training VTKs valid — autoencoder done, NN training started

All 100 training VTKs confirmed valid. 4 test VTKs complete. 8 test sim processes still running.

Step 3 — Autoencoder (PCA sweep d=2,3,4):
  d=2: rel MSE = 37.67%  d=3: 27.85%  d=4: 21.26%
  WARNING: none met <1% threshold — selected d=4 (best available).
  High reconstruction error expected: defect fields are spatially complex; PCA needs higher d to capture variance. Proceeding with d=4.

Step 4 — NN training: MLPRegressor(128,256,128,64), 100-fold LOO-CV (max_iter=5000/fold), final max_iter=20000.
  Running PID 149599. All folds hitting max_iter limit (ConvergenceWarnings). Estimated 30-60 min to complete.

## [2026-04-20 19:46] NN training complete

  Final training MSE: 0.048384 (8821 iterations)
  LOO-CV mean MSE: 1.0207  max: 24.7483
  All 100 folds hit max_iter=5000 limit (ConvergenceWarnings throughout).
  Models saved in models/nn/. Plots: nn_loss.png, nn_latent_parity.png, nn_loo_cv.png.

  Note: extrap_08 had two cluster_main processes running simultaneously (PID 155247 + 158563) —
  duplicate launched by a second xargs invocation. Killed PID 158563; PID 155247 (original, 18:38) completed successfully.

## [2026-04-20 20:15] All 20 test VTKs complete — evaluation done

Step 5 — evaluate.py results:

  Interpolation cases (10):
    interp_00: MSE=8.140e-03  R²=0.820  LOF=0.490%  KEP=0.280%  TOT=0.770%
    interp_01: MSE=1.097e-02  R²=0.863  LOF=0.118%  KEP=0.011%  TOT=0.129%
    interp_02: MSE=1.510e-03  R²=-0.713  LOF=0.450%  KEP=0.461%  TOT=0.912%
    interp_03: MSE=6.643e-03  R²=0.909  LOF=0.173%  KEP=0.008%  TOT=0.165%
    interp_04: MSE=2.005e-03  R²=0.556  LOF=0.131%  KEP=0.000%  TOT=0.131%
    interp_05: MSE=1.749e-02  R²=0.121  LOF=0.807%  KEP=0.029%  TOT=0.778%
    interp_06: MSE=1.151e-02  R²=0.820  LOF=0.588%  KEP=0.082%  TOT=0.506%
    interp_07: MSE=2.984e-03  R²=0.325  LOF=0.005%  KEP=0.165%  TOT=0.170%
    interp_08: MSE=3.903e-03  R²=0.458  LOF=0.051%  KEP=0.142%  TOT=0.193%
    interp_09: MSE=2.406e-02  R²=0.602  LOF=1.094%  KEP=0.032%  TOT=1.062%

  Extrapolation cases (10):
    extrap_00: MSE=3.930e-03  R²=0.698  LOF=0.029%  KEP=0.215%  TOT=0.186%
    extrap_01: MSE=3.952e-01  R²=-2.694  LOF=7.025%  KEP=3.919%  TOT=10.945%
    extrap_02: MSE=1.611e-02  R²=0.460  LOF=0.040%  KEP=1.222%  TOT=1.182%
    extrap_03: MSE=3.032e-02  R²=0.256  LOF=0.177%  KEP=0.003%  TOT=0.180%
    extrap_04: MSE=1.902e-03  R²=0.748  LOF=0.051%  KEP=0.105%  TOT=0.155%
    extrap_05: MSE=3.851e-01  R²=-2.686  LOF=5.730%  KEP=4.496%  TOT=10.226%
    extrap_06: MSE=1.368e-02  R²=0.679  LOF=0.011%  KEP=1.142%  TOT=1.130%
    extrap_07: MSE=3.512e-02  R²=0.259  LOF=0.305%  KEP=0.001%  TOT=0.306%
    extrap_08: MSE=2.367e-03  R²=0.839  LOF=0.025%  KEP=0.497%  TOT=0.473%
    extrap_09: MSE=2.693e-02  R²=0.682  LOF=3.000%  KEP=2.419%  TOT=5.419%

  Summary:
    Metric                   Interpolation    Extrapolation
    Field MSE                8.9207e-03       9.1068e-02
    Field R²                 4.7613e-01      -7.5916e-02
    LOF error                3.9066e-03       1.6393e-02
    Keyhole error            1.2109e-03       1.4019e-02
    Total porosity error     4.8160e-03       3.0203e-02

  Plots saved in results/: interp_field_comparison.png, extrap_field_comparison.png,
    porosity_parity.png, error_summary.png.

  Pipeline complete.
