<#
.SYNOPSIS
    Aplica la Baseline de BIOS mediante el módulo oficial ThinkBios-Config.
.DESCRIPTION
    Consume un archivo de configuración cifrado (.ini/.xml) generado por Lenovo Settings Encrypter
    e invoca el módulo oficial sin exponer variables en memoria.
.PARAMETER ConfigFile
    Ruta oficial al archivo de configuración de BIOS cifrado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "\\NAS-CORP01\Deployment\Baselines\ThinkPad_T14_Baseline_Encrypted.ini"
)

try {
    if (-not (Test-Path $ConfigFile)) {
        throw "No se encontró el archivo de baseline de BIOS en: $ConfigFile"
    }

    # Importación del módulo oficial de Lenovo si no está presente
    if (-not (Get-Module -Name "ThinkBios-Config")) {
        Import-Module ThinkBios-Config -ErrorAction Stop
    }

    Write-Host "Aplicando baseline de BIOS cifrada con ThinkBios-Config: $ConfigFile..." -ForegroundColor Cyan

    # Aplicación declarativa oficial de Lenovo
    Set-ThinkBiosConfig -ConfigFile $ConfigFile -ErrorAction Stop

    Write-Host "Configuración de BIOS con ThinkBios-Config aplicada exitosamente." -ForegroundColor Green
}
catch {
    Write-Error "Error crítico al aplicar la configuración con ThinkBios-Config: $_"
}
