# DeepPCD: Reproducible Computational Workflow for Protein Engineering

## Overview

This repository contains the complete computational workflow developed for the DeepPCD strategy.


The repository provides computational artifacts, executable scripts, parameters, and workflow organization required to reproduce the major computational analyses.

---

## Repository Organization

```
DeepPCD/

├── README.md
├── Cutoffs and random seeds.xlsx
├── ProteinMPNN-designed sequences.xlsx
├── Protein structures designed by ProteinMPPN/

├── FoldX_ddG Analysis/
│   ├── input/
│   ├── scripts/
│   ├── mutations/
│   ├── results/
│   └── README.md

├── Rosetta Cartesian_ddG Analysis/
│   ├── input/
│   ├── scripts/
│   ├── mutfiles/
│   ├── results/
│   └── README.md

├── EVmutation Analysis/
│   ├── data/
│   ├── scripts/
│   ├── alignment/
│   ├── model/
│   ├── results/
│   └── README.md

├── GROMACS_MD/
│   ├── scripts/
│   ├── mdp/
│   ├── topology/
│   ├── analysis/
│   ├── NPT/
│   ├── NVT/
│   └── README.md

└── metadata/
    ├── Software Environment.txt
```

---

## Workflow Overview

```
Protein sequence
        |
        v
ProteinMPNN
        |
        v
AlphaFold3
        |
        v
ConSurf
        |
        v
Mutation candidates
        |
        +----------------+
        |                |
        v                v
     FoldX        Rosetta Cartesian_ddG
        |
        v
   EVmutation
        |
        v
GROMACS Molecular Dynamics
        |
        v
Dynamic stability evaluation
```

---

## Software Environment

| Software | Version |
|-|-|
| Windows | Windows 11 |
| WSL | Ubuntu 24.04 |
| Python | 3.12 |
| FoldX | 5.1 |
| Rosetta |3.15
| EVcouplings | 0.2.1 |
| GROMACS | 2020.6 |

---

## FoldX Module

FoldX evaluates mutation-associated stability changes:

```
ΔΔG = ΔGmutant − ΔGwild-type
```

Workflow:

```
RepairPDB
   |
BuildModel
   |
22 independent mutations
   |
3 runs per mutation
   |
ΔΔG calculation
```

### Input structure

Place the final structure used in the manuscript in:

```text
data\input\BhNIT.pdb
```
Before calculation, verify the chain identifier, PDB residue numbering, wild-type residue identity, completeness of the target residues, oligomeric state, and treatment of ligands, metals, cofactors, and non-standard residues. In particular, confirm:

```text
A121 = G
A255 = F
A311 = N
A336 = A
```

### Validate the mutation file

```bat
python scripts\check_mutations.py mutations\individual_list.txt
```

Expected output:

```text
Validated 22 unique single-point mutations.
```

### Run the workflow

#### CMD

```bat
scripts\run_foldx.cmd "D:\FoldX\foldx.exe" "data\input\BhNIT.pdb" 3 BhNIT_22_single
```

#### PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts\run_foldx.ps1 `
  -FoldXPath "D:\FoldX\foldx.exe" `
  -PdbPath "data\input\BhNIT.pdb" `
  -Runs 3 `
  -OutputName "BhNIT_22_single"
```

### Exact FoldX commands

```bat
foldx.exe --command=RepairPDB --pdb=BhNIT.pdb
```

```bat
foldx.exe --command=BuildModel ^
  --pdb=BhNIT_Repair.pdb ^
  --mutant-file=individual_list.txt ^
  --numberOfRuns=3 ^
  --timeSeedRotabase=false ^
  --out-pdb=false ^
  --output-file=BhNIT_22_single
```

This corresponds to:

```text
22 mutations × 3 runs = 66 mutant calculations
```

No ΔΔG cutoff is used during the FoldX calculation.

### Expected output

Raw files are stored in `results/raw/`:

```text
Dif_*.fxout
Average_*.fxout
Raw_*.fxout
PdbList_*.fxout
```

Processed files are stored in `results/processed/`:

```text
foldx_ddg_long.csv
foldx_ddg_summary.csv
```

The summary table reports the mutation, number of runs, mean ΔΔG, standard deviation, minimum, maximum, and exploratory classification.

---

## Rosetta Cartesian_ddG Module

Rosetta provides an independent stability prediction workflow.

### Important interpretation

Rosetta Cartesian_ddG reports energy differences in Rosetta energy units (REU):

ΔΔG_Rosetta = mean(E_mutant) − mean(E_WT)

Under this sign convention:

- negative ΔΔG indicates predicted stabilization;
- positive ΔΔG indicates predicted destabilization;
- values close to zero indicate a comparatively small predicted energetic effect.

Rosetta REU values are not direct experimental thermodynamic measurements. When an approximate conversion is reported, this repository uses:

Approximate kcal/mol = REU / 2.94

This conversion is approximate and must be labeled accordingly.

### Mutation set

```text
W59A
V94A
L99I
L105Y
G121D
T136G
W168G
P173E
L196Y
A203M
N209R
N210P
S213T
C228T
T230V
L239F
D244E
H250P
F255R
P272E
T306L
N311D
```

Each mutation must be represented by an independent Rosetta mutfile. Multiple substitutions placed in the same mutfile block would be interpreted as a combined multiple-mutant construct.


### Workflow overview

