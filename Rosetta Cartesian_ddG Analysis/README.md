# Reproducible Rosetta Cartesian_ddG Analysis of 22 BhNIT Single-Point Mutations

This repository documents the complete Rosetta Cartesian_ddG workflow used to estimate the effects of 22 independent single-amino-acid substitutions in BhNIT. The workflow was designed for reproducibility under Windows Subsystem for Linux (WSL2) using Ubuntu 24.04 and a locally installed Rosetta binary release.

## Important interpretation

Rosetta Cartesian_ddG reports energy differences in Rosetta energy units (REU):

ΔΔG_Rosetta = mean(E_mutant) − mean(E_WT)

Under this sign convention:

- negative ΔΔG indicates predicted stabilization;
- positive ΔΔG indicates predicted destabilization;
- values close to zero indicate a comparatively small predicted energetic effect.

Rosetta REU values are not direct experimental thermodynamic measurements. When an approximate conversion is reported, this repository uses:

Approximate kcal/mol = REU / 2.94

This conversion is approximate and must be labeled accordingly.

## Mutation set

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

## Workflow overview

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

## Recommended repository structure

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

## Software environment

```text
Operating system: Windows 11 with WSL2
Linux distribution: Ubuntu 24.04
Rosetta : 3.15
Rosetta score function: ref2015_cart
Python: Python 3.12
```

Example environment variables:

```bash
export ROSETTA3="/soft/rosetta.binary.ubuntu.release-408/main/source"
export ROSETTA3_DB="/soft/rosetta.binary.ubuntu.release-408/main/database"
```

Locate the applications:

```bash
RELAX=$(find "$ROSETTA3/bin" -maxdepth 1 -name "relax*.linuxgccrelease" | grep -v mpi | head -n 1)
CARTDDG=$(find "$ROSETTA3/bin" -maxdepth 1 -name "cartesian_ddg*.linuxgccrelease" | grep -v mpi | head -n 1)
```

## 1. Prepare the input structure

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

## 2. Cartesian Relax

Generate 20 Cartesian-relaxed structures and select the model with the lowest Rosetta `total_score`.

```bash
"$RELAX"   -database "$ROSETTA3_DB"   -s input/processed/BhNIT_A_renumbered.pdb   -use_input_sc   -ignore_unrecognized_res   -nstruct 20   -score:weights ref2015_cart   -relax:min_type lbfgs_armijo_nonmonotone   -relax:script cart2.script   -fa_max_dis 9.0   -run:constant_seed   -run:jran 4082026   -out:path:all relax/models   -out:file:scorefile score.sc   2>&1 | tee logs/cartesian_relax.log
```

For the Rosetta binary release used in this workflow, the score function is specified with:

```text
-score:weights ref2015_cart
```

The option `-relax:cartesian-score:weights` was not recognized by that executable and is not used.

### cart2.script

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

## 3. Generate independent mutfiles

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

## 4. Cartesian_ddG calculations

Each mutation is evaluated using three forced Cartesian_ddG iterations.

```bash
"$CARTDDG"   -database "$ROSETTA3_DB"   -s input/processed/BhNIT_A_best_relaxed.pdb   -ddg::mut_file mutfiles/W59A.mut   -ddg::iterations 3   -ddg::force_iterations true   -ddg::cartesian true   -ddg::dump_pdbs false   -ddg::bbnbrs 1   -ddg::frag_nbrs 2   -ddg::flex_bb false   -ddg::legacy false   -score:weights ref2015_cart   -fa_max_dis 9.0   -ignore_zero_occupancy false   -missing_density_to_jump   -run:constant_seed   -run:jran 408001
```

The command is repeated for all 22 substitutions using independent mutfiles and mutation-specific seeds.

## Parameters and random seeds

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

### cart2.script minimization parameters

| Stage | `fa_rep` scale | Tolerance | Constraint scale | Maximum cycles |
|---:|---:|---:|---:|---:|
| 1 | 0.02 | 0.01 | 1.0 | 50 |
| 2 | 0.25 | 0.01 | 0.5 | 50 |
| 3 | 0.55 | 0.01 | 0.0 | 100 |
| 4 | 1.00 | 0.00001 | 0.0 | 200 |

### Cartesian_ddG parameters

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

### Mutation-specific seeds

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

### Convergence-related settings

Rosetta also exposes options such as `ddg::score_cutoff` and `ddg::n_converged`. In this workflow:

```text
ddg::iterations = 3
ddg::force_iterations = true
```

Therefore, all three iterations are completed for every mutation and convergence settings are not used to terminate calculations early.

### ΔΔG screening threshold

No pre-defined Rosetta ΔΔG cutoff was applied before or during the calculations. All 22 substitutions were calculated and retained for relative ranking and cross-method comparison with FoldX, EVmutation, structural analysis, and experimental evidence.

## 5. Parse Rosetta output

The Rosetta release used here writes records such as:

```text
COMPLEX: Round1: WT_: -1613.128 ...
COMPLEX: Round1: MUT_59ALA: -1517.785 ...
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

## 6. Output files

### Long-format file

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

### Summary file

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

## 7. Quality-control checks

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

## 8. Reproducibility metadata

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


## 9. Files recommended for GitHub deposition

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

## 10. Limitations

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
