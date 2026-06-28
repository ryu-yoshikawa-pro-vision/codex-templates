#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
template_source_root="$source_repo_root/template"
fake_codex="$source_repo_root/tests/fixtures/fake-codex.sh"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-scope-test.XXXXXX")"
template_root="$temp_root/template"
wrapper="$template_root/scripts/codex-task.sh"
python_cmd="python3"
if ! command -v python3 >/dev/null 2>&1; then
  python_cmd="python"
fi

cleanup() {
  case "$temp_root" in
    "${TMPDIR:-/tmp}"/codex-scope-test.*)
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

restore_file() {
  local rel="$1"
  mkdir -p "$(dirname "$template_root/$rel")"
  if [[ -f "$template_source_root/$rel" ]]; then
    cp "$template_source_root/$rel" "$template_root/$rel"
  else
    rm -f "$template_root/$rel"
  fi
}

assert_status() {
  local path="$1"
  local expected="$2"
  "$python_cmd" - "$path" "$expected" <<'PY'
import json
import sys
path, expected = sys.argv[1:3]
data = json.load(open(path, encoding="utf-8"))
if data["status"] != expected:
    raise SystemExit(f"expected status {expected}, got {data['status']}")
PY
}

assert_manifest_state() {
  local path="$1"
  local expected_run_status="$2"
  local expected_validation_status="$3"
  local expected_scope_violation="$4"
  local expected_changed_csv="$5"
  "$python_cmd" - "$path" "$expected_run_status" "$expected_validation_status" "$expected_scope_violation" "$expected_changed_csv" <<'PY'
import json
import sys
path, expected_run_status, expected_validation_status, expected_scope_violation, expected_changed_csv = sys.argv[1:6]
data = json.load(open(path, encoding="utf-8"))
if data["status"] != expected_run_status:
    raise SystemExit(f"expected run status {expected_run_status}, got {data['status']}")
if data["validation"]["status"] != expected_validation_status:
    raise SystemExit(f"expected validation status {expected_validation_status}, got {data['validation']['status']}")
expected_scope = expected_scope_violation.lower() == "true"
if data["safety"]["scope_violation"] != expected_scope:
    raise SystemExit(f"expected scope_violation {expected_scope}, got {data['safety']['scope_violation']}")
expected_changed = [] if expected_changed_csv == "" else expected_changed_csv.split(",")
if data["changed_files"] != expected_changed:
    raise SystemExit(f"expected changed_files {expected_changed}, got {data['changed_files']}")
PY
}

assert_manifest_warning() {
  local path="$1"
  local expected_type="$2"
  local expected_path="$3"
  "$python_cmd" - "$path" "$expected_type" "$expected_path" <<'PY'
import json
import sys
path, expected_type, expected_path = sys.argv[1:4]
data = json.load(open(path, encoding="utf-8"))
warnings = data["validation"]["warnings"]
if not warnings:
    raise SystemExit("expected at least one warning")
match = [warning for warning in warnings if warning["type"] == expected_type and warning["path"] == expected_path]
if not match:
    raise SystemExit(f"expected warning {expected_type}/{expected_path}, got {warnings}")
PY
}

export CODEX_BIN="$fake_codex"
cd "$template_root"

allowed_dir_run_id="20260628-112100-JST"
FAKE_CODEX_WRITE_FILES="docs/reference/codex-implementation-harness.md" bash "$wrapper" --run-id "$allowed_dir_run_id" --record-run-manifest --allowed-dirs docs/reference --skip-verify "ALLOWED_DIR_OK"
allowed_dir_report="$(find ".codex/runs/$allowed_dir_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$allowed_dir_report" verify_skipped
assert_manifest_state ".codex/runs/$allowed_dir_run_id/run.json" completed skipped false "docs/reference/codex-implementation-harness.md"
restore_file "docs/reference/codex-implementation-harness.md"

allowed_dir_violation_run_id="20260628-112101-JST"
set +e
FAKE_CODEX_WRITE_FILES="docs/reference-guide.md" bash "$wrapper" --run-id "$allowed_dir_violation_run_id" --record-run-manifest --allowed-dirs docs/reference --skip-verify "ALLOWED_DIR_VIOLATION" >"$temp_root/allowed-dir-violation.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
allowed_dir_violation_report="$(find ".codex/runs/$allowed_dir_violation_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$allowed_dir_violation_report" scope_violation
assert_manifest_state ".codex/runs/$allowed_dir_violation_run_id/run.json" failed blocked true "docs/reference-guide.md"
restore_file "docs/reference-guide.md"

