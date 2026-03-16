#!/usr/bin/env python3
"""Task 8: Compare baseline vs localnum=4 after heat_fluxes/pool_size bounds optimization."""
import numpy as np
import os, re
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

PROJ = os.path.dirname(os.path.abspath(__file__))
RDIR = os.path.join(PROJ, '../../fortran_new/result')

POINT_NAMES = ["P1","P2","P3","P4","P5","P6","P7","P8","P9","P10"]
POINT_DESCS = [
    "(1.0,0.50,0.695) track1 start sfc",
    "(2.0,0.50,0.695) track1 centre sfc",
    "(3.0,0.50,0.695) track1 end sfc",
    "(1.0,0.50,0.655) track1 start -40um",
    "(2.0,0.50,0.655) track1 centre -40um",
    "(3.0,0.50,0.655) track1 end -40um",
    "(2.0,0.25,0.695) offset sfc",
    "(2.0,0.75,0.695) offset sfc",
    "(2.0,1.50,0.695) far-field sfc",
    "(2.0,0.50,0.200) deep substrate",
]

def load_thermal(fname):
    data = np.loadtxt(fname, comments="#")
    if data.ndim == 1:
        data = data[np.newaxis, :]
    return data

def extract_timing(fname):
    with open(fname) as f:
        text = f.read()
    info = {}
    m = re.search(r'Total CPU time:\s+([\d.]+)\s+s', text)
    if m: info['cpu'] = float(m.group(1))
    m = re.search(r'Total wall time:\s+([\d.]+)\s+s', text)
    if m: info['wall'] = float(m.group(1))
    m = re.search(r'Total iterations \(itertot\):\s+(\d+)', text)
    if m: info['itertot'] = int(m.group(1))
    # Extract module times
    for line in text.split('\n'):
        m2 = re.match(r'\s+([\w/() -]+)\|\s+([\d.]+)\s+\|\s+([\d.]+)%', line)
        if m2:
            name = m2.group(1).strip()
            time_s = float(m2.group(2))
            info[name] = time_s
    # Extract local/global step info
    m = re.search(r'Local\s+steps\s+([\d.]+)\s+s\s+\|\s+(\d+)\s+steps', text)
    if m: info['local_wall'] = float(m.group(1)); info['local_steps'] = int(m.group(2))
    m = re.search(r'Global steps\s+([\d.]+)\s+s\s+\|\s+(\d+)\s+steps', text)
    if m: info['global_wall'] = float(m.group(1)); info['global_steps'] = int(m.group(2))
    return info

def compute_metrics(base, loc):
    n = min(len(base), len(loc))
    base = base[:n]; loc = loc[:n]
    metrics = []
    for p in range(10):
        T_base = base[:, p + 1]; T_loc = loc[:, p + 1]
        diff = T_loc - T_base
        max_abs = np.max(np.abs(diff))
        T_peak_base = np.max(T_base)
        max_rel = max_abs / T_peak_base * 100.0 if T_peak_base > 0 else 0.0
        rel_rmsd = np.sqrt(np.mean((diff / T_base) ** 2)) * 100.0
        peak_diff = abs(np.max(T_loc) - T_peak_base)
        metrics.append({'max_abs': max_abs, 'max_rel': max_rel, 'rel_rmsd': rel_rmsd, 'peak_diff': peak_diff})
    return metrics

