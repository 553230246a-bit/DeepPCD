#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# 1. Basic configuration
###############################################################################

PROJECT="$HOME/rosetta_ddg_BhNIT"

INPUT_PDB="$PROJECT/input/BhNIT.pdb"
PREPARED_PDB="$PROJECT/input/BhNIT_A_renumbered.pdb"
BEST_RELAXED_PDB="$PROJECT/input/BhNIT_A_best_relaxed.pdb"

MUTATION_TABLE="$PROJECT/mutations.tsv"
MUTFILE_DIR="$PROJECT/mutfiles"

RELAX_DIR="$PROJECT/relax/models"
RESULTS_DIR="$PROJECT/results"
RAW_RESULT_DIR="$RESULTS_DIR/raw"
PROCESSED_RESULT_DIR="$RESULTS_DIR/processed"
LOG_DIR="$PROJECT/logs"

CART2_SCRIPT="$PROJECT/cart2.script"

RELAX_NSTRUCT=20
DDG_ITERATIONS=3
TARGET_CHAIN="A"

# Actual Rosetta installation detected from the user's environment.
ROSETTA_ROOT="${ROSETTAHOME:-/soft/rosetta.binary.ubuntu.release-408}"
ROSETTA_SOURCE="${ROSETTA3:-$ROSETTA_ROOT/main/source}"
ROSETTA_BIN="$ROSETTA_SOURCE/bin"
ROSETTA_DB="${ROSETTA3_DB:-$ROSETTA_ROOT/main/database}"

###############################################################################
# 2. Utility functions
###############################################################################

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

find_rosetta_executable() {
    local prefix="$1"
    local executable

    shopt -s nullglob

    for executable in "$ROSETTA_BIN"/"${prefix}"*.linuxgccrelease; do
        [[ "$executable" == *mpi* ]] && continue

        if [[ -x "$executable" ]]; then
            printf '%s\n' "$executable"
            shopt -u nullglob
            return 0
        fi
    done

    shopt -u nullglob
    return 1
}

###############################################################################
# 3. Locate Rosetta
###############################################################################

RELAX="$(find_rosetta_executable relax || true)"
CARTDDG="$(find_rosetta_executable cartesian_ddg || true)"

[[ -x "$RELAX" ]] || die "Rosetta relax executable was not found in $ROSETTA_BIN"
[[ -x "$CARTDDG" ]] || die "Rosetta cartesian_ddg executable was not found in $ROSETTA_BIN"
[[ -d "$ROSETTA_DB" ]] || die "Rosetta database was not found: $ROSETTA_DB"
[[ -f "$INPUT_PDB" ]] || die "Input PDB was not found: $INPUT_PDB"

mkdir -p \
    "$PROJECT/input" \
    "$PROJECT/scripts" \
    "$MUTFILE_DIR" \
    "$RELAX_DIR" \
    "$RAW_RESULT_DIR" \
    "$PROCESSED_RESULT_DIR" \
    "$LOG_DIR"

log "Rosetta relax: $RELAX"
log "Rosetta Cartesian_ddG: $CARTDDG"
log "Rosetta database: $ROSETTA_DB"
log "Input PDB: $INPUT_PDB"

###############################################################################
# 4. Define the 22 independent point mutations
###############################################################################

cat > "$MUTATION_TABLE" <<'EOF'
W 59 A
V 94 A
L 99 I
L 105 Y
G 121 D
T 136 G
W 168 G
P 173 E
L 196 Y
A 203 M
N 209 R
N 210 P
S 213 T
C 228 T
T 230 V
L 239 F
D 244 E
H 250 P
F 255 R
P 272 E
T 306 L
N 311 D
EOF

MUTATION_COUNT="$(grep -cv '^[[:space:]]*$' "$MUTATION_TABLE")"

[[ "$MUTATION_COUNT" -eq 22 ]] || \
    die "Expected 22 mutations, but found $MUTATION_COUNT."

log "Mutation table contains $MUTATION_COUNT independent substitutions."

###############################################################################
# 5. Extract chain A, retain standard amino acids, and renumber residues
###############################################################################

