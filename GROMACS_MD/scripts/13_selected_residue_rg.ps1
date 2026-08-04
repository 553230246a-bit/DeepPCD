$ErrorActionPreference = "Stop"

$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"
$TPR = ".\md\md.tpr"
$XTC = ".\analysis\trajectory\md_center.xtc"
$OUT = ".\analysis\residue_Rg"

New-Item -ItemType Directory $OUT -Force | Out-Null

$residues = @(
    59, 94, 99, 105, 136, 168, 173, 196,
    203, 209, 210, 213, 228, 230, 239, 255
)

foreach ($resid in $residues) {
    $NDX = "$OUT\Residue_${resid}.ndx"

    "r $resid`nq" |
    & $GMX make_ndx `
        -f $TPR `
        -o $NDX

    Write-Host "Created: $NDX"
    Write-Host "Verify the generated group number before running gmx gyrate."
}
