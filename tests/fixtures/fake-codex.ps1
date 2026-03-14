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
        '^Remove-Item -Recurse tmp$' { return 'forbidden' }
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
            '--ask-for-approval' { $i++ }
            '--search' { }
            '--json' { }
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

if ($Args.Count -ge 1 -and $Args[0] -eq 'exec') {
    Invoke-FakeExec -ExecArgs $Args[1..($Args.Count - 1)]
}

if ($Args.Count -ge 1 -and $Args[0] -eq '--help') {
    Write-Host 'fake codex help'
    exit 0
}

exit 0
