<#
.SYNOPSIS
    Inyección de Características Opcionales de Windows (Offline Image Servicing).
.DESCRIPTION
    Habilita .NET 4.8, Print-to-PDF y .NET 3.5 (vía SxS Server-Side) y remueve SMBv1, 
    PowerShell v2 y XPS en la imagen offline durante la Task Sequence.
.PARAMETER TargetDrive
    Unidad o ruta del volumen offline del SO
.PARAMETER SxSPath
    Ruta de red o local al directorio de fuentes Side-by-Side (.NET 3.5).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetDrive = "C:\",

    [Parameter(Mandatory = $false)]
    [string]$SxSPath = "\\NAS-CORP01\Deployment\sources\sxs"
)

$ErrorActionPreference = 'Stop'

function Invoke-DismStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host "Ejecutando: $Description..." -ForegroundColor Cyan
    & dism.exe @Arguments
    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0 -and $ExitCode -ne 3010) {
        throw "Fallo en DISM durante '$Description'. Código de salida: $ExitCode (Args: $($Arguments -join ' '))"
    }

    if ($ExitCode -eq 3010) {
        Write-Warning "'$Description' completado, pero requiere reinicio (código 3010)."
    }
}

Write-Host "Iniciando Servicing Offline de características opcionales en $TargetDrive..." -ForegroundColor Cyan

# Habilitar .NET Framework 4.8 Advanced Services
Invoke-DismStep -Description "Habilitar .NET Framework 4.8 Advanced Services" -Arguments @(
    "/Image:$TargetDrive", "/Enable-Feature", "/FeatureName:NetFx4-AdvSvc", "/All", "/NoRestart"
)

# Habilitar Impresión en PDF de Microsoft
Invoke-DismStep -Description "Habilitar Print-to-PDF" -Arguments @(
    "/Image:$TargetDrive", "/Enable-Feature", "/FeatureName:Printing-PrintToPDFServices-Features", "/NoRestart"
)

# Deshabilitar SMBv1 (Cierre de vulnerabilidades / EternalBlue)
Invoke-DismStep -Description "Deshabilitar SMBv1" -Arguments @(
    "/Image:$TargetDrive", "/Disable-Feature", "/FeatureName:SMB1Protocol", "/NoRestart"
)

# Deshabilitar PowerShell 2.0 (Prevención de bypass de seguridad)
Invoke-DismStep -Description "Deshabilitar PowerShell 2.0" -Arguments @(
    "/Image:$TargetDrive", "/Disable-Feature", "/FeatureName:MicrosoftWindowsPowerShellv2Root", "/NoRestart"
)

# Deshabilitar Escritor XPS
Invoke-DismStep -Description "Deshabilitar XPS Writer" -Arguments @(
    "/Image:$TargetDrive", "/Disable-Feature", "/FeatureName:Printing-XPSServices-Features", "/NoRestart"
)

# Instalación bajo demanda de .NET 3.5 desde el Servidor de Despliegue (SxS)
if (Test-Path $SxSPath) {
    Invoke-DismStep -Description "Instalar .NET 3.5 desde SxS" -Arguments @(
        "/Image:$TargetDrive", "/Enable-Feature", "/FeatureName:NetFx3", "/All",
        "/Source:$SxSPath", "/LimitAccess", "/NoRestart"
    )
} else {
    Write-Warning "No se encontró el repositorio SxS en '$SxSPath'. .NET 3.5 se mantendrá deshabilitado por seguridad."
}

Write-Host "Servicing Offline de características completado exitosamente." -ForegroundColor Green
