# Computational command-line templates for DeepPCD-guided BhNIT engineering

This repository provides representative command-line templates and file organization for reproducing the computational steps involving FoldX, Rosetta Cartesian_ddG, EVmutation, and GROMACS molecular dynamics simulations used in the DeepPCD-guided engineering of BhNIT.

These commands are intended as reproducibility templates. Paths, executable names, residue numbering, input structures, random seeds, index groups, and simulation parameters should be replaced with the exact files and values used in the final deposited dataset.

## 1. Repository structure

```bash
DeepPCD_BhNIT_computation/
├── README.md
├── environment/
│   ├── software_versions.txt
│   └── random_seeds.txt
├── input_structures/
│   ├── BhNIT_WT.pdb
│   ├── BhNIT_WT_repaired.pdb
│   ├── BhNIT_3,5-DCPN_complex.pdb
│   ├── M3-GGA_3,5-DCPN_complex.pdb
│   └── M5-GGAEM_3,5-DCPN_complex.pdb
├── mutations/
│   ├── candidate_mutations_all.csv
│   ├── foldx_individual_list.txt
│   ├── rosetta_mutfiles/
│   └── evmutation_mutation_list.txt
├── foldx/
│   ├── input/
│   ├── output/
│   └── foldx_ddg_summary.csv
├── cartesian_ddg/
│   ├── relaxed_structures/
│   ├── mutfiles/
│   ├── output/
│   └── cartesian_ddg_summary.csv
├── evmutation/
│   ├── alignment/
│   ├── config/
│   ├── output/
│   └── evmutation_scores.csv
├── gromacs/
│   ├── mdp_files/
│   ├── ligand_topology/
│   ├── WT_310K/
│   ├── WT_323K/
│   ├── WT_acidic_stress/
│   ├── M3-GGA/
│   ├── M5-GGAEM/
│   └── analysis/
└── scripts/
    ├── summarize_foldx_results.py
    ├── summarize_cartesian_ddg_results.py
    ├── summarize_ddg_intersection.py
    ├── run_gromacs_pipeline.sh
    ├── analyze_gromacs_trajectory.sh
    └── calculate_key_distances.sh
```

## 2. Software versions

Please record the exact versions used locally in `environment/software_versions.txt`.

```text
FoldX version: [REPLACE_WITH_VERSION]
Rosetta version: [REPLACE_WITH_VERSION]
EVmutation / EVcouplings version: [REPLACE_WITH_VERSION]
GROMACS version: 2020
AmberTools version: 2021
ACPYPE version: [REPLACE_WITH_VERSION]
Python version: [REPLACE_WITH_VERSION]
```

If a stochastic tool allowed user-defined random seeds, record them in `environment/random_seeds.txt`.

```text
FoldX random seed: not applicable or not user-defined
Rosetta random seed: [REPLACE_WITH_SEED_IF_SET]
EVmutation random seed: [REPLACE_WITH_SEED_IF_SET]
GROMACS gen_seed: [REPLACE_WITH_SEED_IF_SET]
```

If a seed was not explicitly set or not user-accessible, do not invent one. Instead, deposit the exact input files and raw output files.

---

# 3. FoldX ΔΔG calculation

## 3.1 Input files

Required files:

```text
input_structures/BhNIT_WT.pdb
mutations/foldx_individual_list.txt
```

Example `mutations/foldx_individual_list.txt`:

```text
WA59A;
VA94A;
LA99I;
LA105Y;
TA136G;
WA168G;
PA173E;
LA196Y;
AA203M;
NA209R;
NA210P;
SA213T;
CA228T;
TA230V;
LA239F;
DA244E;
AA255R;
PA272E;
TA306L;
```

Note: The exact mutation format may depend on the installed FoldX version. Please check whether your local FoldX installation requires chain identifiers.

## 3.2 Repair input structure

```bash
mkdir -p foldx/input foldx/output

cp input_structures/BhNIT_WT.pdb foldx/input/

foldx \
  --command=RepairPDB \
  --pdb=BhNIT_WT.pdb \
  --pdb-dir=foldx/input/ \
  --output-dir=foldx/output/
```

Expected output:

```text
foldx/output/BhNIT_WT_Repair.pdb
```

## 3.3 BuildModel ΔΔG calculation

FoldX calculations were performed using default parameters, and each mutation was evaluated in triplicate.

