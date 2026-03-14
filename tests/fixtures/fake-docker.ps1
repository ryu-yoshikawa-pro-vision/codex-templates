[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:CODEX_BIN)) {
    throw "CODEX_BIN is required for fake-docker.ps1"
}

$i = 0
if ($Args.Count -gt 0 -and $Args[0] -eq 'run') {
    $i = 1
}

while ($i -lt $Args.Count) {
    $token = $Args[$i]
    if ($token -in @('--rm')) {
        $i++
        continue
    }
    if ($token -in @('-v', '-w', '-e')) {
        $i += 2
        continue
    }
    break
}

if ($i -ge $Args.Count) {
    throw "docker image argument missing"
}

$i++ # skip image
$commandArgs = if ($i -lt $Args.Count) { $Args[$i..($Args.Count - 1)] } else { @() }
if ($commandArgs.Count -gt 0 -and $commandArgs[0] -eq 'codex') {
    $commandArgs = if ($commandArgs.Count -gt 1) { $commandArgs[1..($commandArgs.Count - 1)] } else { @() }
}

& $env:CODEX_BIN @commandArgs
exit $LASTEXITCODE
