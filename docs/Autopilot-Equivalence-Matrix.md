# Matriz de Equivalencia: GPO On-Premise ↔ Intune Configuration Profile

**Flujo:** Autopilot Remoto vs. Zero-Touch On-Premise
**Responsable:** N3 (Custodio)
**Estado:** Debe validarse antes de producción de cualquier perfil `DeploymentProfile = Remote-Autopilot`

---

## 1. Regla de gobernanza

Ningún perfil Autopilot pasa a producción sin que cada fila de esta matriz tenga estado `Homologado`. Filas en `Pendiente` o `Sin equivalente` deben escalarse a N3 antes del primer despliegue piloto.

---

## 2. Matriz de Equivalencia

| #  | Control                                     | On-Premise (GPO/AD)                                    | Autopilot (Intune)                                                  | Estado                          | Notas                                                                                                  |
|----|---------------------------------------------|--------------------------------------------------------|---------------------------------------------------------------------|---------------------------------|--------------------------------------------------------------------------------------------------------|
| 1  | Nivel de Telemetría                         | `Recopilación de datos / Permitir telemetría` = 0/1    | Settings Catalog → `System/AllowTelemetry`                          | Homologado                      | Mismo valor de registro subyacente.                                                                    |
| 2  | Reconocimiento de voz en línea              | GPO Deshabilitado                                      | Settings Catalog → `Privacy/AllowInputPersonalization`              | Homologado                      |                                                                                                        |
| 3  | Advertising ID                              | GPO Habilitado (desactivar)                            | Settings Catalog → `Privacy/DisableAdvertisingId`                   | Homologado                      |                                                                                                        |
| 4  | Ubicación/Geolocalización                   | GPO Deshabilitado                                      | Settings Catalog → `Privacy/LetAppsAccessLocation` = Force Deny     | Homologado                      |                                                                                                        |
| 5  | Experiencias personalizadas/Trazos          | GPO desactivar personalización de entrada              | Settings Catalog → `TextInput/AllowLinguisticDataCollection`        | Homologado                      |                                                                                                        |
| 6  | Buscar mi dispositivo                       | GPO Deshabilitado                                      | Settings Catalog → `FindMyDevice/LocationSyncEnabled`               | Homologado                      |                                                                                                        |
| 7  | LLMNR                                       | GPO desactivar resolución multidifusión                | Settings Catalog → `DNSClient/TurnOffMulticast`                     | Homologado                      |                                                                                                        |
| 8  | NetBIOS sobre TCP/IP                        | GPO + DHCP Option 001 = Disable                        | Sin equivalente directo                                             | Sin equivalente                 | Requiere script de Proactive Remediation o DHCP del ISP/red — fuera de control administrativo directo. |
| 9  | mDNS                                        | Registro `EnableMDNS = 0`                              | Settings Catalog → `DNSClient/DisableMdns` (build-dependent)        | Pendiente                       | Validar disponibilidad de CSP según build 22H2 antes de homologar.                                     |
| 10 | SMB Signing obligatorio                     | GPO `Digitally sign communications (always)`           | ASR / Settings Catalog `LanManWorkstation/RequireSecuritySignature` | Homologado                      |                                                                                                        |
| 11 | Real-time Protection Defender               | GPO Baseline v1.2                                      | Endpoint Security → Antivirus Policy                                | Homologado                      |                                                                                                        |
| 12 | Cloud-Delivered Protection (High, 60s)      | GPO Baseline v1.2                                      | Antivirus Policy → Cloud Protection Level = High                    | Homologado                      |                                                                                                        |
| 13 | ASR Rules (16 reglas, Block)                | GPO Baseline v1.2                                      | Attack Surface Reduction Policy                                     | Homologado                      | Mapeo 1:1 por GUID de regla.                                                                           |
| 14 | Tamper Protection                           | GPO Baseline v1.2                                      | Antivirus Policy → Tamper Protection = On                           | Homologado                      |                                                                                                        |
| 15 | Onboarding Defender for Endpoint            | Script `WindowsDefenderATPOnboardingScript.cmd` vía TS | EDR Policy (onboarding automático vía tenant)                       | Homologado                      | Mecanismo distinto, resultado equivalente.                                                             |
| 16 | ExecutionPolicy AllSigned                   | GPO `Set-ExecutionPolicy AllSigned`                    | Settings Catalog (según CSP disponible)                             | Pendiente                       | Confirmar CSP exacto; posible script de remediación proactiva.                                         |
| 17 | BitLocker XTS-AES 256 + TPM-Only            | GPO + pre-provisioning en TS                           | Disk Encryption Policy (BitLocker)                                  | Homologado                      | Custodia de clave difiere.                                                                             |
| 18 | Custodia de clave de recuperación BitLocker | AD DS (48 dígitos)                                     | Microsoft Entra ID (escritura automática)                           | Homologado (mecanismo distinto) | Escenario Híbrido/Cloud ya contemplado.                                                                |
| 19 | Secure Boot obligatorio                     | Impuesto vía CIM/WMI en TS                             | No aplica — depende de firmware/fábrica                             | Sin equivalente                 | Requiere homologación con OEM previa al envío.                                                         |
| 20 | Baseline de BIOS/UEFI Lenovo                | CIM/WMI (`Lenovo_SetBiosSetting`) en WinPE             | No aplica — fuera de alcance Autopilot                              | Sin equivalente                 | Aplicar en fábrica por OEM o vía script post-enrolamiento firmado.                                     |
| 21 | Anillo de actualización WUfB Broad Ring     | GPO WSUS/MECM, diferimiento 7/30 días                  | Windows Update for Business                                         | Homologado                      |                                                                                                        |
| 22 | Critical Ring Zero-Day                      | Flag MDTDB + `Invoke-CriticalPatchGate.ps1` en TS      | Pendiente de diseño                                                 | Pendiente                       | Requiere definir mecanismo equivalente vía Intune.                                                     |

---

## 3. Limitaciones no homologables 1:1

1. **BIOS/UEFI (filas 19-20):** Autopilot no ejecuta WinPE ni Task Sequence — la baseline de firmware queda fuera de este mecanismo. Se resuelve contractualmente con el OEM previo al envío del equipo.
2. **NetBIOS sobre TCP/IP (fila 8):** Sin CSP nativo equivalente al DHCP Option 001. Evaluar script de Proactive Remediation como mitigación parcial.
3. **Critical Ring Zero-Day (fila 22):** Pendiente de diseño; no se considera cubierto hasta documentar un mecanismo equivalente (candidato: Windows Autopatch / Expedited Quality Updates).

---

## 4. Procedimiento de Homologación

1. N3 valida cada fila `Pendiente` o `Sin equivalente`: (a) define CSP alternativo, o (b) acepta formalmente el riesgo residual con control compensatorio documentado.
2. Ningún perfil `DeploymentProfile = Remote-Autopilot` se marca `Compliant` en CMDB hasta que las filas 8, 9, 16, 19, 20 y 22 tengan estado distinto de `Pendiente`/`Sin equivalente` sin control compensatorio aprobado.
