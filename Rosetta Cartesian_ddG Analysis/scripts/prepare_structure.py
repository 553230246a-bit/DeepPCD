#!/usr/bin/env python3
"""Prepare a protein-only PDB and validate mutation positions."""

from __future__ import annotations
import argparse
import csv
import sys
from collections import OrderedDict
from pathlib import Path

AA3_TO_AA1 = {
    "ALA":"A","ARG":"R","ASN":"N","ASP":"D","CYS":"C",
    "GLN":"Q","GLU":"E","GLY":"G","HIS":"H","ILE":"I",
    "LEU":"L","LYS":"K","MET":"M","PHE":"F","PRO":"P",
    "SER":"S","THR":"T","TRP":"W","TYR":"Y","VAL":"V",
}

def read_mutations(path: Path) -> list[tuple[str,int,str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        required = {"wild_type", "position", "mutant"}
        if set(reader.fieldnames or []) != required:
            raise ValueError(f"{path} must contain exactly: wild_type, position, mutant")
        return [(r["wild_type"], int(r["position"]), r["mutant"]) for r in reader]

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--mapping", required=True, type=Path)
    p.add_argument("--mutations", required=True, type=Path)
    p.add_argument("--chain", default="A")
    args = p.parse_args()

    mutations = read_mutations(args.mutations)
    lines = args.input.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    residue_order: list[tuple[str,str,str]] = []
    residue_to_pose: OrderedDict[tuple[str,str,str],int] = OrderedDict()
    output_lines: list[str] = []
    removed_hetatm = 0
    model_seen = False
    inside_first_model = False
    chain_found = False

    for line in lines:
        if line.startswith("MODEL"):
            if model_seen:
                break
            model_seen = True
            inside_first_model = True
            continue
        if line.startswith("ENDMDL") and inside_first_model:
            break
        if line.startswith("HETATM"):
            removed_hetatm += 1
            continue
        if not line.startswith("ATOM  ") or len(line) < 27:
            continue
        if line[21].strip() != args.chain:
            continue
        chain_found = True
        if line[16] not in (" ", "A"):
            continue
        resname = line[17:20].strip()
        if resname not in AA3_TO_AA1:
            raise ValueError(
                f"Unsupported residue {resname!r} in chain {args.chain}. "
                "This workflow supports the 20 standard amino acids only."
            )
        original_resseq = line[22:26].strip()
        insertion_code = line[26].strip()
        key = (original_resseq, insertion_code, resname)
        if key not in residue_to_pose:
            residue_to_pose[key] = len(residue_order) + 1
            residue_order.append(key)
        pose_number = residue_to_pose[key]
        new_line = line[:16] + " " + line[17:21] + args.chain + f"{pose_number:4d}" + " " + line[27:]
        output_lines.append(new_line)

    if not chain_found:
        raise ValueError(f"No ATOM records found for chain {args.chain}.")
    if not residue_order:
        raise ValueError("No standard protein residues were extracted.")

    sequence = [AA3_TO_AA1[key[2]] for key in residue_order]
    errors: list[str] = []
    print("Mutation-site validation:")
    print("Mutation\tPose_position\tOriginal_PDB_number\tExpected_WT\tObserved_WT\tStatus")
    for wt, position, mutant in mutations:
        name = f"{wt}{position}{mutant}"
        if position < 1 or position > len(sequence):
            errors.append(f"{name}: position outside prepared sequence")
            continue
        observed = sequence[position-1]
        original_number = residue_order[position-1][0]
        status = "OK" if observed == wt else "MISMATCH"
        print(f"{name}\t{position}\t{original_number}\t{wt}\t{observed}\t{status}")
        if observed != wt:
            errors.append(f"{name}: expected {wt}, observed {observed} at pose {position}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.mapping.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("".join(output_lines) + "TER\nEND\n", encoding="utf-8")

    with args.mapping.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["pose_position","original_pdb_number","insertion_code","residue_3letter","residue_1letter","chain"])
        for index, (resseq, icode, resname) in enumerate(residue_order, start=1):
            writer.writerow([index, resseq, icode, resname, AA3_TO_AA1[resname], args.chain])

    print(f"Prepared residues: {len(residue_order)}")
    print(f"Removed HETATM records: {removed_hetatm}")
    print(f"Prepared PDB: {args.output}")
    print(f"Residue mapping: {args.mapping}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
