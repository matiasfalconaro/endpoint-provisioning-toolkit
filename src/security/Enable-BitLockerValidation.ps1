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

$ErrorActionPreference = 'Stop'

try {
    # 1. Verificación de presencia y estado de dTPM 2.0
    $Tpm = Get-Tpm -ErrorAction SilentlyContinue
    if (-not $Tpm.TpmReady) {
        throw "SEGURIDAD CRÍTICA: El chip dTPM 2.0 no está listo para habilitar BitLocker."
    }

    $TargetDrive = $env:SystemDrive # Típicamente C:

    # 2. Comprobación de estado actual de BitLocker
    $BitLockerStatus = Get-BitLockerVolume -MountPoint $TargetDrive -ErrorAction Stop

    # 3. Inyección de protector TPM si no existe
    $TpmProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }
    if ($null -eq $TpmProtector) {
        Write-Output "Añadiendo protector dTPM al volumen $TargetDrive..."
        Add-BitLockerKeyProtector -MountPoint $TargetDrive -TpmProtector | Out-Null
    }

    # 4. Generación de Recovery Password si no existe
    $RecoveryProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
    if ($null -eq $RecoveryProtector) {
        Write-Output "Generando clave de recuperación de 48 dígitos..."
        $RecoveryProtector = Add-BitLockerKeyProtector -MountPoint $TargetDrive -RecoveryPasswordProtector
    }

    # 5. Respaldado de la clave de recuperación, según escenario de unión
    $DsregStatus = dsregcmd /status
    $IsAzureAdJoined = ($DsregStatus | Select-String "AzureAdJoined\s*:\s*YES")
    $IsDomainJoined  = ($DsregStatus | Select-String "DomainJoined\s*:\s*YES")

    $BackupSucceeded = $false

    if ($IsDomainJoined) {
        Write-Output "Equipo unido a dominio On-Premise: respaldando clave en Active Directory DS..."
        $BackupAD = Backup-BitLockerKeyProtector -MountPoint $TargetDrive -KeyProtectorId $RecoveryProtector.KeyProtectorId -ErrorAction Stop
        Write-Output "Clave respaldada exitosamente en Active Directory DS."
        $BackupSucceeded = $true
    }

    if ($IsAzureAdJoined) {
        Write-Output "Equipo unido a Microsoft Entra ID: respaldando clave en el directorio cloud..."
        BackupToAAD-BitLockerKeyProtector -MountPoint $TargetDrive -KeyProtectorId $RecoveryProtector.KeyProtectorId -ErrorAction Stop
        Write-Output "Clave respaldada exitosamente en Microsoft Entra ID."
        $BackupSucceeded = $true
    }

    if (-not $BackupSucceeded) {
        throw "ALERTA DE SEGURIDAD: El equipo no está unido a Active Directory ni a Microsoft Entra ID. No se pudo respaldar la clave de recuperación de BitLocker en ningún directorio."
    }

    # 6. Activación final del cifrado si estaba suspendido o apagado
    if ($BitLockerStatus.ProtectionStatus -eq 'Off') {
        Write-Output "Iniciando cifrado de unidad BitLocker (XTS-AES 256)..."
        Enable-BitLocker -MountPoint $TargetDrive -EncryptionMethod XtsAes256 -UsedSpaceOnly -SkipHardwareTest | Out-Null
    }

    Write-Output "BitLocker configurado y validado exitosamente. Clave de recuperación respaldada en el directorio."

} catch {
    throw "ERROR CRÍTICO EN GESTIÓN DE BITLOCKER: $_"
}
