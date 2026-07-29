<#
.SYNOPSIS
    Aplica la Baseline de BIOS corporativa en equipos Lenovo ThinkPad.
.DESCRIPTION
    Configura parámetros de seguridad UEFI y asigna la contraseña de Supervisor
    utilizando llamadas CIM/WMI dinámicas, validación de retornos y gestión segura de memoria.
.PARAMETER BiosPassword
    Contraseña de Supervisor de la BIOS representada como SecureString.
.EXAMPLE
    .\Set-LenovoBiosBaseline.ps1 -BiosPassword (Read-Host -AsSecureString "Ingrese la contraseña de BIOS")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Ingrese la contraseña de Supervisor de la BIOS")]
    [System.Security.SecureString]$BiosPassword
)

# Convertir SecureString a puntero en memoria de ejecución activa
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($BiosPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    # 1. Definición de la Baseline de Seguridad (Sin credenciales hardcodeadas)
    # NOTA: AbsolutePersistenceModule se excluye de la baseline global para evitar bloqueos no deseados.
    $BiosSettings = @{
        "SecurityChip"              = "Enable"        # dTPM 2.0
        "SecureBoot"                = "Enable"        # Secure Boot
        "UEFI/LegacyBoot"           = "UEFI Only"     # UEFI Puro
        "CSMSupport"                = "Disable"       # CSM Deshabilitado
        "WakeOnLAN"                 = "AC Only"       # WOL para Mantenimiento Nocturno
        "BootOrderLock"             = "Enable"        # Bloqueo de Secuencia de Arranque
        "VirtualizationTechnology"  = "Enable"        # Intel VT-x / AMD-V
    }

    # 2. Aplicación y validación de parámetros estándar mediante proveedor CIM/WMI
    foreach ($Setting in $BiosSettings.GetEnumerator()) {
        $Result = (Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SetBiosSetting).SetBiosSetting("$($Setting.Key),$($Setting.Value)")
        if ($Result.return -ne "Success") {
            Write-Warning "Falla al aplicar parámetro de BIOS [$($Setting.Key)]: Código de retorno '$($Result.return)'"
        }
    }

    # 3. Inyección aislada de la contraseña de Supervisor con validación
    # Estructura del método Lenovo: "SupervisorPassword,Set,<PASSWORD>"
    $PassResult = (Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SetBiosSetting).SetBiosSetting("SupervisorPassword,Set,$PlainPassword")
    if ($PassResult.return -ne "Success") {
        throw "No se pudo establecer la contraseña de Supervisor en la BIOS. Retorno WMI: $($PassResult.return)"
    }

    # 4. Confirmación y guardado permanente en el microcontrolador (NVRAM)
    $SaveResult = (Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SaveBiosSettings).SaveBiosSettings()
    if ($SaveResult.return -ne "Success") {
        throw "Falla al persistir los cambios en la NVRAM/microcontrolador. Retorno WMI: $($SaveResult.return)"
    }

    Write-Host "Baseline de BIOS aplicada y guardada exitosamente." -ForegroundColor Green

} catch {
    Write-Error "Error crítico durante la configuración de BIOS vía CIM/WMI: $_"
} finally {
    # Purga obligatoria de credenciales en memoria (Hardening de Ejecución)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    $PlainPassword = $null
    [System.GC]::Collect()
}
