#Requires -Version 7.4

using namespace System.IO
using namespace System.Security.Cryptography.X509Certificates

$pfxPassword = 'DoNotShare!' | ConvertTo-SecureString -AsPlainText -Force
$pfxPassword | Export-Clixml -LiteralPath "$PSScriptRoot\cert.pass"

$certParams = @{
    CertStoreLocation = 'Cert:\CurrentUser\My'
    NotAfter = (Get-Date).AddYears(1)
    Provider = 'Microsoft Software Key Storage Provider'
    Subject = 'CN=PSConfEU-2026-In-Australia'
}
$cert = New-SelfSignedCertificate @certParams
try {
    $pfxBytes = $cert.Export([X509ContentType]::Pfx, $pfxPassword)
    [File]::WriteAllBytes("$PSScriptRoot\cert.pfx", $pfxBytes)
}
finally {
    Remove-Item -LiteralPath "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force -DeleteKey
}

if (-not (Get-Module -Name ProcessEx -ListAvailable)) {
    Install-PSResource -Name Ctypes, ProcessEx, PwshSpectreConsole -TrustRepository
}

$exePath = "$PSScriptRoot\print_argv.exe"
Start-Job -PSVersion 5.1 -ScriptBlock {
    Add-Type -OutputType ConsoleApplication -OutputAssembly $using:exePath -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace PrintArgv
{
    class Program
    {
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetCommandLineW();

        static void Main(string[] args)
        {
            IntPtr cmdLinePtr = GetCommandLineW();
            string cmdLine = Marshal.PtrToStringUni(cmdLinePtr);

            Console.WriteLine(cmdLine);
            for (int i = 0; i < args.Length; i++)
            {
                Console.WriteLine("[{0}] {1}", i, args[i]);
            }
        }
    }
}
'@
} | Receive-Job -Wait -AutoRemove
