<#
.SYNOPSIS
    Cobertura unitaria aislada de src/testing/Get-TouchlessComplianceRate.ps1
    (Sección 16.2 — métrica agregada mensual de cumplimiento Touchless).
#>
BeforeAll {
    function Write-DeploymentLog { param($Level, $Message) }
    . "$PSScriptRoot\..\..\src\testing\Get-TouchlessComplianceRate.ps1" -SkipExecution
    Mock Write-DeploymentLog {}
}

Describe 'Get-TouchlessComplianceRate' {

    Context 'Cuando todos los equipos pasan sin excepciones ni fallos' {
        BeforeEach {
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ FullName = 'r1.xml'; LastWriteTime = [datetime]'2026-08-05' }
                    [PSCustomObject]@{ FullName = 'r2.xml'; LastWriteTime = [datetime]'2026-08-06' }
                )
            }
            Mock Get-Content { '<Report><Context name="TouchlessAudit" status="Passed"/><Context name="OobeInteractionAudit" status="Passed"/></Report>' }
        }
        It 'Retorna ComplianceRate = 100' {
            $result = Get-TouchlessComplianceRate -ReportsPath 'C:\Logs' -Month '2026-08'
            $result.ComplianceRate | Should -Be 100
            $result.TotalEquipos | Should -Be 2
        }
    }

    Context 'Cuando hay un fallo NO autorizado (sin ticket asociado)' {
        BeforeEach {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ FullName = 'r1.xml'; LastWriteTime = [datetime]'2026-08-05' })
            }
            Mock Get-Content { '<Report><Context name="TouchlessAudit" status="Failed"/></Report>' }
        }
        It 'Cuenta el equipo como FallosNoAutorizados y penaliza el ComplianceRate' {
            $result = Get-TouchlessComplianceRate -ReportsPath 'C:\Logs' -Month '2026-08'
            $result.FallosNoAutorizados | Should -Be 1
            $result.ComplianceRate | Should -Be 0
        }
    }

    Context 'Cuando hay un fallo con ticket de incidente autorizado (Sección 13.2, Contexto 8)' {
        BeforeEach {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ FullName = 'r1.xml'; LastWriteTime = [datetime]'2026-08-05' })
            }
            Mock Get-Content { '<Report><Context name="TouchlessAudit" status="Failed"/><IncidentTicketRef>INC-00123</IncidentTicketRef></Report>' }
        }
        It 'Excluye el equipo del cálculo y no penaliza el ComplianceRate' {
            $result = Get-TouchlessComplianceRate -ReportsPath 'C:\Logs' -Month '2026-08'
            $result.Excepciones | Should -Be 1
            $result.FallosNoAutorizados | Should -Be 0
            $result.ComplianceRate | Should -Be 100
        }
    }

    Context 'Cuando no existen reportes para el mes solicitado' {
        BeforeEach {
            Mock Get-ChildItem { return @() }
        }
        It 'Registra una advertencia y no lanza excepción' {
            Get-TouchlessComplianceRate -ReportsPath 'C:\Logs' -Month '2099-01'
            Should -Invoke Write-DeploymentLog -ParameterFilter { $Level -eq 'Warn' }
        }
    }

    Context 'Validación del parámetro -Month' {
        It 'Rechaza un formato inválido de mes' {
            { Get-TouchlessComplianceRate -ReportsPath 'C:\Logs' -Month '08-2026' } | Should -Throw
        }
    }
}
