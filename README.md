# DeepPCD: Reproducible Computational Workflow for Protein Engineering

## Overview

This repository contains the complete computational workflow developed for the DeepPCD strategy.


The repository provides computational artifacts, executable scripts, parameters, and workflow organization required to reproduce the major computational analyses.

---

## Repository Organization

```
DeepPCD/

├── README.md
├── ProteinMPNN/

├── FoldX/
│   ├── scripts/
│   ├── mutations/
│   ├── results/
│   └── README.md

├── Rosetta/
│   ├── scripts/
│   ├── mutfiles/
│   ├── results/
│   └── README.md

├── EVmutation/
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
    └── cutoffs and random_seeds.xlsx
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

Detailed workflow:

```
FoldX/README.md
```

---

## Rosetta Cartesian_ddG Module

Rosetta provides an independent stability prediction workflow.

Workflow:

```
Input structure
      |
Cartesian Relax
      |
Best relaxed structure
      |
Mutation-specific mutfiles
      |
Cartesian_ddG
      |
ΔΔG ranking
```

Parameters:

- ref2015_cart score function
- 20 relaxed structures
- 3 ddG iterations per mutation

Detailed workflow:

```
Rosetta/README.md
```

---

## EVmutation Module

EVmutation calculates evolutionary statistical energy differences.

Workflow:

```
BhNIT sequence
      |
Homolog search
      |
MSA construction
      |
plmc model
      |
ΔE calculation
      |
Mutation ranking
```

ΔE values are used for relative ranking within the BhNIT-specific model.

Detailed workflow:

```
EVmutation/README.md
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

Detailed workflow:

```
GROMACS_MD/README.md
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
