[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$planWrapper = Join-Path $sourceRepoRoot "tools\plan-consumer-update.ps1"
$syncWrapper = Join-Path $sourceRepoRoot "tools\sync-template.ps1"
$tempRoot = Join-Path $env:TEMP ("plan-consumer-update-test-" + [guid]::NewGuid().ToString())
$consumerRoot = Join-Path $tempRoot "consumer"

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

New-Item -ItemType Directory -Force -Path `
    (Join-Path $consumerRoot "docs\adr"), `
    (Join-Path $consumerRoot "docs\plans"), `
    (Join-Path $consumerRoot ".codex\runs\20260601-010101-JST"), `
    (Join-Path $consumerRoot ".git") | Out-Null
Set-Content -Path (Join-Path $consumerRoot "codex-project.toml") -Value @'
schema_version = 1
name = "consumer"
template_version = "0.10.0"
'@
Set-Content -Path (Join-Path $consumerRoot "AGENTS.md") -Value "OLD AGENTS"
Set-Content -Path (Join-Path $consumerRoot "docs\PROJECT_CONTEXT.md") -Value "KEEP PROJECT CONTEXT"
Set-Content -Path (Join-Path $consumerRoot "docs\adr\decision.md") -Value "KEEP ADR"
Set-Content -Path (Join-Path $consumerRoot ".codex\runs\20260601-010101-JST\REPORT.md") -Value "KEEP RUN"
Set-Content -Path (Join-Path $consumerRoot ".env.local") -Value "KEEP ENV"
Set-Content -Path (Join-Path $consumerRoot "custom.md") -Value "KEEP EXTRA"
Set-Content -Path (Join-Path $consumerRoot ".git\HEAD") -Value "ref: refs/heads/main"

try {
    $human = Invoke-WindowsPowerShellFile -ScriptPath $planWrapper -Arguments @('-Destination', $consumerRoot)
    if ($human.ExitCode -ne 0) { throw "Human-readable plan failed unexpectedly: $($human.Combined)" }
    foreach ($pattern in @(
        'Source template version:',
        'Consumer template version: 0.10.0',
        'Version change: minor',
        'docs/PROJECT_CONTEXT.md',
        'custom.md',
        'powershell -ExecutionPolicy Bypass -File tools/sync-template.ps1',
        'verify.ps1'
    )) {
        if ($human.StdOut -notmatch [regex]::Escape($pattern)) {
            throw "Missing expected pattern '$pattern' in human output: $($human.StdOut)"
        }
    }

    $json = Invoke-WindowsPowerShellFile -ScriptPath $planWrapper -Arguments @('-Destination', $consumerRoot, '-Json')
    if ($json.ExitCode -ne 0) { throw "JSON plan failed unexpectedly: $($json.Combined)" }
    $plan = $json.StdOut | ConvertFrom-Json
    if ($plan.source_template_version -ne '0.11.0') { throw "Unexpected source template version: $($plan.source_template_version)" }
    if ($plan.consumer_template_version -ne '0.10.0') { throw "Unexpected consumer template version: $($plan.consumer_template_version)" }
    if ($plan.version_change -ne 'minor') { throw "Expected minor version change, got $($plan.version_change)" }
    if ([System.IO.Path]::GetFullPath($plan.destination) -ne [System.IO.Path]::GetFullPath($consumerRoot)) { throw "Unexpected destination path: $($plan.destination)" }
    foreach ($required in @('docs/PROJECT_CONTEXT.md', 'docs/adr/', '.codex/runs/', '.git/', '.env.local')) {
        if ($required -notin @($plan.protected_paths)) { throw "Missing protected path ${required}: $($plan.protected_paths -join ', ')" }
    }
    if ('AGENTS.md' -notin @($plan.candidate_updates)) { throw "Expected AGENTS.md in candidate updates: $($plan.candidate_updates -join ', ')" }
    if ('custom.md' -notin @($plan.manual_review_required)) { throw "Expected custom.md in manual review required: $($plan.manual_review_required -join ', ')" }
    if (@($plan.recommended_commands).Count -lt 1) { throw "Expected recommended commands" }

    $versionOk = Invoke-WindowsPowerShellFile -ScriptPath $planWrapper -Arguments @('-Destination', $consumerRoot, '-TemplateVersion', '0.11.0')
    if ($versionOk.ExitCode -ne 0) { throw "Matching TemplateVersion should succeed: $($versionOk.Combined)" }

    $versionBad = Invoke-WindowsPowerShellFile -ScriptPath $planWrapper -Arguments @('-Destination', $consumerRoot, '-TemplateVersion', '9.9.9')
    if ($versionBad.ExitCode -eq 0) { throw "Mismatched TemplateVersion unexpectedly succeeded" }
    if ($versionBad.Combined -notmatch 'does not match source template version') { throw "Missing TemplateVersion mismatch message: $($versionBad.Combined)" }

    $syncPreview = Invoke-WindowsPowerShellFile -ScriptPath $syncWrapper -Arguments @('-Destination', $consumerRoot, '-Force', '-PlanOnly', '-ExcludeProtected')
    if ($syncPreview.ExitCode -ne 0) { throw "PlanOnly sync preview failed unexpectedly: $($syncPreview.Combined)" }
    if ($syncPreview.StdOut -notmatch 'Protected paths:') { throw "Expected protected paths in sync preview: $($syncPreview.StdOut)" }

    $sync = Invoke-WindowsPowerShellFile -ScriptPath $syncWrapper -Arguments @('-Destination', $consumerRoot, '-Force', '-ExcludeProtected')
    if ($sync.ExitCode -ne 0) { throw "ExcludeProtected sync failed unexpectedly: $($sync.Combined)" }

    $sourceAgents = Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $sourceRepoRoot "template\AGENTS.md")
    $destAgents = Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $consumerRoot "AGENTS.md")
    if ($sourceAgents.Hash -ne $destAgents.Hash) { throw "AGENTS.md was not updated from source template" }
    if ((Get-Content -LiteralPath (Join-Path $consumerRoot "docs\PROJECT_CONTEXT.md") -Raw) -notmatch 'KEEP PROJECT CONTEXT') { throw "Protected PROJECT_CONTEXT should remain unchanged" }
    if ((Get-Content -LiteralPath (Join-Path $consumerRoot "custom.md") -Raw) -notmatch 'KEEP EXTRA') { throw "Destination-only custom.md should remain" }
    foreach ($path in @(
        (Join-Path $consumerRoot ".env.local"),
        (Join-Path $consumerRoot ".codex\runs\20260601-010101-JST\REPORT.md")
    )) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Protected path should remain: $path" }
    }
}
finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}

Write-Host "PASS: plan-consumer-update PowerShell checks"
