#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/cleanup-runs-test.XXXXXX")"
template_root="$temp_root/template"
wrapper="$template_root/scripts/cleanup-runs.sh"

cleanup() {
  case "$temp_root" in
    "${TMPDIR:-/tmp}"/cleanup-runs-test.*)
      rm -rf -- "$temp_root"
      ;;
    *)
      echo "Refusing to clean unexpected temp root: $temp_root" >&2
      ;;
  esac
}
trap cleanup EXIT

mkdir -p "$template_root/scripts"
cp "$source_repo_root/template/scripts/cleanup-runs.sh" "$wrapper"
cd "$template_root"

old_run_id="20260601-010101-JST"
new_run_id="20260628-010101-JST"
mkdir -p ".codex/runs/$old_run_id/reports" ".codex/runs/$new_run_id/reports" ".codex/logs" ".codex/observations" "docs/plans" "docs/reports" "docs/adr"
printf 'old\n' > ".codex/runs/$old_run_id/REPORT.md"
printf 'new\n' > ".codex/runs/$new_run_id/REPORT.md"
printf 'safe\n' > ".codex/logs/codex-safe-old.jsonl"
printf 'hook\n' > ".codex/observations/hooks.jsonl"
printf 'keep\n' > "docs/plans/keep.md"
printf 'keep\n' > "docs/reports/keep.md"
printf 'keep\n' > "docs/adr/keep.md"

touch -d '40 days ago' ".codex/runs/$old_run_id" ".codex/runs/$old_run_id/REPORT.md" ".codex/logs/codex-safe-old.jsonl" ".codex/observations/hooks.jsonl"
touch -d '1 day ago' ".codex/runs/$new_run_id" ".codex/runs/$new_run_id/REPORT.md"

preview_output="$temp_root/preview.out"
bash "$wrapper" --older-than-days 30 --dry-run >"$preview_output"
grep -q 'MODE: preview' "$preview_output"
grep -q ".codex/runs/$old_run_id" "$preview_output"
grep -q '.codex/logs/codex-safe-old.jsonl' "$preview_output"
[[ -d ".codex/runs/$old_run_id" ]]
[[ -f ".codex/logs/codex-safe-old.jsonl" ]]

default_preview_output="$temp_root/default-preview.out"
bash "$wrapper" --older-than-days 30 >"$default_preview_output"
grep -q 'MODE: preview' "$default_preview_output"
[[ -d ".codex/runs/$old_run_id" ]]
[[ -f ".codex/logs/codex-safe-old.jsonl" ]]

bash "$wrapper" --older-than-days 30 --confirm-delete-generated-runs >"$temp_root/delete.out"
[[ ! -d ".codex/runs/$old_run_id" ]]
[[ -d ".codex/runs/$new_run_id" ]]
[[ ! -f ".codex/logs/codex-safe-old.jsonl" ]]
[[ ! -f ".codex/observations/hooks.jsonl" ]]
[[ -f "docs/plans/keep.md" ]]
[[ -f "docs/reports/keep.md" ]]
[[ -f "docs/adr/keep.md" ]]

set +e
bash "$wrapper" --older-than-days -1 >"$temp_root/invalid.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q -- '--older-than-days must be a non-negative integer' "$temp_root/invalid.out"

outside_dir="$temp_root/outside"
mkdir -p "$outside_dir"
symlink_run_id="20260602-020202-JST"
symlink_path_win="$(cygpath -w "$template_root/.codex/runs/$symlink_run_id")"
outside_dir_win="$(cygpath -w "$outside_dir")"
powershell.exe -NoProfile -NonInteractive -Command "\$path = '$symlink_path_win'; \$target = '$outside_dir_win'; New-Item -ItemType Junction -Path \$path -Target \$target | Out-Null"
set +e
bash "$wrapper" --older-than-days 0 --confirm-delete-generated-runs >"$temp_root/symlink.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q 'Refusing to delete symlink/reparse-point candidate' "$temp_root/symlink.out"
[[ -d "$outside_dir" ]]
[[ -d ".codex/runs/$new_run_id" ]]
[[ -d ".codex/runs/$symlink_run_id" ]]

echo "PASS: cleanup-runs bash checks"
