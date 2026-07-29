# Arquitectura del Endpoint Provisioning Toolkit
Toolkit desatendido para el aprovisionamiento, hardening y configuración de Windows 10 Enterprise en hardware Lenovo ThinkPad.

## 1. Diseño

- Zero-Touch: Eliminación total de la intervención técnica manual.
- eclarativo: Configuración mediante plantillas (unattend.xml, .ini, .txt) + PowerShell.
- Zero Secrets: Código desacoplado de credenciales y rutas de infraestructura.
- Idempotente & Resiliente: Ejecución repetible con limpieza garantizada vía bloques try / finally.

## 2. Infraestructura
- On-Premises (PXE / MDT / MECM): Carga en WinPE (particionado GPT + BIOS) y secuencia de tareas en NT AUTHORITY\SYSTEM.
- Cloud / Híbrido (Autopilot / Intune): Despliegue mediante Intune Management Extension (IME) y Proactive Remediations.

![DiagramaArquitectura](img\EndpointProvisioningToolkit.png)

## 4. Seguridad y Credenciales
Gestión de Contraseñas (BIOS)
- Modo Interactivo: SecureString ingresado en consola y purgado de memoria en bloque finally.
- Modo Desatendido: Cifrado simétrico DPAPI (.key) o archivos empaquetados cifrados ThinkBios-Config (.ini/.bin).

Hardening Efímero
- Gestión de Memoria: Liberación explícita de punteros BSTR (ZeroFreeBSTR) y forzado de recolector de basura (GC::Collect).
- Superficie de Ataque: Exclusiones en Defender acotadas estrictamente a C:\IT_Deployment_<GUID> y revocadas en el Teardown.

## 5. Compatibilidad

| Componente         | Requisito de Sistema                   | Proveedor / Módulo                         |
|--------------------|----------------------------------------|--------------------------------------------|
| Windows OS         | Windows 10 Enterprise (x86_64)         | Native System API / Registry               |
| PowerShell         | Windows PowerShell 5.1 / PowerShell 7+ | Engine Execution                           |
| BIOS Management    | Lenovo ThinkPad (L/T/P/X Series)       | WMI Provider (root\wmi) / ThinkBios-Config |
| Partitioning       | UEFI Capable Firmware                  | diskpart.exe                               |
| Feature Management | Windows Image Servicing                | DISM API / Enable-WindowsOptionalFeature   |
