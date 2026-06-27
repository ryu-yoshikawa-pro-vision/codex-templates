#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

python_cmd=""
if command -v python3 >/dev/null 2>&1; then
  python_cmd="python3"
elif command -v python >/dev/null 2>&1; then
  python_cmd="python"
else
  echo "python3 or python is required" >&2
  exit 1
fi

"$python_cmd" - "$repo_root" <<'PY'
import json
import pathlib
import sys

repo_root = pathlib.Path(sys.argv[1])


def read_spec(rel):
    return json.loads((repo_root / rel).read_text(encoding="utf-8"))


def assert_exists(rel):
    path = repo_root / rel
    if not path.exists():
        raise SystemExit(f"Required path missing: {rel}")


def assert_contains(rel, patterns):
    content = (repo_root / rel).read_text(encoding="utf-8")
    for pattern in patterns:
        if pattern not in content:
            raise SystemExit(f"Pattern '{pattern}' not found in {rel}")


def ensure(condition, message):
    if not condition:
        raise SystemExit(message)


def expect_required_fields(schema, fields, label):
    required = schema.get("required", [])
    missing = [field for field in fields if field not in required]
    ensure(not missing, f"{label} missing required fields: {missing}")


def expect_property_keys(schema, fields, label):
    properties = schema.get("properties", {})
    missing = [field for field in fields if field not in properties]
    ensure(not missing, f"{label} missing properties: {missing}")


def expect_enum_contains(values, expected, label):
    missing = [value for value in expected if value not in values]
    ensure(not missing, f"{label} missing enum values: {missing}")


def expect_enum_set(values, expected, label):
    actual_set = set(values)
    expected_set = set(expected)
    ensure(
        actual_set == expected_set,
        f"{label} enum mismatch: expected {sorted(expected_set, key=lambda x: str(x))}, got {sorted(actual_set, key=lambda x: str(x))}",
    )


workflow = read_spec("spec/workflow.json")
routing = read_spec("spec/routing.json")
safety = read_spec("spec/safety-policy.json")
naming = read_spec("spec/naming.json")

for rel in workflow["required_files"]:
    assert_exists(rel)

assert_contains(routing["instructions"]["file"], routing["instructions"]["must_contain"])
assert_contains(routing["planning"]["file"], routing["planning"]["must_contain"])
assert_contains(routing["review"]["file"], routing["review"]["must_contain"])
assert_contains(workflow["planning_reference"]["file"], workflow["planning_reference"]["must_contain"])
assert_contains(workflow["review_reference"]["file"], workflow["review_reference"]["must_contain"])

for rel in routing["skills"]:
    assert_exists(rel)

for rel in safety["wrappers"]:
    assert_exists(rel)
    assert_contains(rel, safety["blocked_tokens"])

assert_contains(safety["config"]["file"], safety["config"]["must_contain"])
subagents = safety.get("subagents")
if not isinstance(subagents, list) or not subagents:
    raise SystemExit("safety.subagents must contain at least one entry")

for idx, agent in enumerate(subagents, start=1):
    if not isinstance(agent, dict):
        raise SystemExit(f"safety.subagents[{idx}] must be an object")

    rel = agent.get("file")
    patterns = agent.get("must_contain")

    if not isinstance(rel, str) or not rel:
        raise SystemExit(f"safety.subagents[{idx}].file must be a non-empty string")

    if not isinstance(patterns, list) or not all(isinstance(p, str) for p in patterns):
        raise SystemExit(f"safety.subagents[{idx}].must_contain must be a string array")

    assert_exists(rel)
    assert_contains(rel, patterns)

worker_mode = safety.get("execution_modes", {}).get("implementation_worker")
if not isinstance(worker_mode, dict):
    raise SystemExit("safety.execution_modes.implementation_worker must be set")

expected_worker_mode = {
    "sandbox_mode": "workspace-write",
    "scope": "parent_approved_small_scoped_changes",
    "delete_operations_allowed": False,
    "rename_operations_allowed": False,
    "git_mutation_allowed": False,
    "parallel_writable_agents_default": False,
}

for key, expected in expected_worker_mode.items():
    if worker_mode.get(key) != expected:
        raise SystemExit(
            f"safety.execution_modes.implementation_worker.{key} is out of contract"
        )

assert_contains(safety["requirements"]["file"], safety["requirements"]["must_contain"])
assert_contains(
    f'{safety["rules_dir"]}/30-destructive-forbidden.rules',
    safety["forbidden_delete_commands"],
)

