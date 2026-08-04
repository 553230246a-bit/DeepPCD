#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/config.sh"
source "$EVCOUPLINGS_VENV/bin/activate"
OUT="$PROJECT_ROOT/results/processed/software_and_run_metadata.txt"
{
  echo 'BhNIT EVmutation Reproducibility Metadata'
  echo '========================================'
  echo
  echo "Generated: $(date --iso-8601=seconds)"
  echo "OS: $(grep PRETTY_NAME /etc/os-release)"
  echo "Python: $(python --version 2>&1)"
  echo "EVcouplings: $(python -c 'from importlib.metadata import version; print(version("evcouplings"))')"
  echo "plmc: $PLMC_BIN"
  echo "jackhmmer: $JACKHMMER_BIN"
  echo
  echo "UniRef90: $UNIREF90_FASTA"
  echo "jackhmmer iterations: $JACKHMMER_ITERATIONS"
  echo "jackhmmer sequence E-value: $JACKHMMER_EVALUE"
  echo "jackhmmer sequence inclusion E-value: $JACKHMMER_INCLUSION_EVALUE"
  echo "jackhmmer domain E-value: $JACKHMMER_DOMAIN_EVALUE"
  echo "jackhmmer domain inclusion E-value: $JACKHMMER_DOMAIN_INCLUSION_EVALUE"
  echo "jackhmmer random seed: $JACKHMMER_SEED"
  echo "minimum sequence coverage: $MINIMUM_SEQUENCE_COVERAGE"
  echo "plmc theta: $PLMC_THETA"
  echo "plmc lambda_e: $PLMC_LAMBDA_E"
  echo "plmc lambda_h: $PLMC_LAMBDA_H"
  echo "plmc maximum iterations: $PLMC_MAX_ITERATIONS"
  echo "plmc cores: $PLMC_CORES"
  echo "plmc precision: $PLMC_MODEL_PRECISION"
  echo "plmc random seed: not applicable in default L-BFGS mode"
  echo "mutation scoring random seed: not applicable"
  echo "mutation scoring repeats: not required"
  echo "units: dimensionless evolutionary statistical-energy units"
  echo "not thermodynamic ΔΔG and not kcal/mol"
  echo
  for f in "$TARGET_FASTA" "$UNIREF90_FASTA" "$PROJECT_ROOT/alignment/BhNIT_focus.a2m" "$PROJECT_ROOT/model/BhNIT.model" "$PROJECT_ROOT/results/processed/BhNIT_22_EVmutation_deltaE.csv"; do
    if [[ -f "$f" ]]; then sha256sum "$f"; else echo "MISSING $f"; fi
  done
} > "$OUT"
echo "Metadata written to: $OUT"
