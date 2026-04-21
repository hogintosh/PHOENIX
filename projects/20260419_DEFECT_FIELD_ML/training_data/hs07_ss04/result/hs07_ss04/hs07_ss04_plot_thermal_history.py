import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

data = np.loadtxt("hs07_ss04_thermal_history.txt", comments="#")
if data.ndim == 1: data = data[np.newaxis, :]
t = data[:, 0] * 1e3  # ms
labels = [
    "P1: track7 start surface",
    "P2: centre surface",
    "P3: track7 end surface",
    "P4: centre 40um depth",
    "P5: centre 100um depth",
    "P6: inter-track surface",
    "P7: 2-hatch offset surface",
    "P8: scan edge surface",
    "P9: outside scan surface",
    "P10: deep substrate",
]
fig, ax = plt.subplots(figsize=(12, 6))
for i in range(10):
    ax.plot(t, data[:, i+1], label=labels[i])
ax.axhline(1563, color="gray", linestyle="--", linewidth=0.8, label="T_solid")
ax.axhline(2650, color="red",  linestyle="--", linewidth=0.8, label="T_boiling")
ax.set_xlabel("Time (ms)")
ax.set_ylabel("Temperature (K)")
ax.set_title("Thermal History - 10 Monitoring Points")
ax.legend(fontsize=7, loc="upper right")
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig("hs07_ss04_thermal_history.png", dpi=150)
print("Saved hs07_ss04_thermal_history.png")
