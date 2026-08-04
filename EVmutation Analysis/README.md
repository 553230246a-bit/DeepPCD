# Reproducible EVmutation Analysis of 22 BhNIT Single-Point Mutations

This repository contains the complete workflow used to calculate evolutionary statistical-energy differences (ΔE) for 22 independent BhNIT substitutions with EVcouplings/EVmutation and plmc under Windows Subsystem for Linux (Ubuntu 24.04).

## Important interpretation

EVmutation ΔE is a **dimensionless evolutionary statistical-energy difference** derived from a protein-family Potts model. It is not a thermodynamic folding free-energy change.

The principal output used for within-model ranking is:

```text
deltaE_epistatic_full
```

No universal absolute ΔE cutoff was imposed. Mutations were ranked within the BhNIT-specific model.

## Mutation set

```text
W59A   V94A   L99I   L105Y  G121D  T136G
W168G  P173E  L196Y  A203M  N209R  N210P
S213T  C228T  T230V  L239F  D244E  H250P
F255R  P272E  T306L  N311D
```

## Workflow overview

```text
BhNIT amino-acid sequence
        |
        v
Validate the sequence and 22 wild-type residues
        |
        v
Search UniRef90 with jackhmmer
        |
        v
Center and filter the multiple-sequence alignment
        |
        v
Validate the 338-position BhNIT focus alignment
        |
        v
Infer a pairwise Potts model with plmc
        |
        v
Validate all 22 positions in BhNIT.model
        |
        v
Calculate full, coupling, field, and independent ΔE
        |
        v
Rank results within the BhNIT-specific model
```

## Repository structure

```text
EVmutation-BhNIT-22-Mutations/
├── README.md
├── requirements.txt
├── config.example.sh
├── data/
│   ├── input/BhNIT.fasta
│   └── mutations/
│       ├── mutations.csv
│       └── mutations.tsv
├── alignment/
├── model/
├── results/processed/
│   ├── BhNIT_22_EVmutation_deltaE.csv
│   └── BhNIT_22_EVmutation_deltaE_ranked.csv
├── logs/
├── scripts/
│   ├── validate_sequence.py
│   ├── run_jackhmmer.sh
│   ├── prepare_focus_alignment.py
│   ├── validate_focus_alignment.py
│   ├── run_plmc.sh
│   ├── validate_model.py
│   ├── score_22_deltaE.py
│   ├── rank_results.py
│   └── generate_metadata.sh
└── docs/
    
```

## 1. Software environment

The original environment used:

```text
WSL: Ubuntu 24.04
Python virtual environment: ~/.venvs/evcouplings
EVcouplings: 0.2.1
setuptools: 81.0.0
HMMER/jackhmmer
plmc compiled with make all-openmp32
```

Activate the environment:

```bash
source "$HOME/.venvs/evcouplings/bin/activate"
```

Install Python requirements:

```bash
python -m pip install -r requirements.txt
```

Compile plmc:

```bash
cd "$HOME/software/plmc"
make -j"$(nproc)" all-openmp32
```

## 2. Configure local paths

```bash
cp config.example.sh config.sh
nano config.sh
```

Set the exact UniRef90 path, for example:

```bash
export UNIREF90_FASTA="/mnt/d/EVmutation_database/uniref90.fasta"
```

## 3. Add and validate the BhNIT sequence

Place the exact wild-type sequence at:

```text
data/input/BhNIT.fasta
```

The FASTA identifier must be:

```text
>BhNIT
```

Run:

```bash
python scripts/validate_sequence.py \
  --fasta data/input/BhNIT.fasta \
  --mutations data/mutations/mutations.tsv \
  --target-id BhNIT
```

All 22 positions must report `status=OK`.

## 4. Search homologous sequences

```bash
bash scripts/run_jackhmmer.sh
```

The configured search uses:

```text
iterations: 5
sequence reporting E-value: 1e-3
sequence inclusion E-value: 1e-3
domain reporting E-value: 1e-3
domain inclusion E-value: 1e-3
random seed: 42
```

Primary outputs:

```text
alignment/BhNIT_raw.sto
alignment/BhNIT_hits.tbl
alignment/BhNIT_domains.tbl
logs/BhNIT_jackhmmer.log
```

