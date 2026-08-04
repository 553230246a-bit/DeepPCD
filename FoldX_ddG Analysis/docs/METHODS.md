# FoldX Methods

The input protein structure was first optimized using the `RepairPDB` command implemented in FoldX. The effects of 22 individual amino acid substitutions on predicted protein folding stability were subsequently evaluated using the `BuildModel` command. Each mutation was modeled independently in three runs. The time-based rotamer seed was disabled (`timeSeedRotabase=false`) to improve reproducibility, and mutant PDB output was disabled (`out-pdb=false`) to reduce unnecessary intermediate files. All other FoldX parameters were retained at their default settings.

The FoldX mutation definitions were supplied in an `individual_list.txt` file, with one independent mutation per line. The reported energy difference was interpreted as:

```text
ΔΔG = ΔG_mutant − ΔG_wild type
```

Negative ΔΔG values indicated predicted stabilization, whereas positive values indicated predicted destabilization. For each mutation, the mean, standard deviation, minimum, and maximum ΔΔG values were calculated from the three FoldX runs. No ΔΔG cutoff was used during FoldX calculation.
