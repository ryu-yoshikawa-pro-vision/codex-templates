#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"

required=(
  template/AGENTS.md
  template/PLANS.md
  template/CODE_REVIEW.md
  template/docs/PROJECT_CONTEXT.md
  template/docs/plans/TEMPLATE.md
  template/docs/reports/README.md
  template/docs/reference/codex-safety-harness.md
  template/docs/reference/codex-implementation-harness.md
  template/scripts/codex-task.ps1
  template/scripts/codex-task.sh
  template/scripts/codex-sandbox.ps1
  template/scripts/codex-sandbox.sh
  template/scripts/validate-output-schema.py
  template/.agents/skills/feature-plan/SKILL.md
  template/.agents/skills/feature-plan/references/planning-workflow.md
  template/.agents/skills/code-review/SKILL.md
  template/.agents/skills/code-review/references/review-workflow.md
)

for path in "${required[@]}"; do
  [[ -f "$path" ]] || {
    echo "Missing required file: $path" >&2
    exit 1
  }
done

[[ ! -e template/docs/agent ]] || {
  echo "template/docs/agent should not exist in the consumer-facing template" >&2
  exit 1
}

rg -q ".agents/skills/feature-plan/SKILL.md" template/AGENTS.md
rg -q ".agents/skills/code-review/SKILL.md" template/AGENTS.md
rg -q "docs/reference/codex-safety-harness.md" template/AGENTS.md
rg -q "docs/reference/codex-implementation-harness.md" template/AGENTS.md
rg -q ".agents/skills/feature-plan/SKILL.md" template/PLANS.md
rg -q ".agents/skills/feature-plan/references/planning-workflow.md" template/PLANS.md
rg -q "docs/plans/TEMPLATE.md" template/PLANS.md
rg -q "Current understanding" template/PLANS.md
rg -q "Non-goals" template/PLANS.md
rg -q "Validation plan" template/PLANS.md
rg -q "Open questions" template/PLANS.md
rg -q ".agents/skills/code-review/SKILL.md" template/CODE_REVIEW.md
rg -q ".agents/skills/code-review/references/review-workflow.md" template/CODE_REVIEW.md
rg -q "findings-first" template/CODE_REVIEW.md
rg -q "Why it matters" template/CODE_REVIEW.md
rg -q "Suggested fix" template/CODE_REVIEW.md
rg -q "Verdict" template/CODE_REVIEW.md
rg -q "confidence" template/CODE_REVIEW.md
rg -q "repo mapping" template/.agents/skills/feature-plan/references/planning-workflow.md
rg -q "Do not use" template/.agents/skills/feature-plan/references/planning-workflow.md
rg -q "Main flow" template/.agents/skills/feature-plan/references/planning-workflow.md
rg -q "Key abstractions" template/.agents/skills/feature-plan/references/planning-workflow.md
rg -q "Safe change surface" template/.agents/skills/feature-plan/references/planning-workflow.md
rg -q "Validation candidates" template/.agents/skills/feature-plan/references/planning-workflow.md
rg -q "Failure modes" template/.agents/skills/feature-plan/references/planning-workflow.md
rg -q "diff triage" template/.agents/skills/code-review/references/review-workflow.md
rg -q "Diff classification" template/.agents/skills/code-review/references/review-workflow.md
rg -q "High-risk areas" template/.agents/skills/code-review/references/review-workflow.md
rg -q "Potential missing tests" template/.agents/skills/code-review/references/review-workflow.md
rg -q "Open questions" template/.agents/skills/code-review/references/review-workflow.md
rg -q "Failure modes" template/.agents/skills/code-review/references/review-workflow.md

echo "PASS: template layout smoke test"
