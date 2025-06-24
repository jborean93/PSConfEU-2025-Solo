using namespace System.Collections.Generic
using namespace System.Runtime.InteropServices

$ErrorActionPreference = 'Stop'

Import-Module -Name Ctypes, PSPrivilege

ctypes_struct AUDIT_POLICY_INFORMATION {
    [Guid]$AuditSubCategoryGuid
    [int]$AuditingInformation
    [Guid]$AuditCategoryGuid
}

$Script:Advapi32 = New-CtypesLib Advapi32.dll

$Script:ProcessCreationSubcategory = [Guid]'{0CCE922B-69AE-11D9-BED3-505054503030}'
$Script:POLICY_AUDIT_EVENT_SUCCESS = 0x00000001
$Script:POLICY_AUDIT_EVENT_FAILURE = 0x00000002
$Script:POLICY_AUDIT_EVENT_NONE = 0x00000004

$Script:CmdLineAuditRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
$Script:CmdLineAuditRegName = 'ProcessCreationIncludeCmdLine_Enabled'

Function Get-SniffMetadata {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        Id = 'CmdlineAuditing'
        Description = 'Command Line Auditing'
        RequiresPattern = $true
    }
}

Function Enable-SniffMonitoring {
    [CmdletBinding()]
    param ()

    Enable-ProcessPrivilege -Name SeSecurityPrivilege

    $resetProcessCreationPolicy = 0
    $existingProcessCreationPolicy = [IntPtr]::Zero
    try {
        $policyMarshaling = [MarshalAsAttribute]::new([UnmanagedType]::LPArray)
        $policyMarshaling.SizeParamIndex = 1
        $res = $Script:Advapi32.SetLastError().AuditQuerySystemPolicy[bool](
            $Script:Advapi32.MarshalAs([Guid[]]@($Script:ProcessCreationSubcategory), $policyMarshaling),
            1,
            [ref]$existingProcessCreationPolicy)
        if (-not $res) {
            $PSCmdlet.WriteError($Script:Advapi32.GetLastErrorRecord("AuditQuerySystemPolicyFailed"))
            return
        }

        $auditInfo = [Marshal]::PtrToStructure[AUDIT_POLICY_INFORMATION](
            $existingProcessCreationPolicy)
        if (
            ($auditInfo.AuditingInformation -band $Script:POLICY_AUDIT_EVENT_SUCCESS) -eq 0 -or
            ($auditInfo.AuditingInformation -band $Script:POLICY_AUDIT_EVENT_FAILURE) -eq 0
        ) {
            if ($auditInfo.AuditingInformation -eq 0) {
                $resetProcessCreationPolicy = $Script:POLICY_AUDIT_EVENT_NONE
            }
            else {
                $resetProcessCreationPolicy = $auditInfo.AuditingInformation
            }

            $auditInfo.AuditingInformation = $Script:POLICY_AUDIT_EVENT_SUCCESS -bor $Script:POLICY_AUDIT_EVENT_FAILURE
            $res = $Script:Advapi32.SetLastError().AuditSetSystemPolicy[bool](
                [ref]$auditInfo,
                1)
            if (-not $res) {
                $PSCmdlet.WriteError($Script:Advapi32.GetLastErrorRecord("AuditSetSystemPolicy"))
                return
            }
        }

        $regValue = $null
        $regKey = Get-Item -LiteralPath $Script:CmdLineAuditRegPath -ErrorAction Ignore
        if ($regKey) {
            $regValue = $regKey.GetValue($Script:CmdLineAuditRegName, $null)
        }
        else {
            New-Item -Path $Script:CmdLineAuditRegPath -Force | Out-Null
        }

        $regParams = @{
            LiteralPath = $Script:CmdLineAuditRegPath
            Name = $Script:CmdLineAuditRegName
            Value = 1
            PropertyType = 'DWord'
            Force = $true
        }
        New-ItemProperty @regParams | Out-Null

        [PSCustomObject]@{
            AuditState = $resetProcessCreationPolicy
            DeleteKey = $null -eq $regKey
            OldValue = $regValue
        }
    }
    finally {
        if ($existingProcessCreationPolicy -ne [IntPtr]::Zero) {
            $Script:Advapi32.AuditFree[void]($existingProcessCreationPolicy)
        }
    }
}

Function Disable-SniffMonitoring {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [int]
        $AuditState,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [bool]
        $DeleteKey,

        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [object]
        $OldValue
    )

    process {
        if ($AuditState) {
            # Need to set NONE to unset any options not specified by
            # $resetProcessCreationPolicy
            $auditInfo = [AUDIT_POLICY_INFORMATION]@{
                AuditSubCategoryGuid = $Script:ProcessCreationSubcategory
                AuditingInformation = $Script:POLICY_AUDIT_EVENT_NONE -bor $PreviousState
            }
            $res = $Script:Advapi32.AuditSetSystemPolicy([ref]$auditInfo, 1)
            if (-not $res) {
                $PSCmdlet.WriteError($Script:Advapi32.GetLastErrorRecord("AuditSetSystemPolicy"))
                return
            }
        }

        if ($DeleteKey) {
            Remove-Item -LiteralPath $Script:CmdLineAuditRegPath -Force
        }
        elseif ($OldValue) {
            $regParams = @{
                LiteralPath = $Script:CmdLineAuditRegPath
                Name = $Script:CmdLineAuditRegName
                Value = $OldValue
                PropertyType = 'DWord'
                Force = $true
            }
            New-ItemProperty @regParams | Out-Null
        }
        else {
            Remove-ItemProperty -LiteralPath $Script:CmdLineAuditRegPath -Name $Script:CmdLineAuditRegName
        }
    }
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

    while ($true) {
        $auditEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            Id = 4688
            NewProcessName = "$PSHome\pwsh.exe"
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

            if (($details = [Regex]::Match($eventInfo.CommandLine, $Pattern, 'IgnoreCase')).Success) {
                $cmdLine = @(
                    $eventInfo.CommandLine.Substring(0, $details.Index)
                    "[red]"
                    $eventInfo.CommandLine.Substring($details.Index, $details.Length)
                    "[/]"
                    $eventInfo.CommandLine.Substring($details.Index + $details.Length)
                ) -join ""
                $cmdSnippet = $eventInfo.CommandLine |
                    Get-ContextSubstring -Index $details.Index -Length $details.Length -Extra 20

                $procId = [Convert]::ToInt32($eventInfo.NewProcessId, 16)
                $parentProcId = [Convert]::ToInt32($eventInfo.ProcessId, 16)
                $eventParams = @{
                    Message = "New process $procId has secret in command line - $cmdSnippet"
                    Detail = @(
                        "PID"
                        $procId
                        "Executable"
                        $eventInfo.NewProcessName
                        "CommandLine"
                        $cmdLine
                        "Parent PID"
                        $parentProcId
                        "Parent Executable"
                        $eventInfo.ParentProcessName
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
