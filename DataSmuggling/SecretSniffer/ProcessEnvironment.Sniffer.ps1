using namespace System.Collections.Generic
using namespace System.Runtime.InteropServices

$ErrorActionPreference = 'Stop'

Import-Module -Name ProcessEx

Function Get-SniffMetadata {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        Id = 'ProcessEnv'
        Description = 'Process Environment Value'
        RequiresPattern = $true
    }
}

Function Enable-SniffMonitoring {
    [CmdletBinding()]
    param ()
}

Function Disable-SniffMonitoring {
    [CmdletBinding()]
    param ()
}

Function Start-SniffCapture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Pattern
    )

    $start = Get-Date
    $found = [HashSet[string]]::new()

    while ($true) {
        Get-Process -Name pwsh | ForEach-Object -Process {
            try {
                $procInfo = $_ | Get-ProcessEx
            }
            catch {
                return
            }

            foreach ($kvp in $procInfo.Environment.GetEnumerator()) {
                $value = "$($kvp.Key)=$($kvp.Value)"

                if (-not $found.Add("$($procInfo.ProcessId) $value")) {
                    continue
                }

                if (($details = [Regex]::Match($value, $Pattern, 'IgnoreCase')).Success) {
                    $envSnippet = $value |
                        Get-ContextSubstring -Index $details.Index -Length $details.Length -Extra 20

                    $eventParams = @{
                        Message = "Process $($procInfo.ProcessId) has a env var secret - $envSnippet"
                        Detail = @(
                            "CommandLine"
                            $procInfo.CommandLine
                            "ProcessId"
                            $procInfo.ProcessId
                            $value
                        ) -join "`n"
                    }
                    Write-SniffEvent @eventParams
                }
            }
        }
    }
}
