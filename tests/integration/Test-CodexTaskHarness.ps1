[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$templateSourceRoot = Join-Path $sourceRepoRoot "template"
$tempRoot = Join-Path $env:TEMP ("codex-task-test-" + [guid]::NewGuid().ToString())
$templateRoot = Join-Path $tempRoot "template"
$wrapperPath = Join-Path $templateRoot "scripts\\codex-task.ps1"
$sandboxPath = Join-Path $templateRoot "scripts\\codex-sandbox.ps1"
$fakeCodex = Join-Path $sourceRepoRoot "tests\\fixtures\\fake-codex.ps1"
$fakeDocker = Join-Path $sourceRepoRoot "tests\\fixtures\\fake-docker.ps1"

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
    $expectedPrefix = "^" + [regex]::Escape(".codex/runs/$ExpectedRunId/reports/")
    $reportRefs = @($manifest.codex_task_reports | ForEach-Object { (([string]$_) -replace '\\', '/') -replace '/+', '/' })
    if (@($reportRefs | Where-Object { $_ -notmatch $expectedPrefix }).Count -ne 0) {
        throw "Expected report refs under .codex/runs/$ExpectedRunId/reports/, got $($reportRefs -join ', ')"
    }
    if (@($reportRefs | Where-Object { $_.EndsWith($ExpectedReportName) }).Count -lt 1) {
        throw "Expected one report ref to end with $ExpectedReportName, got $($reportRefs -join ', ')"
    }
    if (@($manifest.changed_files).Count -ne 0) { throw "Expected changed_files to be empty" }
    if ($null -ne $manifest.evaluation_path) { throw "Expected evaluation_path to be null" }
    if ($null -ne $manifest.primary_failure_category) { throw "Expected primary_failure_category to be null" }
}

function Assert-RunManifestValidationFailed {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Missing run manifest file: $Path"
    }

    $manifest = Get-Content -Raw $Path | ConvertFrom-Json
    if ($manifest.status -ne 'failed') { throw "Expected run status failed, got $($manifest.status)" }
    if ($manifest.validation.status -ne 'failed') { throw "Expected validation.status failed, got $($manifest.validation.status)" }
    $commands = @($manifest.validation.commands)
    if ($commands.Count -lt 1) { throw "Expected at least one validation command, got $($commands.Count)" }
    $failedCommands = @($commands | Where-Object { $_.status -eq 'failed' })
    if ($failedCommands.Count -lt 1) { throw "Expected at least one failed validation command, got $($commands | ConvertTo-Json -Depth 6)" }
    foreach ($command in $failedCommands) {
        if ([string]::IsNullOrWhiteSpace([string]$command.evidence)) { throw "Expected non-empty validation command evidence" }
    }
}

function Assert-RunManifestState {
    param(
        [string]$Path,
        [string]$ExpectedRunStatus,
        [string]$ExpectedValidationStatus,
        [bool]$ExpectedScopeViolation,
        [string[]]$ExpectedChangedFiles,
        [string]$ExpectedCommand = $null,
        [string]$ExpectedCommandStatus = $null
    )

    if (-not (Test-Path $Path)) {
        throw "Missing run manifest file: $Path"
    }

    $manifest = Get-Content -Raw $Path | ConvertFrom-Json
    if ($manifest.status -ne $ExpectedRunStatus) { throw "Expected run status $ExpectedRunStatus, got $($manifest.status)" }
    if ($manifest.validation.status -ne $ExpectedValidationStatus) { throw "Expected validation.status $ExpectedValidationStatus, got $($manifest.validation.status)" }
    if ([bool]$manifest.safety.scope_violation -ne $ExpectedScopeViolation) { throw "Expected scope_violation $ExpectedScopeViolation, got $($manifest.safety.scope_violation)" }
    $actualChanged = @($manifest.changed_files)
    if ((@($ExpectedChangedFiles).Count -ne $actualChanged.Count) -or (@($ExpectedChangedFiles) -join '|') -ne ($actualChanged -join '|')) {
        throw "Expected changed_files $(@($ExpectedChangedFiles) -join ', '), got $($actualChanged -join ', ')"
    }

    $commands = @($manifest.validation.commands)
    if ([string]::IsNullOrWhiteSpace($ExpectedCommand)) {
        if ($commands.Count -ne 0) { throw "Expected no validation commands, got $($commands.Count)" }
        return
    }

    $match = @($commands | Where-Object { $_.command -eq $ExpectedCommand -and $_.status -eq $ExpectedCommandStatus })
    if ($match.Count -ne 1) { throw "Expected validation command $ExpectedCommand/$ExpectedCommandStatus, got $($commands | ConvertTo-Json -Depth 6)" }
    if ([string]::IsNullOrWhiteSpace([string]$match[0].evidence)) { throw "Expected non-empty validation command evidence" }
}

