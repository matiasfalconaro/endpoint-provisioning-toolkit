<#
.SYNOPSIS
    Mock de Set-LenovoBiosBaseline.ps1 con el fix real aplicado (referencia
    para test de regresión).
.DESCRIPTION
    Mismo mock de Invoke-CimMethod que MockBuggy.ps1 (siempre simula
    "AccessDenied"), pero con el patrón corregido: sin catch que intercepte
    el throw, y con $ErrorActionPreference = 'Stop' propio para que el
    script sea seguro incluso si se ejecuta fuera del wrapper.

    Usado por test7-bios-fixed-standalone.ps1 para confirmar que, a
    diferencia de MockBuggy.ps1, este script aborta correctamente (exit
    code distinto de 0) ante el mismo fallo simulado.
.PARAMETER BiosPassword
    Contraseña de Supervisor de la BIOS representada como SecureString.
    No se valida contra hardware real; el mock siempre simula "AccessDenied".
.EXAMPLE
    $SecurePass = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force
    .\Set-LenovoBiosBaseline.MockFixed.ps1 -BiosPassword $SecurePass
    # Resultado esperado: excepción no manejada, el script aborta,
    # exit code distinto de 0.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [System.Security.SecureString]$BiosPassword
)

$ErrorActionPreference = 'Stop'
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($BiosPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    $PassResult = @{ return = "AccessDenied" }   # mock de Invoke-CimMethod

    if ($PassResult.return -ne "Success") {
        throw "No se pudo establecer la contraseña de Supervisor en la BIOS. Retorno WMI: $($PassResult.return)"
    }

    Write-Host "Baseline de BIOS aplicada y guardada exitosamente." -ForegroundColor Green

} finally {
    if ($BSTR -ne [System.IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    $PlainPassword = $null
    [System.GC]::Collect()
}
