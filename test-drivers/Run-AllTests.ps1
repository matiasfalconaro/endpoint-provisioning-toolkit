<#
.SYNOPSIS
    Orquesta la batería completa de pruebas locales para Invoke-DeploymentTask.ps1,
    Confirm-ScriptIntegrity.ps1 y Set-LenovoBiosBaseline.ps1, con auditoría de
    linter y verificación opcional de codificación BOM.
.DESCRIPTION
    1. (Opcional, vía -FixEncoding) Normaliza recursivamente los archivos .ps1 en
       src/ a UTF-8 con BOM para PowerShell 5.1. No se ejecuta por defecto.
    2. Ejecuta PSScriptAnalyzer sobre la carpeta src/ para verificar calidad de código.
    3. Ejecuta los 8 escenarios de test-drivers/ (Test 0 a Test 7) como procesos
       hijos aislados, incluyendo los tests de propagación de errores en BIOS
       (Test 6/7), que corren en aislamiento total sin pasar por el wrapper.
    4. Compara exit code y logs, restaura manifest.json y muestra un resumen
       general PASS/FAIL.
.PARAMETER RepoRoot
    Raíz del repositorio. Si se omite, se resuelve automáticamente en base a
    la ubicación de este script.
.PARAMETER FixEncoding
    Si se especifica, normaliza todos los .ps1 de src/ a UTF-8 con BOM antes
    de correr los tests. No es automático: correr el orquestador sin este
    switch no modifica ningún archivo del repositorio.
.EXAMPLE
    .\test-drivers\Run-AllTests.ps1
.EXAMPLE
    .\test-drivers\Run-AllTests.ps1 -FixEncoding
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [switch]$FixEncoding
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
$SrcPath = Join-Path $RepoRoot "src"
$Results = @()

# ETAPA PREVIA: NORMALIZACIÓN DE ENCODING (opt-in, no automática)
if ($FixEncoding) {
    Write-Host "=== Etapa Previa 1: Verificando/Aplicando UTF-8 con BOM en scripts ===" -ForegroundColor Cyan
    if (Test-Path $SrcPath) {
        Get-ChildItem -Path $SrcPath -Recurse -Filter *.ps1 | ForEach-Object {
            $filePath = $_.FullName
            $content = Get-Content $filePath -Raw
            [System.IO.File]::WriteAllText($filePath, $content, [System.Text.UTF8Encoding]::new($true))
        }
        Write-Host "Codificación UTF-8 BOM normalizada en $SrcPath." -ForegroundColor Green
    }
} else {
    Write-Host "=== Etapa Previa 1: Normalización de encoding OMITIDA (usar -FixEncoding para aplicarla) ===" -ForegroundColor DarkGray
}

# ETAPA PREVIA: AUDITORÍA DE LINTER
Write-Host "`n=== Etapa Previa 2: Análisis estático con PSScriptAnalyzer ===" -ForegroundColor Cyan
if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
    Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
    $LintIssues = Invoke-ScriptAnalyzer -Path $SrcPath -Recurse -Severity Error, Warning
    
    if ($LintIssues) {
        Write-Host "PSScriptAnalyzer reportó observaciones:" -ForegroundColor Yellow
        $LintIssues | Format-Table -AutoSize
    } else {
        Write-Host "Análisis de linter completado sin errores ni advertencias." -ForegroundColor Green
    }
} else {
    Write-Host "[ADVERTENCIA] Módulo PSScriptAnalyzer no instalado. Omitiendo auditoría estática." -ForegroundColor Yellow
}

# FUNCIÓN AUXILIAR DE PRUEBAS
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

