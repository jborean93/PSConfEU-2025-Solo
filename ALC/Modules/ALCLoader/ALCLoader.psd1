@{
    RootModule = 'ALCLoader.psm1'
    ModuleVersion = '1.0.0'
    GUID = '35f25d8d-ed25-4559-ba5c-2868be7b7c20'
    Author = 'Jordan Borean'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Jordan Borean. All rights reserved.'
    Description = 'Example module that loads the Tomlyn 0.19.0 .NET assembly into an ALC using the ALCLoader method'
    PowerShellVersion = '5.1'
    DotNetFrameworkVersion = '4.7.2'
    FunctionsToExport = @()
    CmdletsToExport = @(
        'Get-TomlPropertyDisplayKind'
        'Get-ComplexType'
        'Set-ComplexType'
    )
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{}
    }
}
