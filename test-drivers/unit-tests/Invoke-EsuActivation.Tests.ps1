BeforeAll {
    . "$PSScriptRoot\..\..\src\provisioning\Invoke-EsuActivation.ps1"
}

Describe "Invoke-EsuActivation" {

    Context "Activacion exitosa" {
        BeforeEach {
            Mock Get-CimInstance {
                if ($ClassName -eq 'SoftwareLicensingService') {
                    New-CimInstance -ClassName 'SoftwareLicensingService' -Property @{} -ClientOnly
                } elseif ($ClassName -eq 'SoftwareLicensingProduct') {
                    @(
                        New-CimInstance -ClassName 'SoftwareLicensingProduct' -Property @{
                            PartialProductKey = 'XXXXX'
                            ApplicationId     = '55c92734-d682-4d71-983e-d6ec3f16059f'
                            LicenseIsAddon    = $true
                            LicenseStatus     = 1
                        } -ClientOnly
                    )
                }
            }
            Mock Invoke-CimMethod { [PSCustomObject]@{ ReturnValue = 0 } }
        }

        It "completa sin excepcion cuando InstallProductKey y Activate retornan 0" {
            { Invoke-EsuLicenseActivation -EsuProductKey "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE" } | Should -Not -Throw
            Should -Invoke Invoke-CimMethod -Times 2 -Exactly
        }
    }

    Context "Fallo en InstallProductKey" {
        BeforeEach {
            Mock Get-CimInstance { New-CimInstance -ClassName 'SoftwareLicensingService' -Property @{} -ClientOnly }
            Mock Invoke-CimMethod { [PSCustomObject]@{ ReturnValue = 8 } }
        }

        It "lanza excepcion con ReturnValue cuando InstallProductKey falla" {
            { Invoke-EsuLicenseActivation -EsuProductKey "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE" } | Should -Throw "*ReturnValue*"
        }
    }

    Context "Producto ESU no encontrado tras inyeccion" {
        BeforeEach {
            $script:CallCount = 0
            Mock Get-CimInstance {
                $script:CallCount++
                if ($script:CallCount -eq 1) {
                    New-CimInstance -ClassName 'SoftwareLicensingService' -Property @{} -ClientOnly
                } else {
                    @()
                }
            }
            Mock Invoke-CimMethod { [PSCustomObject]@{ ReturnValue = 0 } }
        }

        It "lanza excepcion explicita en vez de caer al fallback silencioso" {
            { Invoke-EsuLicenseActivation -EsuProductKey "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE" } | Should -Throw "*No se encontro el producto ESU*"
        }
    }

    Context "LicenseStatus no activo tras activacion" {
        BeforeEach {
            $script:CallCount = 0
            Mock Get-CimInstance {
                $script:CallCount++
                if ($script:CallCount -eq 1) {
                    New-CimInstance -ClassName 'SoftwareLicensingService' -Property @{} -ClientOnly
                } elseif ($script:CallCount -eq 2) {
                    @(
                        New-CimInstance -ClassName 'SoftwareLicensingProduct' -Property @{
                            PartialProductKey = 'XXXXX'
                            ApplicationId     = '55c92734-d682-4d71-983e-d6ec3f16059f'
                            LicenseIsAddon    = $true
                            LicenseStatus     = 0
                        } -ClientOnly
                    )
                } else {
                    @()
                }
            }
            Mock Invoke-CimMethod { [PSCustomObject]@{ ReturnValue = 0 } }
        }

        It "lanza excepcion si LicenseStatus no es 1 tras la activacion" {
            { Invoke-EsuLicenseActivation -EsuProductKey "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE" } | Should -Throw "*LicenseStatus = 1*"
        }
    }
}