```text
BhNIT input PDB
→ extract and renumber chain A
→ validate the 22 wild-type residues
→ generate 20 Cartesian-relaxed structures
→ select the lowest-total-score relaxed model
→ generate 22 independent Rosetta mutfiles
→ run 3 Cartesian_ddG iterations per mutation
→ parse WT and mutant total scores
→ calculate mean ΔΔG and standard deviation
→ export detailed and summary CSV files
```
### Recommended repository structure

```text
Rosetta-Cartesian-ddG-22-Mutations/
├── README.md
├── mutations.tsv
├── cart2.script
├── config.example.sh
├── data/input/BhNIT.pdb
├── input/processed/
│   ├── BhNIT_A_renumbered.pdb
│   └── BhNIT_A_best_relaxed.pdb
├── relax/models/
│   ├── BhNIT_A_renumbered_0001.pdb
│   ├── ...
│   ├── BhNIT_A_renumbered_0020.pdb
│   └── score.sc
├── mutfiles/
│   ├── W59A.mut
│   ├── ...
│   └── N311D.mut
├── results/raw/
├── results/processed/
│   ├── rosetta_cartesian_ddg_long.csv
│   ├── rosetta_cartesian_ddg_summary.csv
│   └── software_and_run_metadata.txt
├── logs/
└── scripts/
```

### Software environment

```text
Operating system: Windows 11 with WSL2
Linux distribution: Ubuntu 24.04
Rosetta : 3.15
Rosetta score function: ref2015_cart
Python: Python 3.12
```

### 1. Prepare the input structure

Place the original structure at:

```text
data/input/BhNIT.pdb
```

The preparation step should extract chain A, remove unsupported records as appropriate, renumber residues continuously, generate a residue-number mapping, and validate all 22 wild-type residues.

Expected outputs:

```text
input/processed/BhNIT_A_renumbered.pdb
results/processed/residue_mapping.tsv
```

All 22 sites must report `status=OK` before calculations begin.

### 2. Cartesian Relax

Generate 20 Cartesian-relaxed structures and select the model with the lowest Rosetta `total_score`.

```bash
"$RELAX"   -database "$ROSETTA3_DB"   -s input/processed/BhNIT_A_renumbered.pdb   -use_input_sc   -ignore_unrecognized_res   -nstruct 20   -score:weights ref2015_cart   -relax:min_type lbfgs_armijo_nonmonotone   -relax:script cart2.script   -fa_max_dis 9.0   -run:constant_seed   -run:jran 4082026   -out:path:all relax/models   -out:file:scorefile score.sc   2>&1 | tee logs/cartesian_relax.log
```

For the Rosetta binary release used in this workflow, the score function is specified with:

```text
-score:weights ref2015_cart
```

The option `-relax:cartesian-score:weights` was not recognized by that executable and is not used.

#### cart2.script

```text
switch:cartesian
repeat 2
ramp_repack_min 0.02  0.01     1.0  50
ramp_repack_min 0.250 0.01     0.5  50
ramp_repack_min 0.550 0.01     0.0 100
ramp_repack_min 1     0.00001  0.0 200
accept_to_best
endrepeat
```

The lowest-scoring structure is copied to:

```text
input/processed/BhNIT_A_best_relaxed.pdb
```

### 3. Generate independent mutfiles

Example for W59A:

```text
total 1
1
W 59 A
```

Example for H250P:

```text
total 1
1
H 250 P
```

Check:

```bash
find mutfiles -maxdepth 1 -type f -name "*.mut" | wc -l
```

Expected output:

```text
22
```

### 4. Cartesian_ddG calculations

Each mutation is evaluated using three forced Cartesian_ddG iterations.

```bash
"$CARTDDG"   -database "$ROSETTA3_DB"   -s input/processed/BhNIT_A_best_relaxed.pdb   -ddg::mut_file mutfiles/W59A.mut   -ddg::iterations 3   -ddg::force_iterations true   -ddg::cartesian true   -ddg::dump_pdbs false   -ddg::bbnbrs 1   -ddg::frag_nbrs 2   -ddg::flex_bb false   -ddg::legacy false   -score:weights ref2015_cart   -fa_max_dis 9.0   -ignore_zero_occupancy false   -missing_density_to_jump   -run:constant_seed   -run:jran 408001
```

The command is repeated for all 22 substitutions using independent mutfiles and mutation-specific seeds.

### Parameters and random seeds

### Cartesian Relax parameters

| Parameter | Value | Role |
|---|---:|---|
| Number of relaxed structures | 20 | Structural sampling |
| Score function | `ref2015_cart` | Rosetta energy function |
| `fa_max_dis` | 9.0 Å | Nonbonded interaction-distance cutoff |
| Minimizer | `lbfgs_armijo_nonmonotone` | Energy minimization |
| Relax-script repeats | 2 | Internal relaxation cycles |
| `use_input_sc` | enabled | Use input side-chain conformations |
| `ignore_unrecognized_res` | enabled | Ignore unsupported residue records |
| Constant seed | enabled | Reproducible stochastic sampling |
| Relax random seed | `4082026` | Fixed Cartesian Relax seed |

#### cart2.script minimization parameters

| Stage | `fa_rep` scale | Tolerance | Constraint scale | Maximum cycles |
|---:|---:|---:|---:|---:|
| 1 | 0.02 | 0.01 | 1.0 | 50 |
| 2 | 0.25 | 0.01 | 0.5 | 50 |
| 3 | 0.55 | 0.01 | 0.0 | 100 |
| 4 | 1.00 | 0.00001 | 0.0 | 200 |

#### Cartesian_ddG parameters

