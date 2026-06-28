[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$RunId,

    [ValidateSet("plan", "review", "implementation", "investigation", "repair", "harness-improvement")]
    [string]$TaskType = "implementation",

    [ValidateSet("lightweight", "standard", "strict")]
    [string]$WorkflowLevel = "standard",

    [ValidateSet("safe", "readonly", "auto-net")]
    [string]$Preset = "safe",

    [switch]$NoPlan,

    [switch]$NoRunManifest,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-JstRunId {
    try {
        $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Tokyo Standard Time")
    }
    catch {
        $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Asia/Tokyo")
    }

    $jstNow = [System.TimeZoneInfo]::ConvertTime((Get-Date), $tz)
    return $jstNow.ToString("yyyyMMdd-HHmmss") + "-JST"
}

if ([string]::IsNullOrWhiteSpace($RunId)) {
    $RunId = Get-JstRunId
}

if ($RunId -notmatch '^\d{8}-\d{6}-JST$') {
    throw "Invalid -RunId: expected YYYYMMDD-HHMMSS-JST"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runsRoot = Join-Path $repoRoot ".codex\runs"
if ($Force) {
    New-Item -ItemType Directory -Path $runsRoot -Force | Out-Null
}
elseif (-not (Test-Path -LiteralPath $runsRoot)) {
    New-Item -ItemType Directory -Path $runsRoot | Out-Null
}

$runRoot = Join-Path $runsRoot $RunId
if (Test-Path -LiteralPath $runRoot) {
    throw "Run directory already exists and will not be overwritten: .codex/runs/$RunId"
}

New-Item -ItemType Directory -Path $runRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot ".codex\templates\TASKS.md") -Destination (Join-Path $runRoot "TASKS.md")
Copy-Item -LiteralPath (Join-Path $repoRoot ".codex\templates\REPORT.md") -Destination (Join-Path $runRoot "REPORT.md")
if (-not $NoPlan) {
    Copy-Item -LiteralPath (Join-Path $repoRoot ".codex\templates\PLAN.md") -Destination (Join-Path $runRoot "PLAN.md")
}

if (-not $NoRunManifest) {
    $manifestTemplate = Get-Content -Raw -LiteralPath (Join-Path $repoRoot ".codex\templates\RUN_MANIFEST.json") | ConvertFrom-Json
    $manifestTemplate.run_id = $RunId
    $manifestTemplate.task_type = $TaskType
    $manifestTemplate.workflow_level = $WorkflowLevel
    $manifestTemplate.preset = $Preset
    ($manifestTemplate | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath (Join-Path $runRoot "run.json")
}

Write-Host "Initialized run: .codex/runs/$RunId"
