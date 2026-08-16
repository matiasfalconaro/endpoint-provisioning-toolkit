## Pruebas Locales y Calidad de Código
Para:
- Auditoría estática de código con `PSScriptAnalyzer`
- Normalización opcional de codificación a `UTF-8 con BOM` (`-FixEncoding`)
- Pruebas unitarias aisladas con Pester + Mocks (BitLocker, Defender EDR, Boot Attestation, Authenticode, Rendimiento/Térmica, Auditoría Touchless, Auditoría OOBE, Cumplimiento Touchless agregado, Critical Patch Gate, Custodia de Secretos BIOS vía Key Vault / AD DS)
- Batería completa de pruebas unitarias/integración y consolidación de logs en SQLite (`dev-test-logs.db`)

```powershell
# Ejecución estándar en desarrollo (bloquea/omite tests de riesgo por guarda de seguridad)
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1

# Habilitar explícitamente la ejecución de tests protegidos en la sesión actual
$env:ALLOW_HAZARDOUS_TESTS = "true"
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1
```

**Nota (Guarda de Seguridad):**
Si la variable de entorno `$env:ALLOW_HAZARDOUS_TESTS` no tiene el valor `"true"`, la prueba se omitirá automáticamente con estado SKIPPED o abortará.

**Nota (Pester Mock):**
Los scripts en `src/security/` tocan cmdlets sensibles. El orquestador ejecuta los tests unitarios mediante Mocks sobre invocation guards. Si el módulo Pester no está disponible, la etapa reportará estado SKIPPED.

**Nota (Stubs de Módulos Externos — Az / RSAT-AD-PowerShell):**
`Get-BiosSecretFromKeyVault.ps1` y `Get-BiosSecretFromAdGroupSecret.ps1` dependen de módulos que pueden no estar instalados en el runner de CI ni en la estación de desarrollo local. La suite unitaria declara stubs globales condicionales antes de aplicar `Mock`.

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
> Aplica también a `Get-AzKeyVaultSecret` y a `Get-ADComputer`.

## Calidad y Reglas de Código
- `PSScriptAnalyzer` Integrado automáticamente en `Run-AllTests.ps1`.
- Todos los scripts de prueba unitarios, standalone y Mocks con potencial impacto en hardware o configuración del sistema requieren la variable `$env:ALLOW_HAZARDOUS_TESTS = "true"` para ejecutarse. En tests de Pester reportan SKIPPED si la variable está ausente.
- Todo script en `src/security/` (y, por extensión, cualquier script con efectos secundarios críticos fuera) envuelve su lógica de ejecución dentro de una función pública, y protege su ejecución.
- Para prevenir `CommandNotFoundException` en entornos o runners desprovistos de módulos RSAT/BitLocker/Az, los tests unitarios declaran stubs globales condicionales previa llamada a `Mock`.
- Se consolidan automáticamente los registros en `dev-test-logs.db` discriminando líneas estructuradas y no estructuradas. Si la base de datos no está disponible, conmuta automáticamente al archivado local en carpeta (logs_timestamp).
- `PSReviewUnusedParameter` suprimido vía `SuppressMessageAttribute` en `Invoke-DeploymentTask.ps1` ya que las variables se consumen dentro del closure de logging.
- Write-Host permitido únicamente en consolas interactivas y utilidades.
- Normalización opt-in a UTF-8 con BOM mediante el switch -FixEncoding.

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
