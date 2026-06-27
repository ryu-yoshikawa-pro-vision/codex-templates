[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$templateRoot = Join-Path $sourceRepoRoot "template"
$tempRoot = Join-Path $env:TEMP ("observation-baseline-" + [guid]::NewGuid().ToString())

function Get-PythonCommand {
    foreach ($candidate in @("python", "python3", "py")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        $prevNativeErr = $null
        $hasNativeErrPref = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)
        if ($hasNativeErrPref) {
            $prevNativeErr = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
        }
        try {
            & $cmd.Source --version *> $null
            if ($LASTEXITCODE -eq 0) {
                return $cmd.Source
            }
        }
        catch {
        }
        finally {
            if ($hasNativeErrPref) {
                $PSNativeCommandUseErrorActionPreference = $prevNativeErr
            }
        }
    }

    throw "python is required for observation baseline validation"
}

function Invoke-WindowsPowerShellFile {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments = @(),
        [hashtable]$ExtraEnv
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        foreach ($pair in $ExtraEnv.GetEnumerator()) {
            [System.Environment]::SetEnvironmentVariable($pair.Key, $pair.Value)
        }

        $argList = @('-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments
        $proc = Start-Process -FilePath 'powershell.exe' `
            -ArgumentList $argList `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile

        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            StdOut = if (Test-Path $stdoutFile) { Get-Content $stdoutFile -Raw } else { '' }
            StdErr = if (Test-Path $stderrFile) { Get-Content $stderrFile -Raw } else { '' }
        }
    }
    finally {
        foreach ($pair in $ExtraEnv.GetEnumerator()) {
            [System.Environment]::SetEnvironmentVariable($pair.Key, $null)
        }
        Remove-Item -Force $stdoutFile, $stderrFile -ErrorAction SilentlyContinue
    }
}

