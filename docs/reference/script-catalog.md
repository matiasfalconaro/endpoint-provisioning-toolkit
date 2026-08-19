# Anexo D - Catalogo de Scripts (generado automaticamente)

> No editar manualmente. Generado por tools/Generate-ScriptCatalog.ps1 desde comment-based help.

| Script | Proposito | Ruta | Parametros Obligatorios |
|---|---|---|---|
| `Set-LenovoBiosBaseline.ps1` | Aplica la Baseline de BIOS corporativa en equipos Lenovo ThinkPad. | `src/bios/Set-LenovoBiosBaseline.ps1` | -BiosPassword (SecureString) |
| `Get-BiosSecretFromAdGroupSecret.ps1` | Recupera el secreto de Supervisor de BIOS desde el atributo gestionado de AD DS (Anexo B, Opción C.2). Aplica únicamente post-Join de dominio (Fase 2 en adelante). | `src/bios/workflows/Get-BiosSecretFromAdGroupSecret.ps1` | -ComputerObjectDN (String) |
| `Get-BiosSecretFromKeyVault.ps1` | Recupera el secreto de Supervisor de BIOS desde Azure Key Vault vía Managed Identity, sin persistencia local (Anexo B, Opción C.1). | `src/bios/workflows/Get-BiosSecretFromKeyVault.ps1` | -VaultName (String), -SecretName (String) |
| `New-BiosEncryptedSecret.ps1` | Genera un secreto cifrado vía DPAPI para la contraseña de BIOS. | `src/bios/workflows/New-BiosEncryptedSecret.ps1` | -BiosPassword (SecureString), -OutputPath (String) |
| `Set-LenovoBiosWithDpapi.ps1` | Aplica la Baseline de BIOS de Lenovo utilizando un secreto cifrado por DPAPI. | `src/bios/workflows/Set-LenovoBiosWithDpapi.ps1` | -KeyPath (String) |
| `Set-LenovoBiosWithThinkBios.ps1` | Aplica la Baseline de BIOS mediante el módulo oficial ThinkBios-Config. | `src/bios/workflows/Set-LenovoBiosWithThinkBios.ps1` | -ConfigFile (String) |
| `Invoke-DeploymentTask.ps1` | Wrapper genérico de Task Sequence con validación de integridad, logging centralizado y manejo de errores. | `src/core/Invoke-DeploymentTask.ps1` | -TaskName (String), -ScriptBlock (ScriptBlock), -ScriptPath (String), -AllowUnvalidatedScript (SwitchParameter), -SkipIntegrityValidation (SwitchParameter), -SkipSignatureValidation (SwitchParameter), -ManifestPath (String), -LogPath (String), -LocalFallbackLogPath (String), -IntegrityToolsPath (String) |
| `Remove-AppxBloatware.ps1` | Elimina paquetes UWP/AppX no corporativos de la imagen de Windows en modo offline. | `src/debloat/Remove-AppxBloatware.ps1` | N/A |
| `Enable-WindowsOptionalFeatures.ps1` | Inyección de Características Opcionales de Windows (Offline Image Servicing). | `src/features/Enable-WindowsOptionalFeatures.ps1` | -TargetDrive (String), -SxSPath (String) |
| `Get-HardwareHealthStatus.ps1` | Obtiene el estado de salud del hardware (SSD S.M.A.R.T., Batería y BIOS/Firmware). | `src/maintenance/Get-HardwareHealthStatus.ps1` | N/A |
| `Get-PerformanceHealthStatus.ps1` | Audita el rendimiento y la salud térmica del sistema (CPU, Temperatura y Throughput de Disco NVMe/SATA). | `src/maintenance/Get-PerformanceHealthStatus.ps1` | -MaxCpuTemperatureCelsius (Double), -MaxCpuIdlePercent (Double), -MinNvmeThroughputMBs (Double), -MinSataThroughputMBs (Double) |
| `Invoke-LenovoDriveWipe.ps1` | Ejecuta la sanitización de almacenamiento bajo el estándar NIST SP 800-88 Rev. 1 (Purge/Clear). | `src/maintenance/Invoke-LenovoDriveWipe.ps1` | -SupervisorPassword (SecureString), -Method (String) |
| `Set-WindowsPowerAndServicesOptimization.ps1` | Ajuste dinámico de perfiles de energía por factor de forma (Task Sequence Step). | `src/optimization/Set-WindowsPowerAndServicesOptimization.ps1` | N/A |
| `Invoke-EsuActivation.ps1` | Inyecta y activa desatendidamente licencias Extended Security Updates (ESU) vía WMI/CIM. | `src/provisioning/Invoke-EsuActivation.ps1` | -EsuProductKey (String) |
| `Register-AutopilotHardwareHash.ps1` | Registro asistido del Hardware Hash (4K HH) en Intune/Entra ID para el flujo paralelo Autopilot (Sección 6.4). Uso exclusivo de N3/Compras — no se ejecuta dentro de la Task Sequence On-Premise. | `src/provisioning/Register-AutopilotHardwareHash.ps1` | N/A |
| `Clear-AutoLogonCredentials.ps1` | Sanitiza y destruye las credenciales de AutoLogon y archivos de respuesta desatendidos. | `src/security/Clear-AutoLogonCredentials.ps1` | N/A |
| `Confirm-ScriptIntegrity.ps1` | Genera o valida el manifiesto de integridad de hashes SHA-256 de los scripts del repositorio. | `src/security/Confirm-ScriptIntegrity.ps1` | -Action (String), -ManifestPath (String), -SourcePath (String) |
| `Enable-BitLockerValidation.ps1` | Valida, configura y respalda las claves de BitLocker en Active Directory / Entra ID. | `src/security/Enable-BitLockerValidation.ps1` | N/A |
| `Enable-DefenderEdrOnboarding.ps1` | Valida y ejecuta el onboarding desatendido de Microsoft Defender Antivirus y EDR (XDR). | `src/security/Enable-DefenderEdrOnboarding.ps1` | -OnboardingScriptPath (String), -OnboardingTimeoutSeconds (Int32), -SenseServiceTimeoutSeconds (Int32) |
| `Get-BootAttestationStatus.ps1` | Audita el estado de Secure Boot, dTPM 2.0 y Measured Boot/Atestación en el endpoint. | `src/security/Get-BootAttestationStatus.ps1` | N/A |
| `Invoke-CriticalPatchGate.ps1` | Aplica de forma desatendida un parche crítico "Zero-Day" (Critical Ring) como paso final post-OS / pre-entrega dentro de la Task Sequence. | `src/security/Invoke-CriticalPatchGate.ps1` | N/A |
| `Set-AuthenticodeSignature.ps1` | Firma digitalmente scripts de PowerShell con un certificado Authenticode o valida su integridad. | `src/security/Set-AuthenticodeSignature.ps1` | -ScriptPath (String), -CertificateThumbprint (String), -ValidateOnly (SwitchParameter) |
| `Get-TouchlessComplianceRate.ps1` | Calcula el indicador agregado mensual de % de flota sin evidencia de interacción manual (Sección 16.2), excluyendo intervenciones autorizadas documentadas en ticket. | `src/testing/Get-TouchlessComplianceRate.ps1` | N/A |
| `Invoke-PostDeploymentTest.ps1` | Ejecutor de pruebas de cumplimiento e integración para la Task Sequence. | `src/testing/Invoke-PostDeploymentTest.ps1` | -ReportPath (String) |
| `Test-DeploymentCompliance.Tests.ps1` | Suite de Pruebas de Cumplimiento Post-Aprovisionamiento Pester (Zero-Touch Validation). | `src/testing/Test-DeploymentCompliance.Tests.ps1` | -DeploymentRoot (String) |
| `Test-OobeInteractionAudit.ps1` | Audita evidencia de interacción manual durante el flujo OOBE (Contexto 9). | `src/testing/Test-OobeInteractionAudit.ps1` | N/A |
