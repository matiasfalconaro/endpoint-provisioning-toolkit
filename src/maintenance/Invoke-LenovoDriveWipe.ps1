<#
.SYNOPSIS
    Ejecuta el borrado seguro criptográfico de almacenamiento en fase de decomisionamiento.
.DESCRIPTION
    Invoca la instrucción nativa de sanitización de disco de Lenovo UEFI a través de CIM/WMI
    requiriendo la contraseña de Supervisor para autorizar la destrucción segura de datos.
.PARAMETER SupervisorPassword
    Contraseña de Supervisor de BIOS configurada en el equipo como SecureString.
.EXAMPLE
    .\Invoke-LenovoDriveWipe.ps1 -SupervisorPassword $SecurePass
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Ingrese la contraseña de Supervisor de la BIOS corporativa")]
    [System.Security.SecureString]$SupervisorPassword
)

$ErrorActionPreference = 'Stop'

# Conversión de credencial a memoria efímera
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SupervisorPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    # 1. Verificación de presencia del proveedor CIM de Lenovo
    $LenovoWmi = Get-CimClass -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -ErrorAction SilentlyContinue
    if ($null -eq $LenovoWmi) {
        throw "El proveedor CIM de Lenovo (root\wmi:Lenovo_SetBiosSetting) no está disponible en este hardware."
    }

    # 2. Configuración de bandera de borrado de disco (Secure Wipe / Cryptographic Erase)
    # Formato de comando estructurado Lenovo CIM: "Secure Wipe, Enable"
    $WipeArgument = "SecureWipe,Enable;"
    $WipeResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = $WipeArgument }

    if ($WipeResult.return -ne "Success") {
        throw "No se pudo habilitar el parámetro 'SecureWipe' en la BIOS. Código devuelto: $($WipeResult.return)"
    }

    # 3. Autenticación con contraseña de Supervisor para autorizar el comando
    $AuthArgument = "Supervisor Password,Set,$PlainPassword;"
    $AuthResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = $AuthArgument }

    if ($AuthResult.return -ne "Success") {
        throw "Autenticación de BIOS fallida. No se pudo validar la contraseña de Supervisor para ejecutar el borrado. Retorno: $($AuthResult.return)"
    }

    # 4. Guardado y persistencia en la NVRAM (Dispara la sanitización en el próximo reinicio)
    $SaveResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SaveBiosSettings" -MethodName "SaveBiosSettings"
    if ($SaveResult.return -ne "Success") {
        throw "Falla al persistir la instrucción de borrado seguro en la NVRAM. Retorno: $($SaveResult.return)"
    }

    Write-Output "Instrucción de borrado seguro criptográfico (Cryptographic Erase) programada exitosamente para el próximo reinicio del sistema."

} catch {
    throw "ERROR CRÍTICO EN DECOMISIONAMIENTO / DRIVE WIPE: $_"
} finally {
    # Purga obligatoria de credenciales en memoria efímera
    if ($BSTR -ne [System.IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    $PlainPassword = $null
    [System.GC]::Collect()
}
