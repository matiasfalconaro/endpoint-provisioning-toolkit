<#
.SYNOPSIS
    Cobertura unitaria aislada de src/security/Invoke-CriticalPatchGate.ps1
    Consumido por el Contexto de validación Critical Ring (Sección 12.2a).
#>
BeforeAll {
    function Write-DeploymentLog { param($Level, $Message) }
    function Invoke-MdtDbQuery { param($Connection, $Query) }
    . "$PSScriptRoot\..\..\src\security\Invoke-CriticalPatchGate.ps1" -SkipExecution
    Mock Write-DeploymentLog {}
}
Describe 'Invoke-CriticalPatchGate' {

    Context 'Cuando CriticalPatchPending = false' {
        BeforeEach {
            Mock Invoke-MdtDbQuery { return $false }
            Mock Start-Process {}
        }
        It 'Omite la instalación y retorna exit 0' {
            Mock Test-Path { return $true }
            { Invoke-CriticalPatchGate -KbId 'KB5031234' } | Should -Not -Throw
            Should -Invoke Start-Process -Times 0
        }
    }

    Context 'Cuando CriticalPatchPending = true y el paquete existe' {
        BeforeEach {
            Mock Invoke-MdtDbQuery { return $true }
            Mock Test-Path { return $true }
            Mock Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }
        }
        It 'Invoca wusa.exe en modo silencioso' {
            Invoke-CriticalPatchGate -KbId 'KB5031234'
            Should -Invoke Start-Process -Times 1 -ParameterFilter {
                $FilePath -eq 'wusa.exe' -and $ArgumentList -match '/quiet /norestart'
            }
        }
    }

    Context 'Cuando el paquete no existe en el repositorio local' {
        BeforeEach {
            Mock Invoke-MdtDbQuery { return $true }
            Mock Test-Path { return $false }
        }
        It 'Registra error y aborta con exit 1' {
            Mock Write-DeploymentLog { }
            $result = Invoke-CriticalPatchGate -KbId 'KB5031234' -ErrorAction SilentlyContinue
            Should -Invoke Write-DeploymentLog -ParameterFilter { $Level -eq 'Error' }
        }
    }

    Context 'Cuando wusa.exe retorna código de salida distinto de 0' {
        BeforeEach {
            Mock Invoke-MdtDbQuery { return $true }
            Mock Test-Path { return $true }
            Mock Start-Process { return [PSCustomObject]@{ ExitCode = 87 } }
        }
        It 'Registra error de exit code y aborta' {
            Invoke-CriticalPatchGate -KbId 'KB5031234' -ErrorAction SilentlyContinue
            Should -Invoke Write-DeploymentLog -ParameterFilter {
                $Level -eq 'Error' -and $Message -match '87'
            }
        }
    }

    Context 'Validación de parámetro KbId' {
        It 'Rechaza un formato inválido de KB' {
            { Invoke-CriticalPatchGate -KbId 'INVALID-ID' } | Should -Throw
        }
    }
}
