<#
.SYNOPSIS
    Aplica de forma desatendida un parche crítico "Zero-Day" (Critical Ring) como paso
    final post-OS / pre-entrega dentro de la Task Sequence.
.DESCRIPTION
    Consulta el flag centralizado CriticalPatchPending en MDTDB. Si está activo, instala
    el paquete .msu/.cab correspondiente desde el repositorio local, sin depender de
    WSUS en caliente. Registra el resultado como nuevo Context en
    Test-DeploymentCompliance.Tests.ps1 (Sección 12.2a del Runbook).
.PARAMETER KbId
    Identificador KB del parche crítico a aplicar (ej. "KB5031234").
.PARAMETER SkipExecution
    Uso exclusivo de pruebas unitarias (dot-source). Omite la invocación automática
    de la función al cargar el script, permitiendo mockear dependencias antes de
    invocar Invoke-CriticalPatchGate manualmente desde el test.
.NOTES
    Artefacto: src/security/Invoke-CriticalPatchGate.ps1
    Invocado exclusivamente vía wrapper Invoke-DeploymentTask.ps1.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^KB\d{6,7}$')]
    [string]$KbId,

    [string]$RepoRoot = '\\NAS-CORP01\Deployment\Updates\CriticalRing',

    [string]$MdtDbConnectionName = 'MDTDB',

    [switch]$SkipExecution
)

function Get-CriticalPatchPendingFlag {
    param([string]$ConnectionName)
    # Consulta declarativa contra MDTDB. Retorna $true/$false.
    # Implementación real delega en el módulo de acceso a MDTDB ya usado
    # por la Task Sequence para la asignación de perfiles (Sección 6.1, punto 2).
    $flag = Invoke-MdtDbQuery -Connection $ConnectionName `
        -Query "SELECT CriticalPatchPending FROM DeploymentFlags WHERE Active = 1"
    return [bool]$flag
}

function Invoke-CriticalPatchGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^KB\d{6,7}$')]
        [string]$KbId,

        [string]$RepoRoot = '\\NAS-CORP01\Deployment\Updates\CriticalRing',

        [string]$MdtDbConnectionName = 'MDTDB'
    )

    $ErrorActionPreference = 'Stop'

    try {
        Write-DeploymentLog -Level Info -Message "Evaluando Critical Ring para $KbId"

        if (-not (Get-CriticalPatchPendingFlag -ConnectionName $MdtDbConnectionName)) {
            Write-DeploymentLog -Level Info -Message "CriticalPatchPending = false. Se omite instalación."
            return
        }

        $patchPath = Join-Path $RepoRoot "$KbId.msu"
        if (-not (Test-Path -LiteralPath $patchPath)) {
            Write-DeploymentLog -Level Error -Message "Paquete no encontrado en $patchPath"
            throw "Paquete no encontrado: $patchPath"
        }

        Write-DeploymentLog -Level Info -Message "Instalando $KbId en modo silencioso"
        $proc = Start-Process -FilePath 'wusa.exe' `
            -ArgumentList "`"$patchPath`" /quiet /norestart" `
            -Wait -PassThru

        if ($proc.ExitCode -ne 0) {
            Write-DeploymentLog -Level Error -Message "wusa.exe finalizó con código $($proc.ExitCode)"
            throw "wusa.exe ExitCode=$($proc.ExitCode)"
        }

        Write-DeploymentLog -Level Info -Message "$KbId aplicado correctamente (Critical Ring)"
    }
    catch {
        Write-DeploymentLog -Level Error -Message "Excepción en Critical Patch Gate: $($_.Exception.Message)"
        throw
    }
}

if (-not $SkipExecution) {
    if (-not $KbId) {
        throw "El parámetro -KbId es obligatorio cuando se ejecuta el script directamente."
    }
    Invoke-CriticalPatchGate -KbId $KbId -RepoRoot $RepoRoot -MdtDbConnectionName $MdtDbConnectionName
}