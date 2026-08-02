## Pruebas Locales y Calidad de Código
Para:
- Ejecución de auditoría de código `PSScriptAnalyzer`
- Normalización automática de codificación (`UTF-8 con BOM`)
- Ssuite completa de pruebas unitarias/integración

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1
```
Nota sobre el Test 1: 
Es normal que falle localmente si `Invoke-DeploymentTask.ps1` tiene cambios pendientes de registrar en `manifest.json`. 

Para forzar a que pase localmente antes del commit:
```
.\src\security\Confirm-ScriptIntegrity.ps1 -Action Generate -ManifestPath .\manifest.json
```

## Calidad y Reglas de Código
- `PSScriptAnalyzer`: Integrado automáticamente en `Run-AllTests.ps1`.
- `PSReviewUnusedParameter` (`TaskName`, `LocalFallbackLogPath`) está suprimido en `Invoke-DeploymentTask.ps1` vía `SuppressMessageAttribute` (las variables se consumen internamente dentro del closure Write-DeploymentLog.)
- Write-Host: Permitido en componentes interactivos y scripts de aprovisionamiento en consola.
- Encoding: Los scripts se normalizan a `UTF-8` con `BOM` para garantizar compatibilidad con `PowerShell 5.1`.

Escenarios de Prueba Evaluados\
|Test  |Nombre del Escenario                 |Resultado Esperado en Desarrollo|
|------|-------------------------------------|--------------------------------|
|Test 0|Happy Path (Bypasses)                |PASS (ExitCode: 0)              |
|Test 1|Happy Path (Integridad Real)         |FAIL (Esperado)                 |
|Test 2|Validación sin ScriptPath            |PASS (ExitCode: 1)              |
|Test 3|Detección de Manifiesto Alterado     |PASS (ExitCode: 1)              |
|Test 4|Manejo de Fallos en Proceso Externo  |PASS (ExitCode: 1)              |
|Test 5|Persistencia de Log de Fallback Local|PASS (Warnings: 5)              |
