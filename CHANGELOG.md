# CHANGELOG

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/0.3.0/),
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[Version] - Fecha - [Rama] - [Estado]

## [1.4.0] - 2026-07-28 - [main] - [Unreleased]

### Added
- Auditoría de rendimiento y salud térmica post-despliegue (CPU, temperatura, throughput NVMe/SATA).
- Test de regresión para propagación de excepción CIM/WMI terminante en la auditoría de rendimiento.
- Auditoría de logons interactivos post-OOBE (EventID 4624, LogonType interactivo) para validar la métrica Zero-Touch/Touchless.

---

## [1.3.0] - 2026-07-28 - [main] - [Unreleased]

### Added
- Suites de pruebas unitarias con Pester v5.x y Mocks para interceptar cmdlets sensibles del sistema.
- Integración automática de la etapa de Pester Mocks dentro del orquestador.
- Declaración de stubs globales condicionales en tests unitarios para prevenir errores.

### Changed
- Refactorización y modularización de los 4 scripts de la capa de seguridad.
- Inclusión de guarda de invocación en scripts de seguridad para permitir su importación en tests y su ejecución en la Task Sequence.
- Cambio del parámetro superior para resolver el bloqueo por prompt*interactivo durante el dot-sourcing.

### Fixed
- Corregido cmdlet de respaldo a MED y detección dinámica de tipo de directorio para la custodia de claves de BitLocker.
- Agregada validación por polling con reintentos y timeouts para el registro asíncrono del servicio EDR en el onboarding de Defender.
- Reemplazado método inexistente de atestación TPM por invocación y parsing estructurado, junto con la auditoría de logs de Measured Boot.
- Garantizada la propagación estricta de errores en la firma Authenticode.

---

## [1.2.0] - 2026-07-28 - [main] - [Unreleased]

### Added
- Workflow CI con PSScriptAnalyzer y generación automática de `manifest.json`.
- Validación de integridad SHA-256 y firma Authenticode previa a la ejecución de scripts.
- Captura de código de salida de procesos externos y fallback de logging local.
- Persistencia de logs de pruebas locales a SQLite y automatización del entorno de desarrollo.
- Suites de pruebas Pester para auditoría de hardware, borrado seguro de discos, debloat de AppX y gestión de energía por chasis.

### Changed
- Refactorización de selección de adaptador de red, resolución de rutas y evaluación de desgaste de almacenamiento.
- Endurecimiento de manejo de errores: reemplazo de fallos silenciosos por excepciones explícitas y acumulación de fallos por paquete.
- Encapsulamiento de lógica con guarda de invocación para permitir dot-sourcing seguro en todos los scripts.
- Ampliación y corrección de los Contextos 4 y 5 de testing (firma real, `AllSigned`, purga de registro).

### Fixed
- Corregidos falsos éxitos: contraseña de Supervisor no persistida en NVRAM y fallos de DISM no registrados.
- Corregida duplicación de logs entre salida cruda de proceso y log del wrapper al persistir en SQLite.
- El aviso de fallback de logging ahora se persiste en archivo, no solo en consola.

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
