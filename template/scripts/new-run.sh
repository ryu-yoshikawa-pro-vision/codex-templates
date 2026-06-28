#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/new-run.sh [options]

Options:
  --run-id <id>
  --task-type <plan|review|implementation|investigation|repair|harness-improvement>
  --workflow-level <lightweight|standard|strict>
  --preset <safe|readonly|auto-net>
  --no-plan
  --no-run-manifest
  --force
  -h, --help

Notes:
  - When --run-id is omitted, the script generates YYYYMMDD-HHMMSS-JST using JST.
  - Existing run directories are never overwritten. --force does not change that rule.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"

run_id=""
task_type="implementation"
workflow_level="standard"
preset="safe"
no_plan=0
no_run_manifest=0
force=0

generate_run_id() {
  TZ=Asia/Tokyo date +%Y%m%d-%H%M%S-JST
}

validate_run_id() {
  local value="$1"
  [[ "$value" =~ ^[0-9]{8}-[0-9]{6}-JST$ ]]
}

parse_args() {
  while (($#)); do
    case "$1" in
      --run-id)
        [[ $# -ge 2 ]] || { echo "--run-id requires a value" >&2; exit 2; }
        run_id="$2"
        shift 2
        ;;
      --task-type)
        [[ $# -ge 2 ]] || { echo "--task-type requires a value" >&2; exit 2; }
        task_type="$2"
        shift 2
        ;;
      --workflow-level)
        [[ $# -ge 2 ]] || { echo "--workflow-level requires a value" >&2; exit 2; }
        workflow_level="$2"
        shift 2
        ;;
      --preset)
        [[ $# -ge 2 ]] || { echo "--preset requires a value" >&2; exit 2; }
        preset="$2"
        shift 2
        ;;
      --no-plan)
        no_plan=1
        shift
        ;;
      --no-run-manifest)
        no_run_manifest=1
        shift
        ;;
      --force)
        force=1
        shift
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
}

render_run_manifest() {
  local template_path="$1"
  local output_path="$2"
  local content
  content="$(<"$template_path")"
  content="${content//<run_id>/$run_id}"
  content="${content//\"task_type\": \"implementation\"/\"task_type\": \"$task_type\"}"
  content="${content//\"workflow_level\": \"standard\"/\"workflow_level\": \"$workflow_level\"}"
  content="${content//\"preset\": \"safe\"/\"preset\": \"$preset\"}"
  printf '%s\n' "$content" > "$output_path"
}

parse_args "$@"

if [[ -z "$run_id" ]]; then
  run_id="$(generate_run_id)"
fi

if ! validate_run_id "$run_id"; then
  echo "Invalid --run-id: expected YYYYMMDD-HHMMSS-JST" >&2
  exit 2
fi

case "$task_type" in
  plan|review|implementation|investigation|repair|harness-improvement) ;;
  *)
    echo "Invalid --task-type: $task_type" >&2
    exit 2
    ;;
esac

case "$workflow_level" in
  lightweight|standard|strict) ;;
  *)
    echo "Invalid --workflow-level: $workflow_level" >&2
    exit 2
    ;;
esac

case "$preset" in
  safe|readonly|auto-net) ;;
  *)
    echo "Invalid --preset: $preset" >&2
    exit 2
    ;;
esac

runs_root="$repo_root/.codex/runs"
if (( force )); then
  mkdir -p "$runs_root"
else
  mkdir -p "$runs_root"
fi

run_root="$runs_root/$run_id"
if ! mkdir "$run_root"; then
  echo "Run directory already exists and will not be overwritten: .codex/runs/$run_id" >&2
  exit 1
fi
cp "$repo_root/.codex/templates/TASKS.md" "$run_root/TASKS.md"
cp "$repo_root/.codex/templates/REPORT.md" "$run_root/REPORT.md"
if (( ! no_plan )); then
  cp "$repo_root/.codex/templates/PLAN.md" "$run_root/PLAN.md"
fi
if (( ! no_run_manifest )); then
  render_run_manifest "$repo_root/.codex/templates/RUN_MANIFEST.json" "$run_root/run.json"
fi

printf 'Initialized run: .codex/runs/%s\n' "$run_id"
