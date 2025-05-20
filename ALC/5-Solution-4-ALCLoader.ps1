. ./0-Setup.ps1 -SkipInstallAndBuild

# Shows we can import the ScriptAlc module without any conflicts with what is already present
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleOld"
    Import-Module "$using:moduleRoot/ALCLoader" -Prefix AlcLoader

    $noInline = Get-AlcLoaderTomlPropertyDisplayKind NoInline
    $actualAsm = $noInline.GetType().Assembly
    $loadedAsm = [Tomlyn.Model.TomlPropertyDisplayKind].Assembly
    [Ordered]@{
        NoInline = $noInline
        ActualAsm = $actualAsm.GetName().FullName
        ActualAsmLocation = $actualAsm.Location
        ActualAsmALC = [Runtime.Loader.AssemblyLoadContext]::GetLoadContext($actualAsm).Name

        LoadedAsm = $loadedAsm.GetName().FullName
        LoadedAsmLocation = $loadedAsm.Location
        LoadedAsmALC = [Runtime.Loader.AssemblyLoadContext]::GetLoadContext($loadedAsm).Name
    }
} | Receive-Job -Wait -AutoRemoveJob

# Unlike ScriptAlc or ALCResolver, we can still access the types of the cmdlet assembly
# in pwsh. We cannot access the subsequent dependencies like Tomlyn used by the cmdlet.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleOld" -Prefix ModuleOld
    Import-Module "$using:moduleRoot/ALCLoader" -Prefix AlcLoader

    $default = Get-ModuleOldTomlPropertyDisplayKind InlineTable
    $alc = Get-AlcLoaderTomlPropertyDisplayKind InlineTable

    [Ordered]@{
        Default = $default
        Alc = $alc
        CmdletType = [ALCLoader.GetTomlPropertyDisplayKindCommand]
        DefaultTypeCheck = $default -is [Tomlyn.Model.TomlPropertyDisplayKind]
        AlcTypeCheck = $alc -is [Tomlyn.Model.TomlPropertyDisplayKind]
    }
} | Receive-Job -Wait -AutoRemoveJob

# Unlike ALCResolver, the cmdlet is loaded in the ALC but pwsh knows how to
# resolve the type. Any dependencies loaded in the ALC are still not available.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ALCLoader"

    [Ordered]@{
        CmdletType = [ALCLoader.GetTomlPropertyDisplayKindCommand]
        CmdletTypeAlc = [Runtime.Loader.AssemblyLoadContext]::GetLoadContext([ALCLoader.GetTomlPropertyDisplayKindCommand].Assembly).Name
        SharedType = [ALCLoader.Shared.LoadContext]
        SharedTypeAlc = [Runtime.Loader.AssemblyLoadContext]::GetLoadContext([ALCLoader.Shared.LoadContext].Assembly).Name
    }
} | Receive-Job -Wait -AutoRemoveJob

# We don't need reflection to access the type in the cmdlet assembly but do need
# it for any dependencies it has loaded, e.g. Tomlyn.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ALCLoader"

    # Ensures the type is loaded in the ALC.
    $null = Get-TomlPropertyDisplayKind NoInline

    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'Tomlyn' }
    $tomlPropertyDisplayKind = $asm.GetType('Tomlyn.Model.TomlPropertyDisplayKind')

    [Ordered]@{
        PublicTest = [ALCLoader.PublicTest]::TestPublicMethod()
        TomlynType = $tomlPropertyDisplayKind::InlineTable
    }
} | Receive-Job -Wait -AutoRemoveJob

# Our inputs/parameter types can be contained in the cmdlet assembly loaded in the ALC.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ALCLoader"

    $ct = Get-ComplexType
    $ct | Set-ComplexType -Value InlineTable
    $ct
} | Receive-Job -Wait -AutoRemoveJob
