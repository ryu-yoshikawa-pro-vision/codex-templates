#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
template_source_root="$source_repo_root/template"
fake_codex="$source_repo_root/tests/fixtures/fake-codex.sh"
fake_docker="$source_repo_root/tests/fixtures/fake-docker.sh"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-task-test.XXXXXX")"
template_root="$temp_root/template"
wrapper="$template_root/scripts/codex-task.sh"
sandbox_wrapper="$template_root/scripts/codex-sandbox.sh"
python_cmd="python3"
if ! command -v python3 >/dev/null 2>&1; then
  python_cmd="python"
fi

cleanup() {
  case "$temp_root" in
    "${TMPDIR:-/tmp}"/codex-task-test.*)
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
(
  cd "$template_root"
  git init -q
  git config user.email codex-test@example.com
  git config user.name codex-test
  git add .
  git commit -q -m "test baseline"
)

assert_status() {
  local path="$1"
  local expected="$2"
  "$python_cmd" - "$path" "$expected" <<'PY'
import json
import sys
path, expected = sys.argv[1:3]
data = json.load(open(path, encoding="utf-8"))
required = ["runtime", "preset", "mode", "run_id", "cwd", "git_branch", "git_dirty", "prompt_source", "output_file", "output_schema", "log_path", "codex_exit_code", "verify_exit_code", "status"]
missing = [key for key in required if key not in data]
if missing:
    raise SystemExit(f"missing report keys: {missing}")
if data["status"] != expected:
    raise SystemExit(f"expected status {expected}, got {data['status']}")
PY
}

assert_manifest_baseline() {
  local path="$1"
  local expected_run_id="$2"
  local expected_report_name="$3"
  "$python_cmd" - "$path" "$expected_run_id" "$expected_report_name" <<'PY'
import json
import sys
path, expected_run_id, expected_report_name = sys.argv[1:4]
data = json.load(open(path, encoding="utf-8"))
if data["run_id"] != expected_run_id:
    raise SystemExit(f"expected run_id {expected_run_id}, got {data['run_id']}")
if data["task_type"] != "implementation":
    raise SystemExit(f"expected default task_type implementation, got {data['task_type']}")
if data["workflow_level"] != "standard":
    raise SystemExit(f"expected default workflow_level standard, got {data['workflow_level']}")
if data["validation"]["status"] != "skipped":
    raise SystemExit(f"expected validation.status skipped, got {data['validation']['status']}")
if data["status"] != "completed":
    raise SystemExit(f"expected run status completed, got {data['status']}")
reports = data["codex_task_reports"]
if not reports:
    raise SystemExit("expected codex_task_reports to contain at least one path")
report_ref = reports[0].replace("\\", "/")
expected_prefix = f".codex/runs/{expected_run_id}/reports/"
if not report_ref.startswith(expected_prefix):
    raise SystemExit(f"expected report path under {expected_prefix}, got {report_ref}")
if not report_ref.endswith(expected_report_name):
    raise SystemExit(f"expected report ref to end with {expected_report_name}, got {report_ref}")
if data["changed_files"] != []:
    raise SystemExit(f"expected changed_files to be empty, got {data['changed_files']}")
if data["evaluation_path"] is not None:
    raise SystemExit(f"expected evaluation_path null, got {data['evaluation_path']}")
if data["primary_failure_category"] is not None:
    raise SystemExit(f"expected primary_failure_category null, got {data['primary_failure_category']}")
PY
}

assert_manifest_validation_failed() {
  local path="$1"
  local expected_command="${2:-}"
  "$python_cmd" - "$path" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["status"] != "failed":
    raise SystemExit(f"expected run status failed, got {data['status']}")
if data["validation"]["status"] != "failed":
    raise SystemExit(f"expected validation.status failed, got {data['validation']['status']}")
commands = data["validation"]["commands"]
if not commands:
    raise SystemExit("expected at least one validation command")
failed = [command for command in commands if command["status"] == "failed"]
if not failed:
    raise SystemExit(f"expected at least one failed validation command, got {commands}")
for command in failed:
    if not command["evidence"]:
        raise SystemExit("expected non-empty validation command evidence")
PY
}

