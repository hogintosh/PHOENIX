#!/bin/bash
set -e
echo "Re-running 44 cases, 4 in parallel (no vtkmov output)..."
cat "/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/rerun_missing.txt" | xargs -P 4 -I {} bash "/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/training_data/{}/run_case.sh"
echo "All missing cases complete."