for rel in safety.get("delegating_wrappers", []):
    assert_exists(rel)

assert_exists(safety["rules_dir"])
if "auto_net_rules_dir" in safety:
    assert_exists(safety["auto_net_rules_dir"])
assert_exists(safety["verify"])
assert_contains(
    "template/docs/reference/naming-conventions.md",
    [
        naming["plan_docs"]["pattern"],
        naming["report_docs"]["pattern"],
        naming["history_docs"]["pattern"],
    ],
)

required_paths = [
    "spec/evaluation.schema.json",
    "spec/run-manifest.schema.json",
    "spec/artifact-responsibility.json",
    "spec/change-scope-policy.json",
    "spec/failure-taxonomy.json",
    "template/.codex/templates/RUN_MANIFEST.json",
    "template/.codex/templates/EVALUATION.md",
    "template/.codex/templates/evaluation.schema.json",
    "template/docs/reference/run-artifacts.md",
    "template/docs/reference/failure-taxonomy.md",
    "template/docs/reference/evaluation.md",
    "template/docs/reference/change-scope-policy.md",
]
for rel in required_paths:
    assert_exists(rel)

evaluation_schema = read_spec("spec/evaluation.schema.json")
bundled_evaluation_schema = read_spec("template/.codex/templates/evaluation.schema.json")
run_manifest_schema = read_spec("spec/run-manifest.schema.json")
artifact_responsibility = read_spec("spec/artifact-responsibility.json")
change_scope_policy = read_spec("spec/change-scope-policy.json")
failure_taxonomy = read_spec("spec/failure-taxonomy.json")
run_manifest_template = read_spec("template/.codex/templates/RUN_MANIFEST.json")

ensure(
    artifact_responsibility.get("catalog_type") == "static_artifact_responsibility_catalog",
    "spec/artifact-responsibility.json catalog_type is out of contract",
)
ensure(
    failure_taxonomy.get("catalog_type") == "static_failure_taxonomy_catalog",
    "spec/failure-taxonomy.json catalog_type is out of contract",
)
ensure(
    change_scope_policy.get("catalog_type") == "static_change_scope_policy_catalog",
    "spec/change-scope-policy.json catalog_type is out of contract",
)
ensure(
    change_scope_policy.get("schema_version") == 1,
    "spec/change-scope-policy.json schema_version is out of contract",
)

path_normalization = change_scope_policy.get("path_normalization", {})
ensure(
    path_normalization.get("canonical_format") == "repo_relative_posix",
    "spec/change-scope-policy.json path_normalization.canonical_format is out of contract",
)
ensure(
    path_normalization.get("windows_separator_normalization") is True,
    "spec/change-scope-policy.json path_normalization.windows_separator_normalization is out of contract",
)
ensure(
    path_normalization.get("absolute_paths_for_comparison") is False,
    "spec/change-scope-policy.json path_normalization.absolute_paths_for_comparison is out of contract",
)
ensure(
    path_normalization.get("prevent_repo_escape") is True,
    "spec/change-scope-policy.json path_normalization.prevent_repo_escape is out of contract",
)
ensure(
    path_normalization.get("case_sensitive") is True,
    "spec/change-scope-policy.json path_normalization.case_sensitive is out of contract",
)

expect_enum_set(
    change_scope_policy.get("changed_file_kinds", []),
    [
        "modified",
        "added",
        "untracked",
        "deleted",
        "renamed_old",
        "renamed_new",
        "copied_new",
    ],
    "spec/change-scope-policy.json changed_file_kinds",
)
expect_enum_set(
    change_scope_policy.get("generated_artifact_exclusions", []),
    [".codex/runs/"],
    "spec/change-scope-policy.json generated_artifact_exclusions",
)

allowed_files = change_scope_policy.get("allowed_files", {})
ensure(
    allowed_files.get("meaning") == "maximum_change_boundary",
    "spec/change-scope-policy.json allowed_files.meaning is out of contract",
)
ensure(
    allowed_files.get("match_mode") == "exact_path",
    "spec/change-scope-policy.json allowed_files.match_mode is out of contract",
)
ensure(
    allowed_files.get("glob_support") == "deferred",
    "spec/change-scope-policy.json allowed_files.glob_support is out of contract",
)
ensure(
    allowed_files.get("scope_violation_when_not_allowed") is True,
    "spec/change-scope-policy.json allowed_files.scope_violation_when_not_allowed is out of contract",
)

