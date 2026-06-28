[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet("safe", "readonly", "auto-net")]
    [string]$Preset,

    [ValidateSet("host", "docker-sandbox")]
    [string]$Runtime,

    [string]$TaskType,

    [string]$WorkflowLevel,

    [switch]$RecordRunManifest,

    [string]$PromptFile,

    [string]$OutputFile,

    [string]$OutputSchema,

    [string]$ReportPath,

    [string]$VerifyCommand,

    [switch]$AllowSearch,

    [switch]$SkipPreflight,

    [switch]$SkipVerify,

    [switch]$EvaluationTemplate,

    [switch]$RequireEvaluation,

    [switch]$RequireCleanGit,

    [switch]$RequireRunId,

    [string]$MaxIterations,

    [string]$LogPath,

    [string]$RunId,

    [string[]]$AllowedFiles,

    [string[]]$AllowedDirs,

    [string[]]$AllowedGlobs,

    [string[]]$ExpectedChangedFiles,

    [string]$ExpectedMissing,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    param([string]$ScriptDir)
    return (Resolve-Path (Join-Path $ScriptDir "..")).Path
}

function Test-IsPathUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root)
    if (-not $fullRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $fullRoot += [System.IO.Path]::DirectorySeparatorChar
    }
    return $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        ($fullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar) -eq $fullRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar))
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Convert-ToContainerPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ($Path -eq $RepoRoot) {
        return "/workspace"
    }

    $trimmedRoot = $RepoRoot.TrimEnd('\', '/')
    $relative = $Path.Substring($trimmedRoot.Length).TrimStart('\', '/')
    return "/workspace/" + ($relative -replace '\\', '/')
}

function Get-DefaultLogPath {
    param(
        [string]$RepoRoot,
        [string]$Timestamp,
        [string]$RunId
    )

    $logsDir = Join-Path $RepoRoot ".codex\\logs"
    if (-not [string]::IsNullOrWhiteSpace($RunId)) {
        $logsDir = Join-Path $RepoRoot (Join-Path ".codex\\runs" (Join-Path $RunId "logs"))
    }
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    return (Join-Path $logsDir ("codex-task-" + $Timestamp + ".jsonl"))
}

function Get-PythonCommand {
    foreach ($candidate in @("python", "python3", "py")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if (-not $cmd) {
            continue
        }

        $prevNativeErr = $null
        $hasNativeErrPref = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)
        if ($hasNativeErrPref) {
            $prevNativeErr = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
        }

        try {
            & $cmd.Source --version *> $null
            if ($LASTEXITCODE -eq 0) {
                return $cmd.Source
            }
        }
        catch {
        }
        finally {
            if ($hasNativeErrPref) {
                $PSNativeCommandUseErrorActionPreference = $prevNativeErr
            }
        }
    }
    return $null
}

function Test-RunId {
    param([string]$RunId)

    return [string]::IsNullOrWhiteSpace($RunId) -or $RunId -match '^\d{8}-\d{6}-JST$'
}

function Normalize-RepoRelativePosixPath {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path,
        [switch]$ValidateScopePath,
        [string]$OptionName
    )

    if ($ValidateScopePath -and [string]::IsNullOrWhiteSpace($Path)) {
        throw "$OptionName requires a non-empty path"
    }

    $normalizedInput = $Path -replace '\\', '/'
    if ($ValidateScopePath) {
        if ($normalizedInput.IndexOfAny([char[]]@('*', '?', '[', ']')) -ge 0) {
            throw "$OptionName does not support glob patterns: $Path"
        }
        if ([System.IO.Path]::IsPathRooted($normalizedInput) -or $normalizedInput -match '^[A-Za-z]:/' -or $normalizedInput.StartsWith('//', [System.StringComparison]::Ordinal)) {
            throw "$OptionName requires a repo-relative path: $Path"
        }
    }

    $segments = New-Object System.Collections.Generic.List[string]
    foreach ($segment in $normalizedInput.Split('/', [System.StringSplitOptions]::None)) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.') {
            continue
        }
        if ($segment -eq '..') {
            if ($segments.Count -eq 0) {
                if ($ValidateScopePath) {
                    throw "$OptionName path escapes repo root: $Path"
                }
                return $null
            }
            $segments.RemoveAt($segments.Count - 1)
            continue
        }
        $segments.Add($segment)
    }

    if ($segments.Count -eq 0) {
        if ($ValidateScopePath) {
            throw "$OptionName requires a repo-relative file path: $Path"
        }
        return $null
    }

    return ($segments -join '/')
}

function Add-NormalizedScopePaths {
    param(
        [Parameter(Mandatory = $true)]$Target,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$RawList,
        [Parameter(Mandatory = $true)][string]$OptionName
    )

    foreach ($item in $RawList.Split(',', [System.StringSplitOptions]::None)) {
        $Target.Add((Normalize-RepoRelativePosixPath -Path $item -ValidateScopePath -OptionName $OptionName))
    }
}

function Add-NormalizedDirectoryScopePaths {
    param(
        [Parameter(Mandatory = $true)]$Target,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$RawList,
        [Parameter(Mandatory = $true)][string]$OptionName
    )

    foreach ($item in $RawList.Split(',', [System.StringSplitOptions]::None)) {
        $trimmed = $item.TrimEnd('/', '\')
        $Target.Add((Normalize-RepoRelativePosixPath -Path $trimmed -ValidateScopePath -OptionName $OptionName))
    }
}

function Add-NormalizedScopeGlobs {
    param(
        [Parameter(Mandatory = $true)]$Target,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$RawList,
        [Parameter(Mandatory = $true)][string]$OptionName
    )

    foreach ($item in $RawList.Split(',', [System.StringSplitOptions]::None)) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            throw "$OptionName requires a non-empty path"
        }

        $normalizedInput = $item -replace '\\', '/'
        if ([System.IO.Path]::IsPathRooted($normalizedInput) -or $normalizedInput -match '^[A-Za-z]:/' -or $normalizedInput.StartsWith('//', [System.StringComparison]::Ordinal)) {
            throw "$OptionName requires a repo-relative path: $item"
        }

        $segments = New-Object System.Collections.Generic.List[string]
        foreach ($segment in $normalizedInput.Split('/', [System.StringSplitOptions]::None)) {
            if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.') {
                continue
            }
            if ($segment -eq '..') {
                throw "$OptionName path escapes repo root: $item"
            }
            $segments.Add($segment)
        }

        if ($segments.Count -eq 0) {
            throw "$OptionName requires a repo-relative path: $item"
        }

        $Target.Add(($segments -join '/'))
    }
}

function Convert-LimitedGlobToRegex {
    param([Parameter(Mandatory = $true)][string]$Pattern)

    $builder = [System.Text.StringBuilder]::new('^')
    $i = 0
    while ($i -lt $Pattern.Length) {
        $char = $Pattern[$i]
        if ($char -eq '*') {
            if (($i + 1) -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
                [void]$builder.Append('.*')
                $i += 2
                continue
            }
            [void]$builder.Append('[^/]*')
            $i++
            continue
        }
        if ($char -eq '?') {
            [void]$builder.Append('[^/]')
            $i++
            continue
        }
        [void]$builder.Append([regex]::Escape([string]$char))
        $i++
    }
    [void]$builder.Append('$')
    return $builder.ToString()
}

function Get-SortedUniqueStrings {
    param([string[]]$Values)

    if ($null -eq $Values -or @($Values).Count -eq 0) {
        return @()
    }

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($value in @($Values)) {
        if ($null -ne $value) {
            [void]$set.Add([string]$value)
        }
    }

    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($value in $set) {
        $list.Add($value)
    }

    $list.Sort([System.StringComparer]::Ordinal)
    return @($list)
}

