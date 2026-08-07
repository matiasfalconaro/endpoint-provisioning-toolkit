# CHANGELOG

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/0.3.0/),
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[Version] - Fecha - [Rama] - [Estado]

---

## [1.2.0] - 2026-07-28 - [main] - [Unreleased]

### Added
- Se añade workflow con PSScriptAnalyzer para validación estática y generación automática de `manifest.json`.
- Validación de integridad SHA-256 y firma Authenticode del script invocado antes de cederle el control, con bypass explícito.
- Captura de código de salida de procesos externos, además de excepciones de PowerShell.
- Fallback de logging a ruta local cuando el servidor de logs no está disponible.
- Integra PSScriptAnalyzer, valida los escenarios del wrapper y normaliza codificación a UTF-8 con BOM.
- Persistencia de logs de la suite de pruebas locales a SQLite.
- Automatización de la preparación del entorno de desarrollo local.
- Incorpora test para la auditoría de salud de hardware y borrado seguro de discos.
- Nueva suite de pruebas unitarias Pester v6 con soporte para Mocks y Stubs de cmdlets nativos.
- Validación de escenarios de filtrado exacto, fallos parciales con ejecución continua y omisión de paquetes no listados.
- Suite de pruebas que valida la detección de chasis (Laptop/Desktop) y el manejo de errores de `powercfg`.

### Changed
- Mejora en selección de adaptador de red, excluyendo adaptadores virtuales/VPN/Hyper-V.
- Reemplazo de dependencia de `[System.IO.Path]::GetRelativePath` por función manual.
- Resolución automática de SourcePath y escaneo explícito de `src/` y `templates/`.
- Se agrega `$ErrorActionPreference = 'Stop'` propio, para seguridad si se ejecuta fuera del wrapper.
- Se agregan escenarios de regresión para propagación de errores en BIOS y para captura de exit code en DISM.
- `.gitignore`: Se agrega `manifest.json`.
- Amplía el Contexto 5 de testing para cubrir propiedades de registro y rutas de archivo que purgan.
- Corrige contexto 4 de testingpara exigir `AllSigned`, validar firma real y resolver DeploymentRoot via `-Data`
- Se refactorizó la evaluación de desgaste de almacenamiento para tratar de forma indeterminada la falta de contadores de confiabilidad.
- Se hizo opcional la obligatoriedad del parámetro en el script raíz `Invoke-LenovoDriveWipe.ps1`.
- Encapsulamiento de la lógica e inclusión de guarda de invocación para habilitar dot-sourcing sin ejecución automática.
- Sustitución de `@($ProvisionedApps).Count` para garantizar la coerción a array y evitar evaluadores escalares vacíos en PowerShell 5.1.
- Eliminación de la combinación silenciosa `-ErrorAction SilentlyContinue | Out-Null`, reemplazándola por `-ErrorAction Stop` y manejo de excepciones explícito en cada paquete.
- Implementación de un patrón de acumulación de fallos, permitiendo intentar la eliminación de todos los paquetes independientes de bloatware antes de lanzar un error consolidado.
- Prevencion de ejecuciones no controladas fuera del wrapper de orquestación.
- Control explícito de errores para capturar códigos de salida fallidos de `powercfg`.

### Fixed
- El aviso de fallback de logging ahora se persiste en el archivo de log, no solo en consola.
- Workflow CI: corrección en la detección de la primera generación de `manifest.json`.
- Se elimina contraseña de Supervisor, guardado en NVRAM dejando que el script reportara éxito pese al fallo real.
- Se arregla un fallo de DISM dejaba pasar el script como completado exitosamente sin registrar el error.
- Se corrige la duplicación de líneas de log entre la captura de salida cruda del proceso (`RAWOUTPUT_*`) y el log real del wrapper al persistir a SQLite.
- Se captura la salida completa (stdout) de cada test driver, evitando la pérdida silenciosa de detalle diagnóstico que antes nunca llegaba a ningún archivo de log.

---

## [1.1.0] - 2026-07-28 - [main] - [Unreleased]

### Added
- Estandarización de logging centralizado, manejo de excepciones y códigos de salida.
- Auditoría de salud de SSD (S.M.A.R.T.), ciclos de batería y versión de firmware de la flota.
- Sanitización criptográfica y borrado seguro de almacenamiento en la fase de decomisionamiento.
- Inyección y validación desatendida de licencias ESU.
- Orquestación de In-Place Upgrades.
- Auditoría de Secure Boot, dTPM 2.0 y soporte de atestación remota.
- Habilitación de cifrado XTS-AES 256, protector dTPM 2.0 y resguardo obligatorio de claves de recuperación en Active Directory DS.
- Activación de motores de protección y onboarding desatendido a Defender for Endpoint.
- Firma digital masiva de scripts y auditoría de integridad Authenticode.
- Generación y auditoría de integridad SHA-256 en repositorios On-Premise.
- Eliminación segura de credenciales efímeras y destrucción de archivos `unattend.xml`.
- Suite de pruebas unitarias e integración en Pester v5.x para la validación de conformidad post-despliegue.
- Orquestación desatendida de Pester y la exportación de reportes NUnit XML al servidor central (`NAS-CORP01`).

---

## [1.0.0] - 2026-07-28 - [main] - [Unreleased]

### Added
- Incorporación del archivo `CHANGELOG.md`.
- Incorporacion del documento `RB-IT-W10-1.2.2.pdf`.

### Changed
- Invocación de métodos WMI/CIM y la sintaxis de la contraseña de supervisor en el script de BIOS Lenovo.
- Gestion de debloat para ejecutar la depuración de AppX en modo offline (servidor/WinPE) en lugar de la imagen activa.
- Gestion de características de Windows para usar DISM en modo offline y la ruta SxS del servidor.
- Gestion de energía para limitar el ajuste según chasis en la Task Sequence y delegar la configuración del Registro a la GPO.
- Script para generar secretos cifrados vía DPAPI para la BIOS.
- Script para la aplicación desatendida de la Baseline de BIOS con credenciales cifradas.
- Script para aplicar configuraciones de BIOS mediante el módulo oficial de Lenovo.
- Modularización de los métodos alternativos de aprovisionamiento desatendido al subdirectorio `src/bios/workflows/`.
- Renombrado del directorio `docs/img/` a `docs/assets/` para alojar los recursos gráficos.

### Deprecated
- `src/hardening/Set-WindowsPrivacyHardening.ps1`: En favor de la inyección vía `unattend.xml` y GPO On-Premise. Movido al directorio `/deprecated`.
- `src/provisioning/Invoke-SecureDeploymentEnvironment.ps1`: Se descartan los workspaces temporales en el endpoint. Movido al directorio `/deprecated`.
- `diskpart'partition'uefi.txt`: Es reemplazado por la acción dinámica de la Task Sequence.

---

## [0.0.1] - 2026-06-15 - [main] - [Unreleased]

### Added
- Versión inicial del repositorio con la estructura base de automatización para BIOS, Debloat, Features, Hardening, Optimization y Provisioning.
