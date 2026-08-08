<#
.SYNOPSIS
    Ejecuta el borrado seguro criptogrÃ¡fico de almacenamiento en fase de decomisionamiento.
.DESCRIPTION
    Invoca la instrucciÃ³n nativa de sanitizaciÃ³n de disco de Lenovo UEFI a travÃ©s de CIM/WMI
    requiriendo la contraseÃ±a de Supervisor para autorizar la destrucciÃ³n segura de datos.
.PARAMETER SupervisorPassword
    ContraseÃ±a de Supervisor de BIOS configurada en el equipo como SecureString.
.EXAMPLE
    .\Invoke-LenovoDriveWipe.ps1 -SupervisorPassword $SecurePass
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$SupervisorPassword
)

function Invoke-SecureDriveWipe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$SupervisorPassword
    )

    $ErrorActionPreference = 'Stop'

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SupervisorPassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    try {
        $LenovoWmi = Get-CimClass -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -ErrorAction SilentlyContinue
        if ($null -eq $LenovoWmi) {
            throw "El proveedor CIM de Lenovo (root\wmi:Lenovo_SetBiosSetting) no esta disponible en este hardware."
        }

        $WipeResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = "SecureWipe,Enable;" }
        if ($WipeResult.return -ne "Success") {
            throw "No se pudo habilitar 'SecureWipe' en la BIOS. Codigo: $($WipeResult.return)"
        }

        $AuthResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = "Supervisor Password,Set,$PlainPassword;" }
        if ($AuthResult.return -ne "Success") {
            throw "Autenticacion de BIOS fallida. Retorno: $($AuthResult.return)"
        }

        $SaveResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SaveBiosSettings" -MethodName "SaveBiosSettings"
        if ($SaveResult.return -ne "Success") {
            throw "Falla al persistir la instruccion de borrado en la NVRAM. Retorno: $($SaveResult.return)"
        }

        Write-Output "Instruccion de borrado seguro criptografico programada exitosamente para el proximo reinicio."

    } catch {
        throw "ERROR CRITICO EN DECOMISIONAMIENTO / DRIVE WIPE: $_"
    } finally {
        if ($BSTR -ne [System.IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
        $PlainPassword = $null
        [System.GC]::Collect()
    }
}

# Guarda de invocacion: Solo se ejecuta si se llama directamente al archivo con un parametro valido
if ($MyInvocation.InvocationName -ne '.' -and $PSBoundParameters.ContainsKey('SupervisorPassword')) {
    Invoke-SecureDriveWipe -SupervisorPassword $SupervisorPassword
}
