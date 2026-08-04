#!/usr/bin/env python3
"""Parse completed Rosetta Cartesian_ddG output files.

Supported labels include WT, WT_, MUT, and MUT_*.
"""

from __future__ import annotations

import argparse
import csv
import re
import statistics
import sys
from pathlib import Path


PATTERN = re.compile(
    r"^\s*COMPLEX:\s*"
    r"Round\s*(\d+)\s*:\s*"
    r"(WT_?|MUT(?:_[^:]+)?)\s*:\s*"
    r"([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)"
)


def read_mutations(path: Path) -> list[str]:
    """Read mutations from a three-column TSV or whitespace table."""

    mutations: list[str] = []

    for line_number, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        fields = line.split()

        # Skip a possible header, for example:
        # wild_type    position    mutant
        if fields[0].lower() in {"wild_type", "wt", "original"}:
            continue

        if len(fields) != 3:
            raise ValueError(
                f"Invalid mutation-table line {line_number}: {raw_line!r}"
            )

        wild_type, position, mutant = fields

        try:
            int(position)
        except ValueError as exc:
            raise ValueError(
                f"Invalid residue number on line {line_number}: {position!r}"
            ) from exc

        mutations.append(f"{wild_type}{position}{mutant}")

    if not mutations:
        raise ValueError(f"No mutations were found in {path}")

    return mutations


def parse_one_ddg(
    ddg_file: Path,
    mutation: str,
    expected_iterations: int,
) -> list[dict[str, float]]:
    """Extract WT and mutant total scores from one Rosetta .ddg file."""

    scores: dict[int, dict[str, list[float]]] = {}

    for raw_line in ddg_file.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines():
        match = PATTERN.search(raw_line)
        if not match:
            continue

        round_number = int(match.group(1))
        label = match.group(2)
        total_score = float(match.group(3))

        score_type = "WT" if label.startswith("WT") else "MUT"

        scores.setdefault(
            round_number,
            {"WT": [], "MUT": []},
        )[score_type].append(total_score)

    expected_rounds = list(range(1, expected_iterations + 1))

    if sorted(scores) != expected_rounds:
        raise ValueError(
            f"{mutation}: expected rounds {expected_rounds}, "
            f"but detected rounds {sorted(scores)} in {ddg_file}"
        )

    parsed_rows: list[dict[str, float]] = []

    for round_number in expected_rounds:
        wt_values = scores[round_number]["WT"]
        mutant_values = scores[round_number]["MUT"]

        if not wt_values or not mutant_values:
            raise ValueError(
                f"{mutation}, round {round_number}: "
                f"WT scores={wt_values}; MUT scores={mutant_values}"
            )

        if len(wt_values) > 1 or len(mutant_values) > 1:
            print(
                f"WARNING: {mutation}, round {round_number} contains "
                f"{len(wt_values)} WT and {len(mutant_values)} MUT scores. "
                "The last score of each type will be used.",
                file=sys.stderr,
            )

        wt_score = wt_values[-1]
        mutant_score = mutant_values[-1]

        parsed_rows.append(
            {
                "iteration": round_number,
                "wt_score": wt_score,
                "mutant_score": mutant_score,
                "ddg_reu": mutant_score - wt_score,
            }
        )

    return parsed_rows


