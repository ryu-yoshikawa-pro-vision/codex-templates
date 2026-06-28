[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$templateSourceRoot = Join-Path $sourceRepoRoot "template"
$tempRoot = Join-Path $env:TEMP ("codex-run-artifacts-test-" + [guid]::NewGuid().ToString())
$templateRoot = Join-Path $tempRoot "template"

function Invoke-WindowsPowerShellFile {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments = @()
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath 'powershell.exe' `
            -ArgumentList (@('-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments) `
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
        Remove-Item -Force $stdoutFile, $stderrFile -ErrorAction SilentlyContinue
    }
}

function Invoke-PythonValidation {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$SchemaPath,
        [Parameter(Mandatory = $true)][string]$JsonPath
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath 'python' `
            -ArgumentList @($ScriptPath, $SchemaPath, $JsonPath) `
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
        Remove-Item -Force $stdoutFile, $stderrFile -ErrorAction SilentlyContinue
    }
}

New-Item -ItemType Directory -Force -Path $templateRoot | Out-Null
Get-ChildItem -Force -Path $templateSourceRoot | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $templateRoot -Recurse -Force
}

Push-Location $templateRoot
try {
    $runId = "20260628-120100-JST"
    $newRun = Invoke-WindowsPowerShellFile -ScriptPath (Join-Path $templateRoot "scripts\\new-run.ps1") -Arguments @('-RunId', $runId, '-TaskType', 'harness-improvement', '-WorkflowLevel', 'strict')
    if ($newRun.ExitCode -ne 0) { throw "new-run failed: $($newRun.StdOut)`n$($newRun.StdErr)" }

    $runRoot = Join-Path $templateRoot ".codex\\runs\\$runId"
    New-Item -ItemType Directory -Force -Path (Join-Path $runRoot "reports"), (Join-Path $runRoot "subagents"), (Join-Path $runRoot "logs"), (Join-Path $templateRoot ".codex\\observations") | Out-Null
    '{"status":"ok"}' | Set-Content -Path (Join-Path $runRoot "reports\\codex-task-a.report.json")
    '{"status":"ok"}' | Set-Content -Path (Join-Path $runRoot "reports\\codex-task-b.report.json")

    @'
{
  "schema_version": 1,
  "subagent_run_id": "subagent-001",
  "parent_run_id": "20260628-120100-JST",
  "agent": {"name": "implementation_worker", "model": "gpt-5.4-mini"},
  "role": "implementation_worker",
  "mode": "writable",
  "purpose": "Update one doc in scope.",
  "sandbox": {"type": "workspace-write", "network": false},
  "allowed_files": ["docs/reference/hook-observation.md"],
  "input_files": [],
  "changed_files": ["docs/reference/hook-observation.md"],
  "scope": {"declared": true, "compliant": true, "violations": []},
  "started_at": "2026-06-28T03:00:00Z",
  "ended_at": "2026-06-28T03:02:00Z",
  "status": "completed",
  "summary": "Updated the requested doc in scope.",
  "parent_decision": {"action": "accepted", "reason": "The output stayed within scope."},
  "used_in_final_plan": true,
  "evidence": [{"kind": "path", "value": "docs/reference/hook-observation.md"}],
  "metadata": {}
}
'@ | Set-Content -Path (Join-Path $runRoot "subagents\\subagent-001.json")
    '{"bad":' | Set-Content -Path (Join-Path $runRoot "subagents\\bad.json")
    @'
{
  "schema_version": 1,
  "subagent_run_id": "subagent-999",
  "parent_run_id": "20260628-999999-JST",
  "agent": {"name": "implementation_worker", "model": "gpt-5.4-mini"},
  "role": "implementation_worker",
  "mode": "writable",
  "purpose": "Mismatch sample",
  "sandbox": {"type": "workspace-write", "network": false},
  "allowed_files": ["README.md"],
  "input_files": [],
  "changed_files": ["README.md"],
  "scope": {"declared": true, "compliant": true, "violations": []},
  "started_at": "2026-06-28T03:00:00Z",
  "ended_at": "2026-06-28T03:01:00Z",
  "status": "completed",
  "summary": "Mismatch sample",
  "parent_decision": {"action": "rejected", "reason": "Wrong run"},
  "used_in_final_plan": false,
  "evidence": [],
  "metadata": {}
}
'@ | Set-Content -Path (Join-Path $runRoot "subagents\\mismatch.json")

    @"
{"schema_version":1,"event_id":"evt-1","run_id":"$runId","timestamp":"2026-06-28T03:00:00Z","source":"codex_hook","event":"WrapperStart","severity":"info","blocking":false,"tool":null,"cwd":"/workspace","input_summary":"wrapper start","decision":{"action":"observe","reason":"sample"},"evidence":[],"metadata":{}}
{"schema_version":1,"event_id":"evt-2","run_id":"$runId","timestamp":"2026-06-28T03:01:00Z","source":"codex_hook","event":"SafetyBlocked","severity":"warning","blocking":true,"tool":{"name":"Bash","operation":"command","target":"rm file.txt"},"cwd":"/workspace","input_summary":"delete attempt","decision":{"action":"block","reason":"delete attempt blocked"},"evidence":[],"metadata":{"type":"delete_attempt"}}
{"schema_version":1,"event_id":"evt-3","run_id":"$runId","timestamp":"2026-06-28T03:02:00Z","source":"codex_hook","event":"ObservationError","severity":"error","blocking":false,"tool":null,"cwd":"/workspace","input_summary":"observe failed","decision":{"action":"error","reason":"sample"},"evidence":[],"metadata":{}}
not-json
{"schema_version":1,"event_id":"evt-other","run_id":"20260628-999999-JST","timestamp":"2026-06-28T03:03:00Z","source":"codex_hook","event":"SafetyBlocked","severity":"warning","blocking":true,"tool":null,"cwd":"/workspace","input_summary":"ignore","decision":{"action":"block","reason":"other run"},"evidence":[],"metadata":{"type":"git_mutation"}}
"@ | Set-Content -Path (Join-Path $templateRoot ".codex\\observations\\hooks.jsonl")

    @"
{"schema_version":1,"event_id":"evt-4","run_id":"$runId","timestamp":"2026-06-28T03:04:00Z","source":"subagent","event":"SubagentStart","severity":"info","blocking":false,"tool":null,"cwd":"/workspace","input_summary":"subagent start","decision":{"action":"observe","reason":"sample"},"evidence":[],"metadata":{}}
{"schema_version":1,"event_id":"evt-5","run_id":"$runId","timestamp":"2026-06-28T03:05:00Z","source":"codex_hook","event":"SafetyBlocked","severity":"warning","blocking":true,"tool":{"name":"Git","operation":"command","target":"git add ."},"cwd":"/workspace","input_summary":"git mutation attempt","decision":{"action":"block","reason":"git mutation blocked"},"evidence":[],"metadata":{"type":"git_mutation"}}
"@ | Set-Content -Path (Join-Path $runRoot "logs\\extra-hooks.jsonl")

    @"
{
  "schema_version": 1,
  "run_id": "$runId",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {"rating": "warn", "evidence": "Needs more work."},
    "scope_control": {"rating": "pass", "evidence": "Scope stayed bounded."},
    "validation_confidence": {"rating": "warn", "evidence": "Validation was incomplete."},
    "safety_compliance": {"rating": "pass", "evidence": "Safety boundary held."},
    "reviewability": {"rating": "pass", "evidence": "Artifacts are reviewable."},
    "maintainability": {"rating": "pass", "evidence": "Changes stay local."},
    "reproducibility": {"rating": "pass", "evidence": "Artifacts are reproducible."}
  },
  "findings": [],
  "improvement_candidates": []
}
"@ | Set-Content -Path (Join-Path $runRoot "evaluation.json")

    $manifestPath = Join-Path $runRoot "run.json"
    $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
    $manifest.changed_files = @("README.md")
    $manifest.validation.status = "passed_with_warnings"
    $manifest.validation.commands = @(
        [ordered]@{ command = "bash template/scripts/verify"; exit_code = 0; status = "passed"; evidence = "verify passed" }
    )
    $manifest.validation.warnings = @(
        [ordered]@{ type = "expected_changed_file_missing"; path = "README.md"; message = "sample warning" }
    )
    $manifest.status = "completed"
    ($manifest | ConvertTo-Json -Depth 8) | Set-Content -Path $manifestPath

    $collector = Invoke-WindowsPowerShellFile -ScriptPath (Join-Path $templateRoot "scripts\\collect-run-artifacts.ps1") -Arguments @('-RunId', $runId)
    if ($collector.ExitCode -ne 0) { throw "collector failed: $($collector.StdOut)`n$($collector.StdErr)" }

    $data = Get-Content -Raw $manifestPath | ConvertFrom-Json
    if (@($data.codex_task_reports).Count -ne 2) { throw "Expected two report refs, got $(@($data.codex_task_reports).Count)" }
    if ($data.artifact_summary.codex_task_report_count -ne 2 -or $data.artifact_summary.hook_event_count -ne 5 -or $data.artifact_summary.subagent_run_count -ne 1 -or $data.artifact_summary.evaluation_present -ne $true) {
        throw "Unexpected artifact_summary: $($data.artifact_summary | ConvertTo-Json -Depth 6)"
    }
    $changed = @($data.changed_files)
    if (@(@("README.md", "docs/reference/hook-observation.md") | Where-Object { $_ -notin $changed }).Count -ne 0) { throw "Unexpected changed_files: $($changed -join ', ')" }
    if ($data.hook_observations.event_counts.SafetyBlocked -ne 2 -or $data.hook_observations.event_counts.ObservationError -ne 1 -or $data.hook_observations.event_counts.WrapperStart -ne 1 -or $data.hook_observations.event_counts.SubagentStart -ne 1) {
        throw "Unexpected hook event counts: $($data.hook_observations | ConvertTo-Json -Depth 6)"
    }
    if ($data.safety.delete_attempt_blocked -ne $true -or $data.safety.git_mutation_attempt_blocked -ne $true) { throw "Safety summary was not updated: $($data.safety | ConvertTo-Json -Depth 4)" }
    if ($data.subagents.summary.total -ne 1 -or $data.subagents.summary.writable -ne 1 -or $data.subagents.summary.used_in_final_plan -ne 1) { throw "Unexpected subagent summary: $($data.subagents.summary | ConvertTo-Json -Depth 4)" }
    if ($data.evaluation_path -ne ".codex/runs/$runId/evaluation.json") { throw "Unexpected evaluation_path: $($data.evaluation_path)" }
    if ($data.primary_failure_category -ne "missing_validation") { throw "Unexpected primary_failure_category: $($data.primary_failure_category)" }
    if ("implementation_worker" -notin @($data.agents_used)) { throw "agents_used missing implementation_worker: $($data.agents_used -join ', ')" }
    $warningTypes = @($data.validation.warnings | ForEach-Object { $_.type })
    foreach ($expected in @("expected_changed_file_missing", "subagent_invalid_json", "subagent_parent_run_mismatch", "hook_observation_invalid_jsonl")) {
        if ($expected -notin $warningTypes) { throw "Missing warning ${expected}: $($warningTypes -join ', ')" }
    }

    $validator = Join-Path $templateRoot "scripts\\validate-output-schema.py"
    $schema = Join-Path $templateRoot ".codex\\templates\\evaluation.schema.json"
    @'
{
  "schema_version": 1,
  "run_id": "20260628-120101-JST",
  "result": "not_evaluated",
  "primary_failure_category": null,
  "failure_categories": [],
  "dimensions": {
    "task_completion": {"rating": "not_evaluated", "evidence": "pending"},
    "scope_control": {"rating": "not_evaluated", "evidence": "pending"},
    "validation_confidence": {"rating": "not_evaluated", "evidence": "pending"},
    "safety_compliance": {"rating": "not_evaluated", "evidence": "pending"},
    "reviewability": {"rating": "not_evaluated", "evidence": "pending"},
    "maintainability": {"rating": "not_evaluated", "evidence": "pending"},
    "reproducibility": {"rating": "not_evaluated", "evidence": "pending"}
  },
  "findings": [],
  "improvement_candidates": []
}
'@ | Set-Content -Path (Join-Path $tempRoot "evaluation-old.json")
    @'
{
  "schema_version": 1,
  "run_id": "20260628-120102-JST",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {
      "rating": "warn",
      "evidence": "verify failed",
      "evidence_refs": [{"kind": "validation_command", "path": ".codex/runs/20260628-120102-JST/run.json", "selector": "$.validation.commands[0]", "event_id": null, "summary": "verify failed"}]
    },
    "scope_control": {"rating": "pass", "evidence": "bounded", "evidence_refs": []},
    "validation_confidence": {"rating": "warn", "evidence": "partial", "evidence_refs": []},
    "safety_compliance": {"rating": "pass", "evidence": "safe", "evidence_refs": []},
    "reviewability": {"rating": "pass", "evidence": "reviewable", "evidence_refs": []},
    "maintainability": {"rating": "pass", "evidence": "maintainable", "evidence_refs": []},
    "reproducibility": {"rating": "pass", "evidence": "reproducible", "evidence_refs": []}
  },
  "findings": [],
  "improvement_candidates": [{"target": "scripts/codex-task.sh", "evidence": "same failure repeated", "evidence_refs": [], "expected_impact": "better validation", "recommendation": "tighten checks"}]
}
'@ | Set-Content -Path (Join-Path $tempRoot "evaluation-new.json")
    @'
{
  "schema_version": 1,
  "run_id": "20260628-120103-JST",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {"rating": "warn", "evidence": "verify failed", "evidence_refs": [{"kind": "bad_kind", "path": null, "selector": null, "event_id": null, "summary": "bad"}]},
    "scope_control": {"rating": "pass", "evidence": "bounded"},
    "validation_confidence": {"rating": "warn", "evidence": "partial"},
    "safety_compliance": {"rating": "pass", "evidence": "safe"},
    "reviewability": {"rating": "pass", "evidence": "reviewable"},
    "maintainability": {"rating": "pass", "evidence": "maintainable"},
    "reproducibility": {"rating": "pass", "evidence": "reproducible"}
  },
  "findings": [],
  "improvement_candidates": []
}
'@ | Set-Content -Path (Join-Path $tempRoot "evaluation-invalid-kind.json")
    @'
{
  "schema_version": 1,
  "run_id": "20260628-120104-JST",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {"rating": "warn"},
    "scope_control": {"rating": "pass", "evidence": "bounded"},
    "validation_confidence": {"rating": "warn", "evidence": "partial"},
    "safety_compliance": {"rating": "pass", "evidence": "safe"},
    "reviewability": {"rating": "pass", "evidence": "reviewable"},
    "maintainability": {"rating": "pass", "evidence": "maintainable"},
    "reproducibility": {"rating": "pass", "evidence": "reproducible"}
  },
  "findings": [],
  "improvement_candidates": []
}
'@ | Set-Content -Path (Join-Path $tempRoot "evaluation-missing-evidence.json")

    $oldValidation = Invoke-PythonValidation -ScriptPath $validator -SchemaPath $schema -JsonPath (Join-Path $tempRoot "evaluation-old.json")
    if ($oldValidation.ExitCode -ne 0) { throw "old evaluation should be valid: $($oldValidation.StdErr)" }
    $newValidation = Invoke-PythonValidation -ScriptPath $validator -SchemaPath $schema -JsonPath (Join-Path $tempRoot "evaluation-new.json")
    if ($newValidation.ExitCode -ne 0) { throw "new evaluation should be valid: $($newValidation.StdErr)" }
    $invalidKind = Invoke-PythonValidation -ScriptPath $validator -SchemaPath $schema -JsonPath (Join-Path $tempRoot "evaluation-invalid-kind.json")
    if ($invalidKind.ExitCode -eq 0) { throw "invalid evidence kind unexpectedly passed" }
    $missingEvidence = Invoke-PythonValidation -ScriptPath $validator -SchemaPath $schema -JsonPath (Join-Path $tempRoot "evaluation-missing-evidence.json")
    if ($missingEvidence.ExitCode -eq 0) { throw "missing evidence unexpectedly passed" }
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}

Write-Host "PASS: run artifact aggregation PowerShell checks"
