<#
.SYNOPSIS
    Ajuste dinÃ¡mico de perfiles de energÃ­a por factor de forma (Task Sequence Step).
.DESCRIPTION
    EvalÃºa el tipo de chasis vÃ­a WMI/CIM durante la Task Sequence y aplica el perfil
    de energÃ­a/hibernaciÃ³n correspondiente.
    Las claves de registro de sistema son gestionadas exclusivamente por GPO On-Premise.
#>

[CmdletBinding()]
param()

function Invoke-PowerProfileOptimization {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    Write-Host "Iniciando evaluacion de factor de forma via CIM/WMI..." -ForegroundColor Cyan

    $ChassisTypes = (Get-CimInstance -ClassName Win32_SystemEnclosure).ChassisTypes
    $IsLaptop = $ChassisTypes | Where-Object { $_ -in @(8, 9, 10, 14, 30, 31, 32) }

    if ($IsLaptop) {
        Write-Host "Hardware detectado: PORTATIL. Habilitando hibernacion." -ForegroundColor Green
        powercfg /hibernate on
    } else {
        Write-Host "Hardware detectado: DESKTOP. Deshabilitando hibernacion." -ForegroundColor Yellow
        powercfg /hibernate off
    }

    if ($LASTEXITCODE -ne 0) {
        throw "powercfg finalizo con codigo de salida $LASTEXITCODE. Verificar privilegios de administrador."
    }

    Write-Host "Ajuste dinamico de energia completado exitosamente." -ForegroundColor Green
}

# Guarda de invocacion
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-PowerProfileOptimization
}
