[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $Path,

    [Parameter(Mandatory)]
    [string]
    $Password
)

$pass = $Password | ConvertTo-SecureString -AsPlainText -Force
(Get-PfxCertificate -FilePath $Path -Password $pass).Subject
