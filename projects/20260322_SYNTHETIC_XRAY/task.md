# Task: In-Situ Synthetic Synchrotron X-ray Radiograph Generation

## Objective
Generate **synthetic X-ray transmission radiographs** directly from the CFD simulation, producing 2D images that are pixel-for-pixel comparable to real high-speed synchrotron X-ray imaging experiments (e.g., APS beamline 32-ID).

### Why This Has Never Been Done
AM CFD codes output 3D fields (T, v, p). Synchrotron experiments produce 2D transmission images. Comparing them requires a human to mentally project 3D simulation onto 2D and qualitatively say "it looks similar." Nobody has automated this by computing the actual Beer-Lambert projection from simulation density fields to produce synthetic radiographs.

### Why This Is Important
- **Direct quantitative simulation-experiment comparison**: Overlay synthetic and real X-ray images pixel-by-pixel. Compute correlation, SSIM, or contour matching metrics — replacing subjective visual comparison.
- **Virtual synchrotron experiments**: Test hypotheses before expensive beamtime. Predict what the X-ray image will look like for a given process condition.
- **Reveal what X-ray images actually measure**: A synchrotron image is a line integral of attenuation, not a cross-section. Synthetic radiographs expose what 3D physics features are visible (or hidden) in the 2D projection.
- **Training data for ML image analysis**: Paired synthetic radiographs + ground-truth 3D fields = labeled training data for neural networks that reconstruct 3D melt pool from 2D X-ray.
- **Extends to operando validation**: Time-resolved synthetic radiograph movies from simulation can be synchronized with experimental movies frame-by-frame.

### Direct Connection to PI's Research
Gan's group performs high-speed synchrotron X-ray imaging at APS to observe melt pool and keyhole dynamics in real-time. This module would close the loop: **simulation → synthetic X-ray → compare with experimental X-ray → validate/calibrate simulation**.

---

## Physics: X-ray Transmission

### Beer-Lambert Law
For a monochromatic X-ray beam passing through heterogeneous media:
```
I(x,z) = I_0 * exp( -∫ μ(y) dy )
```
where the integral is along the beam path (y-direction for side-view imaging).

### Attenuation coefficient
```
μ(x,y,z) = (μ/ρ)_material * ρ(x,y,z)
```
- `(μ/ρ)` = mass attenuation coefficient (cm²/g), depends on photon energy and atomic number
- `ρ(x,y,z)` = local density from simulation

### Density field from simulation
PHOENIX already has all the information:
- **Solid bulk**: `ρ = dens` (8440 kg/m³ for IN718)
- **Liquid**: `ρ = denl` (7640 kg/m³)
- **Mushy zone**: `ρ = dens + (denl - dens) * fracl`
- **Powder**: `ρ = pden` (4330 kg/m³, accounts for packing)
- **Keyhole / vapor cavity**: `ρ ≈ 0` where `T > T_boiling` and the cell would be vapor

### What appears in the image
The synthetic radiograph is `-ln(I/I_0)` = projected attenuation:
```
A(x,z) = (μ/ρ) * ∫ ρ(x,y,z) dy
```
This is simply a **density-weighted line integral along the beam direction**.

**Contrast sources** (same as real synchrotron images):
- Keyhole appears **bright** (low attenuation → vapor, ρ≈0)
- Melt pool boundary visible as **density contrast** (solid vs. liquid, ~10% difference)
- Porosity appears as **bright spots** (gas inclusions)
- Powder layer shows **reduced attenuation** (lower effective density)

### Imaging geometry
Standard synchrotron setup for AM:
- X-ray beam: horizontal, perpendicular to scan direction
- Image plane: x-z (along-scan × build-height)
- Projection along: y (transverse to scan)
- Pixel size: matches simulation grid (Δx × Δz)

---

## Design

### Computation
For each pixel (i,k) in the radiograph:
```fortran
attenuation(i,k) = 0
do j = 2, njm1
    rho_local = get_density(i,j,k)  ! from T, fracl, solidfield
    attenuation(i,k) = attenuation(i,k) + mu_over_rho * rho_local * dy(j)
enddo
radiograph(i,k) = exp(-attenuation(i,k))
```

This is an O(ni × nk × nj) computation — same order as one sweep of the TDMA solver. Negligible cost.

### Output
1. **2D radiograph images** at each VTK output interval:
   - Raw transmission `I/I_0` as 2D array
   - Written as VTK 2D structured grid (viewable in ParaView)
   - Also as raw binary for Python post-processing

2. **Radiograph movie**: Python script to assemble frames into a time-lapse video, mimicking real high-speed X-ray camera output.

