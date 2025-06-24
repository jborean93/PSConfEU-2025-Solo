# Some actions won't let you run things over a NETWORK logon.
# Common one I've seen is the Windows Update API
Invoke-Command -HostName localhost {
    $wua = New-Object -ComObject Microsoft.Update.SystemInfo
    $wua.RebootRequired
}

# Works normally on an interactive logon
$wua = New-Object -ComObject Microsoft.Update.SystemInfo
$wua.RebootRequired

# Invoke-Command does show that we are running as admin
Invoke-Command -HostName localhost {
    whoami /all
}

# What can we do, use psexec to run as SYSTEM
# Sucks as:
#   - Stderr come across as error records and psexec uses it for process
#   - psexec doesn't come with Windows
#   - Need to deal with complex command line escaping and passing in data
#   - Parsing the output can also be difficult
Invoke-Command -HostName localhost {
    psexec.exe -accepteula -s pwsh.exe -Command '(New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired'
}

# A nice pwsh way is to use PSRemoting with a scheduled task target
# The New-ScheduledTaskSession.ps1 contains a script that can create
# one of these sessions for you. All data exchanged is done through
# this transport without any files and while the objects exchanged
# are serialized they are still objects
Invoke-Command -HostName localhost {
    . "$using:PSScriptRoot\New-ScheduledTaskSession.ps1"

    $session = New-ScheduledTaskSession
    Invoke-Command -Session $session -ScriptBlock {
        # Anything run inside here will be a new process spawned under
        # the scheduled task process.
        $wua = New-Object -ComObject Microsoft.Update.SystemInfo
        $wua.RebootRequired
    }
    $session | Remove-PSSession
}

# Looking at the whoami output we can see that this is running
# as the same user but now with the BATCH logon
Invoke-Command -HostName localhost {
    . "$using:PSScriptRoot\New-ScheduledTaskSession.ps1"

    $session = New-ScheduledTaskSession
    Invoke-Command -Session $session -ScriptBlock {
        whoami /all
    }
    $session | Remove-PSSession
}

# Another problem is credential delegation, we cannot
# access this network path without using CredSSP or
# Kerberos delegation.
Invoke-Command -HostName localhost {
    $item = Get-Item \\dc01.domain.test\C$\Windows
    $item.FullName
}

# It works normally though
$item = Get-Item \\dc01.domain.test\C$\Windows
$item.FullName

# With the scheduled task we can provide explicit credentials
$targetCred = Get-Credential
Invoke-Command -HostName localhost {
    . "$using:PSScriptRoot\New-ScheduledTaskSession.ps1"

    $session = New-ScheduledTaskSession -Credential $using:targetCred
    Invoke-Command -Session $session -ScriptBlock {
        $item = Get-Item \\dc01.domain.test\C$\Windows
        $item.FullName
    }
    $session | Remove-PSSession
}
