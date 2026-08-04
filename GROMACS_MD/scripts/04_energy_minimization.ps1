$ErrorActionPreference = "Stop"

$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

New-Item -ItemType Directory ".\em" -Force | Out-Null

& $GMX grompp `
    -f ".\mdp\em.mdp" `
    -c ".\topology\complex_ions.gro" `
    -p ".\topology\topol.top" `
    -o ".\em\em.tpr" `
    2>&1 | Tee-Object ".\logs\grompp_em.log"

& $GMX mdrun `
    -deffnm ".\em\em" `
    2>&1 | Tee-Object ".\logs\mdrun_em.log"
