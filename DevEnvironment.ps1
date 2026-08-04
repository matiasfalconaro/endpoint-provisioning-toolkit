<#
.SYNOPSIS
    Bootstrap-DevEnvironment.ps1 - Prepara y configura el entorno dev completo.
.PARAMETER GitUserName
.PARAMETER GitUserEmail
    Sin defaults: cada desarrollador debe pasar los suyos explicitamente,
    o usar -SkipGitConfig si ya tiene su Git configurado globalmente.
.PARAMETER InstallGitHubCli
    Instala GitHub CLI (gh) via winget si no esta presente. Opt-in, no
    forma parte del set minimo requerido por la suite de tests.
#>
[CmdletBinding()]
param(
    [switch]$SkipGitConfig,
    [string]$GitUserName,
    [string]$GitUserEmail,
    [switch]$InstallGitHubCli
)

$ErrorActionPreference = "Stop"

Write-Host "Endpoint Provisioning Toolkit - Bootstrap de Entorno Dev" -ForegroundColor Cyan

Write-Host "[1/5] Verificando ExecutionPolicy..." -ForegroundColor Yellow
if ((Get-ExecutionPolicy -Scope CurrentUser) -notin @('RemoteSigned', 'Unrestricted', 'Bypass')) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host " [OK] ExecutionPolicy configurado en RemoteSigned." -ForegroundColor Green
} else {
    Write-Host " [OK] ExecutionPolicy ya permite ejecucion de scripts." -ForegroundColor Green
}

Write-Host "[2/5] Preparando gestores de paquetes (NuGet y PSDepend)..." -ForegroundColor Yellow
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}
if (-not (Get-Module -ListAvailable -Name PSDepend)) {
    Install-Module -Name PSDepend -Scope CurrentUser -Force -SkipPublisherCheck
}
Write-Host " [OK] Gestores de paquetes listos." -ForegroundColor Green

Write-Host "[3/5] Instalando modulos de PowerShell (via PSDepend)..." -ForegroundColor Yellow
$RequirementsPath = Join-Path $PSScriptRoot "requirements.psd1"
if (Test-Path $RequirementsPath) {
    Invoke-PSDepend -Path $RequirementsPath -Install -Force

    $Expected = @('PSScriptAnalyzer', 'Pester', 'PSSQLite')
    $Missing = $Expected | Where-Object { -not (Get-Module -ListAvailable -Name $_) }
    if ($Missing) {
        throw "PSDepend no instalo correctamente: $($Missing -join ', '). Revisar $RequirementsPath."
    }
    Write-Host " [OK] Dependencias instaladas y verificadas: $($Expected -join ', ')." -ForegroundColor Green
} else {
    Write-Warning "No se encontro requirements.psd1 en $PSScriptRoot."
}

if ($InstallGitHubCli) {
    Write-Host "[4/5] Verificando GitHub CLI..." -ForegroundColor Yellow
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
            Write-Host " [OK] GitHub CLI instalado." -ForegroundColor Green
        } else {
            Write-Warning "winget no disponible - instalar GitHub CLI manualmente: https://cli.github.com/"
        }
    } else {
        Write-Host " [OK] GitHub CLI ya instalado." -ForegroundColor Green
    }

    $AuthStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ACCION REQUERIDA: GitHub CLI no esta autenticado. Ejecuta: gh auth login" -ForegroundColor Yellow
    }
} else {
    Write-Host "[4/5] GitHub CLI omitido (usar -InstallGitHubCli para instalarlo)." -ForegroundColor DarkGray
}

Write-Host "[5/5] Configurando Git y directorios de trabajo..." -ForegroundColor Yellow
if (-not $SkipGitConfig -and (Get-Command git -ErrorAction SilentlyContinue)) {
    if (-not $GitUserName -or -not $GitUserEmail) {
        Write-Warning "Sin -GitUserName/-GitUserEmail, se omite la configuracion de Git. Usa -SkipGitConfig para silenciar este aviso."
    } else {
        git config --global user.name "$GitUserName"
        git config --global user.email "$GitUserEmail"
        Write-Host " [OK] Git configurado para $GitUserName ($GitUserEmail)." -ForegroundColor Green
    }
}

$Dirs = @(".\test-drivers\logs", "C:\Windows\Temp\DeploymentLogs")
foreach ($Dir in $Dirs) {
    if (-not (Test-Path $Dir)) { New-Item -Path $Dir -ItemType Directory -Force | Out-Null }
}

$DbModulePath = ".\test-drivers\TestResultsDb.psm1"
$DbFilePath   = ".\test-drivers\logs\dev-test-logs.db"
if (Test-Path $DbModulePath) {
    Import-Module $DbModulePath -Force
    if (Get-Command Initialize-TestResultsDb -ErrorAction SilentlyContinue) {
        Initialize-TestResultsDb -DatabasePath $DbFilePath
        Write-Host " [OK] Base de datos SQLite inicializada en $DbFilePath" -ForegroundColor Green
    } else {
        Write-Warning "Initialize-TestResultsDb no encontrada en $DbModulePath - revisar TestResultsDb.psm1"
    }
} else {
    Write-Warning "$DbModulePath no encontrado - estas corriendo esto desde la raiz del repo?"
}

try {
    Import-Module PSSQLite -ErrorAction Stop
    Write-Host " [OK] PSSQLite carga correctamente." -ForegroundColor Green
} catch {
    Write-Warning "PSSQLite instalado pero no carga: $($_.Exception.Message)"
}

Write-Host "`nEntorno preparado con exito" -ForegroundColor Cyan
