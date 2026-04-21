#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"

required=(
  template/AGENTS.md
  template/PLANS.md
  template/CODE_REVIEW.md
  template/codex-project.toml
  template/.codex/config.toml
  template/.codex/requirements.toml
  template/docs/PROJECT_CONTEXT.md
  template/docs/plans/TEMPLATE.md
  template/docs/reports/README.md
  template/docs/reference/codex-safety-harness.md
  template/docs/reference/codex-implementation-harness.md
  template/scripts/init-project.ps1
  template/scripts/init-project.sh
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

contains() {
  local pattern="$1"
  local path="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q "$pattern" "$path"
  else
    grep -Fq "$pattern" "$path"
  fi
}

[[ ! -e template/docs/agent ]] || {
  echo "template/docs/agent should not exist in the consumer-facing template" >&2
  exit 1
}

contains ".agents/skills/feature-plan/SKILL.md" template/AGENTS.md
contains ".agents/skills/code-review/SKILL.md" template/AGENTS.md
contains "docs/reference/codex-safety-harness.md" template/AGENTS.md
contains "docs/reference/codex-implementation-harness.md" template/AGENTS.md
contains "Report file" template/AGENTS.md
contains "command-based deletion" template/AGENTS.md
contains ".agents/skills/feature-plan/SKILL.md" template/PLANS.md
contains ".agents/skills/feature-plan/references/planning-workflow.md" template/PLANS.md
contains "docs/plans/TEMPLATE.md" template/PLANS.md
contains "Current understanding" template/PLANS.md
contains "Non-goals" template/PLANS.md
contains "Validation plan" template/PLANS.md
contains "Open questions" template/PLANS.md
contains "Ambiguity handling" template/PLANS.md
contains "mandatory-question" template/PLANS.md
contains ".agents/skills/code-review/SKILL.md" template/CODE_REVIEW.md
contains ".agents/skills/code-review/references/review-workflow.md" template/CODE_REVIEW.md
contains "findings-first" template/CODE_REVIEW.md
contains "Why it matters" template/CODE_REVIEW.md
contains "Suggested fix" template/CODE_REVIEW.md
contains "Verdict" template/CODE_REVIEW.md
contains "confidence" template/CODE_REVIEW.md
contains "review-only" template/CODE_REVIEW.md
contains "repo mapping" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "Do not use" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "Main flow" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "Key abstractions" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "Safe change surface" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "Validation candidates" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "Failure modes" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "Ambiguity handling" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "mandatory-question" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "Report file generation policy" template/.agents/skills/feature-plan/references/planning-workflow.md
contains "diff triage" template/.agents/skills/code-review/references/review-workflow.md
contains "Diff classification" template/.agents/skills/code-review/references/review-workflow.md
contains "High-risk areas" template/.agents/skills/code-review/references/review-workflow.md
contains "Potential missing tests" template/.agents/skills/code-review/references/review-workflow.md
contains "Open questions" template/.agents/skills/code-review/references/review-workflow.md
contains "Failure modes" template/.agents/skills/code-review/references/review-workflow.md
contains "Report file generation policy" template/.agents/skills/code-review/references/review-workflow.md
contains "sandbox_mode = \"workspace-write\"" template/.codex/config.toml
contains "approval_policy = \"untrusted\"" template/.codex/config.toml
contains "web_search = \"cached\"" template/.codex/config.toml

echo "PASS: template layout smoke test"
