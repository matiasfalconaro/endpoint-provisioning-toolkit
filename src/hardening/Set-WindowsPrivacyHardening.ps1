# Hardening de Telemetría y Privacidad
$DiagnosticPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $DiagnosticPath)) { New-Item -Path $DiagnosticPath -Force | Out-Null }

# Configuración: Telemetría en nivel Mínimo / Requerido (1 = Basic / 0 = Security para Enterprise)
Set-ItemProperty -Path $DiagnosticPath -Name "AllowTelemetry" -Value 1 -Type Dword -Force

# Deshabilitación de ID de Publicidad
$AdvPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
if (-not (Test-Path $AdvPath)) { New-Item -Path $AdvPath -Force | Out-Null }
Set-ItemProperty -Path $AdvPath -Name "Enabled" -Value 0 -Type Dword -Force
