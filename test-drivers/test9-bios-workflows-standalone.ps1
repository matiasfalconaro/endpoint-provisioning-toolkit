<#
.SYNOPSIS
    Driver de prueba para verificar la propagación de errores en los workflows de BIOS refactorizados.
#>

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).ProviderPath

# Dot-sourcing de los scripts refactorizados
. (Join-Path $RepoRoot "src\bios\workflows\New-BiosEncryptedSecret.ps1")
. (Join-Path $RepoRoot "src\bios\workflows\Set-LenovoBiosWithDpapi.ps1")
. (Join-Path $RepoRoot "src\bios\workflows\Set-LenovoBiosWithThinkBios.ps1")

$FailedCases = 0

# Prueba 1: Ruta inexistente en Set-LenovoBiosWithDpapi debe provocar un throw
try {
    Invoke-LenovoBiosWithDpapi -KeyPath "C:\Ruta\Inexistente\Secret.key"
    Write-Host "FAIL: Set-LenovoBiosWithDpapi no abortó ante un archivo inexistente." -ForegroundColor Red
    $FailedCases++
} catch {
    Write-Host "PASS: Set-LenovoBiosWithDpapi abortó correctamente ante ruta inexistente." -ForegroundColor Green
}

# Prueba 2: Archivo de configuración inexistente en Set-LenovoBiosWithThinkBios debe provocar un throw
try {
    Invoke-ThinkBiosConfig -ConfigFile "C:\Ruta\Inexistente\Config.ini"
    Write-Host "FAIL: Set-LenovoBiosWithThinkBios no abortó ante un archivo inexistente." -ForegroundColor Red
    $FailedCases++
} catch {
    Write-Host "PASS: Set-LenovoBiosWithThinkBios abortó correctamente ante ruta inexistente." -ForegroundColor Green
}

if ($FailedCases -gt 0) {
    exit 1
} else {
    exit 0
}
