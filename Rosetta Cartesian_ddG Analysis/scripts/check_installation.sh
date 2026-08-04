#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_ROOT
CONFIG_FILE="$PROJECT_ROOT/config.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config.sh was not found."
    echo "Run: cp config.example.sh config.sh"
    exit 2
fi
source "$CONFIG_FILE"
ROSETTA_BIN="$ROSETTA3/bin"
find_executable() {
    local prefix="$1" item
    shopt -s nullglob
    for item in "$ROSETTA_BIN"/"${prefix}"*.linuxgccrelease; do
        [[ "$item" == *mpi* ]] && continue
        if [[ -x "$item" ]]; then printf '%s\n' "$item"; shopt -u nullglob; return 0; fi
    done
    shopt -u nullglob
    return 1
}
RELAX="$(find_executable relax || true)"
CARTDDG="$(find_executable cartesian_ddg || true)"
[[ -x "$RELAX" ]] && echo "relax: OK ($RELAX)" || echo "relax: NOT FOUND"
[[ -x "$CARTDDG" ]] && echo "cartesian_ddg: OK ($CARTDDG)" || echo "cartesian_ddg: NOT FOUND"
[[ -d "$ROSETTA3_DB" ]] && echo "Rosetta database: OK ($ROSETTA3_DB)" || echo "Rosetta database: NOT FOUND"
command -v python3 >/dev/null && echo "Python: OK ($(python3 --version))" || echo "Python: NOT FOUND"
[[ -f "$INPUT_PDB" ]] && echo "Input PDB: OK ($INPUT_PDB)" || echo "Input PDB: NOT FOUND"
[[ -x "$RELAX" && -x "$CARTDDG" && -d "$ROSETTA3_DB" && -f "$INPUT_PDB" ]] || exit 2
