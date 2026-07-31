<#
.SYNOPSIS
    Depuración Server-Side de paquetes AppX provisionados (Image Servicing Offline).
.DESCRIPTION
    Remueve paquetes no corporativos directamente de la imagen de Windows montada/aplicada 
    durante la fase WinPE de la Task Sequence.
.PARAMETER TargetDrive
    Unidad o ruta del volumen del sistema operativo offline.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetDrive = "C:\"
)

# Patrón de bloatware definido por la Baseline
$BloatwareList = @(
    "Microsoft.ZuneVideo",
    "Microsoft.ZuneMusic",
    "Microsoft.GetHelp",
    "Microsoft.BingNews",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.GamingApp",
    "Microsoft.XboxApp"
)

$RegexPattern = ($BloatwareList -join '|')

Write-Host "Iniciando depuración offline de AppX en $TargetDrive..." -ForegroundColor Cyan

# Obtención y depuración OFFLINE sobre la imagen montada/aplicada (No -Online)
$ProvisionedApps = Get-AppxProvisionedPackage -Path $TargetDrive | Where-Object {
    $_.DisplayName -match $RegexPattern -or $_.PackageName -match $RegexPattern
}

foreach ($App in $ProvisionedApps) {
    $AppName = if ($App.DisplayName) { $App.DisplayName } else { $App.PackageName }
    Write-Host "Removiendo paquete provisionado de la imagen base offline: $AppName" -ForegroundColor Yellow
    
    Remove-AppxProvisionedPackage -Path $TargetDrive -PackageName $App.PackageName -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "Depuración Offline de AppX completada en la imagen base." -ForegroundColor Green
