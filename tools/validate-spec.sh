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

for rel in routing["skills"]:
    assert_exists(rel)

for rel in safety["wrappers"]:
    assert_exists(rel)
    assert_contains(rel, safety["blocked_tokens"])

for rel in safety.get("delegating_wrappers", []):
    assert_exists(rel)

assert_exists(safety["rules_dir"])
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
