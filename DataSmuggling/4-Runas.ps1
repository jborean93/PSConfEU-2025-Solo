# Running something as system is easy if you have psexec
# But it sucks to try and capture output or provide more
# complex values to the script
psexec.exe -accepteula -s pwsh.exe -Command '[Environment]::UserName'

# Using the New-ScheduledTaskSession cmdlet can do it for you
. .\New-ScheduledTaskSession.ps1

$session = New-ScheduledTaskSession -UserName SYSTEM
Invoke-Command -Session $session -ScriptBlock {
    [Environment]::UserName
}
$session | Remove-PSSession

# If you wanted to become TrustedInstaller you can do a similar
# thing with ProcessEx.
. .\New-PwshProcessSession.ps1

Start-Service -Name TrustedInstaller
$tiPid = (Get-CimInstance -ClassName Win32_Service -Filter 'Name="TrustedInstaller"').ProcessId

$session = New-PwshProcessSession -ParentProcessId $tiPid

Invoke-Command -Session $session -ScriptBlock {
    whoami /all
}
$session | Remove-PSSession

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
