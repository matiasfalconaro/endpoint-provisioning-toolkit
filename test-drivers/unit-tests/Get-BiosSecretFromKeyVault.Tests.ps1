<#
.SYNOPSIS
    Cobertura unitaria aislada de src/bios/workflows/Get-BiosSecretFromKeyVault.ps1
    (Anexo B, Opción C.1 — Sección 18.2a).
#>
BeforeAll {
    function Write-DeploymentLog { param($Level, $Message) }
    function Get-AzKeyVaultSecret { param($VaultName, $Name, $AsPlainText) }
    . "$PSScriptRoot\..\..\src\bios\workflows\Get-BiosSecretFromKeyVault.ps1" -SkipExecution
    Mock Write-DeploymentLog {}
}

Describe 'Get-BiosSecretFromKeyVault' {

    Context 'Cuando Key Vault devuelve un secreto válido' {
        BeforeEach {
            $secureStub = ConvertTo-SecureString 'DummyValue' -AsPlainText -Force
            Mock Get-AzKeyVaultSecret {
                return [PSCustomObject]@{ SecretValue = $secureStub }
            }
        }
        It 'Retorna un objeto SecureString' {
            $result = Get-BiosSecretFromKeyVault -VaultName 'vault-infra' -SecretName 'bios-supervisor'
            $result | Should -BeOfType [System.Security.SecureString]
        }
        It 'No escribe el valor en texto plano en ningún log' {
            Get-BiosSecretFromKeyVault -VaultName 'vault-infra' -SecretName 'bios-supervisor'
            Should -Invoke Write-DeploymentLog -ParameterFilter { $Message -notmatch 'DummyValue' }
        }
    }

    Context 'Cuando Key Vault no devuelve secreto (null)' {
        BeforeEach {
            Mock Get-AzKeyVaultSecret { return $null }
        }
        It 'Registra error y aborta con exit 1' {
            { Get-BiosSecretFromKeyVault -VaultName 'vault-infra' -SecretName 'bios-supervisor' } | Should -Throw
            Should -Invoke Write-DeploymentLog -ParameterFilter { $Level -eq 'Error' }
        }
    }

    Context 'Cuando la llamada a Key Vault lanza excepción (fallo de Managed Identity)' {
        BeforeEach {
            Mock Get-AzKeyVaultSecret { throw 'AADSTS700016: identity not found' }
        }
        It 'Propaga el fallo y registra el error sin exponer detalles sensibles del token' {
            { Get-BiosSecretFromKeyVault -VaultName 'vault-infra' -SecretName 'bios-supervisor' } | Should -Throw
            Should -Invoke Write-DeploymentLog -ParameterFilter { $Level -eq 'Error' }
        }
    }

    Context 'Parámetros obligatorios' {
        It 'Exige -VaultName' {
            { Get-BiosSecretFromKeyVault -SecretName 'bios-supervisor' } | Should -Throw
        }
        It 'Exige -SecretName' {
            { Get-BiosSecretFromKeyVault -VaultName 'vault-infra' } | Should -Throw
        }
    }
}
