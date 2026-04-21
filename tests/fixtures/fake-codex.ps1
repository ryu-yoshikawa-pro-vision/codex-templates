[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Decision {
    param([string[]]$Tokens)

    $joined = $Tokens -join ' '
    switch -Regex ($joined) {
        '^git status$' { return 'allow' }
        '^rg --files docs$' { return 'allow' }
        '^git add \.$' { return 'prompt' }
        '^git reset --hard HEAD~1$' { return 'forbidden' }
        '^terraform destroy -auto-approve$' { return 'forbidden' }
        '^docker ps$' { return 'prompt' }
        '^rm file.txt$' { return 'forbidden' }
        '^Remove-Item file.txt$' { return 'forbidden' }
        '^git rm file.txt$' { return 'forbidden' }
        default { return 'allow' }
    }
}

function Invoke-FakeExec {
    param([string[]]$ExecArgs)

    $outputPath = $null
    $schemaPath = $null
    $prompt = $null
    $i = 0
    while ($i -lt $ExecArgs.Count) {
        $token = $ExecArgs[$i]
        switch ($token) {
            '--output-last-message' {
                $i++
                $outputPath = $ExecArgs[$i]
            }
            '--output-schema' {
                $i++
                $schemaPath = $ExecArgs[$i]
            }
            '-C' { $i++ }
            '--sandbox' { $i++ }
            '--ask-for-approval' { exit 2 }
            '--search' { exit 2 }
            '--json' { }
            '--definitely-invalid-flag' { exit 2 }
            default {
                if (-not $token.StartsWith('-')) {
                    $prompt = $token
                }
            }
        }
        $i++
    }

    if ($prompt -like '*FAIL_CODEX*') {
        exit 9
    }

    if ($outputPath) {
        $parent = Split-Path -Parent $outputPath
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        if ($prompt -like '*BAD_SCHEMA*') {
            Set-Content -Path $outputPath -Value '{"unexpected":true}'
        }
        elseif ($schemaPath) {
            Set-Content -Path $outputPath -Value '{"status":"ok"}'
        }
        else {
            Set-Content -Path $outputPath -Value 'stub output'
        }
    }

    exit 0
}

if ($Args.Count -ge 2 -and $Args[0] -eq 'execpolicy' -and $Args[1] -eq 'check') {
    $sepIndex = [Array]::IndexOf($Args, '--')
    $tokens = if ($sepIndex -ge 0) { $Args[($sepIndex + 1)..($Args.Count - 1)] } else { @() }
    @{ decision = Get-Decision -Tokens $tokens } | ConvertTo-Json -Compress
    exit 0
}

$start = 0
while ($start -lt $Args.Count) {
    $token = $Args[$start]
    if ($token -in @('-C', '--sandbox', '--ask-for-approval')) {
        $start += 2
        continue
    }
    if ($token -in @('--search', '--json')) {
        $start++
        continue
    }
    break
}

if ($start -lt $Args.Count -and $Args[$start] -eq 'exec') {
    $execArgs = if (($start + 1) -lt $Args.Count) { $Args[($start + 1)..($Args.Count - 1)] } else { @() }
    Invoke-FakeExec -ExecArgs $execArgs
}

if ($Args.Count -ge 1 -and $Args[0] -eq '--help') {
    Write-Host 'fake codex help'
    exit 0
}

exit 0
