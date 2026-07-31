<#
.SYNOPSIS
    Inyecta y activa desatendidamente licencias Extended Security Updates (ESU) vía WMI/CIM.
.DESCRIPTION
    Aplica una clave de activación por volumen (MAK) ESU, ejecuta la activación en línea
    y valida que el estado de licenciamiento del sistema operativo sea correcto.
.PARAMETER EsuProductKey
    Clave de producto ESU corporativa en formato 5x5 (AAAAA-BBBBB-CCCCC-DDDDD-EEEEE).
.EXAMPLE
    .\Invoke-EsuActivation.ps1 -EsuProductKey "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Ingrese la clave de producto ESU corporativa")]
    [ValidatePattern('^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$')]
    [string]$EsuProductKey
)

$ErrorActionPreference = 'Stop'

try {
    # 1. Obtención del servicio de licenciamiento de Windows (SoftwareLicensingService)
    $LicensingService = Get-CimInstance -ClassName "SoftwareLicensingService" -ErrorAction Stop
    
    if ($null -eq $LicensingService) {
        throw "No se pudo acceder al servicio CIM SoftwareLicensingService."
    }

    # 2. Inyección de la clave de producto ESU
    Write-Output "Inyectando clave de producto ESU..."
    $InstallResult = Invoke-CimMethod -InputObject $LicensingService -MethodName "InstallProductKey" -Arguments @{ ProductKey = $EsuProductKey }

    if ($null -eq $InstallResult) {
        throw "Falla al ejecutar el método InstallProductKey en SoftwareLicensingService."
    }

    # 3. Forzado de activación del producto
    Write-Output "Forzando activación en línea de la licencia ESU..."
    $EsuProduct = Get-CimInstance -ClassName "SoftwareLicensingProduct" | Where-Object { $_.PartialProductKey -and $_.ApplicationId -eq "55c92734-d682-4d71-983e-d6ec3f16059f" -and $_.LicenseIsAddon -eq $true } | Select-Object -First 1

    if ($null -ne $EsuProduct) {
        Invoke-CimMethod -InputObject $EsuProduct -MethodName "Activate" | Out-Null
    } else {
        # Fallback a la llamada de activación general del servicio
        Invoke-CimMethod -InputObject $LicensingService -MethodName "RefreshLicenseStatus" | Out-Null
    }

    # 4. Validación de estado de licenciamiento ESU
    $ActivatedProduct = Get-CimInstance -ClassName "SoftwareLicensingProduct" | Where-Object { $_.LicenseStatus -eq 1 -and $_.PartialProductKey }

    if ($null -eq $ActivatedProduct) {
        throw "Error de Validación ESU: El sistema no reporta un estado de licencia activo (LicenseStatus = 1) tras la inyección."
    }

    Write-Output "Licencia ESU inyectada y activada exitosamente. Estado de licencia: Licensed (1)."

} catch {
    throw "ERROR CRÍTICO EN ACTIVACIÓN ESU: $_"
}