assert_manifest_state() {
  local path="$1"
  local expected_run_status="$2"
  local expected_validation_status="$3"
  local expected_scope_violation="$4"
  local expected_changed_csv="$5"
  local expected_command="${6:-}"
  local expected_command_status="${7:-}"
  "$python_cmd" - "$path" "$expected_run_status" "$expected_validation_status" "$expected_scope_violation" "$expected_changed_csv" "$expected_command" "$expected_command_status" <<'PY'
import json
import sys

path, expected_run_status, expected_validation_status, expected_scope_violation, expected_changed_csv, expected_command, expected_command_status = sys.argv[1:8]
data = json.load(open(path, encoding="utf-8"))
if data["status"] != expected_run_status:
    raise SystemExit(f"expected run status {expected_run_status}, got {data['status']}")
if data["validation"]["status"] != expected_validation_status:
    raise SystemExit(f"expected validation.status {expected_validation_status}, got {data['validation']['status']}")
expected_scope = expected_scope_violation.lower() == "true"
if data["safety"]["scope_violation"] != expected_scope:
    raise SystemExit(f"expected scope_violation {expected_scope}, got {data['safety']['scope_violation']}")
expected_changed = [] if expected_changed_csv == "" else expected_changed_csv.split(",")
if data["changed_files"] != expected_changed:
    raise SystemExit(f"expected changed_files {expected_changed}, got {data['changed_files']}")
commands = data["validation"]["commands"]
if expected_command:
    matches = [command for command in commands if command["command"] == expected_command and command["status"] == expected_command_status]
    if not matches:
        raise SystemExit(f"expected validation command {expected_command}/{expected_command_status}, got {commands}")
    command = matches[0]
    if not command["evidence"]:
        raise SystemExit("expected non-empty validation command evidence")
else:
    if commands:
        raise SystemExit(f"expected no validation commands, got {commands}")
PY
}

assert_manifest_contains_command() {
  local path="$1"
  local expected_command="$2"
  local expected_status="$3"
  "$python_cmd" - "$path" "$expected_command" "$expected_status" <<'PY'
import json
import sys
path, expected_command, expected_status = sys.argv[1:4]
data = json.load(open(path, encoding="utf-8"))
commands = data["validation"]["commands"]
matches = [command for command in commands if command["command"] == expected_command and command["status"] == expected_status]
if not matches:
    raise SystemExit(f"expected command {expected_command}/{expected_status}, got {commands}")
if not matches[0]["evidence"]:
    raise SystemExit("expected non-empty validation evidence")
PY
}

assert_manifest_evaluation_summary() {
  local path="$1"
  local expected_evaluation_path="$2"
  local expected_primary_failure_category="$3"
  "$python_cmd" - "$path" "$expected_evaluation_path" "$expected_primary_failure_category" <<'PY'
import json
import sys
path, expected_path, expected_category = sys.argv[1:4]
data = json.load(open(path, encoding="utf-8"))
actual_path = data["evaluation_path"]
actual_category = data["primary_failure_category"]
expected_category = None if expected_category == "null" else expected_category
if actual_path != expected_path:
    raise SystemExit(f"expected evaluation_path {expected_path}, got {actual_path}")
if actual_category != expected_category:
    raise SystemExit(f"expected primary_failure_category {expected_category}, got {actual_category}")
PY
}

restore_scope_fixtures() {
  cp "$template_source_root/README.md" "$template_root/README.md"
  cp "$template_source_root/scripts/verify" "$template_root/scripts/verify"
}

export CODEX_BIN="$fake_codex"
cd "$template_root"
printf '{"type":"object","required":["status"],"properties":{"status":{"type":"string"}},"additionalProperties":false}\n' > "$temp_root/schema.json"
printf '{"oneOf":[{"type":"object"}]}\n' > "$temp_root/unsupported-schema.json"

bash "$wrapper" --output-file "$temp_root/ok.json" --output-schema "$temp_root/schema.json" --report-path "$temp_root/ok.report.json" --log-path "$temp_root/ok.jsonl" --verify-command "true" "SCHEMA_OK"
assert_status "$temp_root/ok.report.json" ok

bash "$wrapper" --preset readonly --output-file "$temp_root/readonly.json" --report-path "$temp_root/readonly.report.json" --log-path "$temp_root/readonly.jsonl" --skip-verify "READONLY_OK"
assert_status "$temp_root/readonly.report.json" verify_skipped