function Get-CodexCommand {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_BIN)) {
        if (Test-Path $env:CODEX_BIN) {
            return (Resolve-Path $env:CODEX_BIN).Path
        }
        return (Get-Command $env:CODEX_BIN -ErrorAction Stop).Source
    }
    return (Get-Command codex -ErrorAction Stop).Source
}

function Get-DockerCommand {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_DOCKER_BIN)) {
        if (Test-Path $env:CODEX_DOCKER_BIN) {
            return (Resolve-Path $env:CODEX_DOCKER_BIN).Path
        }
        return (Get-Command $env:CODEX_DOCKER_BIN -ErrorAction Stop).Source
    }
    return (Get-Command docker -ErrorAction Stop).Source
}

function Get-GitBranch {
    param([string]$RepoRoot)

    try {
        $branch = (& git -C $RepoRoot branch --show-current 2>$null | Select-Object -First 1)
        if ([string]::IsNullOrWhiteSpace($branch)) {
            return $null
        }
        return $branch.Trim()
    }
    catch {
        return $null
    }
}

function Get-GitDirty {
    param([string]$RepoRoot)

    try {
        & git -C $RepoRoot rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -ne 0) { return $false }
        & git -C $RepoRoot diff --quiet --ignore-submodules -- *> $null
        if ($LASTEXITCODE -ne 0) { return $true }
        & git -C $RepoRoot diff --cached --quiet --ignore-submodules -- *> $null
        if ($LASTEXITCODE -ne 0) { return $true }
        $untracked = (& git -C $RepoRoot ls-files --others --exclude-standard 2>$null)
        return ($null -ne $untracked -and @($untracked).Count -gt 0)
    }
    catch {
        return $false
    }
}

function Invoke-VerifyCommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandText,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $resolvedPath = Resolve-RepoPath -RepoRoot $RepoRoot -Path $CommandText
    if (Test-Path $resolvedPath -PathType Leaf) {
        $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()
        switch ($extension) {
            '.ps1' {
                & powershell.exe -ExecutionPolicy Bypass -File $resolvedPath
                return $LASTEXITCODE
            }
            '.cmd' { 
                & cmd.exe /d /c $resolvedPath
                return $LASTEXITCODE
            }
            '.bat' {
                & cmd.exe /d /c $resolvedPath
                return $LASTEXITCODE
            }
            '.sh' {
                $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
                if (-not $bashCmd) {
                    throw "bash command not found for verify script: $resolvedPath"
                }
                & $bashCmd.Source $resolvedPath
                return $LASTEXITCODE
            }
            default {
                & $resolvedPath
                return $LASTEXITCODE
            }
        }
    }

    $previous = [System.Environment]::GetEnvironmentVariable('CODEX_VERIFY_COMMAND')
    try {
        [System.Environment]::SetEnvironmentVariable('CODEX_VERIFY_COMMAND', $CommandText)
        $verifyRunner = '$script = [System.Environment]::GetEnvironmentVariable("CODEX_VERIFY_COMMAND"); & ([scriptblock]::Create($script))'
        $encodedRunner = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($verifyRunner))
        & powershell.exe -NoProfile -EncodedCommand $encodedRunner
        return $LASTEXITCODE
    }
    finally {
        [System.Environment]::SetEnvironmentVariable('CODEX_VERIFY_COMMAND', $previous)
    }
}

function Write-TaskLog {
    param(
        [string]$Path,
        [string]$Event,
        [hashtable]$Data
    )

    $payload = [ordered]@{
        timestamp = (Get-Date).ToString("o")
        event = $Event
    }
    if ($Data) {
        foreach ($key in $Data.Keys) {
            $payload[$key] = $Data[$key]
        }
    }

    ($payload | ConvertTo-Json -Compress -Depth 8) | Add-Content -Path $Path
}

function Write-TaskReport {
    param(
        [string]$Path,
        [System.Collections.IDictionary]$Report
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    ($Report | ConvertTo-Json -Depth 6) | Set-Content -Path $Path
}

function Add-ValidationCommand {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][AllowNull()]$ExitCode,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Evidence
    )

    $State.validation_commands = @($State.validation_commands) + @(
        [ordered]@{
            command = $Command
            exit_code = $ExitCode
            status = $Status
            evidence = $Evidence
        }
    )

    switch ($Status) {
        'blocked' { $State.validation_status = 'blocked' }
        'failed' { $State.validation_status = 'failed' }
        'passed' {
            if ($State.validation_status -in @('not_run', 'skipped')) {
                $State.validation_status = 'passed'
            }
        }
        'skipped' {
            if ($State.validation_status -eq 'not_run') {
                $State.validation_status = 'skipped'
            }
        }
    }
}

function Add-ValidationWarning {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$Message
    )

    $State.validation_warnings = @($State.validation_warnings) + @(
        [ordered]@{
            type = $Type
            path = $Path
            message = $Message
        }
    )

    if ($State.validation_status -notin @('blocked', 'failed')) {
        $State.validation_status = 'passed_with_warnings'
    }
}

