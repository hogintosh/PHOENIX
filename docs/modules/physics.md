# Physics Modules

Laser, toolpath, melt pool detection, species transport, local solver.

---

## mod_laser.f90 — `laserinput`

Laser beam management. Each timestep: interpolates toolpath to find beam position, computes scan velocity, distributes power as 2D Gaussian on top surface.

---

## mod_toolpath.f90 — `toolpath`

- `read_toolpath()` — reads `.crs` file into `toolmatrix(1000, 5)`: time, x, y, z, laser_flag
- `read_coordinates()` — records beam state to rolling buffer each timestep

---

## mod_dimen.f90 — `dimensions`

Melt pool detection from temperature field:

- Computes `alen` (length), `depth`, `width` via linear interpolation at solidus isotherm
- Sets momentum solver bounds (`istat:iend`, `jstat:jend`, `kstat`) with padding

---

## mod_local_enthalpy.f90 — `local_enthalpy`

Adaptive local/global solver scheduling:

- `get_enthalpy_region()` — determines if step is local or global (every `localnum+1` steps)
- `compute_delt_eff()` — effective timestep for skipped cells: `delt × (n_skipped + 1)`
- `update_skipped()` — tracks skip counts per cell

---

## mod_species.f90 — `species`

Dissimilar metal species transport. See [Species Transport](../species/overview.md).

Key functions: `mix(prop1, prop2, C)`, `solve_species()` (FVM + TDMA + block correction), `species_bc()` (zero-flux Neumann).
