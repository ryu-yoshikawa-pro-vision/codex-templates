#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

python_cmd=""
if command -v python3 >/dev/null 2>&1; then
  python_cmd="python3"
elif command -v python >/dev/null 2>&1; then
  python_cmd="python"
else
  echo "python3 or python is required" >&2
  exit 1
fi

"$python_cmd" - "$repo_root" <<'PY'
import json
import pathlib
import sys

repo_root = pathlib.Path(sys.argv[1])


def read_spec(rel):
    return json.loads((repo_root / rel).read_text(encoding="utf-8"))


def assert_exists(rel):
    path = repo_root / rel
    if not path.exists():
        raise SystemExit(f"Required path missing: {rel}")


def assert_contains(rel, patterns):
    content = (repo_root / rel).read_text(encoding="utf-8")
    for pattern in patterns:
        if pattern not in content:
            raise SystemExit(f"Pattern '{pattern}' not found in {rel}")


workflow = read_spec("spec/workflow.yaml")
routing = read_spec("spec/routing.yaml")
safety = read_spec("spec/safety-policy.yaml")
naming = read_spec("spec/naming.yaml")

for rel in workflow["required_files"]:
    assert_exists(rel)

assert_contains(routing["instructions"]["file"], routing["instructions"]["must_contain"])
assert_contains(routing["planning"]["file"], routing["planning"]["must_contain"])
assert_contains(routing["review"]["file"], routing["review"]["must_contain"])
assert_contains(workflow["planning_reference"]["file"], workflow["planning_reference"]["must_contain"])
assert_contains(workflow["review_reference"]["file"], workflow["review_reference"]["must_contain"])

for rel in routing["skills"]:
    assert_exists(rel)

for rel in safety["wrappers"]:
    assert_exists(rel)
    assert_contains(rel, safety["blocked_tokens"])

assert_contains(safety["config"]["file"], safety["config"]["must_contain"])
subagents = safety.get("subagents")
if not isinstance(subagents, list) or not subagents:
    raise SystemExit("safety.subagents must contain at least one entry")

for idx, agent in enumerate(subagents, start=1):
    if not isinstance(agent, dict):
        raise SystemExit(f"safety.subagents[{idx}] must be an object")

    rel = agent.get("file")
    patterns = agent.get("must_contain")

    if not isinstance(rel, str) or not rel:
        raise SystemExit(f"safety.subagents[{idx}].file must be a non-empty string")

    if not isinstance(patterns, list) or not all(isinstance(p, str) for p in patterns):
        raise SystemExit(f"safety.subagents[{idx}].must_contain must be a string array")

    assert_exists(rel)
    assert_contains(rel, patterns)

worker_mode = safety.get("execution_modes", {}).get("implementation_worker")
if not isinstance(worker_mode, dict):
    raise SystemExit("safety.execution_modes.implementation_worker must be set")

expected_worker_mode = {
    "sandbox_mode": "workspace-write",
    "scope": "parent_approved_small_scoped_changes",
    "delete_operations_allowed": False,
    "rename_operations_allowed": False,
    "git_mutation_allowed": False,
    "parallel_writable_agents_default": False,
}

for key, expected in expected_worker_mode.items():
    if worker_mode.get(key) != expected:
        raise SystemExit(
            f"safety.execution_modes.implementation_worker.{key} is out of contract"
        )

assert_contains(safety["requirements"]["file"], safety["requirements"]["must_contain"])
assert_contains(
    f'{safety["rules_dir"]}/30-destructive-forbidden.rules',
    safety["forbidden_delete_commands"],
)

for rel in safety.get("delegating_wrappers", []):
    assert_exists(rel)

assert_exists(safety["rules_dir"])
if "auto_net_rules_dir" in safety:
    assert_exists(safety["auto_net_rules_dir"])
assert_exists(safety["verify"])
assert_contains(
    "template/docs/reference/naming-conventions.md",
    [
        naming["plan_docs"]["pattern"],
        naming["report_docs"]["pattern"],
        naming["history_docs"]["pattern"],
    ],
)

print("PASS: spec validation")
PY
