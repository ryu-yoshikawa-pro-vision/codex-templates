#!/usr/bin/env bash
set -euo pipefail

force=0
dry_run=0
confirm_destructive_overwrite=0

usage() {
  cat >&2 <<'EOF'
usage: tools/sync-template.sh [--dry-run] [--force --confirm-destructive-overwrite] <destination>

Options:
  --dry-run                         Show what would be synced without changing files.
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
if command -v python3 >/dev/null 2>&1; then
  python_cmd="python3"
elif command -v python >/dev/null 2>&1; then
  python_cmd="python"
else
  echo "python3 or python is required" >&2
  exit 1
fi

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

if [[ -e "$dest" && $force -ne 1 ]]; then
  echo "Destination already exists. Use --force to overwrite after reviewing --dry-run: $dest" >&2
  exit 1
fi

if [[ -e "$dest" && $force -eq 1 && $confirm_destructive_overwrite -ne 1 && $dry_run -ne 1 ]]; then
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
  if [[ -e "$dest" && $force -eq 1 ]]; then
    echo "DRY RUN: existing destination top-level entries that would be removed:"
    find "$dest" -mindepth 1 -maxdepth 1 -print | sort
  elif [[ -e "$dest" ]]; then
    echo "DRY RUN: destination exists and --force was not provided; sync would fail."
  else
    echo "DRY RUN: destination does not exist and would be created."
  fi
  echo "DRY RUN: template files would be copied from source to destination."
  exit 0
fi

mkdir -p "$dest"
if [[ $force -eq 1 ]]; then
  find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
fi
cp -R "$source_dir"/. "$dest"/
echo "Template synced to $dest"
