<#
.SYNOPSIS
    Wrapper genérico de Task Sequence con validación de integridad, logging centralizado
    y manejo de errores.
.DESCRIPTION
    Ejecuta cualquier ScriptBlock dentro de una estructura estandarizada que:
    - Valida integridad SHA-256 (manifest.json) y firma Authenticode del script real
      invocado, antes de cederle el control.
    - Captura tanto excepciones de PowerShell como códigos de salida de procesos
      externos (DISM, ThinInstaller, Diskpart, etc.).
    - Centraliza logs en red, con fallback local si el share no está disponible.
    - Purga best-effort de memoria tras cada ejecución.
.PARAMETER ScriptPath
    Ruta del archivo .ps1 real que el ScriptBlock invoca. Requerido para poder validar
    integridad y firma. Fail-closed por defecto: sin este parámetro, la tarea se aborta,
    salvo -AllowUnvalidatedScript.
.PARAMETER AllowUnvalidatedScript
    Permite ejecutar sin -ScriptPath. Uso previsto solo para lógica inline que no invoca
    un archivo del repo. Cada uso queda registrado como WARNING en el log.
.PARAMETER SkipIntegrityValidation
    Omite la comparación de hash contra manifest.json para esta invocación puntual.
.PARAMETER SkipSignatureValidation
    Omite la validación de firma Authenticode para esta invocación puntual. Bypass
    temporal previsto mientras la PKI corporativa todavía no está disponible para 
    firmar los scripts del repositorio.
    Independiente de -SkipIntegrityValidation: se puede validar integridad sin exigir
    firma, o viceversa.
.PARAMETER ManifestPath
    Ruta al manifest.json a validar contra. Default: ubicación estándar en NAS-CORP01.
.EXAMPLE
    # Producción, con PKI ya operativa:
    .\Invoke-DeploymentTask.ps1 -TaskName "BIOS-Baseline" `
        -ScriptPath "\\NAS-CORP01\Deployment\Scripts\src\bios\Set-LenovoBiosBaseline.ps1" `
        -ScriptBlock { & "...\Set-LenovoBiosBaseline.ps1" -BiosPassword $SecurePass }
