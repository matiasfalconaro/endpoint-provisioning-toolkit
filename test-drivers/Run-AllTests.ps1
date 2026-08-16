<#
.SYNOPSIS
    Orquesta la batería completa de pruebas locales para Invoke-DeploymentTask.ps1,
    Confirm-ScriptIntegrity.ps1, scripts hardware/BIOS y la suite de unit tests con Pester.
.DESCRIPTION
    1. (Opcional, vía -FixEncoding) Normaliza recursivamente los archivos .ps1 en
       src/ a UTF-8 con BOM para PowerShell 5.1.
    2. Ejecuta PSScriptAnalyzer sobre la carpeta src/ para verificar calidad de código.
    3. Ejecuta los unit tests con Pester + Mock para los scripts de seguridad y hardware
       ubicados en test-drivers/unit-tests/.
    4. Ejecuta los escenarios de integracion ubicados en test-drivers/scenarios/ (Test 0 a Test 12)
       como procesos hijos aislados.
    5. Compara exit code y logs, restaura manifest.json y muestra un resumen general PASS/FAIL.
.PARAMETER RepoRoot
    Raíz del repositorio. Si se omite, se resuelve automáticamente en base a
    la ubicación de este script.
.PARAMETER FixEncoding
    Si se especifica, normaliza todos los .ps1 de src/ a UTF-8 con BOM antes
    de correr los tests.
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
    [switch]$FixEncoding,

    [Parameter(Mandatory = $false)]
    [string[]]$EncodingTargetPath,

    [Parameter(Mandatory = $false)]
    [switch]$EncodingOnly,

    [Parameter(Mandatory = $false)]
    [string]$UnitTestPath,

    [Parameter(Mandatory = $false)]
    [switch]$SkipScenarios
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
$ScenariosPath = Join-Path $PSScriptRoot "scenarios"
$Results = @()

if ($FixEncoding) {
    Write-Host "=== Etapa Previa 1: Verificando/Aplicando UTF-8 con BOM en scripts y tests ===" -ForegroundColor Cyan

    if ($EncodingTargetPath) {
        $FilesToFix = foreach ($target in $EncodingTargetPath) {
            $ResolvedTarget = Resolve-Path $target -ErrorAction Stop
            if ((Get-Item $ResolvedTarget).PSIsContainer) {
                Get-ChildItem -Path $ResolvedTarget -Recurse -Filter *.ps1
            } else {
                Get-Item $ResolvedTarget
            }
        }
    } else {
        $TestDriversPath = Join-Path $RepoRoot "test-drivers"
        $TargetFolders = @($SrcPath, $TestDriversPath) | Where-Object { $_ -and (Test-Path $_) }
        $FilesToFix = $TargetFolders | ForEach-Object { Get-ChildItem -Path $_ -Recurse -Filter *.ps1 }
    }

    foreach ($file in $FilesToFix) {
        $filePath = $file.FullName
        $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($filePath, $content, [System.Text.UTF8Encoding]::new($true))
        Write-Host "  Corregido: $filePath" -ForegroundColor DarkGray
    }
    Write-Host "Codificación UTF-8 BOM normalizada ($($FilesToFix.Count) archivo(s))." -ForegroundColor Green

    if ($EncodingOnly) {
        Write-Host "`n-EncodingOnly especificado: se omite el resto de la batería de pruebas." -ForegroundColor DarkGray
        exit 0
    }
} else {
    Write-Host "=== Etapa Previa 1: Normalización de encoding OMITIDA (usar -FixEncoding para aplicarla) ===" -ForegroundColor DarkGray
}

# ETAPA PREVIA 2: AUDITORÍA DE LINTER
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

# ETAPA PREVIA 3: UNIT TESTS DE SEGURIDAD Y HARDWARE (PESTER MOCK)
Write-Host "`n=== Etapa Previa 3: Unit tests (Pester Mock) de scripts de seguridad ===" -ForegroundColor Cyan
$UnitTestsPath = Join-Path $PSScriptRoot "unit-tests"

if ($UnitTestPath) {
    $PesterTargetPath = (Resolve-Path $UnitTestPath -ErrorAction Stop).ProviderPath
} elseif (Test-Path $UnitTestsPath) {
    $PesterTargetPath = $UnitTestsPath
} else {
    $PesterTargetPath = $null
}

