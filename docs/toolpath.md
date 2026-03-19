# Toolpath

## File Format (`.crs`)

Toolpath files define the laser scanning pattern. Each line is a waypoint:

```
time        x           y           z           laser_flag
0.00000000  0.00050000  0.00200000  0.00069750  0
0.00600000  0.00350000  0.00200000  0.00069750  1
0.00700000  0.00400000  0.00200000  0.00069750  0
```

| Column | Unit | Description |
|--------|------|-------------|
| `time` | s | Absolute time of this waypoint |
| `x` | m | Beam x-position |
| `y` | m | Beam y-position |
| `z` | m | Beam z-position (typically top of powder layer) |
| `laser_flag` | - | 0 = laser off (repositioning), 1 = laser on (scanning) |

The solver interpolates linearly between waypoints to determine beam position and scan velocity at each time step.

**Conventions:**

- First line is always `0 0 0 0 0` (initial state)
- Second line moves the beam to the scan start position (laser off)
- Subsequent lines alternate between laser-on (scanning) and laser-off (repositioning) segments
- Scan speed is computed automatically from position change / time change between waypoints

## Toolpath Generator

A Python script generates rectangular scan patterns:

```bash
cd fortran_new/ToolFiles

python3 toolpath_generator_rectangle.py \
  --start_x 0.0005 --start_y 0.0005 --start_z 0.0006975 \
  --size_x 0.003 --size_y 0.003 \
  --scan_axis x --bidirectional \
  --hatch_spacing 0.0001 --scan_speed 1.23 \
  --turnaround_time 0.0005 --rotation_angle 0 \
  --output my_toolpath.crs
```

| Argument | Unit | Description |
|----------|------|-------------|
| `--start_x/y/z` | m | Starting corner of scan region |
| `--size_x/y` | m | Scan region dimensions |
| `--scan_axis` | - | Primary scan direction (`x` or `y`) |
| `--bidirectional` | - | Alternate scan direction each track |
| `--unidirectional` | - | Same scan direction each track |
| `--hatch_spacing` | m | Distance between adjacent tracks |
| `--scan_speed` | m/s | Laser scan speed |
| `--turnaround_time` | s | Delay between tracks (laser off) |
| `--rotation_angle` | deg | Rotate scan pattern |
| `--output` | - | Output filename |

Output: `.crs` file + `.png` visualization.

!!! note
    The `.png` visualization is only generated when using `toolpath_generator_rectangle.py`. Manually created `.crs` files do not have a `.png`.

## Manual Toolpath Creation

For simple patterns (single track, custom shapes), create the `.crs` file directly:

**Example: Single track at 0.5 m/s along x at y=2mm**

```
      0.00000000      0.00000000      0.00000000      0.00000000 0
      0.00000000      0.00050000      0.00200000      0.00069750 0
      0.00600000      0.00350000      0.00200000      0.00069750 1
      0.00700000      0.00400000      0.00200000      0.00069750 0
```

- Line 1: Initial state (origin)
- Line 2: Move to start (x=0.5mm, y=2mm, z=0.6975mm), laser off
- Line 3: Scan to x=3.5mm in 6ms (speed = 3mm/6ms = 0.5 m/s), laser on
- Line 4: Overshoot/cool-down, laser off

Set `toolpath_file` in `input_param.txt`:

```
&output_control ... toolpath_file='./ToolFiles/species_test.crs' /
```