def main():
    base_th = load_thermal(os.path.join(RDIR, 'task8_baseline/task8_baseline_thermal_history.txt'))
    loc_th  = load_thermal(os.path.join(RDIR, 'task8_local4/task8_local4_thermal_history.txt'))
    base_ti = extract_timing(os.path.join(RDIR, 'task8_baseline/task8_baseline_timing_report.txt'))
    loc_ti  = extract_timing(os.path.join(RDIR, 'task8_local4/task8_local4_timing_report.txt'))

    metrics = compute_metrics(base_th, loc_th)

    # --- Report ---
    lines = []
    lines.append("=" * 90)
    lines.append("  Task 8: Baseline vs localnum=4 (with heat_fluxes skip + pool_size bounds)")
    lines.append("=" * 90)
    lines.append("")

    # Accuracy table
    lines.append("  Accuracy Comparison")
    lines.append("  " + "-" * 75)
    lines.append(f"  {'Point':<6} | {'MaxAbsDiff(K)':>13} | {'MaxRelDiff(%)':>13} | {'RelRMSD(%)':>10} | {'PeakTDiff(K)':>12}")
    lines.append("  " + "-" * 75)
    max_rel_all = 0; max_rmsd_all = 0
    for p in range(10):
        m = metrics[p]
        max_rel_all = max(max_rel_all, m['max_rel'])
        max_rmsd_all = max(max_rmsd_all, m['rel_rmsd'])
        lines.append(f"  {POINT_NAMES[p]:<6} | {m['max_abs']:13.3f} | {m['max_rel']:13.4f} | {m['rel_rmsd']:10.4f} | {m['peak_diff']:12.3f}")
    lines.append("  " + "-" * 75)
    pass_rel = max_rel_all < 5.0
    pass_rmsd = max_rmsd_all < 3.0
    lines.append(f"  Max MaxRelDiff: {max_rel_all:.4f}% {'PASS' if pass_rel else 'FAIL'} (<5%)")
    lines.append(f"  Max RelRMSD:    {max_rmsd_all:.4f}% {'PASS' if pass_rmsd else 'FAIL'} (<3%)")
    lines.append(f"  Overall: {'PASS' if pass_rel and pass_rmsd else 'FAIL'}")
    lines.append("")

    # Timing comparison
    lines.append("  Timing Comparison")
    lines.append("  " + "-" * 75)
    cpu_sp = base_ti['cpu'] / loc_ti['cpu']
    wall_sp = base_ti['wall'] / loc_ti['wall']
    lines.append(f"  Baseline CPU:  {base_ti['cpu']:.1f}s   Wall: {base_ti['wall']:.1f}s   Iters: {base_ti['itertot']}")
    lines.append(f"  Local4   CPU:  {loc_ti['cpu']:.1f}s   Wall: {loc_ti['wall']:.1f}s   Iters: {loc_ti['itertot']}")
    lines.append(f"  CPU speedup:  {cpu_sp:.2f}x")
    lines.append(f"  Wall speedup: {wall_sp:.2f}x")
    lines.append("")

    # Per-step analysis
    base_gs = base_ti.get('global_steps', 500)
    loc_ls = loc_ti.get('local_steps', 0); loc_gs = loc_ti.get('global_steps', 0)
    loc_lw = loc_ti.get('local_wall', 0); loc_gw = loc_ti.get('global_wall', 0)
    base_gw = base_ti.get('global_wall', 0)
    lines.append("  Per-step wall time")
    lines.append("  " + "-" * 75)
    if base_gs > 0:
        lines.append(f"  Baseline global: {base_gw/base_gs:.2f} s/step ({base_gs} steps)")
    if loc_gs > 0:
        lines.append(f"  Local4   global: {loc_gw/loc_gs:.2f} s/step ({loc_gs} steps)")
    if loc_ls > 0:
        lines.append(f"  Local4   local:  {loc_lw/loc_ls:.2f} s/step ({loc_ls} steps)")
    lines.append("")

    # Module comparison
    lines.append("  Module CPU time comparison")
    lines.append("  " + "-" * 75)
    lines.append(f"  {'Module':<22} | {'Baseline(s)':>11} | {'Local4(s)':>10} | {'Change':>8}")
    lines.append("  " + "-" * 75)
    modules_to_compare = ['mod_discret', 'mod_sour', 'mod_solve', 'mod_dimen', 'mod_flux',
                          'mod_converge', 'mod_resid', 'mod_prop', 'mod_entot', 'mod_bound',
                          'other (copy/misc)']
    for mod in modules_to_compare:
        bt = base_ti.get(mod, 0); lt = loc_ti.get(mod, 0)
        if bt > 0:
            change = (lt - bt) / bt * 100
            lines.append(f"  {mod:<22} | {bt:11.1f} | {lt:10.1f} | {change:+7.1f}%")
    lines.append("")

    report = "\n".join(lines)
    out_path = os.path.join(PROJ, "task8_report.txt")
    with open(out_path, "w") as f:
        f.write(report)
    print(report)

    # --- Thermal history comparison plot ---
    n = min(len(base_th), len(loc_th))
    base_th = base_th[:n]; loc_th = loc_th[:n]
    time_ms = base_th[:, 0] * 1000

    fig, axes = plt.subplots(2, 5, figsize=(22, 9))
    axes = axes.flatten()
    for p in range(10):
        ax = axes[p]
        ax.plot(time_ms, base_th[:, p+1], '-', color='black', linewidth=1.5, label='Baseline')
        ax.plot(time_ms, loc_th[:, p+1], '--', color='red', linewidth=1.0, alpha=0.8, label='localnum=4')
        ax.set_title(f'{POINT_NAMES[p]} {POINT_DESCS[p]}', fontsize=7)
        ax.set_xlabel('Time (ms)', fontsize=7)
        ax.set_ylabel('T (K)', fontsize=7)
        ax.tick_params(labelsize=6)
        ax.legend(fontsize=6)
        ax.grid(True, alpha=0.3)
    fig.suptitle('Task 8: Thermal History — Baseline (solid) vs localnum=4 (dashed)', fontsize=12)
    plt.tight_layout(rect=[0, 0, 1, 0.95])
    png_path = os.path.join(PROJ, "task8_thermal_comparison.png")
    fig.savefig(png_path, dpi=150)
    plt.close(fig)
    print(f"\nPlot saved: {png_path}")

if __name__ == "__main__":
    main()