log "Preparing chain $TARGET_CHAIN and validating mutation positions."

python3 - \
    "$INPUT_PDB" \
    "$PREPARED_PDB" \
    "$MUTATION_TABLE" \
    "$TARGET_CHAIN" <<'PY'
from __future__ import annotations

import sys
from collections import OrderedDict
from pathlib import Path

input_pdb = Path(sys.argv[1])
output_pdb = Path(sys.argv[2])
mutation_table = Path(sys.argv[3])
target_chain = sys.argv[4]

aa3_to_aa1 = {
    "ALA": "A",
    "ARG": "R",
    "ASN": "N",
    "ASP": "D",
    "CYS": "C",
    "GLN": "Q",
    "GLU": "E",
    "GLY": "G",
    "HIS": "H",
    "ILE": "I",
    "LEU": "L",
    "LYS": "K",
    "MET": "M",
    "PHE": "F",
    "PRO": "P",
    "SER": "S",
    "THR": "T",
    "TRP": "W",
    "TYR": "Y",
    "VAL": "V",
}

mutations = []

for raw_line in mutation_table.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()

    if not line:
        continue

    fields = line.split()

    if len(fields) != 3:
        raise SystemExit(f"Invalid mutation-table line: {raw_line!r}")

    wt, position, mutant = fields
    mutations.append((wt, int(position), mutant))

input_lines = input_pdb.read_text(
    encoding="utf-8",
    errors="replace",
).splitlines(keepends=True)

residue_order = []
residue_to_pose = OrderedDict()
prepared_atom_lines = []

hetatm_count = 0
found_target_chain = False
inside_first_model = False
model_seen = False

for line in input_lines:
    if line.startswith("MODEL"):
        if model_seen:
            break

        model_seen = True
        inside_first_model = True
        continue

    if line.startswith("ENDMDL"):
        if inside_first_model:
            break
        continue

    if line.startswith("HETATM"):
        hetatm_count += 1
        continue

    if not line.startswith("ATOM  "):
        continue

    if len(line) < 27:
        continue

    chain = line[21].strip()

    if chain != target_chain:
        continue

    found_target_chain = True

    altloc = line[16]

    if altloc not in (" ", "A"):
        continue

    residue_name = line[17:20].strip()
    original_resseq = line[22:26].strip()
    insertion_code = line[26].strip()

    if residue_name not in aa3_to_aa1:
        raise SystemExit(
            f"Unsupported residue {residue_name!r} in chain {target_chain}. "
            "This protein-only workflow supports the 20 standard amino acids."
        )

    residue_key = (
        original_resseq,
        insertion_code,
        residue_name,
    )

    if residue_key not in residue_to_pose:
        pose_number = len(residue_order) + 1
        residue_to_pose[residue_key] = pose_number
        residue_order.append(residue_key)
    else:
        pose_number = residue_to_pose[residue_key]

    # Blank the alternate-location column, retain chain A, and renumber
    # residues sequentially from 1 so that mutfile positions match pose numbers.
    new_line = (
        line[:16]
        + " "
        + line[17:21]
        + target_chain
        + f"{pose_number:4d}"
        + " "
        + line[27:]
    )

    prepared_atom_lines.append(new_line)

if not found_target_chain:
    raise SystemExit(f"No ATOM records were found for chain {target_chain!r}.")

if not residue_order:
    raise SystemExit("No standard protein residues were extracted.")

sequence = [aa3_to_aa1[key[2]] for key in residue_order]

print(f"Extracted chain: {target_chain}")
print(f"Number of residues: {len(sequence)}")
print(f"Removed HETATM records: {hetatm_count}")
print()
print("Mutation-site validation:")
print(
    "Mutation\tPose_position\tOriginal_PDB_number\t"
    "Expected_WT\tObserved_WT\tStatus"
)

errors = []

