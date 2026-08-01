# Endpoint Provisioning Toolkit

Toolkit de automatización para el aprovisionamiento masivo Zero-Touch, hardening, depuración, mantenimiento de ciclo de vida y configuración de infraestructura en estaciones de trabajo corporativas Windows 10 Enterprise.

---

## Arquitectura Server-Side (Zero-Touch)

Los componentes en `src/` y `templates/` son consumidos e inyectados exclusivamente desde la infraestructura central On-Premise a través de **Microsoft Deployment Toolkit (MDT)** y **Microsoft Endpoint Configuration Manager (MECM)** vía arranque PXE.

---

## Flujo de Ejecución Automatizado (Task Sequence Pipeline)

Todas las tareas en PowerShell se ejecutan envolviéndose en el wrapper central de trazabilidad, el cual orquesta el logging en red, la captura de excepciones y la purga efímera de memoria.

**Pre-Installation (WinPE Stage):**
- Particionado GPT/UEFI dinámico mediante inyección de secuencia de tareas XML.
- Inyección de Drivers certificados por modelo (`Total Control Driver Strategy`) y aplicación de baseline de BIOS UEFI Lenovo cifrada.
- Auditoría de integridad de la cadena de arranque, validación de dTPM 2.0 y soporte de Atestación de Salud de Hardware.
- Habilitación de Pre-provisioning BitLocker (XTS-AES 256), asignación de protector dTPM 2.0 y resguardo obligatorio de claves de recuperación en Active Directory DS.
- Validación de Microsoft Defender Antivirus, reglas ASR y enrolamiento desatendido en Defender for Endpoint / XDR.

**Offline Image Servicing (Server-Side):**
- **Features & Runtimes:** Habilitación offline de `.NET 4.8` y `Print-To-PDF`, e inyección bajo demanda de `.NET 3.5` (vía `\sources\sxs`) descartando SMBv1, PowerShell v2 y XPS.
- **Debloat AppX:** Depuración offline de paquetes UWP/AppX no corporativos directamente sobre la imagen base WIM.

**Hardening & Optimization:**
- Inyección de perfiles de energía dinámicos según el factor de forma detectado por WMI (`IsLaptop` vs `IsDesktop`).
- Hardening de Privacidad, Telemetría y Bloqueo de Protocolos Legados (LLMNR / NetBIOS) delegado inmutablemente a **Active Directory GPO** y la compilación dináimica del `unattend.xml`.
- Validación de firmas digitales Authenticode en scripts de PowerShell y cumplimiento de la directiva `ExecutionPolicy AllSigned`.
- Control de integridad criptográfica y validación de hashes SHA-256 pre-ejecución contra manifiesto firmado.

**OOBE Cleanup & LAPS Delivery:**
- AutoLogon temporal, omisión de pantallas interactivas OOBE y ejecución de `<FirstLogonCommands>`.
- Autodestrucción garantizada del archivo `unattend.xml` en el primer inicio de sesión y entrega de credenciales locales a **Microsoft LAPS On-Premise**.
- Purga inmediata de claves de registro `AutoAdminLogon`/`DefaultPassword`, autodestrucción con sobrescritura del `unattend.xml` y entrega de rotación de administrador local a 

**Microsoft LAPS**

**Mantenimiento, Ciclo de Vida & Servicing (Post-Deployment / Lifecycle):**
- Auditoría de salud de hardware SSD S.M.A.R.T. y estado de baterías.
- In-Place Feature Upgrades y activación desatendida de licencias de actualización extendida.
- Sanitización y borrado seguro criptográfico en fase de decomisionamiento.

**Automated Post-Deployment Compliance Testing:**
- Ejecución desatendida de la suite de pruebas Pester para validar que Secure Boot, BitLocker, EDR, ESU, Authenticode e higiene de AutoLogon cumplen con la baseline sin intervención manual.

## Integración e Impresión

- MDT / MECM: Consumir la release desde la ruta del Deployment Share e importar las secuencias de tareas desde el directorio `templates/`.
- Active Directory: Asegurar la vinculación de la directiva `GPO-WIN10-SECURITY-BASELINE-v1.2` en la OU corporativa de destino (`OU=Workstations`,`OU=Corp`,`DC=empresa`,`DC=local`) para la aplicación instantánea de políticas tras la unión al dominio.
