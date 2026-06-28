[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunId,
    [string]$RunsRoot,
    [string[]]$HookLog,
    [string]$ManifestPath,
[string]$BaseManifest,
    [switch]$Strict
)

function Get-PythonCommand {
    foreach ($candidate in @("python", "python3", "py")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $cmd) {
            continue
        }
        return $cmd.Source
    }

    throw "Python is required to collect run artifacts"
}

$python = Get-PythonCommand
$scriptPath = Join-Path $PSScriptRoot "collect-run-artifacts.py"
$scriptPath = (Resolve-Path $scriptPath).Path
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
