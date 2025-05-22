$moduleRoot = Join-Path $PSSCriptRoot "Modules"

Install-PSResource -RequiredResource  @{
    'dbatools' = @{
        version = '2.1.31'
    }
    'dbatools.library' = @{
        version = '2024.4.12'
    }
    'MSAL.PS' = @{
        version = '4.37.0.0'
    }
} -TrustRepository

& "$moduleRoot/ParentDep1/build.ps1"
& "$moduleRoot/ParentDep2/build.ps1"
& "$moduleRoot/AssemblyResolver/build.ps1"
& "$moduleRoot/TomlynOld/build.ps1"
& "$moduleRoot/ScriptAlc/build.ps1"
& "$moduleRoot/ALCResolver/build.ps1"
& "$moduleRoot/ALCLoader/build.ps1"
