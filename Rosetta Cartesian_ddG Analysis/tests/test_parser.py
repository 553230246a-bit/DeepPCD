from pathlib import Path
import csv
import subprocess
import sys

def test_parser(tmp_path: Path):
    mutations = tmp_path / "mutations.tsv"
    mutations.write_text(
        "wild_type\tposition\tmutant\nW\t59\tA\nV\t94\tA\n",
        encoding="utf-8",
    )
    raw = tmp_path / "raw"
    test_data = [
        ("W59A", [-10.0,-10.2,-10.1], [-11.0,-11.2,-11.1]),
        ("V94A", [-9.0,-9.1,-9.2], [-8.0,-8.1,-8.2]),
    ]
    for name, wt_values, mut_values in test_data:
        directory = raw / name
        directory.mkdir(parents=True)
        lines = []
        for i, (wt, mut) in enumerate(zip(wt_values, mut_values), start=1):
            lines.append(f"COMPLEX: Round{i}: WT: {wt}\n")
            lines.append(f"COMPLEX: Round{i}: MUT_{name}: {mut}\n")
        (directory / f"{name}.ddg").write_text("".join(lines), encoding="utf-8")
    output = tmp_path / "processed"
    script = Path(__file__).resolve().parents[1] / "scripts" / "parse_cartesian_ddg.py"
    completed = subprocess.run(
        [sys.executable, str(script), "--mutations", str(mutations),
         "--raw-dir", str(raw), "--output-dir", str(output),
         "--iterations", "3", "--seed-base", "408000"],
        capture_output=True, text=True, check=False,
    )
    assert completed.returncode == 0, completed.stderr
    with (output / "rosetta_cartesian_ddg_summary.csv").open(
        encoding="utf-8-sig", newline=""
    ) as handle:
        rows = list(csv.DictReader(handle))
    assert rows[0]["mutation"] == "W59A"
    assert rows[0]["mean_ddg_reu"] == "-1.000000"
    assert rows[0]["interpretation"] == "predicted_stabilizing"
    assert rows[1]["mutation"] == "V94A"
    assert rows[1]["mean_ddg_reu"] == "1.000000"