expected_changed_files = change_scope_policy.get("expected_changed_files", {})
ensure(
    expected_changed_files.get("meaning") == "expected_required_changes",
    "spec/change-scope-policy.json expected_changed_files.meaning is out of contract",
)
ensure(
    expected_changed_files.get("must_be_subset_of_allowed_files") == "recommended",
    "spec/change-scope-policy.json expected_changed_files.must_be_subset_of_allowed_files is out of contract",
)
ensure(
    expected_changed_files.get("missing_expected_change_severity") == "warning_or_failure_candidate",
    "spec/change-scope-policy.json expected_changed_files.missing_expected_change_severity is out of contract",
)

deleted_files = change_scope_policy.get("deleted_files", {})
ensure(
    deleted_files.get("included_in_changed_files") is True,
    "spec/change-scope-policy.json deleted_files.included_in_changed_files is out of contract",
)
ensure(
    deleted_files.get("requires_allowed_path") is True,
    "spec/change-scope-policy.json deleted_files.requires_allowed_path is out of contract",
)

renamed_files = change_scope_policy.get("renamed_files", {})
ensure(
    renamed_files.get("evaluate_old_path") is True,
    "spec/change-scope-policy.json renamed_files.evaluate_old_path is out of contract",
)
ensure(
    renamed_files.get("evaluate_new_path") is True,
    "spec/change-scope-policy.json renamed_files.evaluate_new_path is out of contract",
)
ensure(
    renamed_files.get("new_path_requires_allowed_path") is True,
    "spec/change-scope-policy.json renamed_files.new_path_requires_allowed_path is out of contract",
)

copied_files = change_scope_policy.get("copied_files", {})
ensure(
    copied_files.get("evaluate_new_path") is True,
    "spec/change-scope-policy.json copied_files.evaluate_new_path is out of contract",
)
ensure(
    copied_files.get("new_path_requires_allowed_path") is True,
    "spec/change-scope-policy.json copied_files.new_path_requires_allowed_path is out of contract",
)

run_artifacts = change_scope_policy.get("run_artifacts", {})
ensure(
    run_artifacts.get("path_prefix") == ".codex/runs/",
    "spec/change-scope-policy.json run_artifacts.path_prefix is out of contract",
)
ensure(
    run_artifacts.get("excluded_from_scope_check") is True,
    "spec/change-scope-policy.json run_artifacts.excluded_from_scope_check is out of contract",
)
ensure(
    run_artifacts.get("may_be_recorded_in_manifest") is True,
    "spec/change-scope-policy.json run_artifacts.may_be_recorded_in_manifest is out of contract",
)
ensure(
    run_artifacts.get("must_not_be_mixed_with_source_changes") is True,
    "spec/change-scope-policy.json run_artifacts.must_not_be_mixed_with_source_changes is out of contract",
)

deferred = change_scope_policy.get("deferred", {})
ensure(
    deferred.get("runner_enforcement") is False,
    "spec/change-scope-policy.json deferred.runner_enforcement is out of contract",
)
ensure(
    deferred.get("glob_matching") is True,
    "spec/change-scope-policy.json deferred.glob_matching is out of contract",
)
ensure(
    deferred.get("changed_files_collection") is False,
    "spec/change-scope-policy.json deferred.changed_files_collection is out of contract",
)

taxonomy_entries = failure_taxonomy.get("categories")
ensure(isinstance(taxonomy_entries, list) and taxonomy_entries, "spec/failure-taxonomy.json categories must be a non-empty array")

taxonomy_categories = []
for index, item in enumerate(taxonomy_entries, start=1):
    ensure(isinstance(item, dict), f"spec/failure-taxonomy.json categories[{index}] must be an object")
    category = item.get("category")
    ensure(isinstance(category, str) and category, f"spec/failure-taxonomy.json categories[{index}].category must be a non-empty string")
    taxonomy_categories.append(category)

ensure(
    len(taxonomy_categories) == len(set(taxonomy_categories)),
    "spec/failure-taxonomy.json categories must not contain duplicates",
)

required_categories = [
    "instruction_gap",
    "scope_creep",
    "missing_context",
    "missing_validation",
    "unsafe_action_blocked",
    "bad_subagent_delegation",
    "flaky_or_env_issue",
    "review_gap",
    "repair_loop_stalled",
    "artifact_contract_gap",
]
expect_enum_contains(taxonomy_categories, required_categories, "spec/failure-taxonomy.json categories")