def write_csv(
    path: Path,
    fieldnames: list[str],
    rows: list[dict[str, object]],
) -> None:
    """Write UTF-8 CSV output that opens correctly in Excel."""

    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parse completed Rosetta Cartesian_ddG output files."
    )
    parser.add_argument(
        "--mutations",
        required=True,
        type=Path,
        help="Three-column mutation table, for example mutations.tsv.",
    )
    parser.add_argument(
        "--raw-dir",
        required=True,
        type=Path,
        help="Directory containing one subdirectory per mutation.",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        type=Path,
        help="Directory in which processed CSV files will be written.",
    )
    parser.add_argument(
        "--iterations",
        type=int,
        default=3,
        help="Expected Cartesian_ddG iterations per mutation.",
    )
    parser.add_argument(
        "--seed-base",
        type=int,
        default=408000,
        help="Base value used to record mutation-specific random seeds.",
    )

    args = parser.parse_args()

    if args.iterations < 1:
        print("ERROR: --iterations must be at least 1.", file=sys.stderr)
        return 2

    try:
        mutations = read_mutations(args.mutations)
        args.output_dir.mkdir(parents=True, exist_ok=True)

        long_rows: list[dict[str, object]] = []
        summary_rows: list[dict[str, object]] = []

        for mutation_index, mutation in enumerate(mutations, start=1):
            mutation_dir = args.raw_dir / mutation
            ddg_files = sorted(mutation_dir.glob("*.ddg"))

            if len(ddg_files) != 1:
                raise ValueError(
                    f"{mutation}: expected exactly one .ddg file in "
                    f"{mutation_dir}, but found {len(ddg_files)}."
                )

            ddg_file = ddg_files[0]

            parsed_rows = parse_one_ddg(
                ddg_file=ddg_file,
                mutation=mutation,
                expected_iterations=args.iterations,
            )

            wt_values = [row["wt_score"] for row in parsed_rows]
            mutant_values = [row["mutant_score"] for row in parsed_rows]
            ddg_values = [row["ddg_reu"] for row in parsed_rows]

            for row in parsed_rows:
                ddg_reu = row["ddg_reu"]

                long_rows.append(
                    {
                        "mutation": mutation,
                        "iteration": int(row["iteration"]),
                        "wt_total_score_reu": f"{row['wt_score']:.6f}",
                        "mutant_total_score_reu": f"{row['mutant_score']:.6f}",
                        "ddg_reu": f"{ddg_reu:.6f}",
                        "approx_ddg_kcal_mol": f"{ddg_reu / 2.94:.6f}",
                        "seed": args.seed_base + mutation_index,
                        "source_ddg_file": str(ddg_file),
                    }
                )

            mean_wt = statistics.fmean(wt_values)
            mean_mutant = statistics.fmean(mutant_values)
            mean_ddg = mean_mutant - mean_wt

            sd_ddg = (
                statistics.stdev(ddg_values)
                if len(ddg_values) > 1
                else 0.0
            )

            if mean_ddg < 0:
                interpretation = "predicted_stabilizing"
            elif mean_ddg > 0:
                interpretation = "predicted_destabilizing"
            else:
                interpretation = "no_predicted_change"

            summary_row: dict[str, object] = {
                "mutation": mutation,
                "n_iterations": len(ddg_values),
            }

            for index, value in enumerate(ddg_values, start=1):
                summary_row[f"iteration_{index}_ddg_reu"] = f"{value:.6f}"

            summary_row.update(
                {
                    "mean_wt_total_score_reu": f"{mean_wt:.6f}",
                    "mean_mutant_total_score_reu": f"{mean_mutant:.6f}",
                    "mean_ddg_reu": f"{mean_ddg:.6f}",
                    "sd_ddg_reu": f"{sd_ddg:.6f}",
                    "min_ddg_reu": f"{min(ddg_values):.6f}",
                    "max_ddg_reu": f"{max(ddg_values):.6f}",
                    "approx_mean_ddg_kcal_mol": f"{mean_ddg / 2.94:.6f}",
                    "approx_sd_ddg_kcal_mol": f"{sd_ddg / 2.94:.6f}",
                    "interpretation": interpretation,
                }
            )

            summary_rows.append(summary_row)

            print(
                f"[{mutation_index}/{len(mutations)}] "
                f"Parsed {mutation}: mean DDG = {mean_ddg:.6f} REU"
            )

        long_output = args.output_dir / "rosetta_cartesian_ddg_long.csv"
        summary_output = args.output_dir / "rosetta_cartesian_ddg_summary.csv"

        long_fields = [
            "mutation",
            "iteration",
            "wt_total_score_reu",
            "mutant_total_score_reu",
            "ddg_reu",
            "approx_ddg_kcal_mol",
            "seed",
            "source_ddg_file",
        ]

        summary_fields = [
            "mutation",
            "n_iterations",
            *[
                f"iteration_{index}_ddg_reu"
                for index in range(1, args.iterations + 1)
            ],
            "mean_wt_total_score_reu",
            "mean_mutant_total_score_reu",
            "mean_ddg_reu",
            "sd_ddg_reu",
            "min_ddg_reu",
            "max_ddg_reu",
            "approx_mean_ddg_kcal_mol",
            "approx_sd_ddg_kcal_mol",
            "interpretation",
        ]

        write_csv(long_output, long_fields, long_rows)
        write_csv(summary_output, summary_fields, summary_rows)

        print()
        print("Parsing completed successfully.")
        print(f"Mutations: {len(summary_rows)}")
        print(f"Detailed rows: {len(long_rows)}")
        print(f"Long-format output: {long_output}")
        print(f"Summary output: {summary_output}")

        return 0

    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
