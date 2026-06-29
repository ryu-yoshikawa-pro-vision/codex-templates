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

function Read-JsonFile {
    param([string]$RelativePath)
    $fullPath = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path $fullPath)) {
        throw "JSON file not found: $RelativePath"
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

function Test-IsJsonObjectLike {
    param([Parameter(Mandatory = $false)]$Value)

    if ($null -eq $Value) {
        return $false
    }

    return ($Value -is [System.Collections.IDictionary]) -or
        ($Value -is [pscustomobject]) -or
        ($Value.PSObject.TypeNames -contains 'System.Management.Automation.PSCustomObject')
}

function Get-JsonObjectPropertyNames {
    param([Parameter(Mandatory = $true)]$Value)

    if ($Value -is [System.Collections.IDictionary]) {
        return @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    }

    return @($Value.PSObject.Properties | Select-Object -ExpandProperty Name | Sort-Object)
}

function Get-JsonObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($Value -is [System.Collections.IDictionary]) {
        return $Value[$Name]
    }

    return $Value.PSObject.Properties[$Name].Value
}

function Test-JsonStructureEqual {
    param(
        [Parameter(Mandatory = $false)]$Left,
        [Parameter(Mandatory = $false)]$Right
    )

    if ($null -eq $Left -or $null -eq $Right) {
        return ($null -eq $Left -and $null -eq $Right)
    }

    $leftIsObject = Test-IsJsonObjectLike -Value $Left
    $rightIsObject = Test-IsJsonObjectLike -Value $Right
    if ($leftIsObject -or $rightIsObject) {
        if (-not ($leftIsObject -and $rightIsObject)) {
            return $false
        }

        $leftNames = @(Get-JsonObjectPropertyNames -Value $Left)
        $rightNames = @(Get-JsonObjectPropertyNames -Value $Right)
        if ($leftNames.Count -ne $rightNames.Count -or (Compare-Object -ReferenceObject $leftNames -DifferenceObject $rightNames)) {
            return $false
        }

        foreach ($name in $leftNames) {
            if (-not (Test-JsonStructureEqual -Left (Get-JsonObjectPropertyValue -Value $Left -Name $name) -Right (Get-JsonObjectPropertyValue -Value $Right -Name $name))) {
                return $false
            }
        }
        return $true
    }

    $leftIsArray = ($Left -is [System.Collections.IEnumerable] -and -not ($Left -is [string]))
    $rightIsArray = ($Right -is [System.Collections.IEnumerable] -and -not ($Right -is [string]))
    if ($leftIsArray -or $rightIsArray) {
        if (-not ($leftIsArray -and $rightIsArray)) {
            return $false
        }

        $leftItems = @(Normalize-ToArray $Left)
        $rightItems = @(Normalize-ToArray $Right)
        if ($leftItems.Count -ne $rightItems.Count) {
            return $false
        }

        for ($index = 0; $index -lt $leftItems.Count; $index++) {
            if (-not (Test-JsonStructureEqual -Left $leftItems[$index] -Right $rightItems[$index])) {
                return $false
            }
        }
        return $true
    }

    return ($Left -eq $Right)
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

function Test-SemVer {
    param([Parameter(Mandatory = $true)][string]$Value)
    return ($Value -match '^\d+\.\d+\.\d+$')
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

function Expect-Sequence {
    param(
        $Values,
        [object[]]$Expected,
        [string]$Label
    )

    $actual = Normalize-ToArray $Values
    if ($actual.Count -ne $Expected.Count) {
        throw "$Label sequence length mismatch: expected $($Expected.Count), got $($actual.Count)"
    }

    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ([string]$actual[$index] -cne [string]$Expected[$index]) {
            throw "${Label} sequence mismatch at index ${index}: expected '$($Expected[$index])', got '$($actual[$index])'"
        }
    }
}

function Invoke-OutputSchemaValidation {
    param(
        [string]$SchemaRelativePath,
        [string]$OutputRelativePath
    )

    $validator = Join-Path $repoRoot "template/scripts/validate-output-schema.py"
    $schemaPath = Join-Path $repoRoot $SchemaRelativePath
    $outputPath = Join-Path $repoRoot $OutputRelativePath

    $pythonPath = $null
    $pythonArgs = @()
    $pythonCandidates = @(
        @{ Command = "python3"; Args = @() },
        @{ Command = "python"; Args = @() },
        @{ Command = "py"; Args = @("-3") }
    )
    foreach ($candidate in $pythonCandidates) {
        $cmd = Get-Command $candidate.Command -ErrorAction SilentlyContinue
        if (-not $cmd) {
            continue
        }

        $commandPath = if ($cmd.Path) { $cmd.Path } elseif ($cmd.Source) { $cmd.Source } else { $cmd.Name }
        $checkArgs = @($candidate.Args) + @("-c", "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)")
        try {
            & $commandPath @checkArgs *> $null
        }
        catch {
            continue
        }
        if ($LASTEXITCODE -eq 0) {
            $pythonPath = $commandPath
            $pythonArgs = @($candidate.Args)
            break
        }
    }
    if (-not $pythonPath) {
        throw "Python 3 is required"
    }

    & $pythonPath @pythonArgs $validator $schemaPath $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Schema validation failed for $OutputRelativePath"
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
    "spec/hook-observation.schema.json",
    "spec/subagent-run.schema.json",
    "spec/artifact-responsibility.json",
    "spec/change-scope-policy.json",
    "spec/failure-taxonomy.json",
    "template/.codex/templates/RUN_MANIFEST.json",
    "template/.codex/templates/EVALUATION.md",
    "template/.codex/templates/evaluation.schema.json",
    "template/.codex/templates/hook-observation.schema.json",
    "template/.codex/templates/subagent-run.schema.json",
    "template/.codex/hooks/pre_tool_use_policy.py",
    "template/.codex/hooks/pre_tool_use_policy.ps1",
    "template/docs/reference/run-artifacts.md",
    "template/docs/reference/failure-taxonomy.md",
    "template/docs/reference/evaluation.md",
    "template/docs/reference/change-scope-policy.md",
    "template/docs/reference/hook-observation.md",
    "template/docs/reference/subagent-observation.md",
    "template/docs/reference/codex-safety-harness.md",
    "template/docs/reference/codex-implementation-harness.md",
    "template/docs/guides/consumer-update.md",
    "template/scripts/cleanup-runs.sh",
    "template/scripts/cleanup-runs.ps1",
    "template/.codex/hooks/observe.sh",
    "template/.codex/hooks/observe.ps1",
    "tools/plan-consumer-update.sh",
    "tools/plan-consumer-update.ps1",
    "tests/integration/test-cleanup-runs.sh",
    "tests/integration/Test-CleanupRuns.ps1",
    "tests/integration/test-plan-consumer-update.sh",
    "tests/integration/Test-PlanConsumerUpdate.ps1",
    ".github/workflows/validate-template.yml"
)

foreach ($path in $requiredPaths) {
    Assert-Exists -RelativePath $path
}

$evaluationSchema = Read-SpecFile -RelativePath "spec/evaluation.schema.json"
$bundledEvaluationSchema = Read-SpecFile -RelativePath "template/.codex/templates/evaluation.schema.json"
$runManifestSchema = Read-SpecFile -RelativePath "spec/run-manifest.schema.json"
$hookObservationSchema = Read-SpecFile -RelativePath "spec/hook-observation.schema.json"
$bundledHookObservationSchema = Read-SpecFile -RelativePath "template/.codex/templates/hook-observation.schema.json"
$subagentRunSchema = Read-SpecFile -RelativePath "spec/subagent-run.schema.json"
$bundledSubagentRunSchema = Read-SpecFile -RelativePath "template/.codex/templates/subagent-run.schema.json"
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
Assert-Condition ($pathNormalization.absolute_paths_in_scope_inputs -eq $false) "spec/change-scope-policy.json path_normalization.absolute_paths_in_scope_inputs is out of contract"
Assert-Condition ($pathNormalization.prevent_repo_escape -eq $true) "spec/change-scope-policy.json path_normalization.prevent_repo_escape is out of contract"
Assert-Condition ($pathNormalization.case_sensitive -eq $true) "spec/change-scope-policy.json path_normalization.case_sensitive is out of contract"
Assert-Condition ($pathNormalization.directory_trailing_slash_equivalent -eq $true) "spec/change-scope-policy.json path_normalization.directory_trailing_slash_equivalent is out of contract"

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
Assert-Condition ($changeScopePolicy.allowed_files.scope_violation_when_not_allowed -eq $true) "spec/change-scope-policy.json allowed_files.scope_violation_when_not_allowed is out of contract"
Assert-Condition ($changeScopePolicy.allowed_dirs.meaning -eq "allow_descendants_of_directory") "spec/change-scope-policy.json allowed_dirs.meaning is out of contract"
Assert-Condition ($changeScopePolicy.allowed_dirs.match_mode -eq "directory_prefix") "spec/change-scope-policy.json allowed_dirs.match_mode is out of contract"
Assert-Condition ($changeScopePolicy.allowed_dirs.directory_boundary_required -eq $true) "spec/change-scope-policy.json allowed_dirs.directory_boundary_required is out of contract"
Assert-Condition ($changeScopePolicy.allowed_dirs.scope_violation_when_not_allowed -eq $true) "spec/change-scope-policy.json allowed_dirs.scope_violation_when_not_allowed is out of contract"
Assert-Condition ($changeScopePolicy.allowed_globs.meaning -eq "allow_paths_matching_limited_glob") "spec/change-scope-policy.json allowed_globs.meaning is out of contract"
Assert-Condition ($changeScopePolicy.allowed_globs.match_mode -eq "limited_glob") "spec/change-scope-policy.json allowed_globs.match_mode is out of contract"
Expect-EnumSet -Values $changeScopePolicy.allowed_globs.supported_tokens -Expected @("*", "**", "?") -Label "spec/change-scope-policy.json allowed_globs.supported_tokens"
Assert-Condition ($changeScopePolicy.allowed_globs.scope_violation_when_not_allowed -eq $true) "spec/change-scope-policy.json allowed_globs.scope_violation_when_not_allowed is out of contract"
Expect-Sequence -Values $changeScopePolicy.scope_precedence -Expected @("allowed_files", "allowed_dirs", "allowed_globs") -Label "spec/change-scope-policy.json scope_precedence"
Assert-Condition ($changeScopePolicy.expected_changed_files.meaning -eq "expected_required_changes") "spec/change-scope-policy.json expected_changed_files.meaning is out of contract"
Assert-Condition ($changeScopePolicy.expected_changed_files.must_be_subset_of_allowed_scope -eq "recommended") "spec/change-scope-policy.json expected_changed_files.must_be_subset_of_allowed_scope is out of contract"
Expect-EnumSet -Values $changeScopePolicy.expected_changed_files.missing_behavior_options -Expected @("warn", "fail") -Label "spec/change-scope-policy.json expected_changed_files.missing_behavior_options"
Assert-Condition ($changeScopePolicy.expected_changed_files.default_missing_behavior -eq "fail") "spec/change-scope-policy.json expected_changed_files.default_missing_behavior is out of contract"
Assert-Condition ($changeScopePolicy.validation_warning_record.manifest_location -eq "validation.warnings[]") "spec/change-scope-policy.json validation_warning_record.manifest_location is out of contract"
Assert-Condition ($changeScopePolicy.validation_warning_record.warning_type -eq "expected_changed_file_missing") "spec/change-scope-policy.json validation_warning_record.warning_type is out of contract"
Assert-Condition ($changeScopePolicy.validation_warning_record.warning_status -eq "passed_with_warnings") "spec/change-scope-policy.json validation_warning_record.warning_status is out of contract"
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
Assert-Condition ($changeScopePolicy.deferred.runner_enforcement -eq $false) "spec/change-scope-policy.json deferred.runner_enforcement is out of contract"
Assert-Condition ($changeScopePolicy.deferred.glob_matching -eq $false) "spec/change-scope-policy.json deferred.glob_matching is out of contract"
Assert-Condition ($changeScopePolicy.deferred.changed_files_collection -eq $false) "spec/change-scope-policy.json deferred.changed_files_collection is out of contract"

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
if (-not (Test-JsonStructureEqual -Left $bundledEvaluationSchema -Right $evaluationSchema)) {
    throw "template/.codex/templates/evaluation.schema.json must stay in sync with spec/evaluation.schema.json"
}

Assert-Condition ($hookObservationSchema.additionalProperties -eq $false) "spec/hook-observation.schema.json additionalProperties must be false"
Expect-RequiredFields -Schema $hookObservationSchema -Fields @(
    "schema_version",
    "event_id",
    "run_id",
    "timestamp",
    "source",
    "event",
    "severity",
    "blocking",
    "tool",
    "cwd",
    "input_summary",
    "decision",
    "evidence",
    "metadata"
) -Label "spec/hook-observation.schema.json"
Expect-PropertyKeys -Schema $hookObservationSchema -Fields @(
    "schema_version",
    "event_id",
    "run_id",
    "timestamp",
    "source",
    "event",
    "severity",
    "blocking",
    "tool",
    "cwd",
    "input_summary",
    "decision",
    "evidence",
    "metadata"
) -Label "spec/hook-observation.schema.json"
Expect-EnumSet -Values $hookObservationSchema.properties.schema_version.enum -Expected @(1) -Label "spec/hook-observation.schema.json schema_version"
Expect-EnumSet -Values $hookObservationSchema.properties.source.enum -Expected @("codex_hook", "codex_task", "codex_safe", "subagent", "manual", "unknown") -Label "spec/hook-observation.schema.json source"
Expect-EnumSet -Values $hookObservationSchema.properties.event.enum -Expected @("PreToolUse", "PostToolUse", "SubagentStart", "SubagentStop", "Stop", "WrapperStart", "WrapperStop", "SafetyBlocked", "ObservationError") -Label "spec/hook-observation.schema.json event"
Expect-EnumSet -Values $hookObservationSchema.properties.severity.enum -Expected @("debug", "info", "warning", "error", "critical") -Label "spec/hook-observation.schema.json severity"
Assert-Condition ($hookObservationSchema.properties.blocking.type -eq "boolean") "spec/hook-observation.schema.json blocking type is out of contract"
Expect-EnumSet -Values $hookObservationSchema.properties.tool.type -Expected @("object", "null") -Label "spec/hook-observation.schema.json tool.type"
Expect-PropertyKeys -Schema $hookObservationSchema.properties.tool -Fields @("name", "operation", "target") -Label "spec/hook-observation.schema.json tool"
$hookDecisionSchema = $hookObservationSchema.properties.decision
Expect-RequiredFields -Schema $hookDecisionSchema -Fields @("action", "reason") -Label "spec/hook-observation.schema.json decision"
Expect-PropertyKeys -Schema $hookDecisionSchema -Fields @("action", "reason") -Label "spec/hook-observation.schema.json decision"
Expect-EnumSet -Values $hookDecisionSchema.properties.action.enum -Expected @("allow", "observe", "block", "skip", "error") -Label "spec/hook-observation.schema.json decision.action"
$hookEvidenceItem = $hookObservationSchema.properties.evidence.items
Expect-RequiredFields -Schema $hookEvidenceItem -Fields @("kind", "value") -Label "spec/hook-observation.schema.json evidence item"
Expect-PropertyKeys -Schema $hookEvidenceItem -Fields @("kind", "value") -Label "spec/hook-observation.schema.json evidence item"
Expect-EnumSet -Values $hookEvidenceItem.properties.kind.enum -Expected @("path", "command", "pattern", "policy", "status", "message", "other") -Label "spec/hook-observation.schema.json evidence.kind"
Assert-Condition ($hookObservationSchema.properties.metadata.type -eq "object") "spec/hook-observation.schema.json metadata type is out of contract"
if (-not (Test-JsonStructureEqual -Left $bundledHookObservationSchema -Right $hookObservationSchema)) {
    throw "template/.codex/templates/hook-observation.schema.json must stay in sync with spec/hook-observation.schema.json"
}

Assert-Condition ($subagentRunSchema.additionalProperties -eq $false) "spec/subagent-run.schema.json additionalProperties must be false"
Expect-RequiredFields -Schema $subagentRunSchema -Fields @(
    "schema_version",
    "subagent_run_id",
    "parent_run_id",
    "agent",
    "role",
    "mode",
    "purpose",
    "sandbox",
    "allowed_files",
    "input_files",
    "changed_files",
    "scope",
    "started_at",
    "ended_at",
    "status",
    "summary",
    "parent_decision",
    "used_in_final_plan",
    "evidence",
    "metadata"
) -Label "spec/subagent-run.schema.json"
Expect-PropertyKeys -Schema $subagentRunSchema -Fields @(
    "schema_version",
    "subagent_run_id",
    "parent_run_id",
    "agent",
    "role",
    "mode",
    "purpose",
    "sandbox",
    "allowed_files",
    "input_files",
    "changed_files",
    "scope",
    "started_at",
    "ended_at",
    "status",
    "summary",
    "parent_decision",
    "used_in_final_plan",
    "evidence",
    "metadata"
) -Label "spec/subagent-run.schema.json"
Expect-EnumSet -Values $subagentRunSchema.properties.schema_version.enum -Expected @(1) -Label "spec/subagent-run.schema.json schema_version"
$agentSchema = $subagentRunSchema.properties.agent
Expect-RequiredFields -Schema $agentSchema -Fields @("name", "model") -Label "spec/subagent-run.schema.json agent"
Expect-PropertyKeys -Schema $agentSchema -Fields @("name", "model") -Label "spec/subagent-run.schema.json agent"
Expect-EnumSet -Values $subagentRunSchema.properties.role.enum -Expected @("planner", "investigator", "reviewer", "implementation_worker", "validator", "other") -Label "spec/subagent-run.schema.json role"
Expect-EnumSet -Values $subagentRunSchema.properties.mode.enum -Expected @("read_only", "writable", "hybrid", "unknown") -Label "spec/subagent-run.schema.json mode"
$sandboxSchema = $subagentRunSchema.properties.sandbox
Expect-RequiredFields -Schema $sandboxSchema -Fields @("type", "network") -Label "spec/subagent-run.schema.json sandbox"
Expect-PropertyKeys -Schema $sandboxSchema -Fields @("type", "network") -Label "spec/subagent-run.schema.json sandbox"
Expect-EnumSet -Values $sandboxSchema.properties.type.enum -Expected @("read-only", "workspace-write", "danger-full-access", "unknown") -Label "spec/subagent-run.schema.json sandbox.type"
Assert-Condition ($sandboxSchema.properties.network.type -eq "boolean") "spec/subagent-run.schema.json sandbox.network type is out of contract"
$scopeSchema = $subagentRunSchema.properties.scope
Expect-RequiredFields -Schema $scopeSchema -Fields @("declared", "compliant", "violations") -Label "spec/subagent-run.schema.json scope"
Expect-PropertyKeys -Schema $scopeSchema -Fields @("declared", "compliant", "violations") -Label "spec/subagent-run.schema.json scope"
Expect-EnumSet -Values $subagentRunSchema.properties.status.enum -Expected @("pending", "running", "completed", "failed", "cancelled", "blocked", "not_run") -Label "spec/subagent-run.schema.json status"
$parentDecisionSchema = $subagentRunSchema.properties.parent_decision
Expect-RequiredFields -Schema $parentDecisionSchema -Fields @("action", "reason") -Label "spec/subagent-run.schema.json parent_decision"
Expect-PropertyKeys -Schema $parentDecisionSchema -Fields @("action", "reason") -Label "spec/subagent-run.schema.json parent_decision"
Expect-EnumSet -Values $parentDecisionSchema.properties.action.enum -Expected @("accepted", "partially_accepted", "rejected", "deferred", "not_reviewed") -Label "spec/subagent-run.schema.json parent_decision.action"
$subagentEvidenceItem = $subagentRunSchema.properties.evidence.items
Expect-RequiredFields -Schema $subagentEvidenceItem -Fields @("kind", "value") -Label "spec/subagent-run.schema.json evidence item"
Expect-PropertyKeys -Schema $subagentEvidenceItem -Fields @("kind", "value") -Label "spec/subagent-run.schema.json evidence item"
Expect-EnumSet -Values $subagentEvidenceItem.properties.kind.enum -Expected @("path", "summary", "finding", "validation", "review_comment", "other") -Label "spec/subagent-run.schema.json evidence.kind"
Assert-Condition ($subagentRunSchema.properties.metadata.type -eq "object") "spec/subagent-run.schema.json metadata type is out of contract"
if (-not (Test-JsonStructureEqual -Left $bundledSubagentRunSchema -Right $subagentRunSchema)) {
    throw "template/.codex/templates/subagent-run.schema.json must stay in sync with spec/subagent-run.schema.json"
}

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
$evaluationDefsProperty = $evaluationSchema.PSObject.Properties['$defs']
Assert-Condition ($null -ne $evaluationDefsProperty) "spec/evaluation.schema.json must define `$defs"
$evaluationDefs = $evaluationDefsProperty.Value
$evidenceRefProperty = $evaluationDefs.PSObject.Properties['evidence_ref']
Assert-Condition ($null -ne $evidenceRefProperty) "spec/evaluation.schema.json must define `$defs.evidence_ref"
$evidenceRefSchema = $evidenceRefProperty.Value
Expect-RequiredFields -Schema $evidenceRefSchema -Fields @("kind", "summary") -Label "spec/evaluation.schema.json `$defs.evidence_ref"
Expect-PropertyKeys -Schema $evidenceRefSchema -Fields @("kind", "path", "selector", "event_id", "summary") -Label "spec/evaluation.schema.json `$defs.evidence_ref"
Expect-EnumSet -Values $evidenceRefSchema.properties.kind.enum -Expected @(
    "run_manifest",
    "codex_task_report",
    "log_event",
    "hook_observation",
    "subagent_run",
    "changed_file",
    "validation_command",
    "evaluation_note"
) -Label "spec/evaluation.schema.json evidence_refs.kind"
Expect-RequiredFields -Schema $dimensionsSchema -Fields $dimensionNames -Label "spec/evaluation.schema.json dimensions"
Expect-PropertyKeys -Schema $dimensionsSchema -Fields $dimensionNames -Label "spec/evaluation.schema.json dimensions"
foreach ($name in $dimensionNames) {
    $dimensionSchema = $dimensionsSchema.properties.$name
    Expect-RequiredFields -Schema $dimensionSchema -Fields @("rating", "evidence") -Label "spec/evaluation.schema.json dimensions.$name"
    Expect-PropertyKeys -Schema $dimensionSchema -Fields @("rating", "evidence", "evidence_refs") -Label "spec/evaluation.schema.json dimensions.$name"
    Assert-Condition ($dimensionSchema.properties.evidence_refs.items.'$ref' -eq '#/$defs/evidence_ref') "spec/evaluation.schema.json dimensions.$name.evidence_refs must reference #/`$defs/evidence_ref"
    Expect-EnumContains -Values $dimensionSchema.properties.rating.enum -Expected @("pass", "warn", "fail", "not_evaluated") -Label "spec/evaluation.schema.json dimensions.$name.rating"
}

$findingsItem = $evaluationSchema.properties.findings.items
Expect-RequiredFields -Schema $findingsItem -Fields @("category", "severity", "evidence", "detail") -Label "spec/evaluation.schema.json findings item"
Expect-PropertyKeys -Schema $findingsItem -Fields @("category", "severity", "evidence", "evidence_refs", "detail") -Label "spec/evaluation.schema.json findings item"
Assert-Condition ($findingsItem.properties.evidence_refs.items.'$ref' -eq '#/$defs/evidence_ref') "spec/evaluation.schema.json findings.evidence_refs must reference #/`$defs/evidence_ref"
Expect-EnumSet -Values $findingsItem.properties.category.enum -Expected $taxonomyCategories -Label "spec/evaluation.schema.json findings.category"
Expect-EnumContains -Values $findingsItem.properties.severity.enum -Expected @("low", "medium", "high", "critical") -Label "spec/evaluation.schema.json findings.severity"

$improvementItem = $evaluationSchema.properties.improvement_candidates.items
Expect-RequiredFields -Schema $improvementItem -Fields @("target", "evidence", "expected_impact", "recommendation") -Label "spec/evaluation.schema.json improvement_candidates item"
Expect-PropertyKeys -Schema $improvementItem -Fields @("target", "evidence", "evidence_refs", "expected_impact", "recommendation") -Label "spec/evaluation.schema.json improvement_candidates item"
Assert-Condition ($improvementItem.properties.evidence_refs.items.'$ref' -eq '#/$defs/evidence_ref') "spec/evaluation.schema.json improvement_candidates.evidence_refs must reference #/`$defs/evidence_ref"

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

Expect-EnumContains -Values $runManifestSchema.properties.task_type.enum -Expected @("plan", "review", "implementation", "investigation", "repair", "harness-improvement") -Label "spec/run-manifest.schema.json task_type"
Expect-EnumContains -Values $runManifestSchema.properties.workflow_level.enum -Expected @("lightweight", "standard", "strict") -Label "spec/run-manifest.schema.json workflow_level"
Expect-EnumContains -Values $runManifestSchema.properties.preset.enum -Expected @("safe", "readonly", "auto-net") -Label "spec/run-manifest.schema.json preset"
Expect-EnumContains -Values $runManifestSchema.properties.runtime.enum -Expected @("host", "docker-sandbox", "sdk") -Label "spec/run-manifest.schema.json runtime"
Expect-EnumContains -Values $runManifestSchema.properties.status.enum -Expected @("pending", "running", "completed", "failed", "cancelled") -Label "spec/run-manifest.schema.json status"
Expect-EnumSet -Values $runManifestSchema.properties.primary_failure_category.enum -Expected ($taxonomyCategories + @($null)) -Label "spec/run-manifest.schema.json primary_failure_category"

$validationSchema = $runManifestSchema.properties.validation
Expect-RequiredFields -Schema $validationSchema -Fields @("status", "commands") -Label "spec/run-manifest.schema.json validation"
Expect-PropertyKeys -Schema $validationSchema -Fields @("status", "commands", "warnings") -Label "spec/run-manifest.schema.json validation"
Expect-EnumContains -Values $validationSchema.properties.status.enum -Expected @("not_run", "passed", "passed_with_warnings", "failed", "skipped", "blocked") -Label "spec/run-manifest.schema.json validation.status"

$validationCommandItem = $validationSchema.properties.commands.items
Expect-RequiredFields -Schema $validationCommandItem -Fields @("command", "exit_code", "status", "evidence") -Label "spec/run-manifest.schema.json validation.commands item"
Expect-PropertyKeys -Schema $validationCommandItem -Fields @("command", "exit_code", "status", "evidence") -Label "spec/run-manifest.schema.json validation.commands item"
Expect-EnumContains -Values $validationCommandItem.properties.status.enum -Expected @("not_run", "passed", "failed", "skipped", "blocked") -Label "spec/run-manifest.schema.json validation.commands[].status"
$validationWarningItem = $validationSchema.properties.warnings.items
Expect-RequiredFields -Schema $validationWarningItem -Fields @("type", "path") -Label "spec/run-manifest.schema.json validation.warnings item"
Expect-PropertyKeys -Schema $validationWarningItem -Fields @("type", "path", "message") -Label "spec/run-manifest.schema.json validation.warnings item"

$safetySchema = $runManifestSchema.properties.safety
Expect-RequiredFields -Schema $safetySchema -Fields @("network", "delete_attempt_blocked", "git_mutation_attempt_blocked", "scope_violation") -Label "spec/run-manifest.schema.json safety"
Expect-PropertyKeys -Schema $safetySchema -Fields @("network", "delete_attempt_blocked", "git_mutation_attempt_blocked", "scope_violation") -Label "spec/run-manifest.schema.json safety"
$artifactSummarySchema = $runManifestSchema.properties.artifact_summary
Expect-RequiredFields -Schema $artifactSummarySchema -Fields @("codex_task_report_count", "hook_event_count", "subagent_run_count", "evaluation_present") -Label "spec/run-manifest.schema.json artifact_summary"
$hookSummarySchema = $runManifestSchema.properties.hook_observations
Expect-RequiredFields -Schema $hookSummarySchema -Fields @("log_paths", "event_counts", "blocking_event_count", "safety_blocked_count", "observation_error_count") -Label "spec/run-manifest.schema.json hook_observations"
$subagentsSchema = $runManifestSchema.properties.subagents
Expect-RequiredFields -Schema $subagentsSchema -Fields @("records", "summary") -Label "spec/run-manifest.schema.json subagents"
$subagentRecordSchema = $subagentsSchema.properties.records.items
Expect-RequiredFields -Schema $subagentRecordSchema -Fields @("path", "subagent_run_id", "agent_name", "role", "mode", "status", "allowed_files_count", "changed_files_count", "scope_compliant", "used_in_final_plan", "parent_decision") -Label "spec/run-manifest.schema.json subagents.records item"
Expect-EnumSet -Values $subagentRecordSchema.properties.role.enum -Expected $subagentRunSchema.properties.role.enum -Label "spec/run-manifest.schema.json subagents.records.role"
Expect-EnumSet -Values $subagentRecordSchema.properties.mode.enum -Expected $subagentRunSchema.properties.mode.enum -Label "spec/run-manifest.schema.json subagents.records.mode"
Expect-EnumSet -Values $subagentRecordSchema.properties.status.enum -Expected $subagentRunSchema.properties.status.enum -Label "spec/run-manifest.schema.json subagents.records.status"
Expect-EnumSet -Values $subagentRecordSchema.properties.parent_decision.enum -Expected (@($subagentRunSchema.properties.parent_decision.properties.action.enum) + @($null)) -Label "spec/run-manifest.schema.json subagents.records.parent_decision"
$subagentSummarySchema = $subagentsSchema.properties.summary
Expect-RequiredFields -Schema $subagentSummarySchema -Fields @("total", "read_only", "writable", "scope_violations", "used_in_final_plan") -Label "spec/run-manifest.schema.json subagents.summary"

$templateKeys = @($runManifestTemplate.PSObject.Properties.Name)
$requiredManifestKeys = @(Normalize-ToArray $runManifestSchema.required)
$missingTemplateKeys = @($requiredManifestKeys | Where-Object { $_ -notin $templateKeys })
Assert-Condition ($missingTemplateKeys.Count -eq 0) "template/.codex/templates/RUN_MANIFEST.json missing required keys: $($missingTemplateKeys -join ', ')"
Assert-Condition ($runManifestTemplate.schema_version -eq 1) "template/.codex/templates/RUN_MANIFEST.json schema_version must be 1"
Assert-Condition ($runManifestTemplate.run_id -ne "") "template/.codex/templates/RUN_MANIFEST.json run_id must not be empty"
Assert-Condition ($runManifestTemplate.status -eq "pending") "template/.codex/templates/RUN_MANIFEST.json status must default to pending"
Assert-Condition ($null -eq $runManifestTemplate.primary_failure_category) "template/.codex/templates/RUN_MANIFEST.json primary_failure_category must default to null"
Assert-Condition (($runManifestTemplate.validation -is [pscustomobject]) -and ($runManifestTemplate.validation.status -eq "not_run") -and (@(Normalize-ToArray $runManifestTemplate.validation.commands).Count -eq 0) -and (@(Normalize-ToArray $runManifestTemplate.validation.warnings).Count -eq 0)) "template/.codex/templates/RUN_MANIFEST.json validation defaults are out of contract"
Assert-Condition ($runManifestTemplate.safety -is [pscustomobject]) "template/.codex/templates/RUN_MANIFEST.json safety must be an object"
$safetyTemplateKeys = @($runManifestTemplate.safety.PSObject.Properties.Name | Sort-Object)
$expectedSafetyKeys = @("delete_attempt_blocked", "git_mutation_attempt_blocked", "network", "scope_violation") | Sort-Object
Assert-Condition (-not (Compare-Object -ReferenceObject $expectedSafetyKeys -DifferenceObject $safetyTemplateKeys)) "template/.codex/templates/RUN_MANIFEST.json safety keys are out of contract"
Assert-Condition (($runManifestTemplate.artifact_summary.codex_task_report_count -eq 0) -and ($runManifestTemplate.artifact_summary.hook_event_count -eq 0) -and ($runManifestTemplate.artifact_summary.subagent_run_count -eq 0) -and ($runManifestTemplate.artifact_summary.evaluation_present -eq $false)) "template/.codex/templates/RUN_MANIFEST.json artifact_summary defaults are out of contract"
Assert-Condition (Test-JsonStructureEqual -Left $runManifestTemplate.hook_observations -Right ([pscustomobject]@{ log_paths = @(); event_counts = [pscustomobject]@{}; blocking_event_count = 0; safety_blocked_count = 0; observation_error_count = 0 })) "template/.codex/templates/RUN_MANIFEST.json hook_observations defaults are out of contract"
Assert-Condition (Test-JsonStructureEqual -Left $runManifestTemplate.subagents -Right ([pscustomobject]@{ records = @(); summary = [pscustomobject]@{ total = 0; read_only = 0; writable = 0; scope_violations = 0; used_in_final_plan = 0 } })) "template/.codex/templates/RUN_MANIFEST.json subagents defaults are out of contract"

$templateProjectToml = Get-Content -Raw (Join-Path $repoRoot "template/codex-project.toml")
$templateVersionMatch = [regex]::Match($templateProjectToml, '^template_version\s*=\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::Multiline)
Assert-Condition $templateVersionMatch.Success "template/codex-project.toml must define template_version"
$templateVersion = $templateVersionMatch.Groups[1].Value
Assert-Condition (Test-SemVer -Value $templateVersion) "template_version must be semver, got $templateVersion"

Assert-Contains -RelativePath "template/AGENTS.md" -Patterns @(
    "command-based deletion",
    "implementation_worker",
    "writable subagent",
    "auto-net",
    "git mutation"
)
Assert-Contains -RelativePath "README.md" -Patterns @(
    "verify --strict-harness",
    "plan-consumer-update",
    "cleanup-runs",
    "Major:",
    "Minor:",
    "Patch:"
)
Assert-Contains -RelativePath "CHANGELOG.md" -Patterns @(
    "## $templateVersion",
    "verify --strict-harness",
    "cleanup-runs",
    "plan-consumer-update"
)
Assert-Contains -RelativePath "MIGRATION.md" -Patterns @(
    "## $templateVersion",
    "strict-harness",
    "cleanup-runs",
    "plan-consumer-update"
)
Assert-Contains -RelativePath "template/docs/guides/consumer-update.md" -Patterns @(
    "plan-consumer-update",
    "--exclude-protected",
    "cleanup-runs"
)
Assert-Contains -RelativePath "template/docs/reference/run-artifacts.md" -Patterns @(
    "scripts/cleanup-runs.sh",
    "scripts/cleanup-runs.ps1",
    "--confirm-delete-generated-runs"
)
Assert-Contains -RelativePath "template/docs/reference/codex-safety-harness.md" -Patterns @(
    "cleanup-runs",
    "strict-harness"
)
Assert-Contains -RelativePath "template/docs/reference/codex-implementation-harness.md" -Patterns @(
    "--strict-harness",
    "-StrictHarness"
)
Assert-Contains -RelativePath ".github/workflows/validate-template.yml" -Patterns @(
    "permissions:",
    "contents: read",
    "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5",
    "persist-credentials: false",
    "bash template/scripts/verify --strict-harness",
    "bash tests/integration/test-cleanup-runs.sh",
    "bash tests/integration/test-plan-consumer-update.sh",
    "powershell -ExecutionPolicy Bypass -File template/scripts/verify.ps1 -StrictHarness",
    "powershell -ExecutionPolicy Bypass -File tests/integration/Test-CleanupRuns.ps1",
    "powershell -ExecutionPolicy Bypass -File tests/integration/Test-PlanConsumerUpdate.ps1"
)

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

Invoke-OutputSchemaValidation -SchemaRelativePath "spec/evaluation.schema.json" -OutputRelativePath "template/examples/repair-loop/iteration-1-evaluation.json"
Invoke-OutputSchemaValidation -SchemaRelativePath "spec/evaluation.schema.json" -OutputRelativePath "template/examples/repair-loop/iteration-2-evaluation.json"

$candidatesDoc = Read-JsonFile -RelativePath "template/examples/harness-improvement/harness-improvement-candidates.json"
Assert-Condition ($candidatesDoc -is [pscustomobject]) "template/examples/harness-improvement/harness-improvement-candidates.json must be a JSON object"
$candidates = Normalize-ToArray $candidatesDoc.candidates
Assert-Condition ($candidates.Count -ge 3) "template/examples/harness-improvement/harness-improvement-candidates.json must contain at least three candidates"

$candidateRequiredFields = @(
    "candidate_id",
    "target",
    "failure_category",
    "source_runs",
    "evidence",
    "expected_impact",
    "risk",
    "recommended_change",
    "strictness",
    "status",
    "owner_decision"
)
$strictnessValues = @()
$candidateIndex = 0
foreach ($candidate in $candidates) {
    $candidateIndex++
    Assert-Condition ($candidate -is [pscustomobject]) "candidate[$candidateIndex] must be an object"
    foreach ($field in $candidateRequiredFields) {
        if ($field -notin $candidate.PSObject.Properties.Name) {
            throw "candidate[$candidateIndex] missing required field: $field"
        }
    }
    foreach ($field in @(
        "candidate_id",
        "target",
        "failure_category",
        "expected_impact",
        "risk",
        "recommended_change",
        "strictness",
        "status",
        "owner_decision"
    )) {
        $value = $candidate.$field
        Assert-Condition (($value -is [string]) -and -not [string]::IsNullOrWhiteSpace($value)) "candidate[$candidateIndex].$field must be a non-empty string"
    }
    $sourceRuns = @(Normalize-ToArray $candidate.source_runs)
    Assert-Condition ($sourceRuns.Count -gt 0) "candidate[$candidateIndex].source_runs must be a non-empty array"
    Assert-Condition (
        @($sourceRuns | Where-Object { ($_ -is [string]) -and -not [string]::IsNullOrWhiteSpace($_) }).Count -eq $sourceRuns.Count
    ) "candidate[$candidateIndex].source_runs must contain only non-empty strings"
    $evidence = @(Normalize-ToArray $candidate.evidence)
    Assert-Condition ($evidence.Count -gt 0) "candidate[$candidateIndex].evidence must be a non-empty array"
    Assert-Condition (
        @($evidence | Where-Object { ($_ -is [string]) -and -not [string]::IsNullOrWhiteSpace($_) }).Count -eq $evidence.Count
    ) "candidate[$candidateIndex].evidence must contain only non-empty strings"
    Assert-Condition ($candidate.failure_category -in $taxonomyCategories) "candidate[$candidateIndex].failure_category must exist in spec/failure-taxonomy.json"
    Assert-Condition ($candidate.strictness -in @("normal", "strict", "blocked")) "candidate[$candidateIndex].strictness must be one of normal|strict|blocked"
    Assert-Condition ($candidate.status -in @("proposed", "accepted", "rejected", "deferred", "implemented")) "candidate[$candidateIndex].status must be one of proposed|accepted|rejected|deferred|implemented"
    Assert-Condition ($candidate.owner_decision -in @("not_reviewed", "approved", "rejected", "needs_more_evidence")) "candidate[$candidateIndex].owner_decision must be one of not_reviewed|approved|rejected|needs_more_evidence"
    $strictnessValues += $candidate.strictness
}

$strictnessSet = @($strictnessValues | Sort-Object -Unique)
$expectedStrictnessSet = @("blocked", "normal", "strict") | Sort-Object
Assert-Condition (-not (Compare-Object -ReferenceObject $expectedStrictnessSet -DifferenceObject $strictnessSet)) "harness-improvement candidates must include normal, strict, and blocked strictness values"

Write-Host "PASS: spec validation"
