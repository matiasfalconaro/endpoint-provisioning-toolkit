# Endpoint Provisioning Toolkit
Toolkit de automatización para el aprovisionamiento, hardening, depuración y configuración de infraestructura en estaciones de trabajo Windows 10 Enterprise.

## Arquitectura
Los componentes en `src/` y `templates/` son consumidos por el motor de despliegue (MDT / MECM vía PXE o Microsoft Intune en la nube).

## Flujo de Ejecución Automatizado (Task Sequence Pipeline)
1. Pre-Installation (WinPE): Particionado GPT (`diskpart-partition-uefi.txt`) y baseline de BIOS (`Set-LenovoBiosBaseline.ps1` / `ThinkPad_T14_Baseline.ini`).
2. Aislamiento: Creación del workspace aislado `C:\IT_Deployment_<GUID>` y exclusión temporal en Defender (`Invoke-SecureDeploymentEnvironment.ps1`).
3. Features: Habilitación de runtimes y remoción de componentes legacy (`Enable-WindowsOptionalFeatures.ps1`).
4. Hardening & Debloat: Directivas de privacidad (`Set-WindowsPrivacyHardening.ps1`), depuración de AppX Bloatware (`Remove-AppxBloatware.ps1`) y perfiles de energía/chasis (`Set-WindowsPowerAndServicesOptimization.ps1`).
5. OOBE Cleanup: AutoLogon temporal, ejecución de `<FirstLogonCommands>`, purga del workspace y autodestrucción de `unattend.xml`.

## Templates
- `unattend.xml`: Preconfiguración `Sysprep`/`OOBE` y autodestrucción post-ejecución.
- `ts-partition-uefi-gpt.xml`: Snippet de particionado para MDT (`Control.xml`).
- `ThinkPad_T14_Baseline.ini`: Configuración de BIOS para cifrar con `ThinkBios-Config`.

## Integración
- MDT / MECM: Consumir la release v1.2.0 desde el Deployment Share (`\\<SERVER_NAME>\<SHARE_NAME>\Deployment\Scripts`) e invocar los scripts en la Task Sequence.
- Intune: Publicar vía Intune Management Extension o Proactive Remediations.
