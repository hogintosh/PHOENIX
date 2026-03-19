# Architecture Overview

## Program Flow

```
main.f90
│
├── Initialization
│   ├── read_data()           ← Parse input_param.txt
│   ├── read_toolpath()       ← Load .crs toolpath
│   ├── generate_grid()       ← Build non-uniform 3D mesh
│   ├── allocate_fields()     ← Allocate all field arrays
│   ├── initialize()          ← Set initial conditions
│   └── allocate_species()    ← [if species_flag=1]
│
├── Time Stepping Loop (timet < timax)
│   │
│   ├── laser_beam()          ← Update beam position
│   ├── read_coordinates()    ← Record beam state
│   ├── get_enthalpy_region() ← Determine local/global solve
│   │
│   ├── Iteration Loop (niter < maxit)
│   │   │
│   │   ├── properties()       ← Update vis, diff, den from T (and C)
│   │   ├── bound_enthalpy()   ← Enthalpy BCs (radiation, convection)
│   │   ├── discretize_enthalpy() ← FVM coefficients for energy eq
│   │   ├── source_enthalpy()  ← Laser + latent heat source terms
│   │   ├── calc_enthalpy_residual()
│   │   ├── enhance_converge_speed() ← Block correction
│   │   ├── solution_enthalpy() ← TDMA solve for enthalpy
│   │   ├── enthalpy_to_temp() ← H → T, fracl conversion
│   │   ├── pool_size()        ← Find melt pool bounds
│   │   │
│   │   └── [if melt pool exists]
│   │       ├── cleanuvw()     ← Zero velocity in solid
│   │       ├── u-momentum: bound → discretize → source → residual → TDMA
│   │       ├── v-momentum: bound → discretize → source → residual → TDMA
│   │       ├── w-momentum: bound → discretize → source → residual → TDMA
│   │       └── pressure:   bound → discretize → source → residual → TDMA → revision
│   │
│   ├── [after iter_loop]
│   │   ├── species_bc()       ← [if species_flag=1]
│   │   └── solve_species()    ← [if species_flag=1] FVM + TDMA for concentration
│   │
│   ├── update_skipped()       ← Track local solver step counts
│   ├── update_max_temp()      ← Defect analysis accumulation
│   ├── outputres()            ← Print residuals to output.txt
│   ├── Cust_Out()             ← Write VTK (every outputintervel steps)
│   └── conc_old = concentration ← [if species_flag=1]
│
└── Post-simulation
    ├── compute_defect_determ()  ← Defect classification
    ├── write_defect_report()    ← Defect VTK + report
    ├── write_timing_report()    ← Performance breakdown
    └── write_memory_report()    ← Memory usage
```

## Numerical Method

| Aspect | Method |
|--------|--------|
| Spatial discretization | Finite Volume Method (FVM) on structured grid |
| Grid type | Staggered (velocities at faces, scalars at centers) |
| Convection scheme | Power Law (blends central and upwind) |
| Pressure-velocity coupling | SIMPLE algorithm |
| Linear solver | Line-by-line TDMA with block correction |
| Time integration | Implicit Euler (first-order) |
| Phase change | Enthalpy method with Darcy resistance in mushy zone |
| Parallelization | OpenMP (shared memory, per-thread TDMA buffers) |

## Module Dependency Graph

Compilation order reflects dependencies (each module depends only on modules compiled before it):

```
mod_precision       ← Foundation: working precision (single/double)
  └── mod_const     ← Physical constants, convergence thresholds
      └── mod_cfd_utils  ← Utility functions (harmonic mean, power law, etc.)
      └── mod_param      ← Input parsing, material properties
          └── mod_geom        ← Grid generation, geometric quantities
          └── mod_field_data  ← Velocity, pressure, enthalpy, temperature arrays
          └── mod_coeff_data  ← FVM coefficient arrays (an,as,ae,aw,at,ab,ap,su,sp)
          └── mod_sim_state   ← Global state (residuals, beam position, toolpath)
              └── mod_init         ← Initialization wrapper
              └── mod_laser        ← Laser beam positioning + heat distribution
              └── mod_dimen        ← Melt pool size detection
              └── mod_local_enthalpy ← Local/global solver scheduling
              └── mod_resid        ← Residual calculations
              └── mod_species      ← Species transport (dissimilar metals)
              └── mod_prop         ← Temperature/composition-dependent properties
              └── mod_bound        ← Boundary conditions (Marangoni, radiation)
              └── mod_discret      ← FVM discretization (momentum, enthalpy, pp)
              └── mod_entot        ← Enthalpy ↔ temperature conversion
              └── mod_sour         ← Source terms (laser, latent heat, Darcy, buoyancy)
              └── mod_flux         ← Energy balance verification
              └── mod_revise       ← Pressure-velocity correction
              └── mod_solve        ← TDMA solver + velocity cleanup
              └── mod_print        ← Output (text, VTK, thermal history)
              └── mod_converge     ← Block correction acceleration
              └── mod_toolpath     ← Toolpath file reading
              └── mod_timing       ← Performance reporting
              └── mod_defect       ← Defect detection and output
```

## Local Solver

The local solver is a key optimization. Instead of solving the full domain every time step, it alternates:

1. **Local steps** (`localnum` consecutive): Only solve enthalpy in a small region around the melt pool. Momentum is solved in the melt pool region regardless.
2. **Global step** (every `localnum+1`): Solve enthalpy on the full domain.

Skipped cells accumulate an effective time step: `delt_eff = delt * (n_skipped + 1)`, so when they are finally solved, the transient term correctly accounts for the elapsed time.

This typically provides **3-5x speedup** with minimal accuracy impact, since heat conduction far from the melt pool is slow and doesn't need frequent updates.
