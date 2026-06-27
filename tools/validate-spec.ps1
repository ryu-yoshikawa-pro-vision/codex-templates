[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Read-SpecFile {
    param([string]$RelativePath)
    $fullPath = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path $fullPath)) {
        throw "Spec file not found: $RelativePath"
    }
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    return ([System.IO.File]::ReadAllText($fullPath, $utf8) | ConvertFrom-Json)
}

function Assert-Exists {
    param([string]$RelativePath)
    if (-not (Test-Path (Join-Path $repoRoot $RelativePath))) {
        throw "Required path missing: $RelativePath"
    }
}

function Assert-Contains {
    param(
        [string]$RelativePath,
        [string[]]$Patterns
    )
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $content = [System.IO.File]::ReadAllText((Join-Path $repoRoot $RelativePath), $utf8)
    foreach ($pattern in $Patterns) {
        if ($content -notmatch [regex]::Escape($pattern)) {
            throw "Pattern '$pattern' not found in $RelativePath"
        }
    }
}

function Normalize-ToArray {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array]) {
        return @($Value)
    }

    return @($Value)
}

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-EnumValueKey {
    param($Value)

    if ($null -eq $Value) {
        return '<null>'
    }

    return [string]$Value
}

function Expect-RequiredFields {
    param(
        $Schema,
        [string[]]$Fields,
        [string]$Label
    )

    $required = Normalize-ToArray $Schema.required
    $missing = @($Fields | Where-Object { $_ -notin $required })
    if ($missing.Count -gt 0) {
        throw "$Label missing required fields: $($missing -join ', ')"
    }
}

function Expect-PropertyKeys {
    param(
        $Schema,
        [string[]]$Fields,
        [string]$Label
    )

    $propertyNames = @($Schema.properties.PSObject.Properties.Name)
    $missing = @($Fields | Where-Object { $_ -notin $propertyNames })
    if ($missing.Count -gt 0) {
        throw "$Label missing properties: $($missing -join ', ')"
    }
}

function Expect-EnumContains {
    param(
        $Values,
        [object[]]$Expected,
        [string]$Label
    )

    $actual = Normalize-ToArray $Values
    $missing = @($Expected | Where-Object { $_ -notin $actual })
    if ($missing.Count -gt 0) {
        throw "$Label missing enum values: $($missing -join ', ')"
    }
}

function Expect-EnumSet {
    param(
        $Values,
        [object[]]$Expected,
        [string]$Label
    )

    $actualKeys = @(Normalize-ToArray $Values | ForEach-Object { Get-EnumValueKey $_ } | Sort-Object -Unique)
    $expectedKeys = @($Expected | ForEach-Object { Get-EnumValueKey $_ } | Sort-Object -Unique)

    if ($actualKeys.Count -ne $expectedKeys.Count -or (Compare-Object -ReferenceObject $expectedKeys -DifferenceObject $actualKeys)) {
        throw "$Label enum mismatch: expected $($expectedKeys -join ', '), got $($actualKeys -join ', ')"
    }
}

$workflow = Read-SpecFile -RelativePath "spec/workflow.json"
$routing = Read-SpecFile -RelativePath "spec/routing.json"
$safety = Read-SpecFile -RelativePath "spec/safety-policy.json"
$naming = Read-SpecFile -RelativePath "spec/naming.json"

foreach ($path in $workflow.required_files) {
    Assert-Exists -RelativePath $path
}

Assert-Contains -RelativePath $routing.instructions.file -Patterns $routing.instructions.must_contain
Assert-Contains -RelativePath $routing.planning.file -Patterns $routing.planning.must_contain
Assert-Contains -RelativePath $routing.review.file -Patterns $routing.review.must_contain
Assert-Contains -RelativePath $workflow.planning_reference.file -Patterns $workflow.planning_reference.must_contain
Assert-Contains -RelativePath $workflow.review_reference.file -Patterns $workflow.review_reference.must_contain

foreach ($skillPath in $routing.skills) {
    Assert-Exists -RelativePath $skillPath
}