allowed_glob_run_id="20260628-112102-JST"
FAKE_CODEX_WRITE_FILES="scripts/codex-task.sh" bash "$wrapper" --run-id "$allowed_glob_run_id" --record-run-manifest --allowed-globs "scripts/codex-task.*" --skip-verify "ALLOWED_GLOB_OK"
allowed_glob_report="$(find ".codex/runs/$allowed_glob_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$allowed_glob_report" verify_skipped
assert_manifest_state ".codex/runs/$allowed_glob_run_id/run.json" completed skipped false "scripts/codex-task.sh"
restore_file "scripts/codex-task.sh"

expected_warn_run_id="20260628-112103-JST"
bash "$wrapper" --run-id "$expected_warn_run_id" --record-run-manifest --expected-changed-files README.md --expected-missing warn --skip-verify "EXPECTED_WARN"
expected_warn_report="$(find ".codex/runs/$expected_warn_run_id/reports" -type f -name 'codex-task-*.report.json' | sort | tail -n 1)"
assert_status "$expected_warn_report" verify_skipped
assert_manifest_state ".codex/runs/$expected_warn_run_id/run.json" completed passed_with_warnings false ""
assert_manifest_warning ".codex/runs/$expected_warn_run_id/run.json" expected_changed_file_missing README.md

task_type_run_id="20260628-112104-JST"
bash "$wrapper" --run-id "$task_type_run_id" --record-run-manifest --task-type harness-improvement --skip-verify "HARNESS_TASK_TYPE"
"$python_cmd" - ".codex/runs/$task_type_run_id/run.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data["task_type"] != "harness-improvement":
    raise SystemExit(f"expected harness-improvement task type, got {data['task_type']}")
PY

for invalid_value in "../outside" "/tmp/outside"; do
  set +e
  bash "$wrapper" --report-path "$temp_root/invalid-dir.report.json" --log-path "$temp_root/invalid-dir.jsonl" --allowed-dirs "$invalid_value" --skip-verify "INVALID_DIR" >"$temp_root/invalid-dir.out" 2>&1
  code=$?
  set -e
  [[ $code -ne 0 ]]
  assert_status "$temp_root/invalid-dir.report.json" invalid_args
done

for invalid_value in "../*.md" "/tmp/*.md"; do
  set +e
  bash "$wrapper" --report-path "$temp_root/invalid-glob.report.json" --log-path "$temp_root/invalid-glob.jsonl" --allowed-globs "$invalid_value" --skip-verify "INVALID_GLOB" >"$temp_root/invalid-glob.out" 2>&1
  code=$?
  set -e
  [[ $code -ne 0 ]]
  assert_status "$temp_root/invalid-glob.report.json" invalid_args
done

set +e
bash "$wrapper" --report-path "$temp_root/allowed-dir-missing-manifest.report.json" --log-path "$temp_root/allowed-dir-missing-manifest.jsonl" --allowed-dirs docs/reference --skip-verify "ALLOWED_DIR_NO_MANIFEST" >"$temp_root/allowed-dir-missing-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "scope options require --run-id and --record-run-manifest" "$temp_root/allowed-dir-missing-manifest.out"
assert_status "$temp_root/allowed-dir-missing-manifest.report.json" invalid_args

set +e
bash "$wrapper" --report-path "$temp_root/allowed-glob-missing-manifest.report.json" --log-path "$temp_root/allowed-glob-missing-manifest.jsonl" --allowed-globs "scripts/codex-task.*" --skip-verify "ALLOWED_GLOB_NO_MANIFEST" >"$temp_root/allowed-glob-missing-manifest.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "scope options require --run-id and --record-run-manifest" "$temp_root/allowed-glob-missing-manifest.out"
assert_status "$temp_root/allowed-glob-missing-manifest.report.json" invalid_args

set +e
bash "$wrapper" --report-path "$temp_root/invalid-expected-missing.report.json" --log-path "$temp_root/invalid-expected-missing.jsonl" --expected-missing maybe --skip-verify "INVALID_EXPECTED_MISSING" >"$temp_root/invalid-expected-missing.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- "--expected-missing must be warn or fail" "$temp_root/invalid-expected-missing.out"
assert_status "$temp_root/invalid-expected-missing.report.json" invalid_args

echo "PASS: change scope policy bash checks"
