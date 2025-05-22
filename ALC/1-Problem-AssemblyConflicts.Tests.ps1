using namespace System.IO

Describe "Assembly Conflict Real Life Examples" {
    BeforeAll {
        $s = [Path]::DirectorySeparatorChar
    }

    It "Can import MSAL.PS by itself" {
        Import-Module -Name MSAL.PS
        Get-Module -Name MSAL.PS | Should -Not -BeNullOrEmpty
    }

    It "Can import dbatools by itself" {
        Import-Module -Name dbatools
        Get-Module -Name dbatools | Should -Not -BeNullOrEmpty
    }

    It "Can import dbatools before MSAL.PS" {
        Import-Module -Name dbatools

        # Needed to stop the prompt that MSAL.PS will show if it finds a conflict
        Import-Module -Name MSAL.PS -ArgumentList @{
            'dll.lenientLoading' = $true
            'dll.lenientLoadingPrompt' = $false
        }

        $dbatoolsLibraryBase = (Get-Module -Name dbatools.library).ModuleBase
        [Microsoft.Identity.Client.TokenCache].Assembly.Location | Should -Be "$dbatoolsLibraryBase${s}core${s}lib${s}Microsoft.Identity.Client.dll"
        [Microsoft.Identity.Client.TokenCache].Assembly.GetName().Version | Should -Be '4.56.0.0'
    }

    It "Fails to import dbatools after MSAL.PS" {
        $msal = Import-Module -Name MSAL.PS -PassThru
        {
            Import-Module -Name dbatools
        } | Should -Throw -ExpectedMessage "*Couldn't import *Microsoft.Data.SqlClient.dll*Could not load file or assembly 'Microsoft.Identity.Client, Version=4.56.0.0, *"

        [Microsoft.Identity.Client.TokenCache].Assembly.Location | Should -Be "$($msal.ModuleBase)${s}Microsoft.Identity.Client.4.37.0${s}netcoreapp2.1${s}Microsoft.Identity.Client.dll"
        [Microsoft.Identity.Client.TokenCache].Assembly.GetName().Version | Should -Be '4.37.0.0'
    }
}