FAKE_CODEX_DOCKER_PS_DECISION=allow FAKE_CODEX_ALLOW_NEVER=1 bash "$wrapper" --preset auto-net --output-file "$temp_root/auto-net.json" --report-path "$temp_root/auto-net.report.json" --log-path "$temp_root/auto-net.jsonl" --skip-verify "AUTO_NET_OK"
assert_status "$temp_root/auto-net.report.json" verify_skipped
"$python_cmd" - "$temp_root/auto-net.report.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["preset"] != "auto-net":
    raise SystemExit(f"expected auto-net preset, got {data['preset']}")
PY

run_id="20260420-020201-JST"
bash "$wrapper" --run-id "$run_id" --skip-verify "RUN_ID_OK"
run_report="$(find "$template_root/.codex/runs/$run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$run_report" verify_skipped
"$python_cmd" - "$run_report" "$run_id" <<'PY'
import json
import sys
path, expected_run_id = sys.argv[1:3]
data = json.load(open(path, encoding="utf-8"))
if data["run_id"] != expected_run_id:
    raise SystemExit(f"expected run_id {expected_run_id}, got {data['run_id']}")
for key in ("output_file", "log_path"):
    if f".codex/runs/{expected_run_id}/" not in data[key].replace("\\", "/"):
        raise SystemExit(f"{key} is not run-local: {data[key]}")
PY

manifest_run_id="20260420-020203-JST"
bash "$wrapper" --run-id "$manifest_run_id" --record-run-manifest --skip-verify "RUN_MANIFEST_OK"
manifest_report="$(find "$template_root/.codex/runs/$manifest_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
manifest_path="$template_root/.codex/runs/$manifest_run_id/run.json"
assert_status "$manifest_report" verify_skipped
assert_manifest_baseline "$manifest_path" "$manifest_run_id" "$(basename "$manifest_report")"

evaluation_template_run_id="20260420-020211-JST"
bash "$wrapper" --run-id "$evaluation_template_run_id" --record-run-manifest --evaluation-template --skip-verify "EVALUATION_TEMPLATE_OK"
evaluation_template_report="$(find "$template_root/.codex/runs/$evaluation_template_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
evaluation_template_manifest="$template_root/.codex/runs/$evaluation_template_run_id/run.json"
evaluation_template_file="$template_root/.codex/runs/$evaluation_template_run_id/evaluation.json"
assert_status "$evaluation_template_report" verify_skipped
"$python_cmd" - "$evaluation_template_file" "$evaluation_template_run_id" <<'PY'
import json
import sys
path, expected_run_id = sys.argv[1:3]
data = json.load(open(path, encoding="utf-8"))
if data["run_id"] != expected_run_id:
    raise SystemExit(f"expected evaluation run_id {expected_run_id}, got {data['run_id']}")
if data["result"] != "not_evaluated":
    raise SystemExit(f"expected not_evaluated result, got {data['result']}")
PY
assert_manifest_evaluation_summary "$evaluation_template_manifest" ".codex/runs/$evaluation_template_run_id/evaluation.json" "null"

evaluation_existing_run_id="20260420-020212-JST"
evaluation_existing_file="$template_root/.codex/runs/$evaluation_existing_run_id/evaluation.json"
mkdir -p "$(dirname "$evaluation_existing_file")"
printf '{"schema_version":1,"run_id":"%s","result":"not_evaluated","primary_failure_category":null,"failure_categories":[],"dimensions":{"task_completion":{"rating":"not_evaluated","evidence":"KEEP"},"scope_control":{"rating":"not_evaluated","evidence":"KEEP"},"validation_confidence":{"rating":"not_evaluated","evidence":"KEEP"},"safety_compliance":{"rating":"not_evaluated","evidence":"KEEP"},"reviewability":{"rating":"not_evaluated","evidence":"KEEP"},"maintainability":{"rating":"not_evaluated","evidence":"KEEP"},"reproducibility":{"rating":"not_evaluated","evidence":"KEEP"}},"findings":[],"improvement_candidates":[]}\n' "$evaluation_existing_run_id" > "$evaluation_existing_file"
bash "$wrapper" --run-id "$evaluation_existing_run_id" --record-run-manifest --evaluation-template --skip-verify "EVALUATION_TEMPLATE_EXISTS"
grep -q '"evidence":"KEEP"' "$evaluation_existing_file"

