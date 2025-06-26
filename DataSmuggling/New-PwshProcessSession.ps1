# Copyright: (c) 2025, Jordan Borean (@jborean93) <jborean93@gmail.com>
# MIT License (see LICENSE or https://opensource.org/licenses/MIT)

#Requires -Module ProcessEx

using namespace System.Diagnostics
using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces

Function New-PwshProcessSession {
    <#
    .SYNOPSIS
    Creates a PSSession for a new PowerShell process with an optional parent.

    .DESCRIPTION
    Creates a PSSession that can be used to run code inside a new PowerShell
    process. The process will spawn as a child of the current process but can
    be spawned as a child of a custom parent process so that we can do things
    like run as another user/session.

    .PARAMETER PowerShellPath
    Override the PowerShell executable used, by default will use the current
    PowerShell executable.

    .PARAMETER ParentProcessId
    Set to the process id of the parent process to spawn the new pwsh process
    under. The new process will inherit the security token of the specified
    parent.

    .PARAMETER OpenTimeout
    The timeout, in seconds, to wait for the PowerShell process to connect to
    the named pipe it creates.

    .EXAMPLE
        $s = New-PwshProcessSession
        Invoke-Command $s { whoami /all }
        $s | Remove-PSSession

    Runs task as current user and closes the session once done.

    .EXAMPLE

        $lsass = Get-Process -Name lsass
        $s = New-PwshProcessSession -ParentProcessId $lsass.Id
        Invoke-Command $s { whoami }
        $s | Remove-PSSession

    Runs task as SYSTEM.
    #>
    [OutputType([PSSession])]
    [CmdletBinding(DefaultParameterSetName = "UserName")]
    param (
        [Parameter()]
        [string]
        $PowerShellPath,

        [Parameter()]
        [int]
        $ParentProcessId,

        [Parameter()]
        [int]
        $OpenTimeout = 30
    )

    $ErrorActionPreference = 'Stop'

    # PowerShell 7.3 created a public way to build a PSSession but WinPS needs
    # to use reflection to build the PSSession from the Runspace object.
    $createPSSession = if ([PSSession]::Create) {
        {
            [PSSession]::Create($args[0], "Pwsh-$($args[0])", $null)
        }
    }
    else {
        $remoteRunspaceType = [PSObject].Assembly.GetType('System.Management.Automation.RemoteRunspace')
        $pssessionCstr = [PSSession].GetConstructor(
            'NonPublic, Instance',
            $null,
            [type[]]@($remoteRunspaceType),
            $null)

        { $pssessionCstr.Invoke(@($args[0])) }
    }

    if (-not $PowerShellPath) {
        $PowerShellPath = [Process]::GetCurrentProcess().MainModule.FileName
        # wsmprovhost is used in a WSMan PSRemoting target, we need to change
        # that to the proper executable.
        $systemRoot = $env:SystemRoot
        if (-not $systemRoot) {
            $systemRoot = 'C:\Windows'
        }
        if ($PowerShellPath -in @(
            "$systemRoot\system32\wsmprovhost.exe"
            "$systemRoot\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe"
        )) {
            $executable = if ($IsCoreCLR) {
                'pwsh.exe'
            }
            else {
                'powershell.exe'
            }

            $PowerShellPath = Join-Path $PSHome $executable
        }
    }
    # Resolve the absolute path for PowerShell for the CIM filter to work.
    if (Test-Path -LiteralPath $PowerShellPath) {
        $PowerShellPath = (Get-Item -LiteralPath $PowerShellPath).FullName
    }
    elseif ($powershellCommand = Get-Command -Name $PowerShellPath -CommandType Application -ErrorAction SilentlyContinue) {
        $PowerShellPath = $powershellCommand.Path
    }
    else {
        $exc = [ArgumentException]::new("Failed to find PowerShellPath '$PowerShellPath'")
        $err = [ErrorRecord]::new(
            $exc,
            'FailedToFindPowerShell',
            'InvalidArgument',
            $PowerShellPath)
        $PSCmdlet.WriteError($err)
        return
    }

    $siParams = @{
        WindowStyle = 'Hide'
    }
    if ($ParentProcessId) {
        $siParams.ParentProcess = $ParentProcessId
    }
    $si = New-StartupInfo @siParams

    Write-Verbose -Message "Creating process with executable '$PowerShellPath'"
    $stopProc = $true
    $runspace = $null

    $procParams = @{
        FilePath = $PowerShellPath
        StartupInfo = $si
        PassThru = $true
    }
    $proc = Start-ProcessEx @procParams
    try {
        $typeTable = [TypeTable]::LoadDefaultTypeFiles()
        $connInfo = [NamedPipeConnectionInfo]::new($proc.ProcessId)
        $connInfo.OpenTimeout = $OpenTimeout * 1000
        $runspace = [RunspaceFactory]::CreateRunspace($connInfo, $Host, $typeTable)
        $runspace.Open()

        Write-Verbose "Registering handler to stop the process on closing the PSSession"
        $null = Register-ObjectEvent -InputObject $runspace -EventName StateChanged -MessageData $proc.ProcessId -Action {
            if ($EventArgs.RunspaceStateInfo.State -in @('Broken', 'Closed')) {
                Unregister-Event -SourceIdentifier $EventSubscriber.SourceIdentifier
                Stop-Process -Id $Event.MessageData -Force
            }
        }
        $stopProc = $false

        Write-Verbose "Runspace opened, creating PSSession object"
        & $createPSSession $runspace
    }
    catch {
        if ($stopProc -and $proc) {
            Stop-Process -Id $proc.ProcessId -Force
        }
        if ($runspace) {
            $runspace.Dispose()
        }

        $err = [ErrorRecord]::new(
            $_.Exception,
            'FailedToOpenSession',
            'NotSpecified',
            $null)
        $PSCmdlet.WriteError($err)
    }
}
