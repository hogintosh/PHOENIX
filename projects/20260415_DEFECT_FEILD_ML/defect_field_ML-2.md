# Defect Field ML — Fast Prediction of 3D Defect Fields via Autoencoder + NN

## Objective

Build a surrogate model that maps process parameters (hatch spacing, scan speed) to **3D defect fields** using an autoencoder for dimensionality reduction and a neural network for parameter-to-latent mapping.

- LOF porosity: max temperature < T_solid → powder not fully melted
- Keyhole porosity: max temperature > T_boiling → vapor pores
- **Total porosity = LOF + Keyhole**

Pipeline: `Input Parameters → NN → Latent Variables → Decoder → 3D Defect Field`

---

## Overall Pipeline

```
Step 1: Data Generation (10×10 grid simulations)
Step 2: Autoencoder Training (3D defect array → latent variables)
Step 3: NN Fitting (hatch_spacing, scan_speed → latent variables)
Step 4: Test Data Generation (10 in-range + 10 out-of-range)
Step 5: Interpolation & Extrapolation Testing
```

---

## Step 1: Data Generation (Training Data)

### 1.1 Variable Parameters

Only two parameters vary; all others are fixed at `input_param.txt` defaults.

| Parameter | Symbol | Range | Unit | Grid |
|-----------|--------|-------|------|------|
| Hatch spacing | `hatch_spacing` | 50e-6 – 150e-6 | m | 10 uniform points |
| Scan speed | `scan_speed` | 0.8 – 1.6 | m/s | 10 uniform points |

**Total: 10 × 10 = 100 training simulations**

### 1.2 Fixed Toolpath Parameters

| Parameter | Value | Note |
|-----------|-------|------|
| `size_x` | 1e-3 (1 mm) | Scan region width |
| `size_y` | 1e-3 (1 mm) | Scan region height |
| `center_x` | 1e-3 | Centered in 2 mm domain |
| `center_y` | 1e-3 | Centered in 2 mm domain |
| `start_z` | 0.0006975 | Top of domain minus half layer |
| `rotation_angle` | 45 | degrees CCW |
| `scan_axis` | x | default |
| `bidirectional` | yes | default |
| `turnaround_time` | 0.0005 | s |

### 1.3 Fixed Input File Parameters

All parameters from `input_param.txt` remain unchanged except:
- `toolpath_file` in `&output_control` — updated per case to point to each case's `.crs` file
- `case_name` in `&output_control` — unique per case
- `timax` in `&numerical_relax` — set to **toolpath_end_time + 0.005s** per case (read from the last line of `.crs`). This avoids simulating unnecessary cooling time after scanning ends. Range: 0.013s (sparse/fast) to 0.043s (dense/slow), vs. original 0.09s — roughly **2× speedup**.

### 1.4 File Organization

**All generated files (toolpaths, results, scripts) live inside this project folder. The codebase (`fortran_new/`) is not modified.**

```
projects/20260415_DEFECT_FIELD_ML/
├── defect_field_ML.md              # This document
├── toolpath_generator_rectangle.py # Local copy from fortran_new/ToolFiles/ (do not modify original)
├── scripts/
│   ├── generate_training_data.py   # Generate 100 toolpaths + run scripts
│   ├── generate_test_data.py       # Generate 20 test cases
│   ├── train_autoencoder.py        # Step 2: autoencoder
│   ├── train_nn.py                 # Step 3: NN fitting
│   ├── evaluate.py                 # Step 5: testing
│   └── compute_porosity.sh         # Extract porosity from defect arrays
├── run_all_training.sh              # Master script: xargs -P 30, 1 OMP thread each
├── training_data/
│   ├── caselist.txt                # List of all case names
│   ├── training_summary.csv        # hatch_spacing, scan_speed per case
│   ├── hs{i}_ss{j}/               # 100 case folders (i,j = 00..09)
│   │   ├── toolpath.crs            # Generated toolpath
│   │   ├── toolpath.png            # Toolpath visualization
│   │   ├── inputfile/
│   │   │   └── input_param.txt     # Per-case input (unique toolpath_file, case_name)
│   │   ├── run_case.sh             # Per-case run script (isolated working dir)
│   │   ├── run.log                 # Simulation log (stdout+stderr)
│   │   └── result/                 # Simulation output (VTK, defect_report.txt)
├── test_data/
│   ├── interp_XX/                  # 10 in-range test cases
│   ├── extrap_XX/                  # 10 out-of-range test cases
│   └── test_summary.csv
├── models/
│   ├── autoencoder/                # Saved autoencoder weights
│   └── nn/                         # Saved NN weights
└── results/
    ├── autoencoder_loss.png        # Training curves
    ├── nn_loss.png
    ├── interpolation_results.png
    └── extrapolation_results.png
```

