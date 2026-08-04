$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

New-Item -ItemType Directory ".\analysis\rmsf" -Force | Out-Null

& $GMX rmsf `
    -s ".\md\md_.tpr" `
    -f ".\analysis\trajectory\md_center.xtc" `
    -n ".\topology\index.ndx" `
    -o ".\analysis\rmsf\protein_rmsf.xvg" `
    -res
