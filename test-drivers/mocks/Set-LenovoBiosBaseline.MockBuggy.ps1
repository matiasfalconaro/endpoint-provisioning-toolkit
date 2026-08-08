<#
.SYNOPSIS
    Mock de Set-LenovoBiosBaseline.ps1 que reproduce el bug histórico de
    propagación de errores (referencia para test de regresión).
.DESCRIPTION
    Reemplaza la llamada real a Invoke-CimMethod por un resultado simulado
    de fallo ("AccessDenied"), sin requerir hardware Lenovo real. Conserva
    intencionalmente el patrón con bug: un catch que intercepta el throw
    de fallo crítico y lo convierte en Write-Error no terminante, dejando
    que el script termine con exit code 0 pese al fallo real.

    Usado por test6-bios-buggy-standalone.ps1 como prueba de regresión:
    mientras este mock siga dando exit code 0 pese al fallo simulado,
    confirma que el escenario original del bug sigue siendo reproducible
    para comparación contra el fix real.

    NO representa el comportamiento actual de src\bios\Set-LenovoBiosBaseline.ps1
    (ya corregido en la rama 14-bios-error-propagation), es una copia histórica
    congelada a propósito para no perder la capacidad de detectar si el bug
    se reintroduce en el futuro.
.PARAMETER BiosPassword
    Contraseña de Supervisor de la BIOS representada como SecureString.
    No se valida contra hardware real; el mock siempre simula "AccessDenied".
.EXAMPLE
    $SecurePass = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force
    .\Set-LenovoBiosBaseline.MockBuggy.ps1 -BiosPassword $SecurePass
    # Resultado esperado: Write-Error visible, pero el script termina con
    # exit code 0.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [System.Security.SecureString]$BiosPassword
)

# GUARDA DE SEGURIDAD
if ($env:ALLOW_HAZARDOUS_TESTS -ne "true") {
    Write-Warning "El test/mock [$($MyInvocation.MyCommand.Name)] está deshabilitado por guarda de seguridad."
    Write-Host "Para forzar su ejecución establece: `$env:ALLOW_HAZARDOUS_TESTS='true'" -ForegroundColor Yellow
    exit 0
}

# Intencionalmente SIN $ErrorActionPreference = 'Stop'
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($BiosPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    $PassResult = @{ return = "AccessDenied" }   # mock de Invoke-CimMethod

    if ($PassResult.return -ne "Success") {
        throw "No se pudo establecer la contraseña de Supervisor en la BIOS. Retorno WMI: $($PassResult.return)"
    }

    Write-Host "Baseline de BIOS aplicada y guardada exitosamente." -ForegroundColor Green

} catch {
    Write-Error "Error crítico durante la configuración de BIOS vía CIM/WMI: $_"
} finally {
    if ($BSTR -ne [System.IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    $PlainPassword = $null
    [System.GC]::Collect()
}
