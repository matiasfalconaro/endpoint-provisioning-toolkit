# Endpoint Provisioning Toolkit

Toolkit de automatización Zero-Touch para aprovisionamiento, hardening, mantenimiento de ciclo de vida y cumplimiento en estaciones Windows 10 Enterprise mediante MDT / MECM vía PXE.

## Arquitectura e Integración

Los componentes en `src/` y `templates/` son consumidos exclusivamente desde la infraestructura central On-Premise:

* MDT / MECM: Importar las secuencias de tareas desde `templates/` y consumir la release desde el Deployment Share.
* Active Directory: Vincular la directiva `GPO-WIN10-SECURITY-BASELINE-v1.2` a la OU corporativa (`OU=Workstations,OU=Corp,DC=empresa,DC=local`).

## Pipeline de Ejecución Automatizado

1. Pre-Installation (WinPE Stage):
   * Particionado GPT/UEFI dinámico y baseline de BIOS Lenovo cifrada.
   * Validación de dTPM 2.0, Secure Boot y Atestación de Salud de Hardware.
   * Pre-provisioning BitLocker (XTS-AES 256) con respaldo de claves en Active Directory DS.
   * Enrolamiento desatendido en Microsoft Defender Antivirus / XDR y reglas ASR.

2. Offline Image Servicing:
   * Inyección offline de .NET 4.8 / .NET 3.5 y Print-To-PDF; depuración de SMBv1, PowerShell v2 y XPS.
   * Depuración (*Debloat*) offline de paquetes UWP/AppX no corporativos directamente en el WIM.

3. Hardening & Optimización:
   * Perfiles de energía dinámicos según el factor de forma (Laptop/Desktop).
   * Bloqueo de LLMNR/NetBIOS y hardening de telemetría mediante GPO y `unattend.xml`.
   * Verificación SHA-256 (manifest.json) y firma Authenticode (`ExecutionPolicy AllSigned`) antes de ceder el control a cada script, orquestado por `src/core/Invoke-DeploymentTask.ps1`.

4. OOBE Cleanup & LAPS:
   * Omisión de pantallas interactivas OOBE y ejecución de `<FirstLogonCommands>`.
   * Entrega de credenciales de administrador local a Microsoft LAPS On-Premise.
   * Autodestrucción con sobrescritura inmediata del archivo `unattend.xml` y purga de AutoAdminLogon.

5. Post-Deployment & Lifecycle:
   * Auditoría de salud S.M.A.R.T., Batería, Feature Upgrades y sanitización criptográfica para decomisionamiento.
   * **Compliance Testing (Pester):** Validación desatendida post-despliegue de Secure Boot, BitLocker, EDR, LAPS y firmas.

## Entorno de Desarrollo Local

### Requisitos previos
* Windows PowerShell 5.1 (Windows 10/11) o PowerShell 7+.
* Git.
* [Opcional] [winget](https://learn.microsoft.com/windows/package-manager/winget/) — solo si vas a instalar GitHub CLI vía el bootstrap.

### Preparar el entorno

```powershell
cd C:\Ruta\A\Tu\endpoint-provisioning-toolkit
powershell -ExecutionPolicy Bypass -File .\DevEnvironment.ps1 -GitUserName "<USER-GITHUB>" -GitUserEmail "<EMAIL-GITHUB>"
```

Esto configura, instala los módulos de PowerShell requeridos y prepara los directorios locales de trabajo (logs, base de datos SQLite de resultados de tests).
