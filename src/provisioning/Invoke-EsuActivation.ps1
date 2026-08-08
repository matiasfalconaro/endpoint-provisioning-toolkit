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
    [Parameter(Mandatory = $false)]
    [string]$EsuProductKey
)

function Invoke-EsuLicenseActivation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$')]
        [string]$EsuProductKey
    )

    $ErrorActionPreference = 'Stop'

    try {
        # Verificar que el servicio existe antes de intentar invocarlo
        $LicensingService = Get-CimInstance -ClassName "SoftwareLicensingService" -ErrorAction Stop
        if ($null -eq $LicensingService) {
            throw "No se pudo acceder al servicio CIM SoftwareLicensingService."
        }

        Write-Output "Inyectando clave de producto ESU..."
        $InstallResult = Invoke-CimMethod -ClassName "SoftwareLicensingService" `
            -MethodName "InstallProductKey" `
            -Arguments @{ ProductKey = $EsuProductKey }

        if ($null -eq $InstallResult -or $InstallResult.ReturnValue -ne 0) {
            throw "Falla al instalar la clave de producto ESU. ReturnValue: $($InstallResult.ReturnValue)"
        }

        Write-Output "Forzando activacion en linea de la licencia ESU..."
        $EsuProducts = Get-CimInstance -ClassName "SoftwareLicensingProduct" |
            Where-Object {
                $_.PartialProductKey -and
                $_.ApplicationId -eq "55c92734-d682-4d71-983e-d6ec3f16059f" -and
                $_.LicenseIsAddon -eq $true
            }

        $EsuProduct = if ($EsuProducts) { $EsuProducts[0] } else { $null }

        if ($null -ne $EsuProduct) {
            $ActivateResult = Invoke-CimMethod -InputObject $EsuProduct -MethodName "Activate"
            if ($ActivateResult.ReturnValue -ne 0) {
                throw "Falla al activar el producto ESU. ReturnValue: $($ActivateResult.ReturnValue)"
            }
        } else {
            throw "No se encontro el producto ESU en SoftwareLicensingProduct tras la inyeccion de clave."
        }

        $ActivatedProduct = Get-CimInstance -ClassName "SoftwareLicensingProduct" |
            Where-Object { $_.LicenseStatus -eq 1 -and $_.PartialProductKey }

        if ($null -eq $ActivatedProduct) {
            throw "Error de Validacion ESU: LicenseStatus = 1 no reportado tras la inyeccion."
        }

        Write-Output "Licencia ESU inyectada y activada exitosamente. Estado: Licensed (1)."

    } catch {
        throw "ERROR CRITICO EN ACTIVACION ESU: $_"
    }
}

# Guarda de invocacion
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript' -and
    $MyInvocation.InvocationName -notlike '*BeforeAll*' -and
    -not ($MyInvocation.Line -match '^\s*\.')) {
    Invoke-EsuLicenseActivation -EsuProductKey $EsuProductKey
}
