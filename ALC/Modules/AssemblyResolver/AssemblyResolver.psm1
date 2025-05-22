using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Reflection

[CmdletBinding()]
param (
    [Parameter()]
    [IDictionary]
    $Settings = @{}
)

# Just a simple way to validate and convert the settings hashtable to variables
# without having to check the hashtable manually.
. {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $LogAssemblyLoad
    )
} @Settings

$ModuleName = [Path]::GetFileNameWithoutExtension($PSCommandPath)

Function Import-DotNetAssembly {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]
        $Name,

        [Parameter()]
        [switch]
        $LogAssemblyLoad
    )

    begin {
        # Stores log messages for assembly resolution.
        $log = [List[string]]::new()

        # Used to track assemblies that are already loaded.
        $existingAssemblies = [AppDomain]::CurrentDomain.GetAssemblies()

        # This delegate is called when attempting to resolve an assembly
        # through the Add-Type calls.
        $resolveDelegate = [ResolveEventHandler]{
            param (
                [Object]$s,
                [ResolveEventArgs]$e
            )

            $log.Add("Resolving assembly: '$($e.Name)' for '$($e.RequestingAssembly.FullName)'")
            try {
                # $e.Name is most likely the path specified to Add-Type. We try
                # and parse it before checking if the file exists.
                $name = [AssemblyName]::new($e.Name)
                if (-not (Test-Path -LiteralPath $name.Name)) {
                    return
                }

                # If the path exists we extract the assembly info from the dll.
                $assemblyPath = $name.Name
                $assemblyInfo = [AssemblyName]::GetAssemblyName($assemblyPath)

                $log.Add("Processing module assembly requirement '$($assemblyInfo.FullName)'")

                # We first check if that assembly is already loaded.
                $existingAssembly = $existingAssemblies | Where-Object { $_.GetName().Name -eq $assemblyInfo.Name }

                if ($existingAssembly) {
                    # If the assembly is loaded we can't do much but use that even if the
                    # version doesn't meet our requirements. You could add a failure here
                    # if you want to fail explicitly otherwise hope for the best.
                    $log.Add("Using existing loaded assembly '$($existingAssembly.FullName)' from '$($existingAssembly.Location)'")
                    return $existingAssembly
                }
                else {
                    # The assembly is not loaded so we load it from the path.
                    $log.Add("Loading new assembly '$($assemblyInfo.FullName)' from '$assemblyPath'")
                    return [Assembly]::LoadFrom($assemblyPath)
                }
            }
            catch {
                $log.Add("Error resolving assembly: '$($e.Name)': $_")
                return $null
            }
        }

        # Unfortunately this is a global event so we just hope an existing
        # resolver does not try and handle this event before we get to it.
        [AppDomain]::CurrentDomain.add_AssemblyResolve($resolveDelegate)
    }
    process {
        try {
            foreach ($assembly in $Name) {
                # Ensures we don't repeat the existing logs when trying a new assembly.
                $log.Clear()
                Add-Type -LiteralPath $assembly
            }
        }
        finally {
            if ($LogAssemblyLoad) {
                foreach ($entry in $log) {
                    Write-Host "$ModuleName - $entry"
                }
            }
        }
    }
    end {
        # De-registers our handler, if it was still registered but the module
        # was unloaded we could crash the process.
        [AppDomain]::CurrentDomain.remove_AssemblyResolve($resolveDelegate)
    }
}

# We should pre-load the assemblies so we can raise an error on import if
# necessary rather than when the function is called. How you enumerate the dlls
# and the locations are up to you but best to import it from the dependencies
# up to the main assemblies.
$assemblyBin = [Path]::Combine($PSScriptRoot, 'bin')
'SharedDep.dll', 'ParentDep2.dll' |
    Import-DotNetAssembly -Name { [Path]::Combine($assemblyBin, $_) } -LogAssemblyLoad:$LogAssemblyLoad

Function Get-OldValue {
    [ParentDep2.SomeClass]::GetOldValue()
}

Function Get-NewValue {
    [ParentDep2.SomeClass]::GetNewValue()
}

Export-ModuleMember -Function Get-NewValue, Get-OldValue
