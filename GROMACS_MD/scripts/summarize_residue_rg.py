from pathlib import Path
import re
import numpy as np

INPUT_DIR = Path(r".\analysis\residue_Rg")
OUTPUT_XVG = INPUT_DIR / "selected_residue_rg_mean_sd.xvg"

def load_xvg(path: Path) -> np.ndarray:
    rows = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith(("#", "@", "&")):
                continue
            try:
                rows.append([float(value) for value in line.split()])
            except ValueError:
                continue
    if not rows:
        raise ValueError(f"No numerical data found in {path}")
    return np.asarray(rows, dtype=float)

def residue_number(path: Path) -> int:
    match = re.search(r"Residue_(\d+)_Rg", path.stem)
    if not match:
        raise ValueError(f"Cannot identify residue number from {path.name}")
    return int(match.group(1))

def main():
    files = sorted(INPUT_DIR.glob("Residue_*_Rg.xvg"), key=residue_number)
    if not files:
        raise FileNotFoundError(
            f"No Residue_*_Rg.xvg files found in {INPUT_DIR.resolve()}"
        )

    statistics = []

    print(
        f"{'Residue':<18}"
        f"{'Mean Rg (nm)':>15}"
        f"{'SD (nm)':>12}"
        f"{'Min (nm)':>12}"
        f"{'Max (nm)':>12}"
        f"{'Frames':>10}"
    )

    for path in files:
        data = load_xvg(path)
        rg = data[:, 1]
        resid = residue_number(path)

        result = {
            "residue": resid,
            "mean": float(np.mean(rg)),
            "sd": float(np.std(rg, ddof=1)),
            "min": float(np.min(rg)),
            "max": float(np.max(rg)),
            "frames": int(len(rg)),
        }
        statistics.append(result)

        print(
            f"{'Residue_' + str(resid) + '_Rg':<18}"
            f"{result['mean']:>15.6f}"
            f"{result['sd']:>12.6f}"
            f"{result['min']:>12.6f}"
            f"{result['max']:>12.6f}"
            f"{result['frames']:>10d}"
        )

    lines = [
        "# Per-residue radius of gyration",
        "# Column 1: residue number",
        "# Column 2: mean Rg (nm)",
        "# Column 3: standard deviation (nm)",
        '@    title "Per-residue radius of gyration"',
        '@    xaxis label "Residue number"',
        '@    yaxis label "Rg (nm)"',
        '@    type xydy',
    ]

    for item in statistics:
        lines.append(
            f"{item['residue']:8d} "
            f"{item['mean']:14.8f} "
            f"{item['sd']:14.8f}"
        )

    OUTPUT_XVG.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\nXVG created: {OUTPUT_XVG}")

if __name__ == "__main__":
    main()
