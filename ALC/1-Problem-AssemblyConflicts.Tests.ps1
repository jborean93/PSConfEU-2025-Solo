using namespace System.IO

Describe "Assembly Conflict Real Life Examples" {
    It "Can import MSAL.PS by itself" {
        Import-Module -Name MSAL.PS
        Get-Module -Name MSAL.PS | Should -Not -BeNullOrEmpty

        $msalBase = (Get-Module -Name MSAL.PS).ModuleBase
        $expectedLocation = [Path]::Combine(
            $msalBase,
            "Microsoft.Identity.Client.4.37.0",
            "netcoreapp2.1",
            "Microsoft.Identity.Client.dll")
        [Microsoft.Identity.Client.TokenCache].Assembly.Location | Should -Be $expectedLocation
        [Microsoft.Identity.Client.TokenCache].Assembly.GetName().Version | Should -Be '4.37.0.0'
    }

    It "Can import dbatools by itself" {
        Import-Module -Name dbatools
        Get-Module -Name dbatools | Should -Not -BeNullOrEmpty

        $dbatoolsLibraryBase = (Get-Module -Name dbatools.library).ModuleBase
        $expectedLocation = [Path]::Combine(
            $dbatoolsLibraryBase,
            "core",
            "lib",
            "win-sqlclient",
            "Microsoft.Identity.Client.dll")
        [Microsoft.Identity.Client.TokenCache].Assembly.Location | Should -Be $expectedLocation
        [Microsoft.Identity.Client.TokenCache].Assembly.GetName().Version | Should -Be '4.53.0.0'
    }

    It "Can import dbatools before MSAL.PS" {
        Import-Module -Name dbatools

        # Needed to stop the prompt that MSAL.PS will show if it finds a conflict
        Import-Module -Name MSAL.PS -ArgumentList @{
            'dll.lenientLoading' = $true
            'dll.lenientLoadingPrompt' = $false
        }

        $dbatoolsLibraryBase = (Get-Module -Name dbatools.library).ModuleBase
        $expectedLocation = [Path]::Combine(
            $dbatoolsLibraryBase,
            "core",
            "lib",
            "win-sqlclient",
            "Microsoft.Identity.Client.dll")
        [Microsoft.Identity.Client.TokenCache].Assembly.Location | Should -Be $expectedLocation
        [Microsoft.Identity.Client.TokenCache].Assembly.GetName().Version | Should -Be '4.53.0.0'
    }

    It "Fails to import dbatools after MSAL.PS" {
        $msal = Import-Module -Name MSAL.PS -PassThru

        $expectedError = @(
            "*Couldn't import *Microsoft.Data.SqlClient.dll*"
            "Could not load file or assembly 'Microsoft.Identity.Client, Version=4.56.0.0, *"
        ) -join ""
        {
            Import-Module -Name dbatools
        } | Should -Throw -ExpectedMessage $expectedError

        $expectedLocation = [Path]::Combine(
            $msal.ModuleBase,
            "Microsoft.Identity.Client.4.37.0",
            "netcoreapp2.1",
            "Microsoft.Identity.Client.dll")
        [Microsoft.Identity.Client.TokenCache].Assembly.Location | Should -Be $expectedLocation
        [Microsoft.Identity.Client.TokenCache].Assembly.GetName().Version | Should -Be '4.37.0.0'
    }
}