if ($PesterTargetPath) {
    if (Get-Module -ListAvailable -Name Pester) {
        Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

        if (-not (Test-Path $FallbackLogDir)) {
            New-Item -Path $FallbackLogDir -ItemType Directory -Force | Out-Null
        }
        $PesterLogPath = Join-Path $FallbackLogDir "RAWOUTPUT_Pester_UnitTests.log"

        $PesterConfig = [PesterConfiguration]::Default
        $PesterConfig.Run.Path = $PesterTargetPath
        $PesterConfig.Run.PassThru = $true
        $PesterConfig.Output.Verbosity = 'Detailed'
        $PesterConfig.TestResult.Enabled = $true
        $PesterConfig.TestResult.OutputPath = Join-Path $PSScriptRoot "logs\pester-results.xml"
        $PesterConfig.TestResult.OutputFormat = 'NUnitXml'

        $PesterResult = Invoke-Pester -Configuration $PesterConfig

        $PesterFailedCount = if ($null -ne $PesterResult.FailedCount) { $PesterResult.FailedCount } else { 0 }
        $PesterTotalCount  = if ($null -ne $PesterResult.TotalCount)  { $PesterResult.TotalCount }  else { 0 }
        $PesterPassed      = ($PesterFailedCount -eq 0)

        $script:Results += [PSCustomObject]@{
            Test              = "Unit tests seguridad (Pester)"
            ExpectedExitCode  = "0 fallidos"
            ActualExitCode    = "$PesterFailedCount fallidos de $PesterTotalCount"
            LogPatternMatched = "N/A"
            Result            = if ($PesterPassed) { "PASS" } else { "FAIL" }
        }

        if (-not $PesterPassed) {
            Write-Host "Se detectaron $($PesterResult.FailedCount) fallo(s) en las pruebas unitarias." -ForegroundColor Red
        }
    } else {
        Write-Host "[ADVERTENCIA] Modulo Pester no instalado. Omitiendo pruebas unitarias con Mocks." -ForegroundColor Yellow
        $script:Results += [PSCustomObject]@{
            Test              = "Unit tests seguridad (Pester)"
            ExpectedExitCode  = "N/A"
            ActualExitCode    = "Modulo no presente"
            LogPatternMatched = "N/A"
            Result            = "SKIPPED"
        }
    }
} else {
    Write-Host "No se encontro el directorio de unit tests en: $UnitTestsPath" -ForegroundColor DarkGray
    $script:Results += [PSCustomObject]@{
        Test              = "Unit tests seguridad (Pester)"
        ExpectedExitCode  = "N/A"
        ActualExitCode    = "Directorio no encontrado"
        LogPatternMatched = "N/A"
        Result            = "SKIPPED"
    }
}

