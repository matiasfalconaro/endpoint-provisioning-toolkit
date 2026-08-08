<#
.SYNOPSIS
    Mock de fallo para Get-PerformanceHealthStatus.ps1 (Test 10 - Run-AllTests.ps1).
.DESCRIPTION
    Simula una excepcion terminante real del proveedor WMI/CIM (ej. repositorio
    corrupto, clase no registrada) en lugar de un $null silencioso, para validar
    que $ErrorActionPreference = 'Stop' y el bloque try/catch del script propagan
    el fallo correctamente en aislamiento (sin el wrapper Invoke-DeploymentTask.ps1).
.EXAMPLE
    .\Get-PerformanceHealthStatus.MockFail.ps1
#>

[CmdletBinding()]
param()

function global:Get-PhysicalDisk {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]$InputObject,
        $UniqueId,
        $FriendlyName
    )
    process {
        [PSCustomObject]@{ Model = 'NVMe Simulado'; BusType = 'NVMe' }
    }
}

function global:Get-CimInstance {
    [CmdletBinding()]
    param(
        [string]$ClassName,
        [string]$Namespace
    )
    # -ErrorAction ya lo provee CmdletBinding() como parametro comun;
    # declararlo explicitamente aqui genera "defined multiple times".
    throw [System.Management.Automation.RuntimeException] "Invalid class - MSFT_WmiError (0x80041010): El repositorio WMI reporta corrupcion de namespace."
}

# Ejecucion en aislamiento total
try {
    . "$PSScriptRoot\..\..\src\maintenance\Get-PerformanceHealthStatus.ps1"

    if (-not (Get-Command Invoke-PerformanceHealthAudit -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR DE SETUP: Get-PerformanceHealthStatus.ps1 no se pudo cargar (verificar ruta)." -ForegroundColor Red
        exit 2
    }

    $Result = Invoke-PerformanceHealthAudit
    Write-Host "FALLO DE PRUEBA: El script no aborto ante la excepcion CIM simulada." -ForegroundColor Red
    exit 1
} catch {
    Write-Host "OK: El script aborto correctamente ante la excepcion CIM. Mensaje: $_" -ForegroundColor Green
    exit 0
}
