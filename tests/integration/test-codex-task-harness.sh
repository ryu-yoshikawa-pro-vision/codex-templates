#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
template_root="$source_repo_root/template"
wrapper="$template_root/scripts/codex-task.sh"
sandbox_wrapper="$template_root/scripts/codex-sandbox.sh"
fake_codex="$source_repo_root/tests/fixtures/fake-codex.sh"
fake_docker="$source_repo_root/tests/fixtures/fake-docker.sh"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-task-test.XXXXXX")"
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
