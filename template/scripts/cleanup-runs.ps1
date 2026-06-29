[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$DryRun,
    [int]$OlderThanDays,
    [switch]$ConfirmDeleteGeneratedRuns
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PSBoundParameters.ContainsKey('OlderThanDays') -and $OlderThanDays -lt 0) {
    throw "-OlderThanDays must be a non-negative integer"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$previewOnly = $true
if ($ConfirmDeleteGeneratedRuns -and -not $DryRun) {
    $previewOnly = $false
}

$runIdPattern = '^[0-9]{8}-[0-9]{6}-JST$'

function Test-IsReparsePoint {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return $false
    }

    $item = Get-Item -LiteralPath $LiteralPath -Force
    return (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Test-HasReparsePointAncestor {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$StopAt
    )

    $current = Split-Path -Parent ([System.IO.Path]::GetFullPath($LiteralPath))
    $stop = [System.IO.Path]::GetFullPath($StopAt).TrimEnd('\', '/')

    while (-not [string]::IsNullOrWhiteSpace($current)) {
        $normalizedCurrent = [System.IO.Path]::GetFullPath($current).TrimEnd('\', '/')
        if (-not $normalizedCurrent.StartsWith($stop, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        if ($normalizedCurrent -eq $stop) {
            break
        }
        if (Test-IsReparsePoint -LiteralPath $normalizedCurrent) {
            return $true
        }

        $parent = Split-Path -Parent $normalizedCurrent
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $normalizedCurrent) {
            break
        }
        $current = $parent
    }

    return $false
}

function Test-IsOldEnough {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    if (-not $PSBoundParameters.ContainsKey('OlderThanDays') -and -not $script:hasOlderThanDays) {
        return $true
    }

    $item = Get-Item -LiteralPath $LiteralPath -Force
    $threshold = (Get-Date).AddDays(-1 * $script:OlderThanDays)
    return ($item.LastWriteTime -le $threshold)
}

function Get-RepoRelativePath {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $fullPath = [System.IO.Path]::GetFullPath($LiteralPath)
    if ($fullPath.StartsWith($repoRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($repoRoot.Length + 1) -replace '\\', '/'
    }

    return $fullPath
}

function Test-IsWithinRepo {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $fullPath = [System.IO.Path]::GetFullPath($LiteralPath)
    return $fullPath.StartsWith($repoRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Add-Candidate {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    if (-not (Test-IsOldEnough -LiteralPath $Path)) {
        return
    }

    $script:candidates.Add([pscustomobject]@{
        kind = $Kind
        path = $Path
    }) | Out-Null
}

$script:hasOlderThanDays = $PSBoundParameters.ContainsKey('OlderThanDays')
$script:candidates = New-Object System.Collections.Generic.List[object]

$runsRoot = Join-Path $repoRoot ".codex\runs"
if (Test-Path -LiteralPath $runsRoot) {
    Get-ChildItem -LiteralPath $runsRoot -Force | ForEach-Object {
        if ($_.Name -match $runIdPattern) {
            Add-Candidate -Kind "run_dir" -Path $_.FullName
        }
    }
}

$logsRoot = Join-Path $repoRoot ".codex\logs"
if (Test-Path -LiteralPath $logsRoot) {
    Get-ChildItem -LiteralPath $logsRoot -Force -File -Filter *.jsonl | ForEach-Object {
        Add-Candidate -Kind "top_log" -Path $_.FullName
    }
}

$hookLog = Join-Path $repoRoot ".codex\observations\hooks.jsonl"
if (Test-Path -LiteralPath $hookLog) {
    Add-Candidate -Kind "hook_log" -Path $hookLog
}

Write-Host ("MODE: {0}" -f $(if ($previewOnly) { "preview" } else { "delete" }))
if ($script:hasOlderThanDays) {
    Write-Host "OLDER_THAN_DAYS: $OlderThanDays"
}
Write-Host "CANDIDATES:"
if ($script:candidates.Count -eq 0) {
    Write-Host "  (none)"
}
else {
    foreach ($candidate in $script:candidates) {
        Write-Host ("  - [{0}] {1}" -f $candidate.kind, (Get-RepoRelativePath -LiteralPath $candidate.path))
    }
}

if ($previewOnly) {
    Write-Host ("SUMMARY: preview_only deleted=0 candidates={0}" -f $script:candidates.Count)
    return
}

$deletedCount = 0
foreach ($candidate in $script:candidates) {
    if (Test-IsReparsePoint -LiteralPath $candidate.path) {
        throw "Refusing to delete symlink/reparse-point candidate: $(Get-RepoRelativePath -LiteralPath $candidate.path)"
    }
    if (-not (Test-IsWithinRepo -LiteralPath $candidate.path)) {
        throw "Refusing to delete path outside repo root: $($candidate.path)"
    }
    if (Test-HasReparsePointAncestor -LiteralPath $candidate.path -StopAt $repoRoot) {
        throw "Refusing to delete path with symlink/reparse-point ancestor: $(Get-RepoRelativePath -LiteralPath $candidate.path)"
    }
    Remove-Item -LiteralPath $candidate.path -Recurse -Force
    $deletedCount++
}

Write-Host ("SUMMARY: deleted={0} candidates={1}" -f $deletedCount, $script:candidates.Count)
