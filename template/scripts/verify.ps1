[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$passCount = 0
$failCount = 0
$skipCount = 0

function Add-Pass([string]$Name) {
    Write-Host "PASS: $Name"
    $script:passCount++
}

function Add-Fail([string]$Name, [string]$Message) {
    Write-Host "FAIL: $Name"
    if ($Message) {
        Write-Host $Message
    }
    $script:failCount++
}

function Add-Skip([string]$Name) {
    Write-Host "SKIP: $Name"
    $script:skipCount++
}

function Invoke-Check {
    param(
        [string]$Name,
        [scriptblock]$Script
    )

    try {
        & $Script
        Add-Pass $Name
    }
    catch {
        Add-Fail $Name $_.Exception.Message
    }
}

function Get-Decision([string]$Raw) {
    $json = $Raw | ConvertFrom-Json
    return $json.decision
}

function Test-TemplateContract {
    $required = @(
        "AGENTS.md",
        "PLANS.md",
        "CODE_REVIEW.md",
        ".codex/templates/PLAN.md",
        ".codex/rules/10-readonly-allow.rules",
        "scripts/codex-task.ps1",
        "scripts/codex-task.sh",
        "scripts/codex-sandbox.ps1",
        "scripts/codex-sandbox.sh",
        "scripts/validate-output-schema.py",
        ".agents/skills/feature-plan/references/planning-workflow.md",
        ".agents/skills/code-review/references/review-workflow.md",
        "docs/reference/codex-safety-harness.md",
        "docs/reference/codex-implementation-harness.md"
    )
    foreach ($path in $required) {
        if (-not (Test-Path $path)) {
            throw "Missing required path: $path"
        }
    }

    $agents = Get-Content -Raw AGENTS.md
    $plans = Get-Content -Raw PLANS.md
    $review = Get-Content -Raw CODE_REVIEW.md
    if ($agents -notmatch [regex]::Escape(".agents/skills/feature-plan/SKILL.md")) { throw "AGENTS.md missing feature-plan skill reference" }
    if ($agents -notmatch [regex]::Escape(".agents/skills/code-review/SKILL.md")) { throw "AGENTS.md missing code-review skill reference" }
    if ($agents -notmatch [regex]::Escape("docs/reference/codex-safety-harness.md")) { throw "AGENTS.md missing safety harness reference" }
    if ($agents -notmatch [regex]::Escape("docs/reference/codex-implementation-harness.md")) { throw "AGENTS.md missing implementation harness reference" }
    if ($plans -notmatch [regex]::Escape(".agents/skills/feature-plan/SKILL.md")) { throw "PLANS.md missing feature-plan skill reference" }
    if ($plans -notmatch [regex]::Escape(".agents/skills/feature-plan/references/planning-workflow.md")) { throw "PLANS.md missing planning reference" }
    if ($plans -notmatch [regex]::Escape("docs/plans/TEMPLATE.md")) { throw "PLANS.md missing plan template reference" }
    if ($plans -notmatch [regex]::Escape("Current understanding")) { throw "PLANS.md missing Current understanding heading" }
    if ($plans -notmatch [regex]::Escape("Non-goals")) { throw "PLANS.md missing Non-goals heading" }
    if ($plans -notmatch [regex]::Escape("Validation plan")) { throw "PLANS.md missing Validation plan heading" }
    if ($plans -notmatch [regex]::Escape("Open questions")) { throw "PLANS.md missing Open questions heading" }
    if ($review -notmatch [regex]::Escape(".agents/skills/code-review/SKILL.md")) { throw "CODE_REVIEW.md missing code-review skill reference" }
    if ($review -notmatch [regex]::Escape(".agents/skills/code-review/references/review-workflow.md")) { throw "CODE_REVIEW.md missing review reference" }
    if ($review -notmatch [regex]::Escape("findings-first")) { throw "CODE_REVIEW.md missing findings-first guidance" }
    if ($review -notmatch [regex]::Escape("Why it matters")) { throw "CODE_REVIEW.md missing Why it matters field" }
    if ($review -notmatch [regex]::Escape("Suggested fix")) { throw "CODE_REVIEW.md missing Suggested fix field" }
    if ($review -notmatch [regex]::Escape("Verdict")) { throw "CODE_REVIEW.md missing Verdict field" }
    if ($review -notmatch [regex]::Escape("confidence")) { throw "CODE_REVIEW.md missing confidence field" }
    $planningRef = Get-Content -Raw .agents/skills/feature-plan/references/planning-workflow.md
    $reviewRef = Get-Content -Raw .agents/skills/code-review/references/review-workflow.md
    if ($planningRef -notmatch [regex]::Escape("repo mapping")) { throw "planning workflow missing repo mapping phase" }
    if ($planningRef -notmatch [regex]::Escape("Do not use")) { throw "planning workflow missing Do not use section" }
    if ($planningRef -notmatch [regex]::Escape("Main flow")) { throw "planning workflow missing Main flow section" }
    if ($planningRef -notmatch [regex]::Escape("Key abstractions")) { throw "planning workflow missing Key abstractions section" }
    if ($planningRef -notmatch [regex]::Escape("Safe change surface")) { throw "planning workflow missing Safe change surface" }
    if ($planningRef -notmatch [regex]::Escape("Validation candidates")) { throw "planning workflow missing validation candidates" }
    if ($planningRef -notmatch [regex]::Escape("Failure modes")) { throw "planning workflow missing Failure modes" }
    if ($reviewRef -notmatch [regex]::Escape("diff triage")) { throw "review workflow missing diff triage phase" }
    if ($reviewRef -notmatch [regex]::Escape("Diff classification")) { throw "review workflow missing Diff classification" }
    if ($reviewRef -notmatch [regex]::Escape("High-risk areas")) { throw "review workflow missing High-risk areas" }
    if ($reviewRef -notmatch [regex]::Escape("Potential missing tests")) { throw "review workflow missing Potential missing tests" }
    if ($reviewRef -notmatch [regex]::Escape("Open questions")) { throw "review workflow missing Open questions guidance" }
    if ($reviewRef -notmatch [regex]::Escape("Failure modes")) { throw "review workflow missing Failure modes" }
}

function Test-ExecpolicyBaseline {
    $codex = (Get-Command codex -ErrorAction Stop).Source
    $ruleArgs = @(
        '--rules', '.codex/rules/10-readonly-allow.rules',
        '--rules', '.codex/rules/20-risky-prompt.rules',
        '--rules', '.codex/rules/30-destructive-forbidden.rules'
    )

    $allow = & $codex execpolicy check @ruleArgs -- git status 2>&1
    if ((Get-Decision ($allow | Out-String)) -ne 'allow') { throw "git status should be allow" }

    $prompt = & $codex execpolicy check @ruleArgs -- git add . 2>&1
    if ((Get-Decision ($prompt | Out-String)) -ne 'prompt') { throw "git add . should be prompt" }

    $forbidden = & $codex execpolicy check @ruleArgs -- git reset --hard HEAD~1 2>&1
    if ((Get-Decision ($forbidden | Out-String)) -ne 'forbidden') { throw "git reset should be forbidden" }
}

function Test-WrapperPreflight {
    & powershell.exe -ExecutionPolicy Bypass -File scripts/codex-safe.ps1 -PreflightOnly > $null
}

function Test-PowerShellHasCodex {
    $result = & powershell.exe -NoProfile -Command "if (Get-Command codex -ErrorAction SilentlyContinue) { 'yes' } else { 'no' }"
    return (($result | Out-String).Trim() -eq 'yes')
}

Invoke-Check "template contract files" { Test-TemplateContract }

if (Get-Command codex -ErrorAction SilentlyContinue) {
    Invoke-Check "execpolicy baseline decisions" { Test-ExecpolicyBaseline }
}
else {
    Add-Skip "execpolicy baseline decisions"
}

if (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
    if (Test-PowerShellHasCodex) {
        Invoke-Check "PowerShell wrapper preflight" { Test-WrapperPreflight }
    }
    else {
        Add-Skip "PowerShell wrapper preflight"
    }
}
else {
    Add-Skip "PowerShell wrapper preflight"
}

Write-Host "Summary: PASS=$passCount FAIL=$failCount SKIP=$skipCount"

if ($failCount -gt 0) {
    exit 1
}

exit 0