3. **Beam direction**: Default y-axis (side view). Parameter to select x-axis (front view) for multi-angle imaging.

### Module: mod_xray.f90
- `init_xray()` — set up output, compute mass attenuation coefficient
- `compute_xray_radiograph()` — called at VTK output intervals, compute and write one frame
- `finalize_xray()` — generate Python plotting/movie script

### Input parameters
New namelist `&xray_params`:
```
&xray_params  xray_energy=24.0, beam_axis='y' /
```
- `xray_energy` (keV): X-ray photon energy → determines μ/ρ. Default 24 keV (typical for AM imaging at APS)
- `beam_axis`: 'y' (side view, default) or 'x' (front view)

`xray_flag` in `&output_control` (default 0).

### Mass attenuation coefficient
For common AM metals at typical synchrotron energies:
| Material | μ/ρ at 24 keV (cm²/g) | μ/ρ at 40 keV | μ/ρ at 65 keV |
|----------|----------------------|---------------|---------------|
| Ni (IN718) | 16.3 | 4.16 | 1.13 |
| Ti (Ti-6Al-4V) | 7.40 | 1.98 | 0.59 |
| Fe (316L SS) | 13.4 | 3.47 | 0.97 |
| Al (AlSi10Mg) | 1.18 | 0.40 | 0.19 |

Implement a lookup table or simple power-law fit: `μ/ρ ≈ C * E^(-2.8)` (photoelectric regime).

For the default case (IN718 at 24 keV): `μ/ρ = 16.3 cm²/g = 1.63e-3 m²/kg`

---

## Tasks

### Task 1 — Create mod_xray.f90

Core subroutines:
- `init_xray()`: read parameters, compute μ/ρ from energy, open output files
- `compute_xray_radiograph()`:
  - Build density field: ρ(i,j,k) from T, fracl, solidfield, T>T_boiling check
  - Perform line integral along beam_axis for each pixel
  - Normalize: I/I_0 = exp(-attenuation)
  - Write 2D VTK structured grid file
- `finalize_xray()`: generate Python movie script

### Task 2 — Density field construction

```fortran
if (temp(i,j,k) >= tboiling .and. fracl(i,j,k) > 0.5) then
    rho_local = 0.0  ! vapor cavity (keyhole)
else if (solidfield(i,j,k) <= 0.5 .and. k >= k_powder_lo) then
    rho_local = pden  ! powder (not yet melted)
else
    rho_local = dens + (denl - dens) * fracl(i,j,k)  ! solid/mushy/liquid
endif
```

The keyhole identification (`T > T_boiling` in liquid) is the key innovation — this is what makes the synthetic radiograph show the keyhole cavity.

### Task 3 — 2D VTK output

Write each frame as `<case>_xray_<frame>.vtk`:
- 2D structured grid (x-z plane for y-beam, y-z for x-beam)
- SCALARS: `transmission` (I/I_0, range 0-1), `attenuation` (-ln(I/I_0))
- Binary format, same VTK convention as existing output

### Task 4 — Input system integration

- Add `xray_flag`, `xray_energy`, `beam_axis` to mod_param.f90
- Add `&xray_params` namelist
- Integrate calls in main.f90 (at VTK output intervals, global steps only)

### Task 5 — Python movie script

Auto-generated script that:
- Reads all xray frames
- Plots as grayscale images (mimicking X-ray camera)
- Assembles into animated GIF or MP4
- Adds colorbar showing transmission/attenuation scale
- Overlays timestamp

### Task 6 — Validation

- Run simulation with keyhole-mode parameters (high power, slow speed)
- Verify keyhole appears as bright region in synthetic radiograph
- Verify melt pool boundary is visible as density contrast
- Verify powder layer shows reduced attenuation
- Compare qualitatively with published synchrotron images from Zhao et al. (Science, 2017) or Gan et al. (Nature Comms, 2021)

### Task 7 — Documentation

- Update docs with new capability and example images
- Document physics assumptions (monochromatic beam, no scattering, no refraction)

---

## Notes
- Zero additional arrays needed for the CFD solve — radiograph is computed on-the-fly during output
- CPU cost: one projection integral per output frame ≈ negligible
- The synthetic radiograph inherently includes ALL physics already in the simulation (Marangoni flow, phase change, species mixing, powder) — no additional modeling needed
- Limitation: no phase-contrast imaging (would need wave optics). Absorption contrast only.
- Future: add Fresnel propagation for phase-contrast simulation (used in some APS setups)
- Future: multi-angle projections → synthetic tomography → validate 3D reconstruction algorithms
- Future: compute synthetic diffraction patterns for HEDM (high-energy diffraction microscopy)
