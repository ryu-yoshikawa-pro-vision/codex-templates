[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [switch]$Json,

    [string]$TemplateVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourceTemplateRoot = Join-Path $repoRoot "template"
$destinationPath = [System.IO.Path]::GetFullPath($Destination)
$sourceTemplateVersionFile = Join-Path $sourceTemplateRoot "codex-project.toml"

function Test-SemVer {
    param([Parameter(Mandatory = $true)][string]$Value)
    return ($Value -match '^\d+\.\d+\.\d+$')
}

function Get-TemplateVersion {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($content, '^template_version\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value
}

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

function Compare-SourceTree {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if (Test-ProtectedPath -RelativePath $RelativePath) {
        return $false
    }
    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        return $true
    }

    $sourceItem = Get-Item -LiteralPath $SourcePath -Force
    $destinationItem = Get-Item -LiteralPath $DestinationPath -Force

    if ($sourceItem.PSIsContainer -ne $destinationItem.PSIsContainer) {
        return $true
    }

    if (-not $sourceItem.PSIsContainer) {
        $sourceHash = Get-FileHash -Algorithm SHA256 -LiteralPath $SourcePath
        $destinationHash = Get-FileHash -Algorithm SHA256 -LiteralPath $DestinationPath
        return ($sourceHash.Hash -ne $destinationHash.Hash)
    }

    foreach ($child in Get-ChildItem -LiteralPath $SourcePath -Force | Sort-Object Name) {
        $childRelative = if ([string]::IsNullOrWhiteSpace($RelativePath)) { $child.Name } else { "$RelativePath/$($child.Name)" }
        if (Compare-SourceTree -SourcePath $child.FullName -DestinationPath (Join-Path $DestinationPath $child.Name) -RelativePath $childRelative) {
            return $true
        }
    }

    return $false
}

function Get-ProtectedPaths {
    param([Parameter(Mandatory = $true)][string]$DestinationRoot)

    if (-not (Test-Path -LiteralPath $DestinationRoot)) {
        return @()
    }

    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($rel in @('docs/PROJECT_CONTEXT.md', '.env')) {
        if (Test-Path -LiteralPath (Join-Path $DestinationRoot $rel)) {
            $paths.Add($rel) | Out-Null
        }
    }
    foreach ($rel in @('docs/adr', 'docs/plans', 'docs/reports', 'docs/history', '.codex/runs', '.git')) {
        if (Test-Path -LiteralPath (Join-Path $DestinationRoot $rel)) {
            $paths.Add(($rel -replace '\\', '/') + '/') | Out-Null
        }
    }
    Get-ChildItem -LiteralPath $DestinationRoot -Force -Filter '.env.*' -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
        $paths.Add($_.Name) | Out-Null
    }
    return @($paths | Sort-Object -Unique)
}

function Get-CandidateUpdates {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($child in Get-ChildItem -LiteralPath $SourceRoot -Force | Sort-Object Name) {
        if (Test-ProtectedPath -RelativePath $child.Name) {
            continue
        }
        if (Compare-SourceTree -SourcePath $child.FullName -DestinationPath (Join-Path $DestinationRoot $child.Name) -RelativePath $child.Name) {
            $candidates.Add($child.Name) | Out-Null
        }
    }
    return @($candidates)
}

function Get-ManualReviewRequired {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot,
        [string[]]$ProtectedPaths
    )

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($item in $ProtectedPaths) {
        $items.Add($item) | Out-Null
    }

    if (Test-Path -LiteralPath $DestinationRoot) {
        $sourceTop = @{}
        foreach ($child in Get-ChildItem -LiteralPath $SourceRoot -Force) {
            $sourceTop[$child.Name] = $true
        }
        foreach ($child in Get-ChildItem -LiteralPath $DestinationRoot -Force | Sort-Object Name) {
            if (Test-ProtectedPath -RelativePath $child.Name) {
                continue
            }
            if (-not $sourceTop.ContainsKey($child.Name)) {
                $items.Add($child.Name) | Out-Null
            }
        }
    }

    return @($items | Sort-Object -Unique)
}

