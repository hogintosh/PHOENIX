# Species Transport Integration

## Objective

Create `mod_species.f90` in fortran_new based on `D:\Fortran\dissimilar\program931` to solve dissimilar metal species transport. The module must be as self-contained as possible (parameters, initialization, BCs, source terms, solver, output all inside `mod_species.f90`). Minimize changes to existing codebase. Only addition to existing input: `species_flag` (1=on, 0=off).

## Design Principles

- `mod_species.f90` is a standalone module: all secondary material properties, species arrays, solver, BCs, output defined within
- When `species_flag=0`, existing code behavior is unchanged — all property arrays remain constant or T-dependent as before
- When `species_flag=1`, `mod_species.f90` provides functions to update property arrays as composition-dependent
- Species transport active only in melt pool region (same as uvwp): when `T < tsolidmatrix(i,j,k)`, `massdiffusivity = 0`
- Concentration C: 1 = base material (from `&material_properties`), 0 = secondary material (from `mod_species.f90`)
- Species solver reuses global coefficient arrays (`an, as, ae, aw, at, ab, ap, su, sp`) — solve after momentum/enthalpy so coefficients are free
- Species is solved globally every timestep (not restricted to local solver region), using `delt` for transient term

## Key Physics Changes from Original (program931)

- Gamma = rho * D_m (D_m = 5e-9 m^2/s), replacing the old non-physical `massdiffl`. `massdiffusivity` array stores Gamma = rho * D_m (units: kg/(m*s)), used directly as diffusion coefficient in FVM discretization
- Remove velocity x2 factor
- Remove scanning source term (moving frame advection)
- Remove solidification segregation source (kp term)
- All BCs: zero-flux Neumann
- Add solutal Marangoni effect (dgdc based on local composition)
- `dgdt` and `hlatnt` remain scalars (assume both materials have similar values)

## Tasks (easy -> hard)

### Phase 1: Scaffolding

1. [ ] **Add `species_flag` to input parsing**
   - Add `species_flag` to `&output_control` namelist in `mod_init.f90`
   - Declare `species_flag` in `mod_sim_state.f90` (default = 0)
   - No behavior change yet

2. [ ] **Create `mod_species.f90` skeleton**
   - Module with all secondary material parameters as named constants:
     ```
     dens2=8880, viscos2=3.68e-3, tsolid2=1728, tliquid2=1730,
     tvap2=10000, hsmelt2=1.199e6, hlfriz2=1.255e6,
     acp2=515.0, acpb2=0.0, acpl2=595.0, thcons2=60.7, thconl2=120.0,
     beta2=4.5e-5, emiss2=0.0, dgdtp2=-2.23e-4, dgconst2=2.12
     ```
   - `D_m = 5.0e-9_wp` (molecular mass diffusivity, m^2/s)
   - `urfspecies = 0.7_wp` (dedicated relaxation factor)
   - `dgdc_const` (dg/dC, surface tension concentration coefficient — define value)
   - Allocatable arrays: `concentration(:,:,:)`, `conc_old(:,:,:)`, `massdiffusivity(:,:,:)`, `tsolidmatrix(:,:,:)`, `tliquidmatrix(:,:,:)`, `densmatrix(:,:,:)`
   - Empty subroutine stubs: `allocate_species`, `init_species`, `solve_species`, `species_bc`, `update_material_properties`, `update_massdiffusivity`, `write_species_vtk`
   - Compiles but does nothing yet

### Phase 2: Solver core

3. [ ] **Implement `allocate_species` and `init_species`**
   - Allocate all species arrays to (ni, nj, nk)
   - Initial conditions for single-track dissimilar test:
     - Substrate (z < powder layer top): C = 1 (base material)
     - Powder layer, y >= y_mid: C = 1 (base material)
     - Powder layer, y < y_mid: C = 0 (secondary material)
     - No smooth distance — sharp interface
   - Initialize `massdiffusivity = dens * D_m` where `T >= tsolid`, else 0
   - Initialize `tsolidmatrix`, `tliquidmatrix`, `densmatrix`, `hlatntmatrix` from initial C
   - Initialize `conc_old = concentration`

4. [ ] **Implement zero-flux BCs (`species_bc`)**
   - All 6 faces: `C(boundary) = C(interior neighbor)`
   - Called once per outer iteration, before species discretization

5. [ ] **Implement species solver (`solve_species`)**
   - Port FVM discretization from `program931/species_transport.f90`
   - Power Law scheme for convection-diffusion
   - Implicit Euler transient term: `acpnot = densmatrix(i,j,k) / delt * volume(i,j,k)`
   - Diffusion coefficient: use `massdiffusivity(i,j,k)` directly (already stores Gamma = rho * D_m)
   - **Fix: remove velocity x2 factor** — use raw velocities directly
   - **Remove: scanning source term** (no moving frame advection)
   - **Remove: solidification segregation** (no kp term)
   - Reuses global coefficient arrays (`an, as, ae, aw, at, ab, ap, su, sp`)
   - Line-by-line TDMA solver (same pattern as enthalpy)
   - Use `urfspecies` for under-relaxation
   - Concentration clipping [0, 1] after each TDMA sweep
   - Compute and return species residual (`resorc`)

6. [ ] **Wire into main loop**
   - In `main.f90`:
     - Startup: call `allocate_species` and `init_species` (when `species_flag=1`)
     - Inside `iter_loop` (each outer iteration): call `species_bc`, then `solve_species` — after enthalpy/momentum solves so global coefficient arrays are free
     - End of timestep: update `conc_old = concentration` (alongside `hnot`, `tnot`, `fraclnot`)
   - Add `resorc` to convergence output line
   - Add species solve time to timing report