require_evaluation_missing_run_id="20260420-020213-JST"
set +e
bash "$wrapper" --run-id "$require_evaluation_missing_run_id" --record-run-manifest --require-evaluation --skip-verify "EVALUATION_MISSING" >"$temp_root/evaluation-missing.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
require_evaluation_missing_report="$(find "$template_root/.codex/runs/$require_evaluation_missing_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$require_evaluation_missing_report" evaluation_missing
assert_manifest_state "$template_root/.codex/runs/$require_evaluation_missing_run_id/run.json" failed failed false "" "evaluation validation" failed
"$python_cmd" - "$template_root/.codex/runs/$require_evaluation_missing_run_id/run.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["evaluation_path"] is not None:
    raise SystemExit(f"expected evaluation_path null, got {data['evaluation_path']}")
PY

require_evaluation_valid_run_id="20260420-020214-JST"
require_evaluation_valid_file="$template_root/.codex/runs/$require_evaluation_valid_run_id/evaluation.json"
mkdir -p "$(dirname "$require_evaluation_valid_file")"
cat > "$require_evaluation_valid_file" <<EOF
{
  "schema_version": 1,
  "run_id": "$require_evaluation_valid_run_id",
  "result": "partial",
  "primary_failure_category": "missing_validation",
  "failure_categories": ["missing_validation"],
  "dimensions": {
    "task_completion": {"rating": "warn", "evidence": "Task completion needs follow-up."},
    "scope_control": {"rating": "pass", "evidence": "Scope stayed within the requested files."},
    "validation_confidence": {"rating": "warn", "evidence": "Validation was intentionally skipped."},
    "safety_compliance": {"rating": "pass", "evidence": "No unsafe action was observed."},
    "reviewability": {"rating": "pass", "evidence": "Artifacts were easy to inspect."},
    "maintainability": {"rating": "pass", "evidence": "Changes remain localized."},
    "reproducibility": {"rating": "pass", "evidence": "Run artifacts are reproducible."}
  },
  "findings": [],
  "improvement_candidates": []
}
EOF
set +e
bash "$wrapper" --run-id "$require_evaluation_valid_run_id" --record-run-manifest --require-evaluation --skip-verify "EVALUATION_VALID" >"$temp_root/evaluation-valid.out" 2>&1
code=$?
set -e
if [[ $code -ne 0 ]]; then
  cat "$temp_root/evaluation-valid.out" >&2
  find "$template_root/.codex/runs/$require_evaluation_valid_run_id" -maxdepth 2 -type f -print -exec cat {} \; >&2 || true
  exit 1
fi
require_evaluation_valid_report="$(find "$template_root/.codex/runs/$require_evaluation_valid_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$require_evaluation_valid_report" verify_skipped
assert_manifest_evaluation_summary "$template_root/.codex/runs/$require_evaluation_valid_run_id/run.json" ".codex/runs/$require_evaluation_valid_run_id/evaluation.json" "missing_validation"
assert_manifest_contains_command "$template_root/.codex/runs/$require_evaluation_valid_run_id/run.json" "evaluation validation" "passed"

require_evaluation_invalid_run_id="20260420-020215-JST"
require_evaluation_invalid_file="$template_root/.codex/runs/$require_evaluation_invalid_run_id/evaluation.json"
mkdir -p "$(dirname "$require_evaluation_invalid_file")"
printf '{"schema_version":1,"run_id":"%s","result":"not_evaluated"}\n' "$require_evaluation_invalid_run_id" > "$require_evaluation_invalid_file"
set +e
bash "$wrapper" --run-id "$require_evaluation_invalid_run_id" --record-run-manifest --require-evaluation --skip-verify "EVALUATION_INVALID" >"$temp_root/evaluation-invalid.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
require_evaluation_invalid_report="$(find "$template_root/.codex/runs/$require_evaluation_invalid_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$require_evaluation_invalid_report" evaluation_invalid
assert_manifest_state "$template_root/.codex/runs/$require_evaluation_invalid_run_id/run.json" failed failed false "" "evaluation validation" failed

