[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$templateRoot = Join-Path $sourceRepoRoot "template"
$validator = Join-Path $templateRoot "scripts/validate-output-schema.py"
$evaluationSchema = Join-Path $sourceRepoRoot "spec/evaluation.schema.json"
$taxonomyPath = Join-Path $sourceRepoRoot "spec/failure-taxonomy.json"
$candidatesPath = Join-Path $templateRoot "examples/harness-improvement/harness-improvement-candidates.json"

$pythonPath = $null
$pythonArgs = @()
foreach ($candidate in @("python", "py")) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if (-not $cmd) {
        continue
    }
    $probeArgs = @("--version")
    $runArgs = @()
    if ($candidate -eq "py") {
        $probeArgs = @("-3", "--version")
        $runArgs = @("-3")
    }
    & $cmd.Path @probeArgs *> $null
    if ($LASTEXITCODE -eq 0) {
        $pythonPath = $cmd.Path
        $pythonArgs = $runArgs
        break
    }
}
if (-not $pythonPath) {
    throw "python3 or python is required"
}

$requiredPaths = @(
    (Join-Path $templateRoot ".agents/skills/repair-loop/SKILL.md"),
    (Join-Path $templateRoot ".agents/skills/repair-loop/references/repair-workflow.md"),
    (Join-Path $templateRoot ".agents/skills/harness-improvement/SKILL.md"),
    (Join-Path $templateRoot ".agents/skills/harness-improvement/references/improvement-workflow.md"),
    (Join-Path $templateRoot "docs/reference/repair-loop.md"),
    (Join-Path $templateRoot "docs/reference/harness-improvement-loop.md"),
    (Join-Path $templateRoot "examples/repair-loop/README.md"),
    (Join-Path $templateRoot "examples/repair-loop/iteration-1-evaluation.json"),
    (Join-Path $templateRoot "examples/repair-loop/iteration-2-evaluation.json"),
    (Join-Path $templateRoot "examples/repair-loop/repair-summary.md"),
    (Join-Path $templateRoot "examples/harness-improvement/README.md"),
    (Join-Path $templateRoot "examples/harness-improvement/harness-improvement-candidates.json"),
    (Join-Path $templateRoot "examples/harness-improvement/harness-improvement-review.md")
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path $path)) {
        throw "Required path missing: $path"
    }
}

& $pythonPath @pythonArgs $validator $evaluationSchema (Join-Path $templateRoot "examples/repair-loop/iteration-1-evaluation.json")
if ($LASTEXITCODE -ne 0) {
    throw "Schema validation failed for iteration-1-evaluation.json"
}

& $pythonPath @pythonArgs $validator $evaluationSchema (Join-Path $templateRoot "examples/repair-loop/iteration-2-evaluation.json")
if ($LASTEXITCODE -ne 0) {
    throw "Schema validation failed for iteration-2-evaluation.json"
}

$taxonomy = Get-Content -Raw $taxonomyPath | ConvertFrom-Json
$candidatesDoc = Get-Content -Raw $candidatesPath | ConvertFrom-Json
$categories = @($taxonomy.categories | ForEach-Object { $_.category })
$candidates = @($candidatesDoc.candidates)
if ($candidates.Count -lt 3) {
    throw "Expected at least three harness improvement candidates"
}

$strictnessValues = @($candidates | ForEach-Object { $_.strictness } | Sort-Object -Unique)
if (Compare-Object -ReferenceObject @("blocked", "normal", "strict") -DifferenceObject $strictnessValues) {
    throw "Unexpected strictness values: $($strictnessValues -join ', ')"
}

$index = 0
foreach ($candidate in $candidates) {
    $index++
    if ($candidate.failure_category -notin $categories) {
        throw "candidate[$index] has invalid failure_category"
    }
    $sourceRuns = @($candidate.source_runs)
    if ($sourceRuns.Count -eq 0) {
        throw "candidate[$index].source_runs must be a non-empty array"
    }
    if (@($sourceRuns | Where-Object { ($_ -is [string]) -and -not [string]::IsNullOrWhiteSpace($_) }).Count -ne $sourceRuns.Count) {
        throw "candidate[$index].source_runs must contain only non-empty strings"
    }
    $evidence = @($candidate.evidence)
    if ($evidence.Count -eq 0) {
        throw "candidate[$index] must include evidence"
    }
    if (@($evidence | Where-Object { ($_ -is [string]) -and -not [string]::IsNullOrWhiteSpace($_) }).Count -ne $evidence.Count) {
        throw "candidate[$index].evidence must contain only non-empty strings"
    }
}

Push-Location $sourceRepoRoot
try {
    bash "template/scripts/verify"
    if ($LASTEXITCODE -ne 0) {
        throw "template/scripts/verify failed"
    }
} finally {
    Pop-Location
}

Write-Host "PASS: repair improvement workflow checks"
