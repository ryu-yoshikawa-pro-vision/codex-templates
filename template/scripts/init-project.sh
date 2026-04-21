#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/init-project.sh [--name <project-name>]

Initializes the Codex template metadata in the current repository without
deleting or moving files.
EOF
}

project_name=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --name" >&2
        exit 2
      fi
      project_name="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"

cd "$repo_root"

for dir in \
  ".codex/runs" \
  "docs/adr" \
  "docs/history" \
  "docs/plans" \
  "docs/reports"; do
  mkdir -p "$dir"
done

for keep in \
  ".codex/runs/.gitkeep" \
  "docs/adr/.gitkeep" \
  "docs/history/.gitkeep" \
  "docs/plans/.gitkeep" \
  "docs/reports/.gitkeep"; do
  if [[ ! -e "$keep" ]]; then
    : > "$keep"
  fi
done

if [[ -n "$project_name" && -f "codex-project.toml" ]]; then
  python_cmd=""
  if command -v python3 >/dev/null 2>&1; then
    python_cmd="python3"
  elif command -v python >/dev/null 2>&1; then
    python_cmd="python"
  fi

  if [[ -n "$python_cmd" ]]; then
    "$python_cmd" - "$project_name" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path("codex-project.toml")
name = sys.argv[1]
text = path.read_text(encoding="utf-8")
escaped = (
    name.replace("\\", "\\\\")
    .replace('"', '\\"')
    .replace("\r", "\\r")
    .replace("\n", "\\n")
    .replace("\t", "\\t")
)
text = re.sub(r'^name = ".*"$', f'name = "{escaped}"', text, count=1, flags=re.MULTILINE)
path.write_text(text, encoding="utf-8", newline="\n")
PY
  else
    echo "Python not found; leaving codex-project.toml name unchanged." >&2
  fi
fi

echo "Initialized Codex project metadata."
echo "Next: update docs/PROJECT_CONTEXT.md for this repository."
