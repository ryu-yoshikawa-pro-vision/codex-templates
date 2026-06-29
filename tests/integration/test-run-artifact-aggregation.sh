#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
template_source_root="$source_repo_root/template"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-run-artifacts-test.XXXXXX")"
template_root="$temp_root/template"
python_cmd="python"
if ! command -v python >/dev/null 2>&1; then
  python_cmd="python3"
fi

cleanup() {
  case "$temp_root" in
    "${TMPDIR:-/tmp}"/codex-run-artifacts-test.*)
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

run_id="20260628-120000-JST"
bash scripts/new-run.sh --run-id "$run_id" --task-type harness-improvement --workflow-level strict

mkdir -p ".codex/runs/$run_id/reports" ".codex/runs/$run_id/subagents" ".codex/runs/$run_id/logs" ".codex/observations"
printf '{"status":"ok"}\n' > ".codex/runs/$run_id/reports/codex-task-a.report.json"
printf '{"status":"ok"}\n' > ".codex/runs/$run_id/reports/codex-task-b.report.json"

cat > ".codex/runs/$run_id/subagents/subagent-001.json" <<'EOF'
{
  "schema_version": 1,
  "subagent_run_id": "subagent-001",
  "parent_run_id": "20260628-120000-JST",
  "agent": {
    "name": "implementation_worker",
    "model": "gpt-5.4-mini"
  },
  "role": "implementation_worker",
  "mode": "writable",
  "purpose": "Update one doc in scope.",
  "sandbox": {
    "type": "workspace-write",
    "network": false
  },
  "allowed_files": [
    "docs/reference/hook-observation.md"
  ],
  "input_files": [],
  "changed_files": [
    "docs/reference/hook-observation.md"
  ],
  "scope": {
    "declared": true,
    "compliant": true,
    "violations": []
  },
  "started_at": "2026-06-28T03:00:00Z",
  "ended_at": "2026-06-28T03:02:00Z",
  "status": "completed",
  "summary": "Updated the requested doc in scope.",
  "parent_decision": {
    "action": "accepted",
    "reason": "The output stayed within scope."
  },
  "used_in_final_plan": true,
  "evidence": [
    {
      "kind": "path",
      "value": "docs/reference/hook-observation.md"
    }
  ],
  "metadata": {}
}
EOF
printf '{"bad":\n' > ".codex/runs/$run_id/subagents/bad.json"
cat > ".codex/runs/$run_id/subagents/mismatch.json" <<'EOF'
{
  "schema_version": 1,
  "subagent_run_id": "subagent-999",
  "parent_run_id": "20260628-999999-JST",
  "agent": {"name": "implementation_worker", "model": "gpt-5.4-mini"},
  "role": "implementation_worker",
  "mode": "writable",
  "purpose": "Mismatch sample",
  "sandbox": {"type": "workspace-write", "network": false},
  "allowed_files": ["README.md"],
  "input_files": [],
  "changed_files": ["README.md"],
  "scope": {"declared": true, "compliant": true, "violations": []},
  "started_at": "2026-06-28T03:00:00Z",
  "ended_at": "2026-06-28T03:01:00Z",
  "status": "completed",
  "summary": "Mismatch sample",
  "parent_decision": {"action": "rejected", "reason": "Wrong run"},
  "used_in_final_plan": false,
  "evidence": [],
  "metadata": {}
}
EOF

cat > ".codex/observations/hooks.jsonl" <<EOF
{"schema_version":1,"event_id":"evt-1","run_id":"$run_id","timestamp":"2026-06-28T03:00:00Z","source":"codex_hook","event":"WrapperStart","severity":"info","blocking":false,"tool":null,"cwd":"/workspace","input_summary":"wrapper start","decision":{"action":"observe","reason":"sample"},"evidence":[],"metadata":{}}
{"schema_version":1,"event_id":"evt-2","run_id":"$run_id","timestamp":"2026-06-28T03:01:00Z","source":"codex_hook","event":"SafetyBlocked","severity":"warning","blocking":true,"tool":{"name":"Bash","operation":"command","target":"rm file.txt"},"cwd":"/workspace","input_summary":"delete attempt","decision":{"action":"block","reason":"delete attempt blocked"},"evidence":[],"metadata":{"type":"delete_attempt"}}
{"schema_version":1,"event_id":"evt-3","run_id":"$run_id","timestamp":"2026-06-28T03:02:00Z","source":"codex_hook","event":"ObservationError","severity":"error","blocking":false,"tool":null,"cwd":"/workspace","input_summary":"observe failed","decision":{"action":"error","reason":"sample"},"evidence":[],"metadata":{}}
not-json
{"schema_version":1,"event_id":"evt-other","run_id":"20260628-999999-JST","timestamp":"2026-06-28T03:03:00Z","source":"codex_hook","event":"SafetyBlocked","severity":"warning","blocking":true,"tool":null,"cwd":"/workspace","input_summary":"ignore","decision":{"action":"block","reason":"other run"},"evidence":[],"metadata":{"type":"git_mutation"}}
EOF

