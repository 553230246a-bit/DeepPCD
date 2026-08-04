$ErrorActionPreference = "Stop"

$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

New-Item -ItemType Directory ".\analysis\trajectory" -Force | Out-Null

& $GMX trjconv `
    -f ".\md\md.xtc" `
    -s ".\md\md.tpr" `
    -n ".\topology\index.ndx" `
    -o ".\analysis\trajectory\md_nojump.xtc" `
    -pbc nojump

& $GMX trjconv `
    -f ".\analysis\trajectory\md_nojump.xtc" `
    -s ".\md\mdtpr" `
    -n ".\topology\index.ndx" `
    -o ".\analysis\trajectory\md_center.xtc" `
    -pbc mol `
    -center

Write-Host "Select the appropriate groups interactively."