function Get-VersionChange {
    param(
        [AllowNull()][string]$SourceVersion,
        [AllowNull()][string]$ConsumerVersion
    )

    if ([string]::IsNullOrWhiteSpace($SourceVersion) -or [string]::IsNullOrWhiteSpace($ConsumerVersion)) {
        return "unknown"
    }
    if (-not (Test-SemVer -Value $SourceVersion) -or -not (Test-SemVer -Value $ConsumerVersion)) {
        return "unknown"
    }

    $sourceParts = $SourceVersion.Split('.') | ForEach-Object { [int]$_ }
    $consumerParts = $ConsumerVersion.Split('.') | ForEach-Object { [int]$_ }
    if (($sourceParts -join '.') -eq ($consumerParts -join '.')) {
        return "same"
    }
    if ($sourceParts[0] -ne $consumerParts[0]) {
        return "major"
    }
    if ($sourceParts[1] -ne $consumerParts[1]) {
        return "minor"
    }
    return "patch"
}

$sourceTemplateVersion = Get-TemplateVersion -Path $sourceTemplateVersionFile
if (-not $sourceTemplateVersion) {
    throw "Failed to read template_version from template/codex-project.toml"
}
if (-not (Test-SemVer -Value $sourceTemplateVersion)) {
    throw "Source template_version is not semver: $sourceTemplateVersion"
}

if (-not [string]::IsNullOrWhiteSpace($TemplateVersion)) {
    if (-not (Test-SemVer -Value $TemplateVersion)) {
        throw "-TemplateVersion must be semver: $TemplateVersion"
    }
    if ($TemplateVersion -ne $sourceTemplateVersion) {
        throw "-TemplateVersion $TemplateVersion does not match source template version $sourceTemplateVersion"
    }
}

$consumerTemplateVersion = Get-TemplateVersion -Path (Join-Path $destinationPath "codex-project.toml")
$protectedPaths = Get-ProtectedPaths -DestinationRoot $destinationPath
$candidateUpdates = Get-CandidateUpdates -SourceRoot $sourceTemplateRoot -DestinationRoot $destinationPath
$manualReviewRequired = Get-ManualReviewRequired -SourceRoot $sourceTemplateRoot -DestinationRoot $destinationPath -ProtectedPaths $protectedPaths
$recommendedCommands = @(
    ('powershell -ExecutionPolicy Bypass -File tools/plan-consumer-update.ps1 -Destination "{0}"' -f $destinationPath),
    ('powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1 -Destination "{0}" -Force -PlanOnly -ExcludeProtected' -f $destinationPath),
    ('powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1 -Destination "{0}" -Force -ExcludeProtected' -f $destinationPath),
    ('powershell -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $destinationPath 'scripts\verify.ps1')),
    ('bash "{0}"' -f (Join-Path $destinationPath 'scripts\verify'))
)

$result = [ordered]@{
    source_template_version = $sourceTemplateVersion
    consumer_template_version = $consumerTemplateVersion
    version_change = Get-VersionChange -SourceVersion $sourceTemplateVersion -ConsumerVersion $consumerTemplateVersion
    destination = $destinationPath
    protected_paths = @($protectedPaths)
    candidate_updates = @($candidateUpdates)
    manual_review_required = @($manualReviewRequired)
    recommended_commands = @($recommendedCommands)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host "Source template version: $sourceTemplateVersion"
Write-Host ("Consumer template version: {0}" -f $(if ($consumerTemplateVersion) { $consumerTemplateVersion } else { '(not found)' }))
Write-Host "Version change: $($result.version_change)"
Write-Host "Destination: $destinationPath"
Write-Host "Protected paths:"
if (@($protectedPaths).Count -gt 0) {
    foreach ($item in $protectedPaths) {
        Write-Host "  - $item"
    }
}
else {
    Write-Host "  - (none)"
}
Write-Host "Candidate updates:"
if (@($candidateUpdates).Count -gt 0) {
    foreach ($item in $candidateUpdates) {
        Write-Host "  - $item"
    }
}
else {
    Write-Host "  - (none)"
}
Write-Host "Manual review required:"
if (@($manualReviewRequired).Count -gt 0) {
    foreach ($item in $manualReviewRequired) {
        Write-Host "  - $item"
    }
}
else {
    Write-Host "  - (none)"
}
Write-Host "Recommended commands:"
foreach ($command in $recommendedCommands) {
    Write-Host "  - $command"
}