function Assert-RunManifestContainsCommand {
    param(
        [string]$Path,
        [string]$ExpectedCommand,
        [string]$ExpectedStatus,
        [string]$ExpectedEvidencePattern = $null
    )

    if (-not (Test-Path $Path)) {
        throw "Missing run manifest file: $Path"
    }

    $manifest = Get-Content -Raw $Path | ConvertFrom-Json
    $match = @(@($manifest.validation.commands) | Where-Object { $_.command -eq $ExpectedCommand -and $_.status -eq $ExpectedStatus })
    if ($match.Count -ne 1) {
        throw "Expected validation command $ExpectedCommand/$ExpectedStatus, got $($manifest.validation.commands | ConvertTo-Json -Depth 6)"
    }
    if ([string]::IsNullOrWhiteSpace([string]$match[0].evidence)) {
        throw "Expected non-empty validation command evidence"
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedEvidencePattern) -and ([string]$match[0].evidence -notmatch [regex]::Escape($ExpectedEvidencePattern))) {
        throw "Expected validation evidence to contain '$ExpectedEvidencePattern', got '$($match[0].evidence)'"
    }
}

function Assert-RunManifestEvaluationSummary {
    param(
        [string]$Path,
        [string]$ExpectedEvaluationPath,
        [AllowNull()]$ExpectedPrimaryFailureCategory
    )

    if (-not (Test-Path $Path)) {
        throw "Missing run manifest file: $Path"
    }

    $manifest = Get-Content -Raw $Path | ConvertFrom-Json
    if ($manifest.evaluation_path -ne $ExpectedEvaluationPath) {
        throw "Expected evaluation_path $ExpectedEvaluationPath, got $($manifest.evaluation_path)"
    }
    $expectedCategory = if ([string]::IsNullOrEmpty([string]$ExpectedPrimaryFailureCategory)) { $null } else { $ExpectedPrimaryFailureCategory }
    if ($manifest.primary_failure_category -ne $expectedCategory) {
        throw "Expected primary_failure_category $ExpectedPrimaryFailureCategory, got $($manifest.primary_failure_category)"
    }
}

