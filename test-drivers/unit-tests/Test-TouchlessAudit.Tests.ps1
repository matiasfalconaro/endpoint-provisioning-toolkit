BeforeAll {
    function Get-InteractiveLogonEvents {
        param($BootTime)

        $SecurityEvents = Get-WinEvent -FilterHashtable @{
            LogName   = 'Security'
            Id        = 4624
            StartTime = $BootTime
        } -ErrorAction SilentlyContinue

        if ($null -eq $SecurityEvents) { return $null }

        $SecurityEvents | Where-Object {
            $xml = [xml]$_.ToXml()
            $LogonType = ($xml.Event.EventData.Data | Where-Object { $_.GetAttribute('Name') -eq 'LogonType' }).'#text'
            $LogonType -eq '2'
        }
    }
}

Describe "Context 8 - Auditoria Touchless (LogonType interactivo)" {

    Context "Sin eventos de logon interactivo (despliegue Zero-Touch limpio)" {
        BeforeEach {
            Mock Get-WinEvent {
                # Se agrega una propiedad real (Id) ademas del metodo ToXml: un
                # PSCustomObject sin propiedades de datos es tratado como "vacio"
                # por Should -BeNullOrEmpty en Pester v6, aunque tenga metodos.
                $FakeEvent = [PSCustomObject]@{ Id = 4624 }
                $FakeEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                    '<Event><EventData><Data Name="LogonType">5</Data></EventData></Event>'
                }
                @($FakeEvent)
            }
        }

        It "no detecta logons interactivos cuando todos los eventos son de tipo Service" {
            $Result = Get-InteractiveLogonEvents -BootTime (Get-Date)
            $Result | Should -BeNullOrEmpty
        }
    }

    Context "Con un logon interactivo real (violacion Touchless)" {
        BeforeEach {
            Mock Get-WinEvent {
                $FakeEvent = [PSCustomObject]@{ Id = 4624 }
                $FakeEvent | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
                    '<Event><EventData><Data Name="LogonType">2</Data></EventData></Event>'
                }
                @($FakeEvent)
            }
        }

        It "detecta el logon interactivo (LogonType 2) correctamente" {
            $Result = Get-InteractiveLogonEvents -BootTime (Get-Date)
            $Result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Log Security no accesible (sin privilegios o sin auditoria habilitada)" {
        BeforeEach {
            Mock Get-WinEvent { $null }
        }

        It "retorna null en lugar de fallar, permitiendo el Skip explicito aguas arriba" {
            $Result = Get-InteractiveLogonEvents -BootTime (Get-Date)
            $Result | Should -BeNullOrEmpty
        }
    }
}
