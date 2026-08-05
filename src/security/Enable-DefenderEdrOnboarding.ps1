<#
.SYNOPSIS
    Valida y ejecuta el onboarding desatendido de Microsoft Defender Antivirus y EDR (XDR).
.DESCRIPTION
    Verifica el estado de Real-Time Protection, aplica el script de onboarding a Defender for Endpoint
    y valida el funcionamiento del servicio Sense (EDR) y el motor Antimalware.
.PARAMETER OnboardingScriptPath
    Ruta centralizada al script de onboarding corporativo (.cmd o .ps1). Los .ps1 se
    invocan con powershell.exe -File; los .cmd/.bat con cmd.exe /c.
.PARAMETER OnboardingTimeoutSeconds
    Tiempo máximo de espera para que el proceso de onboarding finalice. Default: 300s.
.PARAMETER SenseServiceTimeoutSeconds
    Tiempo máximo de espera (con reintentos) para que el servicio Sense reporte
    'Running' tras el onboarding. Default: 180s.
.EXAMPLE
    .\Enable-DefenderEdrOnboarding.ps1 -OnboardingScriptPath "\\NAS-CORP01\Deployment\Security\WindowsDefenderATPOnboardingScript.cmd"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OnboardingScriptPath = "\\NAS-CORP01\Deployment\Security\WindowsDefenderATPOnboardingScript.cmd",

    [Parameter(Mandatory = $false)]
    [int]$OnboardingTimeoutSeconds = 300,

    [Parameter(Mandatory = $false)]
    [int]$SenseServiceTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'

function Invoke-OnboardingScript {
    param(
        [string]$Path,
        [int]$TimeoutSeconds
    )

    $Extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($Extension) {
        '.ps1' {
            $ProcessArgs = @{
                FilePath     = 'powershell.exe'
                ArgumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Path`"")
            }
        }
        default {
            $ProcessArgs = @{
                FilePath     = 'cmd.exe'
                ArgumentList = @('/c', "`"$Path`"")
            }
        }
    }

    $Process = Start-Process @ProcessArgs -NoNewWindow -PassThru
    $Finished = $Process.WaitForExit($TimeoutSeconds * 1000)

    if (-not $Finished) {
        try { $Process.Kill() } catch { }
        throw "El proceso de onboarding no finalizó dentro de $TimeoutSeconds segundos (posible cuelgue). Proceso terminado forzosamente."
    }

    if ($Process.ExitCode -ne 0) {
        throw "Falla al ejecutar el onboarding de EDR. Código de salida: $($Process.ExitCode)"
    }
}

function Wait-SenseServiceRunning {
    param([int]$TimeoutSeconds)

    # El onboarding de Defender for Endpoint es asincrono: el servicio Sense
    # puede tardar varios minutos en registrarse tras ejecutar el script.
    $PollIntervalSeconds = 10
    $Elapsed = 0

    while ($Elapsed -lt $TimeoutSeconds) {
        $SenseStatus = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
        if ($SenseStatus -and $SenseStatus.Status -eq 'Running') {
            return $true
        }
        Start-Sleep -Seconds $PollIntervalSeconds
        $Elapsed += $PollIntervalSeconds
    }
    return $false
}

try {
    # Verificación y activación del motor Antivirus Defender
    Write-Output "Verificando el estado de Microsoft Defender Antivirus..."
    $DefenderStatus = Get-MpComputerStatus -ErrorAction Stop

    if (-not $DefenderStatus.RealTimeProtectionEnabled) {
        Write-Output "Habilitando Protección en Tiempo Real..."
        # Nota: si Tamper Protection ya está activo, este comando puede fallar
        # por diseño de Microsoft. Si este script corre en una fase posterior
        # a la aplicación de la GPO de Tamper Protection, revisar el orden de
        # ejecución en la Task Sequence.
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
    }

    if (-not $DefenderStatus.AntivirusEnabled) {
        throw "SEGURIDAD CRÍTICA: Microsoft Defender Antivirus se encuentra deshabilitado."
    }

    # Ejecución de Onboarding EDR / Defender for Endpoint (XDR)
    $SenseService = Get-Service -Name "Sense" -ErrorAction SilentlyContinue

    if ($null -eq $SenseService -or $SenseService.Status -ne 'Running') {
        if (-not (Test-Path -Path $OnboardingScriptPath)) {
            throw "No se encontró el script de onboarding de EDR en la ruta: $OnboardingScriptPath"
        }

        Write-Output "Ejecutando onboarding desatendido a Defender for Endpoint (EDR)..."
        Invoke-OnboardingScript -Path $OnboardingScriptPath -TimeoutSeconds $OnboardingTimeoutSeconds
    }

    # Validar inicio y persistencia del servicio EDR (Sense), con reintentos
    Set-Service -Name "Sense" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "Sense" -ErrorAction SilentlyContinue

    Write-Output "Esperando a que el servicio Sense (EDR) quede operativo (hasta $SenseServiceTimeoutSeconds s)..."
    if (-not (Wait-SenseServiceRunning -TimeoutSeconds $SenseServiceTimeoutSeconds)) {
        throw "ALERTA DE SEGURIDAD: El servicio EDR (Sense) no reportó estado 'Running' dentro de $SenseServiceTimeoutSeconds segundos."
    }

    Write-Output "Microsoft Defender Antivirus y EDR (Sense) validados y activos. Dispositivo enrolado en Defender XDR."

} catch {
    throw "ERROR CRÍTICO EN ONBOARDING DEFENDER/EDR: $_"
}