foreach ($wrapperPath in $safety.wrappers) {
    Assert-Exists -RelativePath $wrapperPath
    Assert-Contains -RelativePath $wrapperPath -Patterns $safety.blocked_tokens
}

Assert-Contains -RelativePath $safety.config.file -Patterns $safety.config.must_contain

$subagentIndex = 0
foreach ($agent in $safety.subagents) {
    $subagentIndex++
    if ($null -eq $agent.file -or -not ($agent.file -is [string]) -or [string]::IsNullOrWhiteSpace($agent.file)) {
        throw "safety.subagents[$subagentIndex].file must be a non-empty string"
    }

    if ($null -eq $agent.must_contain -or -not ($agent.must_contain -is [array])) {
        throw "safety.subagents[$subagentIndex].must_contain must be a string array"
    }

    foreach ($pattern in $agent.must_contain) {
        if (-not ($pattern -is [string])) {
            throw "safety.subagents[$subagentIndex].must_contain must be a string array"
        }
    }

    Assert-Exists -RelativePath $agent.file
    Assert-Contains -RelativePath $agent.file -Patterns $agent.must_contain
}

$workerMode = $safety.execution_modes.implementation_worker
if (-not $workerMode) {
    throw "safety.execution_modes.implementation_worker must be set"
}
if (
    $workerMode.sandbox_mode -ne "workspace-write" -or
    $workerMode.scope -ne "parent_approved_small_scoped_changes" -or
    $workerMode.delete_operations_allowed -ne $false -or
    $workerMode.rename_operations_allowed -ne $false -or
    $workerMode.git_mutation_allowed -ne $false -or
    $workerMode.parallel_writable_agents_default -ne $false
) {
    throw "safety.execution_modes.implementation_worker is out of contract"
}

Assert-Contains -RelativePath $safety.requirements.file -Patterns $safety.requirements.must_contain
Assert-Contains -RelativePath (Join-Path $safety.rules_dir "30-destructive-forbidden.rules") -Patterns $safety.forbidden_delete_commands

foreach ($wrapperPath in $safety.delegating_wrappers) {
    Assert-Exists -RelativePath $wrapperPath
}

Assert-Exists -RelativePath $safety.rules_dir
if ($safety.PSObject.Properties.Name -contains "auto_net_rules_dir") {
    Assert-Exists -RelativePath $safety.auto_net_rules_dir
}
Assert-Exists -RelativePath $safety.verify

Assert-Contains -RelativePath "template/docs/reference/naming-conventions.md" -Patterns @(
    $naming.plan_docs.pattern,
    $naming.report_docs.pattern,
    $naming.history_docs.pattern
)

$requiredPaths = @(
    "spec/evaluation.schema.json",
    "spec/run-manifest.schema.json",
    "spec/artifact-responsibility.json",
    "spec/change-scope-policy.json",
    "spec/failure-taxonomy.json",
    "template/.codex/templates/RUN_MANIFEST.json",
    "template/.codex/templates/EVALUATION.md",
    "template/docs/reference/run-artifacts.md",
    "template/docs/reference/failure-taxonomy.md",
    "template/docs/reference/evaluation.md",
    "template/docs/reference/change-scope-policy.md"
)

foreach ($path in $requiredPaths) {
    Assert-Exists -RelativePath $path
}

$evaluationSchema = Read-SpecFile -RelativePath "spec/evaluation.schema.json"
$runManifestSchema = Read-SpecFile -RelativePath "spec/run-manifest.schema.json"
$artifactResponsibility = Read-SpecFile -RelativePath "spec/artifact-responsibility.json"
$changeScopePolicy = Read-SpecFile -RelativePath "spec/change-scope-policy.json"
$failureTaxonomy = Read-SpecFile -RelativePath "spec/failure-taxonomy.json"
$runManifestTemplate = Read-SpecFile -RelativePath "template/.codex/templates/RUN_MANIFEST.json"

