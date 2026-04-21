"""
Rewrite run_case.sh for all cases missing a defect VTK.
New approach: run directly from the case directory (no isolated run/ subdir, no cp).
PHOENIX reads ./inputfile/input_param.txt and writes to ./result/<case_name>/.
"""
import os
import glob

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAINING_DIR = os.path.join(PROJECT_DIR, "training_data")
PHOENIX_BIN = "/home/eva/PHOENIX/fortran_new/cluster_main"

def has_defect_vtk(case):
    pattern = os.path.join(TRAINING_DIR, case, "result", case, f"{case}_defect.vtk")
    return os.path.exists(pattern)

with open(os.path.join(TRAINING_DIR, "caselist.txt")) as f:
    all_cases = [l.strip() for l in f if l.strip()]

missing = [c for c in all_cases if not has_defect_vtk(c)]
print(f"Missing defect VTKs: {len(missing)}")

rerun_list = os.path.join(PROJECT_DIR, "rerun_missing.txt")
with open(rerun_list, "w") as f:
    f.write("\n".join(missing) + "\n")

for case in missing:
    case_dir = os.path.join(TRAINING_DIR, case)
    run_sh = f"""#!/bin/bash
# Run {case} directly from case directory (no isolated run subdir)
set -e
CASE_DIR="{case_dir}"
PHOENIX_BIN="{PHOENIX_BIN}"
cd "$CASE_DIR"
rm -f ./cluster_main
ln -sf "$PHOENIX_BIN" ./cluster_main
OMP_NUM_THREADS=1 ./cluster_main > run.log 2>&1
rm -f ./cluster_main
echo "Done: {case}"
"""
    run_sh_path = os.path.join(case_dir, "run_case.sh")
    with open(run_sh_path, "w") as f:
        f.write(run_sh)
    os.chmod(run_sh_path, 0o755)
    print(f"  Updated {case}")

# Write the parallel re-run master script
rerun_sh = os.path.join(PROJECT_DIR, "run_missing.sh")
with open(rerun_sh, "w") as f:
    f.write(f"""#!/bin/bash
# Re-run {len(missing)} cases missing defect VTKs (4 parallel, direct-from-case-dir approach)
set -e
TRAINING_DIR="{TRAINING_DIR}"
N_PARALLEL=4
echo "Re-running {len(missing)} missing cases, $N_PARALLEL in parallel..."
cat "{rerun_list}" | xargs -P $N_PARALLEL -I {{}} bash "$TRAINING_DIR/{{}}/run_case.sh"
echo "All missing cases complete."
""")
os.chmod(rerun_sh, 0o755)
print(f"\nMissing cases list: {rerun_list}")
print(f"Run with: bash {rerun_sh}")
