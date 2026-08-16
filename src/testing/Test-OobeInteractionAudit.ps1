<#
.SYNOPSIS
    Lógica aislada del Contexto 9 (auditoría de interacción OOBE) para
    Test-DeploymentCompliance.Tests.ps1. Ref. Sección 16.2.
.DESCRIPTION
    Correlaciona eventos del proveedor Microsoft-Windows-Shell-Core y EventID 7001
    contra la ventana de aprovisionamiento (LastBootUpTime → fin de Task Sequence).
    Degrada a estado 'Skipped' si el proveedor de eventos no está disponible,
    siguiendo el mismo patrón que el Contexto 8 (Test-TouchlessAudit.Tests.ps1).
#>
function Invoke-OobeInteractionAudit {
    [CmdletBinding()]
    param(
        [datetime]$WindowStart,
        [datetime]$WindowEnd
    )

    $ErrorActionPreference = 'Stop'

    try {
        $providerAvailable = Get-WinEvent -ListProvider 'Microsoft-Windows-Shell-Core' -ErrorAction SilentlyContinue
        if (-not $providerAvailable) {
            return [PSCustomObject]@{ Status = 'Skipped'; Reason = 'Proveedor Shell-Core no disponible' }
        }

        $events = @(Get-WinEvent -FilterHashtable @{
            LogName      = 'System'
            Id           = 7001
            StartTime    = $WindowStart
            EndTime      = $WindowEnd
        } -ErrorAction SilentlyContinue)

        if ($events.Count -gt 0) {
            return [PSCustomObject]@{
                Status = 'Failed'
                Reason = "Se detectaron $($events.Count) evento(s) de interacción OOBE dentro de la ventana de aprovisionamiento"
            }
        }

        return [PSCustomObject]@{ Status = 'Passed'; Reason = 'Sin evidencia de interacción OOBE' }
    }
    catch {
        return [PSCustomObject]@{ Status = 'Skipped'; Reason = "Excepción al consultar EventLog: $($_.Exception.Message)" }
    }
}