```bash
foldx \
  --command=BuildModel \
  --pdb=BhNIT_WT_Repair.pdb \
  --pdb-dir=foldx/output/ \
  --mutant-file=mutations/foldx_individual_list.txt \
  --numberOfRuns=3 \
  --output-dir=foldx/output/
```

## 3.4 Summarize FoldX output

```bash
python scripts/summarize_foldx_results.py \
  --foldx_dir foldx/output/ \
  --out foldx/foldx_ddg_summary.csv
```

Recommended output columns:

```text
Mutation
Run_1_ddG
Run_2_ddG
Run_3_ddG
Mean_ddG
SD_ddG
Prediction
```

Recommended decision rule:

```text
Mutations with negative or near-neutral ΔΔG values can be considered potentially stabilizing or stability-compatible.
The exact cutoff should be reported explicitly.
```

---

# 4. Rosetta Cartesian_ddG calculation

## 4.1 Input files

Required files:

```text
input_structures/BhNIT_WT.pdb
mutations/rosetta_mutfiles/
```

Example mutation file for W59A:

File name:

```text
mutations/rosetta_mutfiles/mutfile_W59A.txt
```

Content:

```text
total 1
1
W 59 A
```

If chain identifiers are required by the local Rosetta setup, please adjust the mutfile format accordingly.

## 4.2 Cartesian relax before ddG calculation

```bash
mkdir -p cartesian_ddg/relaxed_structures
mkdir -p cartesian_ddg/output

relax.default.linuxgccrelease \
  -s input_structures/BhNIT_WT.pdb \
  -relax:cartesian \
  -score:weights ref2015_cart \
  -nstruct 5 \
  -out:path:all cartesian_ddg/relaxed_structures/
```

Select the best relaxed model according to the Rosetta total score and rename it:

```bash
cp cartesian_ddg/relaxed_structures/[BEST_RELAXED_MODEL].pdb \
   cartesian_ddg/relaxed_structures/BhNIT_WT_relaxed.pdb
```

## 4.3 Run Cartesian_ddG for one mutation

Example for W59A:

```bash
mkdir -p cartesian_ddg/output/W59A

cartesian_ddg.default.linuxgccrelease \
  -s cartesian_ddg/relaxed_structures/BhNIT_WT_relaxed.pdb \
  -ddg:mut_file mutations/rosetta_mutfiles/mutfile_W59A.txt \
  -ddg:iterations 3 \
  -ddg::cartesian \
  -score:weights ref2015_cart \
  -fa_max_dis 9.0 \
  -ddg::dump_pdbs true \
  -out:prefix W59A_ \
  -out:path:all cartesian_ddg/output/W59A/
```

## 4.4 Batch run Cartesian_ddG

```bash
for MUTFILE in mutations/rosetta_mutfiles/*.txt
do
  BASENAME=$(basename "${MUTFILE}" .txt)
  OUTDIR=cartesian_ddg/output/${BASENAME}
  mkdir -p "${OUTDIR}"

  cartesian_ddg.default.linuxgccrelease \
    -s cartesian_ddg/relaxed_structures/BhNIT_WT_relaxed.pdb \
    -ddg:mut_file "${MUTFILE}" \
    -ddg:iterations 3 \
    -ddg::cartesian \
    -score:weights ref2015_cart \
    -fa_max_dis 9.0 \
    -ddg::dump_pdbs true \
    -out:prefix "${BASENAME}_" \
    -out:path:all "${OUTDIR}/"
done
```

## 4.5 Summarize Cartesian_ddG output

```bash
python scripts/summarize_cartesian_ddg_results.py \
  --cartesian_ddg_dir cartesian_ddg/output/ \
  --out cartesian_ddg/cartesian_ddg_summary.csv
```

Recommended output columns:

```text
Mutation
Rosetta_ddG
Mean_score_WT
Mean_score_MUT
Prediction
```

---

# 5. EVmutation analysis

## 5.1 Input files

Required files:

```text
evmutation/alignment/BhNIT_homologs_aligned.a2m
evmutation/config/evmutation_config.yml
mutations/evmutation_mutation_list.txt
```

Example `mutations/evmutation_mutation_list.txt`:

```text
W59A
V94A
L99I
L105Y
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
A255R
P272E
T306L
```

Note: If the original output contains an ambiguous mutation label, verify the residue numbering against the wild-type BhNIT sequence before deposition.