evaluation_props = evaluation_schema.get("properties", {})
expect_required_fields(
    evaluation_schema,
    [
        "schema_version",
        "run_id",
        "result",
        "primary_failure_category",
        "failure_categories",
        "dimensions",
        "findings",
        "improvement_candidates",
    ],
    "spec/evaluation.schema.json",
)
expect_property_keys(
    evaluation_schema,
    [
        "schema_version",
        "run_id",
        "result",
        "primary_failure_category",
        "failure_categories",
        "dimensions",
        "findings",
        "improvement_candidates",
    ],
    "spec/evaluation.schema.json",
)
expect_enum_contains(
    evaluation_props["result"]["enum"],
    ["pass", "partial", "fail", "not_evaluated"],
    "spec/evaluation.schema.json result",
)
expect_enum_set(
    evaluation_props["primary_failure_category"]["enum"],
    taxonomy_categories + [None],
    "spec/evaluation.schema.json primary_failure_category",
)
expect_enum_set(
    evaluation_props["failure_categories"]["items"]["enum"],
    taxonomy_categories,
    "spec/evaluation.schema.json failure_categories items",
)
ensure(
    bundled_evaluation_schema == evaluation_schema,
    "template/.codex/templates/evaluation.schema.json must stay in sync with spec/evaluation.schema.json",
)

dimension_names = [
    "task_completion",
    "scope_control",
    "validation_confidence",
    "safety_compliance",
    "reviewability",
    "maintainability",
    "reproducibility",
]
dimensions_schema = evaluation_props["dimensions"]
expect_required_fields(dimensions_schema, dimension_names, "spec/evaluation.schema.json dimensions")
expect_property_keys(dimensions_schema, dimension_names, "spec/evaluation.schema.json dimensions")
for name in dimension_names:
    dimension_schema = dimensions_schema["properties"][name]
    expect_required_fields(dimension_schema, ["rating", "evidence"], f"spec/evaluation.schema.json dimensions.{name}")
    expect_property_keys(dimension_schema, ["rating", "evidence"], f"spec/evaluation.schema.json dimensions.{name}")
    expect_enum_contains(
        dimension_schema["properties"]["rating"]["enum"],
        ["pass", "warn", "fail", "not_evaluated"],
        f"spec/evaluation.schema.json dimensions.{name}.rating",
    )

findings_item = evaluation_props["findings"]["items"]
expect_required_fields(
    findings_item,
    ["category", "severity", "evidence", "detail"],
    "spec/evaluation.schema.json findings item",
)
expect_property_keys(
    findings_item,
    ["category", "severity", "evidence", "detail"],
    "spec/evaluation.schema.json findings item",
)
expect_enum_set(
    findings_item["properties"]["category"]["enum"],
    taxonomy_categories,
    "spec/evaluation.schema.json findings.category",
)
expect_enum_contains(
    findings_item["properties"]["severity"]["enum"],
    ["low", "medium", "high", "critical"],
    "spec/evaluation.schema.json findings.severity",
)

improvement_item = evaluation_props["improvement_candidates"]["items"]
expect_required_fields(
    improvement_item,
    ["target", "evidence", "expected_impact", "recommendation"],
    "spec/evaluation.schema.json improvement_candidates item",
)
expect_property_keys(
    improvement_item,
    ["target", "evidence", "expected_impact", "recommendation"],
    "spec/evaluation.schema.json improvement_candidates item",
)

