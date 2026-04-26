[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$denyPatterns = @(
    @{ Pattern = '(^|[\s;&|])rm\s+(-[^\s]*[rf][^\s]*\s+)?'; Reason = 'rm deletion is forbidden' },
    @{ Pattern = '(^|[\s;&|])(del|erase|rmdir|unlink)\b'; Reason = 'file deletion is forbidden' },
    @{ Pattern = '\bRemove-Item\b'; Reason = 'Remove-Item is forbidden' },
    @{ Pattern = '\b(Move-Item|Rename-Item)\b[^\n\r]*(\s-Force\b|\s-force\b)'; Reason = 'forced move/rename is forbidden' },
    @{ Pattern = '(^|[\s;&|])mv\s+-f\b'; Reason = 'forced move is forbidden' },
    @{ Pattern = '\bfind\b[^\n\r]*\s-delete\b'; Reason = 'find -delete is forbidden' },
    @{ Pattern = '\brsync\b[^\n\r]*\s--delete\b'; Reason = 'rsync --delete is forbidden' },
    @{ Pattern = '\brobocopy\b[^\n\r]*(\s/MIR\b|\s/mir\b)'; Reason = 'robocopy /MIR is forbidden' },
    @{ Pattern = '\bgit\s+(add|commit|push|rm)\b'; Reason = 'git staging, commit, push, and rm are forbidden' },
    @{ Pattern = '\bgit\s+reset\s+--hard\b'; Reason = 'git reset --hard is forbidden' },
    @{ Pattern = '\bgit\s+clean\s+-[^\s]*[fdx][^\s]*\b'; Reason = 'git clean is forbidden' },
    @{ Pattern = '\bdocker\s+(system|volume|network|image)\s+prune\b'; Reason = 'docker prune is forbidden' },
    @{ Pattern = '\bterraform\s+(apply|destroy)\b'; Reason = 'terraform apply/destroy is forbidden' },
    @{ Pattern = '\bkubectl\s+(apply|delete)\b'; Reason = 'kubectl apply/delete is forbidden' },
    @{ Pattern = '\bhelm\s+uninstall\b'; Reason = 'helm uninstall is forbidden' },
    @{ Pattern = '\baws\s+s3\s+rm\b'; Reason = 'aws s3 rm is forbidden' },
    @{ Pattern = '\baz\s+group\s+delete\b'; Reason = 'az group delete is forbidden' },
    @{ Pattern = '\bgcloud\s+projects\s+delete\b'; Reason = 'gcloud projects delete is forbidden' },
    @{ Pattern = '\b(curl|wget)\b[^\n\r|]*\|\s*(bash|sh)\b'; Reason = 'remote script piping is forbidden' },
    @{ Pattern = '\b(iwr|irm|Invoke-WebRequest|Invoke-RestMethod)\b[^\n\r|]*\|\s*(iex|Invoke-Expression)\b'; Reason = 'PowerShell remote script execution is forbidden' },
    @{ Pattern = '^\*\*\* Delete File:'; Reason = 'patch file deletion is forbidden' },
    @{ Pattern = '^(rename from|rename to|deleted file mode)\b'; Reason = 'patch rename/delete is forbidden' }
)

$textKeys = @(
    'command',
    'cmd',
    'args',
    'arguments',
    'input',
    'patch',
    'content',
    'text',
    'script'
)

function Write-HookDecision {
    param(
        [Parameter(Mandatory = $true)][string]$Decision,
        [string]$Reason,
        [string]$Tool
    )

    $payload = [ordered]@{ decision = $Decision }
    if (-not [string]::IsNullOrWhiteSpace($Reason)) { $payload.reason = $Reason }
    if (-not [string]::IsNullOrWhiteSpace($Tool)) { $payload.tool = $Tool }
    $payload | ConvertTo-Json -Compress
}

function Get-ToolName {
    param([object]$Payload)

    foreach ($key in @('tool_name', 'tool', 'name')) {
        if ($Payload.PSObject.Properties.Name -contains $key) {
            $value = $Payload.$key
            if ($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }
    }
    return 'unknown'
}

function Get-TextValues {
    param(
        [object]$Value,
        [string]$Key = ''
    )

    $items = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Value) {
        return $items
    }

    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Key) -or $textKeys -contains $Key) {
            $items.Add($Value)
        }
        return $items
    }

    if ($Value -is [System.Array]) {
        $allStrings = $true
        foreach ($item in $Value) {
            if ($item -isnot [string]) {
                $allStrings = $false
                break
            }
        }
        if (($Key -in @('args', 'arguments', 'command', 'cmd')) -and $allStrings) {
            $items.Add(($Value -join ' '))
        }
        foreach ($item in $Value) {
            foreach ($text in (Get-TextValues -Value $item -Key $Key)) {
                $items.Add($text)
            }
        }
        return $items
    }

    foreach ($property in $Value.PSObject.Properties) {
        foreach ($text in (Get-TextValues -Value $property.Value -Key $property.Name)) {
            $items.Add($text)
        }
    }
    return $items
}

$raw = [Console]::In.ReadToEnd()
try {
    $payload = $raw | ConvertFrom-Json
}
catch {
    Write-HookDecision -Decision 'block' -Reason "Unable to parse hook payload: $($_.Exception.Message)" -Tool 'unknown'
    exit 0
}

if ($null -eq $payload) {
    Write-HookDecision -Decision 'allow'
    exit 0
}

$tool = Get-ToolName -Payload $payload
foreach ($text in (Get-TextValues -Value $payload)) {
    foreach ($entry in $denyPatterns) {
        if ($text -match $entry.Pattern) {
            Write-HookDecision -Decision 'block' -Reason $entry.Reason -Tool $tool
            exit 0
        }
    }
}

Write-HookDecision -Decision 'allow'
exit 0
