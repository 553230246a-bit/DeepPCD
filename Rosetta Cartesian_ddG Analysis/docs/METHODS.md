# Manuscript-Ready Methods

The effects of 22 independent amino acid substitutions on predicted protein folding stability were evaluated with the Rosetta Cartesian_ddG protocol under Windows Subsystem for Linux using Ubuntu 24.04. The selected protein chain was extracted from the input structure, non-protein `HETATM` records were removed, and standard amino-acid residues were renumbered continuously from 1. The identity of the wild-type residue at every mutation position was verified before calculation.

The prepared structure was preminimized in Cartesian space using the Rosetta `relax` application. Twenty relaxed structures were generated using the `ref2015_cart` score function, the Cartesian Relax script supplied in the repository, `fa_max_dis = 9.0`, and a fixed random seed. The relaxed model with the lowest Rosetta `total_score` was selected as the common input for subsequent mutational calculations. In the installed Rosetta release-408 build, the general `-score:weights ref2015_cart` option was used because `-relax:cartesian-score:weights` was not recognized by that executable.

Each substitution was represented by an independent Rosetta mutfile and was evaluated separately with `cartesian_ddg`. Three refinement iterations were performed per mutation using `ref2015_cart`, `fa_max_dis = 9.0`, `ddg::bbnbrs = 1`, `ddg::frag_nbrs = 2`, `ddg::flex_bb = false`, and `ddg::legacy = false`. `ddg::force_iterations = true` was used to ensure that all three requested iterations were completed. Fixed mutation-specific random seeds were used to facilitate reproducibility.

For each mutation, ΔΔG was calculated as the mean mutant total score minus the mean wild-type total score across the three iterations:

```text
ΔΔG = mean(E_mutant) - mean(E_wild type)
```

Negative values indicated predicted stabilization, whereas positive values indicated predicted destabilization. Results were reported in Rosetta energy units. Approximate values in kcal/mol were additionally calculated by dividing the Rosetta energy-unit value by 2.94, following the Cartesian_ddG documentation. All scripts, mutation definitions, raw `.ddg` output files, logs, processed tables, fixed seeds, and software metadata were deposited in the associated GitHub repository.
