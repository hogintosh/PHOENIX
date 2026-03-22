# Post-Processing Modules

Defect prediction, microstructure, crack risk, output, timing.

---

## mod_defect.f90 — `defect_field`

Post-simulation defect detection from peak temperature history.

- `update_max_temp()` — called every timestep, tracks maximum temperature per cell
- `compute_defect_determ()` — classifies cells: lack-of-fusion ($T_{max} < T_s$), sound, keyhole ($T_{max} > T_b$)
- `write_defect_report()` — volumetric defect fractions, VTK output (`maxtemp.vtk`, `defect.vtk`)
- `compute_scan_range()` / `point_in_scan_region()` — builds convex hull of scanned region from toolpath, used by all post-processing modules

---

## mod_microstructure.f90 — `microstructure_mod`

Solidification microstructure prediction. Enabled by `micro_flag=1`. **Only updates during global solver timesteps.**

- `update_microstructure(dt)` — detects solidification events (`fracl` drops to 0), computes:
    - Cooling rate `|dT/dt|`
    - Thermal gradient `G = |∇T|` (central differences, one-sided at boundaries)
    - Solidification rate `R = |dT/dt| / G`
    - PDAS: $\lambda_1 = a_1 \cdot G^{n_1} \cdot R^{n_2}$
    - SDAS: $\lambda_2 = a_2 \cdot |\dot{T}|^{n_3}$
- `report_microstructure()` — statistics + single `microstructure.vtk` with 5 scalar fields

---

## mod_crack_risk.f90 — `crack_risk_mod`

Crack risk from thermal strain in the Brittle Temperature Range (BTR). Enabled by `crack_flag=1`. **Only updates during global solver timesteps.**

- `update_crack_risk(dt)` — detects solidification, accumulates BTR strain:
    - CSI $= \int_{BTR} \alpha \cdot |\dot{T}| \, dt$ where BTR $= [T_s - \Delta T_{BTR}, T_s]$
- `compute_crack_report()` — statistics + single `crack_risk.vtk` with 4 scalar fields

---

## mod_print.f90 — `printing`

All output routines:

- `outputres()` — per-timestep text log (residuals, pool size, energy balance)
- `Cust_Out()` — VTK snapshots at `outputintervel` frequency (T, velocity, vis, diff, den, solidID, localfield, fracl, [concentration, tsolid_field])
- `init/write/finalize_thermal_history()` — temperature at 10 monitoring points + Python plot
- `init/write/finalize_meltpool_history()` — melt pool geometry time-series + Python plot (global steps only)

---

## mod_timing.f90 — `timing`

- `write_timing_report()` — CPU time breakdown by module (17 categories)
- `write_memory_report()` — peak memory from `/proc/self/status`
