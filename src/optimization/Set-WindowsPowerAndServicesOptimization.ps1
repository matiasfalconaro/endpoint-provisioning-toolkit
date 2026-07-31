<#
.SYNOPSIS
    Ajuste dinámico de perfiles de energía por factor de forma (Task Sequence Step).
.DESCRIPTION
    Evalúa el tipo de chasis vía WMI/CIM durante la Task Sequence y aplica el perfil 
    de energía/hibernación correspondiente.
    Las claves de registro de sistema son gestionadas exclusivamente por GPO On-Premise.
#>

[CmdletBinding()]
param()

Write-Host "Iniciando evaluación de factor de forma vía CIM/WMI..." -ForegroundColor Cyan

# Detección del tipo de chasis vía CIM
$ChassisTypes = (Get-CimInstance -ClassName Win32_SystemEnclosure).ChassisTypes
$IsLaptop = $ChassisTypes | Where-Object { $_ -in @(8, 9, 10, 14, 30, 31, 32) }

if ($IsLaptop) {
    Write-Host "Hardware detectado: PORTÁTIL (IsLaptop = True)." -ForegroundColor Green
    Write-Host "Inyectando perfil de energía con Hibernación HABILITADA (Modern Standby / SO Idle)." -ForegroundColor Green
    powercfg /hibernate on
} else {
    Write-Host "Hardware detectado: ESTACIÓN FIJA / DESKTOP (IsDesktop = True)." -ForegroundColor Yellow
    Write-Host "Inyectando perfil de energía para estaciones fijas: Hibernación DESHABILITADA." -ForegroundColor Yellow
    powercfg /hibernate off
}

# NOTA:
# Las configuraciones 'WaitToKillServiceTimeout' y 'ClearPageFileAtShutdown' se omiten de este script.
# Se imponen de forma declarativa e inmutable a través de la directiva GPO-WIN10-SECURITY-BASELINE-v1.2.

Write-Host "Ajuste dinámico de energía completado exitosamente." -ForegroundColor Green
