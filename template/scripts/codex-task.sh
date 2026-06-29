#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
artifacts_dir="$repo_root/.codex/artifacts"
reports_dir="$repo_root/.codex/reports"
logs_dir="$repo_root/.codex/logs"
mkdir -p "$artifacts_dir" "$reports_dir" "$logs_dir"

preset="safe"
runtime="host"
task_type="implementation"
workflow_level="standard"
record_run_manifest=0
evaluation_template=0
require_evaluation=0
require_clean_git=0
require_run_id=0
prompt_file=""
output_schema=""
verify_command=""
max_iterations=""
max_iterations_provided=0
allow_search=0
skip_preflight=0
skip_verify=0
explicit_log_path=""
explicit_output_file=0
explicit_report_path=0
run_id=""
run_root=""
evaluation_file_path=""
cwd_for_report="$repo_root"
declare -a prompt_parts=()
declare -a allowed_files=()
declare -a allowed_dirs=()
declare -a allowed_globs=()
declare -a expected_changed_files=()
declare -a changed_files=()
declare -a validation_command_names=()
declare -a validation_command_exit_codes=()
declare -a validation_command_statuses=()
declare -a validation_command_evidences=()
declare -a validation_warning_types=()
declare -a validation_warning_paths=()
declare -a validation_warning_messages=()
expected_missing_behavior="fail"

timestamp="$(date +%Y%m%d-%H%M%S)"
output_file="$artifacts_dir/codex-task-${timestamp}.json"
report_path="$reports_dir/codex-task-${timestamp}.report.json"
log_path="$logs_dir/codex-task-${timestamp}.jsonl"

report_status="pending"
run_status="pending"
prompt_source=""
codex_exit_code="null"
verify_exit_code="null"
validation_status="not_run"
manifest_path=""
manifest_started=0
safety_scope_violation=false
evaluation_path=""
primary_failure_category=""

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

join_by() {
  local delimiter="$1"
  shift
  local first=1 item
  for item in "$@"; do
    if (( first )); then
      printf '%s' "$item"
      first=0
    else
      printf '%s%s' "$delimiter" "$item"
    fi
  done
}

json_string_array() {
  local -n _items=$1
  local first=1 item
  printf '['
  for item in "${_items[@]}"; do
    if (( first )); then
      first=0
    else
      printf ', '
    fi
    printf '"%s"' "$(json_escape "$item")"
  done
  printf ']'
}

json_nullable_string() {
  local value="$1"
  if [[ -n "$value" ]]; then
    printf '"%s"' "$(json_escape "$value")"
  else
    printf 'null'
  fi
}

add_validation_command() {
  local command="$1"
  local exit_code="$2"
  local status="$3"
  local evidence="$4"

  validation_command_names+=("$command")
  validation_command_exit_codes+=("$exit_code")
  validation_command_statuses+=("$status")
  validation_command_evidences+=("$evidence")

  case "$status" in
    blocked|failed)
      validation_status="$status"
      ;;
    passed)
      if [[ "$validation_status" == "not_run" || "$validation_status" == "skipped" ]]; then
        validation_status="passed"
      fi
      ;;
    skipped)
      if [[ "$validation_status" == "not_run" ]]; then
        validation_status="skipped"
      fi
      ;;
  esac
}

add_validation_warning() {
  local warning_type="$1"
  local warning_path="$2"
  local warning_message="$3"

  validation_warning_types+=("$warning_type")
  validation_warning_paths+=("$warning_path")
  validation_warning_messages+=("$warning_message")

  if [[ "$validation_status" != "blocked" && "$validation_status" != "failed" ]]; then
    validation_status="passed_with_warnings"
  fi
}

json_validation_commands() {
  local idx first=1
  printf '['
  for idx in "${!validation_command_names[@]}"; do
    if (( first )); then
      first=0
    else
      printf ','
    fi
    printf '\n      {\n'
    printf '        "command": "%s",\n' "$(json_escape "${validation_command_names[$idx]}")"
    printf '        "exit_code": %s,\n' "${validation_command_exit_codes[$idx]}"
    printf '        "status": "%s",\n' "$(json_escape "${validation_command_statuses[$idx]}")"
    printf '        "evidence": "%s"\n' "$(json_escape "${validation_command_evidences[$idx]}")"
    printf '      }'
  done
  if (( ! first )); then
    printf '\n    '
  fi
  printf ']'
}

json_validation_warnings() {
  local idx first=1
  printf '['
  for idx in "${!validation_warning_types[@]}"; do
    if (( first )); then
      first=0
    else
      printf ','
    fi
    printf '\n      {\n'
    printf '        "type": "%s",\n' "$(json_escape "${validation_warning_types[$idx]}")"
    printf '        "path": "%s",\n' "$(json_escape "${validation_warning_paths[$idx]}")"
    printf '        "message": "%s"\n' "$(json_escape "${validation_warning_messages[$idx]}")"
    printf '      }'
  done
  if (( ! first )); then
    printf '\n    '
  fi
  printf ']'
}

ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}

