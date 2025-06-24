# The minishell is a primitive way to run pwsh code
# without having to deal with quoting hell and serialization
# of objects yourself.
# The | Out-String should not be needed but there's a bug in
# vscode I need to track down.

Function ConvertFrom-EncodedString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Value
    )

    [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Value))
}

Function Format-Xml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Value
    )

    $xml = [xml]$Value
    $xml.Save([Console]::Out)
}

# We can easily pass in a complex string with different quoting
# styles without any issues
pwsh {
    "This is a string with 'single' and ""double"" quotes"
} | Out-String

# Equivalent in Pwsh 7 isn't too bad but still more complex
pwsh -Command '"This is a string with ''single'' and ""double"" quotes"'

# WinPS 5.1 is worse though as it doesn't escape " in the required way.
pwsh -Command '\"This is a string with ''single'' and \"\"double\"\" quotes\"'

# We can pass in arguments as well
pwsh {
    param ($Path, $Password)

    "Path '$Path'"
    "SecureString '$([Net.NetworkCredential]::new('', $Password).Password)'"
} -args @(
    'C:\Program Files',
    (ConvertTo-SecureString -AsPlainText -Force -String 'Secret')
 ) | Out-String

# We can pass in complex objects and receive them back
$out = pwsh {
    $args[0].Path

    [PSCustomObject]@{
        SomeProp = 1
    }
} -args @(
    [PSCustomObject]@{
        Path = 'C:\Program Files'
    }
)

# Although we quickly run into command line limits if we
# pass in complex objects
pwsh {
    $args[0].ProcessId
} -args (Get-Process -Id $pid)

# You can see what happens when using {} as a command argument
.\print_argv.exe { 'foo' } | Out-String

# The arguments themselves also become serialized
.\print_argv.exe {
} -args @(
    [PSCustomObject]@{Path = 'C:\Program Files'}
    (ConvertTo-SecureString -AsPlainText -Force -String 'Secret')
) | Out-String

# The output is also serialized in pwsh so we can receive
# richer objects back
.\print_argv.exe {
    [PSCustomObject]@{ Path = 'C:\Program Files' }
    (ConvertTo-SecureString -AsPlainText -Force -String 'Secret')
} | Out-String
