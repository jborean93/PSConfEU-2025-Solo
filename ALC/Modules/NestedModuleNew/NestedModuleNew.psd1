@{
    RootModule = 'NestedModuleNew.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'ca88da2e-1c20-4385-a49d-23df996ac641'
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
