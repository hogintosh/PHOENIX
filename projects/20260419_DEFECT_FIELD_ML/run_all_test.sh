#!/bin/bash
# Run all 20 test simulations in parallel (4 at a time, 1 OMP thread each)
set -e
echo "Launching 20 test cases, 4 in parallel..."
printf '%s\n' interp_00 interp_01 interp_02 interp_03 interp_04 interp_05 interp_06 interp_07 interp_08 interp_09 extrap_00 extrap_01 extrap_02 extrap_03 extrap_04 extrap_05 extrap_06 extrap_07 extrap_08 extrap_09 | xargs -P 4 -I {} bash "/home/eva/PHOENIX/projects/20260419_DEFECT_FIELD_ML/test_data/{}/run_case.sh"
echo "All test simulations complete."
