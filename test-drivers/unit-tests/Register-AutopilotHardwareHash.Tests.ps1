<#
.SYNOPSIS
    Cobertura unitaria aislada de src/provisioning/Register-AutopilotHardwareHash.ps1
    (Sección 6.4 — flujo paralelo Autopilot).
#>
BeforeAll {
    function Write-DeploymentLog { param($Level, $Message) }
    function Get-WindowsAutoPilotInfo { param($OutputFile) }
    . "$PSScriptRoot\..\..\src\provisioning\Register-AutopilotHardwareHash.ps1" -SkipExecution
    Mock Write-DeploymentLog {}
}

Describe 'Register-AutopilotHardwareHash' {

    Context 'Cuando la captura genera el CSV correctamente' {
        BeforeEach {
            Mock Get-WindowsAutoPilotInfo {}
            Mock Test-Path { return $true }
        }
        It 'Retorna exit 0 y registra la ruta de salida' {
            Register-AutopilotHardwareHash -CsvOutputPath 'C:\Temp\hwid.csv'
            Should -Invoke Write-DeploymentLog -ParameterFilter { $Message -match 'C:\\Temp\\hwid.csv' }
        }
    }

    Context 'Cuando Get-WindowsAutoPilotInfo no genera el archivo esperado' {
        BeforeEach {
            Mock Get-WindowsAutoPilotInfo {}
            Mock Test-Path { return $false }
        }
        It 'Registra error y aborta con exit 1' {
            { Register-AutopilotHardwareHash -CsvOutputPath 'C:\Temp\hwid.csv' } | Should -Throw
            Should -Invoke Write-DeploymentLog -ParameterFilter { $Level -eq 'Error' }
        }
    }

    Context 'Cuando el módulo Get-WindowsAutoPilotInfo no está disponible' {
        BeforeEach {
            Mock Get-WindowsAutoPilotInfo { throw 'CommandNotFoundException' }
        }
        It 'Propaga la excepción de dependencia faltante' {
            { Register-AutopilotHardwareHash -CsvOutputPath 'C:\Temp\hwid.csv' } | Should -Throw
        }
    }

    Context 'Parámetro obligatorio -CsvOutputPath' {
        It 'Falla si no se provee la ruta de salida' {
            { Register-AutopilotHardwareHash } | Should -Throw
        }
    }
}
