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

    function global:Get-StorageReliabilityCounter {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline = $true)]$PhysicalDisk
        )
        process {}
    }

    . "$PSScriptRoot\..\..\src\maintenance\Get-HardwareHealthStatus.ps1"
}

Describe "Get-HardwareHealthStatus" {

    Context "Hardware saludable con datos S.M.A.R.T. disponibles" {
        BeforeEach {
            Mock Get-CimInstance {
                if ($ClassName -eq 'Win32_BIOS') {
                    [PSCustomObject]@{ SMBIOSBIOSVersion = 'R22ET70W' }
                } elseif ($ClassName -eq 'Win32_ComputerSystemProduct') {
                    [PSCustomObject]@{ Version = 'ThinkPad T14'; IdentifyingNumber = 'SN123456' }
                } else { $null }
            }
            Mock Get-PhysicalDisk {
                [PSCustomObject]@{ Model = 'Samsung SSD 980'; BusType = 'NVMe'; HealthStatus = 'Healthy' }
            }
            Mock Get-StorageReliabilityCounter {
                [PSCustomObject]@{ Wear = 5; Temperature = 38 }
            }
        }

        It "retorna el reporte cuando el disco esta saludable y el desgaste es bajo" {
            $Report = Invoke-HardwareHealthAudit
            $Report.DiskHealthStatus   | Should -Be 'Healthy'
            $Report.DiskWearPercentage | Should -Be 5
        }
    }

    Context "Disco en estado Unhealthy" {
        BeforeEach {
            Mock Get-CimInstance { [PSCustomObject]@{ SMBIOSBIOSVersion = 'R22ET70W'; Version = 'T14'; IdentifyingNumber = 'SN1' } }
            Mock Get-PhysicalDisk {
                [PSCustomObject]@{ Model = 'SSD Fallido'; BusType = 'NVMe'; HealthStatus = 'Unhealthy' }
            }
            Mock Get-StorageReliabilityCounter { [PSCustomObject]@{ Wear = 45; Temperature = 50 } }
        }

        It "lanza excepcion cuando HealthStatus es Unhealthy" {
            { Invoke-HardwareHealthAudit } | Should -Throw "*estado 'Unhealthy'*"
        }
    }

    Context "Desgaste critico mayor al 90 por ciento" {
        BeforeEach {
            Mock Get-CimInstance { [PSCustomObject]@{ SMBIOSBIOSVersion = 'R22ET70W'; Version = 'T14'; IdentifyingNumber = 'SN1' } }
            Mock Get-PhysicalDisk {
                [PSCustomObject]@{ Model = 'SSD Desgastado'; BusType = 'NVMe'; HealthStatus = 'Healthy' }
            }
            Mock Get-StorageReliabilityCounter { [PSCustomObject]@{ Wear = 95; Temperature = 55 } }
        }

        It "lanza excepcion cuando el desgaste supera el umbral critico" {
            { Invoke-HardwareHealthAudit } | Should -Throw "*desgaste critico*"
        }
    }

    Context "S.M.A.R.T. no disponible (DiskHealth es null)" {
        BeforeEach {
            Mock Get-CimInstance { [PSCustomObject]@{ SMBIOSBIOSVersion = 'R22ET70W'; Version = 'T14'; IdentifyingNumber = 'SN1' } }
            Mock Get-PhysicalDisk {
                [PSCustomObject]@{ Model = 'SSD Sin SMART'; BusType = 'NVMe'; HealthStatus = 'Healthy' }
            }
            Mock Get-StorageReliabilityCounter { $null }
        }

        It "retorna el reporte con warning, no trata null como exito silencioso" {
            $Report = Invoke-HardwareHealthAudit
            $Report | Should -Not -BeNullOrEmpty
            $Report.DiskWearPercentage | Should -BeNullOrEmpty
        }
    }

    Context "Sin disco NVMe o SATA detectado" {
        BeforeEach {
            Mock Get-CimInstance { [PSCustomObject]@{ SMBIOSBIOSVersion = 'R22'; Version = 'T14'; IdentifyingNumber = 'SN1' } }
            Mock Get-PhysicalDisk { @() }
        }

        It "lanza excepcion si no se encuentra ninguna unidad valida" {
            { Invoke-HardwareHealthAudit } | Should -Throw "*No se detecto*"
        }
    }
}