| Parameter | Value | Role |
|---|---:|---|
| `ddg::iterations` | 3 | WT/mutant refinement iterations |
| `ddg::force_iterations` | `true` | Forces all 3 iterations |
| `ddg::cartesian` | `true` | Enables Cartesian minimization |
| `ddg::dump_pdbs` | `false` | Avoids unnecessary output structures |
| `ddg::bbnbrs` | 1 | Local backbone-neighbor range |
| `ddg::frag_nbrs` | 2 | Fragment-neighbor range |
| `ddg::flex_bb` | `false` | Disables extended flexible-backbone mode |
| `ddg::legacy` | `false` | Uses the non-legacy workflow |
| Score function | `ref2015_cart` | Must match Relax |
| `fa_max_dis` | 9.0 Å | Must match Relax |
| `ignore_zero_occupancy` | `false` | Occupancy handling |
| `missing_density_to_jump` | enabled | Missing-density handling |
| Constant seed | enabled | Reproducible stochastic sampling |
| Mutation seeds | `408001–408022` | One fixed seed per mutation |

#### Mutation-specific seeds

| Order | Mutation | Seed |
|---:|---|---:|
| 1 | W59A | 408001 |
| 2 | V94A | 408002 |
| 3 | L99I | 408003 |
| 4 | L105Y | 408004 |
| 5 | G121D | 408005 |
| 6 | T136G | 408006 |
| 7 | W168G | 408007 |
| 8 | P173E | 408008 |
| 9 | L196Y | 408009 |
| 10 | A203M | 408010 |
| 11 | N209R | 408011 |
| 12 | N210P | 408012 |
| 13 | S213T | 408013 |
| 14 | C228T | 408014 |
| 15 | T230V | 408015 |
| 16 | L239F | 408016 |
| 17 | D244E | 408017 |
| 18 | H250P | 408018 |
| 19 | F255R | 408019 |
| 20 | P272E | 408020 |
| 21 | T306L | 408021 |
| 22 | N311D | 408022 |

The three `ddg::iterations` for one mutation are executed within one Rosetta process using the corresponding mutation-specific random-number stream. They are not launched as three separate processes with three independently assigned integer seeds.

#### Convergence-related settings

Rosetta also exposes options such as `ddg::score_cutoff` and `ddg::n_converged`. In this workflow:

```text
ddg::iterations = 3
ddg::force_iterations = true
```

Therefore, all three iterations are completed for every mutation and convergence settings are not used to terminate calculations early.

#### ΔΔG screening threshold

No pre-defined Rosetta ΔΔG cutoff was applied before or during the calculations. All 22 substitutions were calculated and retained for relative ranking and cross-method comparison with FoldX, EVmutation, structural analysis, and experimental evidence.

### 5. Parse Rosetta output

The Rosetta release used here writes records such as:

```text
COMPLEX: Round1: WT_: -1613.128 ...
COMPLEX: Round1: MUT_59ALA: -1617.785 ...
```

The parser must support `WT`, `WT_`, `MUT`, and `MUT_*`.

```python
PATTERN = re.compile(
    r"^\s*COMPLEX:\s*"
    r"Round\s*(\d+)\s*:\s*"
    r"(WT_?|MUT(?:_[^:]+)?)\s*:\s*"
    r"([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)"
)

score_type = "WT" if label.startswith("WT") else "MUT"
```

Run:

```bash
python3 scripts/parse_existing_ddg.py   --mutations mutations.tsv   --raw-dir results/raw   --output-dir results/processed   --iterations 3   --seed-base 408000
```

Expected outputs:

```text
results/processed/rosetta_cartesian_ddg_long.csv
results/processed/rosetta_cartesian_ddg_summary.csv
```

### 6. Output files

#### Long-format file

```text
results/processed/rosetta_cartesian_ddg_long.csv
```

Expected data rows:

```text
22 mutations × 3 iterations = 66
```

Key columns:

```text
mutation
iteration
wt_total_score_reu
mutant_total_score_reu
ddg_reu
approx_ddg_kcal_mol
seed
source_ddg_file
```

#### Summary file

```text
results/processed/rosetta_cartesian_ddg_summary.csv
```

Expected data rows:

```text
22
```

Key columns:

```text
mutation
n_iterations
iteration_1_ddg_reu
iteration_2_ddg_reu
iteration_3_ddg_reu
mean_wt_total_score_reu
mean_mutant_total_score_reu
mean_ddg_reu
sd_ddg_reu
min_ddg_reu
max_ddg_reu
approx_mean_ddg_kcal_mol
approx_sd_ddg_kcal_mol
interpretation
```

The principal result is `mean_ddg_reu`. The approximate kcal/mol representation is `approx_mean_ddg_kcal_mol`.

### 7. Quality-control checks

```bash
find relax/models -maxdepth 1 -type f -name "*.pdb" | wc -l
```

Expected: `20`

```bash
find mutfiles -maxdepth 1 -type f -name "*.mut" | wc -l
```

Expected: `22`

```bash
find results/raw -type f -name "*.ddg" | wc -l
```

Expected: `22`

```bash
find results/raw -type f -name COMPLETE | wc -l
```

Expected: `22`

```bash
wc -l results/processed/rosetta_cartesian_ddg_summary.csv
```

Expected: `23`

```bash
wc -l results/processed/rosetta_cartesian_ddg_long.csv
```

Expected: `67`

### 8. Reproducibility metadata

Record:

```text
Rosetta binary release
Rosetta database release/path
operating system
Relax executable
Cartesian_ddG executable
score function
all command-line parameters
all random seeds
input PDB checksum
prepared PDB checksum
best relaxed PDB checksum
mutation-table checksum
cart2.script checksum
raw .ddg checksums
processed CSV checksums
```