for wt, position, mutant in mutations:
    if position < 1 or position > len(sequence):
        errors.append(
            f"{wt}{position}{mutant}: position is outside the extracted sequence."
        )
        continue

    observed = sequence[position - 1]
    original_number = residue_order[position - 1][0]
    status = "OK" if observed == wt else "MISMATCH"

    print(
        f"{wt}{position}{mutant}\t"
        f"{position}\t"
        f"{original_number}\t"
        f"{wt}\t"
        f"{observed}\t"
        f"{status}"
    )

    if observed != wt:
        errors.append(
            f"{wt}{position}{mutant}: expected {wt} at pose position "
            f"{position}, but observed {observed}."
        )

if errors:
    print("\nMutation validation failed:", file=sys.stderr)

    for error in errors:
        print(f"  - {error}", file=sys.stderr)

    raise SystemExit(
        "\nDo not start Rosetta until the residue-numbering mismatch is resolved."
    )

output_pdb.write_text(
    "".join(prepared_atom_lines) + "TER\nEND\n",
    encoding="utf-8",
)

print(f"\nPrepared PDB written to: {output_pdb}")
PY

[[ -s "$PREPARED_PDB" ]] || die "Prepared PDB was not generated."

###############################################################################
# 6. Generate the official Cartesian Relax script
###############################################################################

cat > "$CART2_SCRIPT" <<'EOF'
switch:cartesian
repeat 2
ramp_repack_min 0.02  0.01     1.0  50
ramp_repack_min 0.250 0.01     0.5  50
ramp_repack_min 0.550 0.01     0.0 100
ramp_repack_min 1     0.00001  0.0 200
accept_to_best
endrepeat
EOF

###############################################################################
# 7. Cartesian Relax: generate 20 structures and select the best one
###############################################################################

if [[ ! -s "$BEST_RELAXED_PDB" ]]; then
    log "Starting Cartesian Relax with $RELAX_NSTRUCT structures."

    rm -rf "$RELAX_DIR"
    mkdir -p "$RELAX_DIR"

    (
        cd "$RELAX_DIR"

        "$RELAX" \
            -database "$ROSETTA_DB" \
            -s "$PREPARED_PDB" \
            -use_input_sc \
            -ignore_unrecognized_res \
            -nstruct "$RELAX_NSTRUCT" \
            -score:weights ref2015_cart \
            -relax:min_type lbfgs_armijo_nonmonotone \
            -relax:script "$CART2_SCRIPT" \
            -fa_max_dis 9.0 \
            -run:constant_seed \
            -run:jran 4082026 \
            -out:file:scorefile score.sc \
            > "$LOG_DIR/cartesian_relax.log" 2>&1
    )

    [[ -s "$RELAX_DIR/score.sc" ]] || {
        tail -n 50 "$LOG_DIR/cartesian_relax.log" || true
        die "Cartesian Relax did not generate score.sc."
    }

    log "Selecting the lowest-total-score Relax model."

    python3 - \
        "$RELAX_DIR/score.sc" \
        "$RELAX_DIR" \
        "$BEST_RELAXED_PDB" <<'PY'
from __future__ import annotations

import shutil
import sys
from pathlib import Path

score_file = Path(sys.argv[1])
relax_directory = Path(sys.argv[2])
output_pdb = Path(sys.argv[3])

header = None
models = []

for raw_line in score_file.read_text(
    encoding="utf-8",
    errors="replace",
).splitlines():
    fields = raw_line.split()

    if not fields or fields[0] != "SCORE:":
        continue

    if len(fields) > 1 and fields[1] == "total_score":
        header = fields
        continue

    if header is None:
        continue

    if len(fields) != len(header):
        continue

    row = dict(zip(header, fields))

    try:
        total_score = float(row["total_score"])
        description = row["description"]
    except (KeyError, ValueError):
        continue

    models.append((total_score, description))

if not models:
    raise SystemExit("No valid Relax models were found in score.sc.")

models.sort(key=lambda item: item[0])
best_score, best_description = models[0]

source_pdb = relax_directory / f"{best_description}.pdb"

if not source_pdb.is_file():
    candidates = list(relax_directory.glob(f"{best_description}*.pdb"))

    if len(candidates) != 1:
        raise SystemExit(
            f"Could not identify the PDB for model {best_description!r}."
        )

    source_pdb = candidates[0]

shutil.copy2(source_pdb, output_pdb)

