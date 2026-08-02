$SecurePass = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force

# Usamos una copia del script real pero con el mismo mock de Invoke-CimMethod,
# para poder probar sin hardware Lenovo. El contenido (sin catch, con
# $ErrorActionPreference = 'Stop') es el que ya está en src\bios\Set-LenovoBiosBaseline.ps1.
& ".\test-drivers\Set-LenovoBiosBaseline.MockFixed.ps1" -BiosPassword $SecurePass

Write-Host "Si ves esto, el script NO abortó (bug seguiría presente)."