require_evaluation_mismatch_run_id="20260420-020216-JST"
require_evaluation_mismatch_file="$template_root/.codex/runs/$require_evaluation_mismatch_run_id/evaluation.json"
mkdir -p "$(dirname "$require_evaluation_mismatch_file")"
cat > "$require_evaluation_mismatch_file" <<EOF
{
  "schema_version": 1,
  "run_id": "20260420-999999-JST",
  "result": "not_evaluated",
  "primary_failure_category": null,
  "failure_categories": [],
  "dimensions": {
    "task_completion": {"rating": "not_evaluated", "evidence": "Task completion has not been evaluated yet."},
    "scope_control": {"rating": "not_evaluated", "evidence": "Scope control has not been evaluated yet."},
    "validation_confidence": {"rating": "not_evaluated", "evidence": "Validation confidence has not been evaluated yet."},
    "safety_compliance": {"rating": "not_evaluated", "evidence": "Safety compliance has not been evaluated yet."},
    "reviewability": {"rating": "not_evaluated", "evidence": "Reviewability has not been evaluated yet."},
    "maintainability": {"rating": "not_evaluated", "evidence": "Maintainability has not been evaluated yet."},
    "reproducibility": {"rating": "not_evaluated", "evidence": "Reproducibility has not been evaluated yet."}
  },
  "findings": [],
  "improvement_candidates": []
}
EOF
set +e
bash "$wrapper" --run-id "$require_evaluation_mismatch_run_id" --record-run-manifest --require-evaluation --skip-verify "EVALUATION_MISMATCH" >"$temp_root/evaluation-mismatch.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
require_evaluation_mismatch_report="$(find "$template_root/.codex/runs/$require_evaluation_mismatch_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$require_evaluation_mismatch_report" evaluation_invalid
"$python_cmd" - "$template_root/.codex/runs/$require_evaluation_mismatch_run_id/run.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
evidence = " ".join(command["evidence"] for command in data["validation"]["commands"])
if "evaluation run_id mismatch" not in evidence:
    raise SystemExit(f"expected run_id mismatch evidence, got {evidence!r}")
PY

set +e
bash "$wrapper" --report-path "$temp_root/evaluation-template-no-manifest.report.json" --log-path "$temp_root/evaluation-template-no-manifest.jsonl" --evaluation-template --skip-verify "EVALUATION_TEMPLATE_NO_MANIFEST" >"$temp_root/evaluation-template-no-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- "--evaluation-template requires --run-id and --record-run-manifest" "$temp_root/evaluation-template-no-manifest.out"
assert_status "$temp_root/evaluation-template-no-manifest.report.json" invalid_args

set +e
bash "$wrapper" --report-path "$temp_root/require-evaluation-no-manifest.report.json" --log-path "$temp_root/require-evaluation-no-manifest.jsonl" --require-evaluation --skip-verify "REQUIRE_EVALUATION_NO_MANIFEST" >"$temp_root/require-evaluation-no-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- "--require-evaluation requires --run-id and --record-run-manifest" "$temp_root/require-evaluation-no-manifest.out"
assert_status "$temp_root/require-evaluation-no-manifest.report.json" invalid_args

bash "$wrapper" --require-clean-git --skip-verify "CLEAN_GIT_OK"
clean_git_report="$(find "$template_root/.codex/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$clean_git_report" verify_skipped

clean_git_run_id="20260420-020217-JST"
bash "$wrapper" --run-id "$clean_git_run_id" --require-clean-git --skip-verify "CLEAN_GIT_OK"
clean_git_report="$(find "$template_root/.codex/runs/$clean_git_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$clean_git_report" verify_skipped

printf '\nDIRTY_GIT\n' >> "$template_root/README.md"
dirty_git_run_id="20260420-020218-JST"
set +e
bash "$wrapper" --run-id "$dirty_git_run_id" --record-run-manifest --require-clean-git --skip-verify "DIRTY_GIT" >"$temp_root/dirty-git.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
dirty_git_report="$(find "$template_root/.codex/runs/$dirty_git_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$dirty_git_report" dirty_git
assert_manifest_state "$template_root/.codex/runs/$dirty_git_run_id/run.json" failed blocked false "README.md" "clean git check" blocked
"$python_cmd" - "$dirty_git_report" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["codex_exit_code"] is not None:
    raise SystemExit(f"expected codex_exit_code null, got {data['codex_exit_code']}")
PY
restore_scope_fixtures