Generate checksums:

```bash
sha256sum   data/input/BhNIT.pdb   input/processed/BhNIT_A_renumbered.pdb   input/processed/BhNIT_A_best_relaxed.pdb   mutations.tsv   cart2.script   results/processed/rosetta_cartesian_ddg_long.csv   results/processed/rosetta_cartesian_ddg_summary.csv   > results/processed/checksums.sha256
```


### 9. Files recommended for GitHub deposition

Upload:

```text
README.md
mutations.tsv
cart2.script
config.example.sh
input PDB when redistribution is permitted
prepared and renumbered PDB
selected lowest-score relaxed PDB
score.sc
22 independent mutfiles
22 raw .ddg files
mutation-specific logs
Cartesian Relax log
master workflow log
long-format result CSV
summary result CSV
software-and-run metadata
checksums
all scripts used for calculation and parsing
```

### 10. Limitations

Rosetta Cartesian_ddG results depend on:

```text
input structure
chain and residue numbering
structure preparation
Rosetta release
score function
relaxation protocol
sampling depth
random seed
compiler and CPU platform
floating-point behavior
```

Small numerical differences may occur across Rosetta releases, compilers, CPU architectures, and operating systems. The input structure, software release, parameters, seeds, raw outputs, and checksums should therefore be deposited together.

---

## EVmutation Module

EVmutation calculates evolutionary statistical energy differences.

Under this sign convention:

- negative ΔΔG indicates predicted stabilization;
- positive ΔΔG indicates predicted destabilization;
- values close to zero indicate a comparatively small predicted energetic effect.

Rosetta REU values are not direct experimental thermodynamic measurements. When an approximate conversion is reported, this repository uses:

Approximate kcal/mol = REU / 2.94

This conversion is approximate and must be labeled accordingly.

### Mutation set

```text
W59A   V94A   L99I   L105Y  G121D  T136G
W168G  P173E  L196Y  A203M  N209R  N210P
S213T  C228T  T230V  L239F  D244E  H250P
F255R  P272E  T306L  N311D
```

### Workflow overview

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

### Repository structure

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

### 1. Software environment

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

### 2. Configure local paths

```bash
cp config.example.sh config.sh
nano config.sh
```

Set the exact UniRef90 path, for example:

```bash
export UNIREF90_FASTA="/mnt/d/EVmutation_database/uniref90.fasta"
```

### 3. Add and validate the BhNIT sequence

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

### 4. Search homologous sequences

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

### 5. Prepare the BhNIT focus alignment

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

### 6. Infer BhNIT.model

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

### 7. Calculate the 22 ΔE values

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

### 8. Rank the results

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

### 9. Parameters and random seeds

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

### 10. Files recommended for public deposition

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

---

## GROMACS Molecular Dynamics Module

MD simulations were performed using:

- GROMACS 2020.6
- AMBER99SB-ILDN force field
- TIP3P water
- GAFF2 + AM1-BCC ligand parameters

Simulation conditions:

```
Production MD: 100 ns

Stable analysis window:
80–100 ns
```

The simulation represents a fixed protonation-state model corresponding to pH 5.5.

This is not constant-pH MD.

Analyses include:

- RMSD
- RMSF
- Radius of gyration
- Hydrogen bonds
- Ligand interactions
- MM/PBSA binding energy

### 2. Project-specific protonation model

The following assignments were obtained from the PDB2PQR/PROPKA workflow used in this project:

|Residue|State|Interpretation|
|-|-|-|
|HIS5|HIP|Doubly protonated histidine, +1|
|GLU48|GLH|Protonated glutamate, neutral|
|HIS57|HID|Neutral histidine, proton on ND1|
|HIS137|HIP|Doubly protonated histidine, +1|
|HIS154|HID|Neutral histidine, proton on ND1|
|HIS170|HID|Neutral histidine, proton on ND1|
|HIS187|HIP|Doubly protonated histidine, +1|
|HIS246|HIP|Doubly protonated histidine, +1|
|HIS250|HIP|Doubly protonated histidine, +1|
|HIS299|HIP|Doubly protonated histidine, +1|
|HIS320|HIP|Doubly protonated histidine, +1|

For the noncovalent enzyme–substrate complex:

```text
Catalytic cysteine: CYS, neutral thiol state
Ligand net charge: 0
```

Reassess these assignments if the protein structure, ligand, catalytic state, or target pH changes.
Simulations conducted under nominal neutral protonation conditions do not require altering the protonation state of the amino acids.

### 3. Software

Example GROMACS installation:

```text
C:\\gmx2020.6\_AVX2\_CUDA\_win64\\gmx2020.6\_GPU
```

PowerShell variable:

```powershell
$GMX = "C:\\gmx2020.6\_AVX2\_CUDA\_win64\\gmx2020.6\_GPU\\bin\\gmx.exe"
\& $GMX --version
```

Additional tools:

* PDB2PQR/PROPKA for protonation-state prediction
* ACPYPE for ligand topology generation
* PyMOL or ChimeraX for structural inspection
* Python 3 for helper scripts

### 4. Project directory

```powershell
Set-Location "C:\\Users\\zxt\\Desktop\\GMX\_BhNIT\_pH5p5"
```

Recommended layout:

```text
GMX\_BhNIT\_pH5p5/
├── input/
├── topology/
├── mdp/
├── em/
├── nvt/
├── npt/
├── md/
├── analysis/
├── logs/
└── scripts/
```

