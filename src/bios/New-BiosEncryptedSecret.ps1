[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Ingrese la contraseña de Supervisor de BIOS a cifrar")]
    [System.Security.SecureString]$BiosPassword,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\BiosSecret.key"
)

try {
    # Convierte el SecureString a un hash cifrado por DPAPI (usuario/equipo actual)
    $EncryptedSecret = $BiosPassword | ConvertFrom-SecureString
    Set-Content -Path $OutputPath -Value $EncryptedSecret -Force
    Write-Host "Secreto cifrado generado exitosamente en: $OutputPath" -ForegroundColor Green
} catch {
    Write-Error "Falla al generar el archivo de secreto cifrado: $_"
}