Assert-Condition ($artifactResponsibility.catalog_type -eq "static_artifact_responsibility_catalog") "spec/artifact-responsibility.json catalog_type is out of contract"
Assert-Condition ($failureTaxonomy.catalog_type -eq "static_failure_taxonomy_catalog") "spec/failure-taxonomy.json catalog_type is out of contract"
Assert-Condition ($changeScopePolicy.catalog_type -eq "static_change_scope_policy_catalog") "spec/change-scope-policy.json catalog_type is out of contract"
Assert-Condition ($changeScopePolicy.schema_version -eq 1) "spec/change-scope-policy.json schema_version is out of contract"

$pathNormalization = $changeScopePolicy.path_normalization
Assert-Condition ($pathNormalization.canonical_format -eq "repo_relative_posix") "spec/change-scope-policy.json path_normalization.canonical_format is out of contract"
Assert-Condition ($pathNormalization.windows_separator_normalization -eq $true) "spec/change-scope-policy.json path_normalization.windows_separator_normalization is out of contract"
Assert-Condition ($pathNormalization.absolute_paths_for_comparison -eq $false) "spec/change-scope-policy.json path_normalization.absolute_paths_for_comparison is out of contract"
Assert-Condition ($pathNormalization.prevent_repo_escape -eq $true) "spec/change-scope-policy.json path_normalization.prevent_repo_escape is out of contract"
Assert-Condition ($pathNormalization.case_sensitive -eq $true) "spec/change-scope-policy.json path_normalization.case_sensitive is out of contract"

Expect-EnumSet -Values $changeScopePolicy.changed_file_kinds -Expected @(
    "modified",
    "added",
    "untracked",
    "deleted",
    "renamed_old",
    "renamed_new",
    "copied_new"
) -Label "spec/change-scope-policy.json changed_file_kinds"
Expect-EnumSet -Values $changeScopePolicy.generated_artifact_exclusions -Expected @(".codex/runs/") -Label "spec/change-scope-policy.json generated_artifact_exclusions"

Assert-Condition ($changeScopePolicy.allowed_files.meaning -eq "maximum_change_boundary") "spec/change-scope-policy.json allowed_files.meaning is out of contract"
Assert-Condition ($changeScopePolicy.allowed_files.match_mode -eq "exact_path") "spec/change-scope-policy.json allowed_files.match_mode is out of contract"
Assert-Condition ($changeScopePolicy.allowed_files.glob_support -eq "deferred") "spec/change-scope-policy.json allowed_files.glob_support is out of contract"
Assert-Condition ($changeScopePolicy.allowed_files.scope_violation_when_not_allowed -eq $true) "spec/change-scope-policy.json allowed_files.scope_violation_when_not_allowed is out of contract"
Assert-Condition ($changeScopePolicy.expected_changed_files.meaning -eq "expected_required_changes") "spec/change-scope-policy.json expected_changed_files.meaning is out of contract"
Assert-Condition ($changeScopePolicy.expected_changed_files.must_be_subset_of_allowed_files -eq "recommended") "spec/change-scope-policy.json expected_changed_files.must_be_subset_of_allowed_files is out of contract"
Assert-Condition ($changeScopePolicy.expected_changed_files.missing_expected_change_severity -eq "warning_or_failure_candidate") "spec/change-scope-policy.json expected_changed_files.missing_expected_change_severity is out of contract"
Assert-Condition ($changeScopePolicy.deleted_files.included_in_changed_files -eq $true) "spec/change-scope-policy.json deleted_files.included_in_changed_files is out of contract"
Assert-Condition ($changeScopePolicy.deleted_files.requires_allowed_path -eq $true) "spec/change-scope-policy.json deleted_files.requires_allowed_path is out of contract"
Assert-Condition ($changeScopePolicy.renamed_files.evaluate_old_path -eq $true) "spec/change-scope-policy.json renamed_files.evaluate_old_path is out of contract"
Assert-Condition ($changeScopePolicy.renamed_files.evaluate_new_path -eq $true) "spec/change-scope-policy.json renamed_files.evaluate_new_path is out of contract"
Assert-Condition ($changeScopePolicy.renamed_files.new_path_requires_allowed_path -eq $true) "spec/change-scope-policy.json renamed_files.new_path_requires_allowed_path is out of contract"
Assert-Condition ($changeScopePolicy.copied_files.evaluate_new_path -eq $true) "spec/change-scope-policy.json copied_files.evaluate_new_path is out of contract"
Assert-Condition ($changeScopePolicy.copied_files.new_path_requires_allowed_path -eq $true) "spec/change-scope-policy.json copied_files.new_path_requires_allowed_path is out of contract"
Assert-Condition ($changeScopePolicy.run_artifacts.path_prefix -eq ".codex/runs/") "spec/change-scope-policy.json run_artifacts.path_prefix is out of contract"
Assert-Condition ($changeScopePolicy.run_artifacts.excluded_from_scope_check -eq $true) "spec/change-scope-policy.json run_artifacts.excluded_from_scope_check is out of contract"
Assert-Condition ($changeScopePolicy.run_artifacts.may_be_recorded_in_manifest -eq $true) "spec/change-scope-policy.json run_artifacts.may_be_recorded_in_manifest is out of contract"
Assert-Condition ($changeScopePolicy.run_artifacts.must_not_be_mixed_with_source_changes -eq $true) "spec/change-scope-policy.json run_artifacts.must_not_be_mixed_with_source_changes is out of contract"
Assert-Condition ($changeScopePolicy.deferred.runner_enforcement -eq $true) "spec/change-scope-policy.json deferred.runner_enforcement is out of contract"
Assert-Condition ($changeScopePolicy.deferred.glob_matching -eq $true) "spec/change-scope-policy.json deferred.glob_matching is out of contract"
Assert-Condition ($changeScopePolicy.deferred.changed_files_collection -eq $true) "spec/change-scope-policy.json deferred.changed_files_collection is out of contract"

