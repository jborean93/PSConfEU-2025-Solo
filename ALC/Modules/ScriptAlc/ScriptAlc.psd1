@{
    RootModule = 'ScriptAlc.psm1'
    ModuleVersion = '1.0.0'
    GUID = '00ef103e-9187-4d8e-8d05-ba3291888216'
    Author = 'Jordan Borean'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Jordan Borean. All rights reserved.'
    Description = 'Example module that loads the Tomlyn 0.19.0 .NET assembly into an ALC using pure PowerShell code'
    PowerShellVersion = '5.1'
    DotNetFrameworkVersion = '4.7.2'
    FunctionsToExport = @('Get-TomlPropertyDisplayKind')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{}
    }
}
