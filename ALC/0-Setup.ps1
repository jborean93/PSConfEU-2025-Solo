[CmdletBinding()]
param (
    [Parameter()]
    [switch]
    $SkipInstallAndBuild
)

$moduleRoot = if (-not $PSScriptRoot) {
    Join-Path $pwd "Modules"
}
else {
    Join-Path $PSSCriptRoot "Modules"
}

if ($SkipInstallAndBuild) {
    return
}

Install-PSResource -Name dbatools, MSAL.PS -TrustRepository -Scope CurrentUser

& "$moduleRoot/ParentDep1/build.ps1"
& "$moduleRoot/ParentDep2/build.ps1"
& "$moduleRoot/NestedModuleOld/build.ps1"
& "$moduleRoot/NestedModuleNew/build.ps1"
& "$moduleRoot/ModuleNew/build.ps1"
& "$moduleRoot/ModuleOld/build.ps1"
& "$moduleRoot/ScriptAlc/build.ps1"
& "$moduleRoot/ALCResolver/build.ps1"
& "$moduleRoot/ALCLoader/build.ps1"
