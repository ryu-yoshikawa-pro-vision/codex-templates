#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
template_root="$source_repo_root/template"
wrapper="$template_root/scripts/codex-task.sh"
sandbox_wrapper="$template_root/scripts/codex-sandbox.sh"
fake_codex="$source_repo_root/tests/fixtures/fake-codex.sh"
fake_docker="$source_repo_root/tests/fixtures/fake-docker.sh"
temp_root="$(mktemp -d)"
python_cmd="python3"
if ! command -v python3 >/dev/null 2>&1; then
  python_cmd="python"
fi

cleanup() {
  rm -rf "$temp_root"
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
required = ["runtime", "preset", "prompt_source", "output_file", "output_schema", "log_path", "codex_exit_code", "verify_exit_code", "status"]
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

bash "$wrapper" --output-file "$temp_root/ok.json" --output-schema "$temp_root/schema.json" --report-path "$temp_root/ok.report.json" --verify-command "true" "SCHEMA_OK"
assert_status "$temp_root/ok.report.json" ok

bash "$wrapper" --preset readonly --output-file "$temp_root/readonly.json" --report-path "$temp_root/readonly.report.json" --skip-verify "READONLY_OK"
assert_status "$temp_root/readonly.report.json" verify_skipped

set +e
bash "$wrapper" --report-path "$temp_root/blocked.report.json" --dangerously-bypass-approvals-and-sandbox >/tmp/codex-task-blocked.out 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q "Unsafe Codex argument blocked" /tmp/codex-task-blocked.out
assert_status "$temp_root/blocked.report.json" blocked_args
rm -f /tmp/codex-task-blocked.out

set +e
bash "$wrapper" --report-path "$temp_root/fail.report.json" --skip-verify "FAIL_CODEX" >/tmp/codex-task-fail.out 2>&1
code=$?
set -e
[[ $code -eq 9 ]]
assert_status "$temp_root/fail.report.json" codex_failed
rm -f /tmp/codex-task-fail.out

set +e
bash "$wrapper" --report-path "$temp_root/verify-fail.report.json" --verify-command "sh -lc 'exit 7'" "VERIFY_FAIL" >/tmp/codex-task-verify.out 2>&1
code=$?
set -e
[[ $code -eq 7 ]]
assert_status "$temp_root/verify-fail.report.json" verify_failed
rm -f /tmp/codex-task-verify.out

bash "$wrapper" --report-path "$temp_root/verify-bash.report.json" --verify-command "printf 'verify-ok\n'" "VERIFY_BASH"
assert_status "$temp_root/verify-bash.report.json" ok

set +e
bash "$wrapper" --output-file "$temp_root/schema-fail.json" --output-schema "$temp_root/schema.json" --report-path "$temp_root/schema-fail.report.json" --skip-verify "BAD_SCHEMA" >/tmp/codex-task-schema.out 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
assert_status "$temp_root/schema-fail.report.json" invalid_output
rm -f /tmp/codex-task-schema.out

set +e
bash "$wrapper" --output-file "$temp_root/unsupported-out.json" --output-schema "$temp_root/unsupported-schema.json" --report-path "$temp_root/unsupported.report.json" --skip-verify "SCHEMA_OK" >/tmp/codex-task-unsupported-schema.out 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
assert_status "$temp_root/unsupported.report.json" invalid_output
rm -f /tmp/codex-task-unsupported-schema.out

set +e
bash "$wrapper" --runtime docker-sandbox --report-path "$temp_root/docker-missing.report.json" --skip-verify "DOCKER_MISSING" >/tmp/codex-task-docker-missing.out 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
assert_status "$temp_root/docker-missing.report.json" docker_unavailable
rm -f /tmp/codex-task-docker-missing.out

if [[ "${CODEX_ENABLE_DOCKER_SANDBOX_TEST:-0}" == "1" ]]; then
  export CODEX_DOCKER_BIN="$fake_docker"
  export CODEX_DOCKER_IMAGE="fake-image"
  bash "$sandbox_wrapper" --output-file ".codex/artifacts/docker-test-output.json" --output-schema "$temp_root/schema.json" --report-path ".codex/reports/docker-test-report.json" --verify-command "true" "DOCKER_OK"
  assert_status "$template_root/.codex/reports/docker-test-report.json" ok
  rm -f "$template_root/.codex/artifacts/docker-test-output.json" "$template_root/.codex/reports/docker-test-report.json"
else
  echo "SKIP: docker sandbox smoke (set CODEX_ENABLE_DOCKER_SANDBOX_TEST=1 to enable)"
fi

echo "PASS: Codex task harness checks"
