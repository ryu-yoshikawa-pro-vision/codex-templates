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
prompt_file=""
output_schema=""
verify_command=""
allow_search=0
skip_preflight=0
skip_verify=0
explicit_log_path=""
explicit_output_file=0
explicit_report_path=0
run_id=""
cwd_for_report="$repo_root"
declare -a prompt_parts=()
declare -a allowed_files=()
declare -a expected_changed_files=()
declare -a changed_files=()

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
validation_command=""
validation_command_exit_code="null"
validation_command_status=""
validation_command_evidence=""
manifest_path=""
manifest_started=0
safety_scope_violation=false

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
  if command -v python3 >/dev/null 2>&1; then
    printf 'python3'
    return
  fi
  if command -v python >/dev/null 2>&1; then
    printf 'python'
    return
  fi
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

normalized_path() {
  local py
  py="$(python_cmd)"
  if [[ -z "$py" ]]; then
    printf '%s' "$1"
    return
  fi
  "$py" -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
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

  local branch report_ref network_enabled validation_commands_json changed_files_json
  branch="$(git_branch)"
  report_ref="$(to_repo_relative_path "$report_path")"
  network_enabled=false
  if [[ "$preset" == "auto-net" ]] || (( allow_search )); then
    network_enabled=true
  fi
  changed_files_json="$(json_string_array changed_files)"

  if [[ -n "$validation_command_status" ]]; then
    validation_commands_json=$(cat <<EOF
[
      {
        "command": "$(json_escape "$validation_command")",
        "exit_code": $validation_command_exit_code,
        "status": "$(json_escape "$validation_command_status")",
        "evidence": "$(json_escape "$validation_command_evidence")"
      }
    ]
EOF
)
  else
    validation_commands_json="[]"
  fi

  ensure_parent_dir "$manifest_path"
  cat > "$manifest_path" <<EOF
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
    "commands": $validation_commands_json
  },
  "safety": {
    "network": $network_enabled,
    "delete_attempt_blocked": false,
    "git_mutation_attempt_blocked": false,
    "scope_violation": $safety_scope_violation
  },
  "evaluation_path": null,
  "status": "$(json_escape "$run_status")",
  "primary_failure_category": null
}
EOF
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
  local -A allowed_lookup=()
  local -A changed_lookup=()
  local -a violations=()
  local -a missing_expected=()
  local path evidence

  if ((${#allowed_files[@]} > 0)); then
    for path in "${allowed_files[@]}"; do
      allowed_lookup["$path"]=1
    done
    for path in "${changed_files[@]}"; do
      if [[ -z "${allowed_lookup[$path]:-}" ]]; then
        violations+=("$path")
      fi
    done
    if ((${#violations[@]} > 0)); then
      sort_unique_array violations
      evidence="changed files outside allowed_files: $(join_by ', ' "${violations[@]}")"
      report_status="scope_violation"
      validation_status="blocked"
      validation_command="change scope check"
      validation_command_exit_code=1
      validation_command_status="blocked"
      validation_command_evidence="$evidence"
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
      report_status="expected_changes_missing"
      validation_status="failed"
      validation_command="expected changed files check"
      validation_command_exit_code=1
      validation_command_status="failed"
      validation_command_evidence="$evidence"
      run_status="failed"
      safety_scope_violation=false
      write_log "expected_changes_missing" ",\"evidence\":\"$(json_escape "$evidence")\""
      write_report
      write_run_manifest
      exit 1
    fi
  fi
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
      --log-path)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--log-path requires a value"
        explicit_log_path="$(resolve_path "$2")"
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
      --expected-changed-files)
        [[ $# -ge 2 ]] || fail_with_status "invalid_args" "--expected-changed-files requires a value"
        append_normalized_scope_paths expected_changed_files "$2" "--expected-changed-files"
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
  sort_unique_array expected_changed_files

  if ((${#allowed_files[@]} > 0)) && { (( ! record_run_manifest )) || [[ -z "$run_id" ]]; }; then
    fail_with_status "invalid_args" "--allowed-files requires --run-id and --record-run-manifest"
  fi
  if ((${#expected_changed_files[@]} > 0)) && { (( ! record_run_manifest )) || [[ -z "$run_id" ]]; }; then
    fail_with_status "invalid_args" "--expected-changed-files requires --run-id and --record-run-manifest"
  fi

  if (( record_run_manifest )) && [[ -z "$run_id" ]]; then
    fail_with_status "invalid_args" "--record-run-manifest requires --run-id"
  fi

  if [[ -n "$run_id" ]]; then
    validate_run_id
    local run_root="$repo_root/.codex/runs/$run_id"
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
  fi

  if [[ -n "$explicit_log_path" ]]; then
    log_path="$explicit_log_path"
  fi
}

validate_metadata() {
  case "$task_type" in
    plan|review|implementation|investigation|repair) ;;
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

  write_log "wrapper_start" ",\"runtime\":\"$(json_escape "$runtime")\",\"preset\":\"$(json_escape "$preset")\",\"run_id\":\"$(json_escape "$run_id")\""

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
    else
      report_status="invalid_output"
      validation_status="failed"
      validation_command="output schema validation"
      validation_command_exit_code=1
      validation_command_status="failed"
      validation_command_evidence="output schema validation failed"
      run_status="failed"
      write_log "schema_failed"
      write_report
      write_run_manifest
      exit 1
    fi
  fi

  if (( skip_verify )); then
    report_status="verify_skipped"
    validation_status="skipped"
    run_status="completed"
    write_report
    write_run_manifest
    exit 0
  fi

  used_verify="$verify_command"
  if [[ -z "$used_verify" ]]; then
    used_verify="$(default_verify_command)"
  fi

  if [[ -z "$used_verify" ]]; then
    report_status="verify_skipped"
    validation_status="skipped"
    run_status="completed"
    write_log "verify_skipped"
    write_report
    write_run_manifest
    exit 0
  fi

  write_log "verify_start" ",\"command\":\"$(json_escape "$used_verify")\""
  set +e
  bash -lc "$used_verify"
  verify_exit_code=$?
  set -e
  write_log "verify_exit" ",\"exit_code\":$verify_exit_code"
  validation_command="$used_verify"
  validation_command_exit_code="$verify_exit_code"

  if [[ "$verify_exit_code" != "0" ]]; then
    report_status="verify_failed"
    validation_status="failed"
    validation_command_status="failed"
    validation_command_evidence="verify command failed"
    run_status="failed"
    write_report
    write_run_manifest
    exit "$verify_exit_code"
  fi

  report_status="ok"
  validation_status="passed"
  validation_command_status="passed"
  validation_command_evidence="verify command completed successfully"
  run_status="completed"
  write_report
  write_run_manifest
}

parse_args "$@"
apply_run_paths
main
