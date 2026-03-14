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
    foreach ($key in @('runtime', 'preset', 'prompt_source', 'output_file', 'output_schema', 'log_path', 'codex_exit_code', 'verify_exit_code', 'status')) {
        if (-not ($report.PSObject.Properties.Name -contains $key)) {
            throw "Missing report key: $key"
        }
    }
    return $report
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

    $outputOk = Join-Path $tempRoot "ok.json"
    $reportOk = Join-Path $tempRoot "ok.report.json"
    $resultOk = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--output-file', $outputOk,
        '--output-schema', $schemaPath,
        '--report-path', $reportOk,
        '--verify-command', $verifyOkCmd,
        'SCHEMA_OK'
    ) -ExtraEnv $envMap
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
        '--skip-verify',
        'READONLY_OK'
    ) -ExtraEnv $envMap
    if ($readonly.ExitCode -ne 0) { throw "Readonly case failed unexpectedly: $($readonly.Combined)" }
    Assert-ReportStatus -Path $readonlyReport -ExpectedStatus 'verify_skipped' | Out-Null

    $blockedReport = Join-Path $tempRoot "blocked.report.json"
    $blocked = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $blockedReport,
        '--dangerously-bypass-approvals-and-sandbox'
    ) -ExtraEnv $envMap
    if ($blocked.ExitCode -eq 0) { throw "Blocked args case unexpectedly succeeded" }
    if ($blocked.Combined -notmatch 'Unsafe Codex argument blocked') { throw "Blocked args message missing: $($blocked.Combined)" }
    Assert-ReportStatus -Path $blockedReport -ExpectedStatus 'blocked_args' | Out-Null

    $failReport = Join-Path $tempRoot "fail.report.json"
    $fail = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $failReport,
        '--skip-verify',
        'FAIL_CODEX'
    ) -ExtraEnv $envMap
    if ($fail.ExitCode -eq 0) { throw "FAIL_CODEX case unexpectedly succeeded" }
    $failJson = Assert-ReportStatus -Path $failReport -ExpectedStatus 'codex_failed'
    if ($failJson.codex_exit_code -ne 9) { throw "Expected codex_exit_code 9, got $($failJson.codex_exit_code)" }

    $verifyFailReport = Join-Path $tempRoot "verify-fail.report.json"
    $verifyFail = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $verifyFailReport,
        '--verify-command', $verifyFailCmd,
        'VERIFY_FAIL'
    ) -ExtraEnv $envMap
    if ($verifyFail.ExitCode -eq 0) { throw "verify failure case unexpectedly succeeded" }
    $verifyFailJson = Assert-ReportStatus -Path $verifyFailReport -ExpectedStatus 'verify_failed'
    if ($verifyFailJson.verify_exit_code -ne 7) { throw "Expected verify_exit_code 7, got $($verifyFailJson.verify_exit_code)" }

    $verifyPsExprReport = Join-Path $tempRoot "verify-ps.report.json"
    $verifyPsExpr = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', $verifyPsExprReport,
        '--verify-command', 'Write-Host verify-ok; exit 0',
        'VERIFY_PS'
    ) -ExtraEnv $envMap
    if ($verifyPsExpr.ExitCode -ne 0) { throw "PowerShell verify expression failed unexpectedly: $($verifyPsExpr.Combined)" }
    Assert-ReportStatus -Path $verifyPsExprReport -ExpectedStatus 'ok' | Out-Null

    $schemaFailOut = Join-Path $tempRoot "schema-fail.json"
    $schemaFailReport = Join-Path $tempRoot "schema-fail.report.json"
    $schemaFail = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--output-file', $schemaFailOut,
        '--output-schema', $schemaPath,
        '--report-path', $schemaFailReport,
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
        '--skip-verify',
        'SCHEMA_OK'
    ) -ExtraEnv $envMap
    if ($unsupportedSchema.ExitCode -eq 0) { throw "unsupported schema case unexpectedly succeeded" }
    Assert-ReportStatus -Path $unsupportedSchemaReport -ExpectedStatus 'invalid_output' | Out-Null

    $dockerMissingReport = Join-Path $tempRoot "docker-missing.report.json"
    $dockerMissing = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--runtime', 'docker-sandbox',
        '--report-path', $dockerMissingReport,
        '--skip-verify',
        'DOCKER_MISSING'
    ) -ExtraEnv $envMap
    if ($dockerMissing.ExitCode -eq 0) { throw "docker missing case unexpectedly succeeded" }
    Assert-ReportStatus -Path $dockerMissingReport -ExpectedStatus 'docker_unavailable' | Out-Null

    if ($env:CODEX_ENABLE_DOCKER_SANDBOX_TEST -eq '1') {
        $dockerOut = Join-Path $templateRoot ".codex\\artifacts\\docker-test-output.json"
        $dockerReport = Join-Path $templateRoot ".codex\\reports\\docker-test-report.json"
        $dockerEnv = @{
            CODEX_BIN = $fakeCodex
            CODEX_DOCKER_BIN = $fakeDocker
            CODEX_DOCKER_IMAGE = 'fake-image'
        }
        $dockerOk = Invoke-WindowsPowerShellFile -ScriptPath $sandboxPath -Arguments @(
            '--output-file', $dockerOut,
            '--output-schema', $schemaPath,
            '--report-path', $dockerReport,
            '--verify-command', $verifyOkCmd,
            'DOCKER_OK'
        ) -ExtraEnv $dockerEnv
        if ($dockerOk.ExitCode -ne 0) { throw "docker sandbox smoke failed: $($dockerOk.Combined)" }
        Assert-ReportStatus -Path $dockerReport -ExpectedStatus 'ok' | Out-Null
        Remove-Item -Force $dockerOut, $dockerReport -ErrorAction SilentlyContinue
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
