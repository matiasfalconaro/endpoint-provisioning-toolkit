BeforeAll {
    # 1. Credenciales y rutas ficticias para ejecución segura
    $Script:TestSecurePass = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
    $Script:FakeKeyPath   = "C:\IT_Deployment\BiosPassword.key"
    $Script:FakeConfigPath = "C:\IT_Deployment\Baseline.ini"

    # Stub para cmdlets externos de módulos Lenovo no instalados localmente
    if (-not (Get-Command Set-ThinkBiosConfig -ErrorAction SilentlyContinue)) {
        function global:Set-ThinkBiosConfig {}
    }

    # 2. Carga por dot-sourcing
    $WorkflowsDir = Resolve-Path "$PSScriptRoot/../../src/bios/workflows"
    . (Join-Path $WorkflowsDir "New-BiosEncryptedSecret.ps1")
    . (Join-Path $WorkflowsDir "Set-LenovoBiosWithDpapi.ps1")
    . (Join-Path $WorkflowsDir "Set-LenovoBiosWithThinkBios.ps1")
}

Describe "Workflow: New-BiosEncryptedSecret" {
    Context "Invoke-BiosSecretGeneration" {
        It "Debe crear el directorio de destino si no existe y escribir el secreto" {
            Mock Test-Path { $false }
            Mock New-Item {}
            Mock Invoke-DpapiProtect { [byte[]]@(1, 2, 3) }
            Mock Invoke-FileWriteAllBytes {}

            {
                Invoke-BiosSecretGeneration -BiosPassword $Script:TestSecurePass -OutputPath $Script:FakeKeyPath
            } | Should -Not -Throw

            Should -Invoke -CommandName Test-Path -Times 1 -Exactly
            Should -Invoke -CommandName New-Item -Times 1 -Exactly
            Should -Invoke -CommandName Invoke-DpapiProtect -Times 1 -Exactly
            Should -Invoke -CommandName Invoke-FileWriteAllBytes -Times 1 -Exactly
        }

        It "Debe propagar la excepción mediante throw si falla la escritura del archivo" {
            Mock Test-Path { $true }
            Mock Invoke-DpapiProtect { [byte[]]@(1, 2, 3) }
            Mock Invoke-FileWriteAllBytes { throw "Acceso Denegado al Disco" }

            {
                Invoke-BiosSecretGeneration -BiosPassword $Script:TestSecurePass -OutputPath $Script:FakeKeyPath
            } | Should -Throw "*Error al generar el secreto cifrado*"
        }
    }
}

Describe "Workflow: Set-LenovoBiosWithDpapi" {
    Context "Invoke-LenovoBiosWithDpapi" {
        It "Debe lanzar excepción no manejada si el archivo de clave cifrada no existe" {
            Mock Test-Path { $false }

            {
                Invoke-LenovoBiosWithDpapi -KeyPath $Script:FakeKeyPath
            } | Should -Throw "*No se encontro el archivo de secreto cifrado*"
        }

        It "Debe continuar y aplicar el resto si falla un parametro individual opcional" {
            Mock Test-Path { $true }
            Mock Get-Content { "ContenidoBase64Simulado" }
            Mock ConvertTo-SecureString { $Script:TestSecurePass }

            Mock Invoke-CimMethod {
                param($MethodName, $Arguments)
                
                $ParamValue = if ($Arguments -and $Arguments.ContainsKey('Parameter')) { $Arguments['Parameter'] } else { $Arguments.Parameter }
                
                if ($ParamValue -like "WakeOnLAN*") {
                    return [PSCustomObject]@{ return = "NotSupported" }
                }
                return [PSCustomObject]@{ return = "Success" }
            }

            {
                Invoke-LenovoBiosWithDpapi -KeyPath $Script:FakeKeyPath
            } | Should -Not -Throw

            Should -Invoke -CommandName Invoke-CimMethod -ParameterFilter { $MethodName -eq 'SetBiosSetting' }
            Should -Invoke -CommandName Invoke-CimMethod -ParameterFilter { $MethodName -eq 'SaveBiosSettings' } -Times 1 -Exactly
        }

        It "Debe abortar con throw si falla la inyeccion de la contraseña de Supervisor" {
            Mock Test-Path { $true }
            Mock Get-Content { "ContenidoBase64Simulado" }
            Mock ConvertTo-SecureString { $Script:TestSecurePass }

            Mock Invoke-CimMethod {
                param($MethodName, $Arguments)
                
                $ParamValue = if ($Arguments -and $Arguments.ContainsKey('Parameter')) { $Arguments['Parameter'] } else { $Arguments.Parameter }

                if ($ParamValue -like "Supervisor Password*") {
                    return [PSCustomObject]@{ return = "InvalidPassword" }
                }
                return [PSCustomObject]@{ return = "Success" }
            }

            {
                Invoke-LenovoBiosWithDpapi -KeyPath $Script:FakeKeyPath
            } | Should -Throw "*No se pudo establecer la contrasena de Supervisor*"
        }
    }
}

Describe "Workflow: Set-LenovoBiosWithThinkBios" {
    Context "Invoke-ThinkBiosConfig" {
        It "Debe cargar el modulo si no esta presente e invocar Set-ThinkBiosConfig" {
            Mock Test-Path { $true }
            Mock Get-Module { $null }
            Mock Import-Module {}
            Mock Set-ThinkBiosConfig {}

            {
                Invoke-ThinkBiosConfig -ConfigFile $Script:FakeConfigPath
            } | Should -Not -Throw

            Should -Invoke -CommandName Import-Module -Times 1 -Exactly
            Should -Invoke -CommandName Set-ThinkBiosConfig -Times 1 -Exactly
        }

        It "Debe hacer throw y propagar el error si Set-ThinkBiosConfig lanza una falla" {
            Mock Test-Path { $true }
            Mock Get-Module { @{ Name = "ThinkBios-Config" } }
            Mock Set-ThinkBiosConfig { throw "Fallo de driver o proveedor WMI" }

            {
                Invoke-ThinkBiosConfig -ConfigFile $Script:FakeConfigPath
            } | Should -Throw "*Error critico al aplicar la configuracion con ThinkBios-Config*"
        }
    }
}