Essential files:

```text
input/BhNIT\_protein.pdb
input/Lig\_pH5p5\_GMX.gro
input/Lig\_pH5p5\_GMX.itp
topology/topol.top
topology/posre\_protein.itp
mdp/ions.mdp
mdp/em.mdp
mdp/nvt.mdp
mdp/npt.mdp
mdp/md.mdp
```

Check them:

```powershell
Get-Item `
  ".\\input\\BhNIT\_protein.pdb", `
  ".\\input\\Lig\_pH5p5\_GMX.gro", `
  ".\\input\\Lig\_pH5p5\_GMX.itp" |
Select-Object FullName, Length
```

### 5. Protein topology

```powershell
\& $GMX pdb2gmx `
  -f ".\\input\\BhNIT\_protein.pdb" `
  -o ".\\topology\\protein\_pH5p5.gro" `
  -p ".\\topology\\topol.top" `
  -i ".\\topology\\posre\_protein.itp" `
  -ff amber99sb-ildn `
  -water tip3p `
  -ignh `
  -glu `
  -his `
  2>\&1 |
Tee-Object ".\\logs\\02\_pdb2gmx\_pH5p5.log"
```

Interactive correspondence:

```text
GLH -> protonated Glu
HID -> proton on ND1
HIE -> proton on NE2
HIP -> protons on ND1 and NE2
```

Select by the displayed chemical description.

### 6. Ligand topology

For a neutral ligand:

```bash
acpype \\
  -i ligand\_pH5p5.mol2 \\
  -b Lig\_pH5p5 \\
  -c bcc \\
  -n 0 \\
  -a gaff2
```

Confirm that the sum of ligand atomic charges is approximately zero.

Topology directive order is critical. `\[ atomtypes ]` must appear before the first `\[ moleculetype ]`. A safe high-level order is:

```text
force-field parameters
ligand atom types
protein moleculetype
protein position restraints
ligand moleculetype
water and ion topology
\[ system ]
\[ molecules ]
```
### 7. Merge protein and ligand coordinates

```powershell
python -u ".\\scripts\\02\_merge\_gro.py" `
  --protein ".\\topology\\protein\_pH5p5.gro" `
  --ligand ".\\input\\Lig\_pH5p5\_GMX.gro" `
  --output ".\\topology\\complex\_pH5p5.gro"
```

Validate atom counts:

```powershell
$ProteinAtoms = \[int](Get-Content ".\\topology\\protein\_pH5p5.gro" -TotalCount 2)\[1]
$LigandAtoms  = \[int](Get-Content ".\\input\\Lig\_pH5p5\_GMX.gro" -TotalCount 2)\[1]
$ComplexAtoms = \[int](Get-Content ".\\topology\\complex\_pH5p5.gro" -TotalCount 2)\[1]

\[PSCustomObject]@{
    ProteinAtoms = $ProteinAtoms
    LigandAtoms  = $LigandAtoms
    Expected     = $ProteinAtoms + $LigandAtoms
    ComplexAtoms = $ComplexAtoms
}
```

The complex atom count must equal protein plus ligand. Coordinate concatenation does not automatically place the ligand in the pocket; inspect the structure before continuing.

### 8. Box and solvation

```powershell
\& $GMX editconf `
  -f ".\\topology\\complex.gro" `
  -o ".\\topology\\complex\_box.gro" `
  -bt dodecahedron `
  -d 1.0 `
  -c `
  2>\&1 |
Tee-Object ".\\logs\\03\_editconf.log"
```

```powershell
\& $GMX solvate `
  -cp ".\\topology\\complex\_box.gro" `
  -cs spc216.gro `
  -p ".\\topology\\topol.top" `
  -o ".\\topology\\complex\_solv.gro" `
  2>\&1 |
Tee-Object ".\\logs\\04\_solvate.log"
```

### 9. Ion addition

```powershell
\& $GMX grompp `
  -f ".\\mdp\\ions.mdp" `
  -c ".\\topology\\complex\_solv.gro" `
  -p ".\\topology\\topol.top" `
  -o ".\\topology\\ions.tpr" `
  -pp ".\\topology\\processed\_topology\_ions.top" `
  2>\&1 |
Tee-Object ".\\logs\\05\_grompp\_ions.log"
```

```powershell
\& $GMX genion `
  -s ".\\topology\\ions.tpr" `
  -o ".\\topology\\complex\_solv\_ions.gro" `
  -p ".\\topology\\topol.top" `
  -pname NA `
  -nname CL `
  -conc 0.15 `
  -neutral `
  -rmin 0.6 `
  2>\&1 |
Tee-Object ".\\logs\\06\_genion.log"
```

Select `SOL` when prompted.

### 10. Energy minimization

Recommended core settings:

```ini
integrator  = steep
emtol       = 1000.0
emstep      = 0.01
nsteps      = 50000
cutoff-scheme = Verlet
nstlist        = 20
rlist          = 1.0
rcoulomb       = 1.0
rvdw           = 1.0
coulombtype    = PME
```

```powershell
\& $GMX grompp `
  -f ".\\mdp\\em.mdp" `
  -c ".\\topology\\complex\_solv\_ions.gro" `
  -p ".\\topology\\topol.top" `
  -o ".\\em\\em.tpr" `
  -po ".\\em\\em\_processed.mdp" `
  -pp ".\\em\\processed\_topology\_em.top" `
  2>\&1 |
