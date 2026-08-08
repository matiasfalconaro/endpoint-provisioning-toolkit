## Pruebas Locales y Calidad de Código
Para:
- Auditoría estática de código con `PSScriptAnalyzer`
- Normalización opcional de codificación a `UTF-8 con BOM` (`-FixEncoding`)
- Pruebas unitarias de seguridad aisladas con Pester + Mocks (BitLocker, Defender EDR, Boot Attestation, Authenticode)
- Batería completa de pruebas unitarias/integración y consolidación de logs en SQLite (`dev-test-logs.db`)

```powershell
# Ejecución estándar en desarrollo (bloquea/omite tests de riesgo por guarda de seguridad)
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1

# Habilitar explícitamente la ejecución de tests protegidos en la sesión actual
$env:ALLOW_HAZARDOUS_TESTS = "true"
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1
```

Nota (Guarda de Seguridad):
Para evitar ejecuciones accidentales en entornos locales, los scripts de prueba sensibles y suites de Pester cuentan con Guard Clause. Si la variable de entorno `$env:ALLOW_HAZARDOUS_TESTS` no tiene el valor `"true"`, la prueba se omitirá automáticamente con estado SKIPPED o abortará limpiamente sin alterar el sistema ni interrumpir la suite global.

Nota (Pester Mock):
Los scripts en `src/security/` tocan cmdlets sensibles del sistema. Para prevenir la alteración del entorno de desarrollo, el orquestador ejecuta los tests unitarios mediante Pester Interception sobre funciones encapsuladas. Si el módulo Pester no está disponible en el sistema, la etapa reportará estado SKIPPED sin bloquear los tests de integración.

Nota (Pester Mock):
Los scripts en src/security/ tocan cmdlets sensibles del sistema (ej. Enable-BitLocker, Set-MpPreference). Para prevenir la alteración del entorno de desarrollo, el orquestador ejecuta los tests unitarios mediante Pester Interception (Mocks) sobre funciones encapsuladas (invocation guards). Si el módulo Pester no está disponible en el sistema, la etapa reportará estado SKIPPED sin bloquear los tests de integración.

Nota sobre el Test 1:
Es normal que falle si existen cambios pendientes de registrar en manifest.json. En CI se resuelve automáticamente al mergear a main. Para forzar el paso local antes de un commit:
```
.\src\security\Confirm-ScriptIntegrity.ps1 -Action Generate -ManifestPath .\manifest.json
```

Nota sobre el test6:
"PASS" confirma que el mock buggy sigue reproduciendo el bug histórico (ExitCode: 0 ante falla real). Es una prueba de regresión; la corrección efectiva se valida en el Test 7.

## Calidad y Reglas de Código
- `PSScriptAnalyzer` Integrado automáticamente en `Run-AllTests.ps1`.
- Todos los scripts de prueba unitarios, standalone y Mocks con potencial impacto en hardware o configuración del sistema requieren la variable `$env:ALLOW_HAZARDOUS_TESTS = "true"` para ejecutarse. En tests de Pester reportan SKIPPED si la variable está ausente.
- Todo script en `src/security/` con efectos secundarios críticos debe envolver su lógica de ejecución dentro de una función pública y proteger su auto-ejecución mediante un condicional.
- Para prevenir `CommandNotFoundException` en entornos o runners desprovistos de módulos RSAT/BitLocker, los tests unitarios declaran stubs globales condicionales previa llamada a `Mock`.
- Se consolidan automáticamente los registros en `dev-test-logs.db` discriminando líneas estructuradas y no estructuradas. Si la base de datos no está disponible, conmuta automáticamente al archivado local en carpeta (logs_timestamp).
- `PSReviewUnusedParameter` suprimido vía `SuppressMessageAttribute` en `Invoke-DeploymentTask.ps1` ya que las variables se consumen dentro del closure de logging.
- Write-Host permitido únicamente en consolas interactivas y utilidades.
- Normalización opt-in a UTF-8 con BOM mediante el switch -FixEncoding.

## Escenarios de Prueba Evaluados
|Test       |Nombre del Escenario                                |Resultado Esperado en Desarrollo|
|-----------|----------------------------------------------------|--------------------------------|
|Pester Unit|Unit tests seguridad (BitLocker, EDR, Boot, Sign)   |PASS (0 fallidos)               |
|Test 0     |Happy Path (Bypasses)                               |PASS (ExitCode: 0)              |
|Test 1     |Happy Path (Integridad Real)                        |FAIL (Esperado)                 |
|Test 2     |Validación sin ScriptPath                           |PASS (ExitCode: 1)              |
|Test 3     |Detección de Manifiesto Alterado                    |PASS (ExitCode: 1)              |
|Test 4     |Manejo de Fallos en Proceso Externo                 |PASS (ExitCode: 1)              |
|Test 5     |Persistencia de Log de Fallback Local               |PASS (Warnings: 5)              |
|Test 6     |Bug Histórico BIOS — Propagación (referencia)       |PASS (ExitCode: 0)              |
|Test 7     |Fix BIOS — Propagación Correcta (standalone)        |PASS (ExitCode: 1)              |
|Test 8     |Features DISM — Captura de Exit Code                |PASS (ExitCode ≠ 0)             |