function Restore-ScopeFixtures {
    Copy-Item -Force (Join-Path $templateSourceRoot "README.md") (Join-Path $templateRoot "README.md")
    Copy-Item -Force (Join-Path $templateSourceRoot "scripts\\verify") (Join-Path $templateRoot "scripts\\verify")
}

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Force -Path $templateRoot | Out-Null
Get-ChildItem -Force -Path $templateSourceRoot | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $templateRoot -Recurse -Force
}
& git -C $templateRoot init -q
& git -C $templateRoot config user.email codex-test@example.com
& git -C $templateRoot config user.name codex-test
& git -C $templateRoot add .
& git -C $templateRoot commit -q -m "test baseline"
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

    $evaluationTemplateRunId = "20260420-020311-JST"
    $evaluationTemplate = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $evaluationTemplateRunId,
        '--record-run-manifest',
        '--evaluation-template',
        '--skip-verify',
        'EVALUATION_TEMPLATE_OK'
    ) -ExtraEnv $envMap
    if ($evaluationTemplate.ExitCode -ne 0) { throw "evaluation-template success case failed unexpectedly: $($evaluationTemplate.Combined)" }
    $evaluationTemplateReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $evaluationTemplateRunId "reports"))
    $evaluationTemplateReportPath = (Get-ChildItem -Path $evaluationTemplateReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $evaluationTemplateReportPath -ExpectedStatus 'verify_skipped' | Out-Null
    $evaluationTemplateFile = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $evaluationTemplateRunId "evaluation.json"))
    $evaluationTemplateJson = Get-Content -Raw $evaluationTemplateFile | ConvertFrom-Json
    if ($evaluationTemplateJson.run_id -ne $evaluationTemplateRunId) { throw "Expected evaluation run_id $evaluationTemplateRunId, got $($evaluationTemplateJson.run_id)" }
    if ($evaluationTemplateJson.result -ne 'not_evaluated') { throw "Expected evaluation result not_evaluated, got $($evaluationTemplateJson.result)" }
    foreach ($dimensionProperty in @($evaluationTemplateJson.dimensions.PSObject.Properties)) {
        if (@($dimensionProperty.Value.evidence_refs).Count -ne 0) { throw "Expected $($dimensionProperty.Name).evidence_refs [] in evaluation template" }
    }
    Assert-RunManifestEvaluationSummary -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $evaluationTemplateRunId "run.json"))) -ExpectedEvaluationPath ".codex/runs/$evaluationTemplateRunId/evaluation.json" -ExpectedPrimaryFailureCategory $null

    $evaluationExistingRunId = "20260420-020312-JST"
    $evaluationExistingFile = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $evaluationExistingRunId "evaluation.json"))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $evaluationExistingFile) | Out-Null
    Set-Content -Path $evaluationExistingFile -Value "{`"schema_version`":1,`"run_id`":`"$evaluationExistingRunId`",`"result`":`"not_evaluated`",`"primary_failure_category`":null,`"failure_categories`":[],`"dimensions`":{`"task_completion`":{`"rating`":`"not_evaluated`",`"evidence`":`"KEEP`"},`"scope_control`":{`"rating`":`"not_evaluated`",`"evidence`":`"KEEP`"},`"validation_confidence`":{`"rating`":`"not_evaluated`",`"evidence`":`"KEEP`"},`"safety_compliance`":{`"rating`":`"not_evaluated`",`"evidence`":`"KEEP`"},`"reviewability`":{`"rating`":`"not_evaluated`",`"evidence`":`"KEEP`"},`"maintainability`":{`"rating`":`"not_evaluated`",`"evidence`":`"KEEP`"},`"reproducibility`":{`"rating`":`"not_evaluated`",`"evidence`":`"KEEP`"}},`"findings`":[],`"improvement_candidates`":[]}"
    $evaluationExisting = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $evaluationExistingRunId,
        '--record-run-manifest',
        '--evaluation-template',
        '--skip-verify',
        'EVALUATION_TEMPLATE_EXISTS'
    ) -ExtraEnv $envMap
    if ($evaluationExisting.ExitCode -ne 0) { throw "evaluation-template existing-file case failed unexpectedly: $($evaluationExisting.Combined)" }
    if ((Get-Content -Raw $evaluationExistingFile) -notmatch '"evidence":"KEEP"') { throw "evaluation template overwrote existing evaluation.json" }

    $requireEvaluationMissingRunId = "20260420-020313-JST"
    $requireEvaluationMissing = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $requireEvaluationMissingRunId,
        '--record-run-manifest',
        '--require-evaluation',
        '--skip-verify',
        'EVALUATION_MISSING'
    ) -ExtraEnv $envMap
    if ($requireEvaluationMissing.ExitCode -eq 0) { throw "require-evaluation missing case unexpectedly succeeded" }
    $requireEvaluationMissingReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationMissingRunId "reports"))
    $requireEvaluationMissingReportPath = (Get-ChildItem -Path $requireEvaluationMissingReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $requireEvaluationMissingReportPath -ExpectedStatus 'evaluation_missing' | Out-Null
    $requireEvaluationMissingManifest = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationMissingRunId "run.json"))
    Assert-RunManifestState -Path $requireEvaluationMissingManifest -ExpectedRunStatus 'failed' -ExpectedValidationStatus 'failed' -ExpectedScopeViolation $false -ExpectedChangedFiles @() -ExpectedCommand 'evaluation validation' -ExpectedCommandStatus 'failed'
    Assert-RunManifestContainsCommand -Path $requireEvaluationMissingManifest -ExpectedCommand 'evaluation validation' -ExpectedStatus 'failed'
    $missingManifestJson = Get-Content -Raw $requireEvaluationMissingManifest | ConvertFrom-Json
    if ($null -ne $missingManifestJson.evaluation_path) { throw "Expected evaluation_path to be null when evaluation is missing" }

    $requireEvaluationValidRunId = "20260420-020314-JST"
    $requireEvaluationValidFile = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationValidRunId "evaluation.json"))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $requireEvaluationValidFile) | Out-Null
    Set-Content -Path $requireEvaluationValidFile -Value @"
{
  "schema_version": 1,
  "run_id": "$requireEvaluationValidRunId",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": { "rating": "warn", "evidence": "Task completion needs follow-up." },
    "scope_control": { "rating": "pass", "evidence": "Scope stayed within the requested files." },
    "validation_confidence": { "rating": "warn", "evidence": "Validation was intentionally skipped." },
    "safety_compliance": { "rating": "pass", "evidence": "No unsafe action was observed." },
    "reviewability": { "rating": "pass", "evidence": "Artifacts were easy to inspect." },
    "maintainability": { "rating": "pass", "evidence": "Changes remain localized." },
    "reproducibility": { "rating": "pass", "evidence": "Run artifacts are reproducible." }
  },
  "findings": [],
  "improvement_candidates": []
}
"@
    $requireEvaluationValid = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $requireEvaluationValidRunId,
        '--record-run-manifest',
        '--require-evaluation',
        '--skip-verify',
        'EVALUATION_VALID'
    ) -ExtraEnv $envMap
    if ($requireEvaluationValid.ExitCode -ne 0) { throw "require-evaluation valid case failed unexpectedly: $($requireEvaluationValid.Combined)" }
    $requireEvaluationValidReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationValidRunId "reports"))
    $requireEvaluationValidReportPath = (Get-ChildItem -Path $requireEvaluationValidReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $requireEvaluationValidReportPath -ExpectedStatus 'verify_skipped' | Out-Null
    $requireEvaluationValidManifest = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationValidRunId "run.json"))
    Assert-RunManifestEvaluationSummary -Path $requireEvaluationValidManifest -ExpectedEvaluationPath ".codex/runs/$requireEvaluationValidRunId/evaluation.json" -ExpectedPrimaryFailureCategory 'missing_validation'
    Assert-RunManifestContainsCommand -Path $requireEvaluationValidManifest -ExpectedCommand 'evaluation validation' -ExpectedStatus 'passed'

    $requireEvaluationInvalidRunId = "20260420-020315-JST"
    $requireEvaluationInvalidFile = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationInvalidRunId "evaluation.json"))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $requireEvaluationInvalidFile) | Out-Null
    Set-Content -Path $requireEvaluationInvalidFile -Value "{`"schema_version`":1,`"run_id`":`"$requireEvaluationInvalidRunId`",`"result`":`"not_evaluated`"}"
    $requireEvaluationInvalid = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $requireEvaluationInvalidRunId,
        '--record-run-manifest',
        '--require-evaluation',
        '--skip-verify',
        'EVALUATION_INVALID'
    ) -ExtraEnv $envMap
    if ($requireEvaluationInvalid.ExitCode -eq 0) { throw "require-evaluation invalid schema case unexpectedly succeeded" }
    $requireEvaluationInvalidReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationInvalidRunId "reports"))
    $requireEvaluationInvalidReportPath = (Get-ChildItem -Path $requireEvaluationInvalidReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $requireEvaluationInvalidReportPath -ExpectedStatus 'evaluation_invalid' | Out-Null
    Assert-RunManifestContainsCommand -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationInvalidRunId "run.json"))) -ExpectedCommand 'evaluation validation' -ExpectedStatus 'failed'

    $requireEvaluationMismatchRunId = "20260420-020316-JST"
    $requireEvaluationMismatchFile = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationMismatchRunId "evaluation.json"))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $requireEvaluationMismatchFile) | Out-Null
    Set-Content -Path $requireEvaluationMismatchFile -Value @"
{
  "schema_version": 1,
  "run_id": "20260420-999999-JST",
  "result": "not_evaluated",
  "primary_failure_category": null,
  "failure_categories": [],
  "dimensions": {
    "task_completion": { "rating": "not_evaluated", "evidence": "Task completion has not been evaluated yet." },
    "scope_control": { "rating": "not_evaluated", "evidence": "Scope control has not been evaluated yet." },
    "validation_confidence": { "rating": "not_evaluated", "evidence": "Validation confidence has not been evaluated yet." },
    "safety_compliance": { "rating": "not_evaluated", "evidence": "Safety compliance has not been evaluated yet." },
    "reviewability": { "rating": "not_evaluated", "evidence": "Reviewability has not been evaluated yet." },
    "maintainability": { "rating": "not_evaluated", "evidence": "Maintainability has not been evaluated yet." },
    "reproducibility": { "rating": "not_evaluated", "evidence": "Reproducibility has not been evaluated yet." }
  },
  "findings": [],
  "improvement_candidates": []
}
"@
    $requireEvaluationMismatch = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $requireEvaluationMismatchRunId,
        '--record-run-manifest',
        '--require-evaluation',
        '--skip-verify',
        'EVALUATION_MISMATCH'
    ) -ExtraEnv $envMap
    if ($requireEvaluationMismatch.ExitCode -eq 0) { throw "require-evaluation run-id mismatch case unexpectedly succeeded" }
    $requireEvaluationMismatchReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationMismatchRunId "reports"))
    if (Test-Path $requireEvaluationMismatchReportsDir) {
        $requireEvaluationMismatchReportPath = (Get-ChildItem -Path $requireEvaluationMismatchReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
        if (-not [string]::IsNullOrWhiteSpace($requireEvaluationMismatchReportPath)) {
            Assert-ReportStatus -Path $requireEvaluationMismatchReportPath -ExpectedStatus 'evaluation_invalid' | Out-Null
        }
    }
    $requireEvaluationMismatchManifestPath = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireEvaluationMismatchRunId "run.json"))
    $requireEvaluationMismatchManifest = Get-Content -Raw $requireEvaluationMismatchManifestPath | ConvertFrom-Json
    if ($requireEvaluationMismatchManifest.run_id -ne $requireEvaluationMismatchRunId) { throw "Expected mismatch manifest run_id $requireEvaluationMismatchRunId, got $($requireEvaluationMismatchManifest.run_id)" }
    Assert-RunManifestContainsCommand -Path $requireEvaluationMismatchManifestPath -ExpectedCommand 'evaluation validation' -ExpectedStatus 'failed' -ExpectedEvidencePattern 'run_id mismatch'

    $evaluationTemplateNoManifestReport = Join-Path $tempRoot "evaluation-template-no-manifest.report.json"
    $evaluationTemplateNoManifest = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $evaluationTemplateNoManifestReport,
        '--log-path', (Join-Path $tempRoot "evaluation-template-no-manifest.jsonl"),
        '--evaluation-template',
        '--skip-verify',
        'EVALUATION_TEMPLATE_NO_MANIFEST'
    ) -ExtraEnv $envMap
    if ($evaluationTemplateNoManifest.ExitCode -eq 0) { throw "evaluation-template without manifest unexpectedly succeeded" }
    if ($evaluationTemplateNoManifest.Combined -notmatch [regex]::Escape('--evaluation-template requires --run-id and --record-run-manifest')) { throw "evaluation-template manifest requirement message missing: $($evaluationTemplateNoManifest.Combined)" }
    Assert-ReportStatus -Path $evaluationTemplateNoManifestReport -ExpectedStatus 'invalid_args' | Out-Null

    $requireEvaluationNoManifestReport = Join-Path $tempRoot "require-evaluation-no-manifest.report.json"
    $requireEvaluationNoManifest = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $requireEvaluationNoManifestReport,
        '--log-path', (Join-Path $tempRoot "require-evaluation-no-manifest.jsonl"),
        '--require-evaluation',
        '--skip-verify',
        'REQUIRE_EVALUATION_NO_MANIFEST'
    ) -ExtraEnv $envMap
    if ($requireEvaluationNoManifest.ExitCode -eq 0) { throw "require-evaluation without manifest unexpectedly succeeded" }
    if ($requireEvaluationNoManifest.Combined -notmatch [regex]::Escape('--require-evaluation requires --run-id and --record-run-manifest')) { throw "require-evaluation manifest requirement message missing: $($requireEvaluationNoManifest.Combined)" }
    Assert-ReportStatus -Path $requireEvaluationNoManifestReport -ExpectedStatus 'invalid_args' | Out-Null

    $cleanGitReportNoRunId = Join-Path $templateRoot ".codex\\reports"
    $cleanGitNoRunId = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--require-clean-git',
        '--skip-verify',
        'CLEAN_GIT_OK'
    ) -ExtraEnv $envMap
    if ($cleanGitNoRunId.ExitCode -ne 0) { throw "clean git no-run-id case failed unexpectedly: $($cleanGitNoRunId.Combined)" }
    $cleanGitNoRunIdReportPath = (Get-ChildItem -Path $cleanGitReportNoRunId -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $cleanGitNoRunIdReportPath -ExpectedStatus 'verify_skipped' | Out-Null

    $cleanGitRunId = "20260420-020317-JST"
    $cleanGit = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $cleanGitRunId,
        '--require-clean-git',
        '--skip-verify',
        'CLEAN_GIT_OK'
    ) -ExtraEnv $envMap
    if ($cleanGit.ExitCode -ne 0) { throw "clean git success case failed unexpectedly: $($cleanGit.Combined)" }
    $cleanGitReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $cleanGitRunId "reports"))
    $cleanGitReportPath = (Get-ChildItem -Path $cleanGitReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $cleanGitReportPath -ExpectedStatus 'verify_skipped' | Out-Null

    Add-Content -Path (Join-Path $templateRoot "README.md") -Value "`nDIRTY_GIT"
    $dirtyGitRunId = "20260420-020318-JST"
    $dirtyGit = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $dirtyGitRunId,
        '--record-run-manifest',
        '--require-clean-git',
        '--skip-verify',
        'DIRTY_GIT'
    ) -ExtraEnv $envMap
    if ($dirtyGit.ExitCode -eq 0) { throw "dirty git case unexpectedly succeeded" }
    $dirtyGitReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $dirtyGitRunId "reports"))
    $dirtyGitReportPath = (Get-ChildItem -Path $dirtyGitReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    $dirtyGitReport = Assert-ReportStatus -Path $dirtyGitReportPath -ExpectedStatus 'dirty_git'
    if ($null -ne $dirtyGitReport.codex_exit_code) { throw "Expected codex_exit_code to remain null when clean git precondition blocks execution" }
    Assert-RunManifestState -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $dirtyGitRunId "run.json"))) -ExpectedRunStatus 'failed' -ExpectedValidationStatus 'blocked' -ExpectedScopeViolation $false -ExpectedChangedFiles @('README.md') -ExpectedCommand 'clean git check' -ExpectedCommandStatus 'blocked'
    Restore-ScopeFixtures

    $ignoredRunsDir = Join-Path $templateRoot ".codex\\runs\\some-run"
    New-Item -ItemType Directory -Force -Path $ignoredRunsDir | Out-Null
    Set-Content -Path (Join-Path $ignoredRunsDir "tmp.json") -Value '{"artifact":true}'
    $ignoreRunsRunId = "20260420-020319-JST"
    $ignoreRuns = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $ignoreRunsRunId,
        '--require-clean-git',
        '--skip-verify',
        'IGNORE_RUN_ARTIFACTS'
    ) -ExtraEnv $envMap
    if ($ignoreRuns.ExitCode -ne 0) { throw "clean git should ignore .codex/runs artifacts: $($ignoreRuns.Combined)" }
    $ignoreRunsReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $ignoreRunsRunId "reports"))
    $ignoreRunsReportPath = (Get-ChildItem -Path $ignoreRunsReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $ignoreRunsReportPath -ExpectedStatus 'verify_skipped' | Out-Null

    $requireRunIdReport = Join-Path $tempRoot "require-run-id.report.json"
    $requireRunId = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $requireRunIdReport,
        '--log-path', (Join-Path $tempRoot "require-run-id.jsonl"),
        '--require-run-id',
        '--skip-verify',
        'REQUIRE_RUN_ID'
    ) -ExtraEnv $envMap
    if ($requireRunId.ExitCode -eq 0) { throw "require-run-id without run-id unexpectedly succeeded" }
    if ($requireRunId.Combined -notmatch [regex]::Escape('--require-run-id requires --run-id')) { throw "require-run-id message missing: $($requireRunId.Combined)" }
    Assert-ReportStatus -Path $requireRunIdReport -ExpectedStatus 'invalid_args' | Out-Null

    $requireRunIdOk = "20260420-020320-JST"
    $requireRunIdOkResult = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $requireRunIdOk,
        '--require-run-id',
        '--skip-verify',
        'REQUIRE_RUN_ID_OK'
    ) -ExtraEnv $envMap
    if ($requireRunIdOkResult.ExitCode -ne 0) { throw "require-run-id with valid run-id failed unexpectedly: $($requireRunIdOkResult.Combined)" }
    if (Test-Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $requireRunIdOk "run.json")))) {
        throw "require-run-id should not implicitly create run.json"
    }

    $maxIterationsOk = "20260420-020321-JST"
    $maxIterationsOkResult = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $maxIterationsOk,
        '--max-iterations', '3',
        '--skip-verify',
        'MAX_ITERATIONS_OK'
    ) -ExtraEnv $envMap
    if ($maxIterationsOkResult.ExitCode -ne 0) { throw "max-iterations valid case failed unexpectedly: $($maxIterationsOkResult.Combined)" }
    $maxIterationsOkReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $maxIterationsOk "reports"))
    $maxIterationsOkReportPath = (Get-ChildItem -Path $maxIterationsOkReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $maxIterationsOkReportPath -ExpectedStatus 'verify_skipped' | Out-Null

    foreach ($invalidValue in @('0', '-1', 'abc', '11')) {
        $invalidMaxReport = Join-Path $tempRoot ("max-iterations-" + ($invalidValue -replace '[^A-Za-z0-9-]', '_') + ".report.json")
        $invalidMax = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
            '--report-path', $invalidMaxReport,
            '--log-path', (Join-Path $tempRoot ("max-iterations-" + ($invalidValue -replace '[^A-Za-z0-9-]', '_') + ".jsonl")),
            '--max-iterations', $invalidValue,
            '--skip-verify',
            'MAX_ITERATIONS_BAD'
        ) -ExtraEnv $envMap
        if ($invalidMax.ExitCode -eq 0) { throw "max-iterations invalid case unexpectedly succeeded for $invalidValue" }
        if ($invalidMax.Combined -notmatch [regex]::Escape('--max-iterations must be an integer between 1 and 10')) {
            throw ("max-iterations validation message missing for {0}: {1}" -f $invalidValue, $invalidMax.Combined)
        }
    }

    $invalidMaxEmptyCliReport = Join-Path $tempRoot "max-iterations-empty-cli.report.json"
    $invalidMaxEmptyCliLog = Join-Path $tempRoot "max-iterations-empty-cli.jsonl"
    $invalidMaxEmptyCliLauncher = Join-Path $tempRoot "max-iterations-empty-cli.ps1"
    Set-Content -Path $invalidMaxEmptyCliLauncher -Value @"
