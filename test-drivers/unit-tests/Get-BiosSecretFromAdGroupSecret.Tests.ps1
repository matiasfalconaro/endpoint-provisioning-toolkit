<#
.SYNOPSIS
    Cobertura unitaria aislada de src/bios/workflows/Get-BiosSecretFromAdGroupSecret.ps1
    (Anexo B, Opción C.2 — Sección 18.2a).
#>
BeforeAll {
    function Write-DeploymentLog { param($Level, $Message) }
    function Get-ADComputer { param($Identity, $Properties) }
    . "$PSScriptRoot\..\..\src\bios\workflows\Get-BiosSecretFromAdGroupSecret.ps1" -SkipExecution
    Mock Write-DeploymentLog {}
}

Describe 'Get-BiosSecretFromAdGroupSecret' {

    Context 'Cuando el atributo msDS-BiosSupervisorSecret está poblado' {
        BeforeEach {
            Mock Get-ADComputer {
                return [PSCustomObject]@{
                    'msDS-BiosSupervisorSecret' = 'EncryptedStubValue=='
                }
            }
        }
        It 'Retorna un SecureString' {
            $result = Get-BiosSecretFromAdGroupSecret -ComputerObjectDN 'CN=WS-001,OU=Workstations,DC=empresa,DC=local'
            $result | Should -BeOfType [System.Security.SecureString]
        }
    }

    Context 'Cuando el atributo está vacío (esquema no homologado)' {
        BeforeEach {
            Mock Get-ADComputer {
                return [PSCustomObject]@{ 'msDS-BiosSupervisorSecret' = $null }
            }
        }
        It 'Registra error indicando esquema no homologado y aborta' {
            { Get-BiosSecretFromAdGroupSecret -ComputerObjectDN 'CN=WS-001,OU=Workstations,DC=empresa,DC=local' } | Should -Throw
            Should -Invoke Write-DeploymentLog -ParameterFilter { $Level -eq 'Error' -and $Message -match 'msDS-BiosSupervisorSecret' }
        }
    }

    Context 'Cuando el objeto de equipo no existe en AD DS' {
        BeforeEach {
            Mock Get-ADComputer { throw 'ADIdentityNotFoundException' }
        }
        It 'Propaga la falla sin persistir ningún valor local' {
            { Get-BiosSecretFromAdGroupSecret -ComputerObjectDN 'CN=NoExiste,DC=empresa,DC=local' } | Should -Throw
        }
    }

    Context 'Parámetro obligatorio -ComputerObjectDN' {
        It 'Falla si no se provee el DN' {
            { Get-BiosSecretFromAdGroupSecret } | Should -Throw
        }
    }
}