cat > ".codex/runs/$run_id/logs/extra-hooks.jsonl" <<EOF
{"schema_version":1,"event_id":"evt-4","run_id":"$run_id","timestamp":"2026-06-28T03:04:00Z","source":"subagent","event":"SubagentStart","severity":"info","blocking":false,"tool":null,"cwd":"/workspace","input_summary":"subagent start","decision":{"action":"observe","reason":"sample"},"evidence":[],"metadata":{}}
{"schema_version":1,"event_id":"evt-5","run_id":"$run_id","timestamp":"2026-06-28T03:05:00Z","source":"codex_hook","event":"SafetyBlocked","severity":"warning","blocking":true,"tool":{"name":"Git","operation":"command","target":"git add ."},"cwd":"/workspace","input_summary":"git mutation attempt","decision":{"action":"block","reason":"git mutation blocked"},"evidence":[],"metadata":{"type":"git_mutation"}}
EOF

cat > ".codex/runs/$run_id/evaluation.json" <<EOF
{
  "schema_version": 1,
  "run_id": "$run_id",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {"rating": "warn", "evidence": "Needs more work."},
    "scope_control": {"rating": "pass", "evidence": "Scope stayed bounded."},
    "validation_confidence": {"rating": "warn", "evidence": "Validation was incomplete."},
    "safety_compliance": {"rating": "pass", "evidence": "Safety boundary held."},
    "reviewability": {"rating": "pass", "evidence": "Artifacts are reviewable."},
    "maintainability": {"rating": "pass", "evidence": "Changes stay local."},
    "reproducibility": {"rating": "pass", "evidence": "Artifacts are reproducible."}
  },
  "findings": [],
  "improvement_candidates": []
}
EOF

"$python_cmd" - ".codex/runs/$run_id/run.json" <<'PY'
import json
import sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["changed_files"] = ["README.md"]
data["validation"]["status"] = "passed_with_warnings"
data["validation"]["commands"] = [
    {"command": "bash template/scripts/verify", "exit_code": 0, "status": "passed", "evidence": "verify passed"}
]
data["validation"]["warnings"] = [
    {"type": "expected_changed_file_missing", "path": "README.md", "message": "sample warning"}
]
data["status"] = "completed"
json.dump(data, open(path, "w", encoding="utf-8"), indent=2)
PY

bash scripts/collect-run-artifacts.sh --run-id "$run_id"

"$python_cmd" - ".codex/runs/$run_id/run.json" "$run_id" <<'PY'
import json
import sys
path, run_id = sys.argv[1:3]
data = json.load(open(path, encoding="utf-8"))
reports = data["codex_task_reports"]
expected_reports = {
    f".codex/runs/{run_id}/reports/codex-task-a.report.json",
    f".codex/runs/{run_id}/reports/codex-task-b.report.json",
}
if not expected_reports.issubset(set(reports)):
    raise SystemExit(f"missing report refs: {reports}")
if data["artifact_summary"] != {
    "codex_task_report_count": 2,
    "hook_event_count": 5,
    "subagent_run_count": 1,
    "evaluation_present": True,
}:
    raise SystemExit(f"unexpected artifact_summary: {data['artifact_summary']}")
if set(data["changed_files"]) != {"README.md", "docs/reference/hook-observation.md"}:
    raise SystemExit(f"unexpected changed_files: {data['changed_files']}")
if data["hook_observations"]["event_counts"] != {
    "ObservationError": 1,
    "SafetyBlocked": 2,
    "SubagentStart": 1,
    "WrapperStart": 1,
}:
    raise SystemExit(f"unexpected hook counts: {data['hook_observations']['event_counts']}")
if data["hook_observations"]["blocking_event_count"] != 2:
    raise SystemExit(f"unexpected blocking count: {data['hook_observations']}")
if data["hook_observations"]["safety_blocked_count"] != 2:
    raise SystemExit(f"unexpected safety blocked count: {data['hook_observations']}")
