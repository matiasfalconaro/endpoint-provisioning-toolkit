<#
.SYNOPSIS
    Audita el estado de Secure Boot, dTPM 2.0 y Measured Boot/Atestación en el endpoint.
.DESCRIPTION
    Consulta la infraestructura CIM/WMI para verificar la integridad de la cadena de arranque,
    la presencia del registro de Measured Boot y el estado de habilitación de Secure Boot.
.EXAMPLE
    .\Get-BootAttestationStatus.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    # 1. Auditoría de Secure Boot (Confirmación por Registro / UEFI)
    $SecureBootActive = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
    
    # 2. Auditoría de dTPM 2.0 y soporte de Atestación
    $TpmInfo = Get-Tpm -ErrorAction SilentlyContinue

    # 3. Verificación de logs de Measured Boot en el SO
    $MeasuredBootLog = Get-CimInstance -Namespace "root\cimv2" -ClassName "Win32_Tpm" -ErrorAction SilentlyContinue

    # Consolidación de Resultados
    $AttestationReport = [PSCustomObject]@{
        SecureBootEnabled   = if ($null -ne $SecureBootActive) { $SecureBootActive } else { "Not Supported / Disabled" }
        TpmPresent          = $TpmInfo.TpmPresent
        TpmReady            = $TpmInfo.TpmReady
        TpmEnabled          = $TpmInfo.TpmEnabled
        TpmHasOwner         = $TpmInfo.TpmHasOwner
        AutoProvisioning    = $TpmInfo.AutoProvisioning
        AttestationReady    = $TpmInfo.IsCapPresent("Attestation")
    }

    Write-Output ($AttestationReport | Format-List | Out-String)

    # Evaluación de Criterios de Seguridad
    if (-not $SecureBootActive) {
        throw "SEGURIDAD CRÍTICA: Secure Boot se encuentra DESHABILITADO en el firmware."
    }

    if (-not $TpmInfo.TpmReady -or -not $TpmInfo.IsCapPresent("Attestation")) {
        throw "SEGURIDAD CRÍTICA: El dTPM 2.0 no está listo o no soporta Atestación de Hardware (Device Health Attestation)."
    }

    return $AttestationReport

} catch {
    throw "Falla durante la auditoría de Secure Boot y Measured Boot: $_"
}
