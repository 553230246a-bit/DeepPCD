$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

New-Item -ItemType Directory ".\analysis\rmsd" -Force | Out-Null

& $GMX rms `
    -s ".\md\md.tpr" `
    -f ".\analysis\trajectory\md_center.xtc" `
    -n ".\topology\index.ndx" `
    -o ".\analysis\rmsd\protein_rmsd.xvg" `
    -tu ns