mkdir -p "$template_root/.codex/runs/some-run"
printf '{"artifact":true}\n' > "$template_root/.codex/runs/some-run/tmp.json"
ignore_runs_run_id="20260420-020219-JST"
bash "$wrapper" --run-id "$ignore_runs_run_id" --require-clean-git --skip-verify "IGNORE_RUN_ARTIFACTS"
ignore_runs_report="$(find "$template_root/.codex/runs/$ignore_runs_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$ignore_runs_report" verify_skipped

set +e
bash "$wrapper" --report-path "$temp_root/require-run-id.report.json" --log-path "$temp_root/require-run-id.jsonl" --require-run-id --skip-verify "REQUIRE_RUN_ID" >"$temp_root/require-run-id.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- "--require-run-id requires --run-id" "$temp_root/require-run-id.out"
assert_status "$temp_root/require-run-id.report.json" invalid_args

require_run_id_ok="20260420-020220-JST"
bash "$wrapper" --run-id "$require_run_id_ok" --require-run-id --skip-verify "REQUIRE_RUN_ID_OK"
[[ ! -f "$template_root/.codex/runs/$require_run_id_ok/run.json" ]]

max_iterations_ok="20260420-020221-JST"
bash "$wrapper" --run-id "$max_iterations_ok" --max-iterations 3 --skip-verify "MAX_ITERATIONS_OK"
max_iterations_ok_report="$(find "$template_root/.codex/runs/$max_iterations_ok/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$max_iterations_ok_report" verify_skipped

for invalid_value in 0 -1 abc 11; do
  set +e
  bash "$wrapper" --report-path "$temp_root/max-iterations-$invalid_value.report.json" --log-path "$temp_root/max-iterations-$invalid_value.jsonl" --max-iterations "$invalid_value" --skip-verify "MAX_ITERATIONS_BAD" >"$temp_root/max-iterations-$invalid_value.out" 2>&1
  code=$?
  set -e
  [[ $code -ne 0 ]]
  grep -q -- "--max-iterations must be an integer between 1 and 10" "$temp_root/max-iterations-$invalid_value.out"
done

set +e
bash "$wrapper" --report-path "$temp_root/max-iterations-empty.report.json" --log-path "$temp_root/max-iterations-empty.jsonl" --max-iterations "" --skip-verify "MAX_ITERATIONS_BAD" >"$temp_root/max-iterations-empty.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- "--max-iterations must be an integer between 1 and 10" "$temp_root/max-iterations-empty.out"

allowed_ok_run_id="20260420-020207-JST"
FAKE_CODEX_WRITE_FILES="README.md" bash "$wrapper" --run-id "$allowed_ok_run_id" --record-run-manifest --allowed-files README.md --skip-verify "ALLOWED_OK"
allowed_ok_report="$(find "$template_root/.codex/runs/$allowed_ok_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$allowed_ok_report" verify_skipped
assert_manifest_state "$template_root/.codex/runs/$allowed_ok_run_id/run.json" completed skipped false "README.md"
restore_scope_fixtures

allowed_violation_run_id="20260420-020208-JST"
set +e
FAKE_CODEX_WRITE_FILES="README.md,scripts/verify" bash "$wrapper" --run-id "$allowed_violation_run_id" --record-run-manifest --allowed-files README.md --skip-verify "ALLOWED_VIOLATION" >"$temp_root/allowed-violation.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
allowed_violation_report="$(find "$template_root/.codex/runs/$allowed_violation_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$allowed_violation_report" scope_violation
assert_manifest_state "$template_root/.codex/runs/$allowed_violation_run_id/run.json" failed blocked true "README.md,scripts/verify" "change scope check" blocked
restore_scope_fixtures

expected_ok_run_id="20260420-020209-JST"
FAKE_CODEX_WRITE_FILES="README.md" bash "$wrapper" --run-id "$expected_ok_run_id" --record-run-manifest --expected-changed-files README.md --skip-verify "EXPECTED_OK"
expected_ok_report="$(find "$template_root/.codex/runs/$expected_ok_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$expected_ok_report" verify_skipped
assert_manifest_state "$template_root/.codex/runs/$expected_ok_run_id/run.json" completed skipped false "README.md"
restore_scope_fixtures

