#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
template_root="$source_repo_root/template"
python_cmd="python3"
if ! command -v python3 >/dev/null 2>&1; then
  python_cmd="python"
fi

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/observation-baseline.XXXXXX")"

cleanup() {
  case "$temp_root" in
    "${TMPDIR:-/tmp}"/observation-baseline.*)
      rm -rf -- "$temp_root"
      ;;
  esac
}
trap cleanup EXIT

compare_json() {
  "$python_cmd" - "$1" "$2" <<'PY'
import json
import sys
left = json.load(open(sys.argv[1], encoding="utf-8"))
right = json.load(open(sys.argv[2], encoding="utf-8"))
if left != right:
    raise SystemExit("JSON files differ")
PY
}

cat > "$temp_root/sample-hook-observation.json" <<'EOF'
{"schema_version":1,"event_id":"20260627T120000Z-12345","run_id":null,"timestamp":"2026-06-27T12:00:00Z","source":"codex_hook","event":"WrapperStart","severity":"info","blocking":false,"tool":null,"cwd":"/workspace","input_summary":null,"decision":{"action":"observe","reason":"optional observation hook recorded the event"},"evidence":[],"metadata":{"hook":"observe.sh"}}
EOF

cat > "$temp_root/sample-hook-observation-extra.json" <<'EOF'
{"schema_version":1,"event_id":"20260627T120000Z-12345","run_id":null,"timestamp":"2026-06-27T12:00:00Z","source":"codex_hook","event":"WrapperStart","severity":"info","blocking":false,"tool":null,"cwd":"/workspace","input_summary":null,"decision":{"action":"observe","reason":"optional observation hook recorded the event"},"evidence":[],"metadata":{"hook":"observe.sh"},"extra":"unexpected"}
EOF

cat > "$temp_root/sample-subagent-run.json" <<'EOF'
{
  "schema_version": 1,
  "subagent_run_id": "subagent-001",
  "parent_run_id": "20260627-120000-JST",
  "agent": {
    "name": "implementation_worker",
    "model": "gpt-5.4-mini"
  },
  "role": "implementation_worker",
  "mode": "writable",
  "purpose": "Update observation docs for the requested files only.",
  "sandbox": {
    "type": "workspace-write",
    "network": false
  },
  "allowed_files": [
    "template/docs/reference/hook-observation.md"
  ],
  "input_files": [
    "template/docs/reference/run-artifacts.md"
  ],
  "changed_files": [
    "template/docs/reference/hook-observation.md"
  ],
  "scope": {
    "declared": true,
    "compliant": true,
    "violations": []
  },
  "started_at": "2026-06-27T12:00:00Z",
  "ended_at": "2026-06-27T12:02:00Z",
  "status": "completed",
  "summary": "Updated the requested observation doc within the declared scope.",
  "parent_decision": {
    "action": "accepted",
    "reason": "The output stayed within allowed_files and matched the requested change."
  },
  "used_in_final_plan": true,
  "evidence": [
    {
      "kind": "path",
      "value": "template/docs/reference/hook-observation.md"
    }
  ],
  "metadata": {
    "note": "Sample only"
  }
}
EOF

"$python_cmd" "$template_root/scripts/validate-output-schema.py" "$source_repo_root/spec/hook-observation.schema.json" "$temp_root/sample-hook-observation.json"
"$python_cmd" "$template_root/scripts/validate-output-schema.py" "$source_repo_root/spec/subagent-run.schema.json" "$temp_root/sample-subagent-run.json"
compare_json "$source_repo_root/spec/hook-observation.schema.json" "$template_root/.codex/templates/hook-observation.schema.json"
compare_json "$source_repo_root/spec/subagent-run.schema.json" "$template_root/.codex/templates/subagent-run.schema.json"

set +e
extra_output="$("$python_cmd" "$template_root/scripts/validate-output-schema.py" "$source_repo_root/spec/hook-observation.schema.json" "$temp_root/sample-hook-observation-extra.json" 2>&1)"
extra_status=$?
set -e
[[ "$extra_status" -ne 0 ]]
[[ "$extra_output" == *"unexpected property 'extra'"* ]]

