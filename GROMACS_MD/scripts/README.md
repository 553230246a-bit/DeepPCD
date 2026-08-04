# Simulation and Analysis Scripts

This folder contains scripts for molecular dynamics simulation and
trajectory analysis of the BhNIT-ligand complex.

## Included scripts

- `00_check_environment.ps1`
- `01_prepare_system.ps1`
- `02_merge_gro.py`
- `03_solvate_ions.ps1`
- `04_energy_minimization.ps1`
- `05_nvt_equilibration.ps1`
- `06_npt_equilibration.ps1`
- `07_production_md.ps1`
- `08_process_trajectory.ps1`
- `09_rmsd_analysis.ps1`
- `10_rmsf_analysis.ps1`
- `11_rg_analysis.ps1`
- `12_hbond_analysis.ps1`
- `13_selected_residue_rg.ps1`
- `summarize_residue_rg.py`
- `run_mmpbsa_80_100ns.sh`

## Notes

The pH 5.5 condition is represented through explicitly assigned
protonation states before the MD simulation.

The 80-100 ns trajectory segment is prepared for MM/PBSA analysis with
a 200 ps sampling interval.

Interactive GROMACS group selections should be verified against the
index file because group numbers can change when an index is regenerated.
