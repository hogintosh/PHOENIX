"""
Step 5: Evaluate the trained surrogate model on interpolation and extrapolation test cases.

Pipeline: (hatch_spacing, scan_speed) → MLP → latent z → PCA decoder → 3D defect field

Metrics per test case:
  - Field MSE and R² (voxelwise, on Z-averaged 2D array)
  - LOF porosity fraction error
  - Keyhole porosity fraction error
  - Total porosity fraction error

Plots produced (saved to results/):
  interp_field_comparison.png    — 3 interp cases: true / predicted / difference
  extrap_field_comparison.png    — 3 extrap cases: same layout
  porosity_parity.png            — LOF / keyhole / total parity plots
  error_summary.png              — 5 metric bar charts (interp vs extrap)
"""

import os
import pickle
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PROJECT_DIR  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_DIR     = os.path.join(PROJECT_DIR, "test_data")
MODEL_DIR_AE = os.path.join(PROJECT_DIR, "models", "autoencoder")
MODEL_DIR_NN = os.path.join(PROJECT_DIR, "models", "nn")
RESULTS_DIR  = os.path.join(PROJECT_DIR, "results")
os.makedirs(RESULTS_DIR, exist_ok=True)


def read_defect_vtk(filepath):
    with open(filepath, "rb") as f:
        raw = f.read()
    pos = 0
    dims = None
    npts = None

    def read_line():
        nonlocal pos
        nl = raw.find(b"\n", pos)
        if nl == -1:
            return None
        line = raw[pos:nl].decode("ascii", errors="replace").strip()
        pos = nl + 1
        return line

    while True:
        line = read_line()
        if line is None:
            break
        if line.startswith("DIMENSIONS"):
            p = line.split()
            nx, ny, nz = int(p[1]), int(p[2]), int(p[3])
            dims = (nz, ny, nx)
        elif line.startswith("POINTS"):
            npts = int(line.split()[1])
            pos += npts * 3 * 4
        elif line.startswith("SCALARS defect"):
            read_line()
            arr = np.frombuffer(raw[pos: pos + npts * 4], dtype=">f4").astype(np.float32)
            return arr.reshape(dims)
    raise ValueError(f"Could not find 'SCALARS defect' in {filepath}")


def defect_vtk_to_2d(filepath):
    return read_defect_vtk(filepath).mean(axis=0)


def compute_porosity(arr2d):
    n = arr2d.size
    lof = np.sum(np.abs(arr2d[arr2d < 0])) / n
    kep = np.sum(arr2d[(arr2d > 0) & (arr2d <= 1)]) / n
    return float(lof), float(kep), float(lof + kep)


def load_models():
    ae_meta = np.load(os.path.join(MODEL_DIR_AE, "meta.npy"), allow_pickle=True).item()
    d = ae_meta["selected_d"]
    with open(os.path.join(MODEL_DIR_AE, f"pca_d{d}.pkl"), "rb") as f:
        pca = pickle.load(f)
    with open(os.path.join(MODEL_DIR_NN, "mlp.pkl"), "rb") as f:
        mlp = pickle.load(f)
    with open(os.path.join(MODEL_DIR_NN, "scaler.pkl"), "rb") as f:
        scaler = pickle.load(f)
    return pca, mlp, scaler, d


def predict_defect_2d(hs, ss, pca, mlp, scaler):
    X_in = scaler.transform([[hs, ss]])
    z_pred = mlp.predict(X_in)
    return pca.inverse_transform(z_pred)[0]


def load_test_summary():
    csv_path = os.path.join(TEST_DIR, "test_summary.csv")
    interp_cases, extrap_cases = [], []
    with open(csv_path) as f:
        for line in f:
            if line.startswith("case_name"):
                continue
            p = line.strip().split(",")
            entry = dict(case=p[0], hs=float(p[1]), ss=float(p[2]), kind=p[4])
            if p[4] == "interp":
                interp_cases.append(entry)
            else:
                extrap_cases.append(entry)
    return interp_cases, extrap_cases


