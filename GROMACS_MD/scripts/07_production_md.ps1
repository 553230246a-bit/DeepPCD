$ErrorActionPreference = "Stop"

$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

New-Item -ItemType Directory ".\md" -Force | Out-Null

& $GMX grompp `
    -f ".\mdp\md.mdp" `
    -c ".\npt\npt.gro" `
    -t ".\npt\npt.cpt" `
    -p ".\topology\topol.top" `
    -n ".\topology\index.ndx" `
    -o ".\md\md.tpr" `
    2>&1 | Tee-Object ".\logs\grompp_md.log"

& $GMX mdrun `
    -deffnm ".\md\md" `
    2>&1 | Tee-Object ".\logs\mdrun_md.log"