### 1.5 Automation

For each of the 100 cases, `generate_training_data.py` creates:
1. `toolpath.crs` — generated via `toolpath_generator_rectangle.py` with case-specific `hatch_spacing` and `scan_speed`
2. `inputfile/input_param.txt` — per-case copy with updated `toolpath_file` (absolute path) and `case_name`
3. `run_case.sh` — per-case script that:
   - Creates a temporary `run/` working directory inside the case folder
   - Copies the per-case input file and symlinks the executable
   - Runs the simulation from the isolated working directory
   - Copies results to `case_dir/result/` and cleans up `run/`

**Parallel execution**: `run_all_training.sh` launches cases via `xargs -P 30` — **30 cases in parallel, 1 OMP thread each**. Each case has its own working directory, so there are no shared-file conflicts.

### 1.6 Output

Each case produces:
- `defect.vtk` — 3D defect field (the target for ML)
- `defect_report.txt` — porosity metrics (for validation)

---

## Step 2: Autoencoder for Dimensionality Reduction

### 2.1 Objective

Compress each 3D defect array into a compact latent representation using an autoencoder-decoder architecture, with the defect array as both input and output.

### 2.2 Architecture

```
Input: 3D defect array (ni × nj × nk_layer)
  → Encoder (3D Conv / flatten + Dense)
    → Latent vector z (dimension: 2–4, test minimum)
  → Decoder (Dense + reshape / 3D Deconv)
→ Output: Reconstructed 3D defect array
```

### 2.3 Training Details

- **Input/Output**: The 100 defect arrays from Step 1 (self-supervised: input = output)
- **Loss**: MSE reconstruction loss
- **Latent dimension sweep**: Test d = 2, 3, 4; select the minimum dimension where reconstruction quality is acceptable (e.g., relative MSE < 1%)
- **Data**: Use all 100 samples (small dataset — may need augmentation or regularization)
- **Preprocessing**: Normalize defect arrays to [0, 1] or [-1, 1]

### 2.4 Deliverables

- Trained encoder (maps defect array → latent vector)
- Trained decoder (maps latent vector → defect array)
- Reconstruction loss vs. latent dimension plot
- Selected latent dimension with justification

---

## Step 3: NN Fitting (Parameters → Latent Variables)

### 3.1 Objective

Train a neural network to map process parameters to the autoencoder's latent space:

```
Input: (hatch_spacing, scan_speed) — 2 features
  → MLP (hidden layers)
→ Output: latent vector z — 2–4 values
```

### 3.2 Training Details

- **Input**: Normalized (hatch_spacing, scan_speed) pairs (100 points)
- **Output**: Latent vectors from the trained encoder (Step 2)
- **Loss**: MSE between predicted and true latent vectors
- **Architecture**: MLP with 2–3 hidden layers, ReLU activation
- **Confirm convergence**: Training loss curve must plateau; validate with leave-one-out or k-fold on the 100 samples

### 3.3 Full Prediction Pipeline

```
(hatch_spacing, scan_speed) → NN → latent z → Decoder → 3D defect field
```

### 3.4 Deliverables

- Trained NN model
- Training/validation loss curves (must show convergence)
- Predicted vs. true latent variables scatter plots

---

## Step 4: Test Data Generation

### 4.1 Interpolation Test Set (10 cases)

- 10 random (hatch_spacing, scan_speed) points **within** the training range:
  - hatch_spacing ∈ [50e-6, 150e-6]
  - scan_speed ∈ [0.8, 1.6]
- Points must not coincide with training grid points

