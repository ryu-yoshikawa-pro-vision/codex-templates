[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
Set-Location $repoRoot

$required = @(
    "template/AGENTS.md",
    "template/PLANS.md",
    "template/CODE_REVIEW.md",
    "template/docs/PROJECT_CONTEXT.md",
    "template/docs/plans/TEMPLATE.md",
    "template/docs/reports/README.md",
    "template/docs/reference/codex-safety-harness.md",
    "template/docs/reference/codex-implementation-harness.md",
    "template/scripts/codex-task.ps1",
    "template/scripts/codex-task.sh",
    "template/scripts/codex-sandbox.ps1",
    "template/scripts/codex-sandbox.sh",
    "template/scripts/validate-output-schema.py",
    "template/.agents/skills/feature-plan/SKILL.md",
    "template/.agents/skills/feature-plan/references/planning-workflow.md",
    "template/.agents/skills/code-review/SKILL.md",
    "template/.agents/skills/code-review/references/review-workflow.md"
)

foreach ($path in $required) {
    if (-not (Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

if (Test-Path "template/docs/agent") {
    throw "template/docs/agent should not exist in the consumer-facing template"
}

$agents = Get-Content -Raw template/AGENTS.md
$plans = Get-Content -Raw template/PLANS.md
$review = Get-Content -Raw template/CODE_REVIEW.md

if ($agents -notmatch [regex]::Escape(".agents/skills/feature-plan/SKILL.md")) { throw "template/AGENTS.md missing feature-plan skill reference" }
if ($agents -notmatch [regex]::Escape(".agents/skills/code-review/SKILL.md")) { throw "template/AGENTS.md missing code-review skill reference" }
if ($agents -notmatch [regex]::Escape("docs/reference/codex-safety-harness.md")) { throw "template/AGENTS.md missing safety harness reference" }
if ($agents -notmatch [regex]::Escape("docs/reference/codex-implementation-harness.md")) { throw "template/AGENTS.md missing implementation harness reference" }
if ($plans -notmatch [regex]::Escape(".agents/skills/feature-plan/SKILL.md")) { throw "template/PLANS.md missing feature-plan skill reference" }
if ($plans -notmatch [regex]::Escape("docs/plans/TEMPLATE.md")) { throw "template/PLANS.md missing plan template reference" }
if ($review -notmatch [regex]::Escape(".agents/skills/code-review/SKILL.md")) { throw "template/CODE_REVIEW.md missing code-review skill reference" }
if ($review -notmatch [regex]::Escape("findings-first")) { throw "template/CODE_REVIEW.md missing findings-first guidance" }

Write-Host "PASS: template layout smoke test"
