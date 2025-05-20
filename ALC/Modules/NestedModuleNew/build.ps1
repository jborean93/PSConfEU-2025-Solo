if (-not (Test-Path "$PSScriptRoot/bin")) {
    New-Item -Path "$PSScriptRoot/bin" -ItemType Directory | Out-Null
}
Copy-Item "$PSScriptRoot/../ParentDep2/bin/Release/netstandard2.0/publish/*.dll" -Destination "$PSScriptRoot/bin" -Force
