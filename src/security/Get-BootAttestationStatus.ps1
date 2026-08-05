<#
.SYNOPSIS
    Audita el estado de Secure Boot, dTPM 2.0 y Measured Boot/Atestación en el endpoint.
.DESCRIPTION
    Consulta Get-Tpm, Confirm-SecureBootUEFI y tpmtool.exe para verificar la integridad
    de la cadena de arranque, la capacidad real de atestación remota (Device Health
    Attestation) y la presencia de logs de Measured Boot.
.EXAMPLE
    .\Get-BootAttestationStatus.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-TpmAttestationCapability {
    $TpmToolOutput = tpmtool getdeviceinformation 2>$null
    if (-not $TpmToolOutput) {
        return $null
    }

    $IsCapable = $TpmToolOutput | Select-String "Is Capable For Attestation\s*:\s*(.+)"
    $IsReady   = $TpmToolOutput | Select-String "Ready For Attestation\s*:\s*(.+)"

    return [PSCustomObject]@{
        IsCapableForAttestation = if ($IsCapable) { $IsCapable.Matches[0].Groups[1].Value.Trim() -eq 'True' } else { $null }
        ReadyForAttestation     = if ($IsReady)   { $IsReady.Matches[0].Groups[1].Value.Trim() -eq 'True' } else { $null }
    }
}

function Test-MeasuredBootLogPresent {
    $LogPath = "$env:SystemRoot\Logs\MeasuredBoot"
    if (-not (Test-Path $LogPath)) {
        return $false
    }
    $Logs = Get-ChildItem -Path $LogPath -Filter "*.json" -ErrorAction SilentlyContinue
    return ($Logs.Count -gt 0)
}

try {
    # Auditoría de Secure Boot
    try {
        $SecureBootActive = Confirm-SecureBootUEFI
    } catch {
        Write-Warning "No se pudo verificar Secure Boot (posible Legacy BIOS o privilegios insuficientes): $($_.Exception.Message)"
        $SecureBootActive = $null
    }

    # Auditoría de dTPM 2.0
    $TpmInfo = Get-Tpm -ErrorAction SilentlyContinue

    # Capacidad real de atestación (reemplaza el método inexistente IsCapPresent)
    $AttestationCapability = Get-TpmAttestationCapability

    # Verificación real de logs de Measured Boot
    $MeasuredBootLogPresent = Test-MeasuredBootLogPresent

    # Consolidación de Resultados
    $AttestationReport = [PSCustomObject]@{
        SecureBootEnabled       = if ($null -ne $SecureBootActive) { $SecureBootActive } else { "No verificable / Deshabilitado" }
        TpmPresent              = $TpmInfo.TpmPresent
        TpmReady                = $TpmInfo.TpmReady
        TpmEnabled               = $TpmInfo.TpmEnabled
        TpmHasOwner              = $TpmInfo.TpmOwned
        AutoProvisioning         = $TpmInfo.AutoProvisioning
        AttestationCapable       = $AttestationCapability.IsCapableForAttestation
        AttestationReady         = $AttestationCapability.ReadyForAttestation
        MeasuredBootLogPresent   = $MeasuredBootLogPresent
    }

    Write-Output ($AttestationReport | Format-List | Out-String)

    # Evaluación de Criterios de Seguridad
    if ($SecureBootActive -ne $true) {
        throw "SEGURIDAD CRÍTICA: Secure Boot se encuentra DESHABILITADO o no pudo ser verificado en el firmware."
    }

    if (-not $TpmInfo.TpmReady) {
        throw "SEGURIDAD CRÍTICA: El dTPM 2.0 no está listo."
    }

    if ($AttestationCapability.IsCapableForAttestation -ne $true) {
        throw "SEGURIDAD CRÍTICA: El dTPM 2.0 no soporta Atestación de Hardware (Device Health Attestation)."
    }

    $AttestationReport

} catch {
    throw "Falla durante la auditoría de Secure Boot y Measured Boot: $_"
}
