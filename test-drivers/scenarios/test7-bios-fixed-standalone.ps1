$SecurePass = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force

& "$PSScriptRoot\..\mocks\Set-LenovoBiosBaseline.MockFixed.ps1" -BiosPassword $SecurePass

Write-Host "Si ves esto, el script NO abortó (bug seguiría presente)."
