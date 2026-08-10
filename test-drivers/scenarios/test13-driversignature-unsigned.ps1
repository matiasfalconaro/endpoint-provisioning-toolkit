<#
.SYNOPSIS
    Driver de escenario para Test 13 (Run-AllTests.ps1) - Firma de drivers no verificada.
.DESCRIPTION
    Carga el mock de Get-WindowsDriver (driver no firmado simulado), ejecuta
    Confirm-DriverSignature.ps1 en aislamiento total y valida que la excepcion
    de seguridad se propague correctamente (exit distinto de 0).
.EXAMPLE
    .\test13-driversignature-unsigned.ps1
#>

[CmdletBinding()]
param()

try {
    . "$PSScriptRoot\..\mocks\Confirm-DriverSignature.MockFail.ps1"
    . "$PSScriptRoot\..\..\src\security\Confirm-DriverSignature.ps1"

    if (-not (Get-Command Invoke-DriverSignatureAudit -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR DE SETUP: Confirm-DriverSignature.ps1 no se pudo cargar (verificar ruta)." -ForegroundColor Red
        exit 2
    }

    $Result = Invoke-DriverSignatureAudit -Online
    Write-Host "FALLO DE PRUEBA: El script no aborto ante el driver no firmado simulado." -ForegroundColor Red
    exit 1
} catch {
    Write-Host "OK: El script aborto correctamente ante driver no firmado. Mensaje: $_" -ForegroundColor Green
    exit 0
}
