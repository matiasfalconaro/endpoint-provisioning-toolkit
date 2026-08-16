## Pruebas Locales y Calidad de Código
Para:
- Auditoría estática de código con `PSScriptAnalyzer`
- Normalización opcional de codificación a `UTF-8 con BOM` (`-FixEncoding`), sobre todo `src/`/`test-drivers/` o sobre rutas puntuales (`-EncodingTargetPath`)
- Pruebas unitarias aisladas con Pester + Mocks (BitLocker, Defender EDR, Boot Attestation, Authenticode, Rendimiento/Térmica, Auditoría Touchless, Auditoría OOBE, Cumplimiento Touchless agregado, Critical Patch Gate, Custodia de Secretos BIOS vía Key Vault / AD DS), sobre toda la suite o un archivo puntual (`-UnitTestPath`)
- Batería completa de pruebas unitarias/integración y consolidación de logs en SQLite (`dev-test-logs.db`), omitible durante desarrollo local (`-SkipScenarios`)

```powershell
# Ejecución estándar en desarrollo (bloquea/omite tests de riesgo por guarda de seguridad)
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1

# Habilitar explícitamente la ejecución de tests protegidos en la sesión actual
$env:ALLOW_HAZARDOUS_TESTS = "true"
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1

# Ciclo rápido de desarrollo: normalizar encoding y correr solo un test puntual,
# sin la batería de integración (Test 0-13)
.\test-drivers\Run-AllTests.ps1 `
    -FixEncoding -EncodingTargetPath ".\src\testing\Get-TouchlessComplianceRate.ps1", ".\test-drivers\unit-tests\Get-TouchlessComplianceRate.Tests.ps1" `
    -UnitTestPath ".\test-drivers\unit-tests\Get-TouchlessComplianceRate.Tests.ps1" `
    -SkipScenarios

