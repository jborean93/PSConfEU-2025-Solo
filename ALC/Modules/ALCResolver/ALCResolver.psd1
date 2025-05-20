@{
    RootModule = if ($PSEdition -eq 'Core') {
        'bin/net8.0/ALCResolver.dll'
    } else {
        'bin/net472/ALCResolver.dll'
    }
    ModuleVersion = '1.0.0'
    GUID = '40da592b-3540-4a90-b58c-25ee78f5b007'
    Author = 'Jordan Borean'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Jordan Borean. All rights reserved.'
    Description = 'Example module that loads the Tomlyn 0.19.0 .NET assembly into an ALC using the ALCResolver method'
    PowerShellVersion = '5.1'
    DotNetFrameworkVersion = '4.7.2'
    FunctionsToExport = @()
    CmdletsToExport = @('Get-TomlPropertyDisplayKind')
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{}
    }
}
