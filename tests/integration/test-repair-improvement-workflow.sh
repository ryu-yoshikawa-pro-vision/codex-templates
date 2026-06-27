#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
template_root="$source_repo_root/template"
python_cmd="python3"
if ! command -v python3 >/dev/null 2>&1; then
  python_cmd="python"
fi

required_paths=(
  "$template_root/.agents/skills/repair-loop/SKILL.md"
  "$template_root/.agents/skills/repair-loop/references/repair-workflow.md"
  "$template_root/.agents/skills/harness-improvement/SKILL.md"
  "$template_root/.agents/skills/harness-improvement/references/improvement-workflow.md"
  "$template_root/docs/reference/repair-loop.md"
  "$template_root/docs/reference/harness-improvement-loop.md"
  "$template_root/examples/repair-loop/README.md"
  "$template_root/examples/repair-loop/iteration-1-evaluation.json"
  "$template_root/examples/repair-loop/iteration-2-evaluation.json"
  "$template_root/examples/repair-loop/repair-summary.md"
  "$template_root/examples/harness-improvement/README.md"
  "$template_root/examples/harness-improvement/harness-improvement-candidates.json"
  "$template_root/examples/harness-improvement/harness-improvement-review.md"
)

for path in "${required_paths[@]}"; do
  [[ -f "$path" ]]
done

"$python_cmd" "$template_root/scripts/validate-output-schema.py" \
  "$source_repo_root/spec/evaluation.schema.json" \
  "$template_root/examples/repair-loop/iteration-1-evaluation.json"

"$python_cmd" "$template_root/scripts/validate-output-schema.py" \
  "$source_repo_root/spec/evaluation.schema.json" \
  "$template_root/examples/repair-loop/iteration-2-evaluation.json"

"$python_cmd" - "$source_repo_root/spec/failure-taxonomy.json" "$template_root/examples/harness-improvement/harness-improvement-candidates.json" <<'PY'
import json
import sys

taxonomy = json.load(open(sys.argv[1], encoding="utf-8"))
doc = json.load(open(sys.argv[2], encoding="utf-8"))
categories = {entry["category"] for entry in taxonomy["categories"]}
candidates = doc["candidates"]
if len(candidates) < 3:
    raise SystemExit("Expected at least three harness improvement candidates")
strictness_values = {candidate["strictness"] for candidate in candidates}
if strictness_values != {"normal", "strict", "blocked"}:
    raise SystemExit(f"Unexpected strictness values: {sorted(strictness_values)}")
for index, candidate in enumerate(candidates, start=1):
    if candidate["failure_category"] not in categories:
        raise SystemExit(f"candidate[{index}] has invalid failure_category")
    if not candidate["evidence"]:
        raise SystemExit(f"candidate[{index}] must include evidence")
PY

bash "$template_root/scripts/verify"

echo "PASS: repair improvement workflow checks"