## 5.2 Example EVmutation configuration

Example file:

```text
evmutation/config/evmutation_config.yml
```

Template content:

```yaml
global:
  prefix: BhNIT_EVmutation
  sequence_id: BhNIT
  region: [1, 310]
  theta: 0.8

align:
  input_alignment: evmutation/alignment/BhNIT_homologs_aligned.a2m

couplings:
  protocol: standard
  iterations: 100
  lambda_h: 0.01
  lambda_J: 0.01

mutations:
  mutation_file: mutations/evmutation_mutation_list.txt

output:
  directory: evmutation/output/
```

The exact configuration should be replaced with the real configuration used for the EVmutation analysis.

## 5.3 Run EVmutation / EVcouplings-compatible workflow

```bash
mkdir -p evmutation/output

evcouplings_runcfg \
  evmutation/config/evmutation_config.yml
```

## 5.4 Summarize EVmutation scores

Expected output:

```text
evmutation/output/mutation_effect_prediction.csv
```

Copy or convert the result to:

```bash
cp evmutation/output/mutation_effect_prediction.csv \
   evmutation/evmutation_scores.csv
```

Recommended output columns:

```text
Mutation
EVmutation_score
Prediction
```

Recommended interpretation:

```text
Mutations with favorable or less deleterious EVmutation scores can be considered evolutionarily compatible.
The scoring direction and threshold should be stated according to the EVmutation implementation used.
```

---

# 6. Integration of FoldX, Cartesian_ddG, and EVmutation results

The three methods were used to reduce method-specific false positives. Mutations consistently supported by the three methods were retained for further prioritization.

## 6.1 Required files

```text
foldx/foldx_ddg_summary.csv
cartesian_ddg/cartesian_ddg_summary.csv
evmutation/evmutation_scores.csv
```

## 6.2 Intersection analysis

```bash
python scripts/summarize_ddg_intersection.py \
  --foldx foldx/foldx_ddg_summary.csv \
  --cartesian_ddg cartesian_ddg/cartesian_ddg_summary.csv \
  --evmutation evmutation/evmutation_scores.csv \
  --out mutations/candidate_mutations_intersection.csv
```

Recommended output columns:

```text
Mutation
FoldX_prediction
Cartesian_ddG_prediction
EVmutation_prediction
Supported_by_all_three_methods
Final_decision
```

---

# 7. GROMACS molecular dynamics simulations

## 7.1 Simulation settings

The following MD settings were used as the basis for the GROMACS simulations.

```text
GROMACS version: 2020
Protein force field: Amber99SB-ILDN
Ligand force field: GAFF2
Ligand topology generation: AmberTools 2021 and ACPYPE
Water model: TIP3P
Box type: dodecahedron
Minimum distance to box edge: 10 Å
Neutralizing ion: Na+
Energy minimization: steepest descent, 5000 steps
NVT equilibration: 100 ps
NPT equilibration: 100 ps
Production simulation: 100 ns
Temperature conditions: 310 K and 323 K
```

## 7.2 Required input files

```text
input_structures/BhNIT_3,5-DCPN_complex.pdb
input_structures/M3-GGA_3,5-DCPN_complex.pdb
input_structures/M5-GGAEM_3,5-DCPN_complex.pdb
gromacs/mdp_files/ions.mdp
gromacs/mdp_files/minim.mdp
gromacs/mdp_files/nvt_100ps.mdp
gromacs/mdp_files/npt_100ps.mdp
gromacs/mdp_files/md_100ns_310K.mdp
gromacs/mdp_files/md_100ns_323K.mdp
gromacs/ligand_topology/
```

## 7.3 Ligand topology generation using AmberTools and ACPYPE

Example for 3,5-DCPN:

```bash
mkdir -p gromacs/ligand_topology

acpype \
  -i ligand/3,5-DCPN.pdb \
  -b DCPN \
  -a gaff2 \
  -c bcc \
  -o gmx
```

Copy the generated ligand topology files to:

```bash
cp DCPN.acpype/* gromacs/ligand_topology/
```

The ligand `.itp`, `.gro`, and parameter files should be included in the deposited repository.

## 7.4 General GROMACS workflow

The following example uses the WT BhNIT–3,5-DCPN complex at 310 K. The same workflow can be repeated for WT at 323 K and for mutant complexes.

