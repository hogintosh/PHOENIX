# Core Infrastructure

Foundation modules: precision, constants, utilities, parameters, geometry, field storage.

---

## mod_precision.f90 — `precision`

Defines working precision for the entire codebase.

```fortran
integer, parameter :: wp = selected_real_kind(6, 37)  ! single precision
```

All floating-point variables use `real(wp)`. Change to `selected_real_kind(15, 307)` for double precision.

---

## mod_const.f90 — `constant`

Physical constants and simulation control parameters.

| Constant | Value | Description |
|----------|-------|-------------|
| `g` | 9.8 | Gravitational acceleration (m/s²) |
| `pi` | 3.14159... | Pi |
| `sigm` | 5.67e-8 | Stefan-Boltzmann constant (W/m²/K⁴) |
| `great` | 1e20 | Large number (for zeroing solid velocity) |
| `small` | 1e-6 | Small number (avoid division by zero) |
| `conv_res_heat` | 1e-5 | Enthalpy convergence threshold (heating) |
| `conv_res_cool` | 1e-6 | Enthalpy convergence threshold (cooling) |
| `vis_solid` | 1e10 | Effective viscosity in solid (Pa·s) |
| `powder_threshold` | 0.5 | solidfield threshold for powder detection |

---

## mod_cfd_utils.f90 — `cfd_utils`

Pure utility functions for CFD calculations.

- `temp_to_enthalpy(T, ...)` — Piecewise H-T conversion (solid/mushy/liquid)
- `harmonic_mean(val1, val2, frac)` — Face property interpolation
- `power_law_coeff(diff, flux)` — Power-law discretization scheme
- `darcy_resistance(viscos, fracl)` — Carman-Kozeny mushy zone model

---

## mod_param.f90 — `parameters`

Reads all simulation parameters from `input_param.txt`. See [Input File Reference](../input-reference.md).

---

## mod_geom.f90 — `geometry`

Generates 3D structured grid with power-law spacing. Computes all geometric quantities: cell volumes, face areas, inverse distances, interpolation fractions.

---

## mod_field_data.f90 — `field_data`

Primary flow field arrays: velocity (`uVel/vVel/wVel`), pressure, enthalpy, temperature, liquid fraction, and their previous-timestep copies.

---

## mod_coeff_data.f90 — `coeff_data`

FVM discretization coefficient arrays (`an/as/ae/aw/at/ab/ap/su/sp`), material property arrays (`vis/diff/den`), velocity correction coefficients. All **shared** between equations sequentially.

---

## mod_sim_state.f90 — `sim_state`

Global simulation state: derived constants (`dgdt`, `boufac`, `deltemp`, `hlcal`), residuals, beam position, toolpath matrix, coordinate history.

---

## mod_init.f90 — `initialization`

Computes derived constants, initializes all fields to preheat conditions, sets enthalpy boundary values.