# Solo normalizar encoding de un archivo o carpeta puntual, sin correr ningún test
.\test-drivers\Run-AllTests.ps1 -FixEncoding -EncodingTargetPath ".\src\bios\workflows" -EncodingOnly
```

**Nota (Parámetros de ejecución acotada):**
- `-EncodingTargetPath <string[]>`: limita `-FixEncoding` a uno o más archivos/carpetas puntuales en vez de normalizar todo `src/`/`test-drivers/`. Acepta múltiples rutas separadas por coma.
- `-EncodingOnly`: detiene la ejecución inmediatamente después de normalizar encoding, sin correr PSScriptAnalyzer, Pester ni la batería de integración.
- `-UnitTestPath <string>`: apunta Pester a un único archivo `.Tests.ps1` en vez de correr toda la carpeta `unit-tests/`.
- `-SkipScenarios`: omite la batería de integración (Test 0-13) y la restauración/persistencia asociada de `manifest.json` y logs.

**Nota (Guarda de Seguridad):**
Si la variable de entorno `$env:ALLOW_HAZARDOUS_TESTS` no tiene el valor `"true"`, la prueba se omitirá automáticamente con estado SKIPPED o abortará.

**Nota (Pester Mock):**
Los scripts en `src/security/` tocan cmdlets sensibles. El orquestador ejecuta los tests unitarios mediante Mocks sobre invocation guards. Si el módulo Pester no está disponible, la etapa reportará estado SKIPPED.

**Nota (Stubs de Módulos Externos — Az / RSAT-AD-PowerShell):**
`Get-BiosSecretFromKeyVault.ps1`, `Get-BiosSecretFromAdGroupSecret.ps1` y `Register-AutopilotHardwareHash.ps1` dependen de módulos que pueden no estar instalados en el runner de CI ni en la estación de desarrollo local. La suite unitaria declara stubs globales condicionales antes de aplicar `Mock`.

**Nota (Parámetros obligatorios a nivel de script):**
Los scripts con función pública + guarda `-SkipExecution` (BIOS Key Vault/AD DS, Autopilot Hardware Hash, Critical Patch Gate, Touchless Compliance Rate) no declaran sus parámetros de negocio como `Mandatory` a nivel de script, para permitir el dot-source en pruebas unitarias sin bloqueo interactivo. La validación de obligatoriedad se aplica manualmente solo en el bloque de ejecución directa (`if (-not $SkipExecution) { ... }`).

**Nota sobre el Test 1:**
Es normal que falle si existen cambios pendientes de registrar en manifest.json. En CI se resuelve automáticamente al mergear a main. Para forzar el paso local antes de un commit:

```
.\src\security\Confirm-ScriptIntegrity.ps1 -Action Generate -ManifestPath .\manifest.json
```

**Nota sobre el test6:**
"PASS" confirma que el mock buggy sigue reproduciendo el bug histórico (ExitCode: 0 ante falla real). Es una prueba de regresión; la corrección efectiva se valida en el Test 7.

**Nota sobre el Test 13:**
En los casos "función pública + guarda `-SkipExecution`", una excepción no capturada dentro de la función (`throw`) sigue propagándose como `ExitCode ≠ 0` cuando el script se invoca como proceso standalone.

**Nota sobre mocks con Add-Member:**
En Pester v6, un `[PSCustomObject]@{}` sin propiedades de datos es tratado como "vacío" por `Should -BeNullOrEmpty`, aunque tenga métodos agregados vía `Add-Member`.
Los mocks que simulan objetos con contenido deben inicializarse con al menos una propiedad real.
> Aplica también a `Get-AzKeyVaultSecret`, a `Get-ADComputer` y a `Get-WindowsAutoPilotInfo`.

**Nota sobre conteo de colecciones de un solo elemento:**
Cuando el pipeline de PowerShell (`Get-ChildItem | Where-Object`, `Get-WinEvent`, etc.) devuelve un único resultado, PowerShell lo entrega como objeto suelto, no como array — por lo que `.Count` sobre ese resultado da `$null` en vez de `1`. Los scripts que acumulan colecciones antes de usar `.Count` deben forzar el contexto de array con `@(...)`.

## Calidad y Reglas de Código
- `PSScriptAnalyzer` Integrado automáticamente en `Run-AllTests.ps1`.
- Todos los scripts de prueba unitarios, standalone y Mocks con potencial impacto en hardware o configuración del sistema requieren la variable `$env:ALLOW_HAZARDOUS_TESTS = "true"` para ejecutarse. En tests de Pester reportan SKIPPED si la variable está ausente.
- Todo script en `src/security/` (y, por extensión, cualquier script con efectos secundarios críticos fuera) envuelve su lógica de ejecución dentro de una función pública, y protege su ejecución.
- Para prevenir `CommandNotFoundException` en entornos o runners desprovistos de módulos RSAT/BitLocker/Az, los tests unitarios declaran stubs globales condicionales previa llamada a `Mock`.
- Se consolidan automáticamente los registros en `dev-test-logs.db` discriminando líneas estructuradas y no estructuradas. Si la base de datos no está disponible, conmuta automáticamente al archivado local en carpeta (logs_timestamp).
- `PSReviewUnusedParameter` suprimido vía `SuppressMessageAttribute` en `Invoke-DeploymentTask.ps1` ya que las variables se consumen dentro del closure de logging.
- `PSAvoidUsingConvertToSecureStringWithPlainText` suprimido vía `SuppressMessageAttribute` en `Get-BiosSecretFromAdGroupSecret.ps1`, dado que el valor llega como texto plano desde el atributo AD sin alternativa dentro del modelo actual.
- Write-Host permitido únicamente en consolas interactivas y utilidades.
- Normalización opt-in a UTF-8 con BOM mediante el switch -FixEncoding, con soporte para acotar la normalización a rutas puntuales vía -EncodingTargetPath.

## Escenarios de Prueba Evaluados
|Test       |Nombre del Escenario                                |Resultado Esperado en Desarrollo|
|-----------|----------------------------------------------------|--------------------------------|
|Pester Unit|Unit tests seguridad, rendimiento y touchless       |PASS (0 fallidos)               |
|Pester Unit|Unit tests Critical Patch Gate, Key Vault/AD Secret, Autopilot Hash, OOBE Audit, Touchless Rate, Templates VLAN-PROV/MAB|PASS (0 fallidos)|
|Test 0     |Skipping Security Checks (solo debugging)           |PASS (ExitCode: 0)              |
|Test 1     |Happy Path (Integridad Real)                        |FAIL (Esperado)                 |
|Test 2     |Validación sin ScriptPath                           |PASS (ExitCode: 1)              |
|Test 3     |Detección de Manifiesto Alterado                    |PASS (ExitCode: 1)              |
|Test 4     |Manejo de Fallos en Proceso Externo                 |PASS (ExitCode: 1)              |
|Test 5     |Persistencia de Log de Fallback Local               |PASS (Warnings: 5)              |
|Test 6     |Bug Histórico BIOS — Propagación (referencia)       |PASS (ExitCode: 0)              |
|Test 7     |Fix BIOS — Propagación Correcta (standalone)        |PASS (ExitCode: 1)              |
|Test 8     |Features DISM — Captura de Exit Code                |PASS (ExitCode ≠ 0)             |
|Test 9     |Workflows BIOS — Propagación ante Rutas Inexistentes|PASS (ExitCode: 0)              |
|Test 10    |Performance — Excepción CIM Terminante              |PASS (ExitCode: 0)              |
|Test 11    |Validación Estricta — SHA-256 + Authenticode reales |PASS (ExitCode: 0)              |
|Test 12    |Sanitización NIST SP 800-88                         |PASS                            |
|Test 13    |Critical Patch Gate — Propagación de ExitCode       |PASS                            |
