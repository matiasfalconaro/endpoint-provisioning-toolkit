<#
.SYNOPSIS
    Aplica la Baseline de BIOS mediante el mÃ³dulo oficial ThinkBios-Config.
.DESCRIPTION
    Consume un archivo de configuraciÃ³n cifrado (.ini/.xml) generado por Lenovo
    Settings Encrypter e invoca el mÃ³dulo oficial sin exponer variables en memoria.
.PARAMETER ConfigFile
    Ruta oficial al archivo de configuraciÃ³n de BIOS cifrado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "\\NAS-CORP01\Deployment\Baselines\ThinkPad_T14_Baseline_Encrypted.ini"
)

function Invoke-ThinkBiosConfig {
    [CmdletBinding()]
    param([string]$ConfigFile)

    $ErrorActionPreference = 'Stop'

    try {
        if (-not (Test-Path $ConfigFile)) {
            throw "No se encontro el archivo de baseline de BIOS en: $ConfigFile"
        }

        if (-not (Get-Module -Name "ThinkBios-Config")) {
            Import-Module ThinkBios-Config -ErrorAction Stop
        }

        Write-Host "Aplicando baseline de BIOS cifrada con ThinkBios-Config: $ConfigFile..." -ForegroundColor Cyan
        Set-ThinkBiosConfig -ConfigFile $ConfigFile -ErrorAction Stop
        Write-Host "Configuracion de BIOS con ThinkBios-Config aplicada exitosamente." -ForegroundColor Green

    } catch {
        # Re-throw sin catch silencioso: el error debe propagarse al wrapper.
        throw "Error critico al aplicar la configuracion con ThinkBios-Config: $_"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ThinkBiosConfig -ConfigFile $ConfigFile
}
