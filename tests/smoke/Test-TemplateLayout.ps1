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
    "template/MIGRATION.md",
    "template/codex-project.toml",
    "template/.codex/config.toml",
    "template/.codex/requirements.toml",
    "template/.codex/hooks/pre_tool_use_policy.py",
    "template/.codex/hooks/pre_tool_use_policy.ps1",
    "template/.codex/rules-auto-net/10-auto-net-allow.rules",
    "template/.codex/rules-auto-net/20-auto-net-risky-forbidden.rules",
    "template/.codex/rules-auto-net/30-auto-net-forbidden.rules",
    "template/docs/PROJECT_CONTEXT.md",
    "template/docs/plans/TEMPLATE.md",
    "template/docs/reports/README.md",
    "template/docs/reference/codex-safety-harness.md",
    "template/docs/reference/codex-implementation-harness.md",
    "template/scripts/init-project.ps1",
    "template/scripts/init-project.sh",
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
if ($agents -notmatch [regex]::Escape("Report file")) { throw "template/AGENTS.md missing report policy" }
if ($agents -notmatch [regex]::Escape("command-based deletion")) { throw "template/AGENTS.md missing deletion policy" }
if ($plans -notmatch [regex]::Escape(".agents/skills/feature-plan/SKILL.md")) { throw "template/PLANS.md missing feature-plan skill reference" }
if ($plans -notmatch [regex]::Escape(".agents/skills/feature-plan/references/planning-workflow.md")) { throw "template/PLANS.md missing planning reference" }
if ($plans -notmatch [regex]::Escape("docs/plans/TEMPLATE.md")) { throw "template/PLANS.md missing plan template reference" }
if ($plans -notmatch [regex]::Escape("Current understanding")) { throw "template/PLANS.md missing Current understanding heading" }
if ($plans -notmatch [regex]::Escape("Non-goals")) { throw "template/PLANS.md missing Non-goals heading" }
if ($plans -notmatch [regex]::Escape("Validation plan")) { throw "template/PLANS.md missing Validation plan heading" }
if ($plans -notmatch [regex]::Escape("Open questions")) { throw "template/PLANS.md missing Open questions heading" }
if ($plans -notmatch [regex]::Escape("Ambiguity handling")) { throw "template/PLANS.md missing ambiguity handling guidance" }
if ($plans -notmatch [regex]::Escape("mandatory-question")) { throw "template/PLANS.md missing mandatory question guidance" }
if ($review -notmatch [regex]::Escape(".agents/skills/code-review/SKILL.md")) { throw "template/CODE_REVIEW.md missing code-review skill reference" }
if ($review -notmatch [regex]::Escape(".agents/skills/code-review/references/review-workflow.md")) { throw "template/CODE_REVIEW.md missing review reference" }
if ($review -notmatch [regex]::Escape("findings-first")) { throw "template/CODE_REVIEW.md missing findings-first guidance" }
if ($review -notmatch [regex]::Escape("Why it matters")) { throw "template/CODE_REVIEW.md missing Why it matters field" }
if ($review -notmatch [regex]::Escape("Suggested fix")) { throw "template/CODE_REVIEW.md missing Suggested fix field" }
if ($review -notmatch [regex]::Escape("Verdict")) { throw "template/CODE_REVIEW.md missing Verdict field" }
if ($review -notmatch [regex]::Escape("confidence")) { throw "template/CODE_REVIEW.md missing confidence field" }
if ($review -notmatch [regex]::Escape("review-only")) { throw "template/CODE_REVIEW.md missing report suppression policy" }
$planningRef = Get-Content -Raw template/.agents/skills/feature-plan/references/planning-workflow.md
$reviewRef = Get-Content -Raw template/.agents/skills/code-review/references/review-workflow.md
if ($planningRef -notmatch [regex]::Escape("repo mapping")) { throw "planning workflow missing repo mapping phase" }
if ($planningRef -notmatch [regex]::Escape("Do not use")) { throw "planning workflow missing Do not use section" }
if ($planningRef -notmatch [regex]::Escape("Main flow")) { throw "planning workflow missing Main flow section" }
if ($planningRef -notmatch [regex]::Escape("Key abstractions")) { throw "planning workflow missing Key abstractions section" }
if ($planningRef -notmatch [regex]::Escape("Safe change surface")) { throw "planning workflow missing Safe change surface" }
if ($planningRef -notmatch [regex]::Escape("Validation candidates")) { throw "planning workflow missing validation candidates" }
if ($planningRef -notmatch [regex]::Escape("Failure modes")) { throw "planning workflow missing Failure modes" }
if ($planningRef -notmatch [regex]::Escape("Ambiguity handling")) { throw "planning workflow missing ambiguity handling guidance" }
if ($planningRef -notmatch [regex]::Escape("mandatory-question")) { throw "planning workflow missing mandatory question guidance" }
if ($planningRef -notmatch [regex]::Escape("Report file generation policy")) { throw "planning workflow missing report file generation policy" }
if ($reviewRef -notmatch [regex]::Escape("diff triage")) { throw "review workflow missing diff triage phase" }
if ($reviewRef -notmatch [regex]::Escape("Diff classification")) { throw "review workflow missing Diff classification" }
if ($reviewRef -notmatch [regex]::Escape("High-risk areas")) { throw "review workflow missing High-risk areas" }
if ($reviewRef -notmatch [regex]::Escape("Potential missing tests")) { throw "review workflow missing Potential missing tests" }
if ($reviewRef -notmatch [regex]::Escape("Open questions")) { throw "review workflow missing Open questions guidance" }
if ($reviewRef -notmatch [regex]::Escape("Failure modes")) { throw "review workflow missing Failure modes" }
if ($reviewRef -notmatch [regex]::Escape("Report file generation policy")) { throw "review workflow missing report file generation policy" }

$config = Get-Content -Raw template/.codex/config.toml
if ($config -notmatch [regex]::Escape('sandbox_mode = "workspace-write"')) { throw "config missing workspace-write sandbox" }
if ($config -notmatch [regex]::Escape('approval_policy = "untrusted"')) { throw "config missing untrusted approval policy" }
if ($config -notmatch [regex]::Escape('web_search = "cached"')) { throw "config missing cached web_search" }
if ($config -notmatch [regex]::Escape('[profiles.repo_auto_net]')) { throw "config missing repo_auto_net profile" }
if ($config -notmatch [regex]::Escape('network_access = true')) { throw "config missing auto-net network access" }
if ($config -notmatch [regex]::Escape('codex_hooks = true')) { throw "config missing hook feature flag" }
if ($config -notmatch [regex]::Escape('pre_tool_use_policy.ps1')) { throw "config missing pre-tool hook command" }

Write-Host "PASS: template layout smoke test"
