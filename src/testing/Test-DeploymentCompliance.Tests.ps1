<#
.SYNOPSIS
    Suite de Pruebas de Cumplimiento Post-Aprovisionamiento Pester (Zero-Touch Validation).
.DESCRIPTION
    Audita la postura de seguridad, parches, licenciamiento ESU, estado de BitLocker, EDR,
    firmas de código e higiene de credenciales del endpoint recién aprovisionado.
.PARAMETER DeploymentRoot
    Ruta a la carpeta src/ del repositorio de despliegue. MECANISMO RECOMENDADO:
    pasarla explícitamente vía New-PesterContainer -Data desde quien invoca Pester
    (ej. Invoke-PostDeploymentTest.ps1), ya que $PSScriptRoot no se propaga de
    forma confiable dentro del modelo de ejecución interno de Pester v5+. Si se
    omite, se intenta una cadena de resolución automática (PSScriptRoot,
    PSCommandPath, MyInvocation, directorio actual) como mejor esfuerzo, pero
    puede dar Skip si ninguna resuelve correctamente.
    fase de Discovery y la fase de Run de Pester v5+.
.EXAMPLE
    Invoke-Pester -Path ".\src\testing\Test-DeploymentCompliance.Tests.ps1" -Output Detailed
.EXAMPLE
    $Container = New-PesterContainer -Path ".\src\testing\Test-DeploymentCompliance.Tests.ps1" `
        -Data @{ DeploymentRoot = "\\NAS-CORP01\Deployment\Scripts\src" }
    Invoke-Pester -Container $Container
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$DeploymentRoot
)


Describe "Auditoría Global de Conformidad de Infraestructura" {

    Context "1. Seguridad de Firmware y Arranque Seguro" {
        It "Secure Boot debe estar habilitado en el firmware UEFI" {
            $SecureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
            $SecureBoot | Should -BeTrue
        }

        It "El microcontrolador dTPM 2.0 debe estar presente y listo" {
            $Tpm = Get-Tpm -ErrorAction SilentlyContinue
            $Tpm.TpmPresent | Should -BeTrue
            $Tpm.TpmReady | Should -BeTrue
        }

        It "El soporte de Device Health Attestation (Measured Boot) debe estar disponible" {
            $Tpm = Get-Tpm -ErrorAction SilentlyContinue
            $Tpm.IsCapPresent("Attestation") | Should -BeTrue
        }
    }

    Context "2. Cifrado de Unidad BitLocker y Respaldado de Claves" {
        It "El volumen del sistema (C:) debe estar cifrado con XTS-AES 256" {
            $BitLocker = Get-BitLockerVolume -MountPoint $env:SystemDrive
            $BitLocker.ProtectionStatus | Should -Be "On"
            $BitLocker.EncryptionMethod | Should -Be "XtsAes256"
        }

        It "Debe existir un protector dTPM y una Clave de Recuperación de 48 dígitos" {
            $BitLocker = Get-BitLockerVolume -MountPoint $env:SystemDrive
            $Protectors = $BitLocker.KeyProtector.KeyProtectorType
            $Protectors | Should -Contain "Tpm"
            $Protectors | Should -Contain "RecoveryPassword"
        }
    }

    Context "3. Postura de Antivirus, EDR y XDR (Microsoft Defender)" {
        It "Microsoft Defender Antivirus debe estar activo y con protección en tiempo real" {
            $Defender = Get-MpComputerStatus
            $Defender.AntivirusEnabled | Should -BeTrue
            $Defender.RealTimeProtectionEnabled | Should -BeTrue
        }

        It "El servicio EDR Defender for Endpoint (Sense) debe estar ejecutándose" {
            $Sense = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
            $Sense.Status | Should -Be "Running"
            $Sense.StartType | Should -Be "Automatic"
        }
    }

    Context "4. Firma de Código e Integridad PowerShell (Authenticode)" {

        It "La política de ejecución de PowerShell debe ser AllSigned" {
            $Policy = Get-ExecutionPolicy
            $Policy | Should -Be "AllSigned"
        }

        It "Todos los scripts desplegados en src/ deben tener firma Authenticode válida" {
            if (-not $DeploymentRoot -or -not (Test-Path $DeploymentRoot)) {
                Set-ItResult -Skipped -Because "DeploymentRoot no fue provisto o no es accesible. Debe pasarse via New-PesterContainer -Data @{ DeploymentRoot = '...' }"
                return
            }

            $Scripts = Get-ChildItem -Path $DeploymentRoot -Filter "*.ps1" -Recurse
            $Unsigned = foreach ($Script in $Scripts) {
                $Signature = Get-AuthenticodeSignature -FilePath $Script.FullName
                if ($Signature.Status -ne 'Valid') {
                    [PSCustomObject]@{ Path = $Script.FullName; Status = $Signature.Status }
                }
            }

            # Se calcula el mensaje ANTES del Should, evitando el if/else inline dentro
            # de -Because, que generaba un error de parseo ambiguo en PowerShell/Pester
            # ("The term 'if' is not recognized as the name of a cmdlet").
            $Reason = if ($Unsigned) {
                "los siguientes scripts no tienen firma Authenticode valida: " +
                (($Unsigned | ForEach-Object { "$($_.Path) [$($_.Status)]" }) -join "; ")
            } else {
                "todos los scripts tienen firma valida"
            }

            $Unsigned | Should -BeNullOrEmpty -Because $Reason
        }
    }

    Context "5. Higiene de Credenciales y Purga de AutoLogon" {
        It "No deben existir credenciales de AutoLogon en texto plano en el Registro" {
            $Winlogon = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue
            $Winlogon.AutoAdminLogon    | Should -Not -Be "1"
            $Winlogon.DefaultPassword   | Should -BeNullOrEmpty
            $Winlogon.AutoLogonCount    | Should -BeNullOrEmpty
            $Winlogon.DefaultUserName   | Should -BeNullOrEmpty
            $Winlogon.DefaultDomainName | Should -BeNullOrEmpty
        }

        It "Ningún archivo de respuesta desatendida (unattend.xml) debe persistir en ninguna ubicación conocida" {
            $UnattendPaths = @(
                "$env:SystemRoot\Panther\unattend.xml",
                "$env:SystemRoot\Panther\Unattend\unattend.xml",
                "$env:SystemRoot\System32\Sysprep\unattend.xml",
                "C:\unattend.xml"
            )

            foreach ($Path in $UnattendPaths) {
                Test-Path -Path $Path | Should -BeFalse -Because "el archivo '$Path' no debería persistir tras la purga de AutoLogon"
            }
        }
    }

    Context "6. Mantenimiento y Ciclo de Vida (Licenciamiento ESU / Salud SSD)" {
        It "El sistema operativo debe mantener un estado de licencia activo" {
            $License = Get-CimInstance -ClassName "SoftwareLicensingProduct" | Where-Object { $_.PartialProductKey -and $_.LicenseStatus -eq 1 }
            $License | Should -Not -BeNullOrEmpty
        }

        It "No deben quedar workspaces efímeros o instaladores temporales en C:\" {
            $TempFolderExists = Test-Path -Path "C:\IT_Deployment_*"
            $TempFolderExists | Should -BeFalse
        }
    }
}
