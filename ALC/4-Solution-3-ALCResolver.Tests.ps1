using namespace System.IO
using namespace System.Runtime.Loader

Describe "ALC Resolver Module example" {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "Modules"
        $oldTomlynPath = Join-Path $moduleRoot "TomlynOld" bin Release netstandard2.0 publish Tomlyn.dll
        $s = [Path]::DirectorySeparatorChar

        Add-Type -LiteralPath $oldTomlynPath
        Import-Module -Name "$moduleRoot/ALCResolver"
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

    It "The type returned from ALCResolver is from the ALC" {
        $asm = (Get-TomlPropertyDisplayKind NoInline).GetType().Assembly
        $asm.Location | Should -Be "$($moduleRoot)${s}ALCResolver${s}bin${s}net8.0${s}Tomlyn.dll"
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

    It "The ALC from the ALCResolver value is from the ALC Resolver ALC" {
        $val = Get-TomlPropertyDisplayKind NoInline
        [AssemblyLoadContext]::GetLoadContext($val.GetType().Assembly).Name |
            Should -Be ALCResolver
    }

    It "Cannot access types in the ALCResolver.Private assembly" {
        {
            [ALCResolver.Private.PublicTest]::TestPublicMethod()
        } | Should -Throw -ExpectedMessage 'Unable to find type `[ALCResolver.Private.PublicTest].'
    }

    It "We can use reflection to access types in ALCResolver.Private assembly if needed" {
        # Makes sure the type is loaded.
        $null = Get-TomlPropertyDisplayKind NoInline

        $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GetName().Name -eq 'ALCResolver.Private' }
        $asm.GetType('ALCResolver.Private.PublicTest')::TestPublicMethod() | Should -Be 'Hello from PublicTest!'
        [AssemblyLoadContext]::GetLoadContext($asm).Name | Should -Be ALCResolver
    }
}
