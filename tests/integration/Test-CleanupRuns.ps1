[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$templateSourceRoot = Join-Path $sourceRepoRoot "template"
$tempRoot = Join-Path $env:TEMP ("cleanup-runs-test-" + [guid]::NewGuid().ToString())
$templateRoot = Join-Path $tempRoot "template"
$wrapperPath = Join-Path $templateRoot "scripts\cleanup-runs.ps1"

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

New-Item -ItemType Directory -Force -Path $tempRoot, $templateRoot | Out-Null
Get-ChildItem -Force -Path $templateSourceRoot | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $templateRoot -Recurse -Force
}

Push-Location $templateRoot
try {
    $oldRunId = "20260601-010101-JST"
    $newRunId = "20260628-010101-JST"
    New-Item -ItemType Directory -Force -Path `
        (Join-Path $templateRoot ".codex\runs\$oldRunId\reports"), `
        (Join-Path $templateRoot ".codex\runs\$newRunId\reports"), `
        (Join-Path $templateRoot ".codex\logs"), `
        (Join-Path $templateRoot ".codex\observations"), `
        (Join-Path $templateRoot "docs\plans"), `
        (Join-Path $templateRoot "docs\reports"), `
        (Join-Path $templateRoot "docs\adr") | Out-Null
    Set-Content -Path (Join-Path $templateRoot ".codex\runs\$oldRunId\REPORT.md") -Value "old"
    Set-Content -Path (Join-Path $templateRoot ".codex\runs\$newRunId\REPORT.md") -Value "new"
    Set-Content -Path (Join-Path $templateRoot ".codex\logs\codex-safe-old.jsonl") -Value "safe"
    Set-Content -Path (Join-Path $templateRoot ".codex\observations\hooks.jsonl") -Value "hook"
    Set-Content -Path (Join-Path $templateRoot "docs\plans\keep.md") -Value "keep"
    Set-Content -Path (Join-Path $templateRoot "docs\reports\keep.md") -Value "keep"
    Set-Content -Path (Join-Path $templateRoot "docs\adr\keep.md") -Value "keep"

    $oldTime = (Get-Date).AddDays(-40)
    $newTime = (Get-Date).AddDays(-1)
    (Get-Item -LiteralPath (Join-Path $templateRoot ".codex\runs\$oldRunId")).LastWriteTime = $oldTime
    (Get-Item -LiteralPath (Join-Path $templateRoot ".codex\runs\$oldRunId\REPORT.md")).LastWriteTime = $oldTime
    (Get-Item -LiteralPath (Join-Path $templateRoot ".codex\logs\codex-safe-old.jsonl")).LastWriteTime = $oldTime
    (Get-Item -LiteralPath (Join-Path $templateRoot ".codex\observations\hooks.jsonl")).LastWriteTime = $oldTime
    (Get-Item -LiteralPath (Join-Path $templateRoot ".codex\runs\$newRunId")).LastWriteTime = $newTime
    (Get-Item -LiteralPath (Join-Path $templateRoot ".codex\runs\$newRunId\REPORT.md")).LastWriteTime = $newTime

    $preview = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-OlderThanDays', '30', '-DryRun')
    if ($preview.ExitCode -ne 0) { throw "DryRun failed unexpectedly: $($preview.Combined)" }
    if ($preview.StdOut -notmatch 'MODE: preview') { throw "Missing preview mode output: $($preview.StdOut)" }
    if ($preview.StdOut -notmatch [regex]::Escape(".codex/runs/$oldRunId")) { throw "Old run missing from preview output: $($preview.StdOut)" }
    if ($preview.StdOut -notmatch [regex]::Escape('.codex/logs/codex-safe-old.jsonl')) { throw "Old log missing from preview output: $($preview.StdOut)" }
    if (-not (Test-Path -LiteralPath (Join-Path $templateRoot ".codex\runs\$oldRunId"))) { throw "DryRun removed old run unexpectedly" }
    if (-not (Test-Path -LiteralPath (Join-Path $templateRoot ".codex\logs\codex-safe-old.jsonl"))) { throw "DryRun removed old log unexpectedly" }

    $defaultPreview = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-OlderThanDays', '30')
    if ($defaultPreview.ExitCode -ne 0) { throw "Default preview failed unexpectedly: $($defaultPreview.Combined)" }
    if ($defaultPreview.StdOut -notmatch 'MODE: preview') { throw "Default mode should stay preview-only: $($defaultPreview.StdOut)" }

    $delete = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-OlderThanDays', '30', '-ConfirmDeleteGeneratedRuns')
    if ($delete.ExitCode -ne 0) { throw "Delete case failed unexpectedly: $($delete.Combined)" }
    if (Test-Path -LiteralPath (Join-Path $templateRoot ".codex\runs\$oldRunId")) { throw "Old run should be deleted" }
    if (-not (Test-Path -LiteralPath (Join-Path $templateRoot ".codex\runs\$newRunId"))) { throw "New run should remain" }
    if (Test-Path -LiteralPath (Join-Path $templateRoot ".codex\logs\codex-safe-old.jsonl")) { throw "Old top-level log should be deleted" }
    if (Test-Path -LiteralPath (Join-Path $templateRoot ".codex\observations\hooks.jsonl")) { throw "Observation log should be deleted" }
    foreach ($path in @(
        (Join-Path $templateRoot "docs\plans\keep.md"),
        (Join-Path $templateRoot "docs\reports\keep.md"),
        (Join-Path $templateRoot "docs\adr\keep.md")
    )) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Protected path should remain: $path" }
    }

    $invalid = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-OlderThanDays', '-1')
    if ($invalid.ExitCode -eq 0) { throw "Negative OlderThanDays unexpectedly succeeded" }
    if ($invalid.Combined -notmatch [regex]::Escape('-OlderThanDays must be a non-negative integer')) { throw "Missing invalid OlderThanDays message: $($invalid.Combined)" }

    $outsideDir = Join-Path $tempRoot "outside"
    New-Item -ItemType Directory -Force -Path $outsideDir | Out-Null
    $symlinkRunId = "20260602-020202-JST"
    $symlinkPath = Join-Path $templateRoot ".codex\runs\$symlinkRunId"
    try {
        New-Item -ItemType Junction -Path $symlinkPath -Target $outsideDir | Out-Null
    }
    catch {
        throw "Failed to create junction for reparse-point test: $($_.Exception.Message)"
    }

    $symlinkCase = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-OlderThanDays', '0', '-ConfirmDeleteGeneratedRuns')
    if ($symlinkCase.ExitCode -eq 0) { throw "Reparse-point delete unexpectedly succeeded" }
    if ($symlinkCase.Combined -notmatch 'Refusing to delete symlink/reparse-point candidate') { throw "Missing reparse-point refusal message: $($symlinkCase.Combined)" }
    if (-not (Test-Path -LiteralPath $symlinkPath)) { throw "Reparse-point candidate should remain" }
    if (-not (Test-Path -LiteralPath $outsideDir)) { throw "Outside target should remain" }

    Remove-Item -LiteralPath $symlinkPath -Force

    $outsideLogsDir = Join-Path $tempRoot "outside-logs"
    New-Item -ItemType Directory -Force -Path $outsideLogsDir | Out-Null
    $outsideLogPath = Join-Path $outsideLogsDir "codex-safe-ancestor.jsonl"
    Set-Content -Path $outsideLogPath -Value "outside"
    (Get-Item -LiteralPath $outsideLogPath).LastWriteTime = (Get-Date).AddDays(-2)

    $logsPath = Join-Path $templateRoot ".codex\logs"
    Remove-Item -LiteralPath $logsPath -Recurse -Force
    try {
        New-Item -ItemType Junction -Path $logsPath -Target $outsideLogsDir | Out-Null
    }
    catch {
        throw "Failed to create junction for ancestor reparse-point test: $($_.Exception.Message)"
    }

    $ancestorCase = Invoke-WindowsPowerShellFile -ScriptPath $wrapperPath -Arguments @('-OlderThanDays', '0', '-ConfirmDeleteGeneratedRuns')
    if ($ancestorCase.ExitCode -eq 0) { throw "Ancestor reparse-point delete unexpectedly succeeded" }
    if ($ancestorCase.Combined -notmatch 'Refusing to delete path with symlink/reparse-point ancestor') { throw "Missing ancestor refusal message: $($ancestorCase.Combined)" }
    if (-not (Test-Path -LiteralPath $outsideLogPath)) { throw "Outside log behind junction should remain" }
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}

Write-Host "PASS: cleanup-runs PowerShell checks"
