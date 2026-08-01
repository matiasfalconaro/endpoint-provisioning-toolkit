<#
.SYNOPSIS
    Wrapper genérico de Task Sequence con Logging centralizado y manejo de errores.
.DESCRIPTION
    Ejecuta cualquier ScriptBlock o comando dentro de una estructura estandarizada de captura 
    de logs en red, captura de excepciones y purga de memoria.
.EXAMPLE
    .\Invoke-DeploymentTask.ps1 -TaskName "BIOS-Baseline" -ScriptBlock {
        .\Set-LenovoBiosBaseline.ps1 -BiosPassword $SecurePass
    }
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Nombre descriptivo de la tarea para el log")]
    [string]$TaskName,

    [Parameter(Mandatory = $true, HelpMessage = "Bloque de código PowerShell a ejecutar")]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "\\NAS-CORP01\Deployment\Logs"
)

$ErrorActionPreference = 'Stop'

# Resolución de identificador dinámico de máquina
$MacAddress = (Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | Select-Object -First 1).MACAddress -replace ':', ''
$ExecutionLog = Join-Path -Path $LogPath -ChildPath "$($MacAddress)_Deployment_Execution.log"

function Write-DeploymentLog {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] [$TaskName] $Message"
    
    Write-Output $LogEntry
    $LogEntry | Out-File -FilePath $ExecutionLog -Append -Encoding utf8
}

try {
    Write-DeploymentLog -Message "Iniciando ejecución de la tarea..." -Level "INFO"

    # Ejecución dinámica del código recibido
    & $ScriptBlock

    Write-DeploymentLog -Message "Tarea completada exitosamente." -Level "INFO"

} catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.InvocationInfo.MyCommand
    Write-DeploymentLog -Message "ERROR CRÍTICO en [$FailedItem]: $ErrorMessage" -Level "ERROR"
    
    # Notifica la falla a la Task Sequence de MDT/MECM para activar Rollback
    exit 1

} finally {
    # Purga obligatoria de memoria y buffers
    [System.GC]::Collect()
    Write-DeploymentLog -Message "Limpieza de memoria y finalización del wrapper." -Level "INFO"
}
