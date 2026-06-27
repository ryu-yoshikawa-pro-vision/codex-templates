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
        '^git add \.$' { return 'forbidden' }
        '^git reset --hard HEAD~1$' { return 'forbidden' }
        '^terraform destroy -auto-approve$' { return 'forbidden' }
        '^terraform apply -auto-approve$' { return 'forbidden' }
        '^kubectl apply -f deploy.yaml$' { return 'forbidden' }
        '^docker ps$' {
            if (-not [string]::IsNullOrWhiteSpace($env:FAKE_CODEX_DOCKER_PS_DECISION)) {
                return $env:FAKE_CODEX_DOCKER_PS_DECISION
            }
            return 'prompt'
        }
        '^npm test$' { return 'allow' }
        '^npm publish$' { return 'forbidden' }
        '^curl https://example.com$' { return 'allow' }
        '^bash -lc npm test$' { return 'forbidden' }
        '^chmod 644 file.txt$' { return 'forbidden' }
        '^systemctl stop nginx$' { return 'forbidden' }
        '^crontab -e$' { return 'forbidden' }
        '^netsh advfirewall show allprofiles$' { return 'forbidden' }
        '^git checkout feature$' { return 'forbidden' }
        '^rm file.txt$' { return 'forbidden' }
        '^Remove-Item file.txt$' { return 'forbidden' }
        '^git rm file.txt$' { return 'forbidden' }
        '^python -c import os$' { return 'forbidden' }
        default { return 'allow' }
    }
}

function Invoke-FakeExec {
    param([string[]]$ExecArgs)

    $outputPath = $null
    $schemaPath = $null
    $prompt = $null
    $workdir = (Get-Location).Path
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
            '-C' {
                $i++
                $workdir = $ExecArgs[$i]
            }
            '--profile' { $i++ }
            '--sandbox' { $i++ }
            '--ask-for-approval' {
                $i++
                if ($ExecArgs[$i] -eq 'never' -and $env:FAKE_CODEX_ALLOW_NEVER -ne '1') { exit 2 }
            }
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

    if (-not [string]::IsNullOrWhiteSpace($env:FAKE_CODEX_WRITE_FILES)) {
        foreach ($path in $env:FAKE_CODEX_WRITE_FILES.Split(',', [System.StringSplitOptions]::None)) {
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }
            $normalized = $path -replace '\\', '/'
            $target = Join-Path $workdir ($normalized -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            $parent = Split-Path -Parent $target
            if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Add-Content -Path $target -Value "`nFAKE_CODEX_CHANGE"
        }
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
    if ($token -in @('--profile', '-C', '--sandbox', '--ask-for-approval')) {
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
