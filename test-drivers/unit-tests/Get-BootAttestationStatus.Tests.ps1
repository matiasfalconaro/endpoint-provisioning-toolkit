BeforeAll {
    . "$PSScriptRoot\..\..\src\security\Get-BootAttestationStatus.ps1"
}

Describe "Get-BootAttestationStatus" {

    Context "Analisis de capacidad TPM via tpmtool" {
        It "parsea correctamente la salida de tpmtool.exe (array de lineas, fiel a la salida real)" {
            Mock Invoke-TpmToolGetInfo {
                @(
                    "Is Capable For Attestation : True",
                    "Ready For Attestation     : True"
                )
            }
            $Result = Get-TpmAttestationCapability
            $Result.IsCapableForAttestation | Should -BeTrue
            $Result.ReadyForAttestation | Should -BeTrue
        }

        It "retorna null si tpmtool no devuelve datos" {
            Mock Invoke-TpmToolGetInfo { $null }
            Get-TpmAttestationCapability | Should -BeNullOrEmpty
        }
    }

    Context "Evaluacion de politicas de seguridad en el arranque" {
        BeforeEach {
            Mock Confirm-SecureBootUEFI { $true }
            Mock Get-Tpm { [PSCustomObject]@{ TpmPresent = $true; TpmReady = $true; TpmEnabled = $true; TpmOwned = $true; AutoProvisioning = $true } }
            Mock Get-TpmAttestationCapability { [PSCustomObject]@{ IsCapableForAttestation = $true; ReadyForAttestation = $true } }
            Mock Test-MeasuredBootLogPresent { $true }
        }

        It "retorna el objeto de reporte si todos los controles de seguridad pasan" {
            $Report = Invoke-BootAttestationStatus
            $Report.SecureBootEnabled | Should -BeTrue
            $Report.AttestationCapable | Should -BeTrue
            $Report.MeasuredBootLogPresent | Should -BeTrue
        }

        It "lanza excepcion si Secure Boot esta deshabilitado" {
            Mock Confirm-SecureBootUEFI { $false }
            { Invoke-BootAttestationStatus } | Should -Throw "*Secure Boot se encuentra DESHABILITADO*"
        }

        It "lanza excepcion si el TPM no esta listo" {
            Mock Get-Tpm { [PSCustomObject]@{ TpmPresent = $true; TpmReady = $false; TpmEnabled = $true; TpmOwned = $true; AutoProvisioning = $true } }
            { Invoke-BootAttestationStatus } | Should -Throw "*dTPM 2.0 no*listo*"
        }

        It "lanza excepcion si el chip dTPM no tiene capacidad de atestacion" {
            Mock Get-TpmAttestationCapability { [PSCustomObject]@{ IsCapableForAttestation = $false; ReadyForAttestation = $false } }
            { Invoke-BootAttestationStatus } | Should -Throw "*no soporta Atestac*n de Hardware*"
        }

        It "lanza excepcion si tpmtool no esta disponible o no devuelve datos" {
            Mock Get-TpmAttestationCapability { $null }
            { Invoke-BootAttestationStatus } | Should -Throw "*no soporta Atestac*n de Hardware*"
        }
    }
}
