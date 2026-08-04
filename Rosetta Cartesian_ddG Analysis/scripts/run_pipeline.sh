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
MUTATIONS="$PROJECT_ROOT/mutations.tsv"
CART2_SCRIPT="$PROJECT_ROOT/cart2.script"
PREPARED_PDB="$PROJECT_ROOT/input/processed/BhNIT_A_renumbered.pdb"
BEST_PDB="$PROJECT_ROOT/input/processed/BhNIT_A_best_relaxed.pdb"
MAPPING="$PROJECT_ROOT/results/processed/residue_mapping.tsv"
RELAX_DIR="$PROJECT_ROOT/relax/models"
MUTFILE_DIR="$PROJECT_ROOT/mutfiles"
RAW_DIR="$PROJECT_ROOT/results/raw"
PROCESSED_DIR="$PROJECT_ROOT/results/processed"
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/input/processed" "$RELAX_DIR" "$MUTFILE_DIR" "$RAW_DIR" "$PROCESSED_DIR" "$LOG_DIR"
log(){ printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die(){ echo "ERROR: $*" >&2; exit 2; }
find_executable(){
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
[[ -x "$RELAX" ]] || die "relax executable not found in $ROSETTA_BIN"
[[ -x "$CARTDDG" ]] || die "cartesian_ddg executable not found in $ROSETTA_BIN"
[[ -d "$ROSETTA3_DB" ]] || die "Rosetta database not found: $ROSETTA3_DB"
[[ -f "$INPUT_PDB" ]] || die "Input PDB not found: $INPUT_PDB"

log "Preparing and validating the input structure."
python3 "$SCRIPT_DIR/prepare_structure.py" \
    --input "$INPUT_PDB" \
    --output "$PREPARED_PDB" \
    --mapping "$MAPPING" \
    --mutations "$MUTATIONS" \
    --chain "$TARGET_CHAIN"

if [[ "${FORCE_RELAX:-0}" == "1" ]]; then
    rm -rf "$RELAX_DIR"; mkdir -p "$RELAX_DIR"; rm -f "$BEST_PDB"
fi

if [[ ! -s "$BEST_PDB" ]]; then
    log "Running Cartesian Relax with $RELAX_NSTRUCT structures."
    rm -rf "$RELAX_DIR"; mkdir -p "$RELAX_DIR"
    (
        cd "$RELAX_DIR"
        "$RELAX" \
            -database "$ROSETTA3_DB" \
            -s "$PREPARED_PDB" \
            -use_input_sc \
            -ignore_unrecognized_res \
            -nstruct "$RELAX_NSTRUCT" \
            -score:weights ref2015_cart \
            -relax:min_type lbfgs_armijo_nonmonotone \
            -relax:script "$CART2_SCRIPT" \
            -fa_max_dis 9.0 \
            -run:constant_seed \
            -run:jran "$RELAX_SEED" \
            -out:file:scorefile score.sc \
            > "$LOG_DIR/cartesian_relax.log" 2>&1
    )
    [[ -s "$RELAX_DIR/score.sc" ]] || { tail -n 80 "$LOG_DIR/cartesian_relax.log" || true; die "Cartesian Relax did not generate score.sc"; }
    python3 "$SCRIPT_DIR/select_best_relax.py" --scorefile "$RELAX_DIR/score.sc" --model-dir "$RELAX_DIR" --output "$BEST_PDB"
else
    log "Reusing existing best relaxed model: $BEST_PDB"
fi

python3 "$SCRIPT_DIR/generate_mutfiles.py" --mutations "$MUTATIONS" --output-dir "$MUTFILE_DIR"
mapfile -t MUTATION_LINES < <(tail -n +2 "$MUTATIONS" | tr '\t' ' ')
mutation_count="${#MUTATION_LINES[@]}"
[[ "$mutation_count" -eq 22 ]] || die "Expected 22 mutations, found $mutation_count"

for index in "${!MUTATION_LINES[@]}"; do
    read -r wt position mutant <<< "${MUTATION_LINES[$index]}"
    number=$((index + 1))
    name="${wt}${position}${mutant}"
    seed=$((DDG_SEED_BASE + number))
    output_dir="$RAW_DIR/$name"
    mutfile="$MUTFILE_DIR/$name.mut"
    if [[ "${FORCE_DDG:-0}" != "1" && -f "$output_dir/COMPLETE" ]]; then
        log "[$number/22] Reusing completed mutation $name."
        continue
    fi
    rm -rf "$output_dir"; mkdir -p "$output_dir"
    log "[$number/22] Running $name with seed $seed."
    (
        cd "$output_dir"
        "$CARTDDG" \
            -database "$ROSETTA3_DB" \
            -s "$BEST_PDB" \
            -ddg::mut_file "$mutfile" \
            -ddg::iterations "$DDG_ITERATIONS" \
            -ddg::force_iterations true \
            -ddg::cartesian true \
            -ddg::dump_pdbs false \
            -ddg::bbnbrs 1 \
            -ddg::frag_nbrs 2 \
            -ddg::flex_bb false \
            -ddg::legacy false \
            -score:weights ref2015_cart \
            -fa_max_dis 9.0 \
            -ignore_zero_occupancy false \
            -missing_density_to_jump \
            -run:constant_seed \
            -run:jran "$seed" \
            > "$name.log" 2>&1
    )
    ddg_file="$(find "$output_dir" -maxdepth 1 -type f -name '*.ddg' | head -n 1 || true)"
    if [[ -z "$ddg_file" || ! -s "$ddg_file" ]]; then
        tail -n 80 "$output_dir/$name.log" || true
        die "Cartesian_ddG failed for $name"
    fi
    {
        echo "mutation=$name"
        echo "seed=$seed"
        echo "iterations=$DDG_ITERATIONS"
        echo "ddg_file=$ddg_file"
    } > "$output_dir/COMPLETE"
done

python3 "$SCRIPT_DIR/parse_cartesian_ddg.py" \
    --mutations "$MUTATIONS" \
    --raw-dir "$RAW_DIR" \
    --output-dir "$PROCESSED_DIR" \
    --iterations "$DDG_ITERATIONS" \
    --seed-base "$DDG_SEED_BASE"

metadata="$PROCESSED_DIR/software_and_run_metadata.txt"
{
    echo "Calculation date: $(date --iso-8601=seconds)"
    echo "Operating system:"; uname -a; echo
    echo "Rosetta source: $ROSETTA3"
    echo "Rosetta database: $ROSETTA3_DB"
    echo "Relax executable: $RELAX"
    echo "Cartesian_ddG executable: $CARTDDG"
    echo "Target chain: $TARGET_CHAIN"
    echo "Relax nstruct: $RELAX_NSTRUCT"
    echo "DDG iterations: $DDG_ITERATIONS"
    echo "Relax seed: $RELAX_SEED"
    echo "DDG seed base: $DDG_SEED_BASE"
    echo "Score function: ref2015_cart"
    echo "fa_max_dis: 9.0"
    echo
    echo "Input PDB SHA256:"; sha256sum "$INPUT_PDB"
    echo "Prepared PDB SHA256:"; sha256sum "$PREPARED_PDB"
    echo "Best relaxed PDB SHA256:"; sha256sum "$BEST_PDB"
    echo "Mutation table SHA256:"; sha256sum "$MUTATIONS"
} > "$metadata"
summary="$PROCESSED_DIR/rosetta_cartesian_ddg_summary.csv"
long="$PROCESSED_DIR/rosetta_cartesian_ddg_long.csv"
summary_rows=$(( $(wc -l < "$summary") - 1 ))
long_rows=$(( $(wc -l < "$long") - 1 ))
[[ "$summary_rows" -eq 22 ]] || die "Expected 22 summary rows, found $summary_rows"
[[ "$long_rows" -eq $((22 * DDG_ITERATIONS)) ]] || die "Unexpected long-format row count: $long_rows"
log "Pipeline completed successfully."
log "Summary: $summary"
log "Detailed output: $long"
log "Metadata: $metadata"