print(f"Best Relax model: {source_pdb.name}")
print(f"Best total_score: {best_score:.6f}")
print(f"Copied to: {output_pdb}")
PY
else
    log "Existing best Relax model found; Relax step will be reused."
fi

[[ -s "$BEST_RELAXED_PDB" ]] || die "Best Relax structure was not generated."

###############################################################################
# 8. Generate one mutfile for each independent point mutation
###############################################################################

rm -rf "$MUTFILE_DIR"
mkdir -p "$MUTFILE_DIR"

while read -r wild_type position mutant; do
    [[ -z "${wild_type:-}" ]] && continue

    mutation_name="${wild_type}${position}${mutant}"
    mutfile="$MUTFILE_DIR/${mutation_name}.mut"

    cat > "$mutfile" <<EOF
total 1
1
${wild_type} ${position} ${mutant}
EOF

done < "$MUTATION_TABLE"

GENERATED_MUTFILES="$(find "$MUTFILE_DIR" -maxdepth 1 -name '*.mut' | wc -l)"

[[ "$GENERATED_MUTFILES" -eq 22 ]] || \
    die "Expected 22 mutfiles, but generated $GENERATED_MUTFILES."

log "Generated 22 independent Rosetta mutfiles."

###############################################################################
# 9. Run Cartesian_ddG for all 22 mutations
###############################################################################

index=0

while read -r wild_type position mutant; do
    [[ -z "${wild_type:-}" ]] && continue

    index=$((index + 1))

    mutation_name="${wild_type}${position}${mutant}"
    mutfile="$MUTFILE_DIR/${mutation_name}.mut"
    mutation_output="$RAW_RESULT_DIR/${mutation_name}"
    seed=$((408000 + index))

    if [[ -f "$mutation_output/COMPLETE" ]]; then
        log "[$index/22] $mutation_name already completed; skipping."
        continue
    fi

    rm -rf "$mutation_output"
    mkdir -p "$mutation_output"

    log "[$index/22] Running $mutation_name with seed $seed."

    (
        cd "$mutation_output"

        "$CARTDDG" \
            -database "$ROSETTA_DB" \
            -s "$BEST_RELAXED_PDB" \
            -ddg::mut_file "$mutfile" \
            -ddg::iterations "$DDG_ITERATIONS" \
            -ddg::force_iterations true \
            -ddg::cartesian true \
            -ddg::dump_pdbs false \
            -ddg::bbnbrs 1 \
            -ddg::frag_nbrs 2 \
            -ddg::flex_bb false \
            -ddg::legacy false \
            -ddg::json false \
            -score:weights ref2015_cart \
            -fa_max_dis 9.0 \
            -ignore_zero_occupancy false \
            -missing_density_to_jump \
            -run:constant_seed \
            -run:jran "$seed" \
            > "${mutation_name}.log" 2>&1
    )

    ddg_file="$(find "$mutation_output" -maxdepth 1 -type f -name '*.ddg' | head -n 1 || true)"

    if [[ -z "$ddg_file" || ! -s "$ddg_file" ]]; then
        echo
        echo "Last 60 lines of $mutation_name log:"
        tail -n 60 "$mutation_output/${mutation_name}.log" || true
        die "Cartesian_ddG failed for $mutation_name."
    fi

    printf '%s\n' \
        "mutation=$mutation_name" \
        "seed=$seed" \
        "iterations=$DDG_ITERATIONS" \
        "ddg_file=$ddg_file" \
        > "$mutation_output/COMPLETE"

    log "[$index/22] Completed $mutation_name."

done < "$MUTATION_TABLE"

###############################################################################
# 10. Parse all Rosetta .ddg files and generate CSV tables
###############################################################################

log "Parsing all Cartesian_ddG output files."

python3 - \
    "$MUTATION_TABLE" \
    "$RAW_RESULT_DIR" \
    "$PROCESSED_RESULT_DIR" \
    "$DDG_ITERATIONS" <<'PY'
from __future__ import annotations

import csv
import re
import statistics
import sys
from pathlib import Path

mutation_table = Path(sys.argv[1])
raw_result_directory = Path(sys.argv[2])
processed_directory = Path(sys.argv[3])
expected_iterations = int(sys.argv[4])

