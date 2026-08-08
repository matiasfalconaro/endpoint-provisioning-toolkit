<#
.SYNOPSIS
    Aplica la Baseline de BIOS corporativa en equipos Lenovo ThinkPad.
.DESCRIPTION
    Configura parÃ¡metros de seguridad UEFI y asigna la contraseÃ±a de Supervisor
    utilizando llamadas CIM/WMI dinÃ¡micas, validaciÃ³n de retornos y gestiÃ³n segura de memoria.
.PARAMETER BiosPassword
    ContraseÃ±a de Supervisor de la BIOS representada como SecureString.
.EXAMPLE
    .\Set-LenovoBiosBaseline.ps1 -BiosPassword (Read-Host -AsSecureString "Ingrese la contraseÃ±a de BIOS")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Ingrese la contraseÃ±a de Supervisor de la BIOS")]
    [System.Security.SecureString]$BiosPassword
)

$ErrorActionPreference = 'Stop'

# SecureString -> puntero en memoria de ejecuciÃ³n activa
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($BiosPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    # Baseline de Seguridad (Excluye AbsolutePersistenceModule por directiva)
    $BiosSettings = @{
        "SecurityChip"             = "Enable"        # dTPM 2.0
        "SecureBoot"               = "Enable"        # Secure Boot
        "UEFI/LegacyBoot"          = "UEFI Only"     # UEFI Puro
        "CSMSupport"               = "Disable"       # CSM Deshabilitado
        "WakeOnLAN"                = "AC Only"       # WOL para Mantenimiento Nocturno
        "BootOrderLock"            = "Enable"        # Bloqueo de Secuencia de Arranque
        "VirtualizationTechnology" = "Enable"        # Intel VT-x / AMD-V
    }

    # ParÃ¡metros estÃ¡ndar mediante proveedor CIM/WMI
    foreach ($Setting in $BiosSettings.GetEnumerator()) {
        $Argument = "$($Setting.Key),$($Setting.Value);"
        $Result = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = $Argument }

        if ($Result.return -ne "Success") {
            # Advertencia, no fallo duro: un setting individual no soportado en un
            # modelo puntual no debe abortar toda la baseline.
            Write-Warning "Falla al aplicar parÃ¡metro de BIOS [$($Setting.Key)]: CÃ³digo de retorno '$($Result.return)'"
        }
    }

    # InyecciÃ³n aislada de la contraseÃ±a de Supervisor
    $PassArgument = "Supervisor Password,Set,$PlainPassword;"
    $PassResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = $PassArgument }

    if ($PassResult.return -ne "Success") {
        throw "No se pudo establecer la contraseÃ±a de Supervisor en la BIOS. Retorno WMI: $($PassResult.return)"
    }

    # ConfirmaciÃ³n y guardado permanente en la NVRAM/microcontrolador
    $SaveResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SaveBiosSettings" -MethodName "SaveBiosSettings"
    if ($SaveResult.return -ne "Success") {
        throw "Falla al persistir los cambios en la NVRAM/microcontrolador. Retorno WMI: $($SaveResult.return)"
    }

    Write-Host "Baseline de BIOS aplicada y guardada exitosamente." -ForegroundColor Green

} finally {
    # Purga obligatoria de credenciales en memoria.
    # Nota: se ejecuta tanto en Ã©xito como en fallo.
    if ($BSTR -ne [System.IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    $PlainPassword = $null
    [System.GC]::Collect()
}
