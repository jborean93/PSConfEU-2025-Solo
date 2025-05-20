. ./0-Setup.ps1 -SkipInstallAndBuild

# Importing normally just works as expected
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleNew"

    @{
        NoInline = Get-TomlPropertyDisplayKind NoInline
        InlineTable = Get-TomlPropertyDisplayKind InlineTable
    }
} | Receive-Job -Wait -AutoRemoveJob

# Both of these fail to import the second module as expected due to the assembly conflict
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleOld"
    Import-Module "$using:moduleRoot/ModuleNew"
} | Receive-Job -Wait -AutoRemoveJob

Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleNew"
    Import-Module "$using:moduleRoot/ModuleOld"
} | Receive-Job -Wait -AutoRemoveJob

# This works by loading the second module with a custom resolver.
# The NoInline property also works as expected as the newer assembly is loaded first.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleNew" -ArgumentList @{
        AddAssemblyFallback = $true
    } -Prefix ModuleNew
    Import-Module "$using:moduleRoot/ModuleOld" -ArgumentList @{
        AddAssemblyFallback = $true
    } -Prefix ModuleOld

    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'Tomlyn' } |
        Select-Object -ExpandProperty Location

    @{
        TomlynLocation = $asm
        ModuleNew = Get-ModuleNewTomlPropertyDisplayKind NoInline
        ModuleOld = Get-ModuleOldTomlPropertyDisplayKind InlineTable
    }
} | Receive-Job -Wait -AutoRemoveJob

# The dangers of this approach is that we could rely on features not present in the older
# version. For example NoLine was added in Tomlyn 0.19.0 so this imports but will fail
# at runtime.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/ModuleOld" -ArgumentList @{
        AddAssemblyFallback = $true
    } -Prefix ModuleOld
    Import-Module "$using:moduleRoot/ModuleNew" -ArgumentList @{
        AddAssemblyFallback = $true
    } -Prefix ModuleNew

    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'Tomlyn' } |
        Select-Object -ExpandProperty Location

    @{
        TomlynLocation = $asm
        ModuleNew = Get-ModuleNewTomlPropertyDisplayKind NoInline -ErrorAction Continue
        ModuleOld = Get-ModuleOldTomlPropertyDisplayKind InlineTable
    }
} | Receive-Job -Wait -AutoRemoveJob

# Loading an assembly with a dependency that has a conflict is even more difficult
# to debug. Deps are loaded when they are used which is typically when it is called
# at runtime rather than when the parent is loaded. In this example we can see that
# even though NestedModuleOld was loaded first, as NestedModuleNew was called first
# the 2.0.0.0 SharedDep will be loaded first.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/NestedModuleOld" -Prefix Old
    Import-Module "$using:moduleRoot/NestedModuleNew" -Prefix New

    $newVal = Get-NewNestedValue
    $oldVal = Get-OldNestedValue
    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'SharedDep' } |
        Select-Object -ExpandProperty Location

    [Ordered]@{
        SharedDepLocation = $asm
        New = $newVal
        Old = $oldVal
    }
} | Receive-Job -Wait -AutoRemoveJob

# If we were to call the old module function first, the old SharedDep assembly will
# be loaded. The order of the module import does not matter as the assembly is loaded
# when the function actually runs.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/NestedModuleNew" -Prefix New
    Import-Module "$using:moduleRoot/NestedModuleOld" -Prefix Old

    $oldVal = Get-OldNestedValue
    $newVal = Get-NewNestedValue
    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'SharedDep' } |
        Select-Object -ExpandProperty Location

    [Ordered]@{
        SharedDepLocation = $asm
        New = $newVal
        Old = $oldVal
    }
} | Receive-Job -Wait -AutoRemoveJob

# Modules could pre-load the dependency
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/NestedModuleNew" -ArgumentList @{
        PreloadDependency = $true
    } -Prefix New
    Import-Module "$using:moduleRoot/NestedModuleOld" -Prefix Old

    $oldVal = Get-OldNestedValue
    $newVal = Get-NewNestedValue
    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'SharedDep' } |
        Select-Object -ExpandProperty Location

    [Ordered]@{
        SharedDepLocation = $asm
        New = $newVal
        Old = $oldVal
    }
} | Receive-Job -Wait -AutoRemoveJob

# But they need to be careful to avoid conflicts, this now fails as the old
# module will attempt to pre-load a dependency conflict.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/NestedModuleNew" -ArgumentList @{
        PreloadDependency = $true
    } -Prefix New
    Import-Module "$using:moduleRoot/NestedModuleOld" -ArgumentList @{
        PreloadDependency = $true
    } -Prefix Old

    $oldVal = Get-OldNestedValue
    $newVal = Get-NewNestedValue
    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'SharedDep' } |
        Select-Object -ExpandProperty Location

    [Ordered]@{
        SharedDepLocation = $asm
        New = $newVal
        Old = $oldVal
    }
} | Receive-Job -Wait -AutoRemoveJob

# The order still matters as we can only have 1 version loaded
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/NestedModuleNew" -ArgumentList @{
        PreloadDependency = $true
    } -Prefix New
    Import-Module "$using:moduleRoot/NestedModuleOld" -ArgumentList @{
        PreloadDependency = $true
    } -Prefix Old

    $oldVal = Get-OldNestedValue
    $newVal = Get-NewNestedValue
    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'SharedDep' } |
        Select-Object -ExpandProperty Location

    [Ordered]@{
        SharedDepLocation = $asm
        New = $newVal
        Old = $oldVal
    }
} | Receive-Job -Wait -AutoRemoveJob

# The best thing to do is to pre-load your assembly and all dependencies on
# the import. This requires an assembly resolver to handle the case when the
# assembly is already loaded or at least do a pre-check to see if it is already
# loaded before doing the import. This does not solve the problem when an older
# version is loaded and you need the new one. Only thing to do here is restart
# the process.
Start-Job -ScriptBlock {
    Import-Module "$using:moduleRoot/NestedModuleNew" -ArgumentList @{
        AddAssemblyFallback = $true
        PreloadDependency = $true
    } -Prefix New
    Import-Module "$using:moduleRoot/NestedModuleOld" -ArgumentList @{
        AddAssemblyFallback = $true
        PreloadDependency = $true
    } -Prefix Old

    $oldVal = Get-OldNestedValue
    $newVal = Get-NewNestedValue
    $asm = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'SharedDep' } |
        Select-Object -ExpandProperty Location

    [Ordered]@{
        SharedDepLocation = $asm
        New = $newVal
        Old = $oldVal
    }
} | Receive-Job -Wait -AutoRemoveJob
