using namespace System.Collections
using namespace System.IO
using namespace System.Reflection
using namespace System.Runtime.Loader

$ModuleName = [Path]::GetFileNameWithoutExtension($PSCommandPath)

if ($IsCoreCLR) {
    $assemblyPath = [Path]::Combine($PSScriptRoot, 'bin', 'net8.0', "Tomlyn.dll")
    $alc = [AssemblyLoadContext]::new($ModuleName, $false)
    $tomlynAsm = $alc.LoadFromAssemblyPath($assemblyPath)
}
else {
    # .NET Framework has no concept of an ALC to load directly
    $assemblyPath = [Path]::Combine($PSScriptRoot, 'bin', 'net472', "Tomlyn.dll")
    Add-Type -Path $assemblyPath
    $tomlynAsm = [Tomlyn.Model.TomlPropertyDisplayKind].Assembly
}

# We store the types in our assembly in a hashtable to make it easier to
# retrieve after. This example just stores it under the full type name but you
# can add whatever logic to shorten or alias the name. Any types that were not
# found will be raised as an error later on.
$Script:ALCTypes = @{}
$unknownTypes = foreach ($typeName in @(
        'Tomlyn.Model.TomlPropertyDisplayKind'
    )) {

    # GetType returns $null if the Assembly.GetType(string name) can't find
    # the assembly. We output that into $unknownTypes for erroring later.
    # Otherwise we add it to our hashtable for referencing later in our module.
    $foundType = $tomlynAsm.GetType($typeName)
    if ($foundType) {
        $ALCTypes[$typeName] = $foundType
    }
    else {
        $typeName
    }
}
if ($unknownTypes) {
    $msg = "Failed to find the following types in Tomlyn: '$($unknownTypes -join "', '")'"
    Write-Error -Message $msg -ErrorAction Stop
}

Function Get-TomlPropertyDisplayKind {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Value
    )

    # We cannot refer to the type normally in PowerShell as pwsh will
    # only look in the default LoadContext. So this will not work:
    # [Tomlyn.Model.TomlPropertyDisplayKind]::$Value
    # $Value -as [Tomlyn.Model.TomlPropertyDisplayKind]

    # We instead use ALCTypes to get the Type object and cast
    # from there like normal.
    $Value -as $ALCTypes['Tomlyn.Model.TomlPropertyDisplayKind']

    # Another alternative
    # $ALCTypes['Tomlyn.Model.TomlPropertyDisplayKind']::$Value
}

Export-ModuleMember -Function Get-TomlPropertyDisplayKind
