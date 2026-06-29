[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [switch]$Force,

    [switch]$DryRun,

    [switch]$ConfirmDestructiveOverwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source = Join-Path $repoRoot "template"
$target = [System.IO.Path]::GetFullPath($Destination)

function Test-PathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Base
    )

    $fullCandidate = [System.IO.Path]::GetFullPath($Candidate).TrimEnd('\', '/')
    $fullBase = [System.IO.Path]::GetFullPath($Base).TrimEnd('\', '/')
    return $fullCandidate.StartsWith($fullBase + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

if ($target.TrimEnd('\', '/') -eq $source.TrimEnd('\', '/')) {
    throw "Destination cannot be the template source directory: $target"
}

if (Test-PathWithin -Candidate $target -Base $source) {
    throw "Destination cannot be inside the template source directory: $target"
}

$destinationExists = Test-Path $target

if ($destinationExists -and -not $Force) {
    throw "Destination already exists. Use -Force after reviewing -DryRun: $target"
}

if ($destinationExists -and $Force -and -not $ConfirmDestructiveOverwrite -and -not $DryRun) {
    throw @"
Refusing to destructively overwrite existing destination without explicit confirmation: $target

Run a dry run first:
  powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1 -Destination "$target" -Force -DryRun

Then confirm destructive overwrite if the removal list is expected:
  powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1 -Destination "$target" -Force -ConfirmDestructiveOverwrite
"@
}

if ($DryRun) {
    Write-Host "DRY RUN: source: $source"
    Write-Host "DRY RUN: destination: $target"
    if ($destinationExists -and $Force) {
        Write-Host "DRY RUN: existing destination top-level entries that would be removed:"
        Get-ChildItem -Force -LiteralPath $target | Sort-Object FullName | ForEach-Object { Write-Host $_.FullName }
    }
    elseif ($destinationExists) {
        Write-Host "DRY RUN: destination exists and -Force was not provided; sync would fail."
    }
    else {
        Write-Host "DRY RUN: destination does not exist and would be created."
    }
    Write-Host "DRY RUN: template files would be copied from source to destination."
    return
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
if ($Force -and (Test-Path $target)) {
    Get-ChildItem -Force -LiteralPath $target | Remove-Item -Recurse -Force
}
Get-ChildItem -Force -LiteralPath $source | Copy-Item -Destination $target -Recurse -Force
Write-Host "Template synced to $target"