processed_directory.mkdir(parents=True, exist_ok=True)

mutations = []

for raw_line in mutation_table.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()

    if not line:
        continue

    wild_type, position, mutant = line.split()
    mutations.append(f"{wild_type}{position}{mutant}")

pattern = re.compile(
    r"^COMPLEX:\s+Round(\d+):\s+"
    r"(WT|MUT_[^:]+):\s+([-+0-9.eE]+)"
)

long_rows = []
summary_rows = []

for mutation_index, mutation in enumerate(mutations, start=1):
    mutation_directory = raw_result_directory / mutation
    ddg_files = sorted(mutation_directory.glob("*.ddg"))

    if len(ddg_files) != 1:
        raise SystemExit(
            f"Expected one .ddg file for {mutation}, found {len(ddg_files)}."
        )

    ddg_file = ddg_files[0]
    round_scores = {}

    for line in ddg_file.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines():
        match = pattern.search(line)

        if not match:
            continue

        round_number = int(match.group(1))
        label = match.group(2)
        score = float(match.group(3))

        score_type = "WT" if label == "WT" else "MUT"
        round_scores.setdefault(round_number, {})[score_type] = score

    expected_rounds = list(range(1, expected_iterations + 1))

    if sorted(round_scores) != expected_rounds:
        raise SystemExit(
            f"{mutation}: expected rounds {expected_rounds}, "
            f"but found {sorted(round_scores)}."
        )

    round_ddgs = []

    for round_number in expected_rounds:
        scores = round_scores[round_number]

        if "WT" not in scores or "MUT" not in scores:
            raise SystemExit(
                f"{mutation}, round {round_number}: missing WT or MUT score."
            )

        wt_score = scores["WT"]
        mutant_score = scores["MUT"]
        ddg_reu = mutant_score - wt_score
        ddg_kcal_mol = ddg_reu / 2.94

        round_ddgs.append(ddg_reu)

        long_rows.append(
            {
                "mutation": mutation,
                "iteration": round_number,
                "wt_total_score_reu": f"{wt_score:.6f}",
                "mutant_total_score_reu": f"{mutant_score:.6f}",
                "ddg_reu": f"{ddg_reu:.6f}",
                "approx_ddg_kcal_mol": f"{ddg_kcal_mol:.6f}",
                "seed": 408000 + mutation_index,
                "source_ddg_file": str(ddg_file),
            }
        )

    mean_ddg_reu = statistics.fmean(round_ddgs)
    sd_ddg_reu = (
        statistics.stdev(round_ddgs)
        if len(round_ddgs) > 1
        else 0.0
    )

    mean_ddg_kcal_mol = mean_ddg_reu / 2.94
    sd_ddg_kcal_mol = sd_ddg_reu / 2.94

    if mean_ddg_reu < 0:
        interpretation = "predicted_stabilizing"
    elif mean_ddg_reu > 0:
        interpretation = "predicted_destabilizing"
    else:
        interpretation = "no_predicted_change"

    summary_rows.append(
        {
            "mutation": mutation,
            "n_iterations": len(round_ddgs),
            "iteration_1_ddg_reu": f"{round_ddgs[0]:.6f}",
            "iteration_2_ddg_reu": f"{round_ddgs[1]:.6f}",
            "iteration_3_ddg_reu": f"{round_ddgs[2]:.6f}",
            "mean_ddg_reu": f"{mean_ddg_reu:.6f}",
            "sd_ddg_reu": f"{sd_ddg_reu:.6f}",
            "min_ddg_reu": f"{min(round_ddgs):.6f}",
            "max_ddg_reu": f"{max(round_ddgs):.6f}",
            "approx_mean_ddg_kcal_mol": f"{mean_ddg_kcal_mol:.6f}",
            "approx_sd_ddg_kcal_mol": f"{sd_ddg_kcal_mol:.6f}",
            "interpretation": interpretation,
        }
    )

long_output = processed_directory / "rosetta_cartesian_ddg_long.csv"
summary_output = processed_directory / "rosetta_cartesian_ddg_summary.csv"

