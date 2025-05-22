@{
    RootModule = 'AssemblyResolver.psm1'
    ModuleVersion = '1.0.0'
    GUID = '5b1a04b3-51d8-46a8-8c16-96b99e7864e7'
    Author = 'Jordan Borean'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Jordan Borean. All rights reserved.'
    Description = 'Example module that loads an assembly with a custom assembly resolver'
    PowerShellVersion = '5.1'
    DotNetFrameworkVersion = '4.7.2'
    FunctionsToExport = @('Get-NewValue', 'Get-OldValue')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{}
    }
}
