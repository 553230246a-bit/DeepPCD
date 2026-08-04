$ErrorActionPreference = "Stop"

$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

& $GMX editconf `
    -f ".\topology\complex.gro" `
    -o ".\topology\complex_box.gro" `
    -c `
    -d 1.0 `
    -bt cubic

& $GMX solvate `
    -cp ".\topology\complex_box.gro" `
    -cs spc216.gro `
    -o ".\topology\complex_solv.gro" `
    -p ".\topology\topol.top"

& $GMX grompp `
    -f ".\mdp\ions.mdp" `
    -c ".\topology\complex_solv.gro" `
    -p ".\topology\topol.top" `
    -o ".\topology\ions.tpr" `
    2>&1 | Tee-Object ".\logs\grompp_ions.log"

Write-Host "Run genion interactively and select the solvent group."
Write-Host "Record the random seed reported by the actual genion run."
