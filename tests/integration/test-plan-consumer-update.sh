#!/usr/bin/env bash
set -euo pipefail

source_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
plan_wrapper="$source_repo_root/tools/plan-consumer-update.sh"
sync_wrapper="$source_repo_root/tools/sync-template.sh"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/plan-consumer-update-test.XXXXXX")"
consumer_root="$temp_root/consumer"
python_cmd=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)" >/dev/null 2>&1; then
    python_cmd="$candidate"
    break
  fi
done
[[ -n "$python_cmd" ]] || { echo "python3 or python is required" >&2; exit 1; }

cleanup() {
  case "$temp_root" in
    "${TMPDIR:-/tmp}"/plan-consumer-update-test.*)
      rm -rf -- "$temp_root"
      ;;
    *)
      echo "Refusing to clean unexpected temp root: $temp_root" >&2
      ;;
  esac
}
trap cleanup EXIT

mkdir -p "$consumer_root/docs/adr" "$consumer_root/docs/plans" "$consumer_root/docs/reports" "$consumer_root/docs/history" "$consumer_root/.codex/runs/20260601-010101-JST" "$consumer_root/.git" "$consumer_root/scripts"
cat > "$consumer_root/codex-project.toml" <<'EOF'
schema_version = 1
name = "consumer"
template_version = "0.10.0"
EOF
printf 'OLD AGENTS\n' > "$consumer_root/AGENTS.md"
printf 'KEEP PROJECT CONTEXT\n' > "$consumer_root/docs/PROJECT_CONTEXT.md"
printf 'KEEP ADR\n' > "$consumer_root/docs/adr/decision.md"
printf 'KEEP RUN\n' > "$consumer_root/.codex/runs/20260601-010101-JST/REPORT.md"
printf 'KEEP ENV\n' > "$consumer_root/.env.local"
printf 'KEEP EXTRA\n' > "$consumer_root/custom.md"
printf 'KEEP REPORT\n' > "$consumer_root/docs/reports/keep.md"
printf 'KEEP HISTORY\n' > "$consumer_root/docs/history/keep.md"
printf 'KEEP OLD TOOL\n' > "$consumer_root/scripts/old-tool.sh"
printf 'ref: refs/heads/main\n' > "$consumer_root/.git/HEAD"

human_output="$temp_root/human.out"
bash "$plan_wrapper" "$consumer_root" >"$human_output"
grep -q 'Source template version:' "$human_output"
grep -q 'Consumer template version: 0.10.0' "$human_output"
grep -q 'Version change: minor' "$human_output"
grep -q 'docs/PROJECT_CONTEXT.md' "$human_output"
grep -q 'custom.md' "$human_output"
grep -q 'scripts/old-tool.sh' "$human_output"
grep -q 'bash tools/sync-template.sh --exclude-protected --force' "$human_output"
grep -q 'bash scripts/verify' "$human_output"

json_output="$temp_root/plan.json"
bash "$plan_wrapper" --json "$consumer_root" >"$json_output"
"$python_cmd" - "$json_output" "$consumer_root" <<'PY'
import json
import pathlib
import sys

path, destination = sys.argv[1:3]
data = json.load(open(path, encoding="utf-8"))
if data["source_template_version"] != "0.11.0":
    raise SystemExit(f"unexpected source template version: {data['source_template_version']}")
if data["consumer_template_version"] != "0.10.0":
    raise SystemExit(f"unexpected consumer template version: {data['consumer_template_version']}")
if data["version_change"] != "minor":
    raise SystemExit(f"expected minor version change, got {data['version_change']}")
if pathlib.Path(data["destination"]) != pathlib.Path(destination).resolve():
    raise SystemExit(f"unexpected destination path: {data['destination']}")
for required in ["docs/PROJECT_CONTEXT.md", "docs/adr/", ".codex/runs/", ".git/", ".env.local"]:
    if required not in data["protected_paths"]:
        raise SystemExit(f"missing protected path {required}: {data['protected_paths']}")
if "AGENTS.md" not in data["candidate_updates"]:
    raise SystemExit(f"expected AGENTS.md in candidate updates: {data['candidate_updates']}")
if "custom.md" not in data["manual_review_required"]:
    raise SystemExit(f"expected custom.md in manual review required: {data['manual_review_required']}")
if "scripts/old-tool.sh" not in data["manual_review_required"]:
    raise SystemExit(f"expected scripts/old-tool.sh in manual review required: {data['manual_review_required']}")
if not data["recommended_commands"]:
    raise SystemExit("expected recommended commands")
PY

bash "$plan_wrapper" --template-version 0.11.0 "$consumer_root" >"$temp_root/version-ok.out"

set +e
bash "$plan_wrapper" --template-version 9.9.9 "$consumer_root" >"$temp_root/version-bad.out" 2>&1
code=$?
set -e
[[ $code -ne 0 ]]
grep -q 'does not match source template version' "$temp_root/version-bad.out"

sync_preview="$temp_root/sync-preview.out"
bash "$sync_wrapper" --plan-only --exclude-protected --force "$consumer_root" >"$sync_preview"
grep -q 'Protected paths:' "$sync_preview"

sync_dry_run="$temp_root/sync-dry-run.out"
bash "$sync_wrapper" --dry-run --exclude-protected --force "$consumer_root" >"$sync_dry_run"
grep -q 'existing destination-only entries would be kept' "$sync_dry_run"
if grep -q 'existing destination top-level entries that would be removed' "$sync_dry_run"; then
  echo "exclude-protected dry run should not print destructive removal list" >&2
  exit 1
fi

bash "$sync_wrapper" --exclude-protected --force "$consumer_root" >"$temp_root/sync.out"
cmp -s "$source_repo_root/template/AGENTS.md" "$consumer_root/AGENTS.md"
grep -q 'KEEP PROJECT CONTEXT' "$consumer_root/docs/PROJECT_CONTEXT.md"
grep -q 'KEEP EXTRA' "$consumer_root/custom.md"
grep -q 'KEEP REPORT' "$consumer_root/docs/reports/keep.md"
grep -q 'KEEP HISTORY' "$consumer_root/docs/history/keep.md"
grep -q 'KEEP OLD TOOL' "$consumer_root/scripts/old-tool.sh"
[[ -f "$consumer_root/.env.local" ]]
[[ -f "$consumer_root/.codex/runs/20260601-010101-JST/REPORT.md" ]]

echo "PASS: plan-consumer-update bash checks"