expected_missing_run_id="20260420-020210-JST"
set +e
bash "$wrapper" --run-id "$expected_missing_run_id" --record-run-manifest --expected-changed-files README.md --skip-verify "EXPECTED_MISSING" >"$temp_root/expected-missing.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
expected_missing_report="$(find "$template_root/.codex/runs/$expected_missing_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$expected_missing_report" expected_changes_missing
assert_manifest_state "$template_root/.codex/runs/$expected_missing_run_id/run.json" failed failed false "" "expected changed files check" failed

for invalid_value in "../outside.md" "/tmp/outside.md" "*.md"; do
  rm -f "$temp_root/invalid-allowed.report.json" "$temp_root/invalid-expected.report.json"

  set +e
  bash "$wrapper" --report-path "$temp_root/invalid-allowed.report.json" --log-path "$temp_root/invalid-allowed.jsonl" --allowed-files "$invalid_value" --skip-verify "INVALID_ALLOWED" >"$temp_root/invalid-allowed.out" 2>&1
  code=$?
  set -e
  [[ $code -ne 0 ]]
  assert_status "$temp_root/invalid-allowed.report.json" invalid_args

  set +e
  bash "$wrapper" --report-path "$temp_root/invalid-expected.report.json" --log-path "$temp_root/invalid-expected.jsonl" --expected-changed-files "$invalid_value" --skip-verify "INVALID_EXPECTED" >"$temp_root/invalid-expected.out" 2>&1
  code=$?
  set -e
  [[ $code -ne 0 ]]
  assert_status "$temp_root/invalid-expected.report.json" invalid_args
done

set +e
bash "$wrapper" --report-path "$temp_root/allowed-missing-manifest.report.json" --log-path "$temp_root/allowed-missing-manifest.jsonl" --allowed-files README.md --skip-verify "ALLOWED_NO_MANIFEST" >"$temp_root/allowed-missing-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- "--allowed-files requires --run-id and --record-run-manifest" "$temp_root/allowed-missing-manifest.out"
assert_status "$temp_root/allowed-missing-manifest.report.json" invalid_args

set +e
bash "$wrapper" --report-path "$temp_root/expected-missing-manifest.report.json" --log-path "$temp_root/expected-missing-manifest.jsonl" --expected-changed-files README.md --skip-verify "EXPECTED_NO_MANIFEST" >"$temp_root/expected-missing-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- "--expected-changed-files requires --run-id and --record-run-manifest" "$temp_root/expected-missing-manifest.out"
assert_status "$temp_root/expected-missing-manifest.report.json" invalid_args

set +e
bash "$wrapper" --report-path "$temp_root/missing-run-id.report.json" --log-path "$temp_root/missing-run-id.jsonl" --record-run-manifest --skip-verify "RUN_MANIFEST_NO_RUN_ID" >"$temp_root/missing-run-id.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- "--record-run-manifest requires --run-id" "$temp_root/missing-run-id.out"
assert_status "$temp_root/missing-run-id.report.json" invalid_args

set +e
bash "$wrapper" --report-path "$temp_root/invalid-task-type.report.json" --log-path "$temp_root/invalid-task-type.jsonl" --task-type invalid --skip-verify "INVALID_TASK_TYPE" >"$temp_root/invalid-task-type.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Invalid --task-type" "$temp_root/invalid-task-type.out"
assert_status "$temp_root/invalid-task-type.report.json" invalid_args

set +e
bash "$wrapper" --report-path "$temp_root/invalid-workflow-level.report.json" --log-path "$temp_root/invalid-workflow-level.jsonl" --workflow-level invalid --skip-verify "INVALID_WORKFLOW_LEVEL" >"$temp_root/invalid-workflow-level.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Invalid --workflow-level" "$temp_root/invalid-workflow-level.out"
assert_status "$temp_root/invalid-workflow-level.report.json" invalid_args

invalid_manifest_run_id="20260420-020204-JST"
set +e
bash "$wrapper" --run-id "$invalid_manifest_run_id" --record-run-manifest --task-type invalid --skip-verify "INVALID_TASK_TYPE_WITH_MANIFEST" >"$temp_root/invalid-task-type-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Invalid --task-type" "$temp_root/invalid-task-type-manifest.out"
[[ ! -f "$template_root/.codex/runs/$invalid_manifest_run_id/run.json" ]]

