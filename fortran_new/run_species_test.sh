#!/bin/bash
# Species one-way coupling validation test
# Runs two cases: species_flag=0 (baseline) and species_flag=1 (species active)
# Compares output.txt, timing, and memory reports
set -e

echo "=== Species One-Way Coupling Validation ==="
echo ""

# Backup original input
cp inputfile/input_param.txt inputfile/input_param_original.txt

# --- Case 1: baseline (species_flag=0) ---
echo "--- Case 1: species_flag=0 (baseline) ---"
sed 's/PLACEHOLDER/sp_base/' inputfile/input_species_test.txt | \
  sed 's/species_flag=0/species_flag=0/' > inputfile/input_param.txt
OMP_NUM_THREADS=4 ./cluster_main
echo "Case 1 done."
echo ""

# --- Case 2: species_flag=1 ---
echo "--- Case 2: species_flag=1 (species active) ---"
sed 's/PLACEHOLDER/sp_test/' inputfile/input_species_test.txt | \
  sed 's/species_flag=0/species_flag=1/' > inputfile/input_param.txt
OMP_NUM_THREADS=4 ./cluster_main
echo "Case 2 done."
echo ""

# Restore original input
cp inputfile/input_param_original.txt inputfile/input_param.txt
rm inputfile/input_param_original.txt

# --- Compare results ---
echo "=== Comparing Results ==="
echo ""

echo "--- Timing Reports ---"
echo "Baseline:"
grep -E "Total CPU|Total wall|mod_species" result/sp_base/sp_base_timing_report.txt 2>/dev/null || echo "  (not found)"
echo ""
echo "Species:"
grep -E "Total CPU|Total wall|mod_species" result/sp_test/sp_test_timing_report.txt 2>/dev/null || echo "  (not found)"
echo ""

echo "--- Memory Reports ---"
echo "Baseline:"
grep -E "VmHWM|VmRSS" result/sp_base/sp_base_memory_report.txt 2>/dev/null || echo "  (not found)"
echo ""
echo "Species:"
grep -E "VmHWM|VmRSS" result/sp_test/sp_test_memory_report.txt 2>/dev/null || echo "  (not found)"
echo ""

echo "--- Output Comparison (last 5 lines of output.txt) ---"
echo "Baseline:"
tail -5 result/sp_base/output.txt 2>/dev/null || echo "  (not found)"
echo ""
echo "Species:"
tail -5 result/sp_test/output.txt 2>/dev/null || echo "  (not found)"
echo ""

echo "--- Species VTK files ---"
ls -la result/sp_test/sp_test_species*.vtk 2>/dev/null || echo "  No species VTK files found"
echo ""

echo "=== Validation Complete ==="
