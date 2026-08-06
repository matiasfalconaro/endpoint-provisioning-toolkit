$SecurePass = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force

& ".\test-drivers\mocks\Set-LenovoBiosBaseline.Mock.ps1" -BiosPassword $SecurePass

Write-Host "Script mock terminó. Exit code visible desde afuera: $LASTEXITCODE"
