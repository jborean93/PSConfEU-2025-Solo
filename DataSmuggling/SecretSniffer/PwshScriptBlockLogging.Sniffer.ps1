using namespace System.Collections.Generic

$ErrorActionPreference = 'Stop'

Function Get-SniffMetadata {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        Id = 'PwshScriptBlockLogging'
        Description = 'PowerShell 7 ScriptBlock Logging'
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
    $found = [HashSet[Int64]]::new()

    $scriptBlocks = @{}

    while ($true) {
        $auditEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'PowerShellCore/Operational'
            Id = 4104
            StartTime = $start
        } -ErrorAction Ignore -Oldest

        $staleEvents = $true
        $auditEvents | ForEach-Object -Process {
            $start = $_.TimeCreated
            $eventXml = [xml]$_.ToXml()

            if (-not $found.Add($eventXml.Event.System.EventRecordID)) {
                return
            }
            $staleEvents = $false

            $eventInfo = @{}
            $eventXml.Event.EventData.Data |
                ForEach-Object -Process {
                    $eventInfo[$_.Name] = $_.'#text'
                }

            if ($scriptBlocks.Contains($eventInfo.ScriptBlockId)) {
                $store = $scriptBlocks[$eventInfo.ScriptBlockId]
            }
            else {
                $store = [List[string]]::new()
                $scriptBlocks[$eventInfo.ScriptBlockId]
            }

            $store.Add($eventInfo.ScriptBlockText)
            if ($store.Count -ne $eventInfo.MessageTotal) {
                return
            }

            $scriptBlocks.Remove($eventInfo.ScriptBlockId)
            $text = $store -join "`n"

            if (($details = [Regex]::Match($text, $Pattern, 'IgnoreCase')).Success) {
                $sbkSnippet = $text |
                    Get-ContextSubstring -Index $details.Index -Length $details.Length -Extra 20
                $sbkDetail = $text |
                    Get-ContextSubstring -Index $details.Index -Length $details.Length -Extra 500
                $eventParams = @{
                    Message = "New process $procId has secret in command line - $sbkSnippet"
                    Detail = $sbkDetail
                }
                Write-SniffEvent @eventParams
            }
        }

        if ($staleEvents) {
            Start-Sleep -Seconds 1
        }
    }
}
