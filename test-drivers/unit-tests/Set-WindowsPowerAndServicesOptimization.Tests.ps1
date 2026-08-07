BeforeAll {
    . "$PSScriptRoot\..\..\src\optimization\Set-WindowsPowerAndServicesOptimization.ps1"
}

Describe "Set-WindowsPowerAndServicesOptimization" {

    Context "Hardware tipo Laptop (ChassisType en lista de portatiles)" {
        BeforeEach {
            Mock Get-CimInstance {
                [PSCustomObject]@{ ChassisTypes = @(10) }
            }
            Mock powercfg { }
            $global:LASTEXITCODE = 0
        }

        It "invoca powercfg /hibernate on para hardware portatil" {
            Invoke-PowerProfileOptimization
            Should -Invoke powercfg -Times 1 -Exactly
        }
    }

    Context "Hardware tipo Desktop (ChassisType fuera de lista de portatiles)" {
        BeforeEach {
            Mock Get-CimInstance {
                [PSCustomObject]@{ ChassisTypes = @(3) }
            }
            Mock powercfg { }
            $global:LASTEXITCODE = 0
        }

        It "invoca powercfg /hibernate off para hardware desktop" {
            Invoke-PowerProfileOptimization
            Should -Invoke powercfg -Times 1 -Exactly
        }
    }

    Context "powercfg falla por falta de privilegios" {
        BeforeEach {
            Mock Get-CimInstance {
                [PSCustomObject]@{ ChassisTypes = @(10) }
            }
            Mock powercfg { $global:LASTEXITCODE = 5 }
        }

        It "lanza excepcion cuando powercfg retorna codigo distinto de 0" {
            { Invoke-PowerProfileOptimization } | Should -Throw "*codigo de salida 5*"
        }
    }
}
