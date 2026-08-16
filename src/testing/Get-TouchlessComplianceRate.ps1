<#
.SYNOPSIS
    Calcula el indicador agregado mensual de % de flota sin evidencia de interacción
    manual (Sección 16.2), excluyendo intervenciones autorizadas documentadas en ticket.
.PARAMETER ReportsPath
    Ruta del directorio de reportes XML de cumplimiento.
.PARAMETER Month
    Mes a evaluar en formato 'yyyy-MM'.
.PARAMETER SkipExecution
    Uso exclusivo de pruebas unitarias (dot-source).
#>
[CmdletBinding()]
param(
    [string]$ReportsPath,

    [ValidatePattern('^\d{4}-\d{2}$')]
    [string]$Month,

    [switch]$SkipExecution
)

function Get-TouchlessComplianceRate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportsPath,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d{4}-\d{2}$')]
        [string]$Month
    )

    $ErrorActionPreference = 'Stop'

    try {
        $reports = @(Get-ChildItem -Path $ReportsPath -Filter '*.xml' |
            Where-Object { $_.LastWriteTime.ToString('yyyy-MM') -eq $Month })

        if (-not $reports) {
            Write-DeploymentLog -Level Warn -Message "No se encontraron reportes para $Month"
            return
        }

        $total = $reports.Count
        $excepciones = 0
        $fallosNoAutorizados = 0

        foreach ($r in $reports) {
            [xml]$xml = Get-Content -LiteralPath $r.FullName
            $context8 = $xml.SelectSingleNode("//Context[@name='TouchlessAudit']")
            $context9 = $xml.SelectSingleNode("//Context[@name='OobeInteractionAudit']")

            $tieneTicketAutorizado = $xml.SelectSingleNode("//IncidentTicketRef") -ne $null

            if (($context8.status -eq 'Failed' -or $context9.status -eq 'Failed')) {
                if ($tieneTicketAutorizado) {
                    $excepciones++
                } else {
                    $fallosNoAutorizados++
                }
            }
        }

        $baseCalculo = $total - $excepciones
        $rate = if ($baseCalculo -gt 0) {
            [math]::Round((($baseCalculo - $fallosNoAutorizados) / $baseCalculo) * 100, 2)
        } else { 100 }

        Write-DeploymentLog -Level Info -Message "Touchless Compliance Rate ($Month): $rate% (Total=$total, Excepciones=$excepciones, Fallos no autorizados=$fallosNoAutorizados)"

        [PSCustomObject]@{
            Month               = $Month
            TotalEquipos        = $total
            Excepciones         = $excepciones
            FallosNoAutorizados = $fallosNoAutorizados
            ComplianceRate      = $rate
        }
    }
    catch {
        Write-DeploymentLog -Level Error -Message "Fallo al calcular Touchless Compliance Rate: $($_.Exception.Message)"
        throw
    }
}

if (-not $SkipExecution) {
    if (-not $ReportsPath -or -not $Month) {
        throw "Los parámetros -ReportsPath y -Month son obligatorios cuando se ejecuta el script directamente."
    }
    Get-TouchlessComplianceRate -ReportsPath $ReportsPath -Month $Month
}
