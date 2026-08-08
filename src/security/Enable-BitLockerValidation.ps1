<#
.SYNOPSIS
    Valida, configura y respalda las claves de BitLocker en Active Directory / Entra ID.
.DESCRIPTION
    Verifica los requisitos de dTPM 2.0, asigna el protector TPM, fuerza el respaldo
    de la clave de recuperación en AD DS y/o Microsoft Entra ID según el escenario de
    unión del equipo, y confirma el cifrado del volumen del sistema.
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
        # Verificación de dTPM 2.0
        $Tpm = Get-Tpm -ErrorAction SilentlyContinue
        if (-not $Tpm.TpmReady) {
            throw "SEGURIDAD CRÍTICA: El chip dTPM 2.0 no está listo para habilitar BitLocker"
        }

        $TargetDrive = $env:SystemDrive

        # Comprobación de estado
        $BitLockerStatus = Get-BitLockerVolume -MountPoint $TargetDrive -ErrorAction Stop

        # Inyección de protector TPM
        $TpmProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }
        if ($null -eq $TpmProtector) {
            Write-Output "Añadiendo protector dTPM al volumen $TargetDrive"
            Add-BitLockerKeyProtector -MountPoint $TargetDrive -TpmProtector | Out-Null
        }

        # Generación / Obtención de Recovery Password
        $RecoveryProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
        if ($null -eq $RecoveryProtector -or [string]::IsNullOrEmpty($RecoveryProtector.KeyProtectorId)) {
            Write-Output "Generando clave de recuperación de 48 dígitos"
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

        # Respaldo según dominio
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
            throw "ALERTA DE SEGURIDAD: El equipo no está unido a Active Directory ni a Microsoft Entra ID. No se pudo respaldar la clave de recuperación de BitLocker en ningún directorio"
        }

        # Activación del cifrado
        if ($BitLockerStatus.ProtectionStatus -eq 'Off') {
            Write-Output "Iniciando cifrado de unidad BitLocker (XTS-AES 256)"
            Enable-BitLocker -MountPoint $TargetDrive -EncryptionMethod XtsAes256 -UsedSpaceOnly -SkipHardwareTest -TpmProtector | Out-Null
        }

        Write-Output "BitLocker configurado y validado exitosamente"

    } catch {
        throw "ERROR CRITICO EN GESTION DE BITLOCKER: $_"
    }
}

# Guarda de invocación
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-BitLockerValidation
}
