#!/usr/bin/env bash
set -euo pipefail

force=0

usage() {
  echo "usage: tools/sync-template.sh [--force] <destination>" >&2
}

while (($#)); do
  case "$1" in
    --force|-f)
      force=1
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

dest="$("$python_cmd" - "$1" <<'PY'
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
  echo "Destination already exists. Use --force to overwrite: $dest" >&2
  exit 1
fi

mkdir -p "$dest"
if [[ $force -eq 1 ]]; then
  find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
fi
cp -R "$source_dir"/. "$dest"/
echo "Template synced to $dest"