$taxonomyEntries = Normalize-ToArray $failureTaxonomy.categories
Assert-Condition ($taxonomyEntries.Count -gt 0) "spec/failure-taxonomy.json categories must be a non-empty array"

$taxonomyCategories = @()
$categoryIndex = 0
foreach ($entry in $taxonomyEntries) {
    $categoryIndex++
    Assert-Condition ($entry -is [pscustomobject]) "spec/failure-taxonomy.json categories[$categoryIndex] must be an object"
    Assert-Condition (($entry.category -is [string]) -and -not [string]::IsNullOrWhiteSpace($entry.category)) "spec/failure-taxonomy.json categories[$categoryIndex].category must be a non-empty string"
    $taxonomyCategories += $entry.category
}

$duplicateCategories = @($taxonomyCategories | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name)
Assert-Condition ($duplicateCategories.Count -eq 0) "spec/failure-taxonomy.json categories must not contain duplicates"

$requiredCategories = @(
    "instruction_gap",
    "scope_creep",
    "missing_context",
    "missing_validation",
    "unsafe_action_blocked",
    "bad_subagent_delegation",
    "flaky_or_env_issue",
    "review_gap",
    "repair_loop_stalled",
    "artifact_contract_gap"
)
Expect-EnumContains -Values $taxonomyCategories -Expected $requiredCategories -Label "spec/failure-taxonomy.json categories"

Expect-RequiredFields -Schema $evaluationSchema -Fields @(
    "schema_version",
    "run_id",
    "result",
    "primary_failure_category",
    "failure_categories",
    "dimensions",
    "findings",
    "improvement_candidates"
) -Label "spec/evaluation.schema.json"
Expect-PropertyKeys -Schema $evaluationSchema -Fields @(
    "schema_version",
    "run_id",
    "result",
    "primary_failure_category",
    "failure_categories",
    "dimensions",
    "findings",
    "improvement_candidates"
) -Label "spec/evaluation.schema.json"

Expect-EnumContains -Values $evaluationSchema.properties.result.enum -Expected @("pass", "partial", "fail", "not_evaluated") -Label "spec/evaluation.schema.json result"
Expect-EnumSet -Values $evaluationSchema.properties.primary_failure_category.enum -Expected ($taxonomyCategories + @($null)) -Label "spec/evaluation.schema.json primary_failure_category"
Expect-EnumSet -Values $evaluationSchema.properties.failure_categories.items.enum -Expected $taxonomyCategories -Label "spec/evaluation.schema.json failure_categories items"

