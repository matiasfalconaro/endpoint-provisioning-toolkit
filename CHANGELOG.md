# CHANGELOG

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/0.3.0/),
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[Version] - Fecha - [Rama] - [Estado]

---

## [0.0.1] - 2026-07-28 - [server-side-architecture] - [Unreleased]

### Added
- Incorporación del archivo `CHANGELOG.md`.
- Incorporacion del documento `RB-IT-W10-1.2.2.pdf`.

### Changed
- Arquitectura Server-Side: Reestructuración de la lógica de despliegue, trasladando la ejecución de scripts locales en el endpoint hacia Task Sequences centralizadas en servidor y *Offline Image Servicing* via DISM.
- Hardening de Privacidad: La gestión de privacidad se centraliza en la compilación dinámica de `unattend.xml` en WinPE y en directivas GPO de Active Directory (`GPO-WIN10-SECURITY-BASELINE-v1.2`).
- Gestión de Entorno: Se elimina la dependencia de crear el directorio local `C:\IT_Deployment_<GUID>` y la aplicación de exclusiones temporales en Microsoft Defender.
- Reorganización de Workflows de BIOS: Modularización de los métodos alternativos de aprovisionamiento desatendido (Opción B.1: DPAPI y Opción B.2: ThinkBios-Config) trasladando sus artefactos (`New-BiosEncryptedSecret.ps1`, `Set-LenovoBiosWithDpapi.ps1`, `Set-LenovoBiosWithThinkBios.ps1`) al subdirectorio `src/bios/workflows/` (o `src/bios/methods/`).
- Reorganización de Documentación y Assets: Renombrado del directorio `docs/img/` a `docs/assets/` para alojar los recursos gráficos.

### Deprecated
- `src/hardening/Set-WindowsPrivacyHardening.ps1`: Deprecado en favor de la inyección vía `unattend.xml` y GPO On-Premise. Movido al directorio `/deprecated`.
- `src/provisioning/Invoke-SecureDeploymentEnvironment.ps1`: Deprecado al descartarse los workspaces temporales en el endpoint. Movido al directorio `/deprecated`.

---

## [0.0.1] - 2026-06-15 - [main] - [Unreleased]

### Added
- Versión inicial del repositorio con la estructura base de automatización para BIOS, Debloat, Features, Hardening, Optimization y Provisioning (SOP-IT-W10-1.2.0).
