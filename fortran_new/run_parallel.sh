#!/bin/bash
# Run all toolpath test cases in parallel
# Each case gets its own working directory to avoid file conflicts
# Results are copied back to fortran_new/result/

set -e
cd "$(dirname "$0")"
BASEDIR=$(pwd)
OMP_THREADS=${1:-1}
TMPDIR="$BASEDIR/.parallel_tmp"
rm -rf "$TMPDIR"

# Case definitions: NAME SIZE_X SIZE_Y ROTATION (max 2x2mm)
CASES=(
  "A_2x2_rot0    0.002  0.002  0"
  "B_2x2_rot45   0.002  0.002  45"
  "C_2x2_rot67   0.002  0.002  67"
  "D_2x1_rot0    0.002  0.001  0"
  "E_2x1_rot30   0.002  0.001  30"
  "F_1.5x1_rot0  0.0015 0.001  0"
  "G_1.5x1_rot90 0.0015 0.001  90"
  "H_1x1_rot0    0.001  0.001  0"
)

# Common toolpath parameters (center of 4x4mm domain)
CX=0.002; CY=0.002; CZ=0.0006975
SPEED=1.23; HATCH=0.0001; TURN=0.0005

echo "=== Setting up ${#CASES[@]} parallel PHOENIX runs ($OMP_THREADS thread(s) each) ==="

PIDS=()
NAMES=()

for entry in "${CASES[@]}"; do
  NAME=$(echo $entry | awk '{print $1}')
  SX=$(echo $entry | awk '{print $2}')
  SY=$(echo $entry | awk '{print $3}')
  ROT=$(echo $entry | awk '{print $4}')

  RUNDIR="$TMPDIR/$NAME"
  mkdir -p "$RUNDIR/inputfile" "$RUNDIR/ToolFiles" "$RUNDIR/result"

  # Copy executable and input
  cp "$BASEDIR/cluster_main" "$RUNDIR/"
  cp "$BASEDIR/inputfile/input_param.txt.bak" "$RUNDIR/inputfile/input_param.txt"

  # Generate toolpath
  python3 "$BASEDIR/ToolFiles/toolpath_generator_rectangle.py" \
    --center_x $CX --center_y $CY --center_z $CZ \
    --size_x $SX --size_y $SY \
    --scan_axis x --bidirectional \
    --hatch_spacing $HATCH --scan_speed $SPEED --turnaround_time $TURN \
    --rotation_angle $ROT --output "$RUNDIR/ToolFiles/B26.crs"

  # Get timax from last line of .crs
  TIMAX=$(tail -1 "$RUNDIR/ToolFiles/B26.crs" | awk '{print $1}')

  # Update timax and case_name
  sed -i "s/timax=[0-9.eE+-]*/timax=$TIMAX/" "$RUNDIR/inputfile/input_param.txt"
  sed -i "s/case_name='[^']*'/case_name='$NAME'/" "$RUNDIR/inputfile/input_param.txt"

  # Launch simulation in background
  echo "  Launching $NAME (${SX}x${SY}m, rot=${ROT}deg, timax=${TIMAX}s)..."
  (
    cd "$RUNDIR"
    export OMP_NUM_THREADS=$OMP_THREADS
    ./cluster_main > "run.log" 2>&1
    # Copy results back to main result/ folder
    cp -r result/* "$BASEDIR/result/" 2>/dev/null || true
    echo "DONE: $NAME at $(date '+%H:%M:%S')"
  ) &
  PIDS+=($!)
  NAMES+=("$NAME")
done

echo ""
echo "=== All ${#CASES[@]} cases launched. Waiting... ==="
echo ""

# Wait and report
FAILED=0
for i in "${!PIDS[@]}"; do
  if wait ${PIDS[$i]}; then
    echo "  [OK] ${NAMES[$i]}"
  else
    echo "  [FAIL] ${NAMES[$i]}"
    FAILED=$((FAILED + 1))
  fi
done

# Clean up temp directories
rm -rf "$TMPDIR"

echo ""
if [ $FAILED -eq 0 ]; then
  echo "=== All ${#CASES[@]} simulations completed successfully ==="
else
  echo "=== $FAILED of ${#CASES[@]} simulations failed ==="
fi
