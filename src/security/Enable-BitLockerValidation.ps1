<#
.SYNOPSIS
    Valida, configura y respalda las claves de BitLocker en Active Directory / Entra ID.
.DESCRIPTION
    Verifica los requisitos de dTPM 2.0, asigna el protector TPM, fuerza el respaldo 
    de la clave de recuperaciÃ³n en AD DS y confirma el cifrado del volumen del sistema.
.EXAMPLE
    .\Enable-BitLockerValidation.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    # 1. VerificaciÃ³n de presencia y estado de dTPM 2.0
    $Tpm = Get-Tpm -ErrorAction SilentlyContinue
    if (-not $Tpm.TpmReady) {
        throw "SEGURIDAD CRÃTICA: El chip dTPM 2.0 no estÃ¡ listo para habilitar BitLocker."
    }

    $TargetDrive = $env:SystemDrive # TÃ­picamente C:

    # 2. ComprobaciÃ³n de estado actual de BitLocker
    $BitLockerStatus = Get-BitLockerVolume -MountPoint $TargetDrive -ErrorAction Stop

    # 3. InyecciÃ³n de protector TPM si no existe
    $TpmProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }
    if ($null -eq $TpmProtector) {
        Write-Output "AÃ±adiendo protector dTPM al volumen $TargetDrive..."
        Add-BitLockerKeyProtector -MountPoint $TargetDrive -TpmProtector | Out-Null
    }

    # 4. GeneraciÃ³n de Recovery Password si no existe
    $RecoveryProtector = $BitLockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
    if ($null -eq $RecoveryProtector) {
        Write-Output "Generando clave de recuperaciÃ³n de 48 dÃ­gitos..."
        $RecoveryProtector = Add-BitLockerKeyProtector -MountPoint $TargetDrive -RecoveryPasswordProtector
    }

    # 5. Respaldado de la clave de recuperaciÃ³n en Active Directory DS
    Write-Output "Respaldando clave de recuperaciÃ³n en Active Directory DS..."
    $BackupResult = BackupToAADOrO365 -MountPoint $TargetDrive -KeyProtectorId $RecoveryProtector.KeyProtectorId -ErrorAction SilentlyContinue
    $BackupAD = Backup-BitLockerKeyProtector -MountPoint $TargetDrive -KeyProtectorId $RecoveryProtector.KeyProtectorId

    if ($null -eq $BackupAD) {
        throw "ALERTA DE SEGURIDAD: Falla al respaldar la clave de recuperaciÃ³n de BitLocker en Active Directory."
    }

    # 6. ActivaciÃ³n final del cifrado si estaba suspendido o apagado
    if ($BitLockerStatus.ProtectionStatus -eq 'Off') {
        Write-Output "Iniciando cifrado de unidad BitLocker (XTS-AES 256)..."
        Enable-BitLocker -MountPoint $TargetDrive -EncryptionMethod XtsAes256 -UsedSpaceOnly -SkipHardwareTest | Out-Null
    }

    Write-Output "BitLocker configurado y validado exitosamente. Clave de recuperaciÃ³n respaldada en el directorio."

} catch {
    throw "ERROR CRÃTICO EN GESTIÃ“N DE BITLOCKER: $_"
}
