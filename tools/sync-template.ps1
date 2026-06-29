[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [switch]$Force,

    [switch]$DryRun,

    [switch]$PlanOnly,

    [switch]$ExcludeProtected,

    [switch]$ConfirmDestructiveOverwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source = Join-Path $repoRoot "template"
$target = [System.IO.Path]::GetFullPath($Destination)

function Test-ProtectedPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $normalized = ($RelativePath -replace '\\', '/').Trim('/')
    if ($normalized -in @('docs/PROJECT_CONTEXT.md', '.env', 'docs/adr', 'docs/plans', 'docs/reports', 'docs/history', '.codex/runs', '.git')) {
        return $true
    }
    if ($normalized.StartsWith('.env.', [System.StringComparison]::Ordinal)) {
        return $true
    }
    foreach ($prefix in @('docs/adr', 'docs/plans', 'docs/reports', 'docs/history', '.codex/runs', '.git')) {
        if ($normalized.StartsWith($prefix + '/', [System.StringComparison]::Ordinal)) {
            return $true
        }
    }
    return $false
}

function Copy-TreeExcludingProtected {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot,
        [string]$RelativeBase = ""
    )

    foreach ($item in Get-ChildItem -LiteralPath $SourceRoot -Force | Sort-Object Name) {
        $relativePath = if ([string]::IsNullOrWhiteSpace($RelativeBase)) { $item.Name } else { "$RelativeBase/$($item.Name)" }
        if (Test-ProtectedPath -RelativePath $relativePath) {
            continue
        }

        $destinationPath = Join-Path $DestinationRoot $item.Name
        if (Test-Path -LiteralPath $destinationPath) {
            $destinationItem = Get-Item -LiteralPath $destinationPath -Force
            if ($destinationItem.PSIsContainer -ne $item.PSIsContainer) {
                throw "ExcludeProtected sync requires manual review for path type conflict: $relativePath"
            }
        }
        if ($item.PSIsContainer) {
            if (-not (Test-Path -LiteralPath $destinationPath)) {
                New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
            }
            Copy-TreeExcludingProtected -SourceRoot $item.FullName -DestinationRoot $destinationPath -RelativeBase $relativePath
            continue
        }

        $parent = Split-Path -Parent $destinationPath
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath $item.FullName -Destination $destinationPath -Force
    }
}

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

$planScript = Join-Path $repoRoot "tools\plan-consumer-update.ps1"
if ($PlanOnly) {
    & powershell.exe -ExecutionPolicy Bypass -File $planScript -Destination $target
    exit $LASTEXITCODE
}

$destinationExists = Test-Path $target

if ($destinationExists -and -not $Force) {
    throw "Destination already exists. Use -Force after reviewing -DryRun: $target"
}

if ($destinationExists -and $Force -and -not $ExcludeProtected -and -not $ConfirmDestructiveOverwrite -and -not $DryRun) {
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
    if ($ExcludeProtected) {
        Write-Host "DRY RUN: protected paths would be preserved and destination-only files would be kept."
    }
    else {
        Write-Host "DRY RUN: destructive overwrite mode is active; existing top-level contents would be removed."
    }
    if ($destinationExists -and $Force -and -not $ExcludeProtected) {
        Write-Host "DRY RUN: existing destination top-level entries that would be removed:"
        Get-ChildItem -Force -LiteralPath $target | Sort-Object FullName | ForEach-Object { Write-Host $_.FullName }
    }
    elseif ($destinationExists -and $Force) {
        Write-Host "DRY RUN: existing destination-only entries would be kept."
    }
    elseif ($destinationExists) {
        Write-Host "DRY RUN: destination exists and -Force was not provided; sync would fail."
    }
    else {
        Write-Host "DRY RUN: destination does not exist and would be created."
    }
    Write-Host "DRY RUN: update planning summary:"
    & powershell.exe -ExecutionPolicy Bypass -File $planScript -Destination $target
    Write-Host "DRY RUN: template files would be copied from source to destination."
    return
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
if ($ExcludeProtected) {
    Copy-TreeExcludingProtected -SourceRoot $source -DestinationRoot $target
    Write-Host "Template synced to $target (non-protected paths updated, protected paths preserved)"
    return
}
if ($Force -and (Test-Path $target)) {
    Get-ChildItem -Force -LiteralPath $target | Remove-Item -Recurse -Force
}
Get-ChildItem -Force -LiteralPath $source | Copy-Item -Destination $target -Recurse -Force
Write-Host "Template synced to $target"
