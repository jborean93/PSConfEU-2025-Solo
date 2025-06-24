using namespace System.Collections.Generic

$ErrorActionPreference = 'Stop'

$Script:PwshModuleLoggingRegPath = 'HKLM:\Software\Policies\Microsoft\PowerShellCore\ModuleLogging'
$Script:PwshModuleLoggingRegName = 'EnableModuleLogging'
$Script:PwshModuleLoggingNameRegName = 'ModuleNames'

Function Get-SniffMetadata {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        Id = 'PwshModuleLogging'
        Description = 'PowerShell 7 Module Logging'
        RequiresPattern = $false
    }
}

Function Enable-SniffMonitoring {
    [CmdletBinding()]
    param ()

    $stateValue = $null
    $moduleNameValue = $null
    $regKey = Get-Item -LiteralPath $Script:PwshModuleLoggingRegPath -ErrorAction Ignore
    if ($regKey) {
        $stateValue = $regKey.GetValue($Script:PwshModuleLoggingRegName, $null)
        $moduleNameValue = $regKey.GetValue($Script:PwshModuleLoggingNameRegName, $null)
    }
    else {
        New-Item -Path $Script:PwshModuleLoggingRegPath -Force | Out-Null
    }

    $regParams = @{
        LiteralPath = $Script:PwshModuleLoggingRegPath
        Force = $true
    }
    New-ItemProperty @regParams -Name $Script:PwshModuleLoggingRegName -Value 1 -PropertyType DWord | Out-Null
    New-ItemProperty @regParams -Name $Script:PwshModuleLoggingNameRegName -Value 'Microsoft.PowerShell.Security' -PropertyType String | Out-Null

    [PSCustomObject]@{
        DeleteKey = $null -eq $regKey
        OldStateValue = $stateValue
        OldModuleNameValue = $moduleNameValue
    }
}

Function Disable-SniffMonitoring {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [bool]
        $DeleteKey,

        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [object]
        $OldStateValue,

        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [object]
        $OldModuleNameValue
    )

    process {
        if ($DeleteKey) {
            Remove-Item -LiteralPath $Script:PwshModuleLoggingRegPath -Force
            return
        }

        if ($OldStateValue) {
            $regParams = @{
                LiteralPath = $Script:PwshModuleLoggingRegPath
                Name = $Script:PwshModuleLoggingRegName
                Value = $OldStateValue
                PropertyType = 'DWord'
                Force = $true
            }
            New-ItemProperty @regParams | Out-Null
        }
        else {
            Remove-ItemProperty -LiteralPath $Script:PwshModuleLoggingRegPath -Name $Script:PwshModuleLoggingRegName
        }

        if ($OldModuleNameValue) {
            $regParams = @{
                LiteralPath = $Script:PwshModuleLoggingRegPath
                Name = $Script:PwshModuleLoggingNameRegName
                Value = $OldModuleNameValue
                PropertyType = 'String'
                Force = $true
            }
            New-ItemProperty @regParams | Out-Null
        }
        else {
            Remove-ItemProperty -LiteralPath $Script:PwshModuleLoggingRegPath -Name $Script:PwshModuleLoggingNameRegName
        }
    }
}

Function Start-SniffCapture {
    [CmdletBinding()]
    param ()

    $start = Get-Date
    $found = [HashSet[Int64]]::new()

    while ($true) {
        $auditEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'PowerShellCore/Operational'
            Id = 4103
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

            $contextInfo = @{}
            $eventInfo.ContextInfo -split "\r?\n" | ForEach-Object {
                $line = $_.Trim()
                if (-not $line) {
                    return
                }

                $split = $line -split '\s+=\s*', 2
                if ($split[1]) {
                    $contextInfo[$split[0]] = $split[1]
                }
                else {
                    $contextInfo[$split[0]] = $null
                }
            }

            if ($contextInfo['Command Name'] -ne 'ConvertTo-SecureString') {
                return
            }

            $stringMatch = $eventInfo.Payload -split "\r?\n" | Where-Object {
                $_ -match 'ParameterBinding\(ConvertTo-SecureString\): name="String"; value="(.*)"'
            }
            if ($stringMatch) {
                $eventParams = @{
                    Message = "ConvertTo-SecureString plaintext string - [red]$($Matches[1])[/]"
                    Detail = @(
                        "Payload"
                        $eventInfo.Payload
                        "Host Application"
                        $contextInfo['Host Application']
                        "Script Name"
                        $contextInfo['Script Name']
                    ) -join "`n"
                }
                Write-SniffEvent @eventParams
            }
        }

        if ($staleEvents) {
            Start-Sleep -Seconds 1
        }
    }
}
