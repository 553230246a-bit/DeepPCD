# Copy this file to config.sh before running:
# cp config.example.sh config.sh

export ROSETTA3="/soft/rosetta.binary.ubuntu.release-408/main/source"
export ROSETTA3_DB="/soft/rosetta.binary.ubuntu.release-408/main/database"
export INPUT_PDB="$PROJECT_ROOT/data/input/BhNIT.pdb"

export TARGET_CHAIN="A"
export RELAX_NSTRUCT=20
export DDG_ITERATIONS=3

export RELAX_SEED=4082026
export DDG_SEED_BASE=408000

export FORCE_RELAX=0
export FORCE_DDG=0
