#!/bin/bash
set -e
cd "/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/test_data/interp_03"
rm -f ./cluster_main
ln -sf "/home/eva/PHOENIX/fortran_new/cluster_main" ./cluster_main
OMP_NUM_THREADS=1 ./cluster_main > run.log 2>&1
rm -f ./cluster_main
echo "Done: interp_03"
