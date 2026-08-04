$ErrorActionPreference = "Stop"

$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

New-Item -ItemType Directory ".\npt" -Force | Out-Null

& $GMX grompp `
    -f ".\mdp\npt.mdp" `
    -c ".\nvt\nvt.gro" `
    -r ".\nvt\nvt.gro" `
    -t ".\nvt\nvt.cpt" `
    -p ".\topology\topol.top" `
    -n ".\topology\index.ndx" `
    -o ".\npt\npt.tpr" `
    2>&1 | Tee-Object ".\logs\grompp_npt.log"

& $GMX mdrun `
    -deffnm ".\npt\npt" `
    2>&1 | Tee-Object ".\logs\mdrun_npt.log"