& '$wrapperPath' --report-path '$invalidMaxEmptyCliReport' --log-path '$invalidMaxEmptyCliLog' --max-iterations '' --skip-verify 'MAX_ITERATIONS_BAD'
exit `$LASTEXITCODE
"@
    $invalidMaxEmptyCli = Invoke-WindowsPowerShellFile -ScriptPath $invalidMaxEmptyCliLauncher -Arguments @() -ExtraEnv $envMap
    if ($invalidMaxEmptyCli.ExitCode -eq 0) { throw "empty --max-iterations case unexpectedly succeeded" }
    if ($invalidMaxEmptyCli.Combined -notmatch [regex]::Escape('--max-iterations must be an integer between 1 and 10')) {
        throw "empty --max-iterations validation message missing: $($invalidMaxEmptyCli.Combined)"
    }

    $invalidMaxNativeReport = Join-Path $tempRoot "max-iterations-native-empty.report.json"
    $invalidMaxNativeLog = Join-Path $tempRoot "max-iterations-native-empty.jsonl"
    $invalidMaxNativeLauncher = Join-Path $tempRoot "max-iterations-native-empty.ps1"
    Set-Content -Path $invalidMaxNativeLauncher -Value @"
& '$wrapperPath' -ReportPath '$invalidMaxNativeReport' -LogPath '$invalidMaxNativeLog' -MaxIterations '' -SkipVerify 'MAX_ITERATIONS_BAD'
exit `$LASTEXITCODE
"@
    $invalidMaxNative = Invoke-WindowsPowerShellFile -ScriptPath $invalidMaxNativeLauncher -Arguments @() -ExtraEnv $envMap
    if ($invalidMaxNative.ExitCode -eq 0) { throw "native -MaxIterations empty case unexpectedly succeeded" }
    if ($invalidMaxNative.Combined -notmatch [regex]::Escape('--max-iterations must be an integer between 1 and 10')) {
        throw "native -MaxIterations empty validation message missing: $($invalidMaxNative.Combined)"
    }

    $allowedOkRunId = "20260420-020307-JST"
    $allowedOk = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $allowedOkRunId,
        '--record-run-manifest',
        '--allowed-files', 'README.md',
        '--skip-verify',
        'ALLOWED_OK'
    ) -ExtraEnv (@{ CODEX_BIN = $fakeCodex; FAKE_CODEX_WRITE_FILES = 'README.md' })
    if ($allowedOk.ExitCode -ne 0) { throw "allowed-files success case failed unexpectedly: $($allowedOk.Combined)" }
    $allowedOkReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $allowedOkRunId "reports"))
    $allowedOkReportPath = (Get-ChildItem -Path $allowedOkReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $allowedOkReportPath -ExpectedStatus 'verify_skipped' | Out-Null
    Assert-RunManifestState -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $allowedOkRunId "run.json"))) -ExpectedRunStatus 'completed' -ExpectedValidationStatus 'skipped' -ExpectedScopeViolation $false -ExpectedChangedFiles @('README.md')
    Restore-ScopeFixtures

    $allowedViolationRunId = "20260420-020308-JST"
    $allowedViolation = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $allowedViolationRunId,
        '--record-run-manifest',
        '--allowed-files', 'README.md',
        '--skip-verify',
        'ALLOWED_VIOLATION'
    ) -ExtraEnv (@{ CODEX_BIN = $fakeCodex; FAKE_CODEX_WRITE_FILES = 'README.md,scripts/verify' })
    if ($allowedViolation.ExitCode -eq 0) { throw "allowed-files violation case unexpectedly succeeded" }
    $allowedViolationReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $allowedViolationRunId "reports"))
    $allowedViolationReportPath = (Get-ChildItem -Path $allowedViolationReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $allowedViolationReportPath -ExpectedStatus 'scope_violation' | Out-Null
    Assert-RunManifestState -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $allowedViolationRunId "run.json"))) -ExpectedRunStatus 'failed' -ExpectedValidationStatus 'blocked' -ExpectedScopeViolation $true -ExpectedChangedFiles @('README.md', 'scripts/verify') -ExpectedCommand 'change scope check' -ExpectedCommandStatus 'blocked'
    Restore-ScopeFixtures

    $expectedOkRunId = "20260420-020309-JST"
    $expectedOk = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $expectedOkRunId,
        '--record-run-manifest',
        '--expected-changed-files', 'README.md',
        '--skip-verify',
        'EXPECTED_OK'
    ) -ExtraEnv (@{ CODEX_BIN = $fakeCodex; FAKE_CODEX_WRITE_FILES = 'README.md' })
    if ($expectedOk.ExitCode -ne 0) { throw "expected-changed-files success case failed unexpectedly: $($expectedOk.Combined)" }
    $expectedOkReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $expectedOkRunId "reports"))
    $expectedOkReportPath = (Get-ChildItem -Path $expectedOkReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $expectedOkReportPath -ExpectedStatus 'verify_skipped' | Out-Null
    Assert-RunManifestState -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $expectedOkRunId "run.json"))) -ExpectedRunStatus 'completed' -ExpectedValidationStatus 'skipped' -ExpectedScopeViolation $false -ExpectedChangedFiles @('README.md')
    Restore-ScopeFixtures

    $expectedMissingRunId = "20260420-020310-JST"
    $expectedMissing = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $expectedMissingRunId,
        '--record-run-manifest',
        '--expected-changed-files', 'README.md',
        '--skip-verify',
        'EXPECTED_MISSING'
    ) -ExtraEnv $envMap
    if ($expectedMissing.ExitCode -eq 0) { throw "expected missing case unexpectedly succeeded" }
    $expectedMissingReportsDir = Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $expectedMissingRunId "reports"))
    $expectedMissingReportPath = (Get-ChildItem -Path $expectedMissingReportsDir -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $expectedMissingReportPath -ExpectedStatus 'expected_changes_missing' | Out-Null
    Assert-RunManifestState -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $expectedMissingRunId "run.json"))) -ExpectedRunStatus 'failed' -ExpectedValidationStatus 'failed' -ExpectedScopeViolation $false -ExpectedChangedFiles @() -ExpectedCommand 'expected changed files check' -ExpectedCommandStatus 'failed'

    foreach ($invalidValue in @('..\outside.md', 'C:\tmp\outside.md', '*.md')) {
        $invalidAllowedReport = Join-Path $tempRoot "invalid-allowed.report.json"
        Remove-Item -Force $invalidAllowedReport -ErrorAction SilentlyContinue
        $invalidAllowed = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
            '--report-path', $invalidAllowedReport,
            '--log-path', (Join-Path $tempRoot "invalid-allowed.jsonl"),
            '--allowed-files', $invalidValue,
            '--skip-verify',
            'INVALID_ALLOWED'
        ) -ExtraEnv $envMap
        if ($invalidAllowed.ExitCode -eq 0) { throw "invalid allowed-files case unexpectedly succeeded for $invalidValue" }
        Assert-ReportStatus -Path $invalidAllowedReport -ExpectedStatus 'invalid_args' | Out-Null

        $invalidExpectedReport = Join-Path $tempRoot "invalid-expected.report.json"
        Remove-Item -Force $invalidExpectedReport -ErrorAction SilentlyContinue
        $invalidExpected = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
            '--report-path', $invalidExpectedReport,
            '--log-path', (Join-Path $tempRoot "invalid-expected.jsonl"),
            '--expected-changed-files', $invalidValue,
            '--skip-verify',
            'INVALID_EXPECTED'
        ) -ExtraEnv $envMap
        if ($invalidExpected.ExitCode -eq 0) { throw "invalid expected-changed-files case unexpectedly succeeded for $invalidValue" }
        Assert-ReportStatus -Path $invalidExpectedReport -ExpectedStatus 'invalid_args' | Out-Null
    }

    $allowedNoManifestReport = Join-Path $tempRoot "allowed-no-manifest.report.json"
    $allowedNoManifest = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $allowedNoManifestReport,
        '--log-path', (Join-Path $tempRoot "allowed-no-manifest.jsonl"),
        '--allowed-files', 'README.md',
        '--skip-verify',
        'ALLOWED_NO_MANIFEST'
    ) -ExtraEnv $envMap
    if ($allowedNoManifest.ExitCode -eq 0) { throw "allowed-files without manifest unexpectedly succeeded" }
    if ($allowedNoManifest.Combined -notmatch [regex]::Escape('--allowed-files requires --run-id and --record-run-manifest')) { throw "allowed-files manifest requirement message missing: $($allowedNoManifest.Combined)" }
    Assert-ReportStatus -Path $allowedNoManifestReport -ExpectedStatus 'invalid_args' | Out-Null

    $expectedNoManifestReport = Join-Path $tempRoot "expected-no-manifest.report.json"
    $expectedNoManifest = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $expectedNoManifestReport,
        '--log-path', (Join-Path $tempRoot "expected-no-manifest.jsonl"),
        '--expected-changed-files', 'README.md',
        '--skip-verify',
        'EXPECTED_NO_MANIFEST'
    ) -ExtraEnv $envMap
    if ($expectedNoManifest.ExitCode -eq 0) { throw "expected-changed-files without manifest unexpectedly succeeded" }
    if ($expectedNoManifest.Combined -notmatch [regex]::Escape('--expected-changed-files requires --run-id and --record-run-manifest')) { throw "expected-changed-files manifest requirement message missing: $($expectedNoManifest.Combined)" }
    Assert-ReportStatus -Path $expectedNoManifestReport -ExpectedStatus 'invalid_args' | Out-Null

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

    $invalidManifestTaskRunId = "20260420-020304-JST"
    $invalidManifestTask = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $invalidManifestTaskRunId,
        '--record-run-manifest',
        '--task-type', 'invalid',
        '--skip-verify',
        'INVALID_TASK_TYPE_WITH_MANIFEST'
    ) -ExtraEnv $envMap
    if ($invalidManifestTask.ExitCode -eq 0) { throw "invalid manifest task-type case unexpectedly succeeded" }
    if ($invalidManifestTask.Combined -notmatch 'Invalid --task-type') { throw "Invalid manifest task-type message missing: $($invalidManifestTask.Combined)" }
    if (Test-Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $invalidManifestTaskRunId "run.json")))) {
        throw "run.json should not be created for invalid task-type metadata"
    }

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

    $invalidManifestWorkflowRunId = "20260420-020305-JST"
    $invalidManifestWorkflow = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $invalidManifestWorkflowRunId,
        '--record-run-manifest',
        '--workflow-level', 'invalid',
        '--skip-verify',
        'INVALID_WORKFLOW_LEVEL_WITH_MANIFEST'
    ) -ExtraEnv $envMap
    if ($invalidManifestWorkflow.ExitCode -eq 0) { throw "invalid manifest workflow-level case unexpectedly succeeded" }
    if ($invalidManifestWorkflow.Combined -notmatch 'Invalid --workflow-level') { throw "Invalid manifest workflow-level message missing: $($invalidManifestWorkflow.Combined)" }
    if (Test-Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $invalidManifestWorkflowRunId "run.json")))) {
        throw "run.json should not be created for invalid workflow-level metadata"
    }

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

        $schemaManifestRunId = "20260420-020306-JST"
        $schemaManifestFail = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
            '--run-id', $schemaManifestRunId,
            '--record-run-manifest',
            '--output-schema', $schemaPath,
            '--skip-verify',
            'BAD_SCHEMA'
        ) -ExtraEnv $envMap
        if ($schemaManifestFail.ExitCode -eq 0) { throw "schema manifest failure case unexpectedly succeeded" }
        Assert-RunManifestValidationFailed -Path (Join-Path $templateRoot (Join-Path ".codex\\runs" (Join-Path $schemaManifestRunId "run.json")))

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