def evaluate_case(entry, pca, mlp, scaler):
    case_name = entry["case"]
    vtk_path = os.path.join(TEST_DIR, case_name, "result", case_name, f"{case_name}_defect.vtk")
    if not os.path.exists(vtk_path):
        return None

    true_2d   = defect_vtk_to_2d(vtk_path)
    true_flat = true_2d.flatten()
    pred_flat = predict_defect_2d(entry["hs"], entry["ss"], pca, mlp, scaler)
    pred_2d   = pred_flat.reshape(true_2d.shape)

    mse = float(np.mean((true_flat - pred_flat) ** 2))
    ss_res = np.sum((true_flat - pred_flat) ** 2)
    ss_tot = np.sum((true_flat - true_flat.mean()) ** 2)
    r2  = float(1 - ss_res / (ss_tot + 1e-30))

    lof_t, kep_t, tot_t = compute_porosity(true_2d)
    lof_p, kep_p, tot_p = compute_porosity(pred_2d)

    return dict(
        case=case_name, hs=entry["hs"], ss=entry["ss"],
        true_2d=true_2d, pred_2d=pred_2d,
        mse=mse, r2=r2,
        lof_true=lof_t, lof_pred=lof_p, lof_err=abs(lof_t - lof_p),
        kep_true=kep_t, kep_pred=kep_p, kep_err=abs(kep_t - kep_p),
        tot_true=tot_t, tot_pred=tot_p, tot_err=abs(tot_t - tot_p),
    )


