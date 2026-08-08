BeforeAll {
    . "$PSScriptRoot\..\..\src\maintenance\Invoke-LenovoDriveWipe.ps1"
}

Describe "Invoke-LenovoDriveWipe" {

    Context "Proveedor CIM de Lenovo no disponible" {
        BeforeEach {
            Mock Get-CimClass { $null }
        }

        It "aborta si el proveedor WMI de Lenovo no esta presente" {
            $SecurePass = ConvertTo-SecureString "Test123" -AsPlainText -Force
            { Invoke-SecureDriveWipe -SupervisorPassword $SecurePass } | Should -Throw "*Lenovo*no esta disponible*"
        }
    }

    Context "Flujo exitoso de borrado seguro" {
        BeforeEach {
            Mock Get-CimClass { [PSCustomObject]@{ CimClassName = 'Lenovo_SetBiosSetting' } }
            Mock Invoke-CimMethod { [PSCustomObject]@{ return = "Success" } }
        }

        It "completa el flujo sin excepcion cuando todos los pasos WMI retornan Success" {
            $SecurePass = ConvertTo-SecureString "Test123" -AsPlainText -Force
            { Invoke-SecureDriveWipe -SupervisorPassword $SecurePass } | Should -Not -Throw
            Should -Invoke Invoke-CimMethod -Times 3 -Exactly
        }
    }

    Context "Fallo al habilitar SecureWipe en BIOS" {
        BeforeEach {
            Mock Get-CimClass { [PSCustomObject]@{ CimClassName = 'Lenovo_SetBiosSetting' } }
            Mock Invoke-CimMethod { [PSCustomObject]@{ return = "AccessDenied" } }
        }

        It "lanza excepcion si SecureWipe no se puede habilitar" {
            $SecurePass = ConvertTo-SecureString "Test123" -AsPlainText -Force
            { Invoke-SecureDriveWipe -SupervisorPassword $SecurePass } | Should -Throw "*SecureWipe*"
        }
    }

    Context "Fallo de autenticacion con contrasena de Supervisor" {
        BeforeEach {
            Mock Get-CimClass { [PSCustomObject]@{ CimClassName = 'Lenovo_SetBiosSetting' } }
            $script:CallCount = 0
            Mock Invoke-CimMethod {
                $script:CallCount++
                if ($script:CallCount -eq 1) {
                    [PSCustomObject]@{ return = "Success" }  # SecureWipe ok
                } else {
                    [PSCustomObject]@{ return = "AccessDenied" }  # Auth falla
                }
            }
        }

        It "lanza excepcion si la autenticacion de Supervisor falla" {
            $SecurePass = ConvertTo-SecureString "WrongPass" -AsPlainText -Force
            { Invoke-SecureDriveWipe -SupervisorPassword $SecurePass } | Should -Throw "*Autenticacion*"
        }
    }
}
