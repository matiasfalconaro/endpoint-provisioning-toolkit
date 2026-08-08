<#
.SYNOPSIS
    Aplica la Baseline de BIOS de Lenovo utilizando un secreto cifrado por DPAPI.
.DESCRIPTION
    Desencripta la contraseÃ±a de BIOS en memoria efÃ­mera, la inyecta vÃ­a CIM/WMI
    y garantiza la purga inmediata de memoria.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$KeyPath = ".\BiosSecret.key"
)

function Invoke-LenovoBiosWithDpapi {
    [CmdletBinding()]
    param([string]$KeyPath)

    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path $KeyPath)) {
        throw "No se encontro el archivo de secreto cifrado en la ruta: $KeyPath"
    }

    $BSTR = [System.IntPtr]::Zero
    $PlainPassword = $null

    try {
        # Credenciales dentro del try para garantizar que el finally
        # siempre corra si algo falla durante la conversion.
        $EncryptedSecret = Get-Content -Path $KeyPath | ConvertTo-SecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptedSecret)
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        $BiosSettings = @{
            "SecurityChip"             = "Enable"
            "SecureBoot"               = "Enable"
            "UEFI/LegacyBoot"          = "UEFI Only"
            "CSMSupport"               = "Disable"
            "WakeOnLAN"                = "AC Only"
            "BootOrderLock"            = "Enable"
            "VirtualizationTechnology" = "Enable"
        }

        foreach ($Setting in $BiosSettings.GetEnumerator()) {
            $Argument = "$($Setting.Key),$($Setting.Value);"
            $Result = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = $Argument }

            # Write-Warning (no throw) para settings individuales: un modelo puntual
            # puede no soportar alguna opcion (ej. WakeOnLAN ausente en cierto SKU)
            # sin que eso invalide el resto de la baseline. Mismo criterio que
            # Set-LenovoBiosBaseline.ps1 (rama 14).
            if ($Result.return -ne "Success") {
                Write-Warning "Falla al aplicar [$($Setting.Key)]: $($Result.return)"
            }
        }

        $PassArgument = "Supervisor Password,Set,$PlainPassword;"
        $PassResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = $PassArgument }

        if ($PassResult.return -ne "Success") {
            throw "No se pudo establecer la contrasena de Supervisor. Retorno WMI: $($PassResult.return)"
        }

        $SaveResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SaveBiosSettings" -MethodName "SaveBiosSettings"
        if ($SaveResult.return -ne "Success") {
            throw "Falla al persistir los cambios en NVRAM. Retorno WMI: $($SaveResult.return)"
        }

        Write-Host "Baseline y Contrasena de BIOS inyectadas exitosamente mediante DPAPI." -ForegroundColor Green

    } finally {
        if ($BSTR -ne [System.IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
        $PlainPassword = $null
        [System.GC]::Collect()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-LenovoBiosWithDpapi -KeyPath $KeyPath
}
