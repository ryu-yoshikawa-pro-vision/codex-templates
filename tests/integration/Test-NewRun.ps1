[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$templateSourceRoot = Join-Path $sourceRepoRoot "template"
$tempRoot = Join-Path $env:TEMP ("codex-new-run-test-" + [guid]::NewGuid().ToString())
$templateRoot = Join-Path $tempRoot "template"
$wrapperPath = Join-Path $templateRoot "scripts\\new-run.ps1"

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

        $stdout = if (Test-Path $stdoutFile) { Get-Content $stdoutFile -Raw } else { '' }
        $stderr = if (Test-Path $stderrFile) { Get-Content $stderrFile -Raw } else { '' }
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            StdOut = $stdout
            StdErr = $stderr
            Combined = (($stdout + "`n" + $stderr).Trim())
        }
    }
    finally {
        Remove-Item -Force $stdoutFile, $stderrFile -ErrorAction SilentlyContinue
    }
}

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Force -Path $templateRoot | Out-Null
Get-ChildItem -Force -Path $templateSourceRoot | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $templateRoot -Recurse -Force
}
Push-Location $templateRoot
try {
    $runId = "20260628-113100-JST"
    $result = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '-RunId', $runId,
        '-TaskType', 'harness-improvement',
        '-WorkflowLevel', 'strict',
        '-Preset', 'auto-net'
    )
    if ($result.ExitCode -ne 0) { throw "new-run failed unexpectedly: $($result.Combined)" }
    foreach ($path in @(
        (Join-Path $templateRoot ".codex\\runs\\$runId\\PLAN.md"),
        (Join-Path $templateRoot ".codex\\runs\\$runId\\TASKS.md"),
        (Join-Path $templateRoot ".codex\\runs\\$runId\\REPORT.md"),
        (Join-Path $templateRoot ".codex\\runs\\$runId\\run.json")
    )) {
        if (-not (Test-Path $path)) { throw "Missing expected file: $path" }
    }

    $manifest = Get-Content -Raw (Join-Path $templateRoot ".codex\\runs\\$runId\\run.json") | ConvertFrom-Json
    if ($manifest.run_id -ne $runId) { throw "Expected run_id $runId, got $($manifest.run_id)" }
    if ($manifest.task_type -ne 'harness-improvement') { throw "Expected harness-improvement task type, got $($manifest.task_type)" }
    if ($manifest.workflow_level -ne 'strict') { throw "Expected strict workflow, got $($manifest.workflow_level)" }
    if ($manifest.preset -ne 'auto-net') { throw "Expected auto-net preset, got $($manifest.preset)" }

    $duplicate = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-RunId', $runId, '-Force')
    if ($duplicate.ExitCode -eq 0) { throw "Duplicate run unexpectedly succeeded" }
    if ($duplicate.Combined -notmatch [regex]::Escape('Run directory already exists')) { throw "Duplicate run message missing: $($duplicate.Combined)" }

    $noPlanRunId = "20260628-113101-JST"
    $noPlan = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-RunId', $noPlanRunId, '-NoPlan', '-NoRunManifest')
    if ($noPlan.ExitCode -ne 0) { throw "NoPlan/NoRunManifest case failed unexpectedly: $($noPlan.Combined)" }
    if (Test-Path (Join-Path $templateRoot ".codex\\runs\\$noPlanRunId\\PLAN.md")) { throw "PLAN.md should not exist for NoPlan case" }
    if (Test-Path (Join-Path $templateRoot ".codex\\runs\\$noPlanRunId\\run.json")) { throw "run.json should not exist for NoRunManifest case" }

    $invalidTask = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-TaskType', 'invalid')
    if ($invalidTask.ExitCode -eq 0) { throw "Invalid task type unexpectedly succeeded" }

    $invalidWorkflow = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-WorkflowLevel', 'invalid')
    if ($invalidWorkflow.ExitCode -eq 0) { throw "Invalid workflow level unexpectedly succeeded" }

    Move-Item -LiteralPath (Join-Path $templateRoot ".codex\\templates\\RUN_MANIFEST.json") -Destination (Join-Path $templateRoot ".codex\\templates\\RUN_MANIFEST.json.bak")
    try {
        $rollbackRunId = "20260628-113102-JST"
        $rollback = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-RunId', $rollbackRunId)
        if ($rollback.ExitCode -eq 0) { throw "Rollback failure case unexpectedly succeeded" }
        if (Test-Path (Join-Path $templateRoot ".codex\\runs\\$rollbackRunId")) { throw "Run directory should be removed after failure rollback" }
    }
    finally {
        Move-Item -LiteralPath (Join-Path $templateRoot ".codex\\templates\\RUN_MANIFEST.json.bak") -Destination (Join-Path $templateRoot ".codex\\templates\\RUN_MANIFEST.json")
    }
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}

Write-Host "PASS: new-run PowerShell checks"
