# Get-PerformanceHealthStatus.Tests.ps1

BeforeAll {
    # Se fuerza la definicion en el Function Provider para enmascarar los cmdlets nativos de Windows Storage
    function global:Get-PhysicalDisk {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline = $true)]$InputObject,
            $UniqueId,
            $FriendlyName
        )
        process {}
    }

    . "$PSScriptRoot\..\..\src\maintenance\Get-PerformanceHealthStatus.ps1"
}

Describe "Get-PerformanceHealthStatus" {

    Context "Rendimiento saludable con datos completos" {
        BeforeEach {
            Mock Get-CimInstance {
                if ($ClassName -eq 'Win32_PerfFormattedData_PerfOS_Processor') {
                    [PSCustomObject]@{ Name = '_Total'; PercentProcessorTime = 3 }
                } elseif ($ClassName -eq 'MSAcpi_ThermalZoneTemperature') {
                    [PSCustomObject]@{ CurrentTemperature = 3231 }  # ~50.0 C
                } elseif ($ClassName -eq 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk') {
                    [PSCustomObject]@{ Name = '0 C:'; DiskReadBytesPersec = 3500MB; DiskWriteBytesPersec = 3200MB }
                } else { $null }
            }
            Mock Get-PhysicalDisk {
                [PSCustomObject]@{ Model = 'Samsung SSD 980'; BusType = 'NVMe' }
            }
        }

        It "retorna el reporte cuando la temperatura y el throughput estan dentro de rango" {
            $Report = Invoke-PerformanceHealthAudit
            $Report.CpuTemperatureCelsius | Should -BeLessThan 85
            $Report.DiskReadMBs           | Should -BeGreaterThan 3000
        }
    }

    Context "Temperatura de CPU critica" {
        BeforeEach {
            Mock Get-CimInstance {
                if ($ClassName -eq 'Win32_PerfFormattedData_PerfOS_Processor') {
                    [PSCustomObject]@{ Name = '_Total'; PercentProcessorTime = 5 }
                } elseif ($ClassName -eq 'MSAcpi_ThermalZoneTemperature') {
                    [PSCustomObject]@{ CurrentTemperature = 3611 }  # ~88.0 C
                } else { $null }
            }
            Mock Get-PhysicalDisk {
                [PSCustomObject]@{ Model = 'SSD Sobrecalentado'; BusType = 'NVMe' }
            }
        }

        It "lanza excepcion cuando la temperatura supera el umbral critico" {
            { Invoke-PerformanceHealthAudit } | Should -Throw "*Temperatura de CPU critica*"
        }
    }

    Context "Throughput de disco por debajo del umbral NVMe" {
        BeforeEach {
            Mock Get-CimInstance {
                if ($ClassName -eq 'Win32_PerfFormattedData_PerfOS_Processor') {
                    [PSCustomObject]@{ Name = '_Total'; PercentProcessorTime = 2 }
                } elseif ($ClassName -eq 'MSAcpi_ThermalZoneTemperature') {
                    [PSCustomObject]@{ CurrentTemperature = 3231 }
                } elseif ($ClassName -eq 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk') {
                    [PSCustomObject]@{ Name = '0 C:'; DiskReadBytesPersec = 800MB; DiskWriteBytesPersec = 750MB }
                } else { $null }
            }
            Mock Get-PhysicalDisk {
                [PSCustomObject]@{ Model = 'NVMe Degradado'; BusType = 'NVMe' }
            }
        }

        It "el reporte refleja throughput inferior al esperado para NVMe (no bloqueante por diseno)" {
            $Report = Invoke-PerformanceHealthAudit
            $Report.DiskReadMBs           | Should -BeLessThan $Report.ExpectedMinThroughput
        }
    }

    Context "Contadores de CPU y disco no disponibles" {
        BeforeEach {
            Mock Get-CimInstance { $null }
            Mock Get-PhysicalDisk {
                [PSCustomObject]@{ Model = 'SSD Sin Contadores'; BusType = 'SATA' }
            }
        }

        It "retorna el reporte con warning, no trata null como fallo silencioso" {
            $Report = Invoke-PerformanceHealthAudit
            $Report                        | Should -Not -BeNullOrEmpty
            $Report.CpuTemperatureCelsius  | Should -BeNullOrEmpty
            $Report.DiskReadMBs            | Should -BeNullOrEmpty
        }
    }

    Context "Sin disco NVMe o SATA detectado" {
        BeforeEach {
            Mock Get-CimInstance { $null }
            Mock Get-PhysicalDisk { @() }
        }

        It "lanza excepcion si no se encuentra ninguna unidad valida" {
            { Invoke-PerformanceHealthAudit } | Should -Throw "*No se detecto*"
        }
    }
}
