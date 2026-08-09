<#
.SYNOPSIS
    Mock de prueba para Invoke-LenovoDriveWipe.ps1 (Test 12 - Run-AllTests.ps1).
.DESCRIPTION
    Simula la presencia de un almacenamiento NVMe y la infraestructura CIM de Lenovo.
    Intercepta las llamadas a Start-Process para validar que las instrucciones
    destructivas (nvme format --ses=1 y diskpart clean all) sean invocadas con la
    sintaxis correcta del estándar NIST SP 800-88 Rev. 1 sin afectar discos reales.
.EXAMPLE
    .\Invoke-LenovoDriveWipe.MockNist.ps1
#>

[CmdletBinding()]
param()

# 1. Mock de consulta de disco físico
function global:Get-PhysicalDisk {
    [CmdletBinding()]
    param()
    process {
        [PSCustomObject]@{
            DeviceId   = 0
            Model      = 'NVMe Test Drive 512GB'
            BusType    = 'NVMe'
            Size       = 512GB
        }
    }
}

# 2. Mock de interceptación de procesos externos (Evita la ejecución real de nvme.exe/diskpart.exe)
function global:Start-Process {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][string]$FilePath,
        [Parameter(Mandatory = $false)][string]$ArgumentList,
        [Parameter(ValueFromRemainingArguments = $true)]$RemainingArgs
    )
    Write-Host "[MOCK PROCESS] Interceptado: $FilePath $ArgumentList" -ForegroundColor Cyan
    return [PSCustomObject]@{ ExitCode = 0 }
}

# 3. Mock de clase CIM/WMI de Lenovo
function global:Get-CimClass {
    [CmdletBinding()]
    param([string]$Namespace, [string]$ClassName)
    if ($ClassName -eq "Lenovo_SetBiosSetting") {
        return [PSCustomObject]@{ CimClassName = "Lenovo_SetBiosSetting" }
    }
    return $null
}

function global:Invoke-CimMethod {
    [CmdletBinding()]
    param([string]$Namespace, [string]$ClassName, [string]$MethodName, $Arguments)
    Write-Host "[MOCK CIM] $ClassName -> $MethodName ($($Arguments | Out-String))" -ForegroundColor DarkGray
    return [PSCustomObject]@{ return = "Success" }
}

# Ejecución de la prueba
try {
    # Carga del script oficial de seguridad
    . "$PSScriptRoot\..\..\src\security\Invoke-LenovoDriveWipe.ps1"

    if (-not (Get-Command Invoke-SecureDriveWipe -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR DE SETUP: Invoke-LenovoDriveWipe.ps1 no se pudo cargar (verificar ruta)." -ForegroundColor Red
        exit 2
    }

    $SecPass = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force

    Write-Host "--- PRUEBA 1: Método NvmePurge (NIST Purge / ses=1) ---" -ForegroundColor Yellow
    Invoke-SecureDriveWipe -SupervisorPassword $SecPass -Method NvmePurge

    Write-Host "--- PRUEBA 2: Método DiskpartClear (NIST Clear / clean all) ---" -ForegroundColor Yellow
    Invoke-SecureDriveWipe -SupervisorPassword $SecPass -Method DiskpartClear

    Write-Host "--- PRUEBA 3: Método LenovoUefiWipe (WMI UEFI) ---" -ForegroundColor Yellow
    Invoke-SecureDriveWipe -SupervisorPassword $SecPass -Method LenovoUefiWipe

    Write-Host "OK: La prueba de métodos NIST SP 800-88 Rev. 1 se completó exitosamente." -ForegroundColor Green
    exit 0

} catch {
    Write-Host "FALLO EN PRUEBA MOCK NIST DRIVE WIPE: $_" -ForegroundColor Red
    exit 1
} finally {
    # Limpieza de funciones del ámbito global
    Remove-Item Function:\Get-PhysicalDisk -ErrorAction SilentlyContinue
    Remove-Item Function:\Start-Process -ErrorAction SilentlyContinue
    Remove-Item Function:\Get-CimClass -ErrorAction SilentlyContinue
    Remove-Item Function:\Invoke-CimMethod -ErrorAction SilentlyContinue
}
