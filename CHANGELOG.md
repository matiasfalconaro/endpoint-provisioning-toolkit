# CHANGELOG

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/0.3.0/),
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[Version] - Fecha - [Rama] - [Estado]

---

## [1.0.0] - 2026-07-28 - [server-side-architecture] - [Unreleased]

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
- Versión inicial del repositorio con la estructura base de automatización para BIOS, Debloat, Features, Hardening, Optimization y Provisioning (SOP-IT-W10-1.2.0).
