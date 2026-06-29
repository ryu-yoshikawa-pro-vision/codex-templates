#!/usr/bin/env bash
set -euo pipefail

force=0
dry_run=0
confirm_destructive_overwrite=0
exclude_protected=0
plan_only=0

usage() {
  cat >&2 <<'EOF'
usage: tools/sync-template.sh [--dry-run|--plan-only] [--exclude-protected] [--force --confirm-destructive-overwrite] <destination>

Options:
  --dry-run                         Show what would be synced without changing files.
  --plan-only                       Show an update plan without copying files.
  --exclude-protected               Overlay-copy non-protected template paths and preserve protected destination paths.
  --force, -f                       Allow syncing into an existing destination.
  --confirm-destructive-overwrite   Required with --force when destination exists; existing top-level contents are removed.
  --help, -h                        Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --force|-f)
      force=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --plan-only)
      plan_only=1
      shift
      ;;
    --exclude-protected)
      exclude_protected=1
      shift
      ;;
    --confirm-destructive-overwrite)
      confirm_destructive_overwrite=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if (($# < 1)); then
  usage
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source_dir="$repo_root/template"
python_cmd=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)" >/dev/null 2>&1; then
    python_cmd="$candidate"
    break
  fi
done
[[ -n "$python_cmd" ]] || { echo "python3 or python is required" >&2; exit 1; }

dest="$($python_cmd - "$1" <<'PY'
import os
import sys
print(os.path.abspath(sys.argv[1]))
PY
)"

if [[ "$dest" == "$source_dir" || "$dest" == "$source_dir/"* ]]; then
  echo "Destination cannot be the template source directory or its child: $dest" >&2
  exit 1
fi

if (( plan_only )); then
  bash "$repo_root/tools/plan-consumer-update.sh" "$dest"
  exit 0
fi

if [[ -e "$dest" && $force -ne 1 ]]; then
  echo "Destination already exists. Use --force to overwrite after reviewing --dry-run: $dest" >&2
  exit 1
fi

if [[ -e "$dest" && $force -eq 1 && $exclude_protected -ne 1 && $confirm_destructive_overwrite -ne 1 && $dry_run -ne 1 ]]; then
  cat >&2 <<EOF
Refusing to destructively overwrite existing destination without explicit confirmation: $dest

Run a dry run first:
  tools/sync-template.sh --dry-run --force "$dest"

Then confirm destructive overwrite if the removal list is expected:
  tools/sync-template.sh --force --confirm-destructive-overwrite "$dest"
EOF
  exit 1
fi

if [[ $dry_run -eq 1 ]]; then
  echo "DRY RUN: source: $source_dir"
  echo "DRY RUN: destination: $dest"
  if (( exclude_protected )); then
    echo "DRY RUN: protected paths would be preserved and destination-only files would be kept."
  else
    echo "DRY RUN: destructive overwrite mode is active; existing top-level contents would be removed."
  fi
  if [[ -e "$dest" && $force -eq 1 && $exclude_protected -ne 1 ]]; then
    echo "DRY RUN: existing destination top-level entries that would be removed:"
    find "$dest" -mindepth 1 -maxdepth 1 -print | sort
  elif [[ -e "$dest" && $force -eq 1 ]]; then
    echo "DRY RUN: existing destination-only entries would be kept."
  elif [[ -e "$dest" ]]; then
    echo "DRY RUN: destination exists and --force was not provided; sync would fail."
  else
    echo "DRY RUN: destination does not exist and would be created."
  fi
  echo "DRY RUN: update planning summary:"
  bash "$repo_root/tools/plan-consumer-update.sh" "$dest"
  echo "DRY RUN: template files would be copied from source to destination."
  exit 0
fi

mkdir -p "$dest"
if [[ $exclude_protected -eq 1 ]]; then
  "$python_cmd" - "$source_dir" "$dest" <<'PY'
import pathlib
import shutil
import sys

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
PROTECTED_PREFIXES = {
    "docs/adr",
    "docs/plans",
    "docs/reports",
    "docs/history",
    ".codex/runs",
    ".git",
}
PROTECTED_EXACT = {
    "docs/PROJECT_CONTEXT.md",
    ".env",
}

def is_protected(rel_path: str) -> bool:
    rel_path = rel_path.strip("/")
    if rel_path in PROTECTED_EXACT or rel_path in PROTECTED_PREFIXES:
        return True
    if rel_path.startswith(".env."):
        return True
    return any(rel_path.startswith(prefix + "/") for prefix in PROTECTED_PREFIXES)

for item in sorted(source.rglob("*")):
    rel = item.relative_to(source).as_posix()
    if is_protected(rel):
        continue
    target = destination / rel
    if item.is_dir():
        target.mkdir(parents=True, exist_ok=True)
        continue
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(item, target)
PY
  echo "Template synced to $dest (non-protected paths updated, protected paths preserved)"
  exit 0
fi

if [[ $force -eq 1 ]]; then
  find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
fi
cp -R "$source_dir"/. "$dest"/
echo "Template synced to $dest"
