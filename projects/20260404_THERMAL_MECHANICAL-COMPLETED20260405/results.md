# Thermal-Mechanical — Results

## Single-Track (single_track.crs)

- **Grid**: 200×200×52 thermal, 51×51×13 FEM (mech_mesh_ratio=4)
- **timax**: 0.002 s (100 thermal steps, 10 mechanical solves)
- **Threads**: 4

| Mech Step | Newton res | max von Mises (MPa) | Yield elements |
|-----------|-----------|---------------------|---------------|
| 1 | 3.06E-02 | 30.3 | 5 |
| 5 | 3.39E-02 | 49.4 | 4 |
| 10 | 2.55E-02 | 126.9 | 11 |

| Metric | Value |
|--------|-------|
| Mechanical CPU time | 2764 s (90% of total) |
| FEM memory | 24 MB |
| VTK files | 10 |

## Multi-Track Uniform Mesh (center_rot0.crs, 11 tracks)

- **Grid**: 200×200×52 thermal, 100×100×25 FEM (mech_mesh_ratio=2)
- **timax**: 0.015 s
- **Threads**: 4, adaptive_flag=0

| Mech Step | Newton res | max von Mises (MPa) | Yield elements |
|-----------|-----------|---------------------|---------------|
| 1 | 3.27E-02 | 27.1 | 4 |
| 25 | 3.46E-02 | 131.1 | 19 |
| 50 | 3.12E-02 | 133.3 | 48 |
| 75 | 1.70E-02 | 132.4 | 54 |

| Metric | Value |
|--------|-------|
| Total wall time | 1248 s (20.8 min) |
| Mechanical CPU | 1197 s (24.6% of total) |
| Thermal CPU | 3669 s (75.4% of total) |
| FEM memory | 24 MB |
| VTK files | 15 mech + 16 thermal |

### Observations

1. **Stress evolution**: von Mises stress grows from 27 MPa to ~132 MPa over 11 tracks, plateauing below the 250 MPa yield stress
2. **Yield elements**: growing from 4 to 54 as more material solidifies and accumulates thermal strain
3. **Newton convergence**: all 75 solves converged with relative residual ~0.02-0.03
4. **GIF visualization**: von Mises stress field with 10x deformation magnification, matplotlib+imageio rendering

## Multi-Track with AMR (center_rot0.crs, 11 tracks)

- **Grid**: 200×100 base thermal, 100×50×25 FEM (mech_mesh_ratio=2)
- **AMR**: adaptive_flag=1, amr_dx_fine=10um, remesh_interval=10

### AMR-Specific Issues Found and Fixed

1. **FEM mesh desync**: `init_mechanical` called once at startup, AMR changes x,y coordinates → FEM mesh stale. **Fix**: `update_mech_grid()` called after every AMR remesh.

2. **Boundary Ke mismatch** (also affects uniform mesh): last FEM element has dx/dy 1.5x larger than uniform due to forced boundary alignment. `ebe_matvec_mech` used precomputed Ke assuming uniform dx, but `compute_residual` used actual dx → CG operator inconsistent → 205 MPa spurious stress at corner node (Nnx,Nny,Nnz). **Fix**: detect `grid_uniform` flag; non-uniform path uses matrix-free matvec.

3. **NaN after AMR**: `eps_gp` computed with old B matrices, new B gives inconsistent `eps_inc` → stress explosion. **Fix**: recompute `eps_gp = B_new * u` after grid update.

4. **T_old_mech reset**: was set to current temperature after AMR, discarding thermal strain increment since last mech solve. Caused 3x displacement underestimate (5 um → 1.7 um). **Fix**: interpolate T_old_mech to new grid instead of resetting.

5. **Stress diffusion from bilinear interpolation**: each AMR cycle smoothed sig_gp peaks via bilinear interpolation. Earlier tracks (more AMR cycles) lost stress progressively. **Fix**: nearest-neighbor interpolation for all fields (sig_gp, ux/uy/uz, T_old_mech, f_plus).

6. **Displacement diffusion**: same bilinear smoothing issue for ux/uy/uz_mech. Caused ~20% displacement underestimate vs uniform mesh. **Fix**: nearest-neighbor interpolation.

### AMR vs Uniform Comparison

After all fixes, AMR results within ~5-10% of uniform mesh (inherent mesh resolution difference in coarser regions away from laser).

## Performance: Matrix-Free Matvec

For non-uniform grids (AMR), the matvec uses a matrix-free approach instead of assembling 24×24 Ke per element:
- **Old**: compute_Ke_uniform (~5600 mults/element) + Ke×u (576 mults) = ~6200 mults/element
- **New**: B^T(C(Bu)) per GP directly (~1056 mults/element) — **~5x faster**
- Exploits isotropic C structure (only λ, μ needed), precomputed shape function derivatives
- Uniform grid still uses precomputed per-layer Ke (unchanged speed)

## GIF Output

`finalize_mechanical_io` generates `plot_deformation.py` that creates:
- **GIF**: von Mises stress with 10x deformation magnification, jet colormap
- **PNG**: final frame at 200 DPI
- Uses pyvista (VTK reading) + matplotlib (rendering) + imageio (GIF encoding)
- No GPU/Xvfb required

## Bug Fixes Summary

| Bug | Symptom | Root Cause | Fix | Commit |
|-----|---------|-----------|-----|--------|
| Phase=0 after solidification | Substrate powder phase | FEM boundary index mapping | Fix index range | 7e140ce |
| Corner stress singularity | 205 MPa at (Nnx,Nny,Nnz) | Non-uniform last element + precomputed Ke | Per-element Ke for boundary | d712b25 |
| NaN with AMR | Stress explosion | eps_gp inconsistent after grid change | Recompute eps_gp from u | 4e54c3b |
| CG divergence with AMR | Non-convergence | ebe_matvec Ke assumes uniform dx | Matrix-free matvec | 3b15cc5 |
| Stress moves with mesh | Visual artifact | sig_gp not interpolated | Nearest-neighbor interp | 5efe51d |
| Displacement 3x low | 5→1.7 um | T_old_mech reset loses dT | Interpolate T_old_mech | 58e824a |
| Stress diffusion | Earlier tracks lose stress | Bilinear interp = low-pass filter | Nearest-neighbor for all | 5aba45d |