```bash
SYSTEM=WT_310K
INPUT_PDB=input_structures/BhNIT_3,5-DCPN_complex.pdb
WORKDIR=gromacs/${SYSTEM}

mkdir -p ${WORKDIR}

gmx pdb2gmx \
  -f ${INPUT_PDB} \
  -o ${WORKDIR}/processed.gro \
  -p ${WORKDIR}/topol.top \
  -ff amber99sb-ildn \
  -water tip3p \
  -ignh
```

After `pdb2gmx`, manually include the ligand topology in `topol.top` if needed:

```text
#include "../ligand_topology/DCPN.itp"
```

Also add the ligand molecule count under `[ molecules ]`.

## 7.5 Define box and solvate

```bash
gmx editconf \
  -f ${WORKDIR}/processed.gro \
  -o ${WORKDIR}/boxed.gro \
  -bt dodecahedron \
  -d 1.0

gmx solvate \
  -cp ${WORKDIR}/boxed.gro \
  -cs spc216.gro \
  -o ${WORKDIR}/solvated.gro \
  -p ${WORKDIR}/topol.top
```

## 7.6 Add neutralizing ions

```bash
gmx grompp \
  -f gromacs/mdp_files/ions.mdp \
  -c ${WORKDIR}/solvated.gro \
  -p ${WORKDIR}/topol.top \
  -o ${WORKDIR}/ions.tpr \
  -maxwarn 1

echo "SOL" | gmx genion \
  -s ${WORKDIR}/ions.tpr \
  -o ${WORKDIR}/solvated_ions.gro \
  -p ${WORKDIR}/topol.top \
  -pname NA \
  -neutral
```

## 7.7 Energy minimization

```bash
gmx grompp \
  -f gromacs/mdp_files/minim.mdp \
  -c ${WORKDIR}/solvated_ions.gro \
  -p ${WORKDIR}/topol.top \
  -o ${WORKDIR}/em.tpr \
  -maxwarn 1

gmx mdrun \
  -deffnm ${WORKDIR}/em
```

## 7.8 NVT equilibration

```bash
gmx grompp \
  -f gromacs/mdp_files/nvt_100ps.mdp \
  -c ${WORKDIR}/em.gro \
  -r ${WORKDIR}/em.gro \
  -p ${WORKDIR}/topol.top \
  -o ${WORKDIR}/nvt.tpr \
  -maxwarn 1

gmx mdrun \
  -deffnm ${WORKDIR}/nvt
```

## 7.9 NPT equilibration

```bash
gmx grompp \
  -f gromacs/mdp_files/npt_100ps.mdp \
  -c ${WORKDIR}/nvt.gro \
  -t ${WORKDIR}/nvt.cpt \
  -r ${WORKDIR}/nvt.gro \
  -p ${WORKDIR}/topol.top \
  -o ${WORKDIR}/npt.tpr \
  -maxwarn 1

gmx mdrun \
  -deffnm ${WORKDIR}/npt
```

## 7.10 Production MD

For 310 K:

```bash
gmx grompp \
  -f gromacs/mdp_files/md_100ns_310K.mdp \
  -c ${WORKDIR}/npt.gro \
  -t ${WORKDIR}/npt.cpt \
  -p ${WORKDIR}/topol.top \
  -o ${WORKDIR}/md_100ns.tpr \
  -maxwarn 1

gmx mdrun \
  -deffnm ${WORKDIR}/md_100ns
```

For 323 K, change the MDP file:

```bash
gmx grompp \
  -f gromacs/mdp_files/md_100ns_323K.mdp \
  -c ${WORKDIR}/npt.gro \
  -t ${WORKDIR}/npt.cpt \
  -p ${WORKDIR}/topol.top \
  -o ${WORKDIR}/md_100ns.tpr \
  -maxwarn 1

gmx mdrun \
  -deffnm ${WORKDIR}/md_100ns
```

## 7.11 Acidic stress simulations

If acidic stress simulations were performed by assigning predefined protonation states, deposit the pH-specific structures and protonation assignment files.

Recommended files:

```text
gromacs/WT_acidic_stress/protonation_assignment.txt
gromacs/WT_acidic_stress/BhNIT_3,5-DCPN_acidic_protonation.pdb
```

Use the same GROMACS workflow described above for minimization, equilibration, and production simulation.

Important note:

```text
Unless constant-pH molecular dynamics was actually performed, these simulations should be described as protonation-state-defined acidic stress simulations rather than constant-pH MD simulations.
```

