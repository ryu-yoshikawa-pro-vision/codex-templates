[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$templateRoot = Join-Path $sourceRepoRoot "template"
$wrapperPath = Join-Path $templateRoot "scripts\\codex-task.ps1"
$sandboxPath = Join-Path $templateRoot "scripts\\codex-sandbox.ps1"
$fakeCodex = Join-Path $sourceRepoRoot "tests\\fixtures\\fake-codex.ps1"
$fakeDocker = Join-Path $sourceRepoRoot "tests\\fixtures\\fake-docker.ps1"
$tempRoot = Join-Path $env:TEMP ("codex-task-test-" + [guid]::NewGuid().ToString())

function Test-PythonAvailable {
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
            if ($LASTEXITCODE -eq 0) { return $true }
        }
        catch {
        }
        finally {
            if ($hasNativeErrPref) {
                $PSNativeCommandUseErrorActionPreference = $prevNativeErr
            }
        }
    }
    return $false
}

function Invoke-WindowsPowerShellFile {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
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
        foreach ($pair in $ExtraEnv.GetEnumerator()) {
            [System.Environment]::SetEnvironmentVariable($pair.Key, $null)
        }
        Remove-Item -Force $stdoutFile, $stderrFile -ErrorAction SilentlyContinue
    }
}

function Assert-ReportStatus {
    param(
        [string]$Path,
        [string]$ExpectedStatus
    )

    if (-not (Test-Path $Path)) {
        throw "Missing report file: $Path"
    }
    $report = Get-Content -Raw $Path | ConvertFrom-Json
    if ($report.status -ne $ExpectedStatus) {
        throw "Expected report status '$ExpectedStatus', got '$($report.status)'"
    }
    foreach ($key in @('runtime', 'preset', 'mode', 'run_id', 'cwd', 'git_branch', 'git_dirty', 'prompt_source', 'output_file', 'output_schema', 'log_path', 'codex_exit_code', 'verify_exit_code', 'status')) {
        if (-not ($report.PSObject.Properties.Name -contains $key)) {
            throw "Missing report key: $key"
        }
    }
    return $report
}

