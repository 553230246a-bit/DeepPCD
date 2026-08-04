$ErrorActionPreference = "Stop"

$dirs = @(
    "input",
    "topology",
    "mdp",
    "em",
    "nvt",
    "npt",
    "md",
    "analysis",
    "logs",
    "mmpbsa"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Write-Host "Project directories created."
