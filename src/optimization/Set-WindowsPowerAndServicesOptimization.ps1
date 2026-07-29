# OPTIMIZACIÓN DE ENERGÍA Y SERVICIOS (REFACTORIZADO)

# Detección dinámica del factor de forma de hardware vía CIM/WMI
# Tipos de Chasis Laptop: 8 (Portable), 9 (Laptop), 10 (Notebook), 14 (SubNotebook), 30 (Tablet), 31 (Convertible)
$ChassisTypes = (Get-CimInstance -ClassName Win32_SystemEnclosure).ChassisTypes

$IsLaptop = $ChassisTypes | Where-Object { $_ -in @(8, 9, 10, 14, 30, 31, 32) }

if ($IsLaptop) {
    Write-Host "Hardware detectado: PORTÁTIL (Notebook/Laptop). Conservando Hibernación activa para prevención de térmicos/batería en Modern Standby." -ForegroundColor Cyan
    # Asegura que la hibernación esté activa para permitir transiciones de energía seguras
    powercfg -h on
} else {
    Write-Host "Hardware detectado: ESTACIÓN FIJA (Desktop/Workstation/VM). Desactivando Hibernación para liberar espacio en SSD (hiberfil.sys)." -ForegroundColor Yellow
    # Elimina hiberfil.sys y recupera espacio en disco en equipos fijos
    powercfg -h off
}

# Configuración de tiempo de espera de cierre de servicios (Estándar Enterprise: 20000 ms / 20 seg)
# Garantiza el cierre ordenado y el envío de telemetría final de agentes EDR/Antivirus, bases de datos locales y suites CAD/BIM
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "20000" -Type String -Force

# Preservación del Archivo de Paginación / Volcados de Memoria (Dumps)
# Se asegura que ClearPageFileAtShutdown = 0 para acelerar el apagado y evitar sobreescritura previa al análisis de crash dumps
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "ClearPageFileAtShutdown" -Value 0 -Type Dword -Force
