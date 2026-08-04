$ErrorActionPreference = "Stop"
$GMX = "C:\gmx2020.6_AVX2_CUDA_win64\gmx2020.6_GPU\bin\gmx.exe"

Write-Host "Checking GROMACS installation..."
if (-not (Test-Path $GMX)) {
    throw "GROMACS executable not found: $GMX"
}

& $GMX --version
Write-Host ""
Write-Host "Python version:"
py -3 --version
Write-Host ""
Write-Host "Current directory:"
Get-Location
