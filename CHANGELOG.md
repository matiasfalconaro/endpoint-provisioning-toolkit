# CHANGELOG

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/0.3.0/),
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[Version] - Fecha - [Rama] - [Estado]

---

## [1.2.0] - 2026-07-28 - [main] - [Unreleased]

### Added
- CI Pipeline: se añade workflow con PSScriptAnalyzer para validación estática y generación automática de `manifest.json`.
- Validación de integridad SHA-256 y firma Authenticode del script invocado antes de cederle el control, con bypass explícito.
- Captura de código de salida de procesos externos, además de excepciones de PowerShell.
- Fallback de logging a ruta local cuando el servidor de logs no está disponible.
- Suite de pruebas locales: Integra PSScriptAnalyzer, valida los escenarios del wrapper y normaliza codificación a UTF-8 con BOM.

### Changed
- Mejora en selección de adaptador de red, excluyendo adaptadores virtuales/VPN/Hyper-V.
- Reemplazo de dependencia de `[System.IO.Path]::GetRelativePath` por función manual.
- Resolución automática de SourcePath y escaneo explícito de `src/` y `templates/`.
- `.gitignore`: Se agrega `manifest.json`.

### Fixed
- El aviso de fallback de logging ahora se persiste en el archivo de log, no solo en consola.
- Workflow CI: corrección en la detección de la primera generación de `manifest.json`.

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