$dimensionNames = @(
    "task_completion",
    "scope_control",
    "validation_confidence",
    "safety_compliance",
    "reviewability",
    "maintainability",
    "reproducibility"
)
$dimensionsSchema = $evaluationSchema.properties.dimensions
Expect-RequiredFields -Schema $dimensionsSchema -Fields $dimensionNames -Label "spec/evaluation.schema.json dimensions"
Expect-PropertyKeys -Schema $dimensionsSchema -Fields $dimensionNames -Label "spec/evaluation.schema.json dimensions"
foreach ($name in $dimensionNames) {
    $dimensionSchema = $dimensionsSchema.properties.$name
    Expect-RequiredFields -Schema $dimensionSchema -Fields @("rating", "evidence") -Label "spec/evaluation.schema.json dimensions.$name"
    Expect-PropertyKeys -Schema $dimensionSchema -Fields @("rating", "evidence") -Label "spec/evaluation.schema.json dimensions.$name"
    Expect-EnumContains -Values $dimensionSchema.properties.rating.enum -Expected @("pass", "warn", "fail", "not_evaluated") -Label "spec/evaluation.schema.json dimensions.$name.rating"
}

$findingsItem = $evaluationSchema.properties.findings.items
Expect-RequiredFields -Schema $findingsItem -Fields @("category", "severity", "evidence", "detail") -Label "spec/evaluation.schema.json findings item"
Expect-PropertyKeys -Schema $findingsItem -Fields @("category", "severity", "evidence", "detail") -Label "spec/evaluation.schema.json findings item"
Expect-EnumSet -Values $findingsItem.properties.category.enum -Expected $taxonomyCategories -Label "spec/evaluation.schema.json findings.category"
Expect-EnumContains -Values $findingsItem.properties.severity.enum -Expected @("low", "medium", "high", "critical") -Label "spec/evaluation.schema.json findings.severity"

$improvementItem = $evaluationSchema.properties.improvement_candidates.items
Expect-RequiredFields -Schema $improvementItem -Fields @("target", "evidence", "expected_impact", "recommendation") -Label "spec/evaluation.schema.json improvement_candidates item"
Expect-PropertyKeys -Schema $improvementItem -Fields @("target", "evidence", "expected_impact", "recommendation") -Label "spec/evaluation.schema.json improvement_candidates item"

Expect-RequiredFields -Schema $runManifestSchema -Fields @(
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
    "primary_failure_category"
) -Label "spec/run-manifest.schema.json"
Expect-PropertyKeys -Schema $runManifestSchema -Fields @(
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
    "primary_failure_category"
) -Label "spec/run-manifest.schema.json"

Expect-EnumContains -Values $runManifestSchema.properties.task_type.enum -Expected @("plan", "review", "implementation", "investigation", "repair") -Label "spec/run-manifest.schema.json task_type"
Expect-EnumContains -Values $runManifestSchema.properties.workflow_level.enum -Expected @("lightweight", "standard", "strict") -Label "spec/run-manifest.schema.json workflow_level"
Expect-EnumContains -Values $runManifestSchema.properties.preset.enum -Expected @("safe", "readonly", "auto-net") -Label "spec/run-manifest.schema.json preset"
Expect-EnumContains -Values $runManifestSchema.properties.runtime.enum -Expected @("host", "docker-sandbox", "sdk") -Label "spec/run-manifest.schema.json runtime"
Expect-EnumContains -Values $runManifestSchema.properties.status.enum -Expected @("pending", "running", "completed", "failed", "cancelled") -Label "spec/run-manifest.schema.json status"
Expect-EnumSet -Values $runManifestSchema.properties.primary_failure_category.enum -Expected ($taxonomyCategories + @($null)) -Label "spec/run-manifest.schema.json primary_failure_category"

