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
    return (Get-Content -Raw $fullPath | ConvertFrom-Json)
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
    $content = Get-Content -Raw (Join-Path $repoRoot $RelativePath)
    foreach ($pattern in $Patterns) {
        if ($content -notmatch [regex]::Escape($pattern)) {
            throw "Pattern '$pattern' not found in $RelativePath"
        }
    }
}

$workflow = Read-SpecFile -RelativePath "spec/workflow.yaml"
$routing = Read-SpecFile -RelativePath "spec/routing.yaml"
$safety = Read-SpecFile -RelativePath "spec/safety-policy.yaml"
$naming = Read-SpecFile -RelativePath "spec/naming.yaml"

foreach ($path in $workflow.required_files) {
    Assert-Exists -RelativePath $path
}

Assert-Contains -RelativePath $routing.instructions.file -Patterns $routing.instructions.must_contain
Assert-Contains -RelativePath $routing.planning.file -Patterns $routing.planning.must_contain
Assert-Contains -RelativePath $routing.review.file -Patterns $routing.review.must_contain

foreach ($skillPath in $routing.skills) {
    Assert-Exists -RelativePath $skillPath
}

foreach ($wrapperPath in $safety.wrappers) {
    Assert-Exists -RelativePath $wrapperPath
    Assert-Contains -RelativePath $wrapperPath -Patterns $safety.blocked_tokens
}

foreach ($wrapperPath in $safety.delegating_wrappers) {
    Assert-Exists -RelativePath $wrapperPath
}

Assert-Exists -RelativePath $safety.rules_dir
Assert-Exists -RelativePath $safety.verify

Assert-Contains -RelativePath "template/docs/reference/naming-conventions.md" -Patterns @(
    $naming.plan_docs.pattern,
    $naming.report_docs.pattern,
    $naming.history_docs.pattern
)

Write-Host "PASS: spec validation"
