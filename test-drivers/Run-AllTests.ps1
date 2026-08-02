<#
.SYNOPSIS
    Orquesta la batería completa de pruebas locales para Invoke-DeploymentTask.ps1
    y Confirm-ScriptIntegrity.ps1, con verificación automática de resultado esperado.
.DESCRIPTION
    Ejecuta los 5 escenarios de test-drivers/ como procesos hijos aislados, compara
    el exit code y contenido del log contra lo esperado, y muestra un resumen PASS/FAIL.
    El manifest.json real se respalda y restaura de forma garantizada (try/finally),
    incluso si algún test falla de forma inesperada.
.EXAMPLE
    .\test-drivers\Run-AllTests.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot no está garantizado dentro de expresiones default de param()
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).ProviderPath
}
Set-Location $RepoRoot

$ManifestPath = Join-Path $RepoRoot "manifest.json"
$ManifestBackupPath = Join-Path $RepoRoot "manifest.backup.json"
$FallbackLogDir = "C:\Windows\Temp\DeploymentLogs"
$Results = @()

function Invoke-TestDriver {
    param(
        [string]$Name,
        [string]$DriverScript,
        [int]$ExpectedExitCode,
        [string]$ExpectedLogPattern
    )

    Write-Host "`n=== Ejecutando: $Name ===" -ForegroundColor Cyan

    $DriverPath = Join-Path $PSScriptRoot $DriverScript
    if (-not (Test-Path $DriverPath)) {
        throw "No se encontró el driver: $DriverPath"
    }

    powershell -NoProfile -ExecutionPolicy Bypass -File $DriverPath
    $ActualExitCode = $LASTEXITCODE

    $ExitCodeMatch = ($ActualExitCode -eq $ExpectedExitCode)

    $LogMatch = $true
    if ($ExpectedLogPattern) {
        $RecentLog = Get-ChildItem -Path $FallbackLogDir -Filter "*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($RecentLog) {
            $LogContent = Get-Content -Path $RecentLog.FullName -Raw
            $LogMatch = $LogContent -match [regex]::Escape($ExpectedLogPattern)
        } else {
            $LogMatch = $false
        }
    }

    $Passed = $ExitCodeMatch -and $LogMatch

    $script:Results += [PSCustomObject]@{
        Test              = $Name
        ExpectedExitCode  = $ExpectedExitCode
        ActualExitCode    = $ActualExitCode
        LogPatternMatched = $LogMatch
        Result            = if ($Passed) { "PASS" } else { "FAIL" }
    }

    $Color = if ($Passed) { "Green" } else { "Red" }
    Write-Host "Resultado: $(if ($Passed) {'PASS'} else {'FAIL'}) (exit code: $ActualExitCode, esperado: $ExpectedExitCode)" -ForegroundColor $Color
}

