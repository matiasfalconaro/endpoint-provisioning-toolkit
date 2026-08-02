# Test Drivers – Validador de Integridad y Wrapper
Pruebas diseñadas para `src/core/Invoke-DeploymentTask.ps1` y `src/security/Confirm-ScriptIntegrity.ps1` en entornos de desarrollo local.

## Requisitos Previos
```
# Que no haya cambios sin commitear en `src/core/Invoke-DeploymentTask.ps1` y `manifest.json`
# Genera el manifiesto actual si no existe y respaldar el manifiesto (necesario para restaurar tras test3)
.\src\security\Confirm-ScriptIntegrity.ps1 -Action Generate -SourcePath "$PWD" -ManifestPath "$PWD\manifest.json"
Copy-Item .\manifest.json .\manifest.backup.json

# Realizar los cambios a probar y commitearlos (o al menos tenerlos staged)
git add src\core\Invoke-DeploymentTask.ps1
git commit -m "..."
```

Nota: Si se commitean los cambios, `test1-happypath.ps1` fallará porque el manifiesto no coincidirá con el estado del disco (lo cual es esperado y válido para probar la detección de integridad).

## Ejecución
Desde `./`, ejecutar cada script con PowerShell 5.1 o 7:

```
# Test 0:
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\test0-happypath.ps1
echo "Exit code: $LASTEXITCODE"

#Test 1:
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\test1-happypath.ps1
echo "Exit code: $LASTEXITCODE"

# Test 2:
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\test2-nopath.ps1
echo "Exit code: $LASTEXITCODE"

# Test 3 (Corrupción del manifiesto en sesión, sin bypass. Solo la invocación del driver lo necesita):
# Respaldo
Copy-Item .\manifest.json .\manifest.backup.json
# Corromper el manifiesto (cambia src/ por XXX/)
(Get-Content .\manifest.json -Raw) -replace '"src/', '"XXX/' | Set-Content .\manifest.json -NoNewline
# Ejecucion
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\test3-tamper.ps1
echo "Exit code: $LASTEXITCODE"
# Restauracion del manifest.json
Move-Item .\manifest.backup.json .\manifest.json -Force

# Test 4:
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\test4-externalfail.ps1
echo "Exit code: $LASTEXITCODE"

# Test 5 — confirmar el log de fallback local:
Get-Content "C:\Windows\Temp\DeploymentLogs\*.log" -Tail 20

# Copia de logs
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item "C:\Windows\Temp\DeploymentLogs\*.log" -Destination ".\test-drivers\logs_$timestamp\" -Force

#Limpieza de logs:
Remove-Item "C:\Windows\Temp\DeploymentLogs\*.log" -Force
```
