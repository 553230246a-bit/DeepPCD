# MM/PBSA Binding Free Energy Calculation Using g_mmpbsa

## Overview

This repository contains the complete workflow used to calculate the binding free energy between **BhNIT** and its ligand using **g_mmpbsa** after molecular dynamics (MD) simulations performed with **GROMACS 2020.6**.

The workflow includes:

- Selection of equilibrated MD trajectories
- Extraction of representative frames
- Molecular mechanics (MM) energy calculation
- Polar solvation energy calculation (Poisson–Boltzmann)
- Nonpolar solvation energy calculation (SASA model)
- Total binding free energy estimation
- Per-residue energy decomposition

---

# Software Requirements

| Software | Version |
|-----------|----------|
| GROMACS | 2020.6 |
| g_mmpbsa | 3.0.13 |
| Python | ≥3.10 |
| Ubuntu (WSL2) | 24.04 LTS |

---

# Repository Structure

```
MM_PBSA/
│
├── md/
│   ├── md.tpr
│   └── md.xtc
│
├── topology/
│   ├── topol.top
│   └── index_mmpbsa.ndx
│
├── mdp/
│   ├── polar.mdp
│   └── apolar_sasa.mdp
│
├── results/
│   ├── energy_MM_80_100ns.xvg
│   ├── polar_80_100ns.xvg
│   ├── apolar_80_100ns.xvg
│   ├── summary_energy_80_100ns.csv
│   ├── summary_energy_80_100ns.dat
│   ├── full_energy_80_100ns.dat
│   ├── residue_contribution_80_100ns.dat
│   └── logs/
│
└── README.md
```

---

# Input Files

The following files are required before starting the MM/PBSA calculation.

```
md/md.tpr
md/md.xtc
topology/topol.top
topology/index_mmpbsa.ndx
mdp/polar.mdp
mdp/apolar_sasa.mdp
```

---

# Step 1. Extract Equilibrated Trajectory

Trajectory analysis indicated that the MD simulation reached equilibrium between **80 ns and 100 ns**.

Frames were extracted every **200 ps**.

```bash
gmx trjconv \
-f md/md.xtc \
-s md/md.tpr \
-o md/md_80_100ns.xtc \
-b 80000 \
-e 100000 \
-dt 200
```

---

# Step 2. Molecular Mechanics Energy

```bash
g_mmpbsa run \
-f md/md_80_100ns.xtc \
-s md/md.tpr \
-n topology/index_mmpbsa.ndx \
-i mdp/polar.mdp \
-pdie 2
```

Generated files

```
01_molecular_mechanics.log

energy_MM_80_100ns.xvg

contribution_MM_80_100ns.dat
```

---

# Step 3. Polar Solvation Energy

```bash
g_mmpbsa run \
-pbsa \
-i mdp/polar.mdp
```

Generated files

```
02_polar_solvation.log

polar_80_100ns.xvg

contribution_polar_80_100ns.dat
```

---

# Step 4. Nonpolar Solvation Energy

```bash
g_mmpbsa run \
-apol sasa \
-i mdp/apolar_sasa.mdp
```

Generated files

```
03_apolar_solvation.log

apolar_80_100ns.xvg

contribution_apolar_80_100ns.dat
```

---

# Step 5. Calculate Average Binding Energy

```bash
g_mmpbsa average
```

Generated files

```
04_average_energy.log

summary_energy_80_100ns.dat

summary_energy_80_100ns.csv

full_energy_80_100ns.dat
```

---

# Step 6. Residue Energy Decomposition

```bash
g_mmpbsa decompose
```

Generated files

```
residue_contribution_80_100ns.dat

residue_contribution.csv
```

---

# Energy Components

The final binding free energy is calculated as

```
ΔGbinding

=

ΔEMM

+

ΔGpolar

+

ΔGnonpolar
```

where

- ΔEMM = van der Waals + electrostatic interaction
- ΔGpolar = Poisson–Boltzmann solvation energy
- ΔGnonpolar = solvent accessible surface area (SASA) contribution

---

# Parameters Used

| Parameter | Value |
|------------|--------|
| Equilibrated trajectory | 80–100 ns |
| Sampling interval | 200 ps |
| Number of frames | 101 |
| Polar model | Poisson–Boltzmann |
| Nonpolar model | SASA |
| Protein dielectric constant | 2 |
| Solvent dielectric constant | 80 |
| Temperature | 310 K |

---

# Output Files

The following files are generated.

```
energy_MM_80_100ns.xvg

polar_80_100ns.xvg

apolar_80_100ns.xvg

summary_energy_80_100ns.csv

summary_energy_80_100ns.dat

full_energy_80_100ns.dat

contribution_MM_80_100ns.dat

contribution_polar_80_100ns.dat

contribution_apolar_80_100ns.dat

residue_contribution_80_100ns.dat
```

---

# Random Seeds

Unlike molecular dynamics simulations, **g_mmpbsa does not generate random numbers during MM/PBSA calculations**.

Therefore,

**No random seed is required for MM/PBSA calculations.**

The calculated binding energies are deterministic provided that identical are used.

- trajectories
- topology files
- index groups
- MDP parameter files
---

# Reproducibility

The calculations can be fully reproduced using

- GROMACS 2020.6
- g_mmpbsa
- Production MD trajectory
- Topology file
- Index file
- `polar.mdp`
- `apolar_sasa.mdp`

and executing the commands described above.

---