run_manifest_props = run_manifest_schema.get("properties", {})
expect_required_fields(
    run_manifest_schema,
    [
        "schema_version",
        "run_id",
        "task_type",
        "workflow_level",
        "preset",
        "runtime",
        "agents_used",
        "repo",
        "branch",
        "base_branch",
        "codex_task_reports",
        "changed_files",
        "validation",
        "safety",
        "evaluation_path",
        "status",
        "primary_failure_category",
    ],
    "spec/run-manifest.schema.json",
)
expect_property_keys(
    run_manifest_schema,
    [
        "schema_version",
        "run_id",
        "task_type",
        "workflow_level",
        "preset",
        "runtime",
        "agents_used",
        "repo",
        "branch",
        "base_branch",
        "codex_task_reports",
        "changed_files",
        "validation",
        "safety",
        "evaluation_path",
        "status",
        "primary_failure_category",
    ],
    "spec/run-manifest.schema.json",
)
expect_enum_contains(
    run_manifest_props["task_type"]["enum"],
    ["plan", "review", "implementation", "investigation", "repair"],
    "spec/run-manifest.schema.json task_type",
)
expect_enum_contains(
    run_manifest_props["workflow_level"]["enum"],
    ["lightweight", "standard", "strict"],
    "spec/run-manifest.schema.json workflow_level",
)
expect_enum_contains(
    run_manifest_props["preset"]["enum"],
    ["safe", "readonly", "auto-net"],
    "spec/run-manifest.schema.json preset",
)
expect_enum_contains(
    run_manifest_props["runtime"]["enum"],
    ["host", "docker-sandbox", "sdk"],
    "spec/run-manifest.schema.json runtime",
)
expect_enum_contains(
    run_manifest_props["status"]["enum"],
    ["pending", "running", "completed", "failed", "cancelled"],
    "spec/run-manifest.schema.json status",
)
validation_schema = run_manifest_props["validation"]
expect_required_fields(validation_schema, ["status", "commands"], "spec/run-manifest.schema.json validation")
expect_property_keys(validation_schema, ["status", "commands"], "spec/run-manifest.schema.json validation")
expect_enum_contains(
    validation_schema["properties"]["status"]["enum"],
    ["not_run", "passed", "failed", "skipped", "blocked"],
    "spec/run-manifest.schema.json validation.status",
)
validation_command_item = validation_schema["properties"]["commands"]["items"]
expect_required_fields(
    validation_command_item,
    ["command", "exit_code", "status", "evidence"],
    "spec/run-manifest.schema.json validation.commands item",
)
expect_property_keys(
    validation_command_item,
    ["command", "exit_code", "status", "evidence"],
    "spec/run-manifest.schema.json validation.commands item",
)
expect_enum_contains(
    validation_command_item["properties"]["status"]["enum"],
    ["not_run", "passed", "failed", "skipped", "blocked"],
    "spec/run-manifest.schema.json validation.commands[].status",
)

safety_schema = run_manifest_props["safety"]
expect_required_fields(
    safety_schema,
    ["network", "delete_attempt_blocked", "git_mutation_attempt_blocked", "scope_violation"],
    "spec/run-manifest.schema.json safety",
)
expect_property_keys(
    safety_schema,
    ["network", "delete_attempt_blocked", "git_mutation_attempt_blocked", "scope_violation"],
    "spec/run-manifest.schema.json safety",
)
expect_enum_set(
    run_manifest_props["primary_failure_category"]["enum"],
    taxonomy_categories + [None],
    "spec/run-manifest.schema.json primary_failure_category",
)

template_keys = set(run_manifest_template.keys())
schema_required = set(run_manifest_schema.get("required", []))
missing_template_keys = sorted(schema_required - template_keys)
ensure(not missing_template_keys, f"template/.codex/templates/RUN_MANIFEST.json missing required keys: {missing_template_keys}")
ensure(run_manifest_template.get("schema_version") == 1, "template/.codex/templates/RUN_MANIFEST.json schema_version must be 1")
ensure(run_manifest_template.get("run_id") != "", "template/.codex/templates/RUN_MANIFEST.json run_id must not be empty")
ensure(run_manifest_template.get("status") == "pending", "template/.codex/templates/RUN_MANIFEST.json status must default to pending")
ensure(run_manifest_template.get("primary_failure_category") is None, "template/.codex/templates/RUN_MANIFEST.json primary_failure_category must default to null")
ensure(
    isinstance(run_manifest_template.get("validation"), dict)
    and run_manifest_template["validation"].get("status") == "not_run"
    and isinstance(run_manifest_template["validation"].get("commands"), list)
    and len(run_manifest_template["validation"]["commands"]) == 0,
    "template/.codex/templates/RUN_MANIFEST.json validation defaults are out of contract",
)
ensure(
    isinstance(run_manifest_template.get("safety"), dict)
    and set(run_manifest_template["safety"].keys()) == {
        "network",
        "delete_attempt_blocked",
        "git_mutation_attempt_blocked",
        "scope_violation",
    },
    "template/.codex/templates/RUN_MANIFEST.json safety keys are out of contract",
)

assert_contains(
    "template/.codex/templates/EVALUATION.md",
    [
        "evaluation.json",
        "spec/failure-taxonomy.json",
        "<run_id>",
        "not_evaluated",
        "rating",
        "evidence",
        "improvement_candidates",
        "Do not hand-write",
        "changed_files",
        "exit code",
    ],
)

print("PASS: spec validation")
PY
