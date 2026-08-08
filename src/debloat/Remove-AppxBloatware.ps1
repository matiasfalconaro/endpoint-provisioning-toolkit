<#
.SYNOPSIS
    DepuraciÃ³n Server-Side de paquetes AppX provisionados (Image Servicing Offline).
.DESCRIPTION
    Remueve paquetes no corporativos directamente de la imagen de Windows montada/aplicada
    durante la fase WinPE de la Task Sequence.
.PARAMETER TargetDrive
    Unidad o ruta del volumen del sistema operativo offline o imagen montada.
    Nota: -Path en Remove-AppxProvisionedPackage opera sobre el volumen offline
    accedido desde WinPE. Para imÃ¡genes WIM montadas con DISM /Mount-Image,
    pasar la ruta de montaje en vez de la letra de unidad.
#>

function Invoke-AppxBloatwareRemoval {
    [CmdletBinding()]
    param(
        [string]$TargetDrive = "C:\"
    )

    $ErrorActionPreference = 'Stop'

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

    Write-Host "Iniciando depuracion offline de AppX en $TargetDrive..." -ForegroundColor Cyan

    $ProvisionedApps = Get-AppxProvisionedPackage -Path $TargetDrive | Where-Object {
        $_.DisplayName -match $RegexPattern -or $_.PackageName -match $RegexPattern
    }

    if (-not $ProvisionedApps -or $ProvisionedApps.Count -eq 0) {
        Write-Host "No se encontraron paquetes de bloatware provisionados en $TargetDrive." -ForegroundColor Green
        return
    }

    $Failed  = @()
    $Removed = @()

    foreach ($App in $ProvisionedApps) {
        $AppName = if ($App.DisplayName) { $App.DisplayName } else { $App.PackageName }

        try {
            Write-Host "Removiendo: $AppName" -ForegroundColor Yellow
            Remove-AppxProvisionedPackage -Path $TargetDrive -PackageName $App.PackageName -ErrorAction Stop | Out-Null
            $Removed += $AppName
        } catch {
            Write-Warning "No se pudo remover '$AppName': $($_.Exception.Message)"
            $Failed += $AppName
        }
    }

    $TotalCount = @($ProvisionedApps).Count
    Write-Host "Paquetes removidos exitosamente: $($Removed.Count)/$TotalCount" -ForegroundColor Green

    if ($Failed.Count -gt 0) {
        throw "Depuracion AppX parcialmente fallida: $($Failed.Count) paquete(s) no pudieron ser removidos: $($Failed -join ', ')"
    }

    Write-Host "Depuracion Offline de AppX completada en la imagen base." -ForegroundColor Green
}

# Guarda de invocacion
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-AppxBloatwareRemoval -TargetDrive $TargetDrive
}