### 4.2 Extrapolation Test Set (10 cases)

- 10 random (hatch_spacing, scan_speed) points **outside** the training range:
  - e.g., hatch_spacing ∈ [30e-6, 50e-6) ∪ (150e-6, 200e-6]
  - e.g., scan_speed ∈ [0.5, 0.8) ∪ (1.6, 2.0]

### 4.3 Run Simulations

- Generate toolpaths and run PHOENIX for all 20 test cases (same procedure as Step 1)
- Collect defect arrays as **ground truth**

### 4.4 Porosity Computation Script

`compute_porosity.sh` — reads defect VTK files and computes:
- **LOF porosity fraction**: volume fraction where defect_arr < 0 (weighted by |defect_arr|)
- **Keyhole porosity fraction**: volume fraction where defect_arr > 0 (weighted by defect_arr)
- **Total porosity fraction**: LOF + Keyhole

Reference: `mod_defect.f90` — `write_defect_report()` subroutine (lines 199–290), which defines:
- LOF: `defect_arr(i,j,k) < 0` → `v_lof += |defect_arr| * v_cell`
- Keyhole: `defect_arr(i,j,k) > 0 and <= 1` → `v_kep += defect_arr * v_cell`
- Fractions: `v_lof / v_total`, `v_kep / v_total`

---

## Step 5: Testing — Interpolation & Extrapolation

### 5.1 Evaluation Method

For each test case:
1. Predict defect field: `(hatch_spacing, scan_speed) → NN → z → Decoder → predicted defect array`
2. Compare with ground truth defect array from simulation

### 5.2 Metrics

| Metric | Description |
|--------|-------------|
| Field MSE | Voxel-wise MSE between predicted and true defect arrays |
| Field R² | Coefficient of determination over all voxels |
| LOF fraction error | |predicted - true| for LOF porosity fraction |
| Keyhole fraction error | |predicted - true| for keyhole porosity fraction |
| Total porosity error | |predicted - true| for total defect fraction |

### 5.3 Visualization

- Side-by-side 2D slices: predicted vs. ground truth defect fields
- Parity plots: predicted porosity fractions vs. true values
- Error distribution histograms

### 5.4 Expected Results

- **Interpolation**: Good agreement expected (points within training convex hull)
- **Extrapolation**: Degraded accuracy expected — quantify how far outside the training range the model remains useful

---

## Task Checklist

- [x] 1.1 Write `generate_training_data.py` — create 100 toolpaths + case folders + run scripts
- [x] 1.2 `run_all_training.sh` generated automatically by Step 1.1 (30 parallel, 1 thread, per-case timax)
- [x] 1.3 Run all 100 training simulations — **100/100 completed** (2026-03-24 00:20–11:18, ~11h)
- [x] 1.4 Verified: 100 defect VTK + 100 defect reports. Physics validated (LOF/keyhole trends correct)
- [x] 2.1 Write `train_autoencoder.py` — 2D Z-averaged defect arrays, sweep d=2,3,4
- [x] 2.2 Autoencoder trained — **d=2 selected** (relMSE=0.072%, well under 1% threshold)
- [x] 3.1 Write `train_nn.py` — MLP 2→128→256→128→64→d, 20k epochs, LOO-CV
- [x] 3.2 NN trained — **converged** (loss=0.001, LOO-CV MSE=1.77)
- [x] 4.1 Write `generate_test_data.py` — 10 interp + 10 extrap points generated
- [x] 4.2 Write `compute_porosity.sh` — extract LOF/keyhole/total from defect reports
- [x] 4.3 Run 20 test simulations — **20/20 completed** (2026-03-24 13:40–16:43)
- [x] 5.1 Write `evaluate.py` — full pipeline prediction, metrics, plots (fixed model architecture mismatch)
- [x] 5.2 Evaluation complete — results below
- [x] 6.1 Plotting — generate all diagnostic and result figures (see below)

### Plotting

The following plots are required to document training convergence, latent
quality, and evaluation accuracy. Each item describes the content,
axes/legend, and diagnostic purpose of the figure.

**Autoencoder training (Step 2)**

