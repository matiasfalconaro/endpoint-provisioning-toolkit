[CmdletBinding()]
param(
    # Parámetro opcional para la ruta de fuentes Side-by-Side (SxS) de .NET 3.5
    [Parameter(Mandatory = $false)]
    [string]$SxSPath = "C:\Sources\sxs"
)

# 1. Habilitación de .NET Framework 4.8 y Servicios de Impresión PDF
Enable-WindowsOptionalFeature -Online -FeatureName "NetFx4-AdvSvc" -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName "Printing-PrintToPDFServices" -NoRestart

# 2. Hardening: Deshabilitación explícita de protocolos y runtimes inseguros
Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2" -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features" -NoRestart

# 3. Procedimiento Especial: Instalación bajo demanda de .NET 3.5 vía Repositorio Local (SxS)
if (Test-Path $SxSPath) {
    # Instalación Offline utilizando el repositorio local o de red especificado
    dism.exe /online /enable-feature /featurename:NetFx3 /All /Source:$SxSPath /LimitAccess
} else {
    Write-Warning "No se encontró la ruta SxS en '$SxSPath'. .NET 3.5 se mantendrá deshabilitado por seguridad."
}
