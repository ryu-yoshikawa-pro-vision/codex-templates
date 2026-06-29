#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
template_source_root="$source_repo_root/template"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-new-run-test.XXXXXX")"
template_root="$temp_root/template"
wrapper="$template_root/scripts/new-run.sh"
python_cmd="python3"
if ! command -v python3 >/dev/null 2>&1; then
  python_cmd="python"
fi

cleanup() {
  case "$temp_root" in
    "${TMPDIR:-/tmp}"/codex-new-run-test.*)
      rm -rf -- "$temp_root"
      ;;
    *)
      echo "Refusing to clean unexpected temp root: $temp_root" >&2
      ;;
  esac
}
trap cleanup EXIT

mkdir -p "$template_root"
cp -R "$template_source_root/." "$template_root"
cd "$template_root"

grep -Fq 'if ! mkdir "$run_root"; then' "$wrapper"
if grep -Fq '[[ -e "$run_root" ]]' "$wrapper"; then
  echo "new-run.sh still contains precheck for existing run_root" >&2
  exit 1
fi

assert_manifest_fields() {
  local path="$1"
  local expected_run_id="$2"
  local expected_task_type="$3"
  local expected_workflow_level="$4"
  local expected_preset="$5"
  "$python_cmd" - "$path" "$expected_run_id" "$expected_task_type" "$expected_workflow_level" "$expected_preset" <<'PY'
import json
import sys
path, expected_run_id, expected_task_type, expected_workflow_level, expected_preset = sys.argv[1:6]
data = json.load(open(path, encoding="utf-8"))
if data["run_id"] != expected_run_id:
    raise SystemExit(f"expected run_id {expected_run_id}, got {data['run_id']}")
if data["task_type"] != expected_task_type:
    raise SystemExit(f"expected task_type {expected_task_type}, got {data['task_type']}")
if data["workflow_level"] != expected_workflow_level:
    raise SystemExit(f"expected workflow_level {expected_workflow_level}, got {data['workflow_level']}")
if data["preset"] != expected_preset:
    raise SystemExit(f"expected preset {expected_preset}, got {data['preset']}")
if data["artifact_summary"] != {
    "codex_task_report_count": 0,
    "hook_event_count": 0,
    "subagent_run_count": 0,
    "evaluation_present": False,
}:
    raise SystemExit(f"unexpected artifact_summary defaults: {data['artifact_summary']}")
if data["hook_observations"] != {
    "log_paths": [],
    "event_counts": {},
    "blocking_event_count": 0,
    "safety_blocked_count": 0,
    "observation_error_count": 0,
}:
    raise SystemExit(f"unexpected hook_observations defaults: {data['hook_observations']}")
if data["subagents"]["summary"] != {
    "total": 0,
    "read_only": 0,
    "writable": 0,
    "scope_violations": 0,
    "used_in_final_plan": 0,
}:
    raise SystemExit(f"unexpected subagents defaults: {data['subagents']}")
if data["subagents"]["records"] != []:
    raise SystemExit(f"unexpected subagent records defaults: {data['subagents']['records']}")
PY
}

run_id="20260628-111100-JST"
bash "$wrapper" --run-id "$run_id" --task-type harness-improvement --workflow-level strict --preset auto-net
[[ -f ".codex/runs/$run_id/PLAN.md" ]]
[[ -f ".codex/runs/$run_id/TASKS.md" ]]
[[ -f ".codex/runs/$run_id/REPORT.md" ]]
[[ -f ".codex/runs/$run_id/run.json" ]]
assert_manifest_fields ".codex/runs/$run_id/run.json" "$run_id" "harness-improvement" "strict" "auto-net"

set +e
bash "$wrapper" --run-id "$run_id" --force >"$temp_root/duplicate.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Run directory already exists" "$temp_root/duplicate.out"

no_plan_run_id="20260628-111101-JST"
bash "$wrapper" --run-id "$no_plan_run_id" --no-plan --no-run-manifest
[[ ! -f ".codex/runs/$no_plan_run_id/PLAN.md" ]]
[[ -f ".codex/runs/$no_plan_run_id/TASKS.md" ]]
[[ -f ".codex/runs/$no_plan_run_id/REPORT.md" ]]
[[ ! -f ".codex/runs/$no_plan_run_id/run.json" ]]

set +e
bash "$wrapper" --task-type invalid >"$temp_root/invalid-task-type.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Invalid --task-type" "$temp_root/invalid-task-type.out"

set +e
bash "$wrapper" --workflow-level invalid >"$temp_root/invalid-workflow-level.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Invalid --workflow-level" "$temp_root/invalid-workflow-level.out"

echo "PASS: new-run bash checks"
