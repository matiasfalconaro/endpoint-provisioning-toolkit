[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [System.Security.SecureString]$BiosPassword
)

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
