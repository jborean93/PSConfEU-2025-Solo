@{
    RootModule = 'NestedModuleOld.psm1'
    ModuleVersion = '1.0.0'
    GUID = '0d6ce1c5-aa3d-4f24-bd70-2602e5a6320a'
    Author = 'Jordan Borean'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Jordan Borean. All rights reserved.'
    Description = 'Example module that loads an assembly with a conflict on a child dependency'
    PowerShellVersion = '5.1'
    DotNetFrameworkVersion = '4.7.2'
    FunctionsToExport = @('Get-NestedValue')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{}
    }
}
