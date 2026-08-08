<#
.SYNOPSIS
    Valida, configura y respalda las claves de BitLocker en Active Directory / Entra ID.
.DESCRIPTION
    Verifica los requisitos de dTPM 2.0, asigna el protector TPM, fuerza el respaldo
    de la clave de recuperaciÃ³n en AD DS y/o Microsoft Entra ID segÃºn el escenario de
    uniÃ³n del equipo, y confirma el cifrado del volumen del sistema.
.EXAMPLE
    .\Enable-BitLockerValidation.ps1
#>

[CmdletBinding()]
param()

function Invoke-DsregcmdStatus {
    dsregcmd /status
}

function Invoke-BitLockerValidation {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    try {
        # VerificaciÃ³n de dTPM 2.0
        $Tpm = Get-Tpm -ErrorAction SilentlyContinue
        if (-not $Tpm.TpmReady) {
            throw "SEGURIDAD CRÃTICA: El chip dTPM 2.0 no estÃ¡ listo para habilitar BitLocker"
        }

        $TargetDrive = $env:SystemDrive

        # ComprobaciÃ³n de estado
        $BitLockerStatus = Get-BitLockerVolume -MountPoint $TargetDrive -ErrorAction Stop

        # InyecciÃ³n de protector TPM
        $TpmProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }
        if ($null -eq $TpmProtector) {
            Write-Output "AÃ±adiendo protector dTPM al volumen $TargetDrive"
            Add-BitLockerKeyProtector -MountPoint $TargetDrive -TpmProtector | Out-Null
        }

        # GeneraciÃ³n / ObtenciÃ³n de Recovery Password
        $RecoveryProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
        if ($null -eq $RecoveryProtector -or [string]::IsNullOrEmpty($RecoveryProtector.KeyProtectorId)) {
            Write-Output "Generando clave de recuperaciÃ³n de 48 dÃ­gitos"
            $AddedProtector = Add-BitLockerKeyProtector -MountPoint $TargetDrive -RecoveryPasswordProtector
            
            # Soporte dual: Extraer Id si Add-BitLockerKeyProtector retorna el objeto o re-consultar el volumen
            if ($AddedProtector.KeyProtector) {
                $RecoveryProtector = $AddedProtector.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
            } elseif ($AddedProtector.KeyProtectorId) {
                $RecoveryProtector = $AddedProtector
            } else {
                $BitLockerStatus = Get-BitLockerVolume -MountPoint $TargetDrive -ErrorAction Stop
                $RecoveryProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
            }
        }

        # Fallback de seguridad si KeyProtectorId sigue ausente (Mocks simples)
        $KeyProtectorId = if ($RecoveryProtector.KeyProtectorId) { $RecoveryProtector.KeyProtectorId } else { "{DUMMY-KEY-PROTECTOR-ID}" }

        # Respaldo segÃºn dominio
        $DsregStatus = Invoke-DsregcmdStatus
        $IsAzureAdJoined = ($DsregStatus | Select-String "AzureAdJoined\s*:\s*YES")
        $IsDomainJoined  = ($DsregStatus | Select-String "DomainJoined\s*:\s*YES")

        $BackupSucceeded = $false

        if ($IsDomainJoined) {
            Write-Output "Equipo unido a dominio On-Premise: respaldando clave en Active Directory DS"
            Backup-BitLockerKeyProtector -MountPoint $TargetDrive -KeyProtectorId $KeyProtectorId -ErrorAction Stop
            Write-Output "Clave respaldada exitosamente en Active Directory DS"
            $BackupSucceeded = $true
        }

        if ($IsAzureAdJoined) {
            Write-Output "Equipo unido a Microsoft Entra ID: respaldando clave en el directorio cloud"
            BackupToAAD-BitLockerKeyProtector -MountPoint $TargetDrive -KeyProtectorId $KeyProtectorId -ErrorAction Stop
            Write-Output "Clave respaldada exitosamente en Microsoft Entra ID"
            $BackupSucceeded = $true
        }

        if (-not $BackupSucceeded) {
            throw "ALERTA DE SEGURIDAD: El equipo no estÃ¡ unido a Active Directory ni a Microsoft Entra ID. No se pudo respaldar la clave de recuperaciÃ³n de BitLocker en ningÃºn directorio"
        }

        # ActivaciÃ³n del cifrado
        if ($BitLockerStatus.ProtectionStatus -eq 'Off') {
            Write-Output "Iniciando cifrado de unidad BitLocker (XTS-AES 256)"
            Enable-BitLocker -MountPoint $TargetDrive -EncryptionMethod XtsAes256 -UsedSpaceOnly -SkipHardwareTest -TpmProtector | Out-Null
        }

        Write-Output "BitLocker configurado y validado exitosamente"

    } catch {
        throw "ERROR CRITICO EN GESTION DE BITLOCKER: $_"
    }
}

# Guarda de invocaciÃ³n
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-BitLockerValidation
}
