#!/usr/bin/env python3
"""Select the lowest-total-score Cartesian Relax model."""
from __future__ import annotations
import argparse
import shutil
from pathlib import Path

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--scorefile", required=True, type=Path)
    p.add_argument("--model-dir", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    args = p.parse_args()

    header = None
    models: list[tuple[float,str]] = []
    for raw in args.scorefile.read_text(encoding="utf-8", errors="replace").splitlines():
        fields = raw.split()
        if not fields or fields[0] != "SCORE:":
            continue
        if len(fields) > 1 and fields[1] == "total_score":
            header = fields
            continue
        if header is None or len(fields) != len(header):
            continue
        row = dict(zip(header, fields))
        try:
            models.append((float(row["total_score"]), row["description"]))
        except (KeyError, ValueError):
            continue

    if not models:
        raise SystemExit("No valid Relax models found in score.sc")
    models.sort(key=lambda item: item[0])
    best_score, description = models[0]
    source = args.model_dir / f"{description}.pdb"
    if not source.is_file():
        candidates = list(args.model_dir.glob(f"{description}*.pdb"))
        if len(candidates) != 1:
            raise SystemExit(f"Could not identify PDB for {description!r}")
        source = candidates[0]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, args.output)
    print(f"Best model: {source.name}")
    print(f"Best total_score: {best_score:.6f}")
    print(f"Output: {args.output}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
