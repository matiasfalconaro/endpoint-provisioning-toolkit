# Gestión de Credenciales de BIOS en Despliegues Desatendidos
Mecanismos homologados para aprovisionar la contraseña de Supervisor de BIOS sin intervención de operador (MDT, MECM, PXE o Intune).

## Opción B.1: Cifrado Simétrico / DPAPI
**Uso:** Task Sequences de MDT/MECM o entornos aislados sin GUI.
>Nota de Seguridad: Cifrado dependiente del contexto. Si la TS ejecuta como SYSTEM, el archivo .key debe ser generado bajo la misma identidad SYSTEM.

```
# 1. Generar contenedor cifrado (N3 / SysAdmin)
.\src\Bios\New-BiosEncryptedSecret.ps1 -BiosPassword (Read-Host -AsSecureString) -OutputPath "\\<SHARE>\Secrets\BiosSecret.key"

# 2. Aplicar en Task Sequence
.\src\Bios\Set-LenovoBiosWithDpapi.ps1 -KeyPath "\\<SHARE>\Secrets\BiosSecret.key"
```

## Opción B.2: ThinkBios-Config (Estándar Recomendado)
**Uso:** Estándar obligatorio para MDT/MECM o Microsoft Intune.
**Ventaja:** Elimina contraseñas en memoria de PowerShell empaquetándolas en hash no revertible (.ini/.bin) mediante Lenovo Settings Encrypter.

```
# 1. Compilar baseline cifrada con Lenovo Settings Encrypter y guardar en servidor
# 2. Invocar desde Task Sequence / Intune
.\src\Bios\Set-LenovoBiosWithThinkBios.ps1 -ConfigFile "\\<SHARE>\Baselines\ThinkPad_T14_Baseline_Encrypted.ini"
```
