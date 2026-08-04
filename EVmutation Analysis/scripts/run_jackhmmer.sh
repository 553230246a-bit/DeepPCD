#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/config.sh"
mkdir -p "$PROJECT_ROOT/alignment" "$PROJECT_ROOT/logs"
"$JACKHMMER_BIN" \
  --cpu "$JACKHMMER_CPU" \
  --seed "$JACKHMMER_SEED" \
  -N "$JACKHMMER_ITERATIONS" \
  -E "$JACKHMMER_EVALUE" \
  --incE "$JACKHMMER_INCLUSION_EVALUE" \
  --domE "$JACKHMMER_DOMAIN_EVALUE" \
  --incdomE "$JACKHMMER_DOMAIN_INCLUSION_EVALUE" \
  -A "$PROJECT_ROOT/alignment/BhNIT_raw.sto" \
  --tblout "$PROJECT_ROOT/alignment/BhNIT_hits.tbl" \
  --domtblout "$PROJECT_ROOT/alignment/BhNIT_domains.tbl" \
  "$TARGET_FASTA" "$UNIREF90_FASTA" \
  2>&1 | tee "$PROJECT_ROOT/logs/BhNIT_jackhmmer.log"
