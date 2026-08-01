<#
.SYNOPSIS
    Valida y ejecuta el onboarding desatendido de Microsoft Defender Antivirus y EDR (XDR).
.DESCRIPTION
    Verifica el estado de Real-Time Protection, aplica el script de onboarding a Defender for Endpoint
    y valida el funcionamiento del servicio Sense (EDR) y el motor Antimalware.
.PARAMETER OnboardingScriptPath
    Ruta centralizada al script de onboarding corporativo (.cmd o .ps1).
.EXAMPLE
    .\Enable-DefenderEdrOnboarding.ps1 -OnboardingScriptPath "\\NAS-CORP01\Deployment\Security\WindowsDefenderATPOnboardingScript.cmd"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OnboardingScriptPath = "\\NAS-CORP01\Deployment\Security\WindowsDefenderATPOnboardingScript.cmd"
)

$ErrorActionPreference = 'Stop'

try {
    # 1. Verificación y activación del motor Antivirus Defender
    Write-Output "Verificando el estado de Microsoft Defender Antivirus..."
    $DefenderStatus = Get-MpComputerStatus -ErrorAction Stop

    if (-not $DefenderStatus.RealTimeProtectionEnabled) {
        Write-Output "Habilitando Protección en Tiempo Real..."
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
    }

    if (-not $DefenderStatus.AntivirusEnabled) {
        throw "SEGURIDAD CRÍTICA: Microsoft Defender Antivirus se encuentra deshabilitado."
    }

    # 2. Ejecución de Onboarding EDR / Defender for Endpoint (XDR)
    $SenseService = Get-Service -Name "Sense" -ErrorAction SilentlyContinue

    if ($null -eq $SenseService -or $SenseService.Status -ne 'Running') {
        if (-not (Test-Path -Path $OnboardingScriptPath)) {
            throw "No se encontró el script de onboarding de EDR en la ruta: $OnboardingScriptPath"
        }

        Write-Output "Ejecutando onboarding desatendido a Defender for Endpoint (EDR)..."
        $Process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$OnboardingScriptPath`"" -Wait -NoNewWindow -PassThru

        if ($Process.ExitCode -ne 0) {
            throw "Falla al ejecutar el onboarding de EDR. Código de salida: $($Process.ExitCode)"
        }
    }

    # 3. Validar inicio y persistencia del servicio EDR (Sense)
    Set-Service -Name "Sense" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "Sense" -ErrorAction SilentlyContinue

    $SenseStatus = Get-Service -Name "Sense" -ErrorAction Stop
    if ($SenseStatus.Status -ne 'Running') {
        throw "ALERTA DE SEGURIDAD: El servicio EDR (Sense) no pudo ser iniciado."
    }

    Write-Output "Microsoft Defender Antivirus y EDR (Sense) validados y activos. Dispositivo enrolado en Defender XDR."

} catch {
    throw "ERROR CRÍTICO EN ONBOARDING DEFENDER/EDR: $_"
}
