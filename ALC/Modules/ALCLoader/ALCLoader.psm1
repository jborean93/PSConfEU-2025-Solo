using namespace System.IO
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Runtime.Loader

$importModule = Get-Command -Name Import-Module -Module Microsoft.PowerShell.Core
$moduleName = [Path]::GetFileNameWithoutExtension($PSCommandPath)

$modAssembly = ('ALCLoader.GetTomlPropertyDisplayKindCommand' -as [type]).Assembly
if ($IsCoreClr) {
    $isReload = $true
    if (-not ('ALCLoader.Shared.LoadContext' -as [type])) {
        $isReload = $false

        Add-Type -Path ([Path]::Combine($PSScriptRoot, 'bin', 'net8.0', "$moduleName.Shared.dll"))
    }

    $mainModule = [ALCLoader.Shared.LoadContext]::Initialize()
    $innerMod = &$importModule -Assembly $mainModule -PassThru:$isReload
}
else {
    # PowerShell 5.1 has no concept of an Assembly Load Context so it will
    # just load the module assembly directly.

    # The type can be any type within our ALCLoader project
    $innerMod = if ($modAssembly) {
        &$importModule -Assembly $modAssembly -Force -PassThru
    }
    else {
        $modPath = [Path]::Combine($PSScriptRoot, 'bin', 'net472', "$moduleName.dll")
        &$importModule -Name $modPath -ErrorAction Stop
    }
}

if ($innerMod) {
    # Bug in pwsh, Import-Module in an assembly will pick up a cached instance
    # and not call the same path to set the nested module's cmdlets to the
    # current module scope. This is only technically needed if someone is
    # calling 'Import-Module -Name ALCLoader -Force' a second time. The first
    # import is still fine.
    # https://github.com/PowerShell/PowerShell/issues/20710
    $addExportedCmdlet = [PSModuleInfo].GetMethod(
        'AddExportedCmdlet',
        [BindingFlags]'Instance, NonPublic'
    )
    foreach ($cmd in $innerMod.ExportedCmdlets.Values) {
        $addExportedCmdlet.Invoke($ExecutionContext.SessionState.Module, @(, $cmd))
    }
}