Tee-Object ".\\logs\\07\_grompp\_em.log"
```

```powershell
Set-Location ".\\em"
\& $GMX mdrun -deffnm em -v 2>\&1 |
Tee-Object "..\\logs\\08\_mdrun\_em.log"
Set-Location ".."
```

Acceptance checks:

```text
Maximum force < emtol
No NaN values
No fatal errors
No LINCS warnings
```

### 11. Index groups

```powershell
\& $GMX make\_ndx `
  -f ".\\em\\em.gro" `
  -o ".\\topology\\index.ndx"
```

Current example:

```text
Protein = 5102 atoms
LIG = 12 atoms
Protein\_LIG = 5114 atoms
```

Example interactive commands:

```text
1 | 13
name 22 Protein\_LIG
q
```

Group numbers can change. Verify them before typing commands.

Recommended groups:

```text
Protein
LIG
Protein\_LIG
Water\_and\_ions
Backbone
C-alpha
```

Temperature coupling:

```ini
tc-grps = Protein\_LIG Water\_and\_ions
```

### 12. NVT equilibration

Representative settings:

```ini
integrator   = md
dt           = 0.002
nsteps       = 50000
continuation = no
define       = -DPOSRES
include      = -I./topology
constraints          = h-bonds
constraint-algorithm = lincs
lincs\_iter           = 1
lincs\_order          = 4
lincs\_warnangle      = 30
cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0
rcoulomb                = 1.0
rvdw                    = 1.0
coulombtype             = PME
fourierspacing          = 0.12
pme\_order               = 4
ewald\_rtol              = 1e-5
verlet-buffer-tolerance = 0.005
tcoupl    = v-rescale
tc-grps   = Protein\_LIG Water\_and\_ions
tau\_t     = 0.1 0.1
ref\_t     = 310.15 310.15
pcoupl    = no
gen\_vel   = yes
gen\_temp  = 310.15
gen\_seed  = 55001
```

Position restraints:

```text
#ifdef POSRES
#include "posre\_protein.itp"
#endif
```

```powershell
\& $GMX grompp `
  -f ".\\mdp\\nvt.mdp" `
  -c ".\\em\\em.gro" `
  -r ".\\em\\em.gro" `
  -p ".\\topology\\topol.top" `
  -n ".\\topology\\index.ndx" `
  -o ".\\nvt\\nvt.tpr" `
  -po ".\\nvt\\nvt\_processed.mdp" `
  -pp ".\\nvt\\processed\_topology\_nvt.top" `
  2>\&1 |
Tee-Object ".\\logs\\09\_grompp\_nvt.log"
```

```powershell
Set-Location ".\\nvt"
\& $GMX mdrun -deffnm nvt\_pH5p5 -v 2>\&1 |
Tee-Object "..\\logs\\10\_mdrun\_nvt.log"
Set-Location ".."
```

### 13. NPT equilibration

Representative settings:

```ini
integrator   = md
dt           = 0.002
nsteps       = 50000
continuation = yes
define       = -DPOSRES
include      = -I./topology
tcoupl       = v-rescale
tc-grps      = Protein\_LIG Water\_and\_ions
tau\_t        = 0.1 0.1
ref\_t        = 310.15 310.15
pcoupl          = Berendsen
pcoupltype      = isotropic
tau\_p           = 2.0
ref\_p           = 1.0
compressibility = 4.5e-5
gen\_vel = no
```

```powershell
\& $GMX grompp `
  -f ".\\mdp\\npt.mdp" `
  -c ".\\nvt\\nvt.gro" `
  -r ".\\nvt\\nvt.gro" `
  -t ".\\nvt\\nvt.cpt" `
  -p ".\\topology\\topol.top" `
  -n ".\\topology\\index\_pH5p5.ndx" `
  -o ".\\npt\\npt.tpr" `
  -po ".\\npt\\npt\_processed.mdp" `
  -pp ".\\npt\\processed\_topology\_npt.top" `
  2>\&1 |
Tee-Object ".\\logs\\11\_grompp\_npt.log"
```

```powershell
Set-Location ".\\npt"
\& $GMX mdrun -deffnm npt\_pH5p5 -v 2>\&1 |
Tee-Object "..\\logs\\12\_mdrun\_npt.log"
Set-Location ".."
```

### 14. Production MD

Representative 100 ns settings:

```ini
integrator   = md
dt           = 0.002
nsteps       = 50000000
continuation = yes
constraints          = h-bonds
constraint-algorithm = lincs
lincs\_iter           = 1
lincs\_order          = 4
lincs\_warnangle      = 30
cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0
rcoulomb                = 1.0
rvdw                    = 1.0
coulombtype             = PME
fourierspacing          = 0.12
pme\_order               = 4
ewald\_rtol              = 1e-5
verlet-buffer-tolerance = 0.005
tcoupl    = v-rescale
tc-grps   = Protein\_LIG Water\_and\_ions
tau\_t     = 0.1 0.1
ref\_t     = 310.15 310.15
pcoupl          = Parrinello-Rahman
pcoupltype      = isotropic
tau\_p           = 2.0
ref\_p           = 1.0
compressibility = 4.5e-5
gen\_vel = no
```

```powershell
\& $GMX grompp `
  -f ".\\mdp\\md.mdp" `
  -c ".\\npt\\npt.gro" `
  -t ".\\npt\\npt.cpt" `
  -p ".\\topology\\topol.top" `
  -n ".\\topology\\index.ndx" `
  -o ".\\md\\md.tpr" `
  -po ".\\md\\md\_processed.mdp" `
  -pp ".\\md\\processed\_topology\_md.top" `
  2>\&1 |
