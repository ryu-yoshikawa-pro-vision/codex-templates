#!/usr/bin/env bash
set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

emit_error() {
  printf '%s\n' "$1" >&2
  exit 0
}

observation_log="${CODEX_OBSERVATION_LOG:-$repo_root/.codex/observations/hooks.jsonl}"
event_name="${CODEX_HOOK_EVENT:-ObservationError}"
tool_name="${CODEX_HOOK_TOOL_NAME:-}"
tool_operation="${CODEX_HOOK_TOOL_OPERATION:-}"
tool_target="${CODEX_HOOK_TOOL_TARGET:-}"
input_summary="${CODEX_HOOK_INPUT_SUMMARY:-Hook event observed without an explicit input summary.}"
run_id="${CODEX_RUN_ID:-}"
source_name="${CODEX_HOOK_SOURCE:-codex_hook}"
severity="${CODEX_HOOK_SEVERITY:-info}"
decision_reason="${CODEX_HOOK_DECISION_REASON:-optional observation hook recorded the event}"
cwd_value="${CODEX_HOOK_CWD:-$(pwd 2>/dev/null || printf '')}"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
event_stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)"
event_id="${event_stamp}-$$"

if [[ -z "$input_summary" ]]; then
  input_summary="Hook event observed without an explicit input summary."
fi

if [[ -n "$run_id" ]]; then
  run_id_json="\"$(json_escape "$run_id")\""
else
  run_id_json="null"
fi

if [[ -n "$cwd_value" ]]; then
  cwd_json="\"$(json_escape "$cwd_value")\""
else
  cwd_json="null"
fi

if [[ -n "$tool_name" || -n "$tool_operation" || -n "$tool_target" ]]; then
  tool_json="{\"name\":$(if [[ -n "$tool_name" ]]; then printf '"%s"' "$(json_escape "$tool_name")"; else printf 'null'; fi),\"operation\":$(if [[ -n "$tool_operation" ]]; then printf '"%s"' "$(json_escape "$tool_operation")"; else printf 'null'; fi),\"target\":$(if [[ -n "$tool_target" ]]; then printf '"%s"' "$(json_escape "$tool_target")"; else printf 'null'; fi)}"
else
  tool_json="null"
fi

log_dir="$(dirname "$observation_log")"
mkdir -p "$log_dir" 2>/dev/null || emit_error "Observation hook: failed to create log directory"

payload="$(cat <<EOF
{"schema_version":1,"event_id":"$(json_escape "$event_id")","run_id":$run_id_json,"timestamp":"$(json_escape "$timestamp")","source":"$(json_escape "$source_name")","event":"$(json_escape "$event_name")","severity":"$(json_escape "$severity")","blocking":false,"tool":$tool_json,"cwd":$cwd_json,"input_summary":"$(json_escape "$input_summary")","decision":{"action":"observe","reason":"$(json_escape "$decision_reason")"},"evidence":[],"metadata":{"hook":"observe.sh"}}
EOF
)"

printf '%s\n' "$payload" >> "$observation_log" 2>/dev/null || emit_error "Observation hook: failed to append event"
exit 0
