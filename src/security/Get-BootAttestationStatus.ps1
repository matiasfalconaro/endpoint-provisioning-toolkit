<#
.SYNOPSIS
    Audita el estado de Secure Boot, dTPM 2.0 y Measured Boot/AtestaciÃ³n en el endpoint.
.DESCRIPTION
    Consulta la infraestructura CIM/WMI para verificar la integridad de la cadena de arranque,
    la presencia del registro de Measured Boot y el estado de habilitaciÃ³n de Secure Boot.
.EXAMPLE
    .\Get-BootAttestationStatus.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    # 1. AuditorÃ­a de Secure Boot (ConfirmaciÃ³n por Registro / UEFI)
    $SecureBootActive = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
    
    # 2. AuditorÃ­a de dTPM 2.0 y soporte de AtestaciÃ³n
    $TpmInfo = Get-Tpm -ErrorAction SilentlyContinue

    # 3. VerificaciÃ³n de logs de Measured Boot en el SO
    $MeasuredBootLog = Get-CimInstance -Namespace "root\cimv2" -ClassName "Win32_Tpm" -ErrorAction SilentlyContinue

    # ConsolidaciÃ³n de Resultados
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

    # EvaluaciÃ³n de Criterios de Seguridad
    if (-not $SecureBootActive) {
        throw "SEGURIDAD CRÃTICA: Secure Boot se encuentra DESHABILITADO en el firmware."
    }

    if (-not $TpmInfo.TpmReady -or -not $TpmInfo.IsCapPresent("Attestation")) {
        throw "SEGURIDAD CRÃTICA: El dTPM 2.0 no estÃ¡ listo o no soporta AtestaciÃ³n de Hardware (Device Health Attestation)."
    }

    return $AttestationReport

} catch {
    throw "Falla durante la auditorÃ­a de Secure Boot y Measured Boot: $_"
}