resolve_path() {
  local raw="$1"
  if [[ "$raw" = /* || "$raw" =~ ^[A-Za-z]:[\\/] || "$raw" =~ ^\\\\ ]]; then
    printf '%s' "$raw"
  else
    printf '%s/%s' "$repo_root" "$raw"
  fi
}

python_cmd() {
  local candidate
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return
    fi
  done
  printf ''
}

validate_run_id() {
  [[ -z "$run_id" ]] && return 0
  if [[ ! "$run_id" =~ ^[0-9]{8}-[0-9]{6}-JST$ ]]; then
    fail_with_status "invalid_args" "Invalid --run-id: expected YYYYMMDD-HHMMSS-JST"
  fi
}

normalize_repo_relative_posix_path() {
  local raw="$1"
  raw="${raw//\\//}"
  local -a segments=()
  local segment
  IFS='/' read -r -a raw_segments <<< "$raw"
  for segment in "${raw_segments[@]}"; do
    if [[ -z "$segment" || "$segment" == "." ]]; then
      continue
    fi
    if [[ "$segment" == ".." ]]; then
      if ((${#segments[@]} == 0)); then
        printf ''
        return 1
      fi
      unset 'segments[${#segments[@]}-1]'
      segments=("${segments[@]}")
      continue
    fi
    segments+=("$segment")
  done

  if ((${#segments[@]} == 0)); then
    printf ''
    return 0
  fi

  local normalized
  local old_ifs="$IFS"
  IFS='/'
  normalized="${segments[*]}"
  IFS="$old_ifs"
  printf '%s' "$normalized"
}

sort_unique_array() {
  local -n _target=$1
  if ((${#_target[@]} == 0)); then
    _target=()
    return
  fi
  mapfile -t _target < <(printf '%s\n' "${_target[@]}" | LC_ALL=C sort -u)
}

normalize_scope_path() {
  local raw="$1"
  local option_name="$2"

  if [[ -z "$raw" ]]; then
    fail_with_status "invalid_args" "$option_name requires a non-empty path"
  fi
  if [[ "$raw" == *'*'* || "$raw" == *'?'* || "$raw" == *'['* || "$raw" == *']'* ]]; then
    fail_with_status "invalid_args" "$option_name does not support glob patterns: $raw"
  fi

  local normalized_input="${raw//\\//}"
  if [[ "$normalized_input" == /* || "$normalized_input" =~ ^[A-Za-z]:/ || "$normalized_input" =~ ^// ]]; then
    fail_with_status "invalid_args" "$option_name requires a repo-relative path: $raw"
  fi

  local normalized
  normalized="$(normalize_repo_relative_posix_path "$normalized_input")" || fail_with_status "invalid_args" "$option_name path escapes repo root: $raw"
  if [[ -z "$normalized" ]]; then
    fail_with_status "invalid_args" "$option_name requires a repo-relative file path: $raw"
  fi
  printf '%s' "$normalized"
}

normalize_directory_scope_path() {
  local raw="$1"
  local option_name="$2"
  local trimmed="${raw%/}"
  trimmed="${trimmed%\\}"
  normalize_scope_path "$trimmed" "$option_name"
}

normalize_scope_glob() {
  local raw="$1"
  local option_name="$2"

  if [[ -z "$raw" ]]; then
    fail_with_status "invalid_args" "$option_name requires a non-empty path"
  fi

  local normalized_input="${raw//\\//}"
  if [[ "$normalized_input" == /* || "$normalized_input" =~ ^[A-Za-z]:/ || "$normalized_input" =~ ^// ]]; then
    fail_with_status "invalid_args" "$option_name requires a repo-relative path: $raw"
  fi

  local -a segments=()
  local segment
  IFS='/' read -r -a raw_segments <<< "$normalized_input"
  for segment in "${raw_segments[@]}"; do
    if [[ -z "$segment" || "$segment" == "." ]]; then
      continue
    fi
    if [[ "$segment" == ".." ]]; then
      fail_with_status "invalid_args" "$option_name path escapes repo root: $raw"
    fi
    segments+=("$segment")
  done

  if ((${#segments[@]} == 0)); then
    fail_with_status "invalid_args" "$option_name requires a repo-relative path: $raw"
  fi

  local normalized
  local old_ifs="$IFS"
  IFS='/'
  normalized="${segments[*]}"
  IFS="$old_ifs"
  printf '%s' "$normalized"
}

append_normalized_scope_paths() {
  local -n _target=$1
  local raw_list="$2"
  local option_name="$3"
  local -a items=()
  local item normalized

  IFS=',' read -r -a items <<< "$raw_list"
  for item in "${items[@]}"; do
    normalized="$(normalize_scope_path "$item" "$option_name")"
    _target+=("$normalized")
  done
}

append_normalized_directory_scope_paths() {
  local -n _target=$1
  local raw_list="$2"
  local option_name="$3"
  local -a items=()
  local item normalized

  IFS=',' read -r -a items <<< "$raw_list"
  for item in "${items[@]}"; do
    normalized="$(normalize_directory_scope_path "$item" "$option_name")"
    _target+=("$normalized")
  done
}

append_normalized_scope_globs() {
  local -n _target=$1
  local raw_list="$2"
  local option_name="$3"
  local -a items=()
  local item normalized

  IFS=',' read -r -a items <<< "$raw_list"
  for item in "${items[@]}"; do
    normalized="$(normalize_scope_glob "$item" "$option_name")"
    _target+=("$normalized")
  done
}

glob_pattern_to_regex() {
  local pattern="$1"
  local regex="^"
  local i=0 length=${#pattern} char next
  while (( i < length )); do
    char="${pattern:i:1}"
    case "$char" in
      '*')
        next=""
        if (( i + 1 < length )); then
          next="${pattern:i+1:1}"
        fi
        if [[ "$next" == "*" ]]; then
          regex+=".*"
          ((i += 2))
        else
          regex+="[^/]*"
          ((i += 1))
        fi
        ;;
      '?')
        regex+="[^/]"
        ((i += 1))
        ;;
      '.'|'+'|'('|')'|'{'|'}'|'['|']'|'^'|'$'|'|'|'\\')
        regex+="\\$char"
        ((i += 1))
        ;;
      *)
        regex+="$char"
        ((i += 1))
        ;;
    esac
  done
  regex+="$"
  printf '%s' "$regex"
}

path_matches_allowed_dir() {
  local path="$1"
  local allowed_dir="$2"
  [[ "$path" == "$allowed_dir" || "$path" == "$allowed_dir/"* ]]
}

path_matches_allowed_glob() {
  local path="$1"
  local pattern="$2"
  local regex
  regex="$(glob_pattern_to_regex "$pattern")"
  [[ "$path" =~ $regex ]]
}

path_matches_allowed_scope() {
  local path="$1"
  local allowed
  for allowed in "${allowed_files[@]}"; do
    [[ "$path" == "$allowed" ]] && return 0
  done
  for allowed in "${allowed_dirs[@]}"; do
    path_matches_allowed_dir "$path" "$allowed" && return 0
  done
  for allowed in "${allowed_globs[@]}"; do
    path_matches_allowed_glob "$path" "$allowed" && return 0
  done
  return 1
}

normalized_path() {
  local py
  py="$(python_cmd)"
  if [[ -z "$py" ]]; then
    printf '%s' "$1" | tr '\\' '/'
    return
  fi
  "$py" -c 'import os,sys; print(os.path.realpath(sys.argv[1]).replace("\\", "/"))' "$1"
}

git_branch() {
  git -C "$repo_root" branch --show-current 2>/dev/null || true
}

git_dirty() {
  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'false'
    return
  fi
  if ! git -C "$repo_root" diff --quiet --ignore-submodules -- 2>/dev/null; then
    printf 'true'
    return
  fi
  if ! git -C "$repo_root" diff --cached --quiet --ignore-submodules -- 2>/dev/null; then
    printf 'true'
    return
  fi
  if [[ -n "$(git -C "$repo_root" ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    printf 'true'
    return
  fi
  printf 'false'
}

to_repo_relative_path() {
  local candidate="$1"
  local normalized_candidate normalized_root
  normalized_candidate="$(normalized_path "$candidate")"
  normalized_root="$(normalized_path "$repo_root")"
  if [[ "$normalized_candidate" == "$normalized_root" ]]; then
    printf '.'
    return
  fi
  if [[ "$normalized_candidate" == "$normalized_root/"* ]]; then
    printf '%s' "${normalized_candidate#"$normalized_root"/}" | tr '\\' '/'
    return
  fi
  printf '%s' "$candidate" | tr '\\' '/'
}

write_run_manifest() {
  (( record_run_manifest )) || return 0
  (( manifest_started )) || return 0
  [[ -n "$manifest_path" ]] || return 0

  local branch report_ref network_enabled validation_commands_json validation_warnings_json changed_files_json py manifest_json
  branch="$(git_branch)"
  report_ref="$(to_repo_relative_path "$report_path")"
  network_enabled=false
  if [[ "$preset" == "auto-net" ]] || (( allow_search )); then
    network_enabled=true
  fi
  changed_files_json="$(json_string_array changed_files)"
  validation_commands_json="$(json_validation_commands)"
  validation_warnings_json="$(json_validation_warnings)"
  py="$(python_cmd)"

  ensure_parent_dir "$manifest_path"
  manifest_json="$(cat <<EOF
{
  "schema_version": 1,
  "run_id": "$(json_escape "$run_id")",
  "task_type": "$(json_escape "$task_type")",
  "workflow_level": "$(json_escape "$workflow_level")",
  "preset": "$(json_escape "$preset")",
  "runtime": "$(json_escape "$runtime")",
  "agents_used": [],
  "repo": null,
  "branch": $(if [[ -n "$branch" ]]; then printf '"%s"' "$(json_escape "$branch")"; else printf 'null'; fi),
  "base_branch": null,
  "codex_task_reports": [
    "$(json_escape "$report_ref")"
  ],
  "changed_files": $changed_files_json,
  "validation": {
    "status": "$(json_escape "$validation_status")",
    "commands": $validation_commands_json,
    "warnings": $validation_warnings_json
  },
  "safety": {
    "network": $network_enabled,
    "delete_attempt_blocked": false,
    "git_mutation_attempt_blocked": false,
    "scope_violation": $safety_scope_violation
  },
  "artifact_summary": {
    "codex_task_report_count": 0,
    "hook_event_count": 0,
    "subagent_run_count": 0,
    "evaluation_present": false
  },
  "hook_observations": {
    "log_paths": [],
    "event_counts": {},
    "blocking_event_count": 0,
    "safety_blocked_count": 0,
    "observation_error_count": 0
  },
  "subagents": {
    "records": [],
    "summary": {
      "total": 0,
      "read_only": 0,
      "writable": 0,
      "scope_violations": 0,
      "used_in_final_plan": 0
    }
  },
  "evaluation_path": $(json_nullable_string "$evaluation_path"),
  "status": "$(json_escape "$run_status")",
  "primary_failure_category": $(json_nullable_string "$primary_failure_category")
}
EOF
)"

  if [[ -n "$py" && -f "$manifest_path" ]]; then
    manifest_json="$(
      CODEX_BASE_MANIFEST_JSON="$manifest_json" "$py" - "$manifest_path" <<'PY'
import json
import os
import sys
from pathlib import Path

current = json.loads(os.environ["CODEX_BASE_MANIFEST_JSON"])
existing_path = Path(sys.argv[1])
try:
    existing = json.loads(existing_path.read_text(encoding="utf-8"))
except Exception:
    existing = {}


def uniq(values):
    result = []
    seen = set()
    for value in values:
        marker = json.dumps(value, sort_keys=True, ensure_ascii=True)
        if marker in seen:
            continue
        seen.add(marker)
        result.append(value)
    return result


current["agents_used"] = uniq(existing.get("agents_used", []) + current.get("agents_used", []))
current["codex_task_reports"] = uniq(existing.get("codex_task_reports", []) + current.get("codex_task_reports", []))
current["changed_files"] = uniq(existing.get("changed_files", []) + current.get("changed_files", []))

current_validation = current.get("validation", {})
existing_validation = existing.get("validation", {})
current_validation["commands"] = uniq(existing_validation.get("commands", []) + current_validation.get("commands", []))
current_validation["warnings"] = uniq(existing_validation.get("warnings", []) + current_validation.get("warnings", []))
current["validation"] = current_validation

current_safety = current.get("safety", {})
existing_safety = existing.get("safety", {})
for key in ("network", "delete_attempt_blocked", "git_mutation_attempt_blocked", "scope_violation"):
    current_safety[key] = bool(current_safety.get(key)) or bool(existing_safety.get(key))
current["safety"] = current_safety

if current.get("evaluation_path") is None and existing.get("evaluation_path") is not None:
    current["evaluation_path"] = existing.get("evaluation_path")
if current.get("primary_failure_category") is None and existing.get("primary_failure_category") is not None:
    current["primary_failure_category"] = existing.get("primary_failure_category")
for key in ("artifact_summary", "hook_observations", "subagents"):
    if key in existing:
        current[key] = existing[key]

print(json.dumps(current, ensure_ascii=True, indent=2))
PY
    )"
  fi

  printf '%s\n' "$manifest_json" > "$manifest_path"
  if [[ -n "$py" && -f "$repo_root/scripts/collect-run-artifacts.sh" ]]; then
    bash "$repo_root/scripts/collect-run-artifacts.sh" --run-id "$run_id" --manifest-path "$manifest_path" >/dev/null
  fi
}

collect_changed_files() {
  changed_files=()
  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  local -a entries=()
  local entry status primary secondary normalized
  local i=0
  mapfile -d '' -t entries < <(git -C "$repo_root" status --porcelain=v1 -z --untracked-files=all 2>/dev/null)

  while (( i < ${#entries[@]} )); do
    entry="${entries[$i]}"
    ((i += 1))
    [[ -n "$entry" ]] || continue

    status="${entry:0:2}"
    primary="${entry:3}"
    normalized="$(normalize_repo_relative_posix_path "$primary")" || normalized=""
    if [[ -n "$normalized" && "$normalized" != ".codex/runs" && "$normalized" != .codex/runs/* ]]; then
      changed_files+=("$normalized")
    fi

    if [[ "$status" == *R* || "$status" == *C* ]]; then
      if (( i < ${#entries[@]} )); then
        secondary="${entries[$i]}"
        ((i += 1))
        if [[ "$status" == *R* ]]; then
          normalized="$(normalize_repo_relative_posix_path "$secondary")" || normalized=""
          if [[ -n "$normalized" && "$normalized" != ".codex/runs" && "$normalized" != .codex/runs/* ]]; then
            changed_files+=("$normalized")
          fi
        fi
      fi
    fi
  done

  sort_unique_array changed_files
}

run_scope_checks() {
  local -A changed_lookup=()
  local -a violations=()
  local -a missing_expected=()
  local path evidence warning_message

  if ((${#allowed_files[@]} > 0 || ${#allowed_dirs[@]} > 0 || ${#allowed_globs[@]} > 0)); then
    for path in "${changed_files[@]}"; do
      if ! path_matches_allowed_scope "$path"; then
        violations+=("$path")
      fi
    done
    if ((${#violations[@]} > 0)); then
      sort_unique_array violations
      evidence="changed files outside allowed scope: $(join_by ', ' "${violations[@]}")"
      report_status="scope_violation"
      add_validation_command "change scope check" 1 "blocked" "$evidence"
      run_status="failed"
      safety_scope_violation=true
      write_log "scope_violation" ",\"evidence\":\"$(json_escape "$evidence")\""
      write_report
      write_run_manifest
      exit 1
    fi
  fi

  if ((${#expected_changed_files[@]} > 0)); then
    for path in "${changed_files[@]}"; do
      changed_lookup["$path"]=1
    done
    for path in "${expected_changed_files[@]}"; do
      if [[ -z "${changed_lookup[$path]:-}" ]]; then
        missing_expected+=("$path")
      fi
    done
    if ((${#missing_expected[@]} > 0)); then
      sort_unique_array missing_expected
      evidence="expected files were not changed: $(join_by ', ' "${missing_expected[@]}")"
      if [[ "$expected_missing_behavior" == "fail" ]]; then
        report_status="expected_changes_missing"
        add_validation_command "expected changed files check" 1 "failed" "$evidence"
        run_status="failed"
        safety_scope_violation=false
        write_log "expected_changes_missing" ",\"evidence\":\"$(json_escape "$evidence")\""
        write_report
        write_run_manifest
        exit 1
      fi

      for path in "${missing_expected[@]}"; do
        warning_message="expected file was not changed: $path"
        add_validation_warning "expected_changed_file_missing" "$path" "$warning_message"
      done
      printf 'Warning: %s\n' "$evidence" >&2
      write_log "expected_changes_missing_warning" ",\"evidence\":\"$(json_escape "$evidence")\""
    fi
  fi
}

check_clean_git_precondition() {
  (( require_clean_git )) || return 0

  collect_changed_files
  if ((${#changed_files[@]} == 0)); then
    return 0
  fi

  local evidence
  evidence="working tree has pre-existing source changes: $(join_by ', ' "${changed_files[@]}")"
  report_status="dirty_git"
  run_status="failed"
  add_validation_command "clean git check" 1 "blocked" "$evidence"
  write_log "dirty_git" ",\"evidence\":\"$(json_escape "$evidence")\""
  write_report
  write_run_manifest
  exit 1
}

create_evaluation_template_if_needed() {
  (( evaluation_template )) || return 0

  evaluation_path=".codex/runs/$run_id/evaluation.json"
  ensure_parent_dir "$evaluation_file_path"
  if [[ -f "$evaluation_file_path" ]]; then
    write_log "evaluation_template_exists" ",\"path\":\"$(json_escape "$evaluation_path")\""
    return 0
  fi

  cat > "$evaluation_file_path" <<EOF
{
  "schema_version": 1,
  "run_id": "$(json_escape "$run_id")",
  "result": "not_evaluated",
  "primary_failure_category": null,
  "failure_categories": [],
  "dimensions": {
    "task_completion": {
      "rating": "not_evaluated",
      "evidence": "Task completion has not been evaluated yet.",
      "evidence_refs": []
    },
    "scope_control": {
      "rating": "not_evaluated",
      "evidence": "Scope control has not been evaluated yet.",
      "evidence_refs": []
    },
    "validation_confidence": {
      "rating": "not_evaluated",
      "evidence": "Validation confidence has not been evaluated yet.",
      "evidence_refs": []
    },
    "safety_compliance": {
      "rating": "not_evaluated",
      "evidence": "Safety compliance has not been evaluated yet.",
      "evidence_refs": []
    },
    "reviewability": {
      "rating": "not_evaluated",
      "evidence": "Reviewability has not been evaluated yet.",
      "evidence_refs": []
    },
    "maintainability": {
      "rating": "not_evaluated",
      "evidence": "Maintainability has not been evaluated yet.",
      "evidence_refs": []
    },
    "reproducibility": {
      "rating": "not_evaluated",
      "evidence": "Reproducibility has not been evaluated yet.",
      "evidence_refs": []
    }
  },
  "findings": [],
  "improvement_candidates": []
}
EOF
  write_log "evaluation_template_created" ",\"path\":\"$(json_escape "$evaluation_path")\""
}

run_json_schema_validation_capture() {
  local schema_path="$1"
  local json_path="$2"
  local py output

  py="$(python_cmd)"
  if [[ -z "$py" ]]; then
    printf 'Python is required to validate JSON schema'
    return 127
  fi

  if ! output="$("$py" "$repo_root/scripts/validate-output-schema.py" "$schema_path" "$json_path" 2>&1)"; then
    printf '%s' "$output"
    return 1
  fi
  return 0
}

resolve_evaluation_schema_path() {
  local candidates=(
    "$repo_root/spec/evaluation.schema.json"
    "$repo_root/.codex/templates/evaluation.schema.json"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  printf ''
  return 1
}

read_evaluation_primary_failure_category() {
  local py
  py="$(python_cmd)"
  if [[ -z "$py" ]]; then
    printf 'Python is required to inspect evaluation.json'
    return 127
  fi

  "$py" - "$evaluation_file_path" "$run_id" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_run_id = sys.argv[2]

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except FileNotFoundError:
    raise SystemExit(f"evaluation.json is missing: {path}")
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid JSON in {path}: {exc}")

actual_run_id = data.get("run_id")
if actual_run_id != expected_run_id:
    raise SystemExit(f"evaluation run_id mismatch: expected {expected_run_id}, got {actual_run_id}")

value = data.get("primary_failure_category")
if value is None:
    print("null")
else:
    print(value)
PY
}

validate_required_evaluation() {
  (( require_evaluation )) || return 0

  local evidence category
  local expected_repo_path=".codex/runs/$run_id/evaluation.json"

  if [[ ! -f "$evaluation_file_path" ]]; then
    report_status="evaluation_missing"
    run_status="failed"
    evaluation_path=""
    evidence="evaluation.json is missing: $expected_repo_path"
    add_validation_command "evaluation validation" 1 "failed" "$evidence"
    write_log "evaluation_missing" ",\"evidence\":\"$(json_escape "$evidence")\""
    write_report
    write_run_manifest
    exit 1
  fi

  evaluation_path="$expected_repo_path"
  local evaluation_schema_path
  evaluation_schema_path="$(resolve_evaluation_schema_path)" || evaluation_schema_path=""
  if [[ -z "$evaluation_schema_path" ]]; then
    report_status="evaluation_invalid"
    run_status="failed"
    evidence="Evaluation schema not found: spec/evaluation.schema.json or .codex/templates/evaluation.schema.json"
    add_validation_command "evaluation validation" 1 "failed" "$evidence"
    write_log "evaluation_invalid" ",\"evidence\":\"$(json_escape "$evidence")\""
    write_report
    write_run_manifest
    exit 1
  fi

  if ! evidence="$(run_json_schema_validation_capture "$evaluation_schema_path" "$evaluation_file_path" 2>&1)"; then
    report_status="evaluation_invalid"
    run_status="failed"
    add_validation_command "evaluation validation" 1 "failed" "$evidence"
    write_log "evaluation_invalid" ",\"evidence\":\"$(json_escape "$evidence")\""
    write_report
    write_run_manifest
    exit 1
  fi

  if ! category="$(read_evaluation_primary_failure_category 2>&1)"; then
    report_status="evaluation_invalid"
    run_status="failed"
    add_validation_command "evaluation validation" 1 "failed" "$category"
    write_log "evaluation_invalid" ",\"evidence\":\"$(json_escape "$category")\""
    write_report
    write_run_manifest
    exit 1
  fi

  if [[ "$category" == "null" ]]; then
    primary_failure_category=""
  else
    primary_failure_category="$category"
  fi
  add_validation_command "evaluation validation" 0 "passed" "evaluation.json passed schema validation"
  write_log "evaluation_valid" ",\"path\":\"$(json_escape "$evaluation_path")\""
}

path_under_root() {
  local candidate root
  candidate="$(normalized_path "$1")"
  root="$(normalized_path "$repo_root")"
  [[ "$candidate" == "$root" || "$candidate" == "$root/"* ]]
}

to_container_path() {
  local full="$1"
  local rel
  if [[ "$full" == "$repo_root" ]]; then
    printf '/workspace'
    return
  fi
  rel="${full#"$repo_root"/}"
  printf '/workspace/%s' "${rel//\\//}"
}

write_log() {
  local event="$1"
  local extra_json="${2:-}"
  ensure_parent_dir "$log_path"
  printf '{"timestamp":"%s","event":"%s"%s}\n' \
    "$(json_escape "$(date -Iseconds)")" \
    "$(json_escape "$event")" \
    "$extra_json" >> "$log_path"
}

write_report() {
  ensure_parent_dir "$report_path"
  cat > "$report_path" <<EOF
{
  "runtime": "$(json_escape "$runtime")",
  "preset": "$(json_escape "$preset")",
  "mode": "$(json_escape "$preset")",
  "run_id": $(if [[ -n "$run_id" ]]; then printf '"%s"' "$(json_escape "$run_id")"; else printf 'null'; fi),
  "cwd": "$(json_escape "$cwd_for_report")",
  "git_branch": $(branch="$(git_branch)"; if [[ -n "$branch" ]]; then printf '"%s"' "$(json_escape "$branch")"; else printf 'null'; fi),
  "git_dirty": $(git_dirty),
  "prompt_source": "$(json_escape "$prompt_source")",
  "output_file": "$(json_escape "$output_file")",
  "output_schema": $(if [[ -n "$output_schema" ]]; then printf '"%s"' "$(json_escape "$output_schema")"; else printf 'null'; fi),
  "log_path": "$(json_escape "$log_path")",
  "codex_exit_code": $codex_exit_code,
  "verify_exit_code": $verify_exit_code,
  "status": "$(json_escape "$report_status")"
}
EOF
}

fail_with_status() {
  local status="$1"
  local message="$2"
  report_status="$status"
  run_status="failed"
  write_log "task_failed" ",\"status\":\"$(json_escape "$status")\",\"message\":\"$(json_escape "$message")\""
  write_report
  write_run_manifest
  printf '%s\n' "$message" >&2
  exit 1
}

block_unsafe_argument() {
  local token="$1"
  local reason="$2"
  fail_with_status "blocked_args" "Unsafe Codex argument blocked: '$token' ($reason)"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --preset)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--preset requires a value"
        preset="$2"
        shift 2
        ;;
      --runtime)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--runtime requires a value"
        runtime="$2"
        shift 2
        ;;
      --task-type)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--task-type requires a value"
        task_type="$2"
        shift 2
        ;;
      --workflow-level)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--workflow-level requires a value"
        workflow_level="$2"
        shift 2
        ;;
      --prompt-file)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--prompt-file requires a value"
        prompt_file="$(resolve_path "$2")"
        shift 2
        ;;
      --output-file)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--output-file requires a value"
        output_file="$(resolve_path "$2")"
        explicit_output_file=1
        shift 2
        ;;
      --output-schema)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--output-schema requires a value"
        output_schema="$(resolve_path "$2")"
        shift 2
        ;;
      --report-path)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--report-path requires a value"
        report_path="$(resolve_path "$2")"
        explicit_report_path=1
        shift 2
        ;;
      --verify-command)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--verify-command requires a value"
        verify_command="$2"
        shift 2
        ;;
      --allow-search)
        allow_search=1
        shift
        ;;
      --skip-preflight)
        skip_preflight=1
        shift
        ;;
      --skip-verify)
        skip_verify=1
        shift
        ;;
      --evaluation-template)
        evaluation_template=1
        shift
        ;;
      --require-evaluation)
        require_evaluation=1
        shift
        ;;
      --require-clean-git)
        require_clean_git=1
        shift
        ;;
      --require-run-id)
        require_run_id=1
        shift
        ;;
      --log-path)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--log-path requires a value"
        explicit_log_path="$(resolve_path "$2")"
        shift 2
        ;;
      --max-iterations)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--max-iterations requires a value"
        max_iterations="$2"
        max_iterations_provided=1
        shift 2
        ;;
      --run-id)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--run-id requires a value"
        run_id="$2"
        shift 2
        ;;
      --allowed-files)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--allowed-files requires a value"
        append_normalized_scope_paths allowed_files "$2" "--allowed-files"
        shift 2
        ;;
      --allowed-dirs)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--allowed-dirs requires a value"
        append_normalized_directory_scope_paths allowed_dirs "$2" "--allowed-dirs"
        shift 2
        ;;
      --allowed-globs)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--allowed-globs requires a value"
        append_normalized_scope_globs allowed_globs "$2" "--allowed-globs"
        shift 2
        ;;
      --expected-changed-files)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--expected-changed-files requires a value"
        append_normalized_scope_paths expected_changed_files "$2" "--expected-changed-files"
        shift 2
        ;;
      --expected-missing)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--expected-missing requires a value"
        expected_missing_behavior="$2"
        shift 2
        ;;
      --record-run-manifest)
        record_run_manifest=1
        shift
        ;;
      --dangerously-bypass-approvals-and-sandbox)
        block_unsafe_argument "$1" "dangerous bypass is prohibited"
        ;;
      --config|--config=*|-c|-c*)
        block_unsafe_argument "$1" "user config overrides are blocked; wrapper injects fixed safety settings"
        ;;
      --sandbox|--sandbox=*|-s|-s*)
        block_unsafe_argument "$1" "sandbox mode is fixed by wrapper"
        ;;
      --ask-for-approval|--ask-for-approval=*|-a|-a*)
        block_unsafe_argument "$1" "approval policy is fixed by wrapper"
        ;;
      --profile|--profile=*|-p|-p*)
        block_unsafe_argument "$1" "profiles are fixed by wrapper presets"
        ;;
      --cd|--cd=*|-C|-C*)
        block_unsafe_argument "$1" "working root is fixed by wrapper"
        ;;
      --enable|--enable=*|--disable|--disable=*)
        block_unsafe_argument "$1" "feature flags are blocked in safe wrapper"
        ;;
      --search)
        block_unsafe_argument "$1" "web search is disabled by default in safe wrapper"
        ;;
      --add-dir|--add-dir=*|--full-auto)
        block_unsafe_argument "$1" "additional writable directories are not allowed"
        ;;
      --*)
        fail_with_status "invalid_args" "Unsupported codex-task option: $1"
        ;;
      *)
        prompt_parts+=("$1")
        shift
        ;;
    esac
  done
}

apply_run_paths() {
  sort_unique_array allowed_files
  sort_unique_array allowed_dirs
  sort_unique_array allowed_globs
  sort_unique_array expected_changed_files

  if [[ "$expected_missing_behavior" != "warn" && "$expected_missing_behavior" != "fail" ]]; then
    fail_with_status "invalid_args" "--expected-missing must be warn or fail"
  fi

  if ((${#allowed_files[@]} > 0)) && { (( ! record_run_manifest )) || [[ -z "$run_id" ]]; }; then
    fail_with_status "invalid_args" "--allowed-files requires --run-id and --record-run-manifest"
  fi
  if ((${#allowed_dirs[@]} > 0 || ${#allowed_globs[@]} > 0)) && { (( ! record_run_manifest )) || [[ -z "$run_id" ]]; }; then
    fail_with_status "invalid_args" "scope options require --run-id and --record-run-manifest"
  fi
  if ((${#expected_changed_files[@]} > 0)) && { (( ! record_run_manifest )) || [[ -z "$run_id" ]]; }; then
    fail_with_status "invalid_args" "--expected-changed-files requires --run-id and --record-run-manifest"
  fi
  if (( evaluation_template )) && { (( ! record_run_manifest )) || [[ -z "$run_id" ]]; }; then
    fail_with_status "invalid_args" "--evaluation-template requires --run-id and --record-run-manifest"
  fi
  if (( require_evaluation )) && { (( ! record_run_manifest )) || [[ -z "$run_id" ]]; }; then
    fail_with_status "invalid_args" "--require-evaluation requires --run-id and --record-run-manifest"
  fi
  if (( require_run_id )) && [[ -z "$run_id" ]]; then
    fail_with_status "invalid_args" "--require-run-id requires --run-id"
  fi
  if (( max_iterations_provided )); then
    if [[ ! "$max_iterations" =~ ^([1-9]|10)$ ]]; then
      fail_with_status "invalid_args" "--max-iterations must be an integer between 1 and 10"
    fi
  fi

  if (( record_run_manifest )) && [[ -z "$run_id" ]]; then
    fail_with_status "invalid_args" "--record-run-manifest requires --run-id"
  fi

  if [[ -n "$run_id" ]]; then
    validate_run_id
    run_root="$repo_root/.codex/runs/$run_id"
    local normalized_runs_root normalized_run_root
    normalized_runs_root="$(normalized_path "$repo_root/.codex/runs")"
    normalized_run_root="$(normalized_path "$run_root")"
    if [[ "$normalized_run_root" != "$normalized_runs_root/"* ]]; then
      fail_with_status "invalid_args" "Invalid --run-id path: resolved run path escapes .codex/runs"
    fi
    if (( ! explicit_output_file )); then
      output_file="$run_root/artifacts/codex-task-${timestamp}.json"
    fi
    if (( ! explicit_report_path )); then
      report_path="$run_root/reports/codex-task-${timestamp}.report.json"
    fi
    if [[ -z "$explicit_log_path" ]]; then
      log_path="$run_root/logs/codex-task-${timestamp}.jsonl"
    fi
    if (( record_run_manifest )); then
      manifest_path="$run_root/run.json"
    fi
    evaluation_file_path="$run_root/evaluation.json"
  fi

  if [[ -n "$explicit_log_path" ]]; then
    log_path="$explicit_log_path"
  fi
}

validate_metadata() {
  case "$task_type" in
    plan|review|implementation|investigation|repair|harness-improvement) ;;
    *) fail_with_status "invalid_args" "Invalid --task-type: $task_type" ;;
  esac

  case "$workflow_level" in
    lightweight|standard|strict) ;;
    *) fail_with_status "invalid_args" "Invalid --workflow-level: $workflow_level" ;;
  esac
}

default_verify_command() {
  if [[ -f "$repo_root/scripts/verify" ]]; then
    printf 'bash scripts/verify'
    return
  fi
  if command -v powershell.exe >/dev/null 2>&1 && [[ -f "$repo_root/scripts/verify.ps1" ]]; then
    printf 'powershell.exe -ExecutionPolicy Bypass -File scripts/verify.ps1'
    return
  fi
  printf ''
}

run_preflight() {
  if [[ -n "$run_id" ]]; then
    bash "$repo_root/scripts/codex-safe.sh" --preset "$preset" --run-id "$run_id" --preflight-only >/dev/null
  else
    bash "$repo_root/scripts/codex-safe.sh" --preset "$preset" --preflight-only >/dev/null
  fi
}

append_command() {
  local -n _target=$1
  local command_path="$2"
  if [[ "$command_path" == *.sh ]]; then
    _target+=(bash "$command_path")
  else
    _target+=("$command_path")
  fi
}

run_schema_check() {
  local py
  py="$(python_cmd)"
  [[ -n "$py" ]] || fail_with_status "invalid_output" "Python is required to validate output schema"
  "$py" "$repo_root/scripts/validate-output-schema.py" "$output_schema" "$output_file"
}

main() {
  local prompt="" cwd sandbox_mode codex_bin used_verify container_output container_schema container_cwd

  case "$preset" in
    safe|readonly|auto-net) ;;
    *) fail_with_status "invalid_args" "Unsupported preset: $preset" ;;
  esac

  case "$runtime" in
    host|docker-sandbox) ;;
    *) fail_with_status "invalid_args" "Unsupported runtime: $runtime" ;;
  esac

  validate_metadata

  cwd="$(pwd -P)"
  if [[ "$cwd" != "$repo_root" && "$cwd" != "$repo_root/"* ]]; then
    cwd="$repo_root"
  fi
  cwd_for_report="$cwd"

  if (( record_run_manifest )); then
    manifest_started=1
    run_status="running"
    write_run_manifest
  fi

  check_clean_git_precondition
  write_log "wrapper_start" ",\"runtime\":\"$(json_escape "$runtime")\",\"preset\":\"$(json_escape "$preset")\",\"run_id\":\"$(json_escape "$run_id")\""
  create_evaluation_template_if_needed
  write_run_manifest

  if [[ -n "$prompt_file" ]]; then
    [[ -f "$prompt_file" ]] || fail_with_status "invalid_args" "Prompt file not found: $prompt_file"
    prompt="$(<"$prompt_file")"
    prompt_source="$prompt_file"
  else
    prompt="${prompt_parts[*]}"
    prompt_source="inline"
  fi
  [[ -n "$prompt" ]] || fail_with_status "invalid_args" "Prompt text is required"

  ensure_parent_dir "$output_file"
  ensure_parent_dir "$report_path"
  if [[ -n "$output_schema" && ! -f "$output_schema" ]]; then
    fail_with_status "invalid_args" "Output schema not found: $output_schema"
  fi

  if (( ! skip_preflight )); then
    write_log "preflight_start"
    if run_preflight; then
      write_log "preflight_ok"
    else
      fail_with_status "preflight_failed" "codex-safe preflight failed"
    fi
  fi

  sandbox_mode="workspace-write"
  approval_policy="never"
  profile_name="repo_safe"
  if [[ "$preset" == "readonly" ]]; then
    sandbox_mode="read-only"
    profile_name="repo_readonly"
  elif [[ "$preset" == "auto-net" ]]; then
    profile_name="repo_auto_net"
  fi

  if [[ -n "${CODEX_BIN:-}" ]]; then
    if [[ -x "$CODEX_BIN" || -f "$CODEX_BIN" ]]; then
      codex_bin="$CODEX_BIN"
    else
      codex_bin="$(command -v "$CODEX_BIN" || true)"
    fi
  else
    codex_bin="$(command -v codex || true)"
  fi
  [[ -n "$codex_bin" ]] || fail_with_status "codex_missing" "codex command not found in PATH"

  write_log "codex_exec_start" ",\"runtime\":\"$(json_escape "$runtime")\",\"output_file\":\"$(json_escape "$output_file")\""
  set +e
  if [[ "$runtime" == "host" ]]; then
    cmd=()
    append_command cmd "$codex_bin"
    cmd+=(--profile "$profile_name" --ask-for-approval "$approval_policy")
    if (( allow_search )); then
      cmd+=(--search)
    fi
    cmd+=(exec -C "$cwd" --sandbox "$sandbox_mode" --output-last-message "$output_file")
    if [[ -n "$output_schema" ]]; then
      cmd+=(--output-schema "$output_schema")
    fi
    cmd+=("$prompt")
    "${cmd[@]}"
    codex_exit_code=$?
  else
    if [[ -n "${CODEX_DOCKER_BIN:-}" ]]; then
      if [[ -x "$CODEX_DOCKER_BIN" || -f "$CODEX_DOCKER_BIN" ]]; then
        docker_bin="$CODEX_DOCKER_BIN"
      else
        docker_bin="$(command -v "$CODEX_DOCKER_BIN" || true)"
      fi
    else
      docker_bin="$(command -v docker || true)"
    fi
    [[ -n "$docker_bin" ]] || fail_with_status "docker_unavailable" "docker command not found in PATH"
    [[ -n "${CODEX_DOCKER_IMAGE:-}" ]] || fail_with_status "docker_unavailable" "Set CODEX_DOCKER_IMAGE before using docker-sandbox runtime"
    path_under_root "$output_file" || fail_with_status "docker_unavailable" "docker-sandbox output file must be under repository root"
    if [[ -n "$output_schema" ]]; then
      path_under_root "$output_schema" || fail_with_status "docker_unavailable" "docker-sandbox output schema must be under repository root"
    fi
    path_under_root "$cwd" || fail_with_status "docker_unavailable" "docker-sandbox working directory must be under repository root"

    container_output="$(to_container_path "$output_file")"
    container_cwd="$(to_container_path "$cwd")"
    docker_cmd=()
    append_command docker_cmd "$docker_bin"
    docker_cmd+=(run --rm -v "$repo_root:/workspace" -w /workspace)
    if [[ -d "${HOME:-}/.codex" ]]; then
      docker_cmd+=(-v "${HOME}/.codex:/root/.codex")
    fi
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
      docker_cmd+=(-e OPENAI_API_KEY)
    fi
    docker_cmd+=("${CODEX_DOCKER_IMAGE}" codex --profile "$profile_name" --ask-for-approval "$approval_policy")
    if (( allow_search )); then
      docker_cmd+=(--search)
    fi
    docker_cmd+=(exec -C "$container_cwd" --sandbox "$sandbox_mode" --output-last-message "$container_output")
    if [[ -n "$output_schema" ]]; then
      container_schema="$(to_container_path "$output_schema")"
      docker_cmd+=(--output-schema "$container_schema")
    fi
    docker_cmd+=("$prompt")
    "${docker_cmd[@]}"
    codex_exit_code=$?
  fi
  set -e

  write_log "codex_exec_exit" ",\"exit_code\":$codex_exit_code"
  if (( record_run_manifest )); then
    collect_changed_files
    write_run_manifest
  fi
  if [[ "$codex_exit_code" != "0" ]]; then
    report_status="codex_failed"
    run_status="failed"
    write_report
    write_run_manifest
    exit "$codex_exit_code"
  fi

  [[ -f "$output_file" ]] || fail_with_status "missing_output" "codex exec completed without writing output file"

  run_scope_checks

  if [[ -n "$output_schema" ]]; then
    if run_schema_check; then
      write_log "schema_ok"
      add_validation_command "output schema validation" 0 "passed" "output schema validation passed"
    else
      report_status="invalid_output"
      add_validation_command "output schema validation" 1 "failed" "output schema validation failed"
      run_status="failed"
      write_log "schema_failed"
      write_report
      write_run_manifest
      exit 1
    fi
  fi

  if (( skip_verify )); then
    report_status="verify_skipped"
    run_status="completed"
    if [[ "$validation_status" == "not_run" ]]; then
      validation_status="skipped"
    fi
  else
    used_verify="$verify_command"
    if [[ -z "$used_verify" ]]; then
      used_verify="$(default_verify_command)"
    fi

    if [[ -z "$used_verify" ]]; then
      report_status="verify_skipped"
      run_status="completed"
      if [[ "$validation_status" == "not_run" ]]; then
        validation_status="skipped"
      fi
      write_log "verify_skipped"
    else
      write_log "verify_start" ",\"command\":\"$(json_escape "$used_verify")\""
      set +e
      bash -lc "$used_verify"
      verify_exit_code=$?
      set -e
      write_log "verify_exit" ",\"exit_code\":$verify_exit_code"

      if [[ "$verify_exit_code" != "0" ]]; then
        report_status="verify_failed"
        add_validation_command "$used_verify" "$verify_exit_code" "failed" "verify command failed"
        run_status="failed"
        write_report
        write_run_manifest
        exit "$verify_exit_code"
      fi

      report_status="ok"
      run_status="completed"
      add_validation_command "$used_verify" "$verify_exit_code" "passed" "verify command completed successfully"
    fi
  fi

  validate_required_evaluation

  write_report
  write_run_manifest
  exit 0
}

parse_args "$@"
apply_run_paths
main
