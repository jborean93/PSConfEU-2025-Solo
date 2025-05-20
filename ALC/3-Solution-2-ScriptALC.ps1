. ./0-Setup.ps1 -SkipInstallAndBuild

# Shows we can import the ScriptAlc module without any conflicts with what is already present
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleOld"
    Import-Module "$using:moduleRoot/ScriptAlc" -Prefix ScriptAlc

    $noInline = Get-ScriptAlcTomlPropertyDisplayKind NoInline
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

# A hiccup with this approach is we cannot check the type outside of the module
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleOld" -Prefix ModuleOld
    Import-Module "$using:moduleRoot/ScriptAlc" -Prefix ScriptAlc

    $default = Get-ModuleOldTomlPropertyDisplayKind InlineTable
    $alc = Get-ScriptAlcTomlPropertyDisplayKind InlineTable

    [Ordered]@{
        Default = $default
        Alc = $alc
        DefaultTypeCheck = $default -is [Tomlyn.Model.TomlPropertyDisplayKind]
        AlcTypeCheck = $alc -is [Tomlyn.Model.TomlPropertyDisplayKind]
    }
} | Receive-Job -Wait -AutoRemoveJob

# You can't even reference the type in the ALC if you didn't have the non-ALC module load it
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ScriptAlc"

    [Tomlyn.Model.TomlPropertyDisplayKind]::InlineTable
} | Receive-Job -Wait -AutoRemoveJob
