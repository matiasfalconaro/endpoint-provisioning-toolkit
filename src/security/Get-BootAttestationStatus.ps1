<#
.SYNOPSIS
    Audita el estado de Secure Boot, dTPM 2.0 y Measured Boot/AtestaciÃ³n en el endpoint.
.DESCRIPTION
    Consulta Get-Tpm, Confirm-SecureBootUEFI y tpmtool.exe para verificar la integridad
    de la cadena de arranque, la capacidad real de atestaciÃ³n remota (Device Health
    Attestation) y la presencia de logs de Measured Boot.
.EXAMPLE
    .\Get-BootAttestationStatus.ps1
#>

[CmdletBinding()]
param()

function Invoke-TpmToolGetInfo {
    tpmtool getdeviceinformation 2>$null
}

function Get-TpmAttestationCapability {
    $TpmToolOutput = Invoke-TpmToolGetInfo
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

function Invoke-BootAttestationStatus {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    try {
        try {
            $SecureBootActive = Confirm-SecureBootUEFI
        } catch {
            Write-Warning "No se pudo verificar Secure Boot: $($_.Exception.Message)"
            $SecureBootActive = $null
        }

        $TpmInfo = Get-Tpm -ErrorAction SilentlyContinue
        $AttestationCapability = Get-TpmAttestationCapability
        $MeasuredBootLogPresent = Test-MeasuredBootLogPresent

        $AttestationReport = [PSCustomObject]@{
            SecureBootEnabled       = if ($null -ne $SecureBootActive) { $SecureBootActive } else { "No verificable / Deshabilitado" }
            TpmPresent              = $TpmInfo.TpmPresent
            TpmReady                = $TpmInfo.TpmReady
            TpmEnabled              = $TpmInfo.TpmEnabled
            TpmHasOwner             = $TpmInfo.TpmOwned
            AutoProvisioning        = $TpmInfo.AutoProvisioning
            AttestationCapable      = $AttestationCapability.IsCapableForAttestation
            AttestationReady        = $AttestationCapability.ReadyForAttestation
            MeasuredBootLogPresent  = $MeasuredBootLogPresent
        }

        if ($SecureBootActive -ne $true) {
            throw "SEGURIDAD CRÃTICA: Secure Boot se encuentra DESHABILITADO o no pudo ser verificado en el firmware."
        }

        if (-not $TpmInfo.TpmReady) {
            throw "SEGURIDAD CRÃTICA: El dTPM 2.0 no estÃ¡ listo."
        }

        if ($AttestationCapability.IsCapableForAttestation -ne $true) {
            throw "SEGURIDAD CRÃTICA: El dTPM 2.0 no soporta AtestaciÃ³n de Hardware (Device Health Attestation)."
        }

        return $AttestationReport

    } catch {
        throw "Falla durante la auditorÃ­a de Secure Boot y Measured Boot: $_"
    }
}

# Guarda de invocaciÃ³n
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-BootAttestationStatus
}
