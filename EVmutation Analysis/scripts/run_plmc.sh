#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/config.sh"
mkdir -p "$PROJECT_ROOT/model" "$PROJECT_ROOT/logs"
"$PLMC_BIN" \
  -o "$PROJECT_ROOT/model/BhNIT.model" \
  -c "$PROJECT_ROOT/model/BhNIT_couplings.txt" \
  --save-weights "$PROJECT_ROOT/model/BhNIT_sequence_weights.txt" \
  -f "$TARGET_ID" \
  -g \
  -t "$PLMC_THETA" \
  -le "$PLMC_LAMBDA_E" \
  -lh "$PLMC_LAMBDA_H" \
  -m "$PLMC_MAX_ITERATIONS" \
  -n "$PLMC_CORES" \
  "$PROJECT_ROOT/alignment/BhNIT_focus.a2m" \
  2>&1 | tee "$PROJECT_ROOT/logs/BhNIT_plmc.log"
test -s "$PROJECT_ROOT/model/BhNIT.model" || { echo 'ERROR: model was not generated.' >&2; exit 2; }
