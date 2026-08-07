## Pruebas Locales y Calidad de Código
Para:
- Auditoría estática de código con `PSScriptAnalyzer`
- Normalización opcional de codificación a `UTF-8 con BOM` (`-FixEncoding`)
- Batería completa de pruebas unitarias/integración y consolidación de logs en SQLite (`TestResults.db`)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1
```

Nota sobre el test1:
Es normal que falle si existen cambios pendientes de registrar en manifest.json. En CI se resuelve automáticamente al mergear a main. Para forzar el paso local antes de un commit:
```
.\src\security\Confirm-ScriptIntegrity.ps1 -Action Generate -ManifestPath .\manifest.json
```

Nota sobre el test6:
"PASS" confirma que el mock buggy sigue reproduciendo el bug histórico (ExitCode: 0 ante falla real). Es una prueba de regresión; la corrección efectiva se valida en el Test 7.

## Calidad y Reglas de Código
- `PSScriptAnalyzer`: Integrado automáticamente en `Run-AllTests.ps1`.
- Persistencia de Logs: Consolida automáticamente los registros en `test-drivers\logs\TestResults.db` discriminando líneas estructuradas y no estructuradas. Si la base de datos no está disponible, conmuta automáticamente al archivado local en carpeta (logs_timestamp).
- PSReviewUnusedParameter: Suprimido vía SuppressMessageAttribute en Invoke-DeploymentTask.ps1 (TaskName, LocalFallbackLogPath) ya que las variables se consumen dentro del closure de logging.
- Write-Host: Permitido únicamente en consolas interactivas y utilidades.
- Encoding: Normalización opt-in a UTF-8 con BOM mediante el switch -FixEncoding.

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
