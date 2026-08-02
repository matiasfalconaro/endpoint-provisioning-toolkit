## Pruebas Locales y Calidad de Código
Para:
- Ejecución de auditoría de código `PSScriptAnalyzer`
- Normalización automática de codificación (`UTF-8 con BOM`)
- Ssuite completa de pruebas unitarias/integración

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1
```

Nota sobre el Test 1: 
Es normal que falle localmente si `Invoke-DeploymentTask.ps1` (o cualquier
script referenciado por `-ScriptPath` en los drivers) tiene cambios pendientes
de registrar en `manifest.json`. Se resuelve automáticamente al mergear la
rama a `main`, donde CI regenera el manifiesto.

Para forzar a que pase localmente antes del commit:
```
.\src\security\Confirm-ScriptIntegrity.ps1 -Action Generate -ManifestPath .\manifest.json
```

Nota sobre el Test 6:
A diferencia del resto, "PASS" en el Test 6 significa que el mock buggy
sigue reproduciendo correctamente el bug histórico (exit code 0 pese a
un fallo real) — es una prueba de regresión, no una validación de que todo
está bien. Si el Test 6 empezara a dar exit code distinto de 0, sería señal
de que el mock dejó de replicar el escenario original, no de que el bug se
resolvió (el fix real se valida en el Test 7).

## Calidad y Reglas de Código
- `PSScriptAnalyzer`: Integrado automáticamente en `Run-AllTests.ps1`.
- `PSReviewUnusedParameter` (`TaskName`, `LocalFallbackLogPath`) está suprimido en `Invoke-DeploymentTask.ps1` vía `SuppressMessageAttribute` (las variables se consumen internamente dentro del closure Write-DeploymentLog.)
- Write-Host: Permitido en componentes interactivos y scripts de aprovisionamiento en consola.
- Encoding: Los scripts se normalizan a `UTF-8` con `BOM` para garantizar compatibilidad con `PowerShell 5.1` (opt-in vía `-FixEncoding`, no automático).

Escenarios de Prueba Evaluados\
|Test  |Nombre del Escenario                                |Resultado Esperado en Desarrollo|
|------|----------------------------------------------------|--------------------------------|
|Test 0|Happy Path (Bypasses)                               |PASS (ExitCode: 0)              |
|Test 1|Happy Path (Integridad Real)                        |FAIL (Esperado)                 |
|Test 2|Validación sin ScriptPath                           |PASS (ExitCode: 1)              |
|Test 3|Detección de Manifiesto Alterado                    |PASS (ExitCode: 1)              |
|Test 4|Manejo de Fallos en Proceso Externo                 |PASS (ExitCode: 1)              |
|Test 5|Persistencia de Log de Fallback Local               |PASS (Warnings: 5)              |
|Test 6|Bug Histórico BIOS — Propagación (referencia)       |PASS (ExitCode: 0)              |
|Test 7|Fix BIOS — Propagación Correcta (standalone)        |PASS (ExitCode: 1)              |
|Test 8|Features DISM — Captura de Exit Code                |PASS (ExitCode ≠ 0)             |