Tee-Object ".\\logs\\13\_grompp\_md.log"
```

```powershell
Set-Location ".\\md"
\& $GMX mdrun -deffnm md -nb gpu -v 2>\&1 |
Tee-Object "..\\logs\\14\_mdrun\_md.log"
Set-Location ".."
```

### 15. Main parameters and random seeds

|Parameter|Value|Meaning|
|-|-:|-|
|`editconf -d`|1.0 nm|Minimum solute-to-box distance|
|`genion -rmin`|0.6 nm|Minimum ion-to-solute distance|
|`emtol`|1000 kJ mol⁻¹ nm⁻¹|Minimization force threshold|
|`emstep`|0.01 nm|Minimization step size|
|`dt`|0.002 ps|MD time step|
|`rcoulomb`|1.0 nm|Coulomb cutoff|
|`rvdw`|1.0 nm|van der Waals cutoff|
|`fourierspacing`|0.12 nm|PME grid spacing|
|`pme\_order`|4|PME interpolation order|
|`ewald\_rtol`|1×10⁻⁵|Ewald tolerance|
|`lincs\_warnangle`|30°|LINCS warning angle|
|`ref\_t`|310.15 K|Target temperature|
|`ref\_p`|1.0 bar|Target pressure|

Random seeds:

|Stage|Parameter|Seed|
|-|-|-:|
|ions fixed|`ld\_seed`|1642684379|
|em|`ld\_seed`|-26742921|
|NVT initial velocities|`gen\_seed`|55001|
|NVT thermostat|`ld\_seed`|-551600386|
|NPT thermostat|`ld\_seed`|-549781771|
|Production thermostat|`ld\_seed`|-2898947|

Identical seeds do not guarantee bitwise-identical trajectories across different hardware or builds.

### 16. Analysis variables

```powershell
Set-Location "C:\\Users\\zxt\\Desktop\\GMX\_BhNIT\_pH5p5"

$ROOT = (Get-Location).Path
$GMX  = "C:\\gmx2020.6\_AVX2\_CUDA\_win64\\gmx2020.6\_GPU\\bin\\gmx.exe"
$TPR  = "$ROOT\\md\\md.tpr"
$XTC  = "$ROOT\\md\\md5.xtc"
$EDR  = "$ROOT\\md\\md.edr"
$NDX  = "$ROOT\\topology\\index.ndx"
$ANA  = "$ROOT\\analysis"
```

```powershell
New-Item -ItemType Directory -Force `
  "$ANA\\trajectory", `
  "$ANA\\energy", `
  "$ANA\\rmsd", `
  "$ANA\\rmsf", `
  "$ANA\\gyrate", `
  "$ANA\\sasa", `
  "$ANA\\hbond", `
  "$ANA\\catalytic\_geometry", `
  "$ANA\\cluster", `
  "$ANA\\structures" |
Out-Null
```

```powershell
\& $GMX check -f $XTC 2>\&1 |
Tee-Object "$ANA\\trajectory\\trajectory\_check.log"
```

Current example group numbers:

```text
0 System
1 Protein
3 C-alpha
4 Backbone
13 LIG
21 Water\_and\_ions
24 Protein\_LIG
```

Verify them before analysis.

### 17. PBC correction and fitting

```powershell
@("0") |
\& $GMX trjconv `
  -s $TPR `
  -f $XTC `
  -n $NDX `
  -o "$ANA\\trajectory\\md.xtc" `
  -pbc mol `
  -ur compact
```

```powershell
@("24", "0") |
\& $GMX trjconv `
  -s $TPR `
  -f "$ANA\\trajectory\\md\_whole.xtc" `
  -n $NDX `
  -o "$ANA\\trajectory\\md\_center.xtc" `
  -pbc mol `
  -center `
  -ur compact
```

The `md_center.xtc` file is stored on Google Drive for public download. The download link is: https://drive.google.com/file/d/1Retd0GuvDzcUvpkLZSWRF__mb7uaLaw0/view?usp=drive_link

`md_center.xtc` is a trajectory file generated by GROMACS MD simulations after applying Periodic Boundary Conditions (PBC) and performing centering. This file is typically not the original MD output file but is instead produced using `gmx trjconv` on the raw trajectory (e.g., `md.xtc`) for subsequent analyses such as RMSD, RMSF, Rg, hydrogen bonding, and MM/PBSA calculations.

```powershell
@("4", "24") |
\& $GMX trjconv `
  -s $TPR `
  -f "$ANA\\trajectory\\md\_center\_system.xtc" `
  -n $NDX `
  -o "$ANA\\trajectory\\md\_fit\_complex.xtc" `
  -fit rot+trans
```

```powershell
$CENTERED = "$ANA\\trajectory\\md\_center\_system.xtc"
$FIT      = "$ANA\\trajectory\\md\_fit\_complex.xtc"
```

### 18. Energy terms

```powershell
@("Temperature", "0") | \& $GMX energy -f $EDR -o "$ANA\\energy\\temperature.xvg"
@("Pressure", "0")    | \& $GMX energy -f $EDR -o "$ANA\\energy\\pressure.xvg"
@("Density", "0")     | \& $GMX energy -f $EDR -o "$ANA\\energy\\density.xvg"
@("Potential", "0")   | \& $GMX energy -f $EDR -o "$ANA\\energy\\potential.xvg"
```

### 19. RMSD

Backbone RMSD:

```powershell
@("4", "4") |
\& $GMX rms -s $TPR -f $CENTERED -n $NDX `
  -o "$ANA\\rmsd\\rmsd\_backbone.xvg" -tu ns
```

