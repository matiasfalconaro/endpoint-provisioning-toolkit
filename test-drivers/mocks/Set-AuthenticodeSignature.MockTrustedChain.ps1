<#
.SYNOPSIS
    Mock de confianza de cadena para Test 11 (Validacion Estricta).
.DESCRIPTION
    Intercepta los cmdlets NATIVOS Set-AuthenticodeSignature y
    Get-AuthenticodeSignature de PowerShell mediante sombreado de funcion
    global (mismo patron que Invoke-LenovoDriveWipe.MockNist.ps1 con
    Start-Process).

    Por que este mock existe:
    src/security/Set-AuthenticodeSignature.ps1 (el wrapper de produccion)
    exige Status -eq 'Valid' tanto al firmar como al validar. El cmdlet
    nativo solo devuelve 'Valid' si la cadena de confianza del certificado
    esta instalada en el sistema (Root/TrustedPublisher), lo cual requiere
    tocar el almacen de confianza real del usuario y dispara el dialogo
    interactivo "Security Warning" de Windows sin excepcion, sin importar
    la herramienta usada (X509Store, certutil, etc).

    Que hace este mock, especificamente:
    1. Llama al cmdlet REAL (via el nombre calificado por modulo, que
       bypasea el sombreado de funcion) para aplicar la firma
       criptografica de verdad sobre el archivo, con el certificado real
       generado por el test.
    2. Si el resultado real es 'UnknownError' o 'NotTrusted' (los estados
       tipicos cuando la firma es tecnicamente correcta pero la CA no es
       de confianza local), se devuelve un objeto de resultado "parcheado"
       con Status = 'Valid', preservando el resto de las propiedades.
    3. Cualquier otro estado (firma realmente corrupta, archivo alterado,
       hash roto, etc.) se propaga SIN modificar.

    Que NO se mockea: la firma en si. El archivo objetivo queda firmado
    con bytes Authenticode reales, generados por el motor criptografico
    real de Windows sobre un certificado real. Solo se enmascara el
    veredicto de confianza de la cadena.

    Nunca se instala ni se toca Cert:\CurrentUser\Root ni
    Cert:\CurrentUser\TrustedPublisher.
.EXAMPLE
    . "$PSScriptRoot\..\mocks\Set-AuthenticodeSignature.MockTrustedChain.ps1"
#>

function global:Set-AuthenticodeSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        $Certificate,

        [Parameter(Mandatory = $false)]
        [string]$TimestampServer,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArgs
    )

    $RealParams = @{
        FilePath    = $FilePath
        Certificate = $Certificate
    }
    if ($TimestampServer) {
        $RealParams.TimestampServer = $TimestampServer
    }

    # Llamada calificada por modulo: bypasea el sombreado de esta misma
    # funcion e invoca directamente al cmdlet nativo real.
    $RealResult = Microsoft.PowerShell.Security\Set-AuthenticodeSignature @RealParams

    Write-Host "[MOCK TRUST] Set-AuthenticodeSignature (real) -> Status: $($RealResult.Status)" -ForegroundColor DarkCyan

    if ($RealResult.Status -in @('UnknownError', 'NotTrusted')) {
        Write-Host "[MOCK TRUST] Cadena de confianza no instalada localmente. Forzando Status a 'Valid' para pruebas locales." -ForegroundColor DarkCyan
        return [PSCustomObject]@{
            Status                  = 'Valid'
            StatusMessage           = "$($RealResult.StatusMessage) [MOCKEADO: cadena de confianza forzada como valida para pruebas locales]"
            Path                    = $RealResult.Path
            SignerCertificate       = $RealResult.SignerCertificate
            TimeStamperCertificate  = $RealResult.TimeStamperCertificate
        }
    }

    return $RealResult
}

function global:Get-AuthenticodeSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArgs
    )

    $RealResult = Microsoft.PowerShell.Security\Get-AuthenticodeSignature -FilePath $FilePath

    Write-Host "[MOCK TRUST] Get-AuthenticodeSignature (real) -> Status: $($RealResult.Status)" -ForegroundColor DarkCyan

    if ($RealResult.Status -in @('UnknownError', 'NotTrusted')) {
        return [PSCustomObject]@{
            Status                  = 'Valid'
            StatusMessage           = "$($RealResult.StatusMessage) [MOCKEADO: cadena de confianza forzada como valida para pruebas locales]"
            Path                    = $RealResult.Path
            SignerCertificate       = $RealResult.SignerCertificate
            TimeStamperCertificate  = $RealResult.TimeStamperCertificate
        }
    }

    return $RealResult
}
