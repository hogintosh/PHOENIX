#!/bin/bash
# Test cases for toolpath_generator_rectangle.py
# All cases use domain center (0.002, 0.002) as toolpath center, z=0.0006975m
# Varies size and rotation angle

set -e

OUTDIR="test_output"
mkdir -p "$OUTDIR"

# Common parameters
CX=0.002        # domain center x (m) — 4mm domain / 2
CY=0.002        # domain center y (m) — 4mm domain / 2
CZ=0.0006975    # top surface z (m)
SPEED=1.23
HATCH=0.0001
TURN=0.0005

echo "=== Toolpath generator test cases ==="
echo "Center: ($CX, $CY, $CZ) m"
echo ""

# Test A: 3x3 mm, 0 deg
echo "--- A: 3x3mm, rot=0 ---"
python3 toolpath_generator_rectangle.py \
  --center_x $CX --center_y $CY --center_z $CZ \
  --size_x 0.003 --size_y 0.003 \
  --scan_axis x --bidirectional \
  --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
  --rotation_angle 0 --output "$OUTDIR/A_3x3_rot0.crs"

# Test B: 3x3 mm, 45 deg
echo "--- B: 3x3mm, rot=45 ---"
python3 toolpath_generator_rectangle.py \
  --center_x $CX --center_y $CY --center_z $CZ \
  --size_x 0.003 --size_y 0.003 \
  --scan_axis x --bidirectional \
  --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
  --rotation_angle 45 --output "$OUTDIR/B_3x3_rot45.crs"

# Test C: 3x3 mm, 67 deg
echo "--- C: 3x3mm, rot=67 ---"
python3 toolpath_generator_rectangle.py \
  --center_x $CX --center_y $CY --center_z $CZ \
  --size_x 0.003 --size_y 0.003 \
  --scan_axis x --bidirectional \
  --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
  --rotation_angle 67 --output "$OUTDIR/C_3x3_rot67.crs"

# Test D: 2x3 mm, 0 deg
echo "--- D: 2x3mm, rot=0 ---"
python3 toolpath_generator_rectangle.py \
  --center_x $CX --center_y $CY --center_z $CZ \
  --size_x 0.002 --size_y 0.003 \
  --scan_axis x --bidirectional \
  --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
  --rotation_angle 0 --output "$OUTDIR/D_2x3_rot0.crs"

# Test E: 2x3 mm, 30 deg
echo "--- E: 2x3mm, rot=30 ---"
python3 toolpath_generator_rectangle.py \
  --center_x $CX --center_y $CY --center_z $CZ \
  --size_x 0.002 --size_y 0.003 \
  --scan_axis x --bidirectional \
  --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
  --rotation_angle 30 --output "$OUTDIR/E_2x3_rot30.crs"

# Test F: 3x1.5 mm, 0 deg
echo "--- F: 3x1.5mm, rot=0 ---"
python3 toolpath_generator_rectangle.py \
  --center_x $CX --center_y $CY --center_z $CZ \
  --size_x 0.003 --size_y 0.0015 \
  --scan_axis x --bidirectional \
  --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
  --rotation_angle 0 --output "$OUTDIR/F_3x1.5_rot0.crs"

# Test G: 3x1.5 mm, 90 deg
echo "--- G: 3x1.5mm, rot=90 ---"
python3 toolpath_generator_rectangle.py \
  --center_x $CX --center_y $CY --center_z $CZ \
  --size_x 0.003 --size_y 0.0015 \
  --scan_axis x --bidirectional \
  --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
  --rotation_angle 90 --output "$OUTDIR/G_3x1.5_rot90.crs"

# Test H: 1x1 mm, 0 deg (small patch)
echo "--- H: 1x1mm, rot=0 ---"
python3 toolpath_generator_rectangle.py \
  --center_x $CX --center_y $CY --center_z $CZ \
  --size_x 0.001 --size_y 0.001 \
  --scan_axis x --bidirectional \
  --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
  --rotation_angle 0 --output "$OUTDIR/H_1x1_rot0.crs"

echo ""
echo "=== All tests passed. Output in $OUTDIR/ ==="