.EXAMPLE
    # Desarrollo local, sin certificado de firma todavía:
    .\Invoke-DeploymentTask.ps1 -TaskName "Test-Features" -SkipSignatureValidation `
        -ScriptPath ".\src\features\Enable-WindowsOptionalFeatures.ps1" `
        -ManifestPath ".\manifest.json" `
        -ScriptBlock { Write-Host "simulando ejecucion..." }
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Nombre descriptivo de la tarea para el log")]
    [string]$TaskName,

    [Parameter(Mandatory = $true, HelpMessage = "Bloque de código PowerShell a ejecutar")]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory = $false, HelpMessage = "Ruta del script real a validar antes de ejecutar")]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [switch]$AllowUnvalidatedScript,

    [Parameter(Mandatory = $false)]
    [switch]$SkipIntegrityValidation,

    [Parameter(Mandatory = $false)]
    [switch]$SkipSignatureValidation,

    [Parameter(Mandatory = $false)]
    [string]$ManifestPath = "\\NAS-CORP01\Deployment\manifest.json",

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "\\NAS-CORP01\Deployment\Logs",

    [Parameter(Mandatory = $false)]
    [string]$LocalFallbackLogPath = "C:\Windows\Temp\DeploymentLogs",

    [Parameter(Mandatory = $false)]
    [string]$IntegrityToolsPath
)

$ErrorActionPreference = 'Stop'

if (-not $IntegrityToolsPath) {
    $IntegrityToolsPath = (Resolve-Path (Join-Path $PSScriptRoot "..\security")).ProviderPath
}

$PhysicalAdapter = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration |
    Where-Object {
        $_.IPEnabled -eq $true -and
        $_.DefaultIPGateway -and
        $_.Description -notmatch 'Virtual|VPN|Loopback|Hyper-V|Tunnel'
    } |
    Select-Object -First 1

$MacAddress = if ($PhysicalAdapter) {
    $PhysicalAdapter.MACAddress -replace ':', ''
} else {
    "UNKNOWN-MAC-$(Get-Date -Format 'yyyyMMddHHmmss')"
}

$ExecutionLogName = "$($MacAddress)_Deployment_Execution.log"
$ExecutionLog = Join-Path -Path $LogPath -ChildPath $ExecutionLogName
$UsingFallbackLog = $false

function Write-DeploymentLog {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] [$TaskName] $Message"
    Write-Host $LogEntry

    try {
        $LogEntry | Out-File -FilePath $ExecutionLog -Append -Encoding utf8 -ErrorAction Stop
    } catch {
        if (-not $UsingFallbackLog) {
            $script:UsingFallbackLog = $true
            if (-not (Test-Path $LocalFallbackLogPath)) {
                New-Item -Path $LocalFallbackLogPath -ItemType Directory -Force | Out-Null
            }
            $script:ExecutionLog = Join-Path -Path $LocalFallbackLogPath -ChildPath $ExecutionLogName
            Write-Host "[$TimeStamp] [WARNING] [$TaskName] Log de red inaccesible ('$LogPath'). Usando fallback local: $ExecutionLog"
        }
        $LogEntry | Out-File -FilePath $ExecutionLog -Append -Encoding utf8 -ErrorAction SilentlyContinue
    }
}

$ExitCode = 0

try {
    Write-DeploymentLog -Message "Iniciando ejecución de la tarea..." -Level "INFO"

    if (-not $ScriptPath) {
        if (-not $AllowUnvalidatedScript) {
            throw "SEGURIDAD CRÍTICA: -ScriptPath no fue provisto. Use -AllowUnvalidatedScript solo para lógica inline que no invoca un archivo del repo."
        }
        Write-DeploymentLog -Message "ADVERTENCIA DE SEGURIDAD: Ejecutando sin -ScriptPath por -AllowUnvalidatedScript. No se valida integridad ni firma." -Level "WARNING"
    } else {
        $ResolvedScriptPath = (Resolve-Path -LiteralPath $ScriptPath -ErrorAction Stop).ProviderPath

        if ($SkipIntegrityValidation) {
            Write-DeploymentLog -Message "Validación de integridad SHA-256 omitida explícitamente para: $ResolvedScriptPath" -Level "WARNING"
        } else {
            Write-DeploymentLog -Message "Validando integridad SHA-256 contra manifest.json..." -Level "INFO"
            & (Join-Path $IntegrityToolsPath "Confirm-ScriptIntegrity.ps1") -Action Validate -ManifestPath $ManifestPath
        }

        if ($SkipSignatureValidation) {
            Write-DeploymentLog -Message "ADVERTENCIA DE SEGURIDAD: Validación de firma Authenticode omitida explícitamente (PKI no disponible aún) para: $ResolvedScriptPath" -Level "WARNING"
        } else {
            Write-DeploymentLog -Message "Validando firma Authenticode de: $ResolvedScriptPath" -Level "INFO"
            $SignatureValid = & (Join-Path $IntegrityToolsPath "Set-AuthenticodeSignature.ps1") -ScriptPath $ResolvedScriptPath -ValidateOnly
            if (-not $SignatureValid) {
                throw "SEGURIDAD CRÍTICA: Firma Authenticode inválida o ausente en: $ResolvedScriptPath"
            }
        }
    }

    & $ScriptBlock

    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "El proceso externo invocado dentro de la tarea finalizó con código de salida $LASTEXITCODE."
    }

    Write-DeploymentLog -Message "Tarea completada exitosamente." -Level "INFO"

} catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.InvocationInfo.MyCommand
    Write-DeploymentLog -Message "ERROR CRÍTICO en [$FailedItem]: $ErrorMessage" -Level "ERROR"
    $ExitCode = 1

} finally {
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-DeploymentLog -Message "Limpieza de memoria y finalización del wrapper. Exit code: $ExitCode" -Level "INFO"
}

exit $ExitCode