function Write-RunManifest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $manifest = [ordered]@{
        schema_version = 1
        run_id = $State.run_id
        task_type = $State.task_type
        workflow_level = $State.workflow_level
        preset = $State.preset
        runtime = $State.runtime
        agents_used = @()
        repo = $null
        branch = Get-GitBranch -RepoRoot $RepoRoot
        base_branch = $null
        codex_task_reports = @(
            Convert-ToRepoRelativePath -RepoRoot $RepoRoot -Path $State.report_path
        )
        changed_files = @($State.changed_files)
        validation = [ordered]@{
            status = $State.validation_status
            commands = @($State.validation_commands)
            warnings = @($State.validation_warnings)
        }
        safety = [ordered]@{
            network = ($State.preset -eq "auto-net" -or $State.allow_search)
            delete_attempt_blocked = $false
            git_mutation_attempt_blocked = $false
            scope_violation = $State.scope_violation
        }
        artifact_summary = [ordered]@{
            codex_task_report_count = 0
            hook_event_count = 0
            subagent_run_count = 0
            evaluation_present = $false
        }
        hook_observations = [ordered]@{
            log_paths = @()
            event_counts = [ordered]@{}
            blocking_event_count = 0
            safety_blocked_count = 0
            observation_error_count = 0
        }
        subagents = [ordered]@{
            records = @()
            summary = [ordered]@{
                total = 0
                read_only = 0
                writable = 0
                scope_violations = 0
                used_in_final_plan = 0
            }
        }
        evaluation_path = $State.evaluation_path
        status = $State.run_status
        primary_failure_category = $State.primary_failure_category
    }

    if (Test-Path $Path) {
        try {
            $existing = Get-Content -Raw -Path $Path | ConvertFrom-Json
        }
        catch {
            $existing = $null
        }

        if ($existing) {
            $manifest.agents_used = @(Get-SortedUniqueStrings -Values (@(@($existing.agents_used) + @($manifest.agents_used))))
            $manifest.codex_task_reports = @(Get-SortedUniqueStrings -Values (@(@($existing.codex_task_reports) + @($manifest.codex_task_reports))))
            $manifest.changed_files = @(Get-SortedUniqueStrings -Values (@(@($existing.changed_files) + @($manifest.changed_files))))
            $existingValidation = if ($existing.PSObject.Properties.Name -contains 'validation') { $existing.validation } else { $null }
            if ($existingValidation) {
                $existingCommands = if ($existingValidation.PSObject.Properties.Name -contains 'commands') { @($existingValidation.commands) } else { @() }
                $existingWarnings = if ($existingValidation.PSObject.Properties.Name -contains 'warnings') { @($existingValidation.warnings) } else { @() }
                $manifest.validation.commands = @(@($existingCommands) + @($manifest.validation.commands))
                $manifest.validation.warnings = @(@($existingWarnings) + @($manifest.validation.warnings))
            }
            $existingSafety = if ($existing.PSObject.Properties.Name -contains 'safety') { $existing.safety } else { $null }
            if ($existingSafety) {
                $manifest.safety.network = ([bool]$existingSafety.network -or [bool]$manifest.safety.network)
                $manifest.safety.delete_attempt_blocked = ([bool]$existingSafety.delete_attempt_blocked -or [bool]$manifest.safety.delete_attempt_blocked)
                $manifest.safety.git_mutation_attempt_blocked = ([bool]$existingSafety.git_mutation_attempt_blocked -or [bool]$manifest.safety.git_mutation_attempt_blocked)
                $manifest.safety.scope_violation = ([bool]$existingSafety.scope_violation -or [bool]$manifest.safety.scope_violation)
            }
            if ($null -eq $manifest.evaluation_path -and $null -ne $existing.evaluation_path) {
                $manifest.evaluation_path = $existing.evaluation_path
            }
            if ($null -eq $manifest.primary_failure_category -and $null -ne $existing.primary_failure_category) {
                $manifest.primary_failure_category = $existing.primary_failure_category
            }
            foreach ($key in @('artifact_summary', 'hook_observations', 'subagents')) {
                if ($existing.PSObject.Properties.Name -contains $key) {
                    $manifest[$key] = $existing.$key
                }
            }
        }
    }

    ($manifest | ConvertTo-Json -Depth 8) | Set-Content -Path $Path

    $pythonCmd = Get-PythonCommand
    if (-not $pythonCmd) {
        throw "Python is required to collect run artifacts when -RecordRunManifest is enabled"
    }

    $collector = Join-Path $RepoRoot "scripts\\collect-run-artifacts.ps1"
    if (-not (Test-Path $collector)) {
        throw "collect-run-artifacts.ps1 is required when -RecordRunManifest is enabled"
    }

    & powershell.exe -ExecutionPolicy Bypass -File $collector -RunId $State.run_id -ManifestPath $Path | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "collect-run-artifacts failed with exit code $LASTEXITCODE"
    }
}

function Test-PathMatchesAllowedDir {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$AllowedDir
    )

    return $Path -ceq $AllowedDir -or $Path.StartsWith($AllowedDir + '/', [System.StringComparison]::Ordinal)
}

function Test-PathMatchesAllowedScope {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][string]$Path
    )

    foreach ($allowed in @($State.allowed_files)) {
        if ($Path -ceq $allowed) {
            return $true
        }
    }

    foreach ($allowedDir in @($State.allowed_dirs)) {
        if (Test-PathMatchesAllowedDir -Path $Path -AllowedDir $allowedDir) {
            return $true
        }
    }

    foreach ($pattern in @($State.allowed_globs)) {
        if ($Path -cmatch (Convert-LimitedGlobToRegex -Pattern $pattern)) {
            return $true
        }
    }

    return $false
}