with long_output.open(
    "w",
    encoding="utf-8-sig",
    newline="",
) as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=[
            "mutation",
            "iteration",
            "wt_total_score_reu",
            "mutant_total_score_reu",
            "ddg_reu",
            "approx_ddg_kcal_mol",
            "seed",
            "source_ddg_file",
        ],
    )
    writer.writeheader()
    writer.writerows(long_rows)

with summary_output.open(
    "w",
    encoding="utf-8-sig",
    newline="",
) as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=[
            "mutation",
            "n_iterations",
            "iteration_1_ddg_reu",
            "iteration_2_ddg_reu",
            "iteration_3_ddg_reu",
            "mean_ddg_reu",
            "sd_ddg_reu",
            "min_ddg_reu",
            "max_ddg_reu",
            "approx_mean_ddg_kcal_mol",
            "approx_sd_ddg_kcal_mol",
            "interpretation",
        ],
    )
    writer.writeheader()
    writer.writerows(summary_rows)

print(f"Long-format results: {long_output}")
print(f"Summary results: {summary_output}")
print(f"Mutations summarized: {len(summary_rows)}")
PY

###############################################################################
# 11. Save reproducibility metadata
###############################################################################

METADATA_FILE="$PROCESSED_RESULT_DIR/software_and_run_metadata.txt"

{
    echo "Calculation date: $(date --iso-8601=seconds)"
    echo "Operating system:"
    uname -a
    echo
    echo "Rosetta root: $ROSETTA_ROOT"
    echo "Rosetta source: $ROSETTA_SOURCE"
    echo "Rosetta database: $ROSETTA_DB"
    echo "Relax executable: $RELAX"
    echo "Cartesian_ddG executable: $CARTDDG"
    echo
    echo "Target chain: $TARGET_CHAIN"
    echo "Number of mutations: $MUTATION_COUNT"
    echo "Cartesian Relax nstruct: $RELAX_NSTRUCT"
    echo "Cartesian_ddG iterations per mutation: $DDG_ITERATIONS"
    echo "Score function: ref2015_cart"
    echo "fa_max_dis: 9.0"
    echo "time-based seed: disabled"
    echo
    echo "Input PDB SHA256:"
    sha256sum "$INPUT_PDB"
    echo
    echo "Prepared PDB SHA256:"
    sha256sum "$PREPARED_PDB"
    echo
    echo "Best Relaxed PDB SHA256:"
    sha256sum "$BEST_RELAXED_PDB"
    echo
    echo "Mutation table SHA256:"
    sha256sum "$MUTATION_TABLE"
} > "$METADATA_FILE"

###############################################################################
# 12. Final checks
###############################################################################

SUMMARY_FILE="$PROCESSED_RESULT_DIR/rosetta_cartesian_ddg_summary.csv"
LONG_FILE="$PROCESSED_RESULT_DIR/rosetta_cartesian_ddg_long.csv"

[[ -s "$SUMMARY_FILE" ]] || die "Summary CSV was not generated."
[[ -s "$LONG_FILE" ]] || die "Long-format CSV was not generated."

SUMMARY_ROWS=$(( $(wc -l < "$SUMMARY_FILE") - 1 ))
LONG_ROWS=$(( $(wc -l < "$LONG_FILE") - 1 ))

[[ "$SUMMARY_ROWS" -eq 22 ]] || \
    die "Expected 22 summary rows, found $SUMMARY_ROWS."

[[ "$LONG_ROWS" -eq 66 ]] || \
    die "Expected 66 long-format rows, found $LONG_ROWS."

log "All 22 mutations completed successfully."
log "Summary: $SUMMARY_FILE"
log "Long-format results: $LONG_FILE"
log "Metadata: $METADATA_FILE"

echo
echo "============================================================"
echo "Rosetta Cartesian_ddG calculation completed"
echo "============================================================"
echo "Mutations:                 22"
echo "Iterations per mutation:   3"
echo "Total DDG iterations:      66"
echo
echo "Main result:"
echo "$SUMMARY_FILE"
echo
echo "Detailed result:"
echo "$LONG_FILE"
echo "============================================================"