function Assert-RunManifestBaseline {
    param(
        [string]$Path,
        [string]$ExpectedRunId,
        [string]$ExpectedReportName
    )

    if (-not (Test-Path $Path)) {
        throw "Missing run manifest file: $Path"
    }

    $manifest = Get-Content -Raw $Path | ConvertFrom-Json
    if ($manifest.run_id -ne $ExpectedRunId) { throw "Expected run_id $ExpectedRunId, got $($manifest.run_id)" }
    if ($manifest.task_type -ne 'implementation') { throw "Expected default task_type implementation, got $($manifest.task_type)" }
    if ($manifest.workflow_level -ne 'standard') { throw "Expected default workflow_level standard, got $($manifest.workflow_level)" }
    if ($manifest.validation.status -ne 'skipped') { throw "Expected validation.status skipped, got $($manifest.validation.status)" }
    if ($manifest.status -ne 'completed') { throw "Expected run status completed, got $($manifest.status)" }
    if (@($manifest.codex_task_reports).Count -lt 1) { throw "Expected codex_task_reports to contain at least one entry" }
    $reportRef = ([string]$manifest.codex_task_reports[0] -replace '\\', '/') -replace '/+', '/'
    if ($reportRef -notmatch [regex]::Escape(".codex/runs/$ExpectedRunId/reports/")) {
        throw "Expected report ref under .codex/runs/$ExpectedRunId/reports/, got $reportRef"
    }
    if (-not $reportRef.EndsWith($ExpectedReportName)) {
        throw "Expected report ref to end with $ExpectedReportName, got $reportRef"
    }
    if (@($manifest.changed_files).Count -ne 0) { throw "Expected changed_files to be empty" }
    if ($null -ne $manifest.evaluation_path) { throw "Expected evaluation_path to be null" }
    if ($null -ne $manifest.primary_failure_category) { throw "Expected primary_failure_category to be null" }
}

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
Push-Location $templateRoot
try {
    $schemaPath = Join-Path $tempRoot "schema.json"
    $unsupportedSchemaPath = Join-Path $tempRoot "unsupported-schema.json"
    $verifyOkCmd = Join-Path $tempRoot "verify-ok.cmd"
    $verifyFailCmd = Join-Path $tempRoot "verify-fail.cmd"
    Set-Content -Path $schemaPath -Value '{"type":"object","required":["status"],"properties":{"status":{"type":"string"}},"additionalProperties":false}'
    Set-Content -Path $unsupportedSchemaPath -Value '{"oneOf":[{"type":"object"}]}'
    Set-Content -Path $verifyOkCmd -Value '@exit /b 0'
    Set-Content -Path $verifyFailCmd -Value '@exit /b 7'

    $envMap = @{
        CODEX_BIN = $fakeCodex
    }
    $pythonAvailable = Test-PythonAvailable

    $outputOk = Join-Path $tempRoot "ok.json"
    $reportOk = Join-Path $tempRoot "ok.report.json"
    $okArgs = @(
        '--output-file', $outputOk,
        '--report-path', $reportOk,
        '--log-path', (Join-Path $tempRoot "ok.jsonl"),
        '--verify-command', $verifyOkCmd,
        'SCHEMA_OK'
    )
    if ($pythonAvailable) {
        $okArgs = @(
            '--output-file', $outputOk,
            '--output-schema', $schemaPath,
            '--report-path', $reportOk,
            '--log-path', (Join-Path $tempRoot "ok.jsonl"),
            '--verify-command', $verifyOkCmd,
            'SCHEMA_OK'
        )
    }
    $resultOk = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments $okArgs -ExtraEnv $envMap
    if ($resultOk.ExitCode -ne 0) { throw "Expected success, got exit=$($resultOk.ExitCode): $($resultOk.Combined)" }
    if (-not (Test-Path $outputOk)) { throw "Missing output file for success case" }
    $okReport = Assert-ReportStatus -Path $reportOk -ExpectedStatus 'ok'
    if ($okReport.preset -ne 'safe') { throw "Expected safe preset in report" }

    $readonlyOut = Join-Path $tempRoot "readonly.json"
    $readonlyReport = Join-Path $tempRoot "readonly.report.json"
    $readonly = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--preset', 'readonly',
        '--output-file', $readonlyOut,
        '--report-path', $readonlyReport,
        '--log-path', (Join-Path $tempRoot "readonly.jsonl"),
        '--skip-verify',
        'READONLY_OK'
    ) -ExtraEnv $envMap
    if ($readonly.ExitCode -ne 0) { throw "Readonly case failed unexpectedly: $($readonly.Combined)" }
    Assert-ReportStatus -Path $readonlyReport -ExpectedStatus 'verify_skipped' | Out-Null

    $autoNetOut = Join-Path $tempRoot "auto-net.json"
    $autoNetReport = Join-Path $tempRoot "auto-net.report.json"
    $autoNetEnv = @{
        CODEX_BIN = $fakeCodex
        FAKE_CODEX_DOCKER_PS_DECISION = 'allow'
        FAKE_CODEX_ALLOW_NEVER = '1'
    }
    $autoNet = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--preset', 'auto-net',
        '--output-file', $autoNetOut,
        '--report-path', $autoNetReport,
        '--log-path', (Join-Path $tempRoot "auto-net.jsonl"),
        '--skip-verify',
        'AUTO_NET_OK'
    ) -ExtraEnv $autoNetEnv
    if ($autoNet.ExitCode -ne 0) { throw "auto-net case failed unexpectedly: $($autoNet.Combined)" }
    $autoNetJson = Assert-ReportStatus -Path $autoNetReport -ExpectedStatus 'verify_skipped'
    if ($autoNetJson.preset -ne 'auto-net') { throw "Expected auto-net preset in report" }

    $nativeParamOut = Join-Path $tempRoot "native-param.json"
    $nativeParamReport = Join-Path $tempRoot "native-param.report.json"
    $nativeParam = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '-Preset', 'auto-net',
        '-OutputFile', $nativeParamOut,
        '-ReportPath', $nativeParamReport,
        '-LogPath', (Join-Path $tempRoot "native-param.jsonl"),
        '-SkipVerify',
        'AUTO_NET_NATIVE_PARAM_OK'
    ) -ExtraEnv $autoNetEnv
    if ($nativeParam.ExitCode -ne 0) { throw "native PowerShell parameter case failed unexpectedly: $($nativeParam.Combined)" }
    $nativeParamJson = Assert-ReportStatus -Path $nativeParamReport -ExpectedStatus 'verify_skipped'
    if ($nativeParamJson.preset -ne 'auto-net') { throw "Expected auto-net preset for native PowerShell parameter case" }

    $runId = "20260420-020301-JST"
    $runIdCase = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $runId,
        '--skip-verify',
        'RUN_ID_OK'
    ) -ExtraEnv $envMap
    if ($runIdCase.ExitCode -ne 0) { throw "Run-id case failed unexpectedly: $($runIdCase.Combined)" }
    $runReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $runId "reports"))
    $runReportPath = (Get-ChildItem -Path $runReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    $runReport = Assert-ReportStatus -Path $runReportPath -ExpectedStatus 'verify_skipped'
    if ($runReport.run_id -ne $runId) { throw "Expected run_id $runId, got $($runReport.run_id)" }
    foreach ($value in @($runReport.output_file, $runReport.log_path)) {
        $normalized = ($value -replace '\\', '/') -replace '/+', '/'
        if ($normalized -notmatch [regex]::Escape(".codex/runs/$runId/")) {
            throw "Run-local path expected, got: $value"
        }
    }

    $manifestRunId = "20260420-020303-JST"
    $manifestCase = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $manifestRunId,
        '--record-run-manifest',
        '--skip-verify',
        'RUN_MANIFEST_OK'
    ) -ExtraEnv $envMap
    if ($manifestCase.ExitCode -ne 0) { throw "run manifest case failed unexpectedly: $($manifestCase.Combined)" }
    $manifestReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $manifestRunId "reports"))
    $manifestReportPath = (Get-ChildItem -Path $manifestReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $manifestReportPath -ExpectedStatus 'verify_skipped' | Out-Null
    Assert-RunManifestBaseline -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $manifestRunId "run.json"))) -ExpectedRunId $manifestRunId -ExpectedReportName ([System.IO.Path]::GetFileName($manifestReportPath))

    $missingRunIdReport = Join-Path $tempRoot "missing-run-id.report.json"
    $missingRunId = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $missingRunIdReport,
        '--log-path', (Join-Path $tempRoot "missing-run-id.jsonl"),
        '--record-run-manifest',
        '--skip-verify',
        'RUN_MANIFEST_NO_RUN_ID'
    ) -ExtraEnv $envMap
    if ($missingRunId.ExitCode -eq 0) { throw "missing run-id manifest case unexpectedly succeeded" }
    if ($missingRunId.Combined -notmatch [regex]::Escape('--record-run-manifest requires --run-id')) { throw "Missing run-id manifest message missing: $($missingRunId.Combined)" }
    Assert-ReportStatus -Path $missingRunIdReport -ExpectedStatus 'invalid_args' | Out-Null

    $invalidTaskTypeReport = Join-Path $tempRoot "invalid-task-type.report.json"
    $invalidTaskType = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $invalidTaskTypeReport,
        '--log-path', (Join-Path $tempRoot "invalid-task-type.jsonl"),
        '--task-type', 'invalid',
        '--skip-verify',
        'INVALID_TASK_TYPE'
    ) -ExtraEnv $envMap
    if ($invalidTaskType.ExitCode -eq 0) { throw "invalid task-type case unexpectedly succeeded" }
    if ($invalidTaskType.Combined -notmatch 'Invalid --task-type') { throw "Invalid task-type message missing: $($invalidTaskType.Combined)" }
    Assert-ReportStatus -Path $invalidTaskTypeReport -ExpectedStatus 'invalid_args' | Out-Null

    $invalidWorkflowLevelReport = Join-Path $tempRoot "invalid-workflow-level.report.json"
    $invalidWorkflowLevel = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $invalidWorkflowLevelReport,
        '--log-path', (Join-Path $tempRoot "invalid-workflow-level.jsonl"),
        '--workflow-level', 'invalid',
        '--skip-verify',
        'INVALID_WORKFLOW_LEVEL'
    ) -ExtraEnv $envMap
    if ($invalidWorkflowLevel.ExitCode -eq 0) { throw "invalid workflow-level case unexpectedly succeeded" }
    if ($invalidWorkflowLevel.Combined -notmatch 'Invalid --workflow-level') { throw "Invalid workflow-level message missing: $($invalidWorkflowLevel.Combined)" }
    Assert-ReportStatus -Path $invalidWorkflowLevelReport -ExpectedStatus 'invalid_args' | Out-Null

    $invalidRunReport = Join-Path $tempRoot "invalid-run.report.json"
    $invalidRun = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $invalidRunReport,
        '--log-path', (Join-Path $tempRoot "invalid-run.jsonl"),
        '--run-id', '..\escape',
        '--skip-verify',
        'RUN_ID_BAD'
    ) -ExtraEnv $envMap
    if ($invalidRun.ExitCode -eq 0) { throw "Invalid run-id case unexpectedly succeeded" }
    if ($invalidRun.Combined -notmatch 'Invalid --run-id') { throw "Invalid run-id message missing: $($invalidRun.Combined)" }
    Assert-ReportStatus -Path $invalidRunReport -ExpectedStatus 'invalid_args' | Out-Null

    $blockedReport = Join-Path $tempRoot "blocked.report.json"
    $blocked = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $blockedReport,
        '--log-path', (Join-Path $tempRoot "blocked.jsonl"),
        '--dangerously-bypass-approvals-and-sandbox'
    ) -ExtraEnv $envMap
    if ($blocked.ExitCode -eq 0) { throw "Blocked args case unexpectedly succeeded" }
    if ($blocked.Combined -notmatch 'Unsafe Codex argument blocked') { throw "Blocked args message missing: $($blocked.Combined)" }
    Assert-ReportStatus -Path $blockedReport -ExpectedStatus 'blocked_args' | Out-Null

    $failReport = Join-Path $tempRoot "fail.report.json"
    $fail = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $failReport,
        '--log-path', (Join-Path $tempRoot "fail.jsonl"),
        '--skip-verify',
        'FAIL_CODEX'
    ) -ExtraEnv $envMap
    if ($fail.ExitCode -eq 0) { throw "FAIL_CODEX case unexpectedly succeeded" }
    $failJson = Assert-ReportStatus -Path $failReport -ExpectedStatus 'codex_failed'
    if ($failJson.codex_exit_code -ne 9) { throw "Expected codex_exit_code 9, got $($failJson.codex_exit_code)" }

    $verifyFailReport = Join-Path $tempRoot "verify-fail.report.json"
    $verifyFail = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $verifyFailReport,
        '--log-path', (Join-Path $tempRoot "verify-fail.jsonl"),
        '--verify-command', $verifyFailCmd,
        'VERIFY_FAIL'
    ) -ExtraEnv $envMap
    if ($verifyFail.ExitCode -eq 0) { throw "verify failure case unexpectedly succeeded" }
    $verifyFailJson = Assert-ReportStatus -Path $verifyFailReport -ExpectedStatus 'verify_failed'
    if ($verifyFailJson.verify_exit_code -ne 7) { throw "Expected verify_exit_code 7, got $($verifyFailJson.verify_exit_code)" }

    $verifyPsExprReport = Join-Path $tempRoot "verify-ps.report.json"
    $verifyPsExpr = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $verifyPsExprReport,
        '--log-path', (Join-Path $tempRoot "verify-ps.jsonl"),
        '--verify-command', 'Write-Host verify-ok; exit 0',
        'VERIFY_PS'
    ) -ExtraEnv $envMap
    if ($verifyPsExpr.ExitCode -ne 0) { throw "PowerShell verify expression failed unexpectedly: $($verifyPsExpr.Combined)" }
    Assert-ReportStatus -Path $verifyPsExprReport -ExpectedStatus 'ok' | Out-Null

    if ($pythonAvailable) {
        $schemaFailOut = Join-Path $tempRoot "schema-fail.json"
        $schemaFailReport = Join-Path $tempRoot "schema-fail.report.json"
        $schemaFail = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
            '--output-file', $schemaFailOut,
            '--output-schema', $schemaPath,
            '--report-path', $schemaFailReport,
            '--log-path', (Join-Path $tempRoot "schema-fail.jsonl"),
            '--skip-verify',
            'BAD_SCHEMA'
        ) -ExtraEnv $envMap
        if ($schemaFail.ExitCode -eq 0) { throw "schema failure case unexpectedly succeeded" }
        Assert-ReportStatus -Path $schemaFailReport -ExpectedStatus 'invalid_output' | Out-Null

        $unsupportedSchemaReport = Join-Path $tempRoot "unsupported-schema.report.json"
        $unsupportedSchema = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
            '--output-file', (Join-Path $tempRoot "unsupported-schema.json.out"),
            '--output-schema', $unsupportedSchemaPath,
            '--report-path', $unsupportedSchemaReport,
            '--log-path', (Join-Path $tempRoot "unsupported-schema.jsonl"),
            '--skip-verify',
            'SCHEMA_OK'
        ) -ExtraEnv $envMap
        if ($unsupportedSchema.ExitCode -eq 0) { throw "unsupported schema case unexpectedly succeeded" }
        Assert-ReportStatus -Path $unsupportedSchemaReport -ExpectedStatus 'invalid_output' | Out-Null
    }
    else {
        Write-Host "SKIP: PowerShell schema validation cases (Windows Python not available)"
        $schemaNoPythonReport = Join-Path $tempRoot "schema-no-python.report.json"
        $schemaNoPython = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
            '--output-file', (Join-Path $tempRoot "schema-no-python.json"),
            '--output-schema', $schemaPath,
            '--report-path', $schemaNoPythonReport,
            '--log-path', (Join-Path $tempRoot "schema-no-python.jsonl"),
            '--skip-verify',
            'SCHEMA_OK'
        ) -ExtraEnv $envMap
        if ($schemaNoPython.ExitCode -eq 0) { throw "schema validation unexpectedly succeeded without Windows Python" }
        if ($schemaNoPython.Combined -notmatch 'Python is required to validate output schema') {
            throw "Expected Python required message, got: $($schemaNoPython.Combined)"
        }
        Assert-ReportStatus -Path $schemaNoPythonReport -ExpectedStatus 'invalid_output' | Out-Null
    }

    $dockerMissingReport = Join-Path $tempRoot "docker-missing.report.json"
    $dockerMissing = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--runtime', 'docker-sandbox',
        '--report-path', $dockerMissingReport,
        '--log-path', (Join-Path $tempRoot "docker-missing.jsonl"),
        '--skip-verify',
        'DOCKER_MISSING'
    ) -ExtraEnv $envMap
    if ($dockerMissing.ExitCode -eq 0) { throw "docker missing case unexpectedly succeeded" }
    Assert-ReportStatus -Path $dockerMissingReport -ExpectedStatus 'docker_unavailable' | Out-Null

    if ($env:CODEX_ENABLE_DOCKER_SANDBOX_TEST -eq '1') {
        $dockerRunId = "20260420-020302-JST"
        $dockerEnv = @{
            CODEX_BIN = $fakeCodex
            CODEX_DOCKER_BIN = $fakeDocker
            CODEX_DOCKER_IMAGE = 'fake-image'
        }
        $dockerOk = Invoke-WindowsPowerShellFile -ScriptPath $sandboxPath -Arguments @(
            '--run-id', $dockerRunId,
            '--output-schema', $schemaPath,
            '--verify-command', $verifyOkCmd,
            'DOCKER_OK'
        ) -ExtraEnv $dockerEnv
        if ($dockerOk.ExitCode -ne 0) { throw "docker sandbox smoke failed: $($dockerOk.Combined)" }
        $dockerReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $dockerRunId "reports"))
        $dockerReport = (Get-ChildItem -Path $dockerReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
        Assert-ReportStatus -Path $dockerReport -ExpectedStatus 'ok' | Out-Null
    }
    else {
        Write-Host "SKIP: docker sandbox smoke (set CODEX_ENABLE_DOCKER_SANDBOX_TEST=1 to enable)"
    }
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}

Write-Host "PASS: Codex task harness checks"
