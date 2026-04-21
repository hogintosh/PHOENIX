#!/bin/bash
set -e
N_PARALLEL=4
echo "Re-running 7 empty-VTK cases..."
cat "/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/rerun_empty.txt" | xargs -P $N_PARALLEL -I {} bash "/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/training_data/{}/run_case.sh"
echo "Done."
