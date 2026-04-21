import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

data = np.loadtxt("hs06_ss01_meltpool_history.txt", comments="#")
if data.ndim == 1: data = data[np.newaxis, :]
t = data[:, 0] * 1e3  # ms
length = data[:, 1] * 1e6  # um
depth  = data[:, 2] * 1e6  # um
width  = data[:, 3] * 1e6  # um
volume = data[:, 4] * 1e9  # mm^3 (1e-9 m^3 = 1 mm^3)
tpeak  = data[:, 5]

fig, axes = plt.subplots(4, 1, figsize=(12, 11), sharex=True)

axes[0].plot(t, length, "b-", lw=0.8)
axes[0].set_ylabel("Length (um)")
axes[0].set_title("Melt Pool Geometry History")
axes[0].grid(True, alpha=0.3)

axes[1].plot(t, depth, "r-", lw=0.8)
axes[1].plot(t, width, "g-", lw=0.8)
axes[1].set_ylabel("Size (um)")
axes[1].legend(["Depth", "Width"], fontsize=8)
axes[1].grid(True, alpha=0.3)

axes[2].plot(t, volume, "m-", lw=0.8)
axes[2].set_ylabel("Volume (mm$^3$)")
axes[2].grid(True, alpha=0.3)

axes[3].plot(t, tpeak, "r-", lw=0.8)
axes[3].axhline(2650, color="red", ls="--", lw=0.8, label="T_boiling")
axes[3].set_ylabel("T_peak (K)")
axes[3].set_xlabel("Time (ms)")
axes[3].legend(fontsize=8)
axes[3].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig("hs06_ss01_meltpool_history.png", dpi=150)
print("Saved hs06_ss01_meltpool_history.png")
