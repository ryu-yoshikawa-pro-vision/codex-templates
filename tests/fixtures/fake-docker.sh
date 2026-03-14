#!/usr/bin/env bash
set -euo pipefail

[[ -n "${CODEX_BIN:-}" ]] || {
  echo "CODEX_BIN is required for fake-docker.sh" >&2
  exit 1
}

if [[ "${1:-}" == "run" ]]; then
  shift
fi

while (($#)); do
  case "$1" in
    --rm)
      shift
      ;;
    -v|-w|-e)
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -ge 1 ]] || {
  echo "docker image argument missing" >&2
  exit 1
}

shift
if [[ "${1:-}" == "codex" ]]; then
  shift
fi

"$CODEX_BIN" "$@"
