"""
Step 2: Autoencoder for dimensionality reduction of 3D defect fields.

Strategy:
  - Load 100 defect VTK files → average over Z → 2D field (ny×nx)
  - Flatten → PCA (linear autoencoder, optimal in MSE sense)
  - Sweep latent dimension d = 2, 3, 4
  - Select minimum d with relative MSE < 1%
  - Save encoder/decoder (PCA model) to models/autoencoder/

Plots produced (saved to results/):
  autoencoder_loss.png        — reconstruction MSE vs d (bar chart + threshold line)
  autoencoder_training.png    — cumulative explained variance vs # components
"""

import os
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.decomposition import PCA
import pickle

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAINING_DIR = os.path.join(PROJECT_DIR, "training_data")
MODEL_DIR    = os.path.join(PROJECT_DIR, "models", "autoencoder")
RESULTS_DIR  = os.path.join(PROJECT_DIR, "results")
os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)


def read_defect_vtk(filepath):
    """Parse a PHOENIX binary VTK structured grid file, return defect array (nz, ny, nx)."""
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
            parts = line.split()
            nx, ny, nz = int(parts[1]), int(parts[2]), int(parts[3])
            dims = (nz, ny, nx)
        elif line.startswith("POINTS"):
            npts = int(line.split()[1])
            pos += npts * 3 * 4
        elif line.startswith("SCALARS defect"):
            read_line()  # LOOKUP_TABLE default
            arr = np.frombuffer(raw[pos: pos + npts * 4], dtype=">f4").astype(np.float32)
            return arr.reshape(dims)

    raise ValueError(f"Could not find 'SCALARS defect' in {filepath}")


def load_all_defect_arrays():
    with open(os.path.join(TRAINING_DIR, "caselist.txt")) as f:
        cases = [l.strip() for l in f if l.strip()]

    arrays = []
    missing = []
    for case in cases:
        vtk_path = os.path.join(TRAINING_DIR, case, "result", case, f"{case}_defect.vtk")
        if not os.path.exists(vtk_path):
            missing.append(case)
            continue
        arr3d = read_defect_vtk(vtk_path)
        arr2d = arr3d.mean(axis=0)
        arrays.append(arr2d.flatten())

    if missing:
        print(f"WARNING: {len(missing)} missing VTK files: {missing[:5]}...")
    if not arrays:
        raise RuntimeError("No defect VTK files found. Run simulations first.")

    X = np.stack(arrays, axis=0)
    print(f"Loaded {len(arrays)} defect arrays, shape {X.shape}")
    return X, cases[:len(arrays)]


def fit_pca_autoencoder(X, d):
    pca = PCA(n_components=d, random_state=0)
    Z = pca.fit_transform(X)
    X_recon = pca.inverse_transform(Z)
    mse = np.mean((X - X_recon) ** 2)
    rel_mse = mse / (np.var(X) + 1e-30)
    return pca, Z, X_recon, rel_mse


def plot_cumvar(X, max_d=20):
    pca_full = PCA(n_components=min(max_d, X.shape[0] - 1), random_state=0)
    pca_full.fit(X)
    cum_var = np.cumsum(pca_full.explained_variance_ratio_) * 100

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(range(1, len(cum_var) + 1), cum_var, "b-o", ms=5)
    ax.axhline(99, color="gray", ls="--", label="99%")
    ax.set_xlabel("Number of PCA components")
    ax.set_ylabel("Cumulative explained variance (%)")
    ax.set_title("Autoencoder: cumulative variance vs latent dimension")
    ax.legend()
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    path = os.path.join(RESULTS_DIR, "autoencoder_training.png")
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"Saved {path}")


def plot_recon_error(ds, rel_mses):
    fig, ax = plt.subplots(figsize=(6, 4))
    colors = ["green" if e < 0.01 else "tomato" for e in rel_mses]
    bars = ax.bar(ds, [e * 100 for e in rel_mses], color=colors, edgecolor="k")
    ax.axhline(1.0, color="red", ls="--", lw=1.5, label="1% threshold")
    for bar, e in zip(bars, rel_mses):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.005,
                f"{e*100:.3f}%", ha="center", va="bottom", fontsize=9)
    ax.set_xlabel("Latent dimension d")
    ax.set_ylabel("Relative reconstruction MSE (%)")
    ax.set_title("Autoencoder reconstruction error vs latent dimension")
    ax.legend()
    ax.set_xticks(ds)
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    path = os.path.join(RESULTS_DIR, "autoencoder_loss.png")
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"Saved {path}")


def main():
    print("=== Step 2: Autoencoder Training ===")
    X, cases = load_all_defect_arrays()

    dims = [2, 3, 4]
    results = {}
    for d in dims:
        pca, Z, X_recon, rel_mse = fit_pca_autoencoder(X, d)
        results[d] = dict(pca=pca, Z=Z, X_recon=X_recon, rel_mse=rel_mse)
        print(f"  d={d}: rel MSE = {rel_mse*100:.4f}%  "
              f"({'PASS' if rel_mse < 0.01 else 'FAIL'} < 1%)")

    selected_d = None
    for d in dims:
        if results[d]["rel_mse"] < 0.01:
            selected_d = d
            break
    if selected_d is None:
        selected_d = dims[-1]
        print(f"WARNING: no d meets <1% threshold, using d={selected_d}")
    else:
        print(f"\nSelected d={selected_d} "
              f"(rel MSE={results[selected_d]['rel_mse']*100:.4f}%)")

    for d in dims:
        model_path = os.path.join(MODEL_DIR, f"pca_d{d}.pkl")
        with open(model_path, "wb") as f:
            pickle.dump(results[d]["pca"], f)
        np.save(os.path.join(MODEL_DIR, f"latent_d{d}.npy"), results[d]["Z"])
        print(f"  Saved PCA d={d} → {model_path}")

    meta = dict(
        selected_d=selected_d,
        cases=cases,
        X_shape=list(X.shape),
        rel_mses={d: results[d]["rel_mse"] for d in dims},
    )
    np.save(os.path.join(MODEL_DIR, "meta.npy"), meta, allow_pickle=True)
    np.save(os.path.join(MODEL_DIR, "X_flat.npy"), X)

    plot_cumvar(X, max_d=min(20, len(cases) - 1))
    plot_recon_error(dims, [results[d]["rel_mse"] for d in dims])

    print(f"\nAutoencoder training complete. Selected latent dimension: d={selected_d}")
    print(f"Models saved in {MODEL_DIR}")


if __name__ == "__main__":
    main()
