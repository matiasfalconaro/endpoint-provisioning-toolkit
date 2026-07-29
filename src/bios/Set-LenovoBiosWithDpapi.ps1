[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$KeyPath = ".\BiosSecret.key"
)

if (-not (Test-Path $KeyPath)) {
    throw "No se encontró el archivo de secreto cifrado en la ruta: $KeyPath"
}

# Lectura y conversión del secreto cifrado
$EncryptedSecret = Get-Content -Path $KeyPath | ConvertTo-SecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptedSecret)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    # Inyección de la contraseña en el microcontrolador vía CIM
    $Result = (Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SetBiosSetting).SetBiosSetting("SupervisorPassword,Set,$PlainPassword")
    if ($Result.return -ne "Success") {
        throw "No se pudo establecer la contraseña de Supervisor en la BIOS. Retorno WMI: $($Result.return)"
    }

    $SaveResult = (Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SaveBiosSettings).SaveBiosSettings()
    if ($SaveResult.return -ne "Success") {
        throw "Falla al persistir los cambios en la NVRAM/microcontrolador. Retorno WMI: $($SaveResult.return)"
    }

    Write-Host "Contraseña de BIOS inyectada exitosamente mediante DPAPI." -ForegroundColor Green
} finally {
    # Purga explícita del puntero en memoria
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    $PlainPassword = $null
    [System.GC]::Collect()
}
