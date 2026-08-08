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
    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$BiosPassword,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "C:\IT_Deployment\BiosPassword.key"
)

function Invoke-DpapiProtect {
    param(
        [byte[]]$Data
    )
    Add-Type -AssemblyName System.Security
    [System.Security.Cryptography.ProtectedData]::Protect(
        $Data, 
        $null, 
        [System.Security.Cryptography.DataProtectionScope]::LocalMachine
    )
}

function Invoke-FileWriteAllBytes {
    param(
        [string]$Path, 
        [byte[]]$Bytes
    )
    [System.IO.File]::WriteAllBytes($Path, $Bytes)
}

function Invoke-BiosSecretGeneration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$BiosPassword,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    try {
        $Directory = Split-Path -Parent $OutputPath
        if (-not (Test-Path -Path $Directory)) {
            New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        }

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($BiosPassword)
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        $EncryptedBytes = Invoke-DpapiProtect -Data ([System.Text.Encoding]::UTF8.GetBytes($PlainPassword))
        Invoke-FileWriteAllBytes -Path $OutputPath -Bytes $EncryptedBytes
    }
    catch {
        throw "Error al generar el secreto cifrado: $_"
    }
    finally {
        if ($BSTR) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $BiosPassword) {
    Invoke-BiosSecretGeneration -BiosPassword $BiosPassword -OutputPath $OutputPath
}
