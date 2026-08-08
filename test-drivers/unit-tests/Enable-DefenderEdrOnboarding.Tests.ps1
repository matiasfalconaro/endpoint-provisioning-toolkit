BeforeAll {
    # GUARDA DE SEGURIDAD
    if ($env:ALLOW_HAZARDOUS_TESTS -ne "true") {
        Set-ItResult -Skipped -Because "Prueba de Pester omitida por guarda de seguridad (`$env:ALLOW_HAZARDOUS_TESTS != 'true')."
        return
    }

    . "$PSScriptRoot\..\..\src\security\Enable-DefenderEdrOnboarding.ps1"
}

Describe "Enable-DefenderEdrOnboarding" {

    Context "Verificación de Antivirus y Real-Time Protection" {
        It "activa RealTimeProtection si se encuentra deshabilitada" {
            Mock Get-MpComputerStatus { [PSCustomObject]@{ RealTimeProtectionEnabled = $false; AntivirusEnabled = $true } }
            Mock Set-MpPreference { }
            Mock Get-Service { [PSCustomObject]@{ Status = 'Running' } }
            Mock Set-Service { }
            Mock Start-Service { }
            Mock Wait-SenseServiceRunning { $true }

            { Invoke-DefenderEdrOnboarding -OnboardingScriptPath "C:\fake\script.cmd" } | Should -Not -Throw
            Should -Invoke Set-MpPreference -Times 1 -Exactly
        }

        It "aborta con error si Defender Antivirus está totalmente deshabilitado" {
            Mock Get-MpComputerStatus { [PSCustomObject]@{ RealTimeProtectionEnabled = $true; AntivirusEnabled = $false } }

            { Invoke-DefenderEdrOnboarding -OnboardingScriptPath "C:\fake\script.cmd" } | Should -Throw "*Microsoft Defender Antivirus se encuentra deshabilitado*"
        }
    }

    Context "Onboarding EDR y Polling de Servicio Sense" {
        It "ejecuta el script de onboarding si el servicio Sense no está en estado Running" {
            Mock Get-MpComputerStatus { [PSCustomObject]@{ RealTimeProtectionEnabled = $true; AntivirusEnabled = $true } }
            Mock Get-Service { $null }
            Mock Test-Path { $true }
            Mock Invoke-OnboardingScript { }
            Mock Set-Service { }
            Mock Start-Service { }
            Mock Wait-SenseServiceRunning { $true }

            { Invoke-DefenderEdrOnboarding -OnboardingScriptPath "C:\fake\script.cmd" } | Should -Not -Throw
            Should -Invoke Invoke-OnboardingScript -Times 1 -Exactly
        }

        It "aborta si el servicio Sense nunca llega a estado Running dentro del tiempo límite" {
            Mock Get-MpComputerStatus { [PSCustomObject]@{ RealTimeProtectionEnabled = $true; AntivirusEnabled = $true } }
            Mock Get-Service { $null }
            Mock Test-Path { $true }
            Mock Invoke-OnboardingScript { }
            Mock Set-Service { }
            Mock Start-Service { }
            Mock Wait-SenseServiceRunning { $false }

            { Invoke-DefenderEdrOnboarding -OnboardingScriptPath "C:\fake\onboard.cmd" } | Should -Throw "*Sense*no reportó estado 'Running'*"
        }
    }

    Context "Aislamiento de temporización en Wait-SenseServiceRunning" {
        It "retorna false tras agotar el timeout sin bloquear la ejecucion real" {
            Mock Get-Service { [PSCustomObject]@{ Status = 'Stopped' } }
            Mock Start-Sleep { }

            $Result = Wait-SenseServiceRunning -TimeoutSeconds 20
            $Result | Should -BeFalse
            Should -Invoke Start-Sleep -Times 2
        }

        It "retorna true en el primer intento si el servicio reporta Running" {
            Mock Get-Service { [PSCustomObject]@{ Status = 'Running' } }
            Mock Start-Sleep { }

            Wait-SenseServiceRunning -TimeoutSeconds 30 | Should -BeTrue
            Should -Invoke Start-Sleep -Times 0 -Exactly
        }
    }
}