## 7.12 Trajectory analysis

Create an analysis directory:

```bash
mkdir -p gromacs/analysis
```

RMSD:

```bash
echo "Backbone Backbone" | gmx rms \
  -s ${WORKDIR}/md_100ns.tpr \
  -f ${WORKDIR}/md_100ns.xtc \
  -o gromacs/analysis/${SYSTEM}_rmsd_backbone.xvg
```

RMSF:

```bash
echo "Protein" | gmx rmsf \
  -s ${WORKDIR}/md_100ns.tpr \
  -f ${WORKDIR}/md_100ns.xtc \
  -res \
  -o gromacs/analysis/${SYSTEM}_rmsf_residue.xvg
```

Radius of gyration:

```bash
echo "Protein" | gmx gyrate \
  -s ${WORKDIR}/md_100ns.tpr \
  -f ${WORKDIR}/md_100ns.xtc \
  -o gromacs/analysis/${SYSTEM}_rg.xvg
```

Solvent-accessible surface area:

```bash
echo "Protein" | gmx sasa \
  -s ${WORKDIR}/md_100ns.tpr \
  -f ${WORKDIR}/md_100ns.xtc \
  -o gromacs/analysis/${SYSTEM}_sasa.xvg
```

Hydrogen bonds:

```bash
echo "Protein Protein" | gmx hbond \
  -s ${WORKDIR}/md_100ns.tpr \
  -f ${WORKDIR}/md_100ns.xtc \
  -num gromacs/analysis/${SYSTEM}_hbond_protein.xvg
```

## 7.13 Catalytic distance analysis

Create index groups for the catalytic atoms and ligand atoms:

```bash
gmx make_ndx \
  -f ${WORKDIR}/md_100ns.tpr \
  -o gromacs/analysis/${SYSTEM}_index.ndx
```

Example distance between catalytic Cys167 sulfur and the nitrile carbon/nitrogen group of 3,5-DCPN:

```bash
gmx distance \
  -s ${WORKDIR}/md_100ns.tpr \
  -f ${WORKDIR}/md_100ns.xtc \
  -n gromacs/analysis/${SYSTEM}_index.ndx \
  -select 'com of group "Cys167_SG" plus com of group "Ligand_CN"' \
  -oall gromacs/analysis/${SYSTEM}_Cys167_ligand_CN_distance.xvg
```

Example distance related to Glu48 and the substrate nitrile group:

```bash
gmx distance \
  -s ${WORKDIR}/md_100ns.tpr \
  -f ${WORKDIR}/md_100ns.xtc \
  -n gromacs/analysis/${SYSTEM}_index.ndx \
  -select 'com of group "Glu48_OE1" plus com of group "Ligand_CN"' \
  -oall gromacs/analysis/${SYSTEM}_Glu48_ligand_CN_distance.xvg
```

The atom-group names in the `-select` command must be replaced with the actual group names defined in the local index file.

---

# 8. Minimum files to deposit

The following files should be deposited to support reproducibility:

```text
1. Wild-type BhNIT structure used for FoldX and Cartesian_ddG
2. FoldX repaired structure
3. FoldX individual_list.txt
4. Raw FoldX output files and summarized ΔΔG table
5. Rosetta relaxed structure
6. Rosetta mutation files
7. Raw Cartesian_ddG output files and summarized ΔΔG table
8. EVmutation alignment file
9. EVmutation configuration file
10. EVmutation raw score table
11. Integrated FoldX/Cartesian_ddG/EVmutation mutation summary
12. GROMACS input structures for WT and mutants
13. Ligand topology generated using AmberTools/GAFF2/ACPYPE
14. GROMACS MDP files
15. GROMACS topology files
16. Initial, minimized, equilibrated, and production structure files
17. Representative trajectory files or reduced trajectories used for analysis
18. Analysis scripts for RMSD, RMSF, Rg, SASA, hydrogen bonds, and catalytic distances
19. Protonation assignment files for acidic stress simulations, if applicable
20. Software version file and random seed record
```

# 9. Notes

The commands provided here are templates for reproducibility and should be adapted to the local software installation. The exact input structures, mutation lists, topology files, MDP files, random seeds, and output tables used in the manuscript should be deposited together with this README.

The numerical thresholds and mutation-selection rules should be interpreted as task-specific filters for BhNIT engineering rather than universal constants for all enzymes.
