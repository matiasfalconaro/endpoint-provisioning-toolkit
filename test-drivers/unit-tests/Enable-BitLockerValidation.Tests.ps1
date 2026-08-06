BeforeAll {
    # Asegura que Pester pueda declarar Mocks incluso en entornos sin el módulo BitLocker/RSAT cargado
    if (-not (Get-Command 'BackupToAAD-BitLockerKeyProtector' -ErrorAction SilentlyContinue)) {
        function global:BackupToAAD-BitLockerKeyProtector {}
    }
    . "$PSScriptRoot\..\..\src\security\Enable-BitLockerValidation.ps1"
}

Describe "Invoke-BitLockerValidation" {

    Context "Equipo On-Premise (solo dominio)" {
        BeforeEach {
            Mock Get-Tpm { [PSCustomObject]@{ TpmReady = $true } }
            Mock Get-BitLockerVolume { [PSCustomObject]@{ KeyProtector = @(); ProtectionStatus = 'Off' } }
            Mock Add-BitLockerKeyProtector { [PSCustomObject]@{ KeyProtectorId = '{TEST-KEY-ID}' } }
            Mock Invoke-DsregcmdStatus { "DomainJoined : YES`nAzureAdJoined : NO" }
            Mock Backup-BitLockerKeyProtector { }
            Mock BackupToAAD-BitLockerKeyProtector { }
            Mock Enable-BitLocker { }
        }

        It "respalda solo en Active Directory DS, no invoca el backup a Entra ID" {
            { Invoke-BitLockerValidation } | Should -Not -Throw
            Should -Invoke Backup-BitLockerKeyProtector -Times 1 -Exactly
            Should -Invoke BackupToAAD-BitLockerKeyProtector -Times 0 -Exactly
        }

        It "invoca Enable-BitLocker cuando el volumen está 'Off'" {
            Invoke-BitLockerValidation
            Should -Invoke Enable-BitLocker -Times 1 -Exactly
        }
    }

    Context "Equipo Hybrid (dominio Y Entra ID simultáneamente)" {
        BeforeEach {
            Mock Get-Tpm { [PSCustomObject]@{ TpmReady = $true } }
            Mock Get-BitLockerVolume { [PSCustomObject]@{ KeyProtector = @(); ProtectionStatus = 'Off' } }
            Mock Add-BitLockerKeyProtector { [PSCustomObject]@{ KeyProtectorId = '{TEST-KEY-ID}' } }
            Mock Invoke-DsregcmdStatus { "DomainJoined : YES`nAzureAdJoined : YES" }
            Mock Backup-BitLockerKeyProtector { }
            Mock BackupToAAD-BitLockerKeyProtector { }
            Mock Enable-BitLocker { }
        }

        It "invoca AMBOS backups (Active Directory Y Entra ID)" {
            Invoke-BitLockerValidation
            Should -Invoke Backup-BitLockerKeyProtector -Times 1 -Exactly
            Should -Invoke BackupToAAD-BitLockerKeyProtector -Times 1 -Exactly
        }
    }

    Context "Volumen ya cifrado (ProtectionStatus = On)" {
        BeforeEach {
            Mock Get-Tpm { [PSCustomObject]@{ TpmReady = $true } }
            Mock Get-BitLockerVolume { 
                [PSCustomObject]@{ 
                    KeyProtector = @(
                        [PSCustomObject]@{ KeyProtectorType = 'Tpm' },
                        [PSCustomObject]@{ KeyProtectorType = 'RecoveryPassword'; KeyProtectorId = '{TEST-KEY-ID}' }
                    )
                    ProtectionStatus = 'On' 
                } 
            }
            Mock Invoke-DsregcmdStatus { "DomainJoined : YES`nAzureAdJoined : NO" }
            Mock Backup-BitLockerKeyProtector { }
            Mock BackupToAAD-BitLockerKeyProtector { }
            Mock Enable-BitLocker { }
        }

        It "NO vuelve a invocar Enable-BitLocker si el volumen ya está 'On'" {
            Invoke-BitLockerValidation
            Should -Invoke Enable-BitLocker -Times 0 -Exactly
        }
    }

    Context "Equipo Hybrid/Cloud (solo Entra ID)" {
        BeforeEach {
            Mock Get-Tpm { [PSCustomObject]@{ TpmReady = $true } }
            Mock Get-BitLockerVolume { [PSCustomObject]@{ KeyProtector = @(); ProtectionStatus = 'Off' } }
            Mock Add-BitLockerKeyProtector { [PSCustomObject]@{ KeyProtectorId = '{TEST-KEY-ID}' } }
            Mock Invoke-DsregcmdStatus { "DomainJoined : NO`nAzureAdJoined : YES" }
            Mock BackupToAAD-BitLockerKeyProtector { }
            Mock Enable-BitLocker { }
        }

        It "invoca el backup a Entra ID correctamente" {
            { Invoke-BitLockerValidation } | Should -Not -Throw
            Should -Invoke BackupToAAD-BitLockerKeyProtector -Times 1 -Exactly
        }
    }

    Context "Equipo sin unión a dominio" {
        BeforeEach {
            Mock Get-Tpm { [PSCustomObject]@{ TpmReady = $true } }
            Mock Get-BitLockerVolume { [PSCustomObject]@{ KeyProtector = @(); ProtectionStatus = 'Off' } }
            Mock Add-BitLockerKeyProtector { [PSCustomObject]@{ KeyProtectorId = '{TEST-KEY-ID}' } }
            Mock Invoke-DsregcmdStatus { "DomainJoined : NO`nAzureAdJoined : NO" }
        }

        It "aborta lanzando excepción sin intentar respaldar ni activar cifrado" {
            { Invoke-BitLockerValidation } | Should -Throw "*No se pudo respaldar la clave*"
        }
    }

    Context "TPM no listo" {
        BeforeEach {
            Mock Get-Tpm { [PSCustomObject]@{ TpmReady = $false } }
        }

        It "aborta de inmediato sin invocar ningún cmdlet de BitLocker" {
            { Invoke-BitLockerValidation } | Should -Throw "*dTPM 2.0 no está listo*"
        }
    }
}
