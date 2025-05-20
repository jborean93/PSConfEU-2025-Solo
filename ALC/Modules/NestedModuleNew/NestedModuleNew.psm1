using namespace System.Collections
using namespace System.IO
using namespace System.Reflection

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [IDictionary]
    $Settings = @{}
)

. {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $AddAssemblyFallback,

        [Parameter()]
        [switch]
        $PreloadDependency
    )
} @Settings

$ModuleName = [Path]::GetFileNameWithoutExtension($PSCommandPath)

Add-Type -Path ([Path]::Combine($PSScriptRoot, 'bin', 'ParentDep2.dll'))

if ($AddAssemblyFallback) {
    $existingSharedDep = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'SharedDep' } |
        Select-Object -First 1

    $resolveDelegate = [ResolveEventHandler]{
        param (
            [Object]$s,
            [ResolveEventArgs]$e
        )

        Write-Host "$ModuleName - Resolving assembly: '$($e.Name)'"

        if ($e.Name -like '*SharedDep.dll,*') {
            if ($existingSharedDep) {
                Write-Host "$ModuleName - Using existing assembly: '$($existingSharedDep.Location)'"
                $existingSharedDep
            }
            else {
                Write-Host "$ModuleName - Loading assembly: '$($e.Name)'"
                [Assembly]::LoadFrom([Path]::Combine($PSScriptRoot, 'bin', 'SharedDep.dll'))
            }
        }
    }
    [AppDomain]::CurrentDomain.add_AssemblyResolve($resolveDelegate)
}

if ($PreloadDependency) {
    Add-Type -Path ([Path]::Combine($PSScriptRoot, 'bin', 'SharedDep.dll'))
}

if ($resolveDelegate) {
    [AppDomain]::CurrentDomain.remove_AssemblyResolve($resolveDelegate)
}

Function Get-NestedValue {
    [ParentDep2.SomeClass]::GetValue()
}

Export-ModuleMember -Function Get-NestedValue
