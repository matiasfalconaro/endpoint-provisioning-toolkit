<#
.SYNOPSIS
    Wrapper genÃ©rico de Task Sequence con validaciÃ³n de integridad, logging centralizado
    y manejo de errores.
.DESCRIPTION
    Ejecuta cualquier ScriptBlock dentro de una estructura estandarizada que:
    - Valida integridad SHA-256 (manifest.json) y firma Authenticode del script real
      invocado, antes de cederle el control.
    - Captura tanto excepciones de PowerShell como cÃ³digos de salida de procesos
      externos (DISM, ThinInstaller, Diskpart, etc.).
    - Centraliza logs en red, con fallback local si el share no estÃ¡ disponible.
    - Purga best-effort de memoria tras cada ejecuciÃ³n.
.PARAMETER ScriptPath
    Ruta del archivo .ps1 real que el ScriptBlock invoca. Requerido para poder validar
    integridad y firma. Fail-closed por defecto: sin este parÃ¡metro, la tarea se aborta,
    salvo -AllowUnvalidatedScript.
.PARAMETER AllowUnvalidatedScript
    Permite ejecutar sin -ScriptPath. Uso previsto solo para lÃ³gica inline que no invoca
    un archivo del repo. Cada uso queda registrado como WARNING en el log.
.PARAMETER SkipIntegrityValidation
    Omite la comparaciÃ³n de hash contra manifest.json para esta invocaciÃ³n puntual.
.PARAMETER SkipSignatureValidation
    Omite la validaciÃ³n de firma Authenticode para esta invocaciÃ³n puntual. Bypass
    temporal previsto mientras la PKI corporativa todavÃ­a no estÃ¡ disponible para 
    firmar los scripts del repositorio.
    Independiente de -SkipIntegrityValidation: se puede validar integridad sin exigir
    firma, o viceversa.
.PARAMETER ManifestPath
    Ruta al manifest.json a validar contra. Default: ubicaciÃ³n estÃ¡ndar en NAS-CORP01.
.EXAMPLE
    # ProducciÃ³n, con PKI ya operativa:
    .\Invoke-DeploymentTask.ps1 -TaskName "BIOS-Baseline" `
        -ScriptPath "\\NAS-CORP01\Deployment\Scripts\src\bios\Set-LenovoBiosBaseline.ps1" `
        -ScriptBlock { & "...\Set-LenovoBiosBaseline.ps1" -BiosPassword $SecurePass }
.EXAMPLE
    # Desarrollo local, sin certificado de firma todavÃ­a:
    .\Invoke-DeploymentTask.ps1 -TaskName "Test-Features" -SkipSignatureValidation `
        -ScriptPath ".\src\features\Enable-WindowsOptionalFeatures.ps1" `
        -ManifestPath ".\manifest.json" `
        -ScriptBlock { Write-Host "simulando ejecucion..." }
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'TaskName',
    Justification = 'Usado dentro del closure Write-DeploymentLog; PSScriptAnalyzer no rastrea uso en funciones anidadas.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'LocalFallbackLogPath',
    Justification = 'Usado dentro del closure Write-DeploymentLog (bloque catch); mismo caso que TaskName.'
)]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Nombre descriptivo de la tarea para el log")]
    [string]$TaskName,

    [Parameter(Mandatory = $true, HelpMessage = "Bloque de cÃ³digo PowerShell a ejecutar")]
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

            $FallbackNotice = "[$TimeStamp] [WARNING] [$TaskName] Log de red inaccesible ('$LogPath'). Usando fallback local: $ExecutionLog"
            Write-Host $FallbackNotice
            $FallbackNotice | Out-File -FilePath $ExecutionLog -Append -Encoding utf8 -ErrorAction SilentlyContinue
        }
        $LogEntry | Out-File -FilePath $ExecutionLog -Append -Encoding utf8 -ErrorAction SilentlyContinue
    }
}

$ExitCode = 0

try {
    Write-DeploymentLog -Message "Iniciando ejecuciÃ³n de la tarea..." -Level "INFO"

    if (-not $ScriptPath) {
        if (-not $AllowUnvalidatedScript) {
            throw "SEGURIDAD CRÃTICA: -ScriptPath no fue provisto. Use -AllowUnvalidatedScript solo para lÃ³gica inline que no invoca un archivo del repo."
        }
        Write-DeploymentLog -Message "ADVERTENCIA DE SEGURIDAD: Ejecutando sin -ScriptPath por -AllowUnvalidatedScript. No se valida integridad ni firma." -Level "WARNING"
    } else {
        $ResolvedScriptPath = (Resolve-Path -LiteralPath $ScriptPath -ErrorAction Stop).ProviderPath

        if ($SkipIntegrityValidation) {
            Write-DeploymentLog -Message "ValidaciÃ³n de integridad SHA-256 omitida explÃ­citamente para: $ResolvedScriptPath" -Level "WARNING"
        } else {
            Write-DeploymentLog -Message "Validando integridad SHA-256 contra manifest.json..." -Level "INFO"
            & (Join-Path $IntegrityToolsPath "Confirm-ScriptIntegrity.ps1") -Action Validate -ManifestPath $ManifestPath
        }

        if ($SkipSignatureValidation) {
            Write-DeploymentLog -Message "ADVERTENCIA DE SEGURIDAD: ValidaciÃ³n de firma Authenticode omitida explÃ­citamente (PKI no disponible aÃºn) para: $ResolvedScriptPath" -Level "WARNING"
        } else {
            Write-DeploymentLog -Message "Validando firma Authenticode de: $ResolvedScriptPath" -Level "INFO"
            $SignatureValid = & (Join-Path $IntegrityToolsPath "Set-AuthenticodeSignature.ps1") -ScriptPath $ResolvedScriptPath -ValidateOnly
            if (-not $SignatureValid) {
                throw "SEGURIDAD CRÃTICA: Firma Authenticode invÃ¡lida o ausente en: $ResolvedScriptPath"
            }
        }
    }

    & $ScriptBlock

    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "El proceso externo invocado dentro de la tarea finalizÃ³ con cÃ³digo de salida $LASTEXITCODE."
    }

    Write-DeploymentLog -Message "Tarea completada exitosamente." -Level "INFO"

} catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.InvocationInfo.MyCommand
    Write-DeploymentLog -Message "ERROR CRÃTICO en [$FailedItem]: $ErrorMessage" -Level "ERROR"
    $ExitCode = 1

} finally {
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-DeploymentLog -Message "Limpieza de memoria y finalizaciÃ³n del wrapper. Exit code: $ExitCode" -Level "INFO"
}

exit $ExitCode
