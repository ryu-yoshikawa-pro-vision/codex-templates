#!/usr/bin/env bash
set -euo pipefail

decision_for() {
  local joined="$*"
  case "$joined" in
    "git status") echo allow ;;
    "rg --files docs") echo allow ;;
    "git add .") echo prompt ;;
    "git reset --hard HEAD~1") echo forbidden ;;
    "terraform destroy -auto-approve") echo forbidden ;;
    "docker ps") echo prompt ;;
    "Remove-Item -Recurse tmp") echo forbidden ;;
    *) echo allow ;;
  esac
}

if [[ $# -ge 2 && "$1" == "execpolicy" && "$2" == "check" ]]; then
  shift 2
  while (($#)); do
    if [[ "$1" == "--" ]]; then
      shift
      break
    fi
    shift
  done
  printf '{"decision":"%s"}\n' "$(decision_for "$@")"
  exit 0
fi

if [[ $# -ge 1 && "$1" == "exec" ]]; then
  shift
  output_path=""
  schema_path=""
  prompt=""
  while (($#)); do
    case "$1" in
      --output-last-message)
        output_path="$2"
        shift 2
        ;;
      --output-schema)
        schema_path="$2"
        shift 2
        ;;
      -C|--sandbox|--ask-for-approval)
        shift 2
        ;;
      --search|--json)
        shift
        ;;
      *)
        if [[ "$1" != -* ]]; then
          prompt="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ "$prompt" == *FAIL_CODEX* ]]; then
    exit 9
  fi

  if [[ -n "$output_path" ]]; then
    mkdir -p "$(dirname "$output_path")"
    if [[ "$prompt" == *BAD_SCHEMA* ]]; then
      printf '{"unexpected":true}\n' > "$output_path"
    elif [[ -n "$schema_path" ]]; then
      printf '{"status":"ok"}\n' > "$output_path"
    else
      printf 'stub output\n' > "$output_path"
    fi
  fi
  exit 0
fi

exit 0
