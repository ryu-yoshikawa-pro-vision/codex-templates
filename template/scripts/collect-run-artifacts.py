#!/usr/bin/env python3
import argparse
import copy
import json
from pathlib import Path


HOOK_EVENTS = {
    "PreToolUse",
    "PostToolUse",
    "SubagentStart",
    "SubagentStop",
    "Stop",
    "WrapperStart",
    "WrapperStop",
    "SafetyBlocked",
    "ObservationError",
}


def parse_args():
    parser = argparse.ArgumentParser(description="Aggregate run-local artifacts into run.json.")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--runs-root")
    parser.add_argument("--hook-log", action="append", default=[])
    parser.add_argument("--manifest-path")
    parser.add_argument("--base-manifest")
    parser.add_argument("--strict", action="store_true")
    return parser.parse_args()


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[1]


def repo_relative(repo_root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.resolve().as_posix()


def normalize_repo_path(value):
    if not isinstance(value, str):
        return value
    return value.replace("\\", "/")


def unique_list(values):
    result = []
    seen = set()
    for value in values:
        marker = json.dumps(value, sort_keys=True, ensure_ascii=True)
        if marker in seen:
            continue
        seen.add(marker)
        result.append(value)
    return result


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def default_manifest(repo_root: Path, run_id: str):
    template_path = repo_root / ".codex" / "templates" / "RUN_MANIFEST.json"
    if template_path.exists():
        data = load_json(template_path)
    else:
        data = {
            "schema_version": 1,
            "run_id": run_id,
            "task_type": "implementation",
            "workflow_level": "standard",
            "preset": "safe",
            "runtime": "host",
            "agents_used": [],
            "repo": None,
            "branch": None,
            "base_branch": None,
            "codex_task_reports": [],
            "changed_files": [],
            "validation": {"status": "not_run", "commands": [], "warnings": []},
            "safety": {
                "network": False,
                "delete_attempt_blocked": False,
                "git_mutation_attempt_blocked": False,
                "scope_violation": False,
            },
            "artifact_summary": {
                "codex_task_report_count": 0,
                "hook_event_count": 0,
                "subagent_run_count": 0,
                "evaluation_present": False,
            },
            "hook_observations": {
                "log_paths": [],
                "event_counts": {},
                "blocking_event_count": 0,
                "safety_blocked_count": 0,
                "observation_error_count": 0,
            },
            "subagents": {
                "records": [],
                "summary": {
                    "total": 0,
                    "read_only": 0,
                    "writable": 0,
                    "scope_violations": 0,
                    "used_in_final_plan": 0,
                },
            },
            "evaluation_path": None,
            "status": "pending",
            "primary_failure_category": None,
        }
    data["run_id"] = run_id
    return data


def add_warning(warnings, warning_type: str, path: str, message: str):
    warnings.append({"type": warning_type, "path": normalize_repo_path(path), "message": message})


def extend_unique_strings(target, values):
    target.extend(normalize_repo_path(value) for value in values if isinstance(value, str) and value)
    return unique_list(target)


def merge_validation_status(base_status: str, commands, warnings):
    statuses = {item.get("status") for item in commands if isinstance(item, dict)}
    if "blocked" in statuses:
        return "blocked"
    if "failed" in statuses:
        return "failed"
    if warnings:
        return "passed_with_warnings"
    if "passed" in statuses:
        return "passed"
    if "skipped" in statuses:
        return "skipped"
    return base_status or "not_run"


def safety_text(event):
    parts = []
    metadata = event.get("metadata")
    if isinstance(metadata, dict):
        for key in ("type", "kind", "category", "blocked_type", "operation"):
            value = metadata.get(key)
            if isinstance(value, str):
                parts.append(value.lower())
    decision = event.get("decision")
    if isinstance(decision, dict):
        reason = decision.get("reason")
        if isinstance(reason, str):
            parts.append(reason.lower())
    tool = event.get("tool")
    if isinstance(tool, dict):
        for key in ("name", "operation", "target"):
            value = tool.get(key)
            if isinstance(value, str):
                parts.append(value.lower())
    return " ".join(parts)


def collect_hook_observations(repo_root: Path, run_root: Path, run_id: str, explicit_logs):
    summary = {
        "log_paths": [],
        "event_counts": {},
        "blocking_event_count": 0,
        "safety_blocked_count": 0,
        "observation_error_count": 0,
    }
    warnings = []
    safety = {"delete_attempt_blocked": False, "git_mutation_attempt_blocked": False}

    default_hook_log = repo_root / ".codex" / "observations" / "hooks.jsonl"
    candidate_paths = []
    explicit_paths = []
    for raw in explicit_logs:
        path = Path(raw)
        if not path.is_absolute():
            path = repo_root / path
        explicit_paths.append(path)
        candidate_paths.append(path)
    if default_hook_log.exists():
        candidate_paths.append(default_hook_log)
    logs_dir = run_root / "logs"
    if logs_dir.exists():
        candidate_paths.extend(sorted(logs_dir.glob("*.jsonl")))
    candidate_paths = unique_list([str(path.resolve()) for path in candidate_paths if path.exists()])
    explicit_markers = {str(path.resolve()) for path in explicit_paths}
    if default_hook_log.exists():
        explicit_markers.add(str(default_hook_log.resolve()))

    for raw_path in candidate_paths:
        path = Path(raw_path)
        matched_in_file = 0
        for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if not line.strip():
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError as exc:
                if raw_path in explicit_markers:
                    add_warning(
                        warnings,
                        "hook_observation_invalid_jsonl",
                        repo_relative(repo_root, path),
                        f"line {index}: {exc.msg}",
                    )
                continue
            if not isinstance(payload, dict):
                continue
            event = payload.get("event")
            if event not in HOOK_EVENTS or payload.get("run_id") != run_id:
                continue
            matched_in_file += 1
            summary["event_counts"][event] = summary["event_counts"].get(event, 0) + 1
            if payload.get("blocking") is True:
                summary["blocking_event_count"] += 1
            if event == "SafetyBlocked":
                summary["safety_blocked_count"] += 1
                text = safety_text(payload)
                if "delete" in text or "remove-item" in text or " rm " in f" {text} ":
                    safety["delete_attempt_blocked"] = True
                if "git " in text or "git_" in text or "git-" in text:
                    safety["git_mutation_attempt_blocked"] = True
            if event == "ObservationError":
                summary["observation_error_count"] += 1
        if matched_in_file:
            summary["log_paths"].append(repo_relative(repo_root, path))

    summary["log_paths"] = unique_list(summary["log_paths"])
    summary["event_counts"] = dict(sorted(summary["event_counts"].items()))
    return summary, warnings, safety


def collect_subagents(repo_root: Path, run_root: Path, run_id: str):
    records = []
    warnings = []
    changed_files = []
    agents_used = []
    subagents_dir = run_root / "subagents"
    if not subagents_dir.exists():
        return {
            "records": [],
            "summary": {
                "total": 0,
                "read_only": 0,
                "writable": 0,
                "scope_violations": 0,
                "used_in_final_plan": 0,
            },
        }, warnings, changed_files, agents_used

    summary = {
        "total": 0,
        "read_only": 0,
        "writable": 0,
        "scope_violations": 0,
        "used_in_final_plan": 0,
    }

    for path in sorted(subagents_dir.glob("*.json")):
        try:
            payload = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            add_warning(warnings, "subagent_invalid_json", repo_relative(repo_root, path), str(exc))
            continue

        if not isinstance(payload, dict):
            add_warning(warnings, "subagent_invalid_json", repo_relative(repo_root, path), "Top-level JSON must be an object")
            continue

        if payload.get("parent_run_id") != run_id:
            add_warning(
                warnings,
                "subagent_parent_run_mismatch",
                repo_relative(repo_root, path),
                f"parent_run_id={payload.get('parent_run_id')!r}",
            )
            continue

        allowed_files = payload.get("allowed_files") if isinstance(payload.get("allowed_files"), list) else []
        file_changes = payload.get("changed_files") if isinstance(payload.get("changed_files"), list) else []
        mode = payload.get("mode")
        scope = payload.get("scope") if isinstance(payload.get("scope"), dict) else {}
        scope_compliant = scope.get("compliant")
        used_in_final_plan = payload.get("used_in_final_plan") is True
        parent_decision = payload.get("parent_decision") if isinstance(payload.get("parent_decision"), dict) else {}
        agent = payload.get("agent") if isinstance(payload.get("agent"), dict) else {}
        agent_name = agent.get("name")

        if mode == "writable" and len(allowed_files) == 0:
            add_warning(
                warnings,
                "subagent_writable_missing_allowed_files",
                repo_relative(repo_root, path),
                "writable subagent should declare allowed_files",
            )
        if mode == "read_only" and len(file_changes) != 0:
            add_warning(
                warnings,
                "subagent_read_only_changed_files",
                repo_relative(repo_root, path),
                "read-only subagent should have changed_files=[]",
            )

        records.append(
            {
                "path": repo_relative(repo_root, path),
                "subagent_run_id": payload.get("subagent_run_id"),
                "agent_name": agent_name,
                "role": payload.get("role"),
                "mode": mode,
                "status": payload.get("status"),
                "allowed_files_count": len(allowed_files),
                "changed_files_count": len(file_changes),
                "scope_compliant": scope_compliant,
                "used_in_final_plan": used_in_final_plan,
                "parent_decision": parent_decision.get("action"),
            }
        )
        changed_files.extend(normalize_repo_path(item) for item in file_changes if isinstance(item, str) and item)
        if isinstance(agent_name, str) and agent_name:
            agents_used.append(agent_name)

        summary["total"] += 1
        if mode == "read_only":
            summary["read_only"] += 1
        if mode == "writable":
            summary["writable"] += 1
        if scope_compliant is False:
            summary["scope_violations"] += 1
        if used_in_final_plan:
            summary["used_in_final_plan"] += 1

    return {"records": records, "summary": summary}, warnings, unique_list(changed_files), unique_list(agents_used)


def collect_report_paths(repo_root: Path, run_root: Path):
    reports_dir = run_root / "reports"
    if not reports_dir.exists():
        return []
    return [repo_relative(repo_root, path) for path in sorted(reports_dir.glob("*.report.json"))]


def load_manifest_candidate(path: Path):
    if not path or not path.exists():
        return None
    try:
        data = load_json(path)
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def merge_manifests(default_data, existing_data, base_data):
    manifest = copy.deepcopy(default_data)
    for source in (base_data or {}, existing_data or {}):
        for key in ("schema_version", "run_id", "task_type", "workflow_level", "preset", "runtime", "repo", "branch", "base_branch", "evaluation_path", "status", "primary_failure_category"):
            value = source.get(key)
            if value is not None:
                manifest[key] = value
        if "agents_used" in source and isinstance(source.get("agents_used"), list):
            manifest["agents_used"] = source.get("agents_used")
        if "codex_task_reports" in source and isinstance(source.get("codex_task_reports"), list):
            manifest["codex_task_reports"] = source.get("codex_task_reports")
        if "changed_files" in source and isinstance(source.get("changed_files"), list):
            manifest["changed_files"] = source.get("changed_files")
        if "validation" in source and isinstance(source.get("validation"), dict):
            manifest["validation"] = source.get("validation")
        if "safety" in source and isinstance(source.get("safety"), dict):
            manifest["safety"] = source.get("safety")
        if "artifact_summary" in source and isinstance(source.get("artifact_summary"), dict):
            manifest["artifact_summary"] = source.get("artifact_summary")
        if "hook_observations" in source and isinstance(source.get("hook_observations"), dict):
            manifest["hook_observations"] = source.get("hook_observations")
        if "subagents" in source and isinstance(source.get("subagents"), dict):
            manifest["subagents"] = source.get("subagents")
    return manifest


def main():
    args = parse_args()
    repo_root = repo_root_from_script()
    runs_root = Path(args.runs_root) if args.runs_root else (repo_root / ".codex" / "runs")
    if not runs_root.is_absolute():
        runs_root = repo_root / runs_root
    run_root = runs_root / args.run_id
    manifest_path = Path(args.manifest_path) if args.manifest_path else (run_root / "run.json")
    if not manifest_path.is_absolute():
        manifest_path = repo_root / manifest_path

    default_data = default_manifest(repo_root, args.run_id)
    existing_data = load_manifest_candidate(manifest_path)
    base_manifest_path = None
    if args.base_manifest:
        base_manifest_path = Path(args.base_manifest)
        if not base_manifest_path.is_absolute():
            base_manifest_path = repo_root / base_manifest_path
    base_data = load_manifest_candidate(base_manifest_path) if base_manifest_path else None
    manifest = merge_manifests(default_data, existing_data, base_data)
    manifest["run_id"] = args.run_id

    validation_warnings = []
    existing_validation = manifest.get("validation") if isinstance(manifest.get("validation"), dict) else {}
    validation_commands = []
    if isinstance(existing_validation.get("commands"), list):
        validation_commands.extend(existing_validation.get("commands"))
    validation_warnings.extend(existing_validation.get("warnings") if isinstance(existing_validation.get("warnings"), list) else [])

    report_paths = collect_report_paths(repo_root, run_root)
    manifest["codex_task_reports"] = unique_list(
        [normalize_repo_path(item) for item in manifest.get("codex_task_reports", []) if isinstance(item, str)] + report_paths
    )

    subagents, subagent_warnings, subagent_changed_files, subagent_agents = collect_subagents(repo_root, run_root, args.run_id)
    validation_warnings.extend(subagent_warnings)
    manifest["subagents"] = subagents

    hook_summary, hook_warnings, safety_updates = collect_hook_observations(repo_root, run_root, args.run_id, args.hook_log)
    validation_warnings.extend(hook_warnings)
    manifest["hook_observations"] = hook_summary

    manifest["changed_files"] = unique_list(
        [normalize_repo_path(item) for item in manifest.get("changed_files", []) if isinstance(item, str)] + subagent_changed_files
    )
    manifest["agents_used"] = unique_list(
        [item for item in manifest.get("agents_used", []) if isinstance(item, str) and item] + subagent_agents
    )

    safety = manifest.get("safety") if isinstance(manifest.get("safety"), dict) else {}
    safety["network"] = bool(safety.get("network"))
    safety["delete_attempt_blocked"] = bool(safety.get("delete_attempt_blocked")) or safety_updates["delete_attempt_blocked"]
    safety["git_mutation_attempt_blocked"] = bool(safety.get("git_mutation_attempt_blocked")) or safety_updates["git_mutation_attempt_blocked"]
    safety["scope_violation"] = bool(safety.get("scope_violation")) or subagents["summary"]["scope_violations"] > 0
    manifest["safety"] = safety

    evaluation_path = run_root / "evaluation.json"
    evaluation_present = evaluation_path.exists()
    if evaluation_present:
        manifest["evaluation_path"] = manifest.get("evaluation_path") or repo_relative(repo_root, evaluation_path)
        try:
            evaluation = load_json(evaluation_path)
        except (OSError, json.JSONDecodeError) as exc:
            add_warning(validation_warnings, "evaluation_invalid_json", repo_relative(repo_root, evaluation_path), str(exc))
        else:
            if isinstance(evaluation, dict):
                if evaluation.get("run_id") == args.run_id:
                    manifest["primary_failure_category"] = evaluation.get("primary_failure_category")
                else:
                    add_warning(
                        validation_warnings,
                        "evaluation_run_id_mismatch",
                        repo_relative(repo_root, evaluation_path),
                        f"run_id={evaluation.get('run_id')!r}",
                    )

    manifest["validation"] = {
        "status": merge_validation_status(existing_validation.get("status"), validation_commands, unique_list(validation_warnings)),
        "commands": unique_list(validation_commands),
        "warnings": unique_list(validation_warnings),
    }
    manifest["artifact_summary"] = {
        "codex_task_report_count": len(manifest["codex_task_reports"]),
        "hook_event_count": sum(hook_summary["event_counts"].values()),
        "subagent_run_count": subagents["summary"]["total"],
        "evaluation_present": evaluation_present,
    }

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

    if args.strict and manifest["validation"]["warnings"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