def plot_field_comparison(results, title_prefix, filename, n_show=3):
    valid = [r for r in results if r is not None][:n_show]
    if not valid:
        print(f"No valid results for {filename}")
        return

    all_vals = np.concatenate([np.stack([r["true_2d"].flatten(),
                                          r["pred_2d"].flatten()]) for r in valid])
    vlo = np.percentile(all_vals, 1)
    vhi = np.percentile(all_vals, 99)

    n = len(valid)
    fig, axes = plt.subplots(n, 3, figsize=(12, 4 * n))
    if n == 1:
        axes = axes[np.newaxis, :]

    for row, r in enumerate(valid):
        true_2d = r["true_2d"]
        pred_2d = r["pred_2d"]
        diff_2d = pred_2d - true_2d
        diff_lim = max(abs(diff_2d.min()), abs(diff_2d.max())) + 1e-9

        ax0, ax1, ax2 = axes[row]
        im0 = ax0.imshow(true_2d, cmap="RdBu_r", vmin=vlo, vmax=vhi, origin="lower")
        im1 = ax1.imshow(pred_2d, cmap="RdBu_r", vmin=vlo, vmax=vhi, origin="lower")
        im2 = ax2.imshow(diff_2d, cmap="RdBu_r", vmin=-diff_lim, vmax=diff_lim, origin="lower")

        ax0.set_title(f"Ground truth\n(hs={r['hs']*1e6:.1f}µm, ss={r['ss']:.3f}m/s)")
        ax1.set_title("Predicted")
        ax2.set_title(f"Difference\nMSE={r['mse']:.3e}")

        for ax, im in [(ax0, im0), (ax1, im1), (ax2, im2)]:
            fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
            ax.axis("off")

    fig.suptitle(f"{title_prefix} — field comparison", fontsize=13)
    fig.tight_layout()
    path = os.path.join(RESULTS_DIR, filename)
    fig.savefig(path, dpi=120, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved {path}")


def plot_porosity_parity(interp_results, extrap_results):
    fig, axes = plt.subplots(1, 3, figsize=(14, 5))
    labels = ["LOF fraction", "Keyhole fraction", "Total porosity"]
    keys_t = ["lof_true", "kep_true", "tot_true"]
    keys_p = ["lof_pred", "kep_pred", "tot_pred"]

    for ax, label, kt, kp in zip(axes, labels, keys_t, keys_p):
        ix = [r[kt] for r in interp_results if r]
        iy = [r[kp] for r in interp_results if r]
        ex = [r[kt] for r in extrap_results if r]
        ey = [r[kp] for r in extrap_results if r]

        ax.scatter(ix, iy, s=60, marker="o", color="steelblue", label="Interpolation")
        ax.scatter(ex, ey, s=60, marker="s", color="tomato",    label="Extrapolation")

        all_x = ix + ex + iy + ey
        if all_x:
            lo, hi = min(all_x), max(all_x)
            margin = (hi - lo) * 0.05
            ax.plot([lo - margin, hi + margin], [lo - margin, hi + margin],
                    "k--", lw=1, label="y=x")
        ax.set_xlabel(f"True {label}")
        ax.set_ylabel(f"Predicted {label}")
        ax.set_title(label)
        ax.set_aspect("equal")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

    fig.suptitle("Porosity parity: predicted vs true", fontsize=13)
    fig.tight_layout()
    path = os.path.join(RESULTS_DIR, "porosity_parity.png")
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved {path}")


def plot_error_summary(interp_results, extrap_results):
    metrics = [
        ("mse",     "Field MSE"),
        ("r2",      "Field R²"),
        ("lof_err", "LOF fraction error"),
        ("kep_err", "Keyhole fraction error"),
        ("tot_err", "Total porosity error"),
    ]

    def mean_metric(results, key):
        vals = [r[key] for r in results if r is not None]
        return np.mean(vals) if vals else 0.0

    fig, axes = plt.subplots(1, 5, figsize=(18, 5))
    for ax, (key, label) in zip(axes, metrics):
        i_val = mean_metric(interp_results, key)
        e_val = mean_metric(extrap_results, key)
        bars = ax.bar(["Interp", "Extrap"], [i_val, e_val],
                      color=["steelblue", "tomato"], edgecolor="k")
        for bar, val in zip(bars, [i_val, e_val]):
            ax.text(bar.get_x() + bar.get_width() / 2,
                    bar.get_height() * 1.02,
                    f"{val:.3e}", ha="center", va="bottom", fontsize=8)
        ax.set_title(label)
        ax.set_ylabel(label)
        ax.grid(True, axis="y", alpha=0.3)
    fig.suptitle("Error summary: interpolation vs extrapolation", fontsize=13)
    fig.tight_layout()
    path = os.path.join(RESULTS_DIR, "error_summary.png")
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved {path}")


def main():
    print("=== Step 5: Evaluation ===")

    pca, mlp, scaler, d = load_models()
    interp_cases, extrap_cases = load_test_summary()
    print(f"Loaded models (d={d})")
    print(f"Test cases: {len(interp_cases)} interp + {len(extrap_cases)} extrap")

    print("\nEvaluating interpolation cases:")
    interp_results = []
    for entry in interp_cases:
        r = evaluate_case(entry, pca, mlp, scaler)
        if r is None:
            print(f"  MISSING: {entry['case']}")
        else:
            print(f"  {entry['case']}: MSE={r['mse']:.3e}  R²={r['r2']:.3f}  "
                  f"LOF_err={r['lof_err']*100:.3f}%  "
                  f"KEP_err={r['kep_err']*100:.3f}%  "
                  f"TOT_err={r['tot_err']*100:.3f}%")
        interp_results.append(r)

    print("\nEvaluating extrapolation cases:")
    extrap_results = []
    for entry in extrap_cases:
        r = evaluate_case(entry, pca, mlp, scaler)
        if r is None:
            print(f"  MISSING: {entry['case']}")
        else:
            print(f"  {entry['case']}: MSE={r['mse']:.3e}  R²={r['r2']:.3f}  "
                  f"LOF_err={r['lof_err']*100:.3f}%  "
                  f"KEP_err={r['kep_err']*100:.3f}%  "
                  f"TOT_err={r['tot_err']*100:.3f}%")
        extrap_results.append(r)

    def safe_mean(results, key):
        vals = [r[key] for r in results if r is not None]
        return np.mean(vals) if vals else float("nan")

    interp_valid = [r for r in interp_results if r]
    extrap_valid = [r for r in extrap_results if r]

    print("\n=== Summary ===")
    rows = [
        ("Field MSE",         safe_mean(interp_valid, "mse"),     safe_mean(extrap_valid, "mse")),
        ("Field R²",          safe_mean(interp_valid, "r2"),      safe_mean(extrap_valid, "r2")),
        ("LOF error",         safe_mean(interp_valid, "lof_err"), safe_mean(extrap_valid, "lof_err")),
        ("Keyhole error",     safe_mean(interp_valid, "kep_err"), safe_mean(extrap_valid, "kep_err")),
        ("Total poro. error", safe_mean(interp_valid, "tot_err"), safe_mean(extrap_valid, "tot_err")),
    ]
    print(f"  {'Metric':<22} {'Interpolation':>18} {'Extrapolation':>18}")
    for name, iv, ev in rows:
        print(f"  {name:<22} {iv:>18.4e} {ev:>18.4e}")

    plot_field_comparison(interp_valid, "Interpolation", "interp_field_comparison.png")
    plot_field_comparison(extrap_valid, "Extrapolation", "extrap_field_comparison.png")
    plot_porosity_parity(interp_valid, extrap_valid)
    plot_error_summary(interp_valid, extrap_valid)

    eval_results = dict(
        interp=[{k: v for k, v in r.items() if k not in ("true_2d", "pred_2d")}
                for r in interp_valid],
        extrap=[{k: v for k, v in r.items() if k not in ("true_2d", "pred_2d")}
                for r in extrap_valid],
    )
    np.save(os.path.join(RESULTS_DIR, "eval_results.npy"), eval_results, allow_pickle=True)
    print(f"\nAll plots and results saved in {RESULTS_DIR}")


if __name__ == "__main__":
    main()
