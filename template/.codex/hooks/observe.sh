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

normalize_enum_value() {
  local raw="$1"
  local default_value="$2"
  local fallback_value="$3"
  shift 3

  NORMALIZED_VALUE="$default_value"
  ORIGINAL_VALUE=""

  if [[ -z "${raw//[[:space:]]/}" ]]; then
    return 0
  fi

  local allowed
  for allowed in "$@"; do
    if [[ "$raw" == "$allowed" ]]; then
      NORMALIZED_VALUE="$raw"
      return 0
    fi
  done

  NORMALIZED_VALUE="$fallback_value"
  ORIGINAL_VALUE="$raw"
}

emit_error() {
  printf '%s\n' "$1" >&2
  exit 0
}

observation_log="${CODEX_OBSERVATION_LOG:-$repo_root/.codex/observations/hooks.jsonl}"
tool_name="${CODEX_HOOK_TOOL_NAME:-}"
tool_operation="${CODEX_HOOK_TOOL_OPERATION:-}"
tool_target="${CODEX_HOOK_TOOL_TARGET:-}"
input_summary="${CODEX_HOOK_INPUT_SUMMARY:-}"
run_id="${CODEX_RUN_ID:-}"
decision_reason="${CODEX_HOOK_DECISION_REASON:-optional observation hook recorded the event}"
cwd_value="${CODEX_HOOK_CWD:-$(pwd 2>/dev/null || printf '')}"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
event_stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)"
event_id="${event_stamp}-$$"

normalize_enum_value "${CODEX_HOOK_EVENT:-}" "ObservationError" "ObservationError" \
  "PreToolUse" "PostToolUse" "SubagentStart" "SubagentStop" "Stop" "WrapperStart" "WrapperStop" "SafetyBlocked" "ObservationError"
event_name="$NORMALIZED_VALUE"
original_event="$ORIGINAL_VALUE"

normalize_enum_value "${CODEX_HOOK_SOURCE:-}" "codex_hook" "unknown" \
  "codex_hook" "codex_task" "codex_safe" "subagent" "manual" "unknown"
source_name="$NORMALIZED_VALUE"
original_source="$ORIGINAL_VALUE"

normalize_enum_value "${CODEX_HOOK_SEVERITY:-}" "info" "warning" \
  "debug" "info" "warning" "error" "critical"
severity="$NORMALIZED_VALUE"
original_severity="$ORIGINAL_VALUE"

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

if [[ -n "${input_summary//[[:space:]]/}" ]]; then
  input_summary_json="\"$(json_escape "$input_summary")\""
else
  input_summary_json="null"
fi

metadata_json='{"hook":"observe.sh"'
if [[ -n "$original_event" ]]; then
  metadata_json+=",\"original_event\":\"$(json_escape "$original_event")\""
fi
if [[ -n "$original_source" ]]; then
  metadata_json+=",\"original_source\":\"$(json_escape "$original_source")\""
fi
if [[ -n "$original_severity" ]]; then
  metadata_json+=",\"original_severity\":\"$(json_escape "$original_severity")\""
fi
metadata_json+='}'

log_dir="$(dirname "$observation_log")"
mkdir -p "$log_dir" 2>/dev/null || emit_error "Observation hook: failed to create log directory"

payload="$(cat <<EOF
{"schema_version":1,"event_id":"$(json_escape "$event_id")","run_id":$run_id_json,"timestamp":"$(json_escape "$timestamp")","source":"$(json_escape "$source_name")","event":"$(json_escape "$event_name")","severity":"$(json_escape "$severity")","blocking":false,"tool":$tool_json,"cwd":$cwd_json,"input_summary":$input_summary_json,"decision":{"action":"observe","reason":"$(json_escape "$decision_reason")"},"evidence":[],"metadata":$metadata_json}
EOF
)"

printf '%s\n' "$payload" >> "$observation_log" 2>/dev/null || emit_error "Observation hook: failed to append event"
exit 0
