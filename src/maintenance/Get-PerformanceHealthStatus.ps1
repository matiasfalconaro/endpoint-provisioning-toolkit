<#
.SYNOPSIS
    Audita el rendimiento y la salud térmica del sistema (CPU, Temperatura y Throughput de Disco NVMe/SATA).
.DESCRIPTION
    Consulta la infraestructura CIM/WMI para validar que el equipo no presente degradación de
    rendimiento en estado idle/post-despliegue: uso de CPU, temperatura de zona térmica y
    velocidad de lectura/escritura del almacenamiento principal, contra umbrales homologados
    por modelo de hardware Lenovo ThinkPad.
.EXAMPLE
    .\Get-PerformanceHealthStatus.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [double]$MaxCpuTemperatureCelsius = 85,

    [Parameter(Mandatory = $false)]
    [double]$MaxCpuIdlePercent = 20,

    [Parameter(Mandatory = $false)]
    [double]$MinNvmeThroughputMBs = 3000,

    [Parameter(Mandatory = $false)]
    [double]$MinSataThroughputMBs = 450
)

$ErrorActionPreference = 'Stop'

function Invoke-PerformanceHealthAudit {
    [CmdletBinding()]
    param(
        [double]$MaxCpuTemperatureCelsius = 85,
        [double]$MaxCpuIdlePercent = 20,
        [double]$MinNvmeThroughputMBs = 3000,
        [double]$MinSataThroughputMBs = 450
    )

    $ErrorActionPreference = 'Stop'

    try {
        $CpuCounter = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq '_Total' }

        # La zona termica ACPI no esta expuesta uniformemente en todo el hardware;
        # se degrada a $null en lugar de fallar la auditoria completa (mismo criterio
        # que Get-StorageReliabilityCounter en Get-HardwareHealthStatus.ps1).
        $ThermalZone = Get-CimInstance -Namespace "root\wmi" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction SilentlyContinue |
            Select-Object -First 1

        $CpuTemperatureCelsius = if ($ThermalZone) {
            # MSAcpi expone decikelvin; conversion a Celsius.
            [math]::Round(($ThermalZone.CurrentTemperature / 10) - 273.15, 1)
        } else { $null }

        $PhysicalDisk = Get-PhysicalDisk |
            Where-Object { $_.BusType -in @('NVMe', 'SATA') } |
            Select-Object -First 1

        if ($null -eq $PhysicalDisk) {
            throw "No se detecto una unidad de almacenamiento NVMe/SATA valida en el sistema."
        }

        $DiskPerfCounter = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '_Total' } |
            Select-Object -First 1

        $DiskReadMBs  = if ($DiskPerfCounter) { [math]::Round($DiskPerfCounter.DiskReadBytesPersec  / 1MB, 1) } else { $null }
        $DiskWriteMBs = if ($DiskPerfCounter) { [math]::Round($DiskPerfCounter.DiskWriteBytesPersec / 1MB, 1) } else { $null }

        $ExpectedMinThroughput = if ($PhysicalDisk.BusType -eq 'NVMe') { $MinNvmeThroughputMBs } else { $MinSataThroughputMBs }

        $PerformanceReport = [PSCustomObject]@{
            CpuIdlePercent         = if ($CpuCounter) { $CpuCounter.PercentProcessorTime } else { $null }
            CpuTemperatureCelsius  = $CpuTemperatureCelsius
            DiskModel              = $PhysicalDisk.Model
            DiskBusType            = $PhysicalDisk.BusType
            DiskReadMBs            = $DiskReadMBs
            DiskWriteMBs           = $DiskWriteMBs
            ExpectedMinThroughput  = $ExpectedMinThroughput
        }

        Write-Host ($PerformanceReport | Format-List | Out-String) -ForegroundColor Cyan

        # Evaluacion de umbrales criticos

        if ($null -eq $CpuTemperatureCelsius) {
            Write-Warning "No se pudo obtener la temperatura de zona termica ACPI. El estado termico es INDETERMINADO."
        } elseif ($CpuTemperatureCelsius -ge $MaxCpuTemperatureCelsius) {
            throw "ALERTA DE RENDIMIENTO: Temperatura de CPU critica detectada: $CpuTemperatureCelsius C (umbral: $MaxCpuTemperatureCelsius C)."
        }

        if ($null -ne $CpuCounter -and $CpuCounter.PercentProcessorTime -ge $MaxCpuIdlePercent) {
            Write-Warning "Uso de CPU en estado idle post-despliegue superior al esperado: $($CpuCounter.PercentProcessorTime)% (umbral: $MaxCpuIdlePercent%)."
        }

        if ($null -eq $DiskPerfCounter) {
            Write-Warning "No se pudieron obtener contadores de rendimiento del disco. El throughput es INDETERMINADO."
        }

        return $PerformanceReport

    } catch {
        throw "Falla al evaluar la salud de rendimiento del hardware: $_"
    }
}

# Guarda de invocacion
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-PerformanceHealthAudit `
        -MaxCpuTemperatureCelsius $MaxCpuTemperatureCelsius `
        -MaxCpuIdlePercent $MaxCpuIdlePercent `
        -MinNvmeThroughputMBs $MinNvmeThroughputMBs `
        -MinSataThroughputMBs $MinSataThroughputMBs
}