# BATERÍA DE PRUEBAS UNITARIAS E INTEGRACIÓN
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

    # Test 0: happy path (skips)
    Invoke-TestDriver -Name "Test 0 - Happy Path (skips)" `
        -DriverScript "test0-happypath.ps1" `
        -ExpectedExitCode 0 `
        -ExpectedLogPattern "Tarea completada exitosamente."

    # Test 1: happy path real
    Invoke-TestDriver -Name "Test 1 - Happy Path (integridad real)" `
        -DriverScript "test1-happypath.ps1" `
        -ExpectedExitCode 0 `
        -ExpectedLogPattern "Tarea completada exitosamente."

    # Test 2: sin -ScriptPath
    Invoke-TestDriver -Name "Test 2 - Sin ScriptPath" `
        -DriverScript "test2-nopath.ps1" `
        -ExpectedExitCode 1 `
        -ExpectedLogPattern "SEGURIDAD CRÍTICA: -ScriptPath no fue provisto"

    # Test 3: manifiesto alterado
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

    # Test 5: persistencia de logs de fallback
    $AllLogs = Get-ChildItem -Path $FallbackLogDir -Filter "*.log" -ErrorAction SilentlyContinue
    $FallbackWarnings = 0
    foreach ($Log in $AllLogs) {
        $FallbackWarnings += (Select-String -Path $Log.FullName -Pattern "Log de red inaccesible").Count
    }
    Write-Host "`n=== Test 5 - Verificación de fallback de log ===" -ForegroundColor Cyan
    $Expected5 = 5
    $Test5Pass = ($FallbackWarnings -eq $Expected5)
    Write-Host "Advertencias de fallback encontradas: $FallbackWarnings (esperado: $Expected5)" -ForegroundColor $(if ($Test5Pass) {"Green"} else {"Red"})

    $script:Results += [PSCustomObject]@{
        Test              = "Test 5 - Persistencia de warning de fallback"
        ExpectedExitCode  = "N/A"
        ActualExitCode    = "N/A"
        LogPatternMatched = $Test5Pass
        Result            = if ($Test5Pass) { "PASS" } else { "FAIL" }
    }

    # Test 6: bug histórico de propagación de errores en BIOS (standalone, sin wrapper)
    # Referencia de regresión: confirma que Set-LenovoBiosBaseline.MockBuggy.ps1 (con
    # catch que traga errores) sigue reproduciendo el bug original si se ejecuta fuera
    # del wrapper. El wrapper por sí solo enmascaraba este bug al heredar su propio
    # $ErrorActionPreference='Stop' — este test prueba el script en aislamiento real.
    Write-Host "`n=== Ejecutando: Test 6 - Bug histórico BIOS (referencia, standalone) ===" -ForegroundColor Cyan
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test6-bios-buggy-standalone.ps1") | Out-Null
    $Test6ExitCode = $LASTEXITCODE
    $Test6Pass = ($Test6ExitCode -eq 0)
    Write-Host "Exit code: $Test6ExitCode (se espera 0 - confirma que el mock buggy reproduce el problema histórico)" -ForegroundColor $(if ($Test6Pass) {"Yellow"} else {"Red"})
    $script:Results += [PSCustomObject]@{
        Test              = "Test 6 - Bug histórico BIOS (referencia)"
        ExpectedExitCode  = 0
        ActualExitCode    = $Test6ExitCode
        LogPatternMatched = "N/A"
        Result            = if ($Test6Pass) { "PASS" } else { "FAIL" }
    }

    # Test 7: script de BIOS con el fix real, standalone (sin wrapper)
    # Confirma que sin catch + con $ErrorActionPreference='Stop' propio, el script
    # aborta correctamente incluso invocado fuera del wrapper.
    Write-Host "`n=== Ejecutando: Test 7 - Propagación correcta BIOS (fix real, standalone) ===" -ForegroundColor Cyan
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test7-bios-fixed-standalone.ps1") | Out-Null
    $Test7ExitCode = $LASTEXITCODE
    $Test7Pass = ($Test7ExitCode -eq 1)
    Write-Host "Exit code: $Test7ExitCode (esperado: 1)" -ForegroundColor $(if ($Test7Pass) {"Green"} else {"Red"})
    $script:Results += [PSCustomObject]@{
        Test              = "Test 7 - Fix BIOS standalone"
        ExpectedExitCode  = 1
        ActualExitCode    = $Test7ExitCode
        LogPatternMatched = "N/A"
        Result            = if ($Test7Pass) { "PASS" } else { "FAIL" }
    }

    # Test 8: Enable-WindowsOptionalFeatures.ps1 captura $LASTEXITCODE de DISM
    # Antes, ninguna de las 6 llamadas a dism.exe revisaba el exit code; un
    # fallo real (ej. 0x800f081f, documentado en runbook 14.2) dejaba pasar
    # el script como "completado exitosamente" sin que nadie se enterara.
    Write-Host "`n=== Ejecutando: Test 8 - Enable-WindowsOptionalFeatures captura LASTEXITCODE ===" -ForegroundColor Cyan
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test8-features-exitcode.ps1") | Out-Null
    $Test8ExitCode = $LASTEXITCODE
    $Test8Pass = ($Test8ExitCode -ne 0)
    Write-Host "Exit code: $Test8ExitCode (se espera distinto de 0 - DISM simulado falla en Paso 2)" -ForegroundColor $(if ($Test8Pass) {"Green"} else {"Red"})
    $script:Results += [PSCustomObject]@{
        Test              = "Test 8 - Features DISM exit code"
        ExpectedExitCode  = "≠0"
        ActualExitCode    = $Test8ExitCode
        LogPatternMatched = "N/A"
        Result            = if ($Test8Pass) { "PASS" } else { "FAIL" }
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

Write-Host "`n=== RESUMEN DE PRUEBAS ===" -ForegroundColor Cyan
$Results | Format-Table -AutoSize

$FailCount = ($Results | Where-Object { $_.Result -eq "FAIL" }).Count
if ($FailCount -gt 0) {
    Write-Host "$FailCount test(s) fallaron." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Todos los tests pasaron exitosamente." -ForegroundColor Green
    exit 0
}
