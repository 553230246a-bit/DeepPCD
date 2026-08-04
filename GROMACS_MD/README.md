# GROMACS Workflow for BhNIT–Ligand Molecular Dynamics at pH 5.5

## 1\. Scope

This repository documents a reproducible workflow for building, running, and analyzing a molecular dynamics simulation of a **BhNIT–ligand complex** using a **fixed protonation-state model representing pH 5.5**.

Example configuration:

* GROMACS 2020.6 on Windows
* AMBER99SB-ILDN protein force field
* TIP3P water
* GAFF2 and AM1-BCC ligand parameters
* Ligand: 3,5-dichloropyridine carbonitrile
* Temperature: 310.15 K when the experiment is performed at 37 °C
* Pressure: 1 bar
* Production simulation: 100 ns
* Stable-state analysis window: 80–100 ns

This is **not constant-pH MD**. Protonation states are assigned before topology generation and remain fixed throughout the simulation.

## 2\. Project-specific protonation model

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

## 3\. Software

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

## 4\. Project directory

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

## 5\. Protein topology

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

## 6\. Ligand topology

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
## 7\. Merge protein and ligand coordinates

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

## 8\. Box and solvation

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

## 9\. Ion addition

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

## 10\. Energy minimization

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

## 11\. Index groups

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

## 12\. NVT equilibration

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

## 13\. NPT equilibration

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

## 14\. Production MD

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

## 15\. Main parameters and random seeds

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

# Analysis workflow

## 16\. Analysis variables

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

## 17\. PBC correction and fitting

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

## 18\. Energy terms

```powershell
@("Temperature", "0") | \& $GMX energy -f $EDR -o "$ANA\\energy\\temperature.xvg"
@("Pressure", "0")    | \& $GMX energy -f $EDR -o "$ANA\\energy\\pressure.xvg"
@("Density", "0")     | \& $GMX energy -f $EDR -o "$ANA\\energy\\density.xvg"
@("Potential", "0")   | \& $GMX energy -f $EDR -o "$ANA\\energy\\potential.xvg"
```

## 19\. RMSD

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

## 20\. C-alpha RMSF over 80–100 ns

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

## 21\. Radius of gyration

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

## 23\. Protein–ligand hydrogen bonds

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

## 24\. Catalytic Cys–nitrile distance

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

## 25\. Extract representative structures

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

## 26\. Key outputs

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

## 27\. Interpretation notes

* RMSD has no universal stability cutoff.
* Compare RMSF using identical atom selections and time windows.
* Instantaneous pressure can fluctuate strongly; inspect means and trends.
* Stable ligand RMSD alone does not prove catalytic competence.
* MM/PBSA is an end-point binding-energy estimate, not a reaction barrier.

## 28\. Reproducibility checklist

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


