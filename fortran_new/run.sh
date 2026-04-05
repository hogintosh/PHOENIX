#!/bin/bash
# PHOENIX Run Script
# Usage: bash run.sh <case_name> [thermal_threads] [mech_threads]
#   thermal_threads: OpenMP threads for thermal solver (default: 4)
#   mech_threads:    OpenMP threads for mechanical solver (default: 0 = serial in-loop)
#                    If >0, mechanical runs as a separate parallel process
#
# Examples:
#   bash run.sh baseline 4 &          # 4 thermal threads, serial mechanical
#   bash run.sh baseline 10 10 &      # 10 thermal + 10 mechanical (parallel)
set -e

CASE_NAME="${1:?Usage: bash run.sh <case_name> [thermal_threads] [mech_threads]}"
N_THERMAL="${2:-4}"
N_MECH="${3:-0}"

# Update case_name in input file
sed -i "s/case_name='[^']*'/case_name='$CASE_NAME'/" ./inputfile/input_param.txt

export PHOENIX_THERMAL_THREADS=$N_THERMAL
export PHOENIX_MECH_THREADS=$N_MECH

if [ "$N_MECH" -gt 0 ]; then
    echo "PHOENIX: thermal=$N_THERMAL threads, mechanical=$N_MECH threads (parallel)"

    # Launch mechanical process in background
    PHOENIX_RUN_MODE=mechanical OMP_NUM_THREADS=$N_MECH ./cluster_main &
    MECH_PID=$!

    # Launch thermal process (foreground)
    PHOENIX_RUN_MODE=thermal OMP_NUM_THREADS=$N_THERMAL ./cluster_main

    # Wait for mechanical to finish
    echo "Thermal complete. Waiting for mechanical (PID $MECH_PID)..."
    wait $MECH_PID
    echo "Mechanical complete. All done."
else
    echo "PHOENIX: $N_THERMAL threads (serial mechanical)"
    OMP_NUM_THREADS=$N_THERMAL ./cluster_main
fi
