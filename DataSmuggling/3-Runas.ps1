# Running something as system is easy if you have psexec
# But it sucks to try and capture output or provide more
# complex values to the script
psexec.exe -accepteula -s pwsh.exe -Command '[Environment]::UserName'

# Using the New-ScheduledTaskSession cmdlet can do it for you
. "$PSScriptRoot\New-ScheduledTaskSession.ps1"

$session = New-ScheduledTaskSession -UserName SYSTEM
Invoke-Command -Session $session -ScriptBlock {
    [Environment]::UserName
}
$session | Remove-PSSession

# If you wanted to become TrustedInstaller you can do a similar
# thing with ProcessEx
Import-Module -Name ProcessEx

Start-Service -Name TrustedInstaller
$tiPid = (Get-CimInstance -ClassName Win32_Service -Filter 'Name="TrustedInstaller"').ProcessId
$startupInfo = New-StartupInfo -ParentProcess $tiPid -WindowStyle Hide
$tiProc = Start-ProcessEx -FilePath pwsh.exe -StartupInfo $startupInfo -PassThru
$session = $null
try {
    $connInfo = [System.Management.Automation.Runspaces.NamedPipeConnectionInfo]::new(
        [int]$tiProc.ProcessId)
    $runspace = [RunspaceFactory]::CreateRunspace($connInfo, $host, $null)
    $runspace.Open()
    $session = [System.Management.Automation.Runspaces.PSSession]::Create(
        $runspace,
        "TIProc",
        $null)

    Invoke-Command -Session $session -ScriptBlock {
        whoami /all
    }

    # Enter-PSSession -Session $session
    $a = ""
}
finally {
    if ($session) {
        $session | Remove-PSSession
    }
    $tiProc | Stop-Process -Force
}

<#
It can also do it interactively in a simpler way

Start-Service -Name TrustedInstaller
$tiPid = (Get-CimInstance -ClassName Win32_Service -Filter 'Name="TrustedInstaller"').ProcessId
$startupInfo = New-StartupInfo -ParentProcess $tiPid -WindowStyle Hide
$tiProc = Start-ProcessEx -FilePath pwsh.exe -StartupInfo $startupInfo -PassThru
Enter-PSHostProcess -Id $tiProc.ProcessId

...

$tiProc | Stop-Process
#>