Whole-protein RMSD after backbone fitting:

```powershell
@("4", "1") |
\& $GMX rms -s $TPR -f $CENTERED -n $NDX `
  -o "$ANA\\rmsd\\rmsd\_protein.xvg" -tu ns
```

Ligand RMSD relative to the protein:

```powershell
@("4", "13") |
\& $GMX rms -s $TPR -f $CENTERED -n $NDX `
  -o "$ANA\\rmsd\\rmsd\_ligand\_protein\_fit.xvg" -tu ns
```

### 20. C-alpha RMSF over 80–100 ns

```powershell
@("3") |
\& $GMX rmsf `
  -s $TPR `
  -f $CENTERED `
  -n $NDX `
  -o "$ANA\\rmsf\\rmsf\_calpha\_80\_100ns.xvg" `
  -ox "$ANA\\rmsf\\average\_structure\_rmsf.pdb" `
  -res `
  -fit `
  -b 80000 `
  -e 100000
```

### 21. Radius of gyration

```powershell
@("1") |
\& $GMX gyrate -s $TPR -f $CENTERED -n $NDX `
  -o "$ANA\\gyrate\\gyrate\_protein.xvg"
```

## 22\. SASA over 80–100 ns

```powershell
$ProteinSelection = 'group "Protein"'

\& $GMX sasa `
  -s $TPR `
  -f $CENTERED `
  -n $NDX `
  -surface $ProteinSelection `
  -output $ProteinSelection `
  -o "$ANA\\sasa\\sasa\_protein.xvg" `
  -or "$ANA\\sasa\\sasa\_per\_residue.xvg" `
  -oa "$ANA\\sasa\\sasa\_per\_atom.xvg" `
  -b 80000 `
  -e 100000
```

### 23. Protein–ligand hydrogen bonds

```powershell
@("1", "13") |
\& $GMX hbond `
  -s $TPR `
  -f $CENTERED `
  -n $NDX `
  -num "$ANA\\hbond\\protein\_ligand\_hbond\_number.xvg" `
  -dist "$ANA\\hbond\\protein\_ligand\_hbond\_distance.xvg" `
  -ang "$ANA\\hbond\\protein\_ligand\_hbond\_angle.xvg" `
  -hbn "$ANA\\hbond\\protein\_ligand\_hbond.ndx" `
  -hbm "$ANA\\hbond\\protein\_ligand\_hbond\_map.xpm" `
  -r 0.35 `
  -a 30 `
  -b 80000 `
  -e 100000
```

Criteria:

```text
Donor–acceptor distance <= 0.35 nm
Hydrogen–donor–acceptor angle <= 30 degrees
```

### 24. Catalytic Cys–nitrile distance

Confirm the real catalytic residue number and ligand atom names before use:

```powershell
$CatalyticCys  = 167
$NitrileCarbon = "C57"

$DistanceSelection = `
  "resnr $CatalyticCys and name SG plus " +
  "resname LIG and name $NitrileCarbon"

\& $GMX distance `
  -s $TPR `
  -f $CENTERED `
  -n $NDX `
  -select $DistanceSelection `
  -oall "$ANA\\catalytic\_geometry\\CysSG\_nitrileC\_distance.xvg" `
  -oh "$ANA\\catalytic\_geometry\\CysSG\_nitrileC\_histogram.xvg" `
  -oallstat "$ANA\\catalytic\_geometry\\CysSG\_nitrileC\_statistics.xvg" `
  -b 80000 `
  -e 100000 `
  -tu ns
```

### 25. Extract representative structures

```powershell
@("24") |
\& $GMX trjconv -s $TPR -f $CENTERED -n $NDX `
  -o "$ANA\\structures\\complex\_90ns.pdb" -dump 90000
```

```powershell
@("24") |
\& $GMX trjconv -s $TPR -f $CENTERED -n $NDX `
  -o "$ANA\\structures\\complex\_100ns.pdb" -dump 100000
```

### 26. Key outputs

```text
analysis/energy/temperature.xvg
analysis/energy/pressure.xvg
analysis/energy/density.xvg
analysis/rmsd/rmsd\_backbone.xvg
analysis/rmsf/rmsf\_calpha\_80\_100ns.xvg
analysis/gyrate/gyrate\_protein.xvg
analysis/sasa/sasa\_protein.xvg
analysis/hbond/protein\_ligand\_hbond\_number.xvg
analysis/catalytic\_geometry/CysSG\_nitrileC\_distance.xvg
```

### 27. Interpretation notes

* RMSD has no universal stability cutoff.
* Compare RMSF using identical atom selections and time windows.
* Instantaneous pressure can fluctuate strongly; inspect means and trends.
* Stable ligand RMSD alone does not prove catalytic competence.
* MM/PBSA is an end-point binding-energy estimate, not a reaction barrier.

### 28. Reproducibility checklist

Archive:

```text
Original and processed MDP files
Final topol.top
All included ITP files
PDB2PQR/PROPKA outputs
Ligand MOL2, GRO, and ITP files
Index file
Initial and equilibrated structures
TPR and CPT files
Run logs
Random-seed table
Analysis commands and outputs
Representative structures
GROMACS version
CPU/GPU information
```

---

## Reproducibility

The repository provides:

- executable scripts
- input structures
- mutation lists
- raw outputs
- processed results
- software versions
- random seeds

External licensed software and large databases are not redistributed.

---

## Citation

Please cite the corresponding DeepPCD manuscript when using this workflow.

---

## Contact

For questions, please open an issue in this repository.
