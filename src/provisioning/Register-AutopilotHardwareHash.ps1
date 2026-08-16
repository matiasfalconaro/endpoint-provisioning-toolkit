<#
.SYNOPSIS
    Registro asistido del Hardware Hash (4K HH) en Intune/Entra ID para el flujo
    paralelo Autopilot (Sección 6.4). Uso exclusivo de N3/Compras — no se ejecuta
    dentro de la Task Sequence On-Premise.
.PARAMETER CsvOutputPath
    Ruta de salida del CSV con el Hardware Hash, formato compatible con
    Import-AutopilotCSV / Microsoft Graph.
.PARAMETER SkipExecution
    Uso exclusivo de pruebas unitarias (dot-source).
#>
[CmdletBinding()]
param(
    [string]$CsvOutputPath,

    [switch]$SkipExecution
)

function Register-AutopilotHardwareHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CsvOutputPath
    )

    $ErrorActionPreference = 'Stop'

    try {
        Write-DeploymentLog -Level Info -Message "Capturando Hardware Hash local"

        # Requiere el módulo Get-WindowsAutoPilotInfo (comunidad/Microsoft) preinstalado
        # en la estación de captura (no en el endpoint destino).
        Get-WindowsAutoPilotInfo -OutputFile $CsvOutputPath

        if (-not (Test-Path -LiteralPath $CsvOutputPath)) {
            Write-DeploymentLog -Level Error -Message "No se generó el archivo CSV esperado"
            throw "No se generó el archivo CSV esperado en $CsvOutputPath"
        }

        Write-DeploymentLog -Level Info -Message "Hardware Hash exportado a $CsvOutputPath. Pendiente de carga manual a Intune por N3."
    }
    catch {
        Write-DeploymentLog -Level Error -Message "Fallo al capturar Hardware Hash: $($_.Exception.Message)"
        throw
    }
}

if (-not $SkipExecution) {
    if (-not $CsvOutputPath) {
        throw "El parámetro -CsvOutputPath es obligatorio cuando se ejecuta el script directamente."
    }
    Register-AutopilotHardwareHash -CsvOutputPath $CsvOutputPath
}
