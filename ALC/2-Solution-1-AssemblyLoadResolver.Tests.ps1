using namespace System.IO

Describe "Assembly Load Resolver" {
    BeforeAll {
        Import-Module -Name Microsoft.PowerShell.Utility

        $requestedAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GetName().Name -eq 'Microsoft.PowerShell.Commands.Utility' } |
            ForEach-Object GetName |
            Select-Object -ExpandProperty FullName

        $moduleRoot = Join-Path $PSScriptRoot "Modules"
        $s = [Path]::DirectorySeparatorChar
    }

    It "Loads a module normally with no conflicts" {
        $logs = Import-Module "$moduleRoot/AssemblyResolver" -ArgumentList @{
            LogAssemblyLoad = $true
        } 6>&1

        $logs[0] | Should -Be "AssemblyResolver - Resolving assembly: '$moduleRoot${s}AssemblyResolver${s}bin${s}SharedDep.dll, Culture=neutral, PublicKeyToken=null' for '$requestedAssembly'"
        $logs[1] | Should -Be "AssemblyResolver - Processing module assembly requirement 'SharedDep, Version=2.0.0.1, Culture=neutral, PublicKeyToken=null'"
        $logs[2] | Should -Be "AssemblyResolver - Loading new assembly 'SharedDep, Version=2.0.0.1, Culture=neutral, PublicKeyToken=null' from '$moduleRoot${s}AssemblyResolver${s}bin${s}SharedDep.dll'"
        $logs[3] | Should -Be "AssemblyResolver - Resolving assembly: '$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll, Culture=neutral, PublicKeyToken=null' for '$requestedAssembly'"
        $logs[4] | Should -Be "AssemblyResolver - Processing module assembly requirement 'ParentDep2, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null'"
        $logs[5] | Should -Be "AssemblyResolver - Loading new assembly 'ParentDep2, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null' from '$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll'"

        Get-OldValue | Should -Be 'Hello Old World!'
        Get-NewValue | Should -Be 'Hello New World!'

        [ParentDep2.SomeClass].Assembly.Location | Should -Be "$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll"
        [SharedDep.SomeClass].Assembly.Location | Should -Be "$moduleRoot${s}AssemblyResolver${s}bin${s}SharedDep.dll"
        [SharedDep.SomeClass].Assembly.GetName().Version | Should -Be '2.0.0.1'
    }

    It "Assembly already loaded but lucky the right one is loaded" {
        Add-Type -Path "$moduleRoot/AssemblyResolver/bin/SharedDep.dll"

        $logs = Import-Module "$moduleRoot/AssemblyResolver" -ArgumentList @{
            LogAssemblyLoad = $true
        } 6>&1

        $logs[0] | Should -Be "AssemblyResolver - Resolving assembly: '$moduleRoot${s}AssemblyResolver${s}bin${s}SharedDep.dll, Culture=neutral, PublicKeyToken=null' for '$requestedAssembly'"
        $logs[1] | Should -Be "AssemblyResolver - Processing module assembly requirement 'SharedDep, Version=2.0.0.1, Culture=neutral, PublicKeyToken=null'"
        $logs[2] | Should -Be "AssemblyResolver - Using existing loaded assembly 'SharedDep, Version=2.0.0.1, Culture=neutral, PublicKeyToken=null' from '$moduleRoot${s}AssemblyResolver${s}bin${s}SharedDep.dll'"
        $logs[3] | Should -Be "AssemblyResolver - Resolving assembly: '$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll, Culture=neutral, PublicKeyToken=null' for '$requestedAssembly'"
        $logs[4] | Should -Be "AssemblyResolver - Processing module assembly requirement 'ParentDep2, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null'"
        $logs[5] | Should -Be "AssemblyResolver - Loading new assembly 'ParentDep2, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null' from '$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll'"

        Get-OldValue | Should -Be 'Hello Old World!'
        Get-NewValue | Should -Be 'Hello New World!'

        [ParentDep2.SomeClass].Assembly.Location | Should -Be "$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll"
        [SharedDep.SomeClass].Assembly.Location | Should -Be "$moduleRoot${s}AssemblyResolver${s}bin${s}SharedDep.dll"
        [SharedDep.SomeClass].Assembly.GetName().Version | Should -Be '2.0.0.1'
    }

    It "Assembly already loaded but unlucky the wrong one is loaded" {
        Add-Type -Path "$moduleRoot/ParentDep1/bin/Release/netstandard2.0/publish/SharedDep.dll"

        $logs = Import-Module "$moduleRoot/AssemblyResolver" -ArgumentList @{
            LogAssemblyLoad = $true
        } 6>&1

        $logs[0] | Should -Be "AssemblyResolver - Resolving assembly: '$moduleRoot${s}AssemblyResolver${s}bin${s}SharedDep.dll, Culture=neutral, PublicKeyToken=null' for '$requestedAssembly'"
        $logs[1] | Should -Be "AssemblyResolver - Processing module assembly requirement 'SharedDep, Version=2.0.0.1, Culture=neutral, PublicKeyToken=null'"
        $logs[2] | Should -Be "AssemblyResolver - Using existing loaded assembly 'SharedDep, Version=1.0.0.1, Culture=neutral, PublicKeyToken=null' from '$moduleRoot${s}ParentDep1${s}bin${s}Release${s}netstandard2.0${s}publish${s}SharedDep.dll'"
        $logs[3] | Should -Be "AssemblyResolver - Resolving assembly: '$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll, Culture=neutral, PublicKeyToken=null' for '$requestedAssembly'"
        $logs[4] | Should -Be "AssemblyResolver - Processing module assembly requirement 'ParentDep2, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null'"
        $logs[5] | Should -Be "AssemblyResolver - Loading new assembly 'ParentDep2, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null' from '$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll'"

        # Both fail, Get-OldValue might reference a type and method that exists
        # in the old version but the assembly manifest still doesn't match up
        # so it still fails.
        {
            Get-OldValue
        } | Should -Throw -ExpectedMessage "*The located assembly's manifest definition does not match the assembly reference.*"

        {
            Get-NewValue
        } | Should -Throw -ExpectedMessage "*The located assembly's manifest definition does not match the assembly reference.*"

        [ParentDep2.SomeClass].Assembly.Location | Should -Be "$moduleRoot${s}AssemblyResolver${s}bin${s}ParentDep2.dll"
        [SharedDep.SomeClass].Assembly.Location | Should -Be "$moduleRoot${s}ParentDep1${s}bin${s}Release${s}netstandard2.0${s}publish${s}SharedDep.dll"
        [SharedDep.SomeClass].Assembly.GetName().Version | Should -Be '1.0.0.1'
    }
}
