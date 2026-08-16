<#
.SYNOPSIS
    Cobertura unitaria aislada del Contexto 9 (auditoría de interacción OOBE),
    consumido por Test-DeploymentCompliance.Tests.ps1 (Sección 16.2).
#>
BeforeAll {
    . "$PSScriptRoot\..\..\src\testing\Test-OobeInteractionAudit.ps1"
}

Describe 'Invoke-OobeInteractionAudit' {

    BeforeAll {
        $windowStart = (Get-Date).AddMinutes(-30)
        $windowEnd   = Get-Date
    }

    Context 'Cuando el proveedor Shell-Core no está disponible en el hardware' {
        BeforeEach {
            Mock Get-WinEvent { $null } -ParameterFilter { $ListProvider -eq 'Microsoft-Windows-Shell-Core' }
        }
        It 'Degrada a estado Skipped (no falla silenciosa)' {
            $result = Invoke-OobeInteractionAudit -WindowStart $windowStart -WindowEnd $windowEnd
            $result.Status | Should -Be 'Skipped'
        }
    }

    Context 'Cuando el proveedor está disponible y no hay eventos EventID 7001 en la ventana' {
        BeforeEach {
            Mock Get-WinEvent { return @{ Name = 'Microsoft-Windows-Shell-Core' } } -ParameterFilter { $ListProvider }
            Mock Get-WinEvent { return @() } -ParameterFilter { $FilterHashtable }
        }
        It 'Retorna estado Passed' {
            $result = Invoke-OobeInteractionAudit -WindowStart $windowStart -WindowEnd $windowEnd
            $result.Status | Should -Be 'Passed'
        }
    }

    Context 'Cuando se detecta al menos un evento EventID 7001 dentro de la ventana' {
        BeforeEach {
            Mock Get-WinEvent { return @{ Name = 'Microsoft-Windows-Shell-Core' } } -ParameterFilter { $ListProvider }
            Mock Get-WinEvent {
                return @(
                    [PSCustomObject]@{ Id = 7001; TimeCreated = (Get-Date).AddMinutes(-10) }
                )
            } -ParameterFilter { $FilterHashtable }
        }
        It 'Retorna estado Failed con el conteo de eventos detectados' {
            $result = Invoke-OobeInteractionAudit -WindowStart $windowStart -WindowEnd $windowEnd
            $result.Status | Should -Be 'Failed'
            $result.Reason | Should -Match '1 evento'
        }
    }

    Context 'Cuando Get-WinEvent lanza una excepción durante la consulta' {
        BeforeEach {
            Mock Get-WinEvent { return @{ Name = 'Microsoft-Windows-Shell-Core' } } -ParameterFilter { $ListProvider }
            Mock Get-WinEvent { throw 'EventLogException' } -ParameterFilter { $FilterHashtable }
        }
        It 'Degrada a estado Skipped en lugar de propagar la excepción' {
            $result = Invoke-OobeInteractionAudit -WindowStart $windowStart -WindowEnd $windowEnd
            $result.Status | Should -Be 'Skipped'
        }
    }
}
