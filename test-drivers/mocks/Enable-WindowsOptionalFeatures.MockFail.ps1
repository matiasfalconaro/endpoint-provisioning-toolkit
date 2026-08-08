<#
.SYNOPSIS
    Mock de Enable-WindowsOptionalFeatures.ps1 que simula un fallo real de DISM
    (código 87, "parámetro incorrecto") en el segundo paso, para probar que el
    fix captura correctamente $LASTEXITCODE de un proceso externo.
.DESCRIPTION
    Reemplaza dism.exe por cmd.exe /c exit <código>, sin tocar el sistema real.
    Usado por test8-features-exitcode.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetDrive = "C:\"
)

# GUARDA DE SEGURIDAD
if ($env:ALLOW_HAZARDOUS_TESTS -ne "true") {
    Write-Warning "El test/mock [$($MyInvocation.MyCommand.Name)] está deshabilitado por guarda de seguridad."
    Write-Host "Para forzar su ejecución establece: `$env:ALLOW_HAZARDOUS_TESTS='true'" -ForegroundColor Yellow
    exit 0
}

$ErrorActionPreference = 'Stop'

function Invoke-DismStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [int]$SimulatedExitCode
    )

    Write-Host "Ejecutando: $Description..." -ForegroundColor Cyan
    cmd.exe /c exit $SimulatedExitCode
    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0 -and $ExitCode -ne 3010) {
        throw "Fallo en DISM durante '$Description'. Código de salida: $ExitCode"
    }
}

Invoke-DismStep -Description "Paso 1 (simulado, éxito)" -SimulatedExitCode 0
Invoke-DismStep -Description "Paso 2 (simulado, FALLO)" -SimulatedExitCode 87
Invoke-DismStep -Description "Paso 3 (no debería alcanzarse)" -SimulatedExitCode 0

Write-Host "Servicing Offline de características completado exitosamente." -ForegroundColor Green
