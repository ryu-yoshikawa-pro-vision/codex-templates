[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$codexCmd = (Get-Command codex -ErrorAction Stop).Source
$ruleFiles = Get-ChildItem -Path (Join-Path $repoRoot ".codex\\rules") -Filter *.rules | Sort-Object Name

if (-not $ruleFiles) {
    throw "No rule files found in .codex/rules"
}

function Invoke-RuleDecision {
    param([string[]]$Tokens)

    $args = @('execpolicy', 'check')
    foreach ($file in $ruleFiles) {
        $args += @('--rules', $file.FullName)
    }
    $args += @('--')
    $args += $Tokens

    $prevNativeErr = $null
    $hasNativeErrPref = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)
    if ($hasNativeErrPref) {
        $prevNativeErr = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $raw = & $codexCmd @args 2>&1
    }
    finally {
        if ($hasNativeErrPref) {
            $PSNativeCommandUseErrorActionPreference = $prevNativeErr
        }
    }
    if ($LASTEXITCODE -ne 0) {
        throw "codex execpolicy check failed: $raw"
    }

    $json = (($raw | Out-String) | ConvertFrom-Json)
    return $json.decision
}

function Assert-Decision {
    param(
        [string[]]$Tokens,
        [string]$Expected
    )

    $actual = Invoke-RuleDecision -Tokens $Tokens
    if ($actual -ne $Expected) {
        throw "Decision mismatch for '$($Tokens -join ' ')': expected '$Expected', got '$actual'"
    }
}

function Invoke-WindowsPowerShellFile {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
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
            StdOut   = $stdout
            StdErr   = $stderr
            Combined = (($stdout + "`n" + $stderr).Trim())
        }
    }
    finally {
        Remove-Item -Force $stdoutFile, $stderrFile -ErrorAction SilentlyContinue
    }
}

function Assert-WrapperCommandBlocked {
    param([string[]]$WrapperArgs)

    $scriptPath = Join-Path $repoRoot "scripts\\codex-safe.ps1"
    $invokeArgs = @('-PrintCommand') + $WrapperArgs
    $result = Invoke-WindowsPowerShellFile -ScriptPath $scriptPath -Arguments $invokeArgs
    $output = $result.Combined
    $code = $result.ExitCode
    if ($code -eq 0) {
        throw "Wrapper unexpectedly allowed args: $($WrapperArgs -join ' ')"
    }
    if ($output -notmatch 'Unsafe Codex argument blocked') {
        throw "Wrapper failed but not with expected safety message: $output"
    }
}

function Assert-WrapperCommandAllowedPreview {
    param([string[]]$WrapperArgs)

    $scriptPath = Join-Path $repoRoot "scripts\\codex-safe.ps1"
    $result = Invoke-WindowsPowerShellFile -ScriptPath $scriptPath -Arguments $WrapperArgs
    $output = $result.Combined
    $code = $result.ExitCode
    if ($code -ne 0) {
        throw "Wrapper preview failed unexpectedly (exit=$code): $output"
    }

    return $result
}

function Assert-LogFileContainsEvent {
    param(
        [string]$Path,
        [string]$Event
    )

    if (-not (Test-Path $Path)) {
        throw "Expected log file not found: $Path"
    }

    $lines = Get-Content -Path $Path
    if (-not $lines) {
        throw "Log file is empty: $Path"
    }

    $events = @()
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $obj = $line | ConvertFrom-Json
        $events += $obj.event
    }

    if ($events -notcontains $Event) {
        throw "Expected log event '$Event' not found in $Path. Events: $($events -join ', ')"
    }
}

Assert-Decision -Tokens @('git', 'status') -Expected 'allow'
Assert-Decision -Tokens @('git', 'add', '.') -Expected 'prompt'
Assert-Decision -Tokens @('git', 'reset', '--hard', 'HEAD~1') -Expected 'forbidden'
Assert-Decision -Tokens @('docker', 'ps') -Expected 'prompt'
Assert-Decision -Tokens @('terraform', 'destroy', '-auto-approve') -Expected 'forbidden'

Assert-WrapperCommandAllowedPreview -WrapperArgs @('-PreflightOnly')
Assert-WrapperCommandAllowedPreview -WrapperArgs @('-PrintCommand', '-Preset', 'readonly', 'exec', '--help')
Assert-WrapperCommandBlocked -WrapperArgs @('--dangerously-bypass-approvals-and-sandbox')
Assert-WrapperCommandBlocked -WrapperArgs @('--config', 'sandbox_mode="danger-full-access"')
Assert-WrapperCommandBlocked -WrapperArgs @('--config=sandbox_mode="danger-full-access"')
Assert-WrapperCommandBlocked -WrapperArgs @('-c', 'sandbox_mode="danger-full-access"')
Assert-WrapperCommandBlocked -WrapperArgs @('--add-dir', 'C:\Temp')
Assert-WrapperCommandBlocked -WrapperArgs @('-C', 'C:\Windows')
Assert-WrapperCommandBlocked -WrapperArgs @('--search')
Assert-WrapperCommandBlocked -WrapperArgs @('-a', 'never')
Assert-WrapperCommandBlocked -WrapperArgs @('-s', 'danger-full-access')
Assert-WrapperCommandAllowedPreview -WrapperArgs @('-PrintCommand', '-AllowSearch', 'exec', '--help')
$specialPrompt = ('special ; | && backtick ' + [char]96 + ' test')
$wildcardEnvPrompt = 'wildcard *.md and envvar $env:USERPROFILE text'
Assert-WrapperCommandAllowedPreview -WrapperArgs @('-PrintCommand', 'exec', $specialPrompt)
Assert-WrapperCommandAllowedPreview -WrapperArgs @('-PrintCommand', 'exec', $wildcardEnvPrompt)

$logPath = Join-Path $env:TEMP ("codex-safe-wrapper-test-" + [guid]::NewGuid().ToString() + ".jsonl")
try {
    Assert-WrapperCommandAllowedPreview -WrapperArgs @('-PrintCommand', '-LogPath', $logPath, 'exec', '--help') | Out-Null
    Assert-LogFileContainsEvent -Path $logPath -Event 'wrapper_start'
    Assert-LogFileContainsEvent -Path $logPath -Event 'preflight_ok'
    Assert-LogFileContainsEvent -Path $logPath -Event 'print_command'
}
finally {
    Remove-Item -Force $logPath -ErrorAction SilentlyContinue
}

Write-Host "PASS: Codex safety harness rules and wrapper checks"
