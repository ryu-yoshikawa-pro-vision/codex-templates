#!/usr/bin/env bash
set -euo pipefail

validate_fake_write_path() {
  local raw="$1"
  local normalized="${raw//\\//}"

  if [[ -z "$normalized" ]]; then
    return 1
  fi
  if [[ "$normalized" == /* || "$normalized" =~ ^[A-Za-z]:/ || "$normalized" =~ ^// ]]; then
    return 1
  fi
  if [[ "$normalized" == ".." || "$normalized" == ../* || "$normalized" == */../* || "$normalized" == */.. ]]; then
    return 1
  fi

  printf '%s' "$normalized"
}

apply_fake_changes() {
  local workdir="$1"
  local raw_list="${FAKE_CODEX_WRITE_FILES:-}"
  [[ -n "$raw_list" ]] || return 0

  local IFS=','
  local path normalized target
  for path in $raw_list; do
    [[ -n "$path" ]] || continue
    normalized="$(validate_fake_write_path "$path")" || {
      echo "Unsafe FAKE_CODEX_WRITE_FILES path: $path" >&2
      exit 10
    }
    target="$workdir/$normalized"
    mkdir -p "$(dirname "$target")"
    printf '\nFAKE_CODEX_CHANGE\n' >> "$target"
  done
}

decision_for() {
  local joined="$*"
  case "$joined" in
    "git status") echo allow ;;
    "rg --files docs") echo allow ;;
    "git add .") echo forbidden ;;
    "git reset --hard HEAD~1") echo forbidden ;;
    "terraform destroy -auto-approve") echo forbidden ;;
    "terraform apply -auto-approve") echo forbidden ;;
    "kubectl apply -f deploy.yaml") echo forbidden ;;
    "docker ps") echo "${FAKE_CODEX_DOCKER_PS_DECISION:-prompt}" ;;
    "npm test") echo allow ;;
    "npm publish") echo forbidden ;;
    "curl https://example.com") echo allow ;;
    "bash -lc npm test") echo forbidden ;;
    "chmod 644 file.txt") echo forbidden ;;
    "systemctl stop nginx") echo forbidden ;;
    "crontab -e") echo forbidden ;;
    "netsh advfirewall show allprofiles") echo forbidden ;;
    "git checkout feature") echo forbidden ;;
    "rm file.txt") echo forbidden ;;
    "Remove-Item file.txt") echo forbidden ;;
    "git rm file.txt") echo forbidden ;;
    "python -c import os") echo forbidden ;;
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

while (($#)); do
  case "$1" in
    --profile|-C|--sandbox|--ask-for-approval)
      shift 2
      ;;
    --search|--json)
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -ge 1 && "$1" == "exec" ]]; then
  shift
  output_path=""
  schema_path=""
  prompt=""
  workdir="$(pwd -P)"
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
      -C)
        workdir="$2"
        shift 2
        ;;
      --profile|-C|--sandbox|--ask-for-approval)
        if [[ "$1" == "--ask-for-approval" && "$2" == "never" && "${FAKE_CODEX_ALLOW_NEVER:-0}" != "1" ]]; then
          exit 2
        fi
        shift 2
        ;;
      --search|--json)
        if [[ "$1" == "--search" ]]; then
          exit 2
        fi
        shift
        ;;
      --definitely-invalid-flag)
        exit 2
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

  apply_fake_changes "$workdir"

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
