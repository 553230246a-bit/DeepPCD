$ErrorActionPreference = "Stop"

$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

New-Item -ItemType Directory ".\nvt" -Force | Out-Null

& $GMX grompp `
    -f ".\mdp\nvt.mdp" `
    -c ".\em\em.gro" `
    -r ".\em\em.gro" `
    -p ".\topology\topol.top" `
    -n ".\topology\index.ndx" `
    -o ".\nvt\nvt.tpr" `
    2>&1 | Tee-Object ".\logs\09_grompp_nvt.log"

& $GMX mdrun `
    -deffnm ".\nvt\nvt" `
    2>&1 | Tee-Object ".\logs\mdrun_nvt.log"
