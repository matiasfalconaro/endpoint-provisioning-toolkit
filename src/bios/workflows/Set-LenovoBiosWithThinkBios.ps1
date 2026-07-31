[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Ruta al archivo .ini o .bin cifrado por Lenovo Settings Encrypter")]
    [string]$ConfigFile
)

if (-not (Test-Path $ConfigFile)) {
    throw "No se encontró el archivo de configuración cifrado en: $ConfigFile"
}

# Importación del módulo oficial homologado de Lenovo
Import-Module ThinkBios-Config -ErrorAction Stop

# Baseline y Contraseña encriptada desde archivo empaquetado
Set-ThinkBiosSetConfig -ConfigFile $ConfigFile

# Validación del estado de ejecución
if ($?) {
    Write-Host "Baseline de BIOS y credencial de Supervisor aplicadas exitosamente mediante ThinkBios-Config." -ForegroundColor Green
} else {
    Write-Error "CRÍTICO: Falló la aplicación de la configuración de BIOS mediante ThinkBios-Config. Revisar logs."
}
