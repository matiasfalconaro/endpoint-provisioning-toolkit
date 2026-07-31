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

Write-Host "Iniciando Servicing Offline de características opcionales en $TargetDrive..." -ForegroundColor Cyan

# 1. Habilitar .NET Framework 4.8 Advanced Services
dism.exe /Image:$TargetDrive /Enable-Feature /FeatureName:NetFx4-AdvSvc /All /NoRestart

# 2. Habilitar Impresión en PDF de Microsoft
dism.exe /Image:$TargetDrive /Enable-Feature /FeatureName:Printing-PrintToPDFServices-Features /NoRestart

# 3. Deshabilitar SMBv1 (Cierre de vulnerabilidades / EternalBlue)
dism.exe /Image:$TargetDrive /Disable-Feature /FeatureName:SMB1Protocol /NoRestart

# 4. Deshabilitar PowerShell 2.0 (Prevención de bypass de seguridad)
dism.exe /Image:$TargetDrive /Disable-Feature /FeatureName:MicrosoftWindowsPowerShellv2Root /NoRestart

# 5. Deshabilitar Escritor XPS
dism.exe /Image:$TargetDrive /Disable-Feature /FeatureName:Printing-XPSServices-Features /NoRestart

# 6. Instalación bajo demanda de .NET 3.5 desde el Servidor de Despliegue (SxS)
if (Test-Path $SxSPath) {
    Write-Host "Inyectando .NET 3.5 desde la fuente Server-Side: $SxSPath" -ForegroundColor Yellow
    dism.exe /Image:$TargetDrive /Enable-Feature /FeatureName:NetFx3 /All /Source:$SxSPath /LimitAccess /NoRestart
} else {
    Write-Warning "No se encontró el repositorio SxS en '$SxSPath'. .NET 3.5 se mantendrá deshabilitado por seguridad."
}

Write-Host "Servicing Offline de características completado exitosamente." -ForegroundColor Green
