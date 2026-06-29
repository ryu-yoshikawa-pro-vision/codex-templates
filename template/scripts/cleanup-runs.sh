#!/usr/bin/env bash
set -euo pipefail

confirm_delete=0
dry_run=0
older_than_days=""

usage() {
  cat <<'EOF'
usage: bash scripts/cleanup-runs.sh [--dry-run] [--older-than-days <days>] [--confirm-delete-generated-runs]

Options:
  --dry-run                          Preview cleanup candidates without deleting files.
  --older-than-days <days>           Limit candidates to paths older than the given number of days.
  --confirm-delete-generated-runs    Delete generated run artifacts after safety checks pass.
  --help, -h                         Show this help.

Notes:
  - Default behavior is preview-only. No files are deleted unless --confirm-delete-generated-runs is set.
  - Only generated run artifacts under .codex/ are eligible.
EOF
}

while (($#)); do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    --older-than-days)
      [[ $# -ge 2 ]] || { echo "--older-than-days requires a value" >&2; exit 1; }
      older_than_days="$2"
      shift 2
      ;;
    --confirm-delete-generated-runs)
      confirm_delete=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$older_than_days" && ! "$older_than_days" =~ ^[0-9]+$ ]]; then
  echo "--older-than-days must be a non-negative integer" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

run_id_regex='^[0-9]{8}-[0-9]{6}-JST$'
preview_only=1
if (( confirm_delete )) && (( ! dry_run )); then
  preview_only=0
fi

declare -a candidate_paths=()
declare -a candidate_kinds=()

to_windows_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$path"
    return 0
  fi
  printf '%s\n' "$path"
}

is_reparse_point() {
  local path="$1"
  if [[ -L "$path" ]]; then
    return 0
  fi
  if ! command -v powershell.exe >/dev/null 2>&1; then
    return 1
  fi
  local win_path escaped_path result
  win_path="$(to_windows_path "$path")"
  escaped_path="${win_path//\'/\'\'}"
  result="$(
    powershell.exe -NoProfile -NonInteractive -Command \
      "[bool]((Get-Item -LiteralPath '$escaped_path' -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint)" \
      2>/dev/null | tr -d '\r'
  )" || return 1
  [[ "$result" == "True" ]]
}

get_mtime_epoch() {
  local path="$1"
  if stat -c %Y "$path" >/dev/null 2>&1; then
    stat -c %Y "$path"
    return 0
  fi
  stat -f %m "$path"
}

is_old_enough() {
  local path="$1"
  if [[ -z "$older_than_days" ]]; then
    return 0
  fi
  local mtime now cutoff_seconds age_seconds
  mtime="$(get_mtime_epoch "$path")" || return 1
  now="$(date +%s)"
  cutoff_seconds=$((older_than_days * 86400))
  age_seconds=$((now - mtime))
  (( age_seconds >= cutoff_seconds ))
}

normalize_abs_path() {
  local path="$1"
  local dir base
  dir="$(cd "$(dirname "$path")" && pwd -P)"
  base="$(basename "$path")"
  printf '%s/%s\n' "$dir" "$base"
}

repo_contains_path() {
  local abs_path="$1"
  case "$abs_path" in
    "$repo_root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

to_repo_relative() {
  local abs_path="$1"
  printf '%s\n' "${abs_path#"$repo_root"/}"
}

add_candidate() {
  local kind="$1"
  local path="$2"
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    return 0
  fi
  if is_reparse_point "$path"; then
    candidate_kinds+=("$kind")
    candidate_paths+=("$path")
    return 0
  fi
  if ! is_old_enough "$path"; then
    return 0
  fi
  candidate_kinds+=("$kind")
  candidate_paths+=("$path")
}

if [[ -d ".codex/runs" ]]; then
  while IFS= read -r -d '' entry; do
    base="$(basename "$entry")"
    if [[ "$base" =~ $run_id_regex ]]; then
      add_candidate "run_dir" "$entry"
    fi
  done < <(find ".codex/runs" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
fi

if [[ -d ".codex/logs" ]]; then
  while IFS= read -r -d '' entry; do
    add_candidate "top_log" "$entry"
  done < <(find ".codex/logs" -mindepth 1 -maxdepth 1 -type f -name '*.jsonl' -print0 2>/dev/null)
fi

if [[ -f ".codex/observations/hooks.jsonl" || -L ".codex/observations/hooks.jsonl" ]]; then
  add_candidate "hook_log" ".codex/observations/hooks.jsonl"
fi

echo "MODE: $(if (( preview_only )); then printf 'preview'; else printf 'delete'; fi)"
if [[ -n "$older_than_days" ]]; then
  echo "OLDER_THAN_DAYS: $older_than_days"
fi
echo "CANDIDATES:"

if ((${#candidate_paths[@]} == 0)); then
  echo "  (none)"
else
  for index in "${!candidate_paths[@]}"; do
    abs_path="$(normalize_abs_path "${candidate_paths[$index]}")"
    if repo_contains_path "$abs_path"; then
      rel_path="$(to_repo_relative "$abs_path")"
    else
      rel_path="$abs_path"
    fi
    printf '  - [%s] %s\n' "${candidate_kinds[$index]}" "$rel_path"
  done
fi

deleted_count=0

if (( preview_only )); then
  echo "SUMMARY: preview_only deleted=0 candidates=${#candidate_paths[@]}"
  exit 0
fi

for index in "${!candidate_paths[@]}"; do
  raw_path="${candidate_paths[$index]}"
  abs_path="$(normalize_abs_path "$raw_path")"

  if is_reparse_point "$raw_path"; then
    echo "Refusing to delete symlink/reparse-point candidate: $(to_repo_relative "$abs_path")" >&2
    exit 1
  fi

  if ! repo_contains_path "$abs_path"; then
    echo "Refusing to delete path outside repo root: $abs_path" >&2
    exit 1
  fi

  rm -rf -- "$raw_path"
  deleted_count=$((deleted_count + 1))
done

echo "SUMMARY: deleted=$deleted_count candidates=${#candidate_paths[@]}"
