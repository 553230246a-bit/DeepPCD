$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

New-Item -ItemType Directory ".\analysis\hbond" -Force | Out-Null

& $GMX hbond `
    -s ".\md\md.tpr" `
    -f ".\analysis\trajectory\md_center.xtc" `
    -n ".\topology\index.ndx" `
    -num ".\analysis\hbond\protein_ligand_hbond.xvg"

Write-Host "Select Protein and LIG interactively."