if data["hook_observations"]["observation_error_count"] != 1:
    raise SystemExit(f"unexpected observation error count: {data['hook_observations']}")
if data["safety"]["delete_attempt_blocked"] is not True:
    raise SystemExit(f"delete safety summary was not updated: {data['safety']}")
if data["safety"]["git_mutation_attempt_blocked"] is not True:
    raise SystemExit(f"git safety summary was not updated: {data['safety']}")
if data["subagents"]["summary"] != {
    "total": 1,
    "read_only": 0,
    "writable": 1,
    "scope_violations": 0,
    "used_in_final_plan": 1,
}:
    raise SystemExit(f"unexpected subagent summary: {data['subagents']['summary']}")
record = data["subagents"]["records"][0]
if record["path"] != f".codex/runs/{run_id}/subagents/subagent-001.json":
    raise SystemExit(f"unexpected subagent record path: {record}")
if record["subagent_run_id"] != "subagent-001" or record["agent_name"] != "implementation_worker" or record["role"] != "implementation_worker" or record["mode"] != "writable" or record["status"] != "completed":
    raise SystemExit(f"unexpected subagent identity fields: {record}")
if record["changed_files_count"] != 1 or record["allowed_files_count"] != 1 or record["scope_compliant"] is not True or record["used_in_final_plan"] is not True or record["parent_decision"] != "accepted":
    raise SystemExit(f"unexpected subagent record: {record}")
if data["evaluation_path"] != f".codex/runs/{run_id}/evaluation.json":
    raise SystemExit(f"unexpected evaluation_path: {data['evaluation_path']}")
if data["primary_failure_category"] != "missing_validation":
    raise SystemExit(f"unexpected primary_failure_category: {data['primary_failure_category']}")
if "implementation_worker" not in data["agents_used"]:
    raise SystemExit(f"agents_used missing subagent: {data['agents_used']}")
warning_types = {item["type"] for item in data["validation"]["warnings"]}
for expected in {"expected_changed_file_missing", "subagent_invalid_json", "subagent_parent_run_mismatch", "hook_observation_invalid_jsonl"}:
    if expected not in warning_types:
        raise SystemExit(f"missing warning {expected}: {data['validation']['warnings']}")
PY

cat > ".codex/runs/$run_id/base.json" <<EOF
{
  "schema_version": 1,
  "run_id": "$run_id",
  "task_type": "harness-improvement",
  "workflow_level": "strict",
  "preset": "safe",
  "runtime": "host",
  "agents_used": ["baseline"],
  "repo": "sample/repo",
  "branch": "feature/base-manifest",
  "base_branch": "main",
  "codex_task_reports": [],
  "changed_files": [],
  "validation": {"status": "not_run", "commands": [], "warnings": []},
  "safety": {"network": false, "delete_attempt_blocked": false, "git_mutation_attempt_blocked": false, "scope_violation": false},
  "artifact_summary": {"codex_task_report_count": 0, "hook_event_count": 0, "subagent_run_count": 0, "evaluation_present": false},
  "hook_observations": {"log_paths": [], "event_counts": {}, "blocking_event_count": 0, "safety_blocked_count": 0, "observation_error_count": 0},
  "subagents": {"records": [], "summary": {"total": 0, "read_only": 0, "writable": 0, "scope_violations": 0, "used_in_final_plan": 0}},
  "evaluation_path": null,
  "status": "pending",
  "primary_failure_category": null
}
EOF

(
  cd "$temp_root"
  bash "$template_root/scripts/collect-run-artifacts.sh" \
    --run-id "$run_id" \
    --base-manifest ".codex/runs/$run_id/base.json" \
    --manifest-path ".codex/runs/$run_id/relative-run.json"
)

"$python_cmd" - "$template_root/.codex/runs/$run_id/relative-run.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["repo"] != "sample/repo" or data["branch"] != "feature/base-manifest" or data["base_branch"] != "main":
    raise SystemExit(f"relative base-manifest inheritance failed: {data}")
if "baseline" not in data["agents_used"]:
    raise SystemExit(f"relative base-manifest agents_used inheritance failed: {data['agents_used']}")
PY

