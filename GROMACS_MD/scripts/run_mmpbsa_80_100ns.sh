#!/usr/bin/env bash
set -euo pipefail

START=80000
END=100000
DT=200

TPR="../md/md.tpr"
XTC="../analysis/trajectory/md_center.xtc"
NDX="../topology/index_mmpbsa.ndx"

echo "MM/PBSA trajectory preparation"
echo "Time window: 80-100 ns"
echo "Sampling interval: 200 ps"

gmx trjconv \
    -s "${TPR}" \
    -f "${XTC}" \
    -n "${NDX}" \
    -o md_80_100ns.xtc \
    -b "${START}" \
    -e "${END}" \
    -dt "${DT}"

echo "Trajectory extraction completed."
echo "Run g_mmpbsa using the exact CLI syntax validated for your installed version."
