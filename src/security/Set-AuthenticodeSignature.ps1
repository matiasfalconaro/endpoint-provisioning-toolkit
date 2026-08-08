<#
.SYNOPSIS
    Firma digitalmente scripts de PowerShell con un certificado Authenticode o valida su integridad.
.DESCRIPTION
    Aplica una firma Authenticode utilizando un certificado de la PKI corporativa o verifica
    que el script estÃ© firmado por un editor de confianza antes de la ejecuciÃ³n de la Task Sequence.
.PARAMETER ScriptPath
    Ruta del archivo o directorio de scripts PowerShell a firmar o validar.
.PARAMETER CertificateThumbprint
    Huella digital (Thumbprint) del certificado Code Signing instalado en el almacÃ©n My (Personal).
.PARAMETER ValidateOnly
    Si se especifica, solo audita la validez de la firma sin aplicar una nueva.
.EXAMPLE
    .\Set-AuthenticodeSignature.ps1 -ScriptPath "C:\Deployment\src\bios\Set-LenovoBiosBaseline.ps1" -CertificateThumbprint "A1B2C3D4..."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Ruta al archivo .ps1 o directorio a procesar")]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [string]$CertificateThumbprint,

    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

try {
    # 1. Modo ValidaciÃ³n de Firma (Pre-Execution Check)
    if ($ValidateOnly) {
        Write-Output "Verificando firma Authenticode en: $ScriptPath..."
        $Signature = Get-AuthenticodeSignature -FilePath $ScriptPath -ErrorAction Stop

        if ($Signature.Status -ne 'Valid') {
            throw "FALLA DE SEGURIDAD: El script '$ScriptPath' no cuenta con una firma Authenticode vÃ¡lida. Estado: $($Signature.Status) - StatusMessage: $($Signature.StatusMessage)"
        }

        Write-Output "Firma Authenticode VÃLIDA. Firmado por: $($Signature.SignerCertificate.Subject)"
        return $true
    }

    # 2. Modo Firma de Scripts
    if (-not $CertificateThumbprint) {
        throw "Debe proporcionar el parÃ¡metro -CertificateThumbprint para firmar digitalmente los scripts."
    }

    $Cert = Get-Item -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
    if ($null -eq $Cert) {
        $Cert = Get-Item -Path "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction Stop
    }

    Write-Output "Aplicando firma Authenticode con el certificado: $($Cert.Subject)..."
    
    if (Test-Path -Path $ScriptPath -PathType Leaf) {
        $Status = Set-AuthenticodeSignature -FilePath $ScriptPath -Certificate $Cert -TimestampServer "http://timestamp.digicert.com"
        if ($Status.Status -ne 'Valid') {
            throw "Error al firmar el archivo '$ScriptPath': $($Status.StatusMessage)"
        }
        Write-Output "Script firmando exitosamente: $ScriptPath"
    }
    elseif (Test-Path -Path $ScriptPath -PathType Container) {
        $Scripts = Get-ChildItem -Path $ScriptPath -Filter "*.ps1" -Recurse
        foreach ($Script in $Scripts) {
            $Status = Set-AuthenticodeSignature -FilePath $Script.FullName -Certificate $Cert -TimestampServer "http://timestamp.digicert.com"
            Write-Output "Firmado: $($Script.Name) -> $($Status.Status)"
        }
    }

} catch {
    throw "ERROR CRÃTICO EN AUTHERNTICODE SIGNING: $_"
}