invalid_manifest_run_id="20260420-020205-JST"
set +e
bash "$wrapper" --run-id "$invalid_manifest_run_id" --record-run-manifest --workflow-level invalid --skip-verify "INVALID_WORKFLOW_LEVEL_WITH_MANIFEST" >"$temp_root/invalid-workflow-level-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Invalid --workflow-level" "$temp_root/invalid-workflow-level-manifest.out"
[[ ! -f "$template_root/.codex/runs/$invalid_manifest_run_id/run.json" ]]

set +e
bash "$wrapper" --report-path "$temp_root/invalid-run.report.json" --log-path "$temp_root/invalid-run.jsonl" --run-id "../escape" --skip-verify "RUN_ID_BAD" >"$temp_root/invalid-run.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Invalid --run-id" "$temp_root/invalid-run.out"
assert_status "$temp_root/invalid-run.report.json" invalid_args

set +e
bash "$wrapper" --report-path "$temp_root/blocked.report.json" --log-path "$temp_root/blocked.jsonl" --dangerously-bypass-approvals-and-sandbox >"$temp_root/blocked.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Unsafe Codex argument blocked" "$temp_root/blocked.out"
assert_status "$temp_root/blocked.report.json" blocked_args

set +e
bash "$wrapper" --report-path "$temp_root/fail.report.json" --log-path "$temp_root/fail.jsonl" --skip-verify "FAIL_CODEX" >"$temp_root/fail.out" 2>&1
code=$?
set -e
[[ $code -eq 9 ]]
assert_status "$temp_root/fail.report.json" codex_failed

set +e
bash "$wrapper" --report-path "$temp_root/verify-fail.report.json" --log-path "$temp_root/verify-fail.jsonl" --verify-command "sh -lc 'exit 7'" "VERIFY_FAIL" >"$temp_root/verify-fail.out" 2>&1
code=$?
set -e
[[ $code -eq 7 ]]
assert_status "$temp_root/verify-fail.report.json" verify_failed

bash "$wrapper" --report-path "$temp_root/verify-bash.report.json" --log-path "$temp_root/verify-bash.jsonl" --verify-command "printf 'verify-ok\n'" "VERIFY_BASH"
assert_status "$temp_root/verify-bash.report.json" ok

set +e
bash "$wrapper" --output-file "$temp_root/schema-fail.json" --output-schema "$temp_root/schema.json" --report-path "$temp_root/schema-fail.report.json" --log-path "$temp_root/schema-fail.jsonl" --skip-verify "BAD_SCHEMA" >"$temp_root/schema-fail.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
assert_status "$temp_root/schema-fail.report.json" invalid_output

schema_fail_run_id="20260420-020206-JST"
set +e
bash "$wrapper" --run-id "$schema_fail_run_id" --record-run-manifest --output-schema "$temp_root/schema.json" --skip-verify "BAD_SCHEMA" >"$temp_root/schema-fail-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
assert_manifest_validation_failed "$template_root/.codex/runs/$schema_fail_run_id/run.json"

set +e
bash "$wrapper" --output-file "$temp_root/unsupported-out.json" --output-schema "$temp_root/unsupported-schema.json" --report-path "$temp_root/unsupported.report.json" --log-path "$temp_root/unsupported.jsonl" --skip-verify "SCHEMA_OK" >"$temp_root/unsupported-schema.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
assert_status "$temp_root/unsupported.report.json" invalid_output

set +e
bash "$wrapper" --runtime docker-sandbox --report-path "$temp_root/docker-missing.report.json" --log-path "$temp_root/docker-missing.jsonl" --skip-verify "DOCKER_MISSING" >"$temp_root/docker-missing.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
assert_status "$temp_root/docker-missing.report.json" docker_unavailable

if [[ "${CODEX_ENABLE_DOCKER_SANDBOX_TEST:-0}" == "1" ]]; then
  export CODEX_DOCKER_BIN="$fake_docker"
  export CODEX_DOCKER_IMAGE="fake-image"
  docker_run_id="20260420-020202-JST"
  bash "$sandbox_wrapper" --run-id "$docker_run_id" --output-schema "$temp_root/schema.json" --verify-command "true" "DOCKER_OK"
  docker_report="$(find "$template_root/.codex/runs/$docker_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
  assert_status "$docker_report" ok
else
  echo "SKIP: docker sandbox smoke (set CODEX_ENABLE_DOCKER_SANDBOX_TEST=1 to enable)"
fi

echo "PASS: Codex task harness checks"
