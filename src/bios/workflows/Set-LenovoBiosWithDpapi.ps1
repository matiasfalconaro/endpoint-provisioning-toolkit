<#
.SYNOPSIS
    Aplica la Baseline de BIOS de Lenovo utilizando un secreto cifrado por DPAPI.
.DESCRIPTION
    Desencripta la contraseña de BIOS en memoria efímera, la inyecta vía CIM/WMI
    y garantiza la purga inmediata de memoria.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$KeyPath = ".\BiosSecret.key"
)

if (-not (Test-Path $KeyPath)) {
    throw "No se encontró el archivo de secreto cifrado en la ruta: $KeyPath"
}

# Lectura y conversión del secreto cifrado
$EncryptedSecret = Get-Content -Path $KeyPath | ConvertTo-SecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptedSecret)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    # 1. Aplicación de la Baseline de Seguridad.
    $BiosSettings = @{
        "SecurityChip"             = "Enable"        # dTPM 2.0
        "SecureBoot"               = "Enable"        # Secure Boot
        "UEFI/LegacyBoot"          = "UEFI Only"     # UEFI Puro
        "CSMSupport"               = "Disable"       # CSM Deshabilitado
        "WakeOnLAN"                = "AC Only"       # WOL para Mantenimiento Nocturno
        "BootOrderLock"            = "Enable"        # Bloqueo de Secuencia de Arranque
        "VirtualizationTechnology" = "Enable"        # Intel VT-x / AMD-V
    }

    foreach ($Setting in $BiosSettings.GetEnumerator()) {
        $Argument = "$($Setting.Key),$($Setting.Value);"
        Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = $Argument } | Out-Null
    }

    # 2. Inyección de la contraseña con la sintaxis EXACTA ("Supervisor Password,Set,<PASSWORD>")
    $PassArgument = "Supervisor Password,Set,$PlainPassword;"
    $PassResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = $PassArgument }

    if ($PassResult.return -ne "Success") {
        throw "No se pudo establecer la contraseña de Supervisor en la BIOS. Retorno WMI: $($PassResult.return)"
    }

    # 3. Guardado en NVRAM
    $SaveResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SaveBiosSettings" -MethodName "SaveBiosSettings"
    if ($SaveResult.return -ne "Success") {
        throw "Falla al persistir los cambios en la NVRAM/microcontrolador. Retorno WMI: $($SaveResult.return)"
    }

    Write-Host "Baseline y Contraseña de BIOS inyectadas exitosamente mediante DPAPI." -ForegroundColor Green
}
finally {
    # Purga explícita del puntero en memoria
    if ($BSTR -ne [System.IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    $PlainPassword = $null
    [System.GC]::Collect()
}
