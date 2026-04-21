#!/bin/bash
# Run all 100 training simulations in parallel (4 at a time, 1 OMP thread each)
# Usage: bash run_all_training.sh
set -e

TRAINING_DIR="/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/training_data"
CASELIST="$TRAINING_DIR/caselist.txt"
N_PARALLEL=4

echo "Launching $(wc -l < "$CASELIST") cases, $N_PARALLEL in parallel..."
cat "$CASELIST" | xargs -P $N_PARALLEL -I {} bash "$TRAINING_DIR/{}/run_case.sh"
echo "All training simulations complete."