if [[ -f "$template_root/.codex/hooks/observe.sh" ]]; then
  observation_log="$temp_root/hooks.jsonl"
  (
    cd "$template_root"
    CODEX_HOOK_EVENT=PreToolUse \
    CODEX_HOOK_TOOL_NAME=Bash \
    CODEX_HOOK_TOOL_OPERATION=command \
    CODEX_HOOK_TOOL_TARGET=scripts/verify \
    CODEX_HOOK_INPUT_SUMMARY="Run verification command" \
    CODEX_OBSERVATION_LOG="$observation_log" \
    bash ".codex/hooks/observe.sh"
  )

  line_count="$(wc -l < "$observation_log")"
  [[ "$line_count" -eq 1 ]]

  "$python_cmd" - "$observation_log" "$source_repo_root/spec/hook-observation.schema.json" "$template_root/scripts/validate-output-schema.py" "$temp_root/observed-hook-event.json" <<'PY'
import json
import subprocess
import sys
log_path, schema_path, validator_path, output_path = sys.argv[1:5]
line = open(log_path, encoding="utf-8").read().strip()
payload = json.loads(line)
if payload["schema_version"] != 1:
    raise SystemExit("schema_version mismatch")
if payload["source"] != "codex_hook":
    raise SystemExit(f"source mismatch: {payload['source']}")
if payload["event"] != "PreToolUse":
    raise SystemExit(f"event mismatch: {payload['event']}")
if payload["blocking"] is not False:
    raise SystemExit(f"blocking mismatch: {payload['blocking']}")
if payload["decision"]["action"] != "observe":
    raise SystemExit(f"decision mismatch: {payload['decision']}")
with open(output_path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh)
subprocess.check_call([sys.executable, validator_path, schema_path, output_path])
PY

  invalid_observation_log="$temp_root/invalid-hooks.jsonl"
  (
    cd "$template_root"
    CODEX_HOOK_EVENT=UnknownEvent \
    CODEX_HOOK_SOURCE=unknown_source \
    CODEX_HOOK_SEVERITY=loud \
    CODEX_OBSERVATION_LOG="$invalid_observation_log" \
    bash ".codex/hooks/observe.sh"
  )

  "$python_cmd" - "$invalid_observation_log" "$source_repo_root/spec/hook-observation.schema.json" "$template_root/scripts/validate-output-schema.py" "$temp_root/invalid-observed-hook-event.json" <<'PY'
import json
import subprocess
import sys
log_path, schema_path, validator_path, output_path = sys.argv[1:5]
line = open(log_path, encoding="utf-8").read().strip()
payload = json.loads(line)
if payload["event"] != "ObservationError":
    raise SystemExit(f"event mismatch: {payload['event']}")
if payload["source"] != "unknown":
    raise SystemExit(f"source mismatch: {payload['source']}")
if payload["severity"] != "warning":
    raise SystemExit(f"severity mismatch: {payload['severity']}")
if payload["input_summary"] is not None:
    raise SystemExit(f"input_summary mismatch: {payload['input_summary']!r}")
metadata = payload["metadata"]
if metadata.get("original_event") != "UnknownEvent":
    raise SystemExit(f"original_event mismatch: {metadata}")
if metadata.get("original_source") != "unknown_source":
    raise SystemExit(f"original_source mismatch: {metadata}")
if metadata.get("original_severity") != "loud":
    raise SystemExit(f"original_severity mismatch: {metadata}")
with open(output_path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh)
subprocess.check_call([sys.executable, validator_path, schema_path, output_path])
PY

  mkdir -p "$temp_root/failure-dir"
  set +e
  (
    cd "$template_root"
    CODEX_HOOK_EVENT=PreToolUse \
    CODEX_HOOK_TOOL_NAME=Bash \
    CODEX_HOOK_INPUT_SUMMARY="Run verification command" \
    CODEX_OBSERVATION_LOG="$temp_root/failure-dir" \
    bash ".codex/hooks/observe.sh"
  ) >"$temp_root/failure.out" 2>"$temp_root/failure.err"
  failure_code=$?
  set -e
  [[ "$failure_code" -eq 0 ]]
fi

echo "PASS: observation baseline checks"
