#!/usr/bin/env bash
set -euo pipefail

json_output=0
template_version_override=""

usage() {
  cat <<'EOF'
usage: bash tools/plan-consumer-update.sh [--json] [--template-version <version>] <destination>

Options:
  --json                        Print machine-readable JSON output.
  --template-version <version>  Require the source template version to match the expected target version.
  --help, -h                    Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --json)
      json_output=1
      shift
      ;;
    --template-version)
      [[ $# -ge 2 ]] || { echo "--template-version requires a value" >&2; exit 1; }
      template_version_override="$2"
      shift 2
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

if (($# != 1)); then
  usage >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source_template_root="$repo_root/template"
python_cmd=""
if command -v python >/dev/null 2>&1; then
  python_cmd="python"
elif command -v python3 >/dev/null 2>&1; then
  python_cmd="python3"
else
  echo "python3 or python is required" >&2
  exit 1
fi

"$python_cmd" - "$source_template_root" "$1" "$template_version_override" "$json_output" <<'PY'
import filecmp
import json
import pathlib
import re
import shlex
import sys

source_template_root = pathlib.Path(sys.argv[1]).resolve()
destination = pathlib.Path(sys.argv[2]).resolve()
template_version_override = sys.argv[3]
json_output = sys.argv[4] == "1"

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


def fail(message: str) -> None:
    raise SystemExit(message)


def is_semver(value: str) -> bool:
    return bool(re.fullmatch(r"\d+\.\d+\.\d+", value))


def parse_template_version(path: pathlib.Path):
    if not path.exists():
        return None
    content = path.read_text(encoding="utf-8")
    match = re.search(r'^template_version\s*=\s*"([^"]+)"', content, re.MULTILINE)
    if not match:
        return None
    return match.group(1)


def is_protected(rel_path: str) -> bool:
    rel_path = rel_path.strip("/")
    if rel_path in PROTECTED_EXACT or rel_path in PROTECTED_PREFIXES:
        return True
    if rel_path.startswith(".env."):
        return True
    return any(rel_path.startswith(prefix + "/") for prefix in PROTECTED_PREFIXES)


def version_change(source_version, consumer_version):
    if not source_version or not consumer_version:
        return "unknown"
    if not (is_semver(source_version) and is_semver(consumer_version)):
        return "unknown"
    source_parts = tuple(int(part) for part in source_version.split("."))
    consumer_parts = tuple(int(part) for part in consumer_version.split("."))
    if source_parts == consumer_parts:
        return "same"
    if source_parts[0] != consumer_parts[0]:
        return "major"
    if source_parts[1] != consumer_parts[1]:
        return "minor"
    return "patch"


def tree_has_source_diff(source_path: pathlib.Path, destination_path: pathlib.Path, rel_path: str) -> bool:
    if is_protected(rel_path):
        return False
    if not destination_path.exists():
        return True
    if source_path.is_dir() != destination_path.is_dir():
        return True
    if source_path.is_file():
        return not filecmp.cmp(source_path, destination_path, shallow=False)
    for child in sorted(source_path.iterdir(), key=lambda item: item.name):
        child_rel = f"{rel_path}/{child.name}" if rel_path else child.name
        if tree_has_source_diff(child, destination_path / child.name, child_rel):
            return True
    return False


def collect_existing_protected_paths(destination_root: pathlib.Path):
    items = []
    for rel in sorted(PROTECTED_EXACT):
        if (destination_root / rel).exists():
            items.append(rel)
    for prefix in sorted(PROTECTED_PREFIXES):
        path = destination_root / prefix
        if path.exists():
            items.append(prefix + "/")
    for env_path in sorted(destination_root.glob(".env.*")):
        if env_path.exists():
            items.append(env_path.relative_to(destination_root).as_posix())
    return items


def collect_candidate_updates(source_root: pathlib.Path, destination_root: pathlib.Path):
    candidates = []
    for child in sorted(source_root.iterdir(), key=lambda item: item.name):
        rel = child.name
        if is_protected(rel):
            continue
        if tree_has_source_diff(child, destination_root / child.name, rel):
            candidates.append(rel)
    return candidates


def collect_manual_review(source_root: pathlib.Path, destination_root: pathlib.Path, protected_paths):
    manual = list(protected_paths)
    if destination_root.exists():
        source_top = {child.name for child in source_root.iterdir()}
        for child in sorted(destination_root.iterdir(), key=lambda item: item.name):
            rel = child.name
            if is_protected(rel):
                continue
            if rel not in source_top:
                manual.append(rel)
    deduped = []
    seen = set()
    for item in manual:
        if item not in seen:
            deduped.append(item)
            seen.add(item)
    return deduped


source_version = parse_template_version(source_template_root / "codex-project.toml")
if not source_version:
    fail("Failed to read template_version from template/codex-project.toml")
if not is_semver(source_version):
    fail(f"Source template_version is not semver: {source_version}")

if template_version_override:
    if not is_semver(template_version_override):
        fail(f"--template-version must be semver: {template_version_override}")
    if template_version_override != source_version:
        fail(
            f"--template-version {template_version_override} does not match source template version {source_version}"
        )

consumer_version = parse_template_version(destination / "codex-project.toml")
protected_paths = collect_existing_protected_paths(destination)
candidate_updates = collect_candidate_updates(source_template_root, destination)
manual_review_required = collect_manual_review(source_template_root, destination, protected_paths)

dest_quoted = shlex.quote(str(destination))
result = {
    "source_template_version": source_version,
    "consumer_template_version": consumer_version,
    "version_change": version_change(source_version, consumer_version),
    "destination": str(destination),
    "protected_paths": protected_paths,
    "candidate_updates": candidate_updates,
    "manual_review_required": manual_review_required,
    "recommended_commands": [
        f"bash tools/plan-consumer-update.sh {dest_quoted}",
        f"bash tools/sync-template.sh --plan-only --exclude-protected --force {dest_quoted}",
        f"bash tools/sync-template.sh --exclude-protected --force {dest_quoted}",
        f"(cd {dest_quoted} && bash scripts/verify)",
        f"(cd {dest_quoted} && powershell -ExecutionPolicy Bypass -File scripts/verify.ps1)",
    ],
}

if json_output:
    print(json.dumps(result, indent=2, ensure_ascii=False))
    raise SystemExit(0)

print(f"Source template version: {source_version}")
print(f"Consumer template version: {consumer_version or '(not found)'}")
print(f"Version change: {result['version_change']}")
print(f"Destination: {destination}")
print("Protected paths:")
if protected_paths:
    for item in protected_paths:
        print(f"  - {item}")
else:
    print("  - (none)")
print("Candidate updates:")
if candidate_updates:
    for item in candidate_updates:
        print(f"  - {item}")
else:
    print("  - (none)")
print("Manual review required:")
if manual_review_required:
    for item in manual_review_required:
        print(f"  - {item}")
else:
    print("  - (none)")
print("Recommended commands:")
for command in result["recommended_commands"]:
    print(f"  - {command}")
PY
