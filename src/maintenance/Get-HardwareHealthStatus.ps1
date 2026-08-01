<#
.SYNOPSIS
    Obtiene el estado de salud del hardware (SSD S.M.A.R.T., Batería y BIOS/Firmware).
.DESCRIPTION
    Consulta la infraestructura CIM/WMI para auditar el desgaste del almacenamiento,
    salud de la batería y versión de firmware en equipos Lenovo ThinkPad.
.EXAMPLE
    .\Get-HardwareHealthStatus.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    # 1. Auditoría de BIOS y Firmware
    $BiosInfo = Get-CimInstance -ClassName Win32_BIOS
    $SystemInfo = Get-CimInstance -ClassName Win32_ComputerSystemProduct

    # 2. Auditoría de Salud de Disco (Storage / SSD S.M.A.R.T.)
    $PhysicalDisk = Get-PhysicalDisk | Where-Object { $_.BusType -in @('NVMe', 'SATA', 'SSD') } | Select-Object -First 1
    
    if ($null -eq $PhysicalDisk) {
        throw "No se detectó una unidad de almacenamiento SSD/NVMe válida en el sistema."
    }

    $DiskHealth = Get-StorageReliabilityCounter -PhysicalDisk $PhysicalDisk -ErrorAction SilentlyContinue

    # 3. Auditoría de Batería (Lenovo WMI / CIM Power)
    $Battery = Get-CimInstance -Namespace "root\cimv2" -ClassName "Win32_Battery" -ErrorAction SilentlyContinue
    $LenovoBattery = Get-CimInstance -Namespace "root\wmi" -ClassName "Lenovo_BatteryInformation" -ErrorAction SilentlyContinue

    # Consolidación de Resultados
    $HealthReport = [PSCustomObject]@{
        ComputerModel       = $SystemInfo.Version
        SerialNumber        = $SystemInfo.IdentifyingNumber
        BIOSVersion         = $BiosInfo.SMBIOSBIOSVersion
        DiskModel           = $PhysicalDisk.Model
        DiskHealthStatus    = $PhysicalDisk.HealthStatus
        DiskWearPercentage  = if ($DiskHealth) { $DiskHealth.Wear } else { "N/A" }
        TemperatureCelsius  = if ($DiskHealth) { $DiskHealth.Temperature } else { "N/A" }
        BatteryStatus       = if ($Battery) { $Battery.Status } else { "N/A" }
        BatteryCycleCount   = if ($LenovoBattery) { $LenovoBattery.CycleCount } else { "N/A" }
    }

    # Formateo de salida para el Wrapper / Consola
    Write-Output ($HealthReport | Format-List | Out-String)

    # Evaluación de Umbrales Críticos para la Task Sequence
    if ($PhysicalDisk.HealthStatus -ne 'Unhealthy' -and ($null -eq $DiskHealth -or $DiskHealth.Wear -lt 90)) {
        # Hardware en estado saludable
        return $HealthReport
    } else {
        throw "ALERTA DE HARDWARE: El almacenamiento SSD ($($PhysicalDisk.Model)) presenta un desgaste crítico ($($DiskHealth.Wear)%) o estado Unhealthy."
    }

} catch {
    throw "Falla al evaluar la salud del hardware: $_"
}
