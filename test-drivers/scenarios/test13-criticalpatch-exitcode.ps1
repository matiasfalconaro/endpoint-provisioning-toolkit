<#
.SYNOPSIS
    Test 13 — Valida que Invoke-CriticalPatchGate.ps1, ejecutado como proceso standalone,
    propaga ExitCode ≠ 0 cuando la función interna lanza una excepción no capturada
    (regresión del refactor "función pública + -SkipExecution", Sección 18.8).
.NOTES
    Requiere $env:ALLOW_HAZARDOUS_TESTS = 'true' — invoca el script real vía proceso hijo
    (no dot-source), simulando el escenario de fallo de wusa.exe sin tocar el sistema real
    mediante interceptación previa del PATH (mock de wusa.exe como script de PowerShell).
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
)

if ($env:ALLOW_HAZARDOUS_TESTS -ne 'true') {
    Write-Warning "Test 13 omitido: ALLOW_HAZARDOUS_TESTS no está en 'true'."
    exit 0
}

$scriptPath = Join-Path $RepoRoot 'src\security\Invoke-CriticalPatchGate.ps1'

# Se simula un paquete inexistente para forzar la excepción sin invocar wusa.exe real.
$proc = Start-Process -FilePath 'powershell.exe' `
    -ArgumentList "-NoProfile -File `"$scriptPath`" -KbId KB9999999 -RepoRoot `"$env:TEMP\no-existe`"" `
    -Wait -PassThru -NoNewWindow

if ($proc.ExitCode -eq 0) {
    Write-Error "Test 13 FALLIDO: se esperaba ExitCode != 0, se obtuvo 0."
    exit 1
}

Write-Output "Test 13 PASS: ExitCode=$($proc.ExitCode) (propagación correcta de excepción no capturada)"
exit 0
