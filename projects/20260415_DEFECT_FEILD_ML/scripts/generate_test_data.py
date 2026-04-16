"""
Generate 20 test case folders for defect field ML evaluation.

10 interpolation cases: (hs, ss) within training range but not on grid
10 extrapolation cases: (hs, ss) outside training range

Output:
  test_data/interp_XX/   — 10 in-range cases
  test_data/extrap_XX/   — 10 out-of-range cases
  test_data/test_summary.csv
  run_all_test.sh        — master parallel runner
"""

import sys
import os
import re
import numpy as np

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORTRAN_DIR = "/home/eva/PHOENIX/fortran_new"
PHOENIX_BIN = os.path.join(FORTRAN_DIR, "cluster_main")
BASE_INPUT  = os.path.join(FORTRAN_DIR, "inputfile", "input_param.txt")

sys.path.insert(0, PROJECT_DIR)
import toolpath_generator_rectangle as tpgen

TEST_DIR = os.path.join(PROJECT_DIR, "test_data")

# Training range
HS_MIN, HS_MAX = 50e-6, 150e-6
SS_MIN, SS_MAX = 0.8, 1.6

# Training grid points (to exclude from interpolation)
HATCH_GRID = np.linspace(HS_MIN, HS_MAX, 10)
SPEED_GRID  = np.linspace(SS_MIN, SS_MAX, 10)

FIXED_TP = dict(
    center_x=1e-3, center_y=1e-3, start_z=0.0006975,
    size_x=1e-3, size_y=1e-3,
    scan_axis="x", bidirectional=True,
    turnaround_time=0.0005, rotation_angle=45.0,
    domain_x=2e-3, domain_y=2e-3,
)

RNG = np.random.default_rng(seed=42)


def on_training_grid(hs, ss, tol=2e-7):
    """Return True if (hs, ss) is too close to a training grid point."""
    for hg in HATCH_GRID:
        for sg in SPEED_GRID:
            if abs(hs - hg) < tol and abs(ss - sg) < tol:
                return True
    return False


def sample_interp(n=10):
    """Sample n points within training range, off grid."""
    pts = []
    while len(pts) < n:
        hs = RNG.uniform(HS_MIN, HS_MAX)
        ss = RNG.uniform(SS_MIN, SS_MAX)
        if not on_training_grid(hs, ss):
            pts.append((hs, ss))
    return pts


def sample_extrap(n=10):
    """Sample n points outside training range."""
    # Extrap regions: hs outside [50,150]µm OR ss outside [0.8,1.6]
    extrap_regions = [
        # Low hatch + any speed
        (30e-6, 50e-6,  0.8, 1.6),
        # High hatch + any speed
        (150e-6, 200e-6, 0.8, 1.6),
        # In-range hatch + low speed
        (50e-6, 150e-6, 0.5, 0.8),
        # In-range hatch + high speed
        (50e-6, 150e-6, 1.6, 2.0),
    ]
    pts = []
    i = 0
    while len(pts) < n:
        region = extrap_regions[i % len(extrap_regions)]
        hs = RNG.uniform(region[0], region[1])
        ss = RNG.uniform(region[2], region[3])
        # Ensure actually outside training bounds
        if hs < HS_MIN or hs > HS_MAX or ss < SS_MIN or ss > SS_MAX:
            pts.append((hs, ss))
        i += 1
    return pts


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
    txt = re.sub(r"case_name='[^']*'",     f"case_name='{case_name}'",         txt)
    txt = re.sub(r"toolpath_file='[^']*'", f"toolpath_file='{toolpath_abs}'",  txt)
    txt = re.sub(r"timax=[\d.eE+-]+",      f"timax={timax:.6f}",               txt)
    txt = re.sub(r"mechanical_flag=\d+",   "mechanical_flag=0",                txt)
    txt = re.sub(r"species_flag=\d+",      "species_flag=0",                   txt)
    return txt


def make_run_script(case_dir, case_name):
    return f"""#!/bin/bash
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


def create_cases(pts, prefix, subdir):
    with open(BASE_INPUT) as f:
        base_txt = f.read()

    caselist = []
    rows = []

    for idx, (hs, ss) in enumerate(pts):
        case_name = f"{prefix}_{idx:02d}"
        case_dir  = os.path.join(TEST_DIR, case_name)
        os.makedirs(os.path.join(case_dir, "inputfile"), exist_ok=True)
        os.makedirs(os.path.join(case_dir, "result"),    exist_ok=True)

        crs_path = os.path.join(case_dir, "toolpath.crs")
        start_x = FIXED_TP["center_x"] - FIXED_TP["size_x"] / 2
        start_y = FIXED_TP["center_y"] - FIXED_TP["size_y"] / 2
        tpgen.generate_toolpath(
            start_x=start_x, start_y=start_y, start_z=FIXED_TP["start_z"],
            size_x=FIXED_TP["size_x"], size_y=FIXED_TP["size_y"],
            scan_axis=FIXED_TP["scan_axis"], bidirectional=FIXED_TP["bidirectional"],
            hatch_spacing=hs, scan_speed=ss,
            turnaround_time=FIXED_TP["turnaround_time"],
            output_filename=crs_path,
            rotation_angle=FIXED_TP["rotation_angle"],
            domain_x=FIXED_TP["domain_x"], domain_y=FIXED_TP["domain_y"],
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
        rows.append(f"{case_name},{hs:.6e},{ss:.6f},{timax:.6f}")
        print(f"  Created {case_name}  hs={hs*1e6:.2f}µm  ss={ss:.4f}m/s  timax={timax:.4f}s")

    return caselist, rows


def main():
    os.makedirs(TEST_DIR, exist_ok=True)

    print("Sampling interpolation points...")
    interp_pts = sample_interp(10)
    print("Sampling extrapolation points...")
    extrap_pts = sample_extrap(10)

    print("\nCreating interpolation cases:")
    interp_cases, interp_rows = create_cases(interp_pts, "interp", "interp")

    print("\nCreating extrapolation cases:")
    extrap_cases, extrap_rows = create_cases(extrap_pts, "extrap", "extrap")

    all_cases = interp_cases + extrap_cases
    all_rows = (
        ["case_name,hatch_spacing_m,scan_speed_m_s,timax_s,type"]
        + [r + ",interp" for r in interp_rows]
        + [r + ",extrap" for r in extrap_rows]
    )

    with open(os.path.join(TEST_DIR, "test_summary.csv"), "w") as f:
        f.write("\n".join(all_rows) + "\n")

    # Write run_all_test.sh
    run_all_path = os.path.join(PROJECT_DIR, "run_all_test.sh")
    with open(run_all_path, "w") as f:
        f.write(f"""#!/bin/bash
# Run all 20 test simulations in parallel (20 at a time, 1 OMP thread each)
set -e
echo "Launching {len(all_cases)} test cases..."
""")
        for case_name in all_cases:
            f.write(f'bash "{os.path.join(TEST_DIR, case_name, "run_case.sh")}" &\n')
        f.write("wait\necho 'All test simulations complete.'\n")
    os.chmod(run_all_path, 0o755)

    print(f"\nGenerated {len(all_cases)} test cases in {TEST_DIR}")
    print(f"  Interpolation: {len(interp_cases)}")
    print(f"  Extrapolation: {len(extrap_cases)}")
    print(f"Run with: bash {run_all_path}")


if __name__ == "__main__":
    main()
