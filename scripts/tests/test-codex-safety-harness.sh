#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
wrapper="$repo_root/scripts/codex-safe.sh"

rule_args=(
  --rules "$repo_root/.codex/rules/10-readonly-allow.rules"
  --rules "$repo_root/.codex/rules/20-risky-prompt.rules"
  --rules "$repo_root/.codex/rules/30-destructive-forbidden.rules"
)

decision_from_json() {
  local output="$1"
  local decision
  decision="${output##*\"decision\":\"}"
  decision="${decision%%\"*}"
  [[ -n "$decision" && "$decision" != "$output" ]] || {
    echo "Unable to parse decision from: $output" >&2
    return 1
  }
  printf '%s' "$decision"
}

assert_decision() {
  local expected="$1"
  shift
  local output
  output="$(codex execpolicy check "${rule_args[@]}" -- "$@")"
  local actual
  actual="$(decision_from_json "$output")"
  if [[ "$actual" != "$expected" ]]; then
    echo "Decision mismatch for '$*': expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_wrapper_blocked() {
  local out
  set +e
  out="$($wrapper --print-command "$@" 2>&1)"
  local code=$?
  set -e
  if [[ $code -eq 0 ]]; then
    echo "Wrapper unexpectedly allowed args: $*" >&2
    exit 1
  fi
  if [[ "$out" != *"Unsafe Codex argument blocked"* ]]; then
    echo "Wrapper failed without expected safety message: $out" >&2
    exit 1
  fi
}

assert_wrapper_preview_ok() {
  "$wrapper" --print-command "$@" >/tmp/codex-safe-preview.json
  rm -f /tmp/codex-safe-preview.json
}

assert_decision allow git status
assert_decision prompt git add .
assert_decision forbidden git reset --hard HEAD~1
assert_decision prompt docker ps
assert_decision forbidden terraform destroy -auto-approve

"$wrapper" --preflight-only >/tmp/codex-safe-preflight.log
rm -f /tmp/codex-safe-preflight.log

assert_wrapper_preview_ok exec --help
assert_wrapper_preview_ok --preset readonly exec --help
assert_wrapper_blocked --dangerously-bypass-approvals-and-sandbox
assert_wrapper_blocked --config sandbox_mode="danger-full-access"
assert_wrapper_blocked --config=sandbox_mode="danger-full-access"
assert_wrapper_blocked -c sandbox_mode="danger-full-access"
assert_wrapper_blocked --add-dir /tmp
assert_wrapper_blocked -C /tmp
assert_wrapper_blocked --search
assert_wrapper_blocked -a never
assert_wrapper_blocked -s danger-full-access
assert_wrapper_preview_ok --allow-search exec --help

log_path="$(mktemp)"
"$wrapper" --print-command --log-path "$log_path" exec --help >/tmp/codex-safe-log-preview.json
rm -f /tmp/codex-safe-log-preview.json
if ! grep -q '"event":"wrapper_start"' "$log_path"; then
  echo "Missing wrapper_start event in log" >&2
  rm -f "$log_path"
  exit 1
fi
if ! grep -q '"event":"preflight_ok"' "$log_path"; then
  echo "Missing preflight_ok event in log" >&2
  rm -f "$log_path"
  exit 1
fi
if ! grep -q '"event":"print_command"' "$log_path"; then
  echo "Missing print_command event in log" >&2
  rm -f "$log_path"
  exit 1
fi
rm -f "$log_path"

failure_log="$(mktemp)"
set +e
"$wrapper" --log-path "$failure_log" exec --definitely-invalid-flag >/tmp/codex-safe-failure-case.out 2>&1
failure_code=$?
set -e
rm -f /tmp/codex-safe-failure-case.out
if [[ $failure_code -eq 0 ]]; then
  echo "Expected wrapper/codex to fail for invalid codex arg" >&2
  rm -f "$failure_log"
  exit 1
fi
if ! grep -q '"event":"codex_exec_exit"' "$failure_log"; then
  echo "Missing codex_exec_exit event for failed codex execution" >&2
  rm -f "$failure_log"
  exit 1
fi
rm -f "$failure_log"

echo "PASS: Bash Codex safety harness checks"