## 5. Prepare the BhNIT focus alignment

```bash
python scripts/prepare_focus_alignment.py \
  --stockholm alignment/BhNIT_raw.sto \
  --output alignment/BhNIT_focus.a2m \
  --stats alignment/BhNIT_sequence_coverage.csv \
  --target-id BhNIT \
  --minimum-coverage 0.70
```

Validate the focus alignment:

```bash
python scripts/validate_focus_alignment.py \
  --alignment alignment/BhNIT_focus.a2m \
  --target-id BhNIT \
  --expected-length 338
```

The completed analysis used:

```text
53,836 aligned sequences
338 BhNIT target positions
no gaps in the BhNIT focus sequence
```

## 6. Infer BhNIT.model

```bash
bash scripts/run_plmc.sh
```

The model-inference command is equivalent to:

```bash
plmc \
  -o model/BhNIT.model \
  -c model/BhNIT_couplings.txt \
  --save-weights model/BhNIT_sequence_weights.txt \
  -f BhNIT \
  -g \
  -t 0.2 \
  -le 16.0 \
  -lh 0.01 \
  -m 100 \
  -n 8 \
  alignment/BhNIT_focus.a2m
```

Validate the model:

```bash
python scripts/validate_model.py \
  --model model/BhNIT.model \
  --mutations data/mutations/mutations.tsv \
  --precision float32
```

## 7. Calculate the 22 ΔE values

```bash
python scripts/score_22_deltaE.py \
  --model model/BhNIT.model \
  --mutations data/mutations/mutations.csv \
  --output results/processed/BhNIT_22_EVmutation_deltaE.csv \
  --metadata results/processed/BhNIT_22_EVmutation_metadata.json \
  --precision float32 \
  2>&1 | tee logs/score_22_deltaE.log
```

The output contains:

```text
deltaE_epistatic_full
deltaE_epistatic_couplings
deltaE_epistatic_fields
deltaE_independent
```

The full score equals the coupling and field contributions, subject to floating-point rounding.

## 8. Rank the results

```bash
python scripts/rank_results.py \
  --input results/processed/BhNIT_22_EVmutation_deltaE.csv \
  --output results/processed/BhNIT_22_EVmutation_deltaE_ranked.csv
```

The BhNIT-specific ranking begins:

```text
N209R
L196Y
C228T
L239
L105Y
S213T
```

This is a relative ranking within the BhNIT model, not a universal mutation-effect threshold.

## 9. Parameters and random seeds

| Stage | Parameter | Value |
|---|---|---:|
| jackhmmer | iterations | 5 |
| jackhmmer | sequence E-value | 1e-3 |
| jackhmmer | sequence inclusion E-value | 1e-3 |
| jackhmmer | domain E-value | 1e-3 |
| jackhmmer | domain inclusion E-value | 1e-3 |
| jackhmmer | random seed | 42 |
| MSA filtering | minimum homolog coverage | 0.70 |
| plmc | sequence divergence threshold | 0.2 |
| plmc | coupling L2 regularization | 16.0 |
| plmc | field L2 regularization | 0.01 |
| plmc | maximum iterations | 100 |
| plmc | model precision | float32 |
| plmc | random seed | not applicable in default L-BFGS mode |
| ΔE scoring | random seed | not applicable |
| ΔE scoring | repeated runs | not required |
| ΔE filtering | universal cutoff | none |

## 10. Files recommended for public deposition

Upload:

```text
BhNIT.fasta
mutations.csv and mutations.tsv
all scripts
config.example.sh
BhNIT_focus.a2m
BhNIT_sequence_coverage.csv
BhNIT.model
BhNIT_couplings.txt
BhNIT_sequence_weights.txt
jackhmmer and plmc logs
raw and ranked result CSV files
metadata and checksums
```

Do not upload:

```text
the full UniRef90 database
the Python virtual environment
compiled system libraries
private local paths or credentials
```

Use Git LFS or Zenodo for raw alignments or other files that exceed standard GitHub file-size limits.

## 11. Reproducibility limitations

The exact result depends on the BhNIT sequence, UniRef90 release, database checksum, HMMER version, focus-alignment construction, plmc source revision, compile precision, and all listed parameters. the model and focus alignment results are submitted along with the relevant scripts.
