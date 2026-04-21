# Task: Defect Field ML — Fast Prediction of 3D Defect Fields

## Objective

Build a surrogate model mapping (hatch_spacing, scan_speed) → 3D defect fields using PCA autoencoder + MLP neural network. Matches pipeline from defect_field_ML.md. Simulations run with 4 parallel workers (1 OMP thread each) to avoid overloading the machine.

## Tasks

- [x] 1.1 Create project folder and copy toolpath generator
- [x] 1.2 Write `scripts/generate_training_data.py` — 100 toolpaths + case folders, run_all_training.sh with -P 4
- [x] 1.3 Write `scripts/generate_test_data.py` — 20 test cases, run_all_test.sh with -P 4
- [x] 1.4 Write `scripts/train_autoencoder.py` — PCA sweep d=2,3,4
- [x] 1.5 Write `scripts/train_nn.py` — MLP + LOO-CV
- [x] 1.6 Write `scripts/evaluate.py` — full pipeline evaluation + plots
- [x] 2.1 Run `generate_training_data.py` — create 100 case folders
- [x] 2.2 Run `run_all_training.sh` — 100 training simulations (4 parallel)
- [x] 3.1 Run `train_autoencoder.py` — PCA dimensionality reduction (d=4 selected, 21.26% rel MSE)
- [x] 3.2 Run `train_nn.py` — MLP fitting + LOO-CV (LOO mean MSE=1.0207)
- [x] 4.1 Run `generate_test_data.py` — create 20 test cases
- [x] 4.2 Run `run_all_test.sh` — 20 test simulations (4 parallel)
- [x] 5.1 Run `evaluate.py` — evaluation + plots

## Results

| Metric | Interpolation | Extrapolation |
|--------|--------------|---------------|
| Field MSE | 8.92e-03 | 9.11e-02 |
| Field R² | 0.476 | -0.076 |
| LOF error | 0.39% | 1.64% |
| Keyhole error | 0.12% | 1.40% |
| Total porosity error | 0.48% | 3.02% |

Interpolation porosity prediction is good (<1% total error on most cases). Extrapolation degrades significantly (extrap_01 and extrap_05 both ~10% total error). Field R² is modest for interpolation (0.476) and negative for extrapolation — PCA d=4 reconstruction error (21%) limits field-level accuracy.

## Key Parameters

| Parameter | Value |
|-----------|-------|
| Hatch spacing range | 50–150 µm (10 points) |
| Scan speed range | 0.8–1.6 m/s (10 points) |
| Training simulations | 100 (10×10 grid) |
| Parallel workers | 4 (1 OMP thread each) |
| Scan region | 1×1 mm, centered at (1,1) mm |
| Rotation | 45° |

## Notes

- mechanical_flag=0 and species_flag=0 for all ML cases (speed up simulations)
- timax = toolpath_end_time + 0.005 s (per-case, avoids excess cooling time)
- Results go in `results/`, models in `models/`