function Get-GitChangedFiles {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    try {
        & git -C $RepoRoot rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -ne 0) {
            return @()
        }
    }
    catch {
        return @()
    }

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        return @()
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $gitCmd.Source
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $escapedRepoRoot = $RepoRoot.Replace('"', '\"')
    $psi.Arguments = "-C `"$escapedRepoRoot`" status --porcelain=v1 -z --untracked-files=all"

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $buffer = New-Object System.IO.MemoryStream

    try {
        $process.Start() | Out-Null
        $process.StandardOutput.BaseStream.CopyTo($buffer)
        $null = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            return @()
        }

        $entries = ([System.Text.Encoding]::UTF8.GetString($buffer.ToArray())).Split([char]0, [System.StringSplitOptions]::None)
        $paths = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $entry = $entries[$i]
            if ([string]::IsNullOrEmpty($entry)) {
                continue
            }

            $status = $entry.Substring(0, 2)
            $primary = $entry.Substring(3)
            $normalized = Normalize-RepoRelativePosixPath -Path $primary
            if (-not [string]::IsNullOrWhiteSpace($normalized) -and
                $normalized -ne '.codex/runs' -and
                -not $normalized.StartsWith('.codex/runs/', [System.StringComparison]::Ordinal)) {
                $paths.Add($normalized)
            }

            if ($status.Contains('R') -or $status.Contains('C')) {
                if (($i + 1) -lt $entries.Count) {
                    $secondary = $entries[$i + 1]
                    $i++
                    if ($status.Contains('R')) {
                        $normalized = Normalize-RepoRelativePosixPath -Path $secondary
                        if (-not [string]::IsNullOrWhiteSpace($normalized) -and
                            $normalized -ne '.codex/runs' -and
                            -not $normalized.StartsWith('.codex/runs/', [System.StringComparison]::Ordinal)) {
                            $paths.Add($normalized)
                        }
                    }
                }
            }
        }

        return @(Get-SortedUniqueStrings -Values @($paths))
    }
    finally {
        $buffer.Dispose()
        $process.Dispose()
    }
}

function Invoke-ScopeChecks {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if ((@($State.allowed_files).Count + @($State.allowed_dirs).Count + @($State.allowed_globs).Count) -gt 0) {
        $violations = New-Object System.Collections.Generic.List[string]
        foreach ($path in @($State.changed_files)) {
            if (-not (Test-PathMatchesAllowedScope -State $State -Path $path)) {
                $violations.Add($path)
            }
        }

        if ($violations.Count -gt 0) {
            $orderedViolations = @(Get-SortedUniqueStrings -Values @($violations))
            $evidence = "changed files outside allowed scope: " + ($orderedViolations -join ', ')
            $Report.status = "scope_violation"
            Add-ValidationCommand -State $State -Command "change scope check" -ExitCode 1 -Status "blocked" -Evidence $evidence
            $State.run_status = "failed"
            $State.scope_violation = $true
            Write-TaskLog -Path $State.log_path -Event "scope_violation" -Data @{ evidence = $evidence }
            Write-TaskReport -Path $State.report_path -Report $Report
            if ($State.record_run_manifest) {
                Write-RunManifest -Path $State.manifest_path -State $State -Report $Report -RepoRoot $RepoRoot
            }
            exit 1
        }
    }

    if (@($State.expected_changed_files).Count -gt 0) {
        $changedLookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($path in @($State.changed_files)) {
            [void]$changedLookup.Add($path)
        }

        $missingExpected = New-Object System.Collections.Generic.List[string]
        foreach ($path in @($State.expected_changed_files)) {
            if (-not $changedLookup.Contains($path)) {
                $missingExpected.Add($path)
            }
        }

        if ($missingExpected.Count -gt 0) {
            $orderedMissing = @(Get-SortedUniqueStrings -Values @($missingExpected))
            $evidence = "expected files were not changed: " + ($orderedMissing -join ', ')
            if ($State.expected_missing_behavior -eq 'fail') {
                $Report.status = "expected_changes_missing"
                Add-ValidationCommand -State $State -Command "expected changed files check" -ExitCode 1 -Status "failed" -Evidence $evidence
                $State.run_status = "failed"
                $State.scope_violation = $false
                Write-TaskLog -Path $State.log_path -Event "expected_changes_missing" -Data @{ evidence = $evidence }
                Write-TaskReport -Path $State.report_path -Report $Report
                if ($State.record_run_manifest) {
                    Write-RunManifest -Path $State.manifest_path -State $State -Report $Report -RepoRoot $RepoRoot
                }
                exit 1
            }

            foreach ($path in $orderedMissing) {
                Add-ValidationWarning -State $State -Type 'expected_changed_file_missing' -Path $path -Message ("expected file was not changed: " + $path)
            }
            Write-Warning $evidence
            Write-TaskLog -Path $State.log_path -Event "expected_changes_missing_warning" -Data @{ evidence = $evidence }
        }
    }
}

function Invoke-CleanGitPrecondition {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if (-not $State.require_clean_git) {
        return
    }

    $State.changed_files = @(Get-GitChangedFiles -RepoRoot $RepoRoot)
    if (@($State.changed_files).Count -eq 0) {
        return
    }

    $evidence = "working tree has pre-existing source changes: " + (@($State.changed_files) -join ', ')
    $Report.status = "dirty_git"
    $State.run_status = "failed"
    Add-ValidationCommand -State $State -Command "clean git check" -ExitCode 1 -Status "blocked" -Evidence $evidence
    Write-TaskLog -Path $State.log_path -Event "dirty_git" -Data @{ evidence = $evidence }
    Write-TaskReport -Path $State.report_path -Report $Report
    if ($State.record_run_manifest) {
        Write-RunManifest -Path $State.manifest_path -State $State -Report $Report -RepoRoot $RepoRoot
    }
    exit 1
}

function Initialize-EvaluationTemplate {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if (-not $State.evaluation_template) {
        return
    }

    $State.evaluation_path = ".codex/runs/$($State.run_id)/evaluation.json"
    $parent = Split-Path -Parent $State.evaluation_file_path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path $State.evaluation_file_path) {
        Write-TaskLog -Path $State.log_path -Event "evaluation_template_exists" -Data @{ path = $State.evaluation_path }
        return
    }

    $evaluation = [ordered]@{
        schema_version = 1
        run_id = $State.run_id
        result = "not_evaluated"
        primary_failure_category = $null
        failure_categories = @()
        dimensions = [ordered]@{
            task_completion = [ordered]@{
                rating = "not_evaluated"
                evidence = "Task completion has not been evaluated yet."
                evidence_refs = @()
            }
            scope_control = [ordered]@{
                rating = "not_evaluated"
                evidence = "Scope control has not been evaluated yet."
                evidence_refs = @()
            }
            validation_confidence = [ordered]@{
                rating = "not_evaluated"
                evidence = "Validation confidence has not been evaluated yet."
                evidence_refs = @()
            }
            safety_compliance = [ordered]@{
                rating = "not_evaluated"
                evidence = "Safety compliance has not been evaluated yet."
                evidence_refs = @()
            }
            reviewability = [ordered]@{
                rating = "not_evaluated"
                evidence = "Reviewability has not been evaluated yet."
                evidence_refs = @()
            }
            maintainability = [ordered]@{
                rating = "not_evaluated"
                evidence = "Maintainability has not been evaluated yet."
                evidence_refs = @()
            }
            reproducibility = [ordered]@{
                rating = "not_evaluated"
                evidence = "Reproducibility has not been evaluated yet."
                evidence_refs = @()
            }
        }
        findings = @()
        improvement_candidates = @()
    }

    ($evaluation | ConvertTo-Json -Depth 8) | Set-Content -Path $State.evaluation_file_path
    Write-TaskLog -Path $State.log_path -Event "evaluation_template_created" -Data @{ path = $State.evaluation_path }
}

function Invoke-JsonSchemaValidation {
    param(
        [Parameter(Mandatory = $true)][string]$SchemaPath,
        [Parameter(Mandatory = $true)][string]$JsonPath
    )

    $pythonCmd = Get-PythonCommand
    if (-not $pythonCmd) {
        throw "Python is required to validate JSON schema"
    }

    $result = & $pythonCmd (Join-Path $repoRoot "scripts\\validate-output-schema.py") $SchemaPath $JsonPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $message = ($result | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "schema validation failed"
        }
        throw $message
    }
}

function Resolve-EvaluationSchemaPath {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    foreach ($candidate in @(
            (Join-Path $RepoRoot "spec\\evaluation.schema.json"),
            (Join-Path $RepoRoot ".codex\\templates\\evaluation.schema.json")
        )) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-EvaluationPrimaryFailureCategory {
    param(
        [Parameter(Mandatory = $true)][string]$EvaluationPath,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId
    )

    if (-not (Test-Path $EvaluationPath)) {
        throw "evaluation.json is missing: $EvaluationPath"
    }

    try {
        $data = Get-Content -Raw -Path $EvaluationPath | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in ${EvaluationPath}: $($_.Exception.Message)"
    }

    $actualRunId = [string]$data.run_id
    if ($actualRunId -ne $ExpectedRunId) {
        throw "evaluation run_id mismatch: expected $ExpectedRunId, got $actualRunId"
    }

    $value = $data.primary_failure_category
    if ($null -eq $value) {
        return "null"
    }

    return [string]$value
}

function Invoke-RequiredEvaluationValidation {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$State,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if (-not $State.require_evaluation) {
        return
    }

    $expectedRepoPath = ".codex/runs/$($State.run_id)/evaluation.json"
    if (-not (Test-Path $State.evaluation_file_path)) {
        $Report.status = "evaluation_missing"
        $State.run_status = "failed"
        $State.evaluation_path = $null
        $evidence = "evaluation.json is missing: $expectedRepoPath"
        Add-ValidationCommand -State $State -Command "evaluation validation" -ExitCode 1 -Status "failed" -Evidence $evidence
        Write-TaskLog -Path $State.log_path -Event "evaluation_missing" -Data @{ evidence = $evidence }
        Write-TaskReport -Path $State.report_path -Report $Report
        if ($State.record_run_manifest) {
            Write-RunManifest -Path $State.manifest_path -State $State -Report $Report -RepoRoot $RepoRoot
        }
        exit 1
    }

    $State.evaluation_path = $expectedRepoPath
    $evaluationSchemaPath = Resolve-EvaluationSchemaPath -RepoRoot $RepoRoot
    if (-not $evaluationSchemaPath) {
        $Report.status = "evaluation_invalid"
        $State.run_status = "failed"
        $evidence = "Evaluation schema not found: spec/evaluation.schema.json or .codex/templates/evaluation.schema.json"
        Add-ValidationCommand -State $State -Command "evaluation validation" -ExitCode 1 -Status "failed" -Evidence $evidence
        Write-TaskLog -Path $State.log_path -Event "evaluation_invalid" -Data @{ evidence = $evidence }
        Write-TaskReport -Path $State.report_path -Report $Report
        if ($State.record_run_manifest) {
            Write-RunManifest -Path $State.manifest_path -State $State -Report $Report -RepoRoot $RepoRoot
        }
        exit 1
    }

    try {
        Invoke-JsonSchemaValidation -SchemaPath $evaluationSchemaPath -JsonPath $State.evaluation_file_path
        $category = Get-EvaluationPrimaryFailureCategory -EvaluationPath $State.evaluation_file_path -ExpectedRunId $State.run_id
    }
    catch {
        $Report.status = "evaluation_invalid"
        $State.run_status = "failed"
        $evidence = $_.Exception.Message
        Add-ValidationCommand -State $State -Command "evaluation validation" -ExitCode 1 -Status "failed" -Evidence $evidence
        Write-TaskLog -Path $State.log_path -Event "evaluation_invalid" -Data @{ evidence = $evidence }
        Write-TaskReport -Path $State.report_path -Report $Report
        if ($State.record_run_manifest) {
            Write-RunManifest -Path $State.manifest_path -State $State -Report $Report -RepoRoot $RepoRoot
        }
        exit 1
    }

    $State.primary_failure_category = if ($category -eq 'null') { $null } else { $category }
    Add-ValidationCommand -State $State -Command "evaluation validation" -ExitCode 0 -Status "passed" -Evidence "evaluation.json passed schema validation"
    Write-TaskLog -Path $State.log_path -Event "evaluation_valid" -Data @{ path = $State.evaluation_path }
}

function Fail-Task {
    param(
        [string]$Status,
        [string]$Message,
        [string]$LogPath,
        [string]$ReportPath,
        [System.Collections.IDictionary]$Report
    )

    $Report.status = $Status
    Write-TaskLog -Path $LogPath -Event "task_failed" -Data @{ status = $Status; message = $Message }
    Write-TaskReport -Path $ReportPath -Report $Report
    if ($script:state -and $script:state.record_run_manifest -and $script:state.manifest_started -and -not [string]::IsNullOrWhiteSpace($script:state.manifest_path)) {
        $script:state.run_status = "failed"
        Write-RunManifest -Path $script:state.manifest_path -State $script:state -Report $Report -RepoRoot $script:repoRoot
    }
    throw $Message
}

function Block-UnsafeArgument {
    param(
        [string]$Token,
        [string]$Reason,
        [string]$LogPath,
        [string]$ReportPath,
        [System.Collections.IDictionary]$Report
    )

    Fail-Task -Status "blocked_args" -Message "Unsafe Codex argument blocked: '$Token' ($Reason)" -LogPath $LogPath -ReportPath $ReportPath -Report $Report
}

$repoRoot = Get-RepoRoot -ScriptDir $PSScriptRoot
$timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$artifactsDir = Join-Path $repoRoot ".codex\\artifacts"
$reportsDir = Join-Path $repoRoot ".codex\\reports"
foreach ($dir in @($artifactsDir, $reportsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$state = [ordered]@{
    preset = "safe"
    runtime = "host"
    task_type = "implementation"
    workflow_level = "standard"
    record_run_manifest = $false
    evaluation_template = $false
    require_evaluation = $false
    require_clean_git = $false
    require_run_id = $false
    max_iterations = $null
    run_id = $null
    run_root = $null
    evaluation_file_path = $null
    evaluation_path = $null
    primary_failure_category = $null
    prompt_file = $null
    prompt = $null
    output_file = Join-Path $artifactsDir ("codex-task-" + $timestamp + ".json")
    output_schema = $null
    report_path = Join-Path $reportsDir ("codex-task-" + $timestamp + ".report.json")
    verify_command = $null
    allow_search = $false
    skip_preflight = $false
    skip_verify = $false
    log_path = Get-DefaultLogPath -RepoRoot $repoRoot -Timestamp $timestamp -RunId $null
    explicit_output_file = $false
    explicit_report_path = $false
    explicit_log_path = $false
    manifest_path = $null
    manifest_started = $false
    run_status = "pending"
    validation_status = "not_run"
    validation_commands = @()
    validation_warnings = @()
    allowed_files = (New-Object System.Collections.Generic.List[string])
    allowed_dirs = (New-Object System.Collections.Generic.List[string])
    allowed_globs = (New-Object System.Collections.Generic.List[string])
    expected_changed_files = (New-Object System.Collections.Generic.List[string])
    expected_missing_behavior = "fail"
    changed_files = @()
    scope_violation = $false
}

$report = [ordered]@{
    runtime = $state.runtime
    preset = $state.preset
    mode = $state.preset
    run_id = $state.run_id
    cwd = $repoRoot
    git_branch = Get-GitBranch -RepoRoot $repoRoot
    git_dirty = Get-GitDirty -RepoRoot $repoRoot
    prompt_source = ""
    output_file = $state.output_file
    output_schema = $null
    log_path = $state.log_path
    codex_exit_code = $null
    verify_exit_code = $null
    status = "pending"
}

$normalizedArguments = New-Object System.Collections.Generic.List[string]
if ($PSBoundParameters.ContainsKey('Preset')) { $normalizedArguments.Add('--preset'); $normalizedArguments.Add($Preset) }
if ($PSBoundParameters.ContainsKey('Runtime')) { $normalizedArguments.Add('--runtime'); $normalizedArguments.Add($Runtime) }
if ($PSBoundParameters.ContainsKey('TaskType')) { $normalizedArguments.Add('--task-type'); $normalizedArguments.Add($TaskType) }
if ($PSBoundParameters.ContainsKey('WorkflowLevel')) { $normalizedArguments.Add('--workflow-level'); $normalizedArguments.Add($WorkflowLevel) }
if ($RecordRunManifest) { $normalizedArguments.Add('--record-run-manifest') }
if ($PSBoundParameters.ContainsKey('PromptFile')) { $normalizedArguments.Add('--prompt-file'); $normalizedArguments.Add($PromptFile) }
if ($PSBoundParameters.ContainsKey('OutputFile')) { $normalizedArguments.Add('--output-file'); $normalizedArguments.Add($OutputFile) }
if ($PSBoundParameters.ContainsKey('OutputSchema')) { $normalizedArguments.Add('--output-schema'); $normalizedArguments.Add($OutputSchema) }
if ($PSBoundParameters.ContainsKey('ReportPath')) { $normalizedArguments.Add('--report-path'); $normalizedArguments.Add($ReportPath) }
if ($PSBoundParameters.ContainsKey('VerifyCommand')) { $normalizedArguments.Add('--verify-command'); $normalizedArguments.Add($VerifyCommand) }
if ($AllowSearch) { $normalizedArguments.Add('--allow-search') }
if ($SkipPreflight) { $normalizedArguments.Add('--skip-preflight') }
if ($SkipVerify) { $normalizedArguments.Add('--skip-verify') }
if ($EvaluationTemplate) { $normalizedArguments.Add('--evaluation-template') }
if ($RequireEvaluation) { $normalizedArguments.Add('--require-evaluation') }
if ($RequireCleanGit) { $normalizedArguments.Add('--require-clean-git') }
if ($RequireRunId) { $normalizedArguments.Add('--require-run-id') }
if ($PSBoundParameters.ContainsKey('MaxIterations')) { $normalizedArguments.Add('--max-iterations'); $normalizedArguments.Add($MaxIterations) }
if ($PSBoundParameters.ContainsKey('LogPath')) { $normalizedArguments.Add('--log-path'); $normalizedArguments.Add($LogPath) }
if ($PSBoundParameters.ContainsKey('RunId')) { $normalizedArguments.Add('--run-id'); $normalizedArguments.Add($RunId) }
if ($PSBoundParameters.ContainsKey('AllowedFiles')) {
    foreach ($value in $AllowedFiles) {
        $normalizedArguments.Add('--allowed-files')
        $normalizedArguments.Add($value)
    }
}
if ($PSBoundParameters.ContainsKey('AllowedDirs')) {
    foreach ($value in $AllowedDirs) {
        $normalizedArguments.Add('--allowed-dirs')
        $normalizedArguments.Add($value)
    }
}
if ($PSBoundParameters.ContainsKey('AllowedGlobs')) {
    foreach ($value in $AllowedGlobs) {
        $normalizedArguments.Add('--allowed-globs')
        $normalizedArguments.Add($value)
    }
}
if ($PSBoundParameters.ContainsKey('ExpectedChangedFiles')) {
    foreach ($value in $ExpectedChangedFiles) {
        $normalizedArguments.Add('--expected-changed-files')
        $normalizedArguments.Add($value)
    }
}
if ($PSBoundParameters.ContainsKey('ExpectedMissing')) { $normalizedArguments.Add('--expected-missing'); $normalizedArguments.Add($ExpectedMissing) }
if ($Arguments) {
    foreach ($arg in $Arguments) {
        $normalizedArguments.Add($arg)
    }
}

function Convert-ToRepoRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-IsPathUnderRoot -Path $Path -Root $RepoRoot)) {
        return ($Path -replace '\\', '/')
    }

    $fullRoot = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.TrimEnd('\', '/') -eq $fullRoot) {
        return "."
    }

    $relative = $fullPath.Substring($fullRoot.Length).TrimStart('\', '/')
    return ($relative -replace '\\', '/')
}
$Arguments = $normalizedArguments.ToArray()

$positionals = New-Object System.Collections.Generic.List[string]
$i = 0
while ($i -lt $Arguments.Count) {
    $token = $Arguments[$i]
    switch ($token) {
        '--preset' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--preset requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.preset = $Arguments[$i]
        }
        '--runtime' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--runtime requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.runtime = $Arguments[$i]
        }
        '--task-type' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--task-type requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.task_type = $Arguments[$i]
        }
        '--workflow-level' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--workflow-level requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.workflow_level = $Arguments[$i]
        }
        '--prompt-file' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--prompt-file requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.prompt_file = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
        }
        '--output-file' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--output-file requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.output_file = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
            $state.explicit_output_file = $true
        }
        '--output-schema' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--output-schema requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.output_schema = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
        }
        '--report-path' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--report-path requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.report_path = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
            $state.explicit_report_path = $true
        }
        '--verify-command' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--verify-command requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.verify_command = $Arguments[$i]
        }
        '--allow-search' { $state.allow_search = $true }
        '--skip-preflight' { $state.skip_preflight = $true }
        '--skip-verify' { $state.skip_verify = $true }
        '--evaluation-template' { $state.evaluation_template = $true }
        '--require-evaluation' { $state.require_evaluation = $true }
        '--require-clean-git' { $state.require_clean_git = $true }
        '--require-run-id' { $state.require_run_id = $true }
        '--log-path' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--log-path requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.log_path = Resolve-RepoPath -RepoRoot $repoRoot -Path $Arguments[$i]
            $state.explicit_log_path = $true
        }
        '--max-iterations' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--max-iterations requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.max_iterations = $Arguments[$i]
        }
        '--run-id' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--run-id requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.run_id = $Arguments[$i]
        }
        '--allowed-files' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--allowed-files requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            try {
                Add-NormalizedScopePaths -Target $state.allowed_files -RawList $Arguments[$i] -OptionName '--allowed-files'
            }
            catch {
                Fail-Task -Status "invalid_args" -Message $_.Exception.Message -LogPath $state.log_path -ReportPath $state.report_path -Report $report
            }
        }
        '--allowed-dirs' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--allowed-dirs requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            try {
                Add-NormalizedDirectoryScopePaths -Target $state.allowed_dirs -RawList $Arguments[$i] -OptionName '--allowed-dirs'
            }
            catch {
                Fail-Task -Status "invalid_args" -Message $_.Exception.Message -LogPath $state.log_path -ReportPath $state.report_path -Report $report
            }
        }
        '--allowed-globs' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--allowed-globs requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            try {
                Add-NormalizedScopeGlobs -Target $state.allowed_globs -RawList $Arguments[$i] -OptionName '--allowed-globs'
            }
            catch {
                Fail-Task -Status "invalid_args" -Message $_.Exception.Message -LogPath $state.log_path -ReportPath $state.report_path -Report $report
            }
        }
        '--expected-changed-files' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--expected-changed-files requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            try {
                Add-NormalizedScopePaths -Target $state.expected_changed_files -RawList $Arguments[$i] -OptionName '--expected-changed-files'
            }
            catch {
                Fail-Task -Status "invalid_args" -Message $_.Exception.Message -LogPath $state.log_path -ReportPath $state.report_path -Report $report
            }
        }
        '--expected-missing' {
            $i++
            if ($i -ge $Arguments.Count) { Fail-Task -Status "invalid_args" -Message "--expected-missing requires a value" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
            $state.expected_missing_behavior = $Arguments[$i]
        }
        '--record-run-manifest' { $state.record_run_manifest = $true }
        '--dangerously-bypass-approvals-and-sandbox' { Block-UnsafeArgument -Token $token -Reason "dangerous bypass is prohibited" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--config*' -or $_ -like '-c*' } { Block-UnsafeArgument -Token $token -Reason "user config overrides are blocked; wrapper injects fixed safety settings" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--sandbox*' -or $_ -like '-s*' } { Block-UnsafeArgument -Token $token -Reason "sandbox mode is fixed by wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--ask-for-approval*' -or $_ -like '-a*' } { Block-UnsafeArgument -Token $token -Reason "approval policy is fixed by wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--profile*' -or $_ -like '-p*' } { Block-UnsafeArgument -Token $token -Reason "profiles are fixed by wrapper presets" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--cd*' -or $_ -like '-C*' } { Block-UnsafeArgument -Token $token -Reason "working root is fixed by wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--enable*' -or $_ -like '--disable*' } { Block-UnsafeArgument -Token $token -Reason "feature flags are blocked in safe wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        '--search' { Block-UnsafeArgument -Token $token -Reason "web search is disabled by default in safe wrapper" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        { $_ -like '--add-dir*' -or $_ -eq '--full-auto' } { Block-UnsafeArgument -Token $token -Reason "additional writable directories are not allowed" -LogPath $state.log_path -ReportPath $state.report_path -Report $report }
        default {
            if ($token.StartsWith('-')) {
                Fail-Task -Status "invalid_args" -Message "Unsupported codex-task option: $token" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
            }
            $positionals.Add($token)
        }
    }
    $i++
}

$state.allowed_files = @(Get-SortedUniqueStrings -Values @($state.allowed_files))
$state.allowed_dirs = @(Get-SortedUniqueStrings -Values @($state.allowed_dirs))
$state.allowed_globs = @(Get-SortedUniqueStrings -Values @($state.allowed_globs))
$state.expected_changed_files = @(Get-SortedUniqueStrings -Values @($state.expected_changed_files))

if ($state.expected_missing_behavior -notin @('warn', 'fail')) {
    Fail-Task -Status "invalid_args" -Message "--expected-missing must be warn or fail" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if (@($state.allowed_files).Count -gt 0 -and (-not $state.record_run_manifest -or [string]::IsNullOrWhiteSpace($state.run_id))) {
    Fail-Task -Status "invalid_args" -Message "--allowed-files requires --run-id and --record-run-manifest" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ((@($state.allowed_dirs).Count + @($state.allowed_globs).Count) -gt 0 -and (-not $state.record_run_manifest -or [string]::IsNullOrWhiteSpace($state.run_id))) {
    Fail-Task -Status "invalid_args" -Message "scope options require --run-id and --record-run-manifest" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if (@($state.expected_changed_files).Count -gt 0 -and (-not $state.record_run_manifest -or [string]::IsNullOrWhiteSpace($state.run_id))) {
    Fail-Task -Status "invalid_args" -Message "--expected-changed-files requires --run-id and --record-run-manifest" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($state.evaluation_template -and (-not $state.record_run_manifest -or [string]::IsNullOrWhiteSpace($state.run_id))) {
    Fail-Task -Status "invalid_args" -Message "--evaluation-template requires --run-id and --record-run-manifest" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($state.require_evaluation -and (-not $state.record_run_manifest -or [string]::IsNullOrWhiteSpace($state.run_id))) {
    Fail-Task -Status "invalid_args" -Message "--require-evaluation requires --run-id and --record-run-manifest" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($state.require_run_id -and [string]::IsNullOrWhiteSpace($state.run_id)) {
    Fail-Task -Status "invalid_args" -Message "--require-run-id requires --run-id" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($null -ne $state.max_iterations) {
    $parsedMaxIterations = 0
    if ([string]::IsNullOrWhiteSpace([string]$state.max_iterations) -or
        -not [int]::TryParse([string]$state.max_iterations, [ref]$parsedMaxIterations) -or
        $parsedMaxIterations -lt 1 -or
        $parsedMaxIterations -gt 10) {
        Fail-Task -Status "invalid_args" -Message "--max-iterations must be an integer between 1 and 10" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    $state.max_iterations = $parsedMaxIterations
}

if ($state.record_run_manifest -and [string]::IsNullOrWhiteSpace($state.run_id)) {
    Fail-Task -Status "invalid_args" -Message "--record-run-manifest requires --run-id" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if (-not [string]::IsNullOrWhiteSpace($state.run_id)) {
    if (-not (Test-RunId -RunId $state.run_id)) {
        Fail-Task -Status "invalid_args" -Message "Invalid --run-id: expected YYYYMMDD-HHMMSS-JST" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    $runRoot = Join-Path $repoRoot (Join-Path ".codex\\runs" $state.run_id)
    $state.run_root = $runRoot
    $runsRoot = Join-Path $repoRoot ".codex\\runs"
    if (-not (Test-IsPathUnderRoot -Path $runRoot -Root $runsRoot)) {
        Fail-Task -Status "invalid_args" -Message "Invalid --run-id path: resolved run path escapes .codex/runs" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if (-not $state.explicit_output_file) {
        $state.output_file = Join-Path (Join-Path $runRoot "artifacts") ("codex-task-" + $timestamp + ".json")
    }
    if (-not $state.explicit_report_path) {
        $state.report_path = Join-Path (Join-Path $runRoot "reports") ("codex-task-" + $timestamp + ".report.json")
    }
    if (-not $state.explicit_log_path) {
        $state.log_path = Get-DefaultLogPath -RepoRoot $repoRoot -Timestamp $timestamp -RunId $state.run_id
    }
    if ($state.record_run_manifest) {
        $state.manifest_path = Join-Path $runRoot "run.json"
    }
    $state.evaluation_file_path = Join-Path $runRoot "evaluation.json"
}

$report.runtime = $state.runtime
$report.preset = $state.preset
$report.mode = $state.preset
$report.run_id = $state.run_id
$report.output_file = $state.output_file
$report.output_schema = $state.output_schema
$report.log_path = $state.log_path
$report.git_branch = Get-GitBranch -RepoRoot $repoRoot
$report.git_dirty = Get-GitDirty -RepoRoot $repoRoot

$logParent = Split-Path -Parent $state.log_path
if (-not (Test-Path $logParent)) {
    New-Item -ItemType Directory -Path $logParent -Force | Out-Null
}

if ($state.preset -notin @("safe", "readonly", "auto-net")) {
    Fail-Task -Status "invalid_args" -Message "Unsupported preset: $($state.preset)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($state.runtime -notin @("host", "docker-sandbox")) {
    Fail-Task -Status "invalid_args" -Message "Unsupported runtime: $($state.runtime)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($state.task_type -notin @("plan", "review", "implementation", "investigation", "repair", "harness-improvement")) {
    Fail-Task -Status "invalid_args" -Message "Invalid --task-type: $($state.task_type)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if ($state.workflow_level -notin @("lightweight", "standard", "strict")) {
    Fail-Task -Status "invalid_args" -Message "Invalid --workflow-level: $($state.workflow_level)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

$cwd = (Get-Location).Path
if (-not (Test-IsPathUnderRoot -Path $cwd -Root $repoRoot)) {
    $cwd = $repoRoot
}
$report.cwd = $cwd

if ($state.record_run_manifest) {
    $state.manifest_started = $true
    $state.run_status = "running"
    Write-RunManifest -Path $state.manifest_path -State $state -Report $report -RepoRoot $repoRoot
}

Invoke-CleanGitPrecondition -State $state -Report $report -RepoRoot $repoRoot
Write-TaskLog -Path $state.log_path -Event "wrapper_start" -Data @{ runtime = $state.runtime; preset = $state.preset; run_id = $state.run_id }
Initialize-EvaluationTemplate -State $state -RepoRoot $repoRoot
if ($state.record_run_manifest) {
    Write-RunManifest -Path $state.manifest_path -State $state -Report $report -RepoRoot $repoRoot
}

$prompt = if ($state.prompt_file) {
    if (-not (Test-Path $state.prompt_file)) {
        Fail-Task -Status "invalid_args" -Message "Prompt file not found: $($state.prompt_file)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    $report.prompt_source = $state.prompt_file
    Get-Content -Raw $state.prompt_file
}
else {
    $report.prompt_source = "inline"
    ($positionals -join ' ')
}

if ([string]::IsNullOrWhiteSpace($prompt)) {
    Fail-Task -Status "invalid_args" -Message "Prompt text is required" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

foreach ($path in @($state.output_file, $state.report_path)) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

if ($state.output_schema -and -not (Test-Path $state.output_schema)) {
    Fail-Task -Status "invalid_args" -Message "Output schema not found: $($state.output_schema)" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

if (-not $state.skip_preflight) {
    Write-TaskLog -Path $state.log_path -Event "preflight_start" -Data @{}
    try {
        $preflightArgs = @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $repoRoot "scripts\\codex-safe.ps1"), "-Preset", $state.preset, "-PreflightOnly")
        if (-not [string]::IsNullOrWhiteSpace($state.run_id)) {
            $preflightArgs += @("-RunId", $state.run_id)
        }
        & powershell.exe @preflightArgs | Out-Null
        Write-TaskLog -Path $state.log_path -Event "preflight_ok" -Data @{}
    }
    catch {
        Fail-Task -Status "preflight_failed" -Message "codex-safe preflight failed" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
}

$sandboxMode = if ($state.preset -eq "readonly") { "read-only" } else { "workspace-write" }
$approvalPolicy = "never"
$profileName = switch ($state.preset) {
    "readonly" { "repo_readonly" }
    "auto-net" { "repo_auto_net" }
    default { "repo_safe" }
}
$codexCmd = try { Get-CodexCommand } catch { $null }
if (-not $codexCmd) {
    Fail-Task -Status "codex_missing" -Message "codex command not found in PATH" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

Write-TaskLog -Path $state.log_path -Event "codex_exec_start" -Data @{ runtime = $state.runtime; output_file = $state.output_file }
$codexArgs = @("--profile", $profileName, "--ask-for-approval", $approvalPolicy)
if ($state.allow_search) {
    $codexArgs += "--search"
}
$execArgs = @("exec", "-C", $cwd, "--sandbox", $sandboxMode, "--output-last-message", $state.output_file)
if ($state.output_schema) {
    $execArgs += @("--output-schema", $state.output_schema)
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$CommandArgs
    )

    $prevNativeErr = $null
    $hasNativeErrPref = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)
    if ($hasNativeErrPref) {
        $prevNativeErr = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        & $Command @CommandArgs
        return $LASTEXITCODE
    }
    finally {
        if ($hasNativeErrPref) {
            $PSNativeCommandUseErrorActionPreference = $prevNativeErr
        }
    }
}

if ($state.runtime -eq "host") {
    $report.codex_exit_code = Invoke-NativeCommand -Command $codexCmd -CommandArgs ($codexArgs + $execArgs + $prompt)
}
else {
    $dockerCmd = try { Get-DockerCommand } catch { $null }
    if (-not $dockerCmd) {
        Fail-Task -Status "docker_unavailable" -Message "docker command not found in PATH" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if ([string]::IsNullOrWhiteSpace($env:CODEX_DOCKER_IMAGE)) {
        Fail-Task -Status "docker_unavailable" -Message "Set CODEX_DOCKER_IMAGE before using docker-sandbox runtime" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if (-not (Test-IsPathUnderRoot -Path $state.output_file -Root $repoRoot)) {
        Fail-Task -Status "docker_unavailable" -Message "docker-sandbox output file must be under repository root" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if ($state.output_schema -and -not (Test-IsPathUnderRoot -Path $state.output_schema -Root $repoRoot)) {
        Fail-Task -Status "docker_unavailable" -Message "docker-sandbox output schema must be under repository root" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }
    if (-not (Test-IsPathUnderRoot -Path $cwd -Root $repoRoot)) {
        Fail-Task -Status "docker_unavailable" -Message "docker-sandbox working directory must be under repository root" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
    }

    $dockerArgs = @("run", "--rm", "-v", "${repoRoot}:/workspace", "-w", "/workspace")
    $homeCodex = Join-Path $HOME ".codex"
    if (Test-Path $homeCodex) {
        $dockerArgs += @("-v", "${homeCodex}:/root/.codex")
    }
    if (-not [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
        $dockerArgs += @("-e", "OPENAI_API_KEY")
    }

    $containerArgs = @("codex", "--profile", $profileName, "--ask-for-approval", $approvalPolicy)
    if ($state.allow_search) {
        $containerArgs += "--search"
    }
    $containerArgs += @(
        "exec",
        "-C", (Convert-ToContainerPath -RepoRoot $repoRoot -Path $cwd),
        "--sandbox", $sandboxMode,
        "--output-last-message", (Convert-ToContainerPath -RepoRoot $repoRoot -Path $state.output_file)
    )
    if ($state.output_schema) {
        $containerArgs += @("--output-schema", (Convert-ToContainerPath -RepoRoot $repoRoot -Path $state.output_schema))
    }
    $report.codex_exit_code = Invoke-NativeCommand -Command $dockerCmd -CommandArgs ($dockerArgs + @($env:CODEX_DOCKER_IMAGE) + $containerArgs + $prompt)
}

Write-TaskLog -Path $state.log_path -Event "codex_exec_exit" -Data @{ exit_code = $report.codex_exit_code }
if ($state.record_run_manifest) {
    $state.changed_files = @(Get-GitChangedFiles -RepoRoot $repoRoot)
    Write-RunManifest -Path $state.manifest_path -State $state -Report $report -RepoRoot $repoRoot
}
if ($report.codex_exit_code -ne 0) {
    $report.status = "codex_failed"
    Write-TaskReport -Path $state.report_path -Report $report
    $state.run_status = "failed"
    if ($state.record_run_manifest) {
        Write-RunManifest -Path $state.manifest_path -State $state -Report $report -RepoRoot $repoRoot
    }
    exit $report.codex_exit_code
}

if (-not (Test-Path $state.output_file)) {
    Fail-Task -Status "missing_output" -Message "codex exec completed without writing output file" -LogPath $state.log_path -ReportPath $state.report_path -Report $report
}

Invoke-ScopeChecks -State $state -Report $report -RepoRoot $repoRoot

if ($state.output_schema) {
    try {
        Invoke-JsonSchemaValidation -SchemaPath $state.output_schema -JsonPath $state.output_file
        Write-TaskLog -Path $state.log_path -Event "schema_ok" -Data @{}
        Add-ValidationCommand -State $state -Command "output schema validation" -ExitCode 0 -Status "passed" -Evidence "output schema validation passed"
    }
    catch {
        $report.status = "invalid_output"
        $message = $_.Exception.Message
        Write-TaskLog -Path $state.log_path -Event "schema_failed" -Data @{ message = $message }
        Add-ValidationCommand -State $state -Command "output schema validation" -ExitCode 1 -Status "failed" -Evidence "output schema validation failed"
        Write-TaskReport -Path $state.report_path -Report $report
        $state.run_status = "failed"
        if ($state.record_run_manifest) {
            Write-RunManifest -Path $state.manifest_path -State $state -Report $report -RepoRoot $repoRoot
        }
        exit 1
    }
}

if ($state.skip_verify) {
    $report.status = "verify_skipped"
    $state.run_status = "completed"
    if ($state.validation_status -ceq 'not_run') {
        $state.validation_status = 'skipped'
    }
}
else {
    $verifyCommand = $state.verify_command
    if ([string]::IsNullOrWhiteSpace($verifyCommand)) {
        if (Test-Path (Join-Path $repoRoot "scripts\\verify.ps1")) {
            $verifyCommand = "powershell.exe -ExecutionPolicy Bypass -File scripts/verify.ps1"
        }
        elseif ((Get-Command bash -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $repoRoot "scripts\\verify"))) {
            $verifyCommand = "bash scripts/verify"
        }
    }

    if ([string]::IsNullOrWhiteSpace($verifyCommand)) {
        $report.status = "verify_skipped"
        $state.run_status = "completed"
        if ($state.validation_status -ceq 'not_run') {
            $state.validation_status = 'skipped'
        }
        Write-TaskLog -Path $state.log_path -Event "verify_skipped" -Data @{}
    }
    else {
        Write-TaskLog -Path $state.log_path -Event "verify_start" -Data @{ command = $verifyCommand }
        try {
            $report.verify_exit_code = Invoke-VerifyCommand -CommandText $verifyCommand -RepoRoot $repoRoot
        }
        catch {
            $report.verify_exit_code = 1
            Write-TaskLog -Path $state.log_path -Event "verify_failed_to_start" -Data @{ message = $_.Exception.Message }
        }
        Write-TaskLog -Path $state.log_path -Event "verify_exit" -Data @{ exit_code = $report.verify_exit_code }

        if ($report.verify_exit_code -ne 0) {
            $report.status = "verify_failed"
            Add-ValidationCommand -State $state -Command $verifyCommand -ExitCode $report.verify_exit_code -Status "failed" -Evidence "verify command failed"
            Write-TaskReport -Path $state.report_path -Report $report
            $state.run_status = "failed"
            if ($state.record_run_manifest) {
                Write-RunManifest -Path $state.manifest_path -State $state -Report $report -RepoRoot $repoRoot
            }
            exit $report.verify_exit_code
        }

        $report.status = "ok"
        $state.run_status = "completed"
        Add-ValidationCommand -State $state -Command $verifyCommand -ExitCode $report.verify_exit_code -Status "passed" -Evidence "verify command completed successfully"
    }
}

Invoke-RequiredEvaluationValidation -State $state -Report $report -RepoRoot $repoRoot

Write-TaskReport -Path $state.report_path -Report $report
if ($state.record_run_manifest) {
    Write-RunManifest -Path $state.manifest_path -State $state -Report $report -RepoRoot $repoRoot
}
exit 0
