# Species Transport — Task Tracking

Current status of species transport implementation. See `projects/20260312_SPECIES/task.md` for full details.

## Completed

- [x] **Phase 0**: Infrastructure — memory report, compile script improvements
- [x] **Phase 1**: Scaffolding — `species_flag` input, `mod_species.f90` creation
- [x] **Phase 2**: Solver core — FVM discretization, TDMA, block correction, boundary conditions, wiring into main loop
- [x] **Milestone**: One-way coupling validated — concentration field correct, <1% overhead
- [x] **Phase 3**: Two-way coupling — composition-dependent properties in `mod_prop`, `mod_entot`, `mod_sour`, `mod_solve`, `main`
- [x] **Phase 4**: Solutal Marangoni — `dgdc_const = -0.3 N/m` in `mod_bound`
- [x] **Phase 5**: Two-way coupling validated — correct mixing, +16% property coupling overhead

## Key Design Decisions

- **Inline computation** (not per-cell arrays): all composition mixing computed on-the-fly via `mix()`. Zero memory overhead, ~16% CPU overhead from extra multiplications in hot loops.
- **Melt pool region only**: species solver uses same indices as momentum (`istatp1:iendm1, jstat:jend, kstat:nkm1`). Overhead <1%.
- **Shared coefficient arrays**: species reuses `an, as, ae, aw, at, ab, ap, su, sp, apnot` — solved after iteration loop when arrays are free.
- **Scalar simplifications**: `hlatnt`, `dgdt`, `beta`, `emiss` remain scalars (assume similar values for both materials).