# FUNCIÓN AUXILIAR DE PRUEBAS DE INTEGRACIÓN
function Invoke-TestDriver {
    param(
        [string]$Name,
        [string]$DriverScript,
        [int]$ExpectedExitCode,
        [string]$ExpectedLogPattern
    )

    Write-Host "`n=== Ejecutando: $Name ===" -ForegroundColor Cyan

    $DriverPath = Join-Path $ScenariosPath $DriverScript
    if (-not (Test-Path $DriverPath)) {
        throw "No se encontró el driver: $DriverPath"
    }

    # Se captura stdout del proceso hijo ademas de dejarlo pasar a consola
    $RawOutput = powershell -NoProfile -ExecutionPolicy Bypass -File $DriverPath 2>&1
    $RawOutput | ForEach-Object { Write-Host $_ }
    $ActualExitCode = $LASTEXITCODE

    # Prefijo RAWOUTPUT (en vez de una MAC real) para que Save-TestLogsToSqlite
    # reconozca este archivo como salida cruda de consola, no como log del
    # wrapper, y no infiera una MAC falsa a partir del nombre del test.
    $SafeName = $Name -replace '[^\w]', '_'
    $RawLogPath = Join-Path $FallbackLogDir "RAWOUTPUT_$($SafeName)_Execution.log"
    $RawOutput | Out-File -FilePath $RawLogPath -Encoding utf8

    $ExitCodeMatch = ($ActualExitCode -eq $ExpectedExitCode)

    $LogMatch = $true
    if ($ExpectedLogPattern) {
        $RecentLog = Get-ChildItem -Path $FallbackLogDir -Filter "*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike "RAWOUTPUT_*" } |
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

# BATERÍA DE PRUEBAS DE INTEGRACIÓN
if (-not $SkipScenarios) {
    try {
        # Precondicion: respaldo del manifiesto real
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
        Invoke-TestDriver -Name "Test 0 - Skipping Security Checks (uso exclusivo para debugging)" `
            -DriverScript "test0-skipping_security_checks.ps1" `
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
        Copy-Item $ManifestBackupPath $ManifestPath -Force

        # Test 4: proceso externo falla
        Invoke-TestDriver -Name "Test 4 - Fallo de proceso externo" `
            -DriverScript "test4-externalfail.ps1" `
            -ExpectedExitCode 1 `
            -ExpectedLogPattern "código de salida 87"

        # Test 5: persistencia de logs de fallback
        $AllLogs = Get-ChildItem -Path $FallbackLogDir -Filter "*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike "RAWOUTPUT_*" }
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

        # Test 6: bug histórico de propagación de errores en BIOS
        Write-Host "`n=== Ejecutando: Test 6 - Bug histórico BIOS (referencia, standalone) ===" -ForegroundColor Cyan
        powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:ALLOW_HAZARDOUS_TESTS='true'; & '$ScenariosPath\test6-bios-buggy-standalone.ps1'" | Out-Null
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

        # Test 7: script de BIOS con el fix real, standalone
        Write-Host "`n=== Ejecutando: Test 7 - Propagación correcta BIOS (fix real, standalone) ===" -ForegroundColor Cyan
        powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:ALLOW_HAZARDOUS_TESTS='true'; & '$ScenariosPath\test7-bios-fixed-standalone.ps1'" | Out-Null
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
        Write-Host "`n=== Ejecutando: Test 8 - Enable-WindowsOptionalFeatures captura LASTEXITCODE ===" -ForegroundColor Cyan
        powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:ALLOW_HAZARDOUS_TESTS='true'; & '$ScenariosPath\test8-features-exitcode.ps1'" | Out-Null
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

        # Test 9: workflows de BIOS - propagacion de errores ante rutas inexistentes
        Write-Host "`n=== Ejecutando: Test 9 - Workflows BIOS propagacion de errores ===" -ForegroundColor Cyan
        powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:ALLOW_HAZARDOUS_TESTS='true'; & '$ScenariosPath\test9-bios-workflows-standalone.ps1'" | Out-Null
        $Test9ExitCode = $LASTEXITCODE
        $Test9Pass = ($Test9ExitCode -eq 0)
        Write-Host "Exit code: $Test9ExitCode (esperado: 0)" -ForegroundColor $(if ($Test9Pass) {"Green"} else {"Red"})
        $script:Results += [PSCustomObject]@{
            Test              = "Test 9 - Workflows BIOS propagacion de errores"
            ExpectedExitCode  = 0
            ActualExitCode    = $Test9ExitCode
            LogPatternMatched = "N/A"
            Result            = if ($Test9Pass) { "PASS" } else { "FAIL" }
        }

        # Test 10: Get-PerformanceHealthStatus - excepcion terminante real de CIM/WMI
        Write-Host "`n=== Ejecutando: Test 10 - Performance excepcion CIM terminante ===" -ForegroundColor Cyan
        powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:ALLOW_HAZARDOUS_TESTS='true'; & '$ScenariosPath\test10-performance-cimfail.ps1'" | Out-Null
        $Test10ExitCode = $LASTEXITCODE
        $Test10Pass = ($Test10ExitCode -eq 0)
        Write-Host "Exit code: $Test10ExitCode (se espera 0 - el mock confirma que el script aborta ante la excepcion CIM)" -ForegroundColor $(if ($Test10Pass) {"Green"} else {"Red"})
        $script:Results += [PSCustomObject]@{
            Test              = "Test 10 - Performance excepcion CIM terminante"
            ExpectedExitCode  = 0
            ActualExitCode    = $Test10ExitCode
            LogPatternMatched = "N/A"
            Result            = if ($Test10Pass) { "PASS" } else { "FAIL" }
        }

        # Test 11: Validacion Estricta - integridad SHA-256 y firma Authenticode reales
        Write-Host "`n=== Ejecutando: Test 11 - Validacion Estricta (SHA-256 + Authenticode reales) ===" -ForegroundColor Cyan
        powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:ALLOW_HAZARDOUS_TESTS='true'; & '$ScenariosPath\test11-strict_validation.ps1'" | Out-Null
        $Test11ExitCode = $LASTEXITCODE
        $Test11Pass = ($Test11ExitCode -eq 0)
        Write-Host "Exit code: $Test11ExitCode (esperado: 0)" -ForegroundColor $(if ($Test11Pass) {"Green"} else {"Red"})
        $script:Results += [PSCustomObject]@{
            Test              = "Test 11 - Validacion Estricta (SHA-256 + Authenticode)"
            ExpectedExitCode  = 0
            ActualExitCode    = $Test11ExitCode
            LogPatternMatched = "N/A"
            Result            = if ($Test11Pass) { "PASS" } else { "FAIL" }
        }

        # Test 12: Drive Wipe NIST SP 800-88 Rev. 1 - Validacion de metodos Purge/Clear
        Write-Host "`n=== Ejecutando: Test 12 - Drive Wipe NIST SP 800-88 Rev. 1 ===" -ForegroundColor Cyan
        powershell -NoProfile -ExecutionPolicy Bypass -Command "`$env:ALLOW_HAZARDOUS_TESTS='true'; & '$ScenariosPath\test12-drivewipe-nist.ps1'" | Out-Null
        $Test12ExitCode = $LASTEXITCODE
        $Test12Pass = ($Test12ExitCode -eq 0)
        Write-Host "Exit code: $Test12ExitCode (se espera 0 - confirma la correcta evaluacion de metodos NIST)" -ForegroundColor $(if ($Test12Pass) {"Green"} else {"Red"})
        $script:Results += [PSCustomObject]@{
            Test              = "Test 12 - Drive Wipe NIST SP 800-88 Rev. 1"
            ExpectedExitCode  = 0
            ActualExitCode    = $Test12ExitCode
            LogPatternMatched = "N/A"
            Result            = if ($Test12Pass) { "PASS" } else { "FAIL" }
        }

    } finally {
        # Restauracion garantizada del manifiesto real
        if (Test-Path $ManifestBackupPath) {
            Copy-Item $ManifestBackupPath $ManifestPath -Force
            Remove-Item $ManifestBackupPath -Force
            Write-Host "`nmanifest.json restaurado a su estado original." -ForegroundColor Gray
        }

        # Persistencia de logs de esta corrida
        if (Test-Path $FallbackLogDir) {
            $LogDirTarget = Join-Path $PSScriptRoot "logs"
            if (-not (Test-Path $LogDirTarget)) {
                New-Item -Path $LogDirTarget -ItemType Directory -Force | Out-Null
            }

            $DatabasePath = Join-Path $LogDirTarget "dev-test-logs.db"
            $RunId = Get-Date -Format "yyyyMMdd_HHmmss"

            $Persisted = $false
            try {
                Import-Module (Join-Path $PSScriptRoot "TestResultsDb.psm1") -ErrorAction Stop
                $Persisted = Save-TestLogsToSqlite -LogDir $FallbackLogDir -DatabasePath $DatabasePath -RunId $RunId
            } catch {
                Write-Warning "No se pudo persistir a SQLite ($($_.Exception.Message)). Se conserva el archivado por carpeta."
            }

            if ($Persisted) {
                Write-Host "Logs consolidados en: $DatabasePath (RunId: $RunId)" -ForegroundColor Gray
                Remove-Item "$FallbackLogDir\*.log" -Force -ErrorAction SilentlyContinue
            } else {
                $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $ArchiveDir = Join-Path $PSScriptRoot "logs_$Timestamp"
                New-Item -Path $ArchiveDir -ItemType Directory -Force | Out-Null
                Copy-Item "$FallbackLogDir\*.log" -Destination $ArchiveDir -Force -ErrorAction SilentlyContinue
                Remove-Item "$FallbackLogDir\*.log" -Force -ErrorAction SilentlyContinue
                Write-Host "Logs de esta corrida archivados en: $ArchiveDir" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "`n-SkipScenarios especificado: se omite la batería de pruebas de integración (Test 0-12)." -ForegroundColor DarkGray
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
