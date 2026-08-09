<#
.SYNOPSIS
    Validacion Estricta: replica el flujo real de produccion, exigiendo
    OBLIGATORIAMENTE las validaciones de integridad SHA-256 y firma Authenticode.
.DESCRIPTION
    A diferencia de Test 0 (test0-skipping_security_checks.ps1) y Test 1, que usan
    -SkipSignatureValidation, este test NO utiliza ningun flag de omision.

    Construye una copia aislada de la estructura src/core, src/security y
    src/features en un directorio temporal (ya que Invoke-DeploymentTask.ps1 y
    Confirm-ScriptIntegrity.ps1 resuelven sus rutas via $PSScriptRoot y no
    aceptan un SourcePath externo), firma el script objetivo con un certificado
    autofirmado de prueba, genera el manifiesto DESPUES de firmar (el hash debe
    reflejar el binario ya firmado), y recien entonces invoca el wrapper sin
    flags de skip.

    NOTA SOBRE VALIDACION DE CADENA DE CONFIANZA (Mock de cmdlets nativos):
    src/security/Set-AuthenticodeSignature.ps1 exige Status -eq 'Valid' al
    firmar, lo cual con el cmdlet nativo requiere que la CA de prueba sea
    de confianza en Cert:\CurrentUser\Root/TrustedPublisher. Instalar una CA
    ahi -por cualquier medio (X509Store, certutil)- dispara el dialogo
    interactivo "Security Warning" de Windows sin excepcion.

    Para evitarlo sin perder cobertura real de firmado, este test carga
    test-drivers/mocks/Set-AuthenticodeSignature.MockTrustedChain.ps1, que
    intercepta Set-AuthenticodeSignature y Get-AuthenticodeSignature
    (los cmdlets NATIVOS, no el wrapper del repo) para forzar Status='Valid'
    UNICAMENTE cuando la causa real es una cadena de confianza no instalada.
    La firma en si sigue siendo real (bytes Authenticode reales sobre un
    certificado real). Nunca se toca Root/TrustedPublisher.

    Ver el docstring del mock para el detalle completo del mecanismo.

    DEPENDENCIA EXTERNA CONOCIDA: la firma real usa un servidor de timestamp
    fijo (timestamp.digicert.com) que requiere conectividad a Internet. Sin
    red, este test puede fallar por causas ajenas a la logica que dice
    validar.
#>

if ($env:ALLOW_HAZARDOUS_TESTS -ne 'true') {
    Write-Host "Este test requiere `$env:ALLOW_HAZARDOUS_TESTS = 'true' (genera y firma con un certificado de prueba temporal). Abortando por seguridad." -ForegroundColor Red
    exit 1
}

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).ProviderPath
$TempRoot = Join-Path $env:TEMP "strict-validation-test-$(Get-Random)"
$Cert = $null
$MockLoaded = $false

try {
    Write-Host "=== Paso 0: Cargando mock de cadena de confianza (sin tocar Root/TrustedPublisher) ===" -ForegroundColor Cyan
    . (Join-Path $PSScriptRoot "..\mocks\Set-AuthenticodeSignature.MockTrustedChain.ps1")
    $MockLoaded = $true

    # Estructura aislada, replicando src/core, src/security, src/features
    New-Item -Path (Join-Path $TempRoot "src\core") -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $TempRoot "src\security") -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $TempRoot "src\features") -ItemType Directory -Force | Out-Null

    Copy-Item (Join-Path $RepoRoot "src\core\Invoke-DeploymentTask.ps1") (Join-Path $TempRoot "src\core\")
    Copy-Item (Join-Path $RepoRoot "src\security\Confirm-ScriptIntegrity.ps1") (Join-Path $TempRoot "src\security\")
    Copy-Item (Join-Path $RepoRoot "src\security\Set-AuthenticodeSignature.ps1") (Join-Path $TempRoot "src\security\")
    Copy-Item (Join-Path $RepoRoot "src\features\Enable-WindowsOptionalFeatures.ps1") (Join-Path $TempRoot "src\features\")

    $TempTargetScript = Join-Path $TempRoot "src\features\Enable-WindowsOptionalFeatures.ps1"
    $TempManifest     = Join-Path $TempRoot "manifest.json"
    $TempTask         = Join-Path $TempRoot "src\core\Invoke-DeploymentTask.ps1"
    $TempIntegrity    = Join-Path $TempRoot "src\security\Confirm-ScriptIntegrity.ps1"

    Write-Host "=== Paso 1: Generando certificado Code Signing autofirmado de prueba ===" -ForegroundColor Cyan
    Write-Host "(Permanece unicamente en Cert:\CurrentUser\My - no se instala en Root/TrustedPublisher)" -ForegroundColor DarkGray
    $Cert = New-SelfSignedCertificate -Subject "CN=Strict-Validation-Test" `
        -Type CodeSigningCert -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddDays(1)

    Write-Host "=== Paso 2: Firmando la copia aislada del script objetivo ===" -ForegroundColor Cyan
    & (Join-Path $TempRoot "src\security\Set-AuthenticodeSignature.ps1") `
        -ScriptPath $TempTargetScript -CertificateThumbprint $Cert.Thumbprint

    Write-Host "=== Paso 3: Verificando la firma de forma independiente (Get-AuthenticodeSignature) ===" -ForegroundColor Cyan
    $VerifySig = Get-AuthenticodeSignature -FilePath $TempTargetScript
    Write-Host "Status reportado: $($VerifySig.Status)"
    if ($VerifySig.Status -ne 'Valid') {
        throw "SETUP INVALIDO: la firma de prueba no quedo en estado 'Valid' (Status: $($VerifySig.Status)). No tiene sentido continuar - revisar conectividad al timestamp server o el mock de cadena de confianza."
    }
    if ($VerifySig.SignerCertificate.Thumbprint -ne $Cert.Thumbprint) {
        throw "SETUP INVALIDO: la firma presente no corresponde al certificado de prueba generado."
    }

    Write-Host "=== Paso 4: Generando manifiesto SHA-256 (DESPUES de firmar) ===" -ForegroundColor Cyan
    & $TempIntegrity -Action Generate -SourcePath $TempRoot -ManifestPath $TempManifest

    Write-Host "=== Paso 5: Ejecutando Invoke-DeploymentTask.ps1 SIN flags de omision ===" -ForegroundColor Cyan
    & $TempTask -TaskName "Test-StrictValidation" `
        -ScriptPath $TempTargetScript `
        -ManifestPath $TempManifest `
        -LogPath $TempRoot `
        -LocalFallbackLogPath $TempRoot `
        -ScriptBlock { Write-Host "Simulando tarea con validacion estricta (real, sin bypass)..." }

    $ExitCode = $LASTEXITCODE

} catch {
    Write-Host "ERROR EN SETUP DEL TEST: $_" -ForegroundColor Red
    $ExitCode = 1
} finally {
    Write-Host "=== Limpieza: removiendo certificado, mock y directorio temporal ===" -ForegroundColor Gray
    if ($Cert) {
        Get-ChildItem "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $Cert.Thumbprint } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    if ($MockLoaded) {
        Remove-Item Function:\Set-AuthenticodeSignature -ErrorAction SilentlyContinue
        Remove-Item Function:\Get-AuthenticodeSignature -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit $ExitCode
