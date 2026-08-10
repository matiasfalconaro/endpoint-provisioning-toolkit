BeforeAll {
    . "$PSScriptRoot\..\..\src\security\Confirm-DriverSignature.ps1"
}

Describe "Confirm-DriverSignature" {

    Context "Modo Online - todos los drivers firmados" {
        BeforeEach {
            Mock Get-DriverInventory {
                @(
                    [PSCustomObject]@{ OriginalFileName = 'nvme.inf'; ProviderName = 'Samsung'; ClassName = 'DiskDrive'; Signed = $true }
                    [PSCustomObject]@{ OriginalFileName = 'netadapter.inf'; ProviderName = 'Intel'; ClassName = 'Net'; Signed = $true }
                )
            }
        }

        It "retorna el inventario completo sin lanzar excepcion" {
            $Result = Invoke-DriverSignatureAudit -Online
            $Result.Count | Should -Be 2
        }
    }

    Context "Modo Online - driver no firmado detectado" {
        BeforeEach {
            Mock Get-DriverInventory {
                @(
                    [PSCustomObject]@{ OriginalFileName = 'legacy_capture.inf'; ProviderName = 'Generic'; ClassName = 'Unknown'; Signed = $false }
                )
            }
        }

        It "lanza excepcion de seguridad critica ante driver no firmado" {
            { Invoke-DriverSignatureAudit -Online } | Should -Throw "*SEGURIDAD CRÍTICA*"
        }
    }

    Context "Modo Offline - TargetDrive valido, drivers firmados" {
        BeforeEach {
            Mock Get-DriverInventory {
                @([PSCustomObject]@{ OriginalFileName = 'chipset.inf'; ProviderName = 'Lenovo'; ClassName = 'System'; Signed = $true })
            }
            Mock Test-Path { $true }
        }

        It "audita la imagen offline correctamente" {
            $Result = Invoke-DriverSignatureAudit -TargetDrive "W:\"
            $Result.Count | Should -Be 1
        }
    }

    Context "Modo Offline - ruta de imagen inexistente" {
        BeforeEach {
            Mock Test-Path { $false }
        }

        It "lanza excepcion si TargetDrive no existe" {
            { Invoke-DriverSignatureAudit -TargetDrive "Z:\NoExiste" } | Should -Throw "*no existe*"
        }
    }

    Context "Sin -Online ni -TargetDrive especificados" {
        It "lanza excepcion indicando que se debe especificar el alcance" {
            { Invoke-DriverSignatureAudit } | Should -Throw "*Debe especificar*"
        }
    }
}
