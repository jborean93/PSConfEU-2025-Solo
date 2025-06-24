using namespace System.IO
using namespace System.Runtime.Loader

Describe "ALC Loader Module example" {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "Modules"
        $oldTomlynPath = Join-Path $moduleRoot "TomlynOld" bin Release netstandard2.0 publish Tomlyn.dll
        $s = [Path]::DirectorySeparatorChar

        Add-Type -LiteralPath $oldTomlynPath
        Import-Module -Name "$moduleRoot/ALCLoader"
    }

    It "Pwsh only sees the old Tomlyn assembly through the type syntax" {
        [Tomlyn.Model.TomlPropertyDisplayKind].Assembly.Location | Should -Be $oldTomlynPath
        [Tomlyn.Model.TomlPropertyDisplayKind].Assembly.GetName().Version | Should -Be '0.18.0.0'
    }

    It "Old Tomlyn assembly does not have NoInline" {
        [Tomlyn.Model.TomlPropertyDisplayKind]::NoInline | Should -BeNullOrEmpty
    }

    It "ALC module can access NoInline in new version loaded" {
        $noInline = Get-TomlPropertyDisplayKind NoInline
        $noInline | Should -Be NoInline
    }

    It "The type returned from ALCLoader is from the ALC" {
        $asm = (Get-TomlPropertyDisplayKind NoInline).GetType().Assembly
        $asm.Location | Should -Be "$($moduleRoot)${s}ALCLoader${s}bin${s}net8.0${s}Tomlyn.dll"
        $asm.GetName().Version | Should -Be '0.19.0.0'
    }

    It "We can check the ALC type by name but not against the [type] syntax" {
        $value = Get-TomlPropertyDisplayKind NoInline
        $value.GetType().FullName | Should -Be 'Tomlyn.Model.TomlPropertyDisplayKind'
        $value -is [Tomlyn.Model.TomlPropertyDisplayKind] | Should -BeFalse
    }

    It "The ALC from the pwsh exposed type is from the default ACL" {
        [AssemblyLoadContext]::GetLoadContext([Tomlyn.Model.TomlPropertyDisplayKind].Assembly).Name |
            Should -Be Default
    }

    It "The ALC from the ALCLoader value is from the ALC Loader ALC" {
        $val = Get-TomlPropertyDisplayKind NoInline
        [AssemblyLoadContext]::GetLoadContext($val.GetType().Assembly).Name |
            Should -Be ALCLoader
    }

    It "Can reference types in the direct cmdlet assembly located in the ALC" {
        $asm = [ALCLoader.GetTomlPropertyDisplayKindCommand].Assembly

        $asm.Location | Should -Be "$($moduleRoot)${s}ALCLoader${s}bin${s}net8.0${s}ALCLoader.dll"
        [AssemblyLoadContext]::GetLoadContext($asm).Name | Should -Be ALCLoader
    }

    It "The ALC LoadContext is still in the default ALC" {
        [AssemblyLoadContext]::GetLoadContext([ALCLoader.Shared.LoadContext].Assembly).Name |
            Should -Be Default
    }

    It "Can also access non-cmdlet types even in the ALCLoader assembly" {
        [ALCLoader.PublicTest]::TestPublicMethod() | Should -Be 'Hello from PublicTest!'

        [AssemblyLoadContext]::GetLoadContext([ALCLoader.PublicTest].Assembly).Name |
            Should -Be ALCLoader
    }

    It "Can share the input/output types in the cmdlet assembly" {
        $ct = Get-ComplexType
        $ct | Should -BeOfType [ALCLoader.ComplexType]
        $ct.PropertyDisplayKind | Should -Be Default

        $ct | Set-ComplexType -Value InlineTable
        $ct | Should -BeOfType [ALCLoader.ComplexType]
        $ct.PropertyDisplayKind | Should -Be InlineTable
    }
}
