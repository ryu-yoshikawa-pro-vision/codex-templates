[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [switch]$Force
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

if ((Test-Path $target) -and -not $Force) {
    throw "Destination already exists. Use -Force to overwrite: $target"
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
if ($Force -and (Test-Path $target)) {
    Get-ChildItem -Force -LiteralPath $target | Remove-Item -Recurse -Force
}
Copy-Item (Join-Path $source "*") $target -Recurse -Force
Write-Host "Template synced to $target"
