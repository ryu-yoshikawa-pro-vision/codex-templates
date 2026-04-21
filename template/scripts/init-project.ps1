[CmdletBinding()]
param(
    [string]$Name
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$directories = @(
    ".codex\runs",
    "docs\adr",
    "docs\history",
    "docs\plans",
    "docs\reports"
)

foreach ($dir in $directories) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

$keepFiles = @(
    ".codex\runs\.gitkeep",
    "docs\adr\.gitkeep",
    "docs\history\.gitkeep",
    "docs\plans\.gitkeep",
    "docs\reports\.gitkeep"
)

foreach ($keep in $keepFiles) {
    if (-not (Test-Path -LiteralPath $keep)) {
        New-Item -ItemType File -Path $keep | Out-Null
    }
}

if ($Name -and (Test-Path -LiteralPath "codex-project.toml")) {
    $escapedName = $Name -replace '\\', '\\\\'
    $escapedName = $escapedName -replace '"', '\"'
    $escapedName = $escapedName -replace "`r", '\r'
    $escapedName = $escapedName -replace "`n", '\n'
    $escapedName = $escapedName -replace "`t", '\t'

    $lines = Get-Content -LiteralPath "codex-project.toml"
    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $updated -and $lines[$i] -match '^name = ".*"$') {
            $lines[$i] = 'name = "' + $escapedName + '"'
            $updated = $true
        }
    }
    Set-Content -LiteralPath "codex-project.toml" -Value $lines
}

Write-Host "Initialized Codex project metadata."
Write-Host "Next: update docs/PROJECT_CONTEXT.md for this repository."