$validationSchema = $runManifestSchema.properties.validation
Expect-RequiredFields -Schema $validationSchema -Fields @("status", "commands") -Label "spec/run-manifest.schema.json validation"
Expect-PropertyKeys -Schema $validationSchema -Fields @("status", "commands") -Label "spec/run-manifest.schema.json validation"
Expect-EnumContains -Values $validationSchema.properties.status.enum -Expected @("not_run", "passed", "failed", "skipped", "blocked") -Label "spec/run-manifest.schema.json validation.status"

$validationCommandItem = $validationSchema.properties.commands.items
Expect-RequiredFields -Schema $validationCommandItem -Fields @("command", "exit_code", "status", "evidence") -Label "spec/run-manifest.schema.json validation.commands item"
Expect-PropertyKeys -Schema $validationCommandItem -Fields @("command", "exit_code", "status", "evidence") -Label "spec/run-manifest.schema.json validation.commands item"
Expect-EnumContains -Values $validationCommandItem.properties.status.enum -Expected @("not_run", "passed", "failed", "skipped", "blocked") -Label "spec/run-manifest.schema.json validation.commands[].status"

$safetySchema = $runManifestSchema.properties.safety
Expect-RequiredFields -Schema $safetySchema -Fields @("network", "delete_attempt_blocked", "git_mutation_attempt_blocked", "scope_violation") -Label "spec/run-manifest.schema.json safety"
Expect-PropertyKeys -Schema $safetySchema -Fields @("network", "delete_attempt_blocked", "git_mutation_attempt_blocked", "scope_violation") -Label "spec/run-manifest.schema.json safety"

$templateKeys = @($runManifestTemplate.PSObject.Properties.Name)
$requiredManifestKeys = @(Normalize-ToArray $runManifestSchema.required)
$missingTemplateKeys = @($requiredManifestKeys | Where-Object { $_ -notin $templateKeys })
Assert-Condition ($missingTemplateKeys.Count -eq 0) "template/.codex/templates/RUN_MANIFEST.json missing required keys: $($missingTemplateKeys -join ', ')"
Assert-Condition ($runManifestTemplate.schema_version -eq 1) "template/.codex/templates/RUN_MANIFEST.json schema_version must be 1"
Assert-Condition ($runManifestTemplate.run_id -ne "") "template/.codex/templates/RUN_MANIFEST.json run_id must not be empty"
Assert-Condition ($runManifestTemplate.status -eq "pending") "template/.codex/templates/RUN_MANIFEST.json status must default to pending"
Assert-Condition ($null -eq $runManifestTemplate.primary_failure_category) "template/.codex/templates/RUN_MANIFEST.json primary_failure_category must default to null"
Assert-Condition (($runManifestTemplate.validation -is [pscustomobject]) -and ($runManifestTemplate.validation.status -eq "not_run") -and (@(Normalize-ToArray $runManifestTemplate.validation.commands).Count -eq 0)) "template/.codex/templates/RUN_MANIFEST.json validation defaults are out of contract"
Assert-Condition ($runManifestTemplate.safety -is [pscustomobject]) "template/.codex/templates/RUN_MANIFEST.json safety must be an object"
$safetyTemplateKeys = @($runManifestTemplate.safety.PSObject.Properties.Name | Sort-Object)
$expectedSafetyKeys = @("delete_attempt_blocked", "git_mutation_attempt_blocked", "network", "scope_violation") | Sort-Object
Assert-Condition (-not (Compare-Object -ReferenceObject $expectedSafetyKeys -DifferenceObject $safetyTemplateKeys)) "template/.codex/templates/RUN_MANIFEST.json safety keys are out of contract"

Assert-Contains -RelativePath "template/.codex/templates/EVALUATION.md" -Patterns @(
    "evaluation.json",
    "spec/failure-taxonomy.json",
    "<run_id>",
    "not_evaluated",
    "rating",
    "evidence",
    "improvement_candidates",
    "Do not hand-write",
    "changed_files",
    "exit code"
)

Write-Host "PASS: spec validation"
