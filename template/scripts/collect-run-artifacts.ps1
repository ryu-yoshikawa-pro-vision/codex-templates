[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunId,
    [string]$RunsRoot,
    [string[]]$HookLog,
    [string]$ManifestPath,
    [string]$BaseManifest,
    [switch]$Strict
)

$python = if (Get-Command python -ErrorAction SilentlyContinue) {
    "python"
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    "py"
}
else {
    throw "Python is required to collect run artifacts"
}

$scriptPath = Join-Path $PSScriptRoot "collect-run-artifacts.py"
$argsList = @($scriptPath, "--run-id", $RunId)
if ($RunsRoot) { $argsList += @("--runs-root", $RunsRoot) }
foreach ($path in @($HookLog)) {
    if ($path) { $argsList += @("--hook-log", $path) }
}
if ($ManifestPath) { $argsList += @("--manifest-path", $ManifestPath) }
if ($BaseManifest) { $argsList += @("--base-manifest", $BaseManifest) }
if ($Strict) { $argsList += "--strict" }

& $python @argsList
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
