<#
.SYNOPSIS
    Obtiene el estado de salud del hardware (SSD S.M.A.R.T., BaterÃ­a y BIOS/Firmware).
.DESCRIPTION
    Consulta la infraestructura CIM/WMI para auditar el desgaste del almacenamiento,
    salud de la baterÃ­a y versiÃ³n de firmware en equipos Lenovo ThinkPad.
.EXAMPLE
    .\Get-HardwareHealthStatus.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Invoke-HardwareHealthAudit {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    try {
        $BiosInfo   = Get-CimInstance -ClassName Win32_BIOS
        $SystemInfo = Get-CimInstance -ClassName Win32_ComputerSystemProduct

        $PhysicalDisk = Get-PhysicalDisk |
            Where-Object { $_.BusType -in @('NVMe', 'SATA') } |
            Select-Object -First 1

        if ($null -eq $PhysicalDisk) {
            throw "No se detecto una unidad de almacenamiento NVMe/SATA valida en el sistema."
        }

        $DiskHealth = Get-StorageReliabilityCounter -PhysicalDisk $PhysicalDisk -ErrorAction SilentlyContinue

        $Battery       = Get-CimInstance -Namespace "root\cimv2" -ClassName "Win32_Battery"          -ErrorAction SilentlyContinue
        $LenovoBattery = Get-CimInstance -Namespace "root\wmi"   -ClassName "Lenovo_BatteryInformation" -ErrorAction SilentlyContinue

        $HealthReport = [PSCustomObject]@{
            ComputerModel      = $SystemInfo.Version
            SerialNumber       = $SystemInfo.IdentifyingNumber
            BIOSVersion        = $BiosInfo.SMBIOSBIOSVersion
            DiskModel          = $PhysicalDisk.Model
            DiskHealthStatus   = $PhysicalDisk.HealthStatus
            DiskWearPercentage = if ($DiskHealth) { $DiskHealth.Wear } else { $null }
            TemperatureCelsius = if ($DiskHealth) { $DiskHealth.Temperature } else { $null }
            BatteryStatus      = if ($Battery)       { $Battery.Status }           else { "N/A" }
            BatteryCycleCount  = if ($LenovoBattery) { $LenovoBattery.CycleCount } else { "N/A" }
        }

        Write-Host ($HealthReport | Format-List | Out-String) -ForegroundColor Cyan

        # Evaluacion de umbrales criticos
        if ($PhysicalDisk.HealthStatus -eq 'Unhealthy') {
            throw "ALERTA DE HARDWARE: El almacenamiento ($($PhysicalDisk.Model)) reporta estado 'Unhealthy'."
        }

        if ($null -eq $DiskHealth) {
            Write-Warning "No se pudieron obtener datos S.M.A.R.T. de Get-StorageReliabilityCounter. El estado de desgaste del disco es INDETERMINADO."
        } elseif ($DiskHealth.Wear -ge 90) {
            throw "ALERTA DE HARDWARE: El almacenamiento ($($PhysicalDisk.Model)) presenta desgaste critico: $($DiskHealth.Wear)%."
        }

        return $HealthReport

    } catch {
        throw "Falla al evaluar la salud del hardware: $_"
    }
}

# Guarda de invocacion
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-HardwareHealthAudit
}