- *Autoencoder loss curves* — training loss vs. epoch, one curve per swept
  latent dimension (`d = 2, 3, 4`) on a single axes, log-scale y. Purpose:
  confirm convergence and compare how fast each `d` plateaus.
- *Reconstruction error vs. latent dim* — bar or line plot of final
  relative reconstruction MSE (%) vs. `d`. Horizontal reference line at the
  1% acceptance threshold. Purpose: justify the smallest `d` that clears the
  threshold (here `d = 2` at 0.072%).

**NN training (Step 3)**

- *NN loss curve* — training loss (MSE in latent space) vs. epoch, log-scale
  y. Purpose: show the loss plateaus, confirming convergence.
- *Latent parity plot* — predicted vs. true latent components on the 100
  training points; one subplot per latent dimension, with the `y = x` line
  overlaid. Purpose: show the NN faithfully reproduces each latent axis.
- *LOO-CV error per sample* — leave-one-out cross-validation MSE for each of
  the 100 held-out samples as a bar chart (x = sample index, y = error),
  with the mean drawn as a horizontal line. Purpose: expose outlier
  (hatch, speed) combinations where the surrogate is weakest.

**Evaluation (Step 5)**

- *Interpolation field comparison* — for up to 3 interpolation cases, a row
  of three 2D mid-Z slices: ground-truth defect field, predicted defect
  field, and their pointwise difference. Diverging colormap (`RdBu_r`)
  centered at 0; true/predicted share a common color range (1st/99th
  percentile across shown cases); the difference panel uses its own
  symmetric range and reports the case MSE in its title. Row label shows
  the case's `(hatch_spacing, scan_speed)`.
- *Extrapolation field comparison* — identical layout to the above, but
  for extrapolation cases. Purpose: visualize how the prediction degrades
  outside the training convex hull.
- *Porosity parity plot* — three side-by-side scatter plots for LOF,
  keyhole, and total porosity fractions (predicted y vs. true x). Two
  marker/color series: interpolation (blue circles) and extrapolation
  (red squares); `y = x` dashed reference line; equal aspect ratio.
  Purpose: single-glance summary of scalar-porosity accuracy across all 20
  test cases and both regimes.
- *Error summary bar chart* — five side-by-side bar charts (field MSE,
  field R², LOF fraction error, keyhole fraction error, total porosity
  error), each comparing the mean over interpolation vs. extrapolation
  cases. Numeric value annotated on top of every bar. Purpose: quantitative
  interp-vs-extrap comparison in one figure, complementing the parity plot.

**Porosity definition (used by the parity and error-summary plots)**

Matches `mod_defect.f90`'s `write_defect_report`. With equal-volume cells
the cell volume cancels, so over the full defect array:

- LOF fraction = Σ |defect| over voxels with `defect < 0`, divided by total voxel count
- Keyhole fraction = Σ defect over voxels with `0 < defect ≤ 1`, divided by total voxel count
- Total fraction = LOF + keyhole

**How to regenerate every figure**

```bash
cd projects/20260323_DEFECT_FIELD_ML-COMPLETED20260331
python scripts/train_autoencoder.py   # autoencoder loss + recon-vs-d plots
python scripts/train_nn.py            # NN loss, latent parity, LOO-CV plots
python scripts/evaluate.py            # interp/extrap field comparisons, porosity parity, error summary
```

### Evaluation Results (Step 5)

| Metric | Interpolation (10 cases) | Extrapolation (10 cases) |
|--------|--------------------------|--------------------------|
| Mean Field MSE | 1.64e-02 | 2.98e-02 |
| Mean Field R² | 0.46 | -10.80 |
| Mean LOF error | 0.42% | 1.69% |
| Mean Keyhole error | 0.33% | 2.25% |
| Mean Total porosity error | 0.64% | 3.60% |

- **Interpolation**: Most cases have R² > 0.95, total porosity error < 1%. A few outliers (interp_05, interp_09) degrade the mean.
- **Extrapolation**: Significantly worse, especially for extreme parameter combinations (extrap_04, extrap_06 with very large/small hatch or speed). Mean R² is negative due to these outliers.
- **Conclusion**: The surrogate model works well for interpolation within the training range, but extrapolation requires caution — errors grow rapidly outside the training domain.
