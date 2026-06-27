[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-ObservationError {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
    exit 0
}

try {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $observationLog = if ([string]::IsNullOrWhiteSpace($env:CODEX_OBSERVATION_LOG)) {
        Join-Path $repoRoot ".codex\observations\hooks.jsonl"
    }
    else {
        $env:CODEX_OBSERVATION_LOG
    }

    $eventName = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_EVENT)) { "ObservationError" } else { $env:CODEX_HOOK_EVENT }
    $inputSummary = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_INPUT_SUMMARY)) {
        "Hook event observed without an explicit input summary."
    }
    else {
        $env:CODEX_HOOK_INPUT_SUMMARY
    }

    $tool = $null
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOOK_TOOL_NAME) -or
        -not [string]::IsNullOrWhiteSpace($env:CODEX_HOOK_TOOL_OPERATION) -or
        -not [string]::IsNullOrWhiteSpace($env:CODEX_HOOK_TOOL_TARGET)) {
        $tool = [ordered]@{
            name = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_TOOL_NAME)) { $null } else { $env:CODEX_HOOK_TOOL_NAME }
            operation = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_TOOL_OPERATION)) { $null } else { $env:CODEX_HOOK_TOOL_OPERATION }
            target = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_TOOL_TARGET)) { $null } else { $env:CODEX_HOOK_TOOL_TARGET }
        }
    }

    $cwdValue = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_CWD)) {
        try { (Get-Location).Path } catch { $null }
    }
    else {
        $env:CODEX_HOOK_CWD
    }

    $payload = [ordered]@{
        schema_version = 1
        event_id = ("{0}-{1}" -f (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ"), $PID)
        run_id = if ([string]::IsNullOrWhiteSpace($env:CODEX_RUN_ID)) { $null } else { $env:CODEX_RUN_ID }
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        source = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_SOURCE)) { "codex_hook" } else { $env:CODEX_HOOK_SOURCE }
        event = $eventName
        severity = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_SEVERITY)) { "info" } else { $env:CODEX_HOOK_SEVERITY }
        blocking = $false
        tool = $tool
        cwd = $cwdValue
        input_summary = $inputSummary
        decision = [ordered]@{
            action = "observe"
            reason = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_DECISION_REASON)) {
                "optional observation hook recorded the event"
            }
            else {
                $env:CODEX_HOOK_DECISION_REASON
            }
        }
        evidence = @()
        metadata = [ordered]@{
            hook = "observe.ps1"
        }
    }

    $parent = Split-Path -Parent $observationLog
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    ($payload | ConvertTo-Json -Compress -Depth 8) | Add-Content -Path $observationLog
    exit 0
}
catch {
    Write-ObservationError "Observation hook: failed to append event"
}
