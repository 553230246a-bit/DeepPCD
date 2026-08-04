from pathlib import Path
import subprocess
import sys


def write_gro(path: Path, title: str, atom_lines: list[str], box: str) -> None:
    path.write_text(
        "\n".join([title, str(len(atom_lines)), *atom_lines, box]) + "\n",
        encoding="utf-8",
    )


def test_merge_gro(tmp_path: Path):
    protein = tmp_path / "protein.gro"
    ligand = tmp_path / "ligand.gro"
    output = tmp_path / "complex.gro"

    protein_atoms = [
        "    1PROT    N    1   0.000   0.000   0.000",
        "    1PROT   CA    2   0.100   0.000   0.000",
    ]
    ligand_atoms = [
        "    2LIG    C1    1   0.200   0.000   0.000",
    ]

    write_gro(protein, "protein", protein_atoms, "1.0 1.0 1.0")
    write_gro(ligand, "ligand", ligand_atoms, "0.0 0.0 0.0")

    script = Path(__file__).resolve().parents[1] / "scripts" / "02_merge_gro.py"
    result = subprocess.run(
        [
            sys.executable,
            str(script),
            "--protein",
            str(protein),
            "--ligand",
            str(ligand),
            "--output",
            str(output),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    lines = output.read_text(encoding="utf-8").splitlines()
    assert int(lines[1].strip()) == 3
    assert lines[-1] == "1.0 1.0 1.0"
