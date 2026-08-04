[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$FoldXPath,
    [Parameter(Mandatory = $true)][string]$PdbPath,
    [ValidateRange(1,100)][int]$Runs = 3,
    [string]$OutputName = "BhNIT_22_single",
    [switch]$SkipRepair
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RequiredFile {
    param([string]$PathValue,[string]$Description)
    if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
        throw "$Description not found: $PathValue"
    }
    return (Resolve-Path -LiteralPath $PathValue).Path
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$WorkDir = Join-Path $RepoRoot "work"
$RawDir = Join-Path $RepoRoot "results\raw"
$ProcessedDir = Join-Path $RepoRoot "results\processed"
$MutationFile = Join-Path $RepoRoot "mutations\individual_list.txt"
$Validator = Join-Path $PSScriptRoot "check_mutations.py"
$Parser = Join-Path $PSScriptRoot "parse_foldx_results.py"

$FoldX = Resolve-RequiredFile $FoldXPath "FoldX executable"
$InputPdb = Resolve-RequiredFile $PdbPath "Input PDB"
$MutationList = Resolve-RequiredFile $MutationFile "Mutation list"

New-Item -ItemType Directory -Force -Path $WorkDir,$RawDir,$ProcessedDir | Out-Null
& python $Validator $MutationList
if ($LASTEXITCODE -ne 0) { throw "Mutation validation failed." }

Get-ChildItem -LiteralPath $WorkDir -Force | Remove-Item -Recurse -Force
$InputPdbName = [System.IO.Path]::GetFileName($InputPdb)
Copy-Item -LiteralPath $InputPdb -Destination (Join-Path $WorkDir $InputPdbName)
Copy-Item -LiteralPath $MutationList -Destination (Join-Path $WorkDir "individual_list.txt")

$Log = Join-Path $RawDir "foldx_run.log"
"FoldX executable: $FoldX" | Set-Content $Log
"Input PDB: $InputPdb" | Add-Content $Log
"Mutation count: 22" | Add-Content $Log
"Runs per mutation: $Runs" | Add-Content $Log
"Total mutant calculations: $($Runs * 22)" | Add-Content $Log
"timeSeedRotabase: false" | Add-Content $Log
"out-pdb: false" | Add-Content $Log
"Started: $(Get-Date -Format o)" | Add-Content $Log

Push-Location $WorkDir
try {
    if (-not $SkipRepair) {
        & $FoldX --command=RepairPDB --pdb=$InputPdbName 2>&1 | Tee-Object -FilePath $Log -Append
        if ($LASTEXITCODE -ne 0) { throw "RepairPDB failed." }
        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InputPdbName)
        $BuildPdb = "${BaseName}_Repair.pdb"
    } else {
        $BuildPdb = $InputPdbName
    }

    if (-not (Test-Path -LiteralPath $BuildPdb -PathType Leaf)) {
        throw "Build input PDB not found: $BuildPdb"
    }

    & $FoldX `
        --command=BuildModel `
        --pdb=$BuildPdb `
        --mutant-file=individual_list.txt `
        --numberOfRuns=$Runs `
        --timeSeedRotabase=false `
        --out-pdb=false `
        --output-file=$OutputName 2>&1 | Tee-Object -FilePath $Log -Append

    if ($LASTEXITCODE -ne 0) { throw "BuildModel failed." }

    Get-ChildItem -Filter "*.fxout" -File | Copy-Item -Destination $RawDir -Force
    Copy-Item -LiteralPath $BuildPdb -Destination $RawDir -Force

    $DifFile = Get-ChildItem -Filter "Dif_*.fxout" -File |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $DifFile) { throw "No Dif_*.fxout file was generated." }

    & python $Parser `
        --dif $DifFile.FullName `
        --mutations $MutationList `
        --runs $Runs `
        --output (Join-Path $ProcessedDir "foldx_ddg_summary.csv") `
        --long-output (Join-Path $ProcessedDir "foldx_ddg_long.csv")

    if ($LASTEXITCODE -ne 0) { throw "Result parsing failed." }
    "Completed: $(Get-Date -Format o)" | Add-Content $Log
    Write-Host "FoldX workflow completed successfully."
}
finally {
    Pop-Location
}
