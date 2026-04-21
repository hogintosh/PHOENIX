#!/bin/bash
set -e
CASE_DIR="/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/training_data/hs05_ss03"
PHOENIX_BIN="/home/eva/PHOENIX/fortran_new/cluster_main"
cd "$CASE_DIR"
rm -f ./cluster_main
ln -sf "$PHOENIX_BIN" ./cluster_main
OMP_NUM_THREADS=1 ./cluster_main > run.log 2>&1
rm -f ./cluster_main
echo "Done: hs05_ss03"
