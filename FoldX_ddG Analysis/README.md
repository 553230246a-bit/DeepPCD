# Reproducible FoldX ΔΔG Analysis of 22 Independent Single-Point Mutations

This repository contains the complete Windows 11 workflow used to calculate the predicted effects of 22 independent amino acid substitutions on protein folding stability with FoldX. It was prepared to support reproducibility for an ACS Synthetic Biology manuscript. Each mutation is modeled independently in three FoldX runs.

> FoldX itself is not included because it is distributed under its own license. Users must obtain the Windows executable separately and comply with the FoldX license terms.

## Mutation set

```text
WA59A;
VA94A;
LA99I;
LA105Y;
GA121D;
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
FA255R;
PA272E;
TA306L;
NA311D;
AA336E;
```

Each line represents one independent single-point mutation on chain `A`. Do not combine the mutations with commas.

## Software requirements

- Windows 11
- FoldX 5.1
- Python 3.9 or later

## Input structure

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

## Validate the mutation file

```bat
python scripts\check_mutations.py mutations\individual_list.txt
```

Expected output:

```text
Validated 22 unique single-point mutations.
```

## Run the workflow

### CMD

```bat
scripts\run_foldx.cmd "D:\FoldX\foldx.exe" "data\input\BhNIT.pdb" 3 BhNIT_22_single
```

### PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts\run_foldx.ps1 `
  -FoldXPath "D:\FoldX\foldx.exe" `
  -PdbPath "data\input\BhNIT.pdb" `
  -Runs 3 `
  -OutputName "BhNIT_22_single"
```

## Exact FoldX commands

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

## ΔΔG convention

```text
ΔΔG = ΔG_mutant − ΔG_wild type
```

Negative values indicate predicted stabilization, whereas positive values indicate predicted destabilization.

## Expected output

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

## Files to upload for ACS Synthetic Biology reproducibility

Upload the exact mutation list, final input PDB when redistribution is permitted, repaired PDB when redistribution is permitted, all scripts, parameter configuration, software-version record, raw FoldX `.fxout` files, execution log, long-format ΔΔG table, summary table, methods documentation, and result-interpretation documentation.


This template does not contain fabricated ΔΔG values. Actual result files must be generated using the structure used in the manuscript.
