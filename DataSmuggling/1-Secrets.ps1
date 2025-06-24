# Sharing through command line triggers auditing logs" {
pwsh -Command "`$password = 'DoNotShare!' | ConvertTo-SecureString -AsPlainText -Force; (Get-PfxCertificate -FilePath '$PSScriptRoot\cert.pfx' -Password `$password).Subject"

# Can also trigger scriptblock logging if certain keywords are used" {
pwsh -Command "<# Properties #>`$password = 'DoNotShare!' | ConvertTo-SecureString -AsPlainText -Force; (Get-PfxCertificate -FilePath '$PSScriptRoot\cert.pfx' -Password `$password).Subject"

# We can pass it through an env var to avoid ScriptBlock or cmdline auditing
# but module logging will pick this up and the env vars can be scanned as well
$env:MY_PASSWORD = 'DoNotShare!'
pwsh -Command "<# Properties #>Start-Sleep -Seconds 5; `$password = `$env:MY_PASSWORD | ConvertTo-SecureString -AsPlainText -Force; (Get-PfxCertificate -FilePath '$PSScriptRoot\cert.pfx' -Password `$password).Subject"
$env:MY_PASSWORD = $null

# Passing through stdin is another nice way but still detectable by module
# logging
'DoNotShare!' | pwsh -Command "<# Properties #> `$password = `$input | ConvertTo-SecureString -AsPlainText -Force; (Get-PfxCertificate -FilePath '$PSScriptRoot\cert.pfx' -Password `$password).Subject"

# Using -EncodedCommand will avoid cmdline logging from seeing
# it in plaintext but it'll still be decodable. Will still be
# seen in ScriptBlock logging or Module logging
Push-Location -LiteralPath $PSScriptRoot
pwsh {
    # Properties
    $password = 'DoNotShare!' | ConvertTo-SecureString -AsPlainText -Force
    (Get-PfxCertificate -FilePath '.\cert.pfx' -Password $password).Subject
} | Out-String
Pop-Location

# You can see what happens when using {} as a command argument
& "$PSScriptRoot\print_argv.exe" { 'foo' } | Out-String

# Using Start-Job with a provided SecureString avoids all this
$SecureStringPassword = Import-Clixml -LiteralPath "$PSScriptRoot\cert.pass"
Start-Job -ScriptBlock {
    # Properties
    $password = $using:SecureStringPassword
    (Get-PfxCertificate -FilePath "$using:PSScriptRoot\cert.pfx" -Password $password).Subject
} | Receive-Job -Wait -AutoRemoveJob