### Phase 3: Material property coupling

7. [ ] **Implement `update_material_properties`**
   - When `species_flag=1`, update property arrays each timestep based on local C (linear mixing):
     - `tsolidmatrix(i,j,k) = tsolid*C + tsolid2*(1-C)`
     - `tliquidmatrix(i,j,k) = tliquid*C + tliquid2*(1-C)`
     - `densmatrix(i,j,k) = dens*C + dens2*(1-C)`
     - viscosity, cp (solid and liquid), thermal conductivity (solid and liquid), beta, emissivity
     - Note: `hlatnt` and `dgdt` remain scalars (assume similar values for both materials)
   - When `species_flag=0`, arrays keep existing constant/T-dependent values
   - **Call sequence in main loop**: `update_material_properties` -> `properties` (mod_prop.f90) -> momentum/enthalpy solves

8. [ ] **Modify `properties` (mod_prop.f90) to use composition-dependent values**
   - When `species_flag=1`, `properties` reads from species arrays (e.g., `densmatrix`, composition-weighted viscosity, cp, thermal conductivity)
   - When `species_flag=0`, behavior unchanged (scalar parameters as before)
   - Minimal changes: add `if (species_flag==1)` branches where needed

9. [ ] **Modify `enthalpy_to_temp` (mod_entot.f90) for composition-dependent phase change**
   - When `species_flag=1`, use cell-local values instead of scalars:
     - `tsolid` -> `tsolidmatrix(i,j,k)`
     - `tliquid` -> `tliquidmatrix(i,j,k)`
     - `deltemp` -> `tliquidmatrix(i,j,k) - tsolidmatrix(i,j,k)`
     - `hsmelt` -> computed from composition-dependent `acpa_local`, `acpb_local`, `tsolid_local`
     - `hlcal` -> computed from local `hsmelt`, `cpavg`, `deltemp`
     - `acpl` -> composition-weighted
   - `hlatnt` remains scalar (same for both materials)
   - This affects `fracl` and `temp` computation — critical for correctness
   - When `species_flag=0`, behavior unchanged

10. [ ] **Use composition-dependent solidus for diffusivity switch (`update_massdiffusivity`)**
    - `massdiffusivity(i,j,k) = dens_local * D_m` when `temp(i,j,k) >= tsolidmatrix(i,j,k)`, else 0
    - Called each iteration after `enthalpy_to_temp` updates temperature

12. [ ] **Use `densmatrix` in species convective fluxes**
    - Replace constant `dens` with `densmatrix(i,j,k)` in species FVM flux computation
    - Ensure mass conservation with variable density

### Phase 4: Output and Marangoni

13. [ ] **Implement `write_species_vtk`**
    - Write concentration field as standalone VTK file (same format as defect VTK)
    - ASCII header + binary data, structured grid
    - Called at same frequency as `Cust_Out` (every `outputintervel` steps)
    - Filename: `{case_name}_species{N}.vtk`
    - Also add concentration as a scalar in main VTK output (`Cust_Out`)

14. [ ] **Solutal Marangoni effect (dgdc)**
    - Define `dgdc` as a scalar constant in `mod_species.f90` (dg/dC, surface tension concentration coefficient)
    - Analogous to thermal Marangoni (`dgdt * dT/dx`), solutal Marangoni is `dgdc * dC/dx`
    - Total surface tension force: `tau = dgdt * grad(T) + dgdc * grad(C)`
    - `dgdt` remains scalar (same for both materials)
    - In `mod_bound.f90` `bound_uv`, after thermal Marangoni block, add:
      ```fortran
      if (species_flag == 1) then
          dcd = (concentration(i,j,nk) - concentration(i-1,j,nk)) * dxpwinv(i)  ! case 1
          term1 = fracl_stag * dgdc_const * dcd / (vis1 * dzpbinv(nk))
          uVel(i,j,nk) = uVel(i,j,nk) + term1
      endif
      ```
      Same pattern for case 2 (v-velocity, dC/dy)

### Phase 5: Testing

15. [ ] **Create single-track test toolpath**
    - Generate a simple single-track toolpath scanning along x-direction at y = half of domain
    - Use `toolpath_generator_rectangle.py` with 1 track (or write manually)
    - Purpose: test species transport with laser scanning across the material interface

16. [ ] **Validation run**
    - Run single-track test with `species_flag=1`
    - Verify: concentration stays in [0,1], mixing occurs only in melt pool, material properties update correctly, VTK output readable in ParaView
    - Compare melt pool shape with `species_flag=0` to verify minimal impact when C=1 everywhere

### Optional / Future

17. [ ] **`enhance_species_speed` block correction**
    - Port 1D block-correction from program931 for faster convergence
    - Not required for correctness, but improves convergence speed

## Design Notes

### Coefficient arrays
Species solver reuses global coefficient arrays (`an, as, ae, aw, at, ab, ap, su, sp` from `mod_coeff_data.f90`). Species must be solved after momentum/enthalpy in the iteration loop so the arrays are free to be overwritten.

### Local solver interaction
Species is always solved globally (full domain), not restricted to local solver region. This is simpler and species solve is cheap relative to enthalpy. Uses `delt` (not `delt_eff`) for the transient term.

### Diffusivity convention
`massdiffusivity(i,j,k)` stores Gamma = rho * D_m (units: kg/(m*s)). This is the FVM diffusion coefficient used directly in face conductance: `D_face = Gamma * A / dx`. Analogous to how `diff = k/cp` is the enthalpy diffusion coefficient.

## Reference

- Source implementation: `D:\Fortran\dissimilar\program931\species_transport.f90`
- Analysis of differences: see `species.md` in this folder
