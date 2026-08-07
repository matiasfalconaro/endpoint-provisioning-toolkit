<#
.SYNOPSIS
    Genera un secreto cifrado vía DPAPI para la contraseña de BIOS.
.DESCRIPTION
    Convierte una entrada SecureString en un archivo cifrado con DPAPI para
    ejecuciones desatendidas. Requiere ensamblado System.Security (incluido
    en .NET Framework / Windows PowerShell 5.1 pero no cargado por defecto).
.PARAMETER BiosPassword
    Contraseña de BIOS representada como SecureString.
.PARAMETER OutputPath
    Ruta donde se guardará el archivo de secreto cifrado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [System.Security.SecureString]$BiosPassword,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "C:\IT_Deployment\BiosPassword.key"
)

function Invoke-BiosSecretGeneration {
    [CmdletBinding()]
    param(
        [System.Security.SecureString]$BiosPassword,
        [string]$OutputPath
    )

    $ErrorActionPreference = 'Stop'

    # Requerido en PowerShell 5.1 (WinPE): ProtectedData no esta cargado por defecto.
    # En PowerShell 7 esta disponible sin esta linea, pero Add-Type es idempotente.
    Add-Type -AssemblyName System.Security

    $BSTR = [System.IntPtr]::Zero
    $PlainPassword = $null

    try {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($BiosPassword)
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        $EncryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
            [System.Text.Encoding]::UTF8.GetBytes($PlainPassword),
            $null,
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )

        $OutputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $OutputDir)) {
            New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
        }

        [System.IO.File]::WriteAllBytes($OutputPath, $EncryptedBytes)
        Write-Host "Secreto DPAPI generado exitosamente en: $OutputPath" -ForegroundColor Green

    } catch {
        # Re-throw sin catch silencioso: el error debe propagarse al wrapper
        # para que la Task Sequence lo registre y active el rollback.
        throw "Error al generar el secreto cifrado: $_"
    } finally {
        if ($BSTR -ne [System.IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
        $PlainPassword = $null
        [System.GC]::Collect()
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $BiosPassword) {
    Invoke-BiosSecretGeneration -BiosPassword $BiosPassword -OutputPath $OutputPath
}
