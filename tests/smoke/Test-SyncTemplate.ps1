[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$scriptPath = Join-Path $repoRoot "tools\\sync-template.ps1"
$tempPath = Join-Path $env:TEMP ("codex-template-sync-test-" + [guid]::NewGuid().ToString())

try {
    New-Item -ItemType Directory -Force -Path $tempPath | Out-Null
    Set-Content -Path (Join-Path $tempPath "old-v1-file.txt") -Value "stale"

    powershell.exe -ExecutionPolicy Bypass -File $scriptPath -Destination $tempPath -Force | Out-Null

    if (Test-Path (Join-Path $tempPath "old-v1-file.txt")) {
        throw "stale file was not removed by sync-template.ps1"
    }

    foreach ($required in @("AGENTS.md", ".codex", ".agents", "docs", "scripts")) {
        if (-not (Test-Path (Join-Path $tempPath $required))) {
            throw "Missing synced path: $required"
        }
    }

    if (Test-Path (Join-Path $tempPath "docs\\agent")) {
        throw "docs/agent should not be synced into the consumer-facing template"
    }
}
finally {
    Remove-Item -Recurse -Force $tempPath -ErrorAction SilentlyContinue
}

Write-Host "PASS: sync-template PowerShell mirror test"
