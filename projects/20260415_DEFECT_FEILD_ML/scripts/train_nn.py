"""
Step 3: NN Fitting — (hatch_spacing, scan_speed) → latent PCA components.

Architecture: MLP with sklearn MLPRegressor
Input:  [hatch_spacing, scan_speed]  (normalized to [0,1])
Output: PCA latent vector z (dimension d selected by autoencoder step)

Training:
  - Fit on all 100 samples
  - Leave-one-out cross-validation (LOO-CV) to measure generalization
  - Save trained model + normalizer

Plots produced (saved to results/):
  nn_loss.png             — training loss curve
  nn_latent_parity.png    — predicted vs true latent components (100 training pts)
  nn_loo_cv.png           — LOO-CV MSE per sample bar chart
"""

import os
import sys
import pickle
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.neural_network import MLPRegressor
from sklearn.preprocessing import MinMaxScaler

PROJECT_DIR  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAINING_DIR = os.path.join(PROJECT_DIR, "training_data")
MODEL_DIR_AE = os.path.join(PROJECT_DIR, "models", "autoencoder")
MODEL_DIR_NN = os.path.join(PROJECT_DIR, "models", "nn")
RESULTS_DIR  = os.path.join(PROJECT_DIR, "results")
os.makedirs(MODEL_DIR_NN, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)


def load_training_params():
    """Load (hatch_spacing, scan_speed) from training_summary.csv in order."""
    csv_path = os.path.join(TRAINING_DIR, "training_summary.csv")
    rows = []
    with open(csv_path) as f:
        for line in f:
            if line.startswith("case_name"):
                continue
            parts = line.strip().split(",")
            hs, ss = float(parts[1]), float(parts[2])
            rows.append((parts[0], hs, ss))
    return rows


def main():
    print("=== Step 3: NN Training ===")

    # Load autoencoder metadata
    meta = np.load(os.path.join(MODEL_DIR_AE, "meta.npy"), allow_pickle=True).item()
    d = meta["selected_d"]
    cases = meta["cases"]
    print(f"Using latent dimension d={d} from autoencoder step")

    # Load latent vectors (PCA components)
    Z = np.load(os.path.join(MODEL_DIR_AE, f"latent_d{d}.npy"))  # (n, d)

    # Load process parameters
    param_rows = load_training_params()
    # Align with cases list
    param_dict = {row[0]: (row[1], row[2]) for row in param_rows}
    X_params = np.array([param_dict[c] for c in cases])  # (n, 2): hs, ss

    n = X_params.shape[0]
    print(f"Training data: {n} samples, {d} latent dims")

    # Normalize inputs to [0, 1]
    scaler = MinMaxScaler()
    X_scaled = scaler.fit_transform(X_params)

    # MLP architecture: hidden layers as in spec (2→128→256→128→64→d)
    hidden = (128, 256, 128, 64)
    mlp = MLPRegressor(
        hidden_layer_sizes=hidden,
        activation="relu",
        max_iter=20000,
        n_iter_no_change=500,
        tol=1e-8,
        random_state=0,
        verbose=False,
        learning_rate_init=1e-3,
        early_stopping=False,
    )

    print("Fitting MLP on all 100 training samples...")
    mlp.fit(X_scaled, Z)
    Z_pred_train = mlp.predict(X_scaled)
    train_mse = np.mean((Z - Z_pred_train) ** 2)
    print(f"  Final training MSE: {train_mse:.6f}")
    print(f"  Iterations: {mlp.n_iter_}")

    # LOO-CV
    print("Running leave-one-out cross-validation...")
    loo_mses = []
    for k in range(n):
        mask = np.ones(n, dtype=bool)
        mask[k] = False
        X_tr, Z_tr = X_scaled[mask], Z[mask]
        X_val, Z_val = X_scaled[[k]], Z[[k]]

        mlp_loo = MLPRegressor(
            hidden_layer_sizes=hidden,
            activation="relu",
            max_iter=5000,
            n_iter_no_change=200,
            tol=1e-7,
            random_state=0,
            verbose=False,
            learning_rate_init=1e-3,
        )
        mlp_loo.fit(X_tr, Z_tr)
        Z_val_pred = mlp_loo.predict(X_val)
        loo_mse = float(np.mean((Z_val - Z_val_pred) ** 2))
        loo_mses.append(loo_mse)
        if (k + 1) % 10 == 0:
            print(f"  LOO {k+1}/{n}")

    loo_mses = np.array(loo_mses)
    print(f"  LOO-CV mean MSE: {loo_mses.mean():.4f}  max: {loo_mses.max():.4f}")

    # Save models
    with open(os.path.join(MODEL_DIR_NN, "mlp.pkl"), "wb") as f:
        pickle.dump(mlp, f)
    with open(os.path.join(MODEL_DIR_NN, "scaler.pkl"), "wb") as f:
        pickle.dump(scaler, f)
    nn_meta = dict(d=d, train_mse=train_mse, loo_mses=loo_mses.tolist(),
                   cases=cases, n_iter=mlp.n_iter_)
    np.save(os.path.join(MODEL_DIR_NN, "meta.npy"), nn_meta, allow_pickle=True)
    print(f"Models saved in {MODEL_DIR_NN}")

    # --- Plots ---

    # 1) Training loss curve
    loss_curve = mlp.loss_curve_
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.semilogy(loss_curve, color="steelblue", lw=1.5)
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Training MSE (log scale)")
    ax.set_title(f"NN training loss — MLP {hidden} → d={d}")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    path = os.path.join(RESULTS_DIR, "nn_loss.png")
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"Saved {path}")

    # 2) Latent parity plots (predicted vs true on training set)
    fig, axes = plt.subplots(1, d, figsize=(4 * d, 4))
    if d == 1:
        axes = [axes]
    for dim_idx in range(d):
        ax = axes[dim_idx]
        ax.scatter(Z[:, dim_idx], Z_pred_train[:, dim_idx], s=20, alpha=0.7)
        lo = min(Z[:, dim_idx].min(), Z_pred_train[:, dim_idx].min())
        hi = max(Z[:, dim_idx].max(), Z_pred_train[:, dim_idx].max())
        ax.plot([lo, hi], [lo, hi], "r--", lw=1)
        ax.set_xlabel(f"True z{dim_idx+1}")
        ax.set_ylabel(f"Predicted z{dim_idx+1}")
        ax.set_title(f"Latent component {dim_idx+1}")
        ax.set_aspect("equal")
        ax.grid(True, alpha=0.3)
    fig.suptitle(f"NN latent parity (training data, d={d})", y=1.02)
    fig.tight_layout()
    path = os.path.join(RESULTS_DIR, "nn_latent_parity.png")
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved {path}")

    # 3) LOO-CV bar chart
    fig, ax = plt.subplots(figsize=(12, 4))
    ax.bar(range(n), loo_mses, color="steelblue", edgecolor="k", linewidth=0.3)
    ax.axhline(loo_mses.mean(), color="red", ls="--", lw=1.5,
               label=f"Mean LOO-CV MSE = {loo_mses.mean():.4f}")
    ax.set_xlabel("Sample index")
    ax.set_ylabel("LOO-CV MSE")
    ax.set_title("Leave-one-out cross-validation error per sample")
    ax.legend()
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    path = os.path.join(RESULTS_DIR, "nn_loo_cv.png")
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"Saved {path}")

    print(f"\nNN training complete. LOO-CV mean MSE={loo_mses.mean():.4f}")


if __name__ == "__main__":
    main()
