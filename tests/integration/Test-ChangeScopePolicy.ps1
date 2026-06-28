[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$templateSourceRoot = Join-Path $sourceRepoRoot "template"
$tempRoot = Join-Path $env:TEMP ("codex-scope-test-" + [guid]::NewGuid().ToString())
$templateRoot = Join-Path $tempRoot "template"
$wrapperPath = Join-Path $templateRoot "scripts\\codex-task.ps1"
$fakeCodex = Join-Path $sourceRepoRoot "tests\\fixtures\\fake-codex.ps1"

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

        $proc = Start-Process -FilePath 'powershell.exe' `
            -ArgumentList (@('-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments) `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile

        $stdout = if (Test-Path $stdoutFile) { Get-Content $stdoutFile -Raw } else { '' }
        $stderr = if (Test-Path $stderrFile) { Get-Content $stderrFile -Raw } else { '' }
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
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
    param([string]$Path, [string]$ExpectedStatus)
    $report = Get-Content -Raw $Path | ConvertFrom-Json
    if ($report.status -ne $ExpectedStatus) { throw "Expected report status $ExpectedStatus, got $($report.status)" }
}

function Assert-ManifestState {
    param(
        [string]$Path,
        [string]$ExpectedRunStatus,
        [string]$ExpectedValidationStatus,
        [bool]$ExpectedScopeViolation,
        [string[]]$ExpectedChangedFiles
    )

    $manifest = Get-Content -Raw $Path | ConvertFrom-Json
    if ($manifest.status -ne $ExpectedRunStatus) { throw "Expected run status $ExpectedRunStatus, got $($manifest.status)" }
    if ($manifest.validation.status -ne $ExpectedValidationStatus) { throw "Expected validation status $ExpectedValidationStatus, got $($manifest.validation.status)" }
    if ([bool]$manifest.safety.scope_violation -ne $ExpectedScopeViolation) { throw "Expected scope_violation $ExpectedScopeViolation, got $($manifest.safety.scope_violation)" }
    $actualChanged = @($manifest.changed_files)
    if ((@($ExpectedChangedFiles).Count -ne $actualChanged.Count) -or (@($ExpectedChangedFiles) -join '|') -ne ($actualChanged -join '|')) {
        throw "Expected changed_files $(@($ExpectedChangedFiles) -join ', '), got $($actualChanged -join ', ')"
    }
}

function Restore-TemplateFile {
    param([string]$RelativePath)
    $sourcePath = Join-Path $templateSourceRoot $RelativePath
    $destPath = Join-Path $templateRoot $RelativePath
    if (Test-Path $sourcePath) {
        $parent = Split-Path -Parent $destPath
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -Force $sourcePath $destPath
    }
    else {
        Remove-Item -Force $destPath -ErrorAction SilentlyContinue
    }
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
    $baseEnv = @{ CODEX_BIN = $fakeCodex }

    $allowedDirRunId = "20260628-114100-JST"
    $allowedDir = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $allowedDirRunId,
        '--record-run-manifest',
        '--allowed-dirs', 'docs/reference',
        '--skip-verify',
        'ALLOWED_DIR_OK'
    ) -ExtraEnv (@{ CODEX_BIN = $fakeCodex; FAKE_CODEX_WRITE_FILES = 'docs/reference/codex-implementation-harness.md' })
    if ($allowedDir.ExitCode -ne 0) { throw "allowed-dirs success case failed unexpectedly: $($allowedDir.Combined)" }
    $allowedDirReport = (Get-ChildItem -Path (Join-Path $templateRoot ".codex\\runs\\$allowedDirRunId\\reports") -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $allowedDirReport -ExpectedStatus 'verify_skipped'
    Assert-ManifestState -Path (Join-Path $templateRoot ".codex\\runs\\$allowedDirRunId\\run.json") -ExpectedRunStatus 'completed' -ExpectedValidationStatus 'skipped' -ExpectedScopeViolation $false -ExpectedChangedFiles @('docs/reference/codex-implementation-harness.md')
    Restore-TemplateFile -RelativePath 'docs/reference/codex-implementation-harness.md'

    $allowedGlobRunId = "20260628-114101-JST"
    $allowedGlob = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $allowedGlobRunId,
        '--record-run-manifest',
        '--allowed-globs', 'scripts/codex-task.*',
        '--skip-verify',
        'ALLOWED_GLOB_OK'
    ) -ExtraEnv (@{ CODEX_BIN = $fakeCodex; FAKE_CODEX_WRITE_FILES = 'scripts/codex-task.ps1' })
    if ($allowedGlob.ExitCode -ne 0) { throw "allowed-globs success case failed unexpectedly: $($allowedGlob.Combined)" }
    $allowedGlobReport = (Get-ChildItem -Path (Join-Path $templateRoot ".codex\\runs\\$allowedGlobRunId\\reports") -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $allowedGlobReport -ExpectedStatus 'verify_skipped'
    Assert-ManifestState -Path (Join-Path $templateRoot ".codex\\runs\\$allowedGlobRunId\\run.json") -ExpectedRunStatus 'completed' -ExpectedValidationStatus 'skipped' -ExpectedScopeViolation $false -ExpectedChangedFiles @('scripts/codex-task.ps1')
    Restore-TemplateFile -RelativePath 'scripts/codex-task.ps1'

    $expectedWarnRunId = "20260628-114102-JST"
    $expectedWarn = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--run-id', $expectedWarnRunId,
        '--record-run-manifest',
        '--expected-changed-files', 'README.md',
        '--expected-missing', 'warn',
        '--skip-verify',
        'EXPECTED_WARN'
    ) -ExtraEnv $baseEnv
    if ($expectedWarn.ExitCode -ne 0) { throw "expected-missing warn case failed unexpectedly: $($expectedWarn.Combined)" }
    $expectedWarnReport = (Get-ChildItem -Path (Join-Path $templateRoot ".codex\\runs\\$expectedWarnRunId\\reports") -Filter "codex-task-*.report.json" | Sort-Object Name | Select-Object -Last 1).FullName
    Assert-ReportStatus -Path $expectedWarnReport -ExpectedStatus 'verify_skipped'
    $expectedWarnManifest = Get-Content -Raw (Join-Path $templateRoot ".codex\\runs\\$expectedWarnRunId\\run.json") | ConvertFrom-Json
    if ($expectedWarnManifest.validation.status -ne 'passed_with_warnings') { throw "Expected passed_with_warnings, got $($expectedWarnManifest.validation.status)" }
    if (@($expectedWarnManifest.validation.warnings).Count -lt 1) { throw "Expected at least one warning record" }

    $invalidExpected = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @(
        '--report-path', (Join-Path $tempRoot 'invalid-expected-missing.report.json'),
        '--log-path', (Join-Path $tempRoot 'invalid-expected-missing.jsonl'),
        '--expected-missing', 'maybe',
        '--skip-verify',
        'INVALID_EXPECTED_MISSING'
    ) -ExtraEnv $baseEnv
    if ($invalidExpected.ExitCode -eq 0) { throw "Invalid expected-missing case unexpectedly succeeded" }
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}

Write-Host "PASS: change scope policy PowerShell checks"
