[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-ObservationError {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
    exit 0
}

function Normalize-EnumValue {
    param(
        [AllowNull()][string]$Value,
        [Parameter(Mandatory = $true)][string[]]$Allowed,
        [Parameter(Mandatory = $true)][string]$Default,
        [Parameter(Mandatory = $true)][string]$Fallback
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{
            Value = $Default
            Original = $null
        }
    }

    if ($Allowed -contains $Value) {
        return [pscustomobject]@{
            Value = $Value
            Original = $null
        }
    }

    return [pscustomobject]@{
        Value = $Fallback
        Original = $Value
    }
}

function Add-Utf8NoBomLine {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Line
    )

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::AppendAllText($Path, $Line + [Environment]::NewLine, $utf8NoBom)
}

try {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $observationLog = if ([string]::IsNullOrWhiteSpace($env:CODEX_OBSERVATION_LOG)) {
        Join-Path $repoRoot ".codex\observations\hooks.jsonl"
    }
    else {
        $env:CODEX_OBSERVATION_LOG
    }

    $normalizedEvent = Normalize-EnumValue `
        -Value $env:CODEX_HOOK_EVENT `
        -Allowed @("PreToolUse", "PostToolUse", "SubagentStart", "SubagentStop", "Stop", "WrapperStart", "WrapperStop", "SafetyBlocked", "ObservationError") `
        -Default "ObservationError" `
        -Fallback "ObservationError"

    $normalizedSource = Normalize-EnumValue `
        -Value $env:CODEX_HOOK_SOURCE `
        -Allowed @("codex_hook", "codex_task", "codex_safe", "subagent", "manual", "unknown") `
        -Default "codex_hook" `
        -Fallback "unknown"

    $normalizedSeverity = Normalize-EnumValue `
        -Value $env:CODEX_HOOK_SEVERITY `
        -Allowed @("debug", "info", "warning", "error", "critical") `
        -Default "info" `
        -Fallback "warning"

    $inputSummary = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOOK_INPUT_SUMMARY)) {
        $null
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

    $metadata = [ordered]@{
        hook = "observe.ps1"
    }
    if (-not [string]::IsNullOrWhiteSpace($normalizedEvent.Original)) {
        $metadata.original_event = $normalizedEvent.Original
    }
    if (-not [string]::IsNullOrWhiteSpace($normalizedSource.Original)) {
        $metadata.original_source = $normalizedSource.Original
    }
    if (-not [string]::IsNullOrWhiteSpace($normalizedSeverity.Original)) {
        $metadata.original_severity = $normalizedSeverity.Original
    }

    $payload = [ordered]@{
        schema_version = 1
        event_id = ("{0}-{1}" -f (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ"), $PID)
        run_id = if ([string]::IsNullOrWhiteSpace($env:CODEX_RUN_ID)) { $null } else { $env:CODEX_RUN_ID }
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        source = $normalizedSource.Value
        event = $normalizedEvent.Value
        severity = $normalizedSeverity.Value
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
        metadata = $metadata
    }

    $parent = Split-Path -Parent $observationLog
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $jsonLine = $payload | ConvertTo-Json -Compress -Depth 8
    Add-Utf8NoBomLine -Path $observationLog -Line $jsonLine
    exit 0
}
catch {
    Write-ObservationError "Observation hook: failed to append event"
}
