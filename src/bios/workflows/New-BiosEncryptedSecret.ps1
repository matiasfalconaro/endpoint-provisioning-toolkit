<#
.SYNOPSIS
    Genera un secreto cifrado vía DPAPI para la contraseña de BIOS.
.DESCRIPTION
    Convierte una entrada SecureString en un archivo cifrado con DPAPI para ejecuciones desatendidas.
.PARAMETER BiosPassword
    Contraseña de BIOS representada como SecureString.
.PARAMETER OutputPath
    Ruta donde se guardará el archivo de secreto cifrado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Ingrese la contraseña de BIOS")]
    [System.Security.SecureString]$BiosPassword,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "C:\IT_Deployment\BiosPassword.key"
)

try {
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($BiosPassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Cifrado vía DPAPI (Data Protection API)
    $EncryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        [System.Text.Encoding]::UTF8.GetBytes($PlainPassword),
        $null,
        [System.Security.Cryptography.DataProtectionScope]::LocalMachine
    )

    [System.IO.File]::WriteAllBytes($OutputPath, $EncryptedBytes)
    Write-Host "Secreto DPAPI generado exitosamente en: $OutputPath" -ForegroundColor Green
}
catch {
    Write-Error "Error al generar el secreto cifrado: $_"
}
finally {
    if ($BSTR -ne [System.IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    $PlainPassword = $null
    [System.GC]::Collect()
}
