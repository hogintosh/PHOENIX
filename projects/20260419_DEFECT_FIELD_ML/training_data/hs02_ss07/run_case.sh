#!/bin/bash
# Run script for case hs02_ss07
set -e

CASE_DIR="/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/training_data/hs02_ss07"
PHOENIX_BIN="/home/eva/PHOENIX/fortran_new/cluster_main"

RUN_DIR="$CASE_DIR/run"
rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR/inputfile" "$RUN_DIR/result"

cp "$CASE_DIR/inputfile/input_param.txt" "$RUN_DIR/inputfile/"
ln -sf "$PHOENIX_BIN" "$RUN_DIR/cluster_main"

cd "$RUN_DIR"
OMP_NUM_THREADS=1 ./cluster_main > "$CASE_DIR/run.log" 2>&1

mkdir -p "$CASE_DIR/result"
cp -r result/. "$CASE_DIR/result/" 2>/dev/null || true

cd "$CASE_DIR"
rm -rf "$RUN_DIR"
echo "Done: hs02_ss07"
