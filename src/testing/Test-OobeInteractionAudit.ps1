<#
.SYNOPSIS
    Audita evidencia de interacción manual durante el flujo OOBE (Contexto 9).
.DESCRIPTION
    Inspecciona el registro de eventos System en busca de EventID 7001 y eventos
    del proveedor Microsoft-Windows-Shell-Core, correlacionando su timestamp contra
    la ventana de aprovisionamiento (LastBootUpTime hasta fin de Task Sequence).
    Degrada a Skipped si el proveedor de eventos no está disponible.
.PARAMETER DeploymentWindowStart
    Timestamp de inicio de la ventana de aprovisionamiento a auditar.
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