try {
    # Precondición: respaldo del manifiesto real
    # Todo lo que sigue asume que este backup existe y es restaurable
    if (-not (Test-Path $ManifestPath)) {
        Write-Host "manifest.json no existe, generando uno nuevo..." -ForegroundColor Yellow
        & (Join-Path $RepoRoot "src\security\Confirm-ScriptIntegrity.ps1") `
            -Action Generate -SourcePath $RepoRoot -ManifestPath $ManifestPath
    }
    Copy-Item $ManifestPath $ManifestBackupPath -Force

    # Limpieza de logs previos
    if (Test-Path $FallbackLogDir) {
        Remove-Item "$FallbackLogDir\*.log" -Force -ErrorAction SilentlyContinue
    }

    # Test 0: happy path, con ambos skips (valida binding de parámetros y flujo feliz)
    Invoke-TestDriver -Name "Test 0 - Happy Path (skips)" `
        -DriverScript "test0-happypath.ps1" `
        -ExpectedExitCode 0 `
        -ExpectedLogPattern "Tarea completada exitosamente."

    # Test 1: happy path real, sin skip de integridad
    # Nota: si Invoke-DeploymentTask.ps1 tiene cambios sin commitear/sin reflejar en
    # manifest.json, este test es ESPERADO que falle (discrepancia de hash del propio
    # wrapper) hasta que la rama se mergee y CI regenere el manifiesto.
    Invoke-TestDriver -Name "Test 1 - Happy Path (integridad real)" `
        -DriverScript "test1-happypath.ps1" `
        -ExpectedExitCode 0 `
        -ExpectedLogPattern "Tarea completada exitosamente."

    # Test 2: sin -ScriptPath, debe abortar
    Invoke-TestDriver -Name "Test 2 - Sin ScriptPath" `
        -DriverScript "test2-nopath.ps1" `
        -ExpectedExitCode 1 `
        -ExpectedLogPattern "SEGURIDAD CRÍTICA: -ScriptPath no fue provisto"

    # Test 3: manifiesto corrupto a propósito
    (Get-Content $ManifestPath -Raw) -replace '"src/', '"XXX/' | Set-Content $ManifestPath -NoNewline
    Invoke-TestDriver -Name "Test 3 - Manifiesto alterado" `
        -DriverScript "test3-tamper.ps1" `
        -ExpectedExitCode 1 `
        -ExpectedLogPattern "FALLA DE INTEGRIDAD"
    # Restauración inmediata, no depender solo del finally general para este paso puntual
    Copy-Item $ManifestBackupPath $ManifestPath -Force

    # Test 4: proceso externo falla
    Invoke-TestDriver -Name "Test 4 - Fallo de proceso externo" `
        -DriverScript "test4-externalfail.ps1" `
        -ExpectedExitCode 1 `
        -ExpectedLogPattern "código de salida 87"

    # Test 5: confirmar que el WARNING de fallback se persiste, uno por proceso
    $AllLogs = Get-ChildItem -Path $FallbackLogDir -Filter "*.log" -ErrorAction SilentlyContinue
    $FallbackWarnings = 0
    foreach ($Log in $AllLogs) {
        $FallbackWarnings += (Select-String -Path $Log.FullName -Pattern "Log de red inaccesible").Count
    }
    Write-Host "`n=== Test 5 - Verificación de fallback de log ===" -ForegroundColor Cyan
    $Expected5 = 5  # una por cada uno de los 5 procesos hijo (Test 0 a 4)
    $Test5Pass = ($FallbackWarnings -eq $Expected5)
    Write-Host "Advertencias de fallback encontradas: $FallbackWarnings (esperado: $Expected5)" -ForegroundColor $(if ($Test5Pass) {"Green"} else {"Red"})

    $script:Results += [PSCustomObject]@{
        Test              = "Test 5 - Persistencia de warning de fallback"
        ExpectedExitCode  = "N/A"
        ActualExitCode    = "N/A"
        LogPatternMatched = $Test5Pass
        Result            = if ($Test5Pass) { "PASS" } else { "FAIL" }
    }

} finally {
    # Restauración garantizada del manifiesto real, incluso si algo falló arriba
    if (Test-Path $ManifestBackupPath) {
        Copy-Item $ManifestBackupPath $ManifestPath -Force
        Remove-Item $ManifestBackupPath -Force
        Write-Host "`nmanifest.json restaurado a su estado original." -ForegroundColor Gray
    }

    # Archivar logs de esta corrida
    if (Test-Path $FallbackLogDir) {
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $ArchiveDir = Join-Path $PSScriptRoot "logs_$Timestamp"
        New-Item -Path $ArchiveDir -ItemType Directory -Force | Out-Null
        Copy-Item "$FallbackLogDir\*.log" -Destination $ArchiveDir -Force -ErrorAction SilentlyContinue
        Remove-Item "$FallbackLogDir\*.log" -Force -ErrorAction SilentlyContinue
        Write-Host "Logs de esta corrida archivados en: $ArchiveDir" -ForegroundColor Gray
    }
}

Write-Host "`n=== RESUMEN ===" -ForegroundColor Cyan
$Results | Format-Table -AutoSize

$FailCount = ($Results | Where-Object { $_.Result -eq "FAIL" }).Count
if ($FailCount -gt 0) {
    Write-Host "$FailCount test(s) fallaron." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Todos los tests pasaron." -ForegroundColor Green
    exit 0
}
