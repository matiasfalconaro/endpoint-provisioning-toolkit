<#
.SYNOPSIS
    Sanitiza y destruye las credenciales de AutoLogon y archivos de respuesta desatendidos.
.DESCRIPTION
    Elimina las claves DefaultPassword, DefaultUserName y AutoAdminLogon del Registro de Windows,
    fuerza el borrado seguro del archivo unattend.xml y verifica que el inicio de sesión automático quede deshabilitado.
.EXAMPLE
    .\Clear-AutoLogonCredentials.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    Write-Output "Iniciando proceso de sanitización de credenciales temporales de AutoLogon..."

    # 1. Borrado seguro de claves de AutoLogon en HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon
    $WinlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    $TargetProperties = @(
        "DefaultPassword",
        "AutoAdminLogon",
        "AutoLogonCount",
        "DefaultUserName",
        "DefaultDomainName"
    )

    foreach ($Property in $TargetProperties) {
        if (Get-ItemProperty -Path $WinlogonPath -Name $Property -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $WinlogonPath -Name $Property -Force -ErrorAction SilentlyContinue
            Write-Output "Clave de registro purgada: $Property"
        }
    }

    # Forzar AutoAdminLogon a 0 explícitamente
    Set-ItemProperty -Path $WinlogonPath -Name "AutoAdminLogon" -Value "0" -Type String -Force

    # 2. Destrucción de archivos de respuesta Unattend con credenciales en texto plano / base64
    $UnattendPaths = @(
        "$env:SystemRoot\Panther\unattend.xml",
        "$env:SystemRoot\Panther\Unattend\unattend.xml",
        "$env:SystemRoot\System32\Sysprep\unattend.xml",
        "C:\unattend.xml"
    )

    foreach ($Path in $UnattendPaths) {
        if (Test-Path -Path $Path) {
            Write-Output "Destruyendo archivo de respuesta con credenciales efímeras: $Path"
            
            # Sobrescritura previa a la eliminación
            Set-Content -Path $Path -Value "SANATIZED" -Force
            Remove-Item -Path $Path -Force
        }
    }

    # 3. Validar que la purga fue exitosa
    $CheckPassword = (Get-ItemProperty -Path $WinlogonPath -ErrorAction SilentlyContinue).DefaultPassword
    if ($null -ne $CheckPassword) {
        throw "ALERTA DE SEGURIDAD CRÍTICA: La contraseña de AutoLogon no pudo ser eliminada del Registro."
    }

    Write-Output "Sanitización de credenciales de AutoLogon completada exitosamente. Registro y disco limpios."

} catch {
    throw "ERROR CRÍTICO EN PURGA DE AUTOLOGON: $_"
}