cat > "$temp_root/evaluation-old.json" <<'EOF'
{
  "schema_version": 1,
  "run_id": "20260628-120001-JST",
  "result": "not_evaluated",
  "primary_failure_category": null,
  "failure_categories": [],
  "dimensions": {
    "task_completion": {"rating": "not_evaluated", "evidence": "pending"},
    "scope_control": {"rating": "not_evaluated", "evidence": "pending"},
    "validation_confidence": {"rating": "not_evaluated", "evidence": "pending"},
    "safety_compliance": {"rating": "not_evaluated", "evidence": "pending"},
    "reviewability": {"rating": "not_evaluated", "evidence": "pending"},
    "maintainability": {"rating": "not_evaluated", "evidence": "pending"},
    "reproducibility": {"rating": "not_evaluated", "evidence": "pending"}
  },
  "findings": [],
  "improvement_candidates": []
}
EOF

cat > "$temp_root/evaluation-new.json" <<'EOF'
{
  "schema_version": 1,
  "run_id": "20260628-120002-JST",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {
      "rating": "warn",
      "evidence": "verify failed",
      "evidence_refs": [
        {
          "kind": "validation_command",
          "path": ".codex/runs/20260628-120002-JST/run.json",
          "selector": "$.validation.commands[0]",
          "event_id": null,
          "summary": "verify failed"
        }
      ]
    },
    "scope_control": {"rating": "pass", "evidence": "bounded", "evidence_refs": []},
    "validation_confidence": {"rating": "warn", "evidence": "partial", "evidence_refs": []},
    "safety_compliance": {"rating": "pass", "evidence": "safe", "evidence_refs": []},
    "reviewability": {"rating": "pass", "evidence": "reviewable", "evidence_refs": []},
    "maintainability": {"rating": "pass", "evidence": "maintainable", "evidence_refs": []},
    "reproducibility": {"rating": "pass", "evidence": "reproducible", "evidence_refs": []}
  },
  "findings": [
    {
      "category": "missing_validation",
      "severity": "medium",
      "evidence": "verify failed",
      "evidence_refs": [
        {
          "kind": "run_manifest",
          "path": ".codex/runs/20260628-120002-JST/run.json",
          "selector": "$.validation",
          "event_id": null,
          "summary": "validation summary"
        }
      ],
      "detail": "verify did not pass"
    }
  ],
  "improvement_candidates": [
    {
      "target": "scripts/codex-task.sh",
      "evidence": "same failure repeated",
      "evidence_refs": [],
      "expected_impact": "better validation",
      "recommendation": "tighten checks"
    }
  ]
}
EOF

cat > "$temp_root/evaluation-invalid-kind.json" <<'EOF'
{
  "schema_version": 1,
  "run_id": "20260628-120003-JST",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {
      "rating": "warn",
      "evidence": "verify failed",
      "evidence_refs": [
        {"kind": "bad_kind", "path": null, "selector": null, "event_id": null, "summary": "bad"}
      ]
    },
    "scope_control": {"rating": "pass", "evidence": "bounded"},
    "validation_confidence": {"rating": "warn", "evidence": "partial"},
    "safety_compliance": {"rating": "pass", "evidence": "safe"},
    "reviewability": {"rating": "pass", "evidence": "reviewable"},
    "maintainability": {"rating": "pass", "evidence": "maintainable"},
    "reproducibility": {"rating": "pass", "evidence": "reproducible"}
  },
  "findings": [],
  "improvement_candidates": []
}
EOF

cat > "$temp_root/evaluation-missing-evidence.json" <<'EOF'
{
  "schema_version": 1,
  "run_id": "20260628-120004-JST",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {"rating": "warn"},
    "scope_control": {"rating": "pass", "evidence": "bounded"},
    "validation_confidence": {"rating": "warn", "evidence": "partial"},
    "safety_compliance": {"rating": "pass", "evidence": "safe"},
    "reviewability": {"rating": "pass", "evidence": "reviewable"},
    "maintainability": {"rating": "pass", "evidence": "maintainable"},
    "reproducibility": {"rating": "pass", "evidence": "reproducible"}
  },
  "findings": [],
  "improvement_candidates": []
}
EOF

"$python_cmd" scripts/validate-output-schema.py .codex/templates/evaluation.schema.json "$temp_root/evaluation-old.json"
"$python_cmd" scripts/validate-output-schema.py .codex/templates/evaluation.schema.json "$temp_root/evaluation-new.json"

set +e
"$python_cmd" scripts/validate-output-schema.py .codex/templates/evaluation.schema.json "$temp_root/evaluation-invalid-kind.json" >"$temp_root/invalid-kind.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]

set +e
"$python_cmd" scripts/validate-output-schema.py .codex/templates/evaluation.schema.json "$temp_root/evaluation-missing-evidence.json" >"$temp_root/missing-evidence.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]

echo "PASS: run artifact aggregation bash checks"
