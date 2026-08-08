BeforeAll {
    $script:TempDir = Join-Path $env:TEMP "sig-test-$(Get-Random)"
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

    . "$PSScriptRoot\..\..\src\security\Set-AuthenticodeSignature.ps1"
}

AfterAll {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Set-AuthenticodeSignature" {

    Context "Modo Validación (-ValidateOnly)" {
        It "retorna true si la firma es VÁLIDA" {
            $File = Join-Path $TempDir "valid.ps1"
            "Write-Host 'Valid'" | Set-Content $File

            Mock Get-AuthenticodeSignature {
                [PSCustomObject]@{
                    Status = 'Valid'
                    SignerCertificate = [PSCustomObject]@{ Subject = 'CN=Corporate PKI' }
                }
            }

            $Result = Invoke-AuthenticodeSigning -ScriptPath $File -ValidateOnly
            $Result | Should -BeTrue
            Should -Invoke Get-AuthenticodeSignature -Times 1 -Exactly
        }

        It "detecta y rechaza un script con firma no válida" {
            $Unsigned = Join-Path $TempDir "unsigned.ps1"
            "Write-Host 'Unsigned'" | Set-Content $Unsigned

            Mock Get-AuthenticodeSignature {
                [PSCustomObject]@{
                    Status = 'NotSigned'
                    StatusMessage = 'The file is not signed.'
                }
            }

            { Invoke-AuthenticodeSigning -ScriptPath $Unsigned -ValidateOnly } | Should -Throw "*no cuenta con una firma Authenticode válida*"
        }
    }

    Context "Modo Firma de Scripts" {
        It "firma un archivo individual de prueba correctamente" {
            $File = Join-Path $TempDir "script1.ps1"
            "Write-Host 'Test'" | Set-Content $File

            $DummyCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()
            Mock Get-Item { $DummyCert }
            Mock Set-AuthenticodeSignature { [PSCustomObject]@{ Status = 'Valid' } }

            Invoke-AuthenticodeSigning -ScriptPath $File -CertificateThumbprint "12345"
            Should -Invoke Set-AuthenticodeSignature -Times 1 -Exactly
        }

        It "lanza excepción si el certificado especificado no existe en el almacén" {
            $File = Join-Path $TempDir "script2.ps1"
            "Write-Host 'Test'" | Set-Content $File

            Mock Get-Item { $null }

            { Invoke-AuthenticodeSigning -ScriptPath $File -CertificateThumbprint "NOTFOUND" } | Should -Throw "*No se encontró el certificado*"
        }

        It "lanza excepción si la ruta indicada no existe" {
            $DummyCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()
            Mock Get-Item { $DummyCert }

            { Invoke-AuthenticodeSigning -ScriptPath "C:\invalid_path\missing.ps1" -CertificateThumbprint "12345" } | Should -Throw "*no existe*"
        }

        It "en procesamiento de directorio, propaga el fallo si falla la firma de un script" {
            $BatchDir = Join-Path $TempDir "batch"
            New-Item -Path $BatchDir -ItemType Directory -Force | Out-Null
            "Write-Host '1'" | Set-Content (Join-Path $BatchDir "file1.ps1")
            "Write-Host '2'" | Set-Content (Join-Path $BatchDir "file2.ps1")

            $DummyCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()
            Mock Get-Item { $DummyCert }
            Mock Set-AuthenticodeSignature {
                [PSCustomObject]@{ Status = 'UnknownError'; StatusMessage = 'Timestamp server unreachable' }
            }

            { Invoke-AuthenticodeSigning -ScriptPath $BatchDir -CertificateThumbprint "12345" } | Should -Throw "*Fallo al firmar*"
        }
    }
}
