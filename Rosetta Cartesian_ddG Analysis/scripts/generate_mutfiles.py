#!/usr/bin/env python3
"""Generate one Rosetta mutfile per independent mutation."""
from __future__ import annotations
import argparse
import csv
import shutil
from pathlib import Path

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--mutations", required=True, type=Path)
    p.add_argument("--output-dir", required=True, type=Path)
    args = p.parse_args()
    if args.output_dir.exists():
        shutil.rmtree(args.output_dir)
    args.output_dir.mkdir(parents=True)
    count = 0
    with args.mutations.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            wt, pos, mut = row["wild_type"], int(row["position"]), row["mutant"]
            name = f"{wt}{pos}{mut}"
            (args.output_dir/f"{name}.mut").write_text(
                f"total 1\n1\n{wt} {pos} {mut}\n", encoding="ascii"
            )
            count += 1
    print(f"Generated {count} independent mutfiles.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
