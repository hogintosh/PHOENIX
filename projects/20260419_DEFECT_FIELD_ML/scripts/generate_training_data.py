"""
Generate 100 training case folders for defect field ML.

Hatch spacing: 10 uniform points in [50e-6, 150e-6] m
Scan speed:    10 uniform points in [0.8, 1.6] m/s
Total: 10 × 10 = 100 cases

Each case folder contains:
  toolpath.crs    — generated toolpath
  toolpath.png    — toolpath visualization
  inputfile/
    input_param.txt — per-case simulation input
  run_case.sh     — isolated run script

Also generates:
  run_all_training.sh  — master parallel runner (xargs -P 4)
  training_data/caselist.txt
  training_data/training_summary.csv
"""

import sys
import os
import re
import numpy as np

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORTRAN_DIR = "/home/eva/PHOENIX/fortran_new"
PHOENIX_BIN = os.path.join(FORTRAN_DIR, "cluster_main")
BASE_INPUT  = os.path.join(FORTRAN_DIR, "inputfile", "input_param.txt")
TOOLPATH_GEN = os.path.join(PROJECT_DIR, "toolpath_generator_rectangle.py")

sys.path.insert(0, PROJECT_DIR)
import toolpath_generator_rectangle as tpgen

TRAINING_DIR = os.path.join(PROJECT_DIR, "training_data")

HATCH_VALS  = np.linspace(50e-6, 150e-6, 10)
SPEED_VALS  = np.linspace(0.8, 1.6, 10)

FIXED_TP = dict(
    center_x=1e-3,
    center_y=1e-3,
    start_z=0.0006975,
    size_x=1e-3,
    size_y=1e-3,
    scan_axis="x",
    bidirectional=True,
    turnaround_time=0.0005,
    rotation_angle=45.0,
    domain_x=2e-3,
    domain_y=2e-3,
)


def get_toolpath_end_time(crs_path):
    t_last = 0.0
    with open(crs_path) as f:
        for line in f:
            parts = line.split()
            if parts:
                t = float(parts[0])
                if t > 0:
                    t_last = t
    return t_last


def make_input_param(base_txt, case_name, toolpath_abs, timax):
    txt = base_txt
    txt = re.sub(r"case_name='[^']*'", f"case_name='{case_name}'", txt)
    txt = re.sub(r"toolpath_file='[^']*'", f"toolpath_file='{toolpath_abs}'", txt)
    txt = re.sub(r"timax=[\d.eE+-]+", f"timax={timax:.6f}", txt)
    txt = re.sub(r"mechanical_flag=\d+", "mechanical_flag=0", txt)
    txt = re.sub(r"species_flag=\d+", "species_flag=0", txt)
    return txt


def make_run_script(case_dir, case_name):
    return f"""#!/bin/bash
# Run script for case {case_name}
set -e

CASE_DIR="{case_dir}"
PHOENIX_BIN="{PHOENIX_BIN}"

RUN_DIR="$CASE_DIR/run"
rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR/inputfile" "$RUN_DIR/result"

cp "$CASE_DIR/inputfile/input_param.txt" "$RUN_DIR/inputfile/"
ln -sf "$PHOENIX_BIN" "$RUN_DIR/cluster_main"

cd "$RUN_DIR"
OMP_NUM_THREADS=1 ./cluster_main > "$CASE_DIR/run.log" 2>&1

mkdir -p "$CASE_DIR/result"
cp result/* "$CASE_DIR/result/" 2>/dev/null || true

cd "$CASE_DIR"
rm -rf "$RUN_DIR"
echo "Done: {case_name}"
"""


def main():
    os.makedirs(TRAINING_DIR, exist_ok=True)

    with open(BASE_INPUT) as f:
        base_txt = f.read()

    caselist = []
    summary_rows = ["case_name,hatch_spacing_m,scan_speed_m_s,timax_s"]

    for i, hs in enumerate(HATCH_VALS):
        for j, ss in enumerate(SPEED_VALS):
            case_name = f"hs{i:02d}_ss{j:02d}"
            case_dir  = os.path.join(TRAINING_DIR, case_name)
            os.makedirs(os.path.join(case_dir, "inputfile"), exist_ok=True)
            os.makedirs(os.path.join(case_dir, "result"),    exist_ok=True)

            crs_path = os.path.join(case_dir, "toolpath.crs")
            start_x = FIXED_TP["center_x"] - FIXED_TP["size_x"] / 2
            start_y = FIXED_TP["center_y"] - FIXED_TP["size_y"] / 2
            tpgen.generate_toolpath(
                start_x=start_x,
                start_y=start_y,
                start_z=FIXED_TP["start_z"],
                size_x=FIXED_TP["size_x"],
                size_y=FIXED_TP["size_y"],
                scan_axis=FIXED_TP["scan_axis"],
                bidirectional=FIXED_TP["bidirectional"],
                hatch_spacing=hs,
                scan_speed=ss,
                turnaround_time=FIXED_TP["turnaround_time"],
                output_filename=crs_path,
                rotation_angle=FIXED_TP["rotation_angle"],
                domain_x=FIXED_TP["domain_x"],
                domain_y=FIXED_TP["domain_y"],
            )

            t_end = get_toolpath_end_time(crs_path)
            timax = t_end + 0.005

            inp_txt = make_input_param(base_txt, case_name, crs_path, timax)
            with open(os.path.join(case_dir, "inputfile", "input_param.txt"), "w") as f:
                f.write(inp_txt)

            run_sh_path = os.path.join(case_dir, "run_case.sh")
            with open(run_sh_path, "w") as f:
                f.write(make_run_script(case_dir, case_name))
            os.chmod(run_sh_path, 0o755)

            caselist.append(case_name)
            summary_rows.append(f"{case_name},{hs:.6e},{ss:.6f},{timax:.6f}")
            print(f"  Created {case_name}  hs={hs*1e6:.1f}µm  ss={ss:.3f}m/s  timax={timax:.4f}s")

    with open(os.path.join(TRAINING_DIR, "caselist.txt"), "w") as f:
        f.write("\n".join(caselist) + "\n")

    with open(os.path.join(TRAINING_DIR, "training_summary.csv"), "w") as f:
        f.write("\n".join(summary_rows) + "\n")

    run_all_path = os.path.join(PROJECT_DIR, "run_all_training.sh")
    with open(run_all_path, "w") as f:
        f.write(f"""#!/bin/bash
# Run all 100 training simulations in parallel (4 at a time, 1 OMP thread each)
# Usage: bash run_all_training.sh
set -e

TRAINING_DIR="{TRAINING_DIR}"
CASELIST="$TRAINING_DIR/caselist.txt"
N_PARALLEL=4

echo "Launching $(wc -l < "$CASELIST") cases, $N_PARALLEL in parallel..."
cat "$CASELIST" | xargs -P $N_PARALLEL -I {{}} bash "$TRAINING_DIR/{{}}/run_case.sh"
echo "All training simulations complete."
""")
    os.chmod(run_all_path, 0o755)

    print(f"\nGenerated {len(caselist)} cases in {TRAINING_DIR}")
    print(f"Master run script: {run_all_path}")
    print(f"  To run: bash {run_all_path}")


if __name__ == "__main__":
    main()
