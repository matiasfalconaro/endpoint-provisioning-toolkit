<#
.SYNOPSIS
    Ejecutor de pruebas de cumplimiento e integraciÃ³n para la Task Sequence.
.DESCRIPTION
    Invoca la suite de pruebas Pester, exporta el reporte en formato NUnit XML al servidor NAS
    y devuelve exit code 0 (Ã‰xito) o exit code 1 (Si alguna prueba de cumplimiento falla).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "\\NAS-CORP01\Deployment\Logs\ComplianceReports"
)

$ErrorActionPreference = 'Stop'

try {
    # 1. Asegurar la presencia del mÃ³dulo Pester (o importar desde el Deployment Share)
    if (-not (Get-Module -Name Pester -ListAvailable)) {
        Import-Module "\\NAS-CORP01\Deployment\Tools\Pester\Pester.psm1" -ErrorAction Stop
    }

    $ComputerName = $env:COMPUTERNAME
    $OutputFile = Join-Path -Path $ReportPath -ChildPath "Compliance_$($ComputerName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').xml"

    Write-Output "Iniciando Suite de Pruebas de Cumplimiento Automatizado Pester..."

    # 2. Configurar la ejecuciÃ³n de Pester 5.x
    $PesterConfig = [PesterConfiguration]::Default
    $PesterConfig.Run.Path = "$PSScriptRoot\Test-DeploymentCompliance.Tests.ps1"
    $PesterConfig.TestResult.Enabled = $true
    $PesterConfig.TestResult.OutputPath = $OutputFile
    $PesterConfig.TestResult.OutputFormat = "NUnitXml"
    $PesterConfig.Output.Verbosity = "Detailed"

    # 3. Ejecutar Pester
    $Result = Invoke-Pester -Configuration $PesterConfig

    # 4. EvaluaciÃ³n de Criterios
    if ($Result.FailedCount -gt 0) {
        throw "FALLA DE CUMPLIMIENTO: $($Result.FailedCount) prueba(s) automatizada(s) no pasaron la validaciÃ³n. Reporte guardado en: $OutputFile"
    }

    Write-Output "TODAS LAS PRUEBAS DE CUMPLIMIENTO PASARON EXITOSAMENTE ($($Result.PassedCount)/$($Result.TotalCount)). Reporte generado en: $OutputFile"

} catch {
    throw "ERROR CRÃTICO EN VALIDACIÃ“N DE INFRAESTRUCTURA: $_"
}