function Assert-JsonEqual {
    param(
        [string]$LeftPath,
        [string]$RightPath
    )

    $left = Get-Content -Raw $LeftPath | ConvertFrom-Json
    $right = Get-Content -Raw $RightPath | ConvertFrom-Json
    if (($left | ConvertTo-Json -Depth 20 -Compress) -ne ($right | ConvertTo-Json -Depth 20 -Compress)) {
        throw "JSON files differ: $LeftPath vs $RightPath"
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    $python = Get-PythonCommand
    $validator = Join-Path $templateRoot "scripts\validate-output-schema.py"
    $hookSchema = Join-Path $sourceRepoRoot "spec\hook-observation.schema.json"
    $subagentSchema = Join-Path $sourceRepoRoot "spec\subagent-run.schema.json"
    $hookTemplate = Join-Path $templateRoot ".codex\templates\hook-observation.schema.json"
    $subagentTemplate = Join-Path $templateRoot ".codex\templates\subagent-run.schema.json"

    $sampleHookPath = Join-Path $tempRoot "sample-hook-observation.json"
    $sampleSubagentPath = Join-Path $tempRoot "sample-subagent-run.json"

    Write-Utf8NoBom -Path $sampleHookPath -Content @'
{"schema_version":1,"event_id":"20260627T120000Z-12345","run_id":null,"timestamp":"2026-06-27T12:00:00Z","source":"codex_hook","event":"PreToolUse","severity":"info","blocking":false,"tool":{"name":"PowerShell","operation":"command","target":"scripts/verify"},"cwd":"C:/workspace","input_summary":"Run verification command","decision":{"action":"observe","reason":"optional observation hook recorded the event"},"evidence":[],"metadata":{"hook":"observe.ps1"}}
'@

    Write-Utf8NoBom -Path $sampleSubagentPath -Content @'
{
  "schema_version": 1,
  "subagent_run_id": "subagent-001",
  "parent_run_id": "20260627-120000-JST",
  "agent": {
    "name": "implementation_worker",
    "model": "gpt-5.4-mini"
  },
  "role": "implementation_worker",
  "mode": "writable",
  "purpose": "Update observation docs for the requested files only.",
  "sandbox": {
    "type": "workspace-write",
    "network": false
  },
  "allowed_files": [
    "template/docs/reference/hook-observation.md"
  ],
  "input_files": [
    "template/docs/reference/run-artifacts.md"
  ],
  "changed_files": [
    "template/docs/reference/hook-observation.md"
  ],
  "scope": {
    "declared": true,
    "compliant": true,
    "violations": []
  },
  "started_at": "2026-06-27T12:00:00Z",
  "ended_at": "2026-06-27T12:02:00Z",
  "status": "completed",
  "summary": "Updated the requested observation doc within the declared scope.",
  "parent_decision": {
    "action": "accepted",
    "reason": "The output stayed within allowed_files and matched the requested change."
  },
  "used_in_final_plan": true,
  "evidence": [
    {
      "kind": "path",
      "value": "template/docs/reference/hook-observation.md"
    }
  ],
  "metadata": {
    "note": "Sample only"
  }
}
'@

    & $python $validator $hookSchema $sampleHookPath
    if ($LASTEXITCODE -ne 0) { throw "hook observation sample validation failed" }
    & $python $validator $subagentSchema $sampleSubagentPath
    if ($LASTEXITCODE -ne 0) { throw "subagent run sample validation failed" }

    Assert-JsonEqual -LeftPath $hookSchema -RightPath $hookTemplate
    Assert-JsonEqual -LeftPath $subagentSchema -RightPath $subagentTemplate

    $observeHook = Join-Path $templateRoot ".codex\hooks\observe.ps1"
    if (Test-Path $observeHook) {
        $observationLog = Join-Path $tempRoot "hooks.jsonl"
        $success = Invoke-WindowsPowerShellFile -ScriptPath $observeHook -ExtraEnv @{
            CODEX_HOOK_EVENT = "PreToolUse"
            CODEX_HOOK_TOOL_NAME = "PowerShell"
            CODEX_HOOK_TOOL_OPERATION = "command"
            CODEX_HOOK_TOOL_TARGET = "scripts/verify"
            CODEX_HOOK_INPUT_SUMMARY = "Run verification command"
            CODEX_OBSERVATION_LOG = $observationLog
        }
        if ($success.ExitCode -ne 0) {
            throw "observe.ps1 failed unexpectedly: $($success.StdErr)"
        }

        $lines = @(Get-Content -Path $observationLog)
        if ($lines.Count -ne 1) {
            throw "expected one JSONL line, got $($lines.Count)"
        }

        $payload = $lines[0] | ConvertFrom-Json
        if ($payload.source -ne "codex_hook") { throw "expected source codex_hook, got $($payload.source)" }
        if ($payload.event -ne "PreToolUse") { throw "expected event PreToolUse, got $($payload.event)" }
        if ($payload.blocking -ne $false) { throw "expected blocking false, got $($payload.blocking)" }
        if ($payload.decision.action -ne "observe") { throw "expected decision.action observe, got $($payload.decision.action)" }

        $observedPayloadPath = Join-Path $tempRoot "observed-hook-event.json"
        Write-Utf8NoBom -Path $observedPayloadPath -Content ($payload | ConvertTo-Json -Depth 10)
        & $python $validator $hookSchema $observedPayloadPath
        if ($LASTEXITCODE -ne 0) { throw "observe.ps1 output failed schema validation" }

        $failureDir = Join-Path $tempRoot "failure-dir"
        New-Item -ItemType Directory -Force -Path $failureDir | Out-Null
        $failure = Invoke-WindowsPowerShellFile -ScriptPath $observeHook -ExtraEnv @{
            CODEX_HOOK_EVENT = "PreToolUse"
            CODEX_HOOK_TOOL_NAME = "PowerShell"
            CODEX_HOOK_INPUT_SUMMARY = "Run verification command"
            CODEX_OBSERVATION_LOG = $failureDir
        }
        if ($failure.ExitCode -ne 0) {
            throw "observe.ps1 should exit 0 even when append fails"
        }
    }
}
finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}

Write-Host "PASS: observation baseline checks"
