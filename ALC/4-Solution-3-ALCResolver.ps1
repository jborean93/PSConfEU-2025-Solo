. ./0-Setup.ps1 -SkipInstallAndBuild

# Shows we can import the ScriptAlc module without any conflicts with what is already present
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleOld"
    Import-Module "$using:moduleRoot/ALCResolver" -Prefix AlcResolver

    $noInline = Get-AlcResolverTomlPropertyDisplayKind NoInline
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

# Like ScriptAlc we still cannot check the type outside of the ALC.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleOld" -Prefix ModuleOld
    Import-Module "$using:moduleRoot/ALCResolver" -Prefix AlcResolver

    $default = Get-ModuleOldTomlPropertyDisplayKind InlineTable
    $alc = Get-AlcResolverTomlPropertyDisplayKind InlineTable

    [Ordered]@{
        Default = $default
        Alc = $alc
        DefaultTypeCheck = $default -is [Tomlyn.Model.TomlPropertyDisplayKind]
        AlcTypeCheck = $alc -is [Tomlyn.Model.TomlPropertyDisplayKind]
    }
} | Receive-Job -Wait -AutoRemoveJob

# The cmdlet types and other types loaded in the main DLL are accessible
# but anything in ALCResolver.Private is not as it's contained within the ALC.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ALCResolver"

    try {
        $res = [ALCResolver.Private.PublicTest]::TestPublicMethod()
    }
    catch {
        $res = [string]$_
    }

    [Ordered]@{
        CmdletType = [ALCResolver.GetTomlPropertyDisplayKindCommand]
        UtilType = $res
    }
} | Receive-Job -Wait -AutoRemoveJob

# If we really wanted to we could use reflection to access the types loaded in the
# ALC
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ALCResolver"

    # Ensures the private type is loaded
    $null = Get-TomlPropertyDisplayKind InlineTable

    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'ALCResolver.Private' }
    $asm.GetType('ALCResolver.Private.PublicTest')::TestPublicMethod()
} | Receive-Job -Wait -AutoRemoveJob
