#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
python_cmd=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)" >/dev/null 2>&1; then
    python_cmd="$candidate"
    break
  fi
done
[[ -n "$python_cmd" ]] || { echo "Python 3 is required to collect run artifacts" >&2; exit 127; }

"$python_cmd" "$script_dir/collect-run-artifacts.py" "$@"
