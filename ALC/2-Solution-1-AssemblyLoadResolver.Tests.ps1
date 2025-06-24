using namespace System.IO

Describe "Assembly Load Resolver" {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "Modules"
    }

    It "Loads a module normally with no conflicts" {
        Import-Module "$moduleRoot/AssemblyResolver"

        Get-OldValue | Should -Be 'Hello Old World!'
        Get-NewValue | Should -Be 'Hello New World!'

        $expectedParent = [Path]::Combine(
            $moduleRoot,
            "AssemblyResolver",
            "bin",
            "ParentDep2.dll")
        [ParentDep2.SomeClass].Assembly.Location | Should -Be $expectedParent

        $expectedShared = [Path]::Combine(
            $moduleRoot,
            "AssemblyResolver",
            "bin",
            "SharedDep.dll")
        [SharedDep.SomeClass].Assembly.Location | Should -Be $expectedShared

        [SharedDep.SomeClass].Assembly.GetName().Version | Should -Be '2.0.0.1'
    }

    It "Assembly already loaded but lucky the right one is loaded" {
        Add-Type -Path "$moduleRoot/AssemblyResolver/bin/SharedDep.dll"

        Import-Module "$moduleRoot/AssemblyResolver"

        Get-OldValue | Should -Be 'Hello Old World!'
        Get-NewValue | Should -Be 'Hello New World!'

        $expectedParent = [Path]::Combine(
            $moduleRoot,
            "AssemblyResolver",
            "bin",
            "ParentDep2.dll")
        [ParentDep2.SomeClass].Assembly.Location | Should -Be $expectedParent

        $expectedShared = [Path]::Combine(
            $moduleRoot,
            "AssemblyResolver",
            "bin",
            "SharedDep.dll")
        [SharedDep.SomeClass].Assembly.Location | Should -Be $expectedShared

        [SharedDep.SomeClass].Assembly.GetName().Version | Should -Be '2.0.0.1'
    }

    It "Assembly already loaded but unlucky the wrong one is loaded" {
        Add-Type -Path "$moduleRoot/ParentDep1/bin/Release/netstandard2.0/publish/SharedDep.dll"

        Import-Module "$moduleRoot/AssemblyResolver/AssemblyResolver"
        # Both fail, Get-OldValue might reference a type and method that exists
        # in the old version but the assembly manifest still doesn't match up
        # so it still fails.
        $expectedError = "*The located assembly's manifest definition does not match the assembly reference.*"
        {
            Get-OldValue
        } | Should -Throw -ExpectedMessage $expectedError

        {
            Get-NewValue
        } | Should -Throw -ExpectedMessage $expectedError

        $expectedParent = [Path]::Combine(
            $moduleRoot,
            "AssemblyResolver",
            "bin",
            "ParentDep2.dll")
        [ParentDep2.SomeClass].Assembly.Location | Should -Be $expectedParent

        $expectedShared = [Path]::Combine(
            $moduleRoot,
            "ParentDep1",
            "bin",
            "Release",
            "netstandard2.0",
            "publish",
            "SharedDep.dll")
        [SharedDep.SomeClass].Assembly.Location | Should -Be $expectedShared

        [SharedDep.SomeClass].Assembly.GetName().Version | Should -Be '1.0.0.1'
    }
}
