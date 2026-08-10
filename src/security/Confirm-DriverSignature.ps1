<#
.SYNOPSIS
    Audita la firma digital (WHQL/Authenticode) de los controladores inyectados en el sistema.
.DESCRIPTION
    Ejecuta Get-WindowsDriver contra la imagen (online u offline) para detectar controladores
    de terceros sin firma digital válida tras la inyección Server-Side vía PnPUtil/DISM
    (Sección 7.3). Si se detecta al menos un driver no firmado, el script aborta la ejecución
    para evitar la entrega de un endpoint con controladores no verificados (Total Control
    Driver Strategy).

    La llamada a Get-WindowsDriver se aísla detrás de la función Get-DriverInventory para
    permitir un mockeo confiable en Pester: al ser un cmdlet del módulo binario Dism con
    parameter sets mutuamente excluyentes, el mockeo directo del cmdlet puede no interceptar
    de forma consistente. Get-DriverInventory, al ser una función simple de script, sí es
    mockeable de forma determinística.
.PARAMETER TargetDrive
    Unidad montada a auditar cuando se ejecuta en modo offline (WinPE, sobre la imagen recién
    aplicada). Si se omite y -Online no se especifica, se asume auditoría Online sobre el
    sistema en ejecución.
.PARAMETER Online
    Indica que la auditoría debe ejecutarse contra el sistema operativo actualmente en
    ejecución (Get-WindowsDriver -Online), en lugar de una imagen offline montada.
.EXAMPLE
    .\Confirm-DriverSignature.ps1 -Online
.EXAMPLE
    .\Confirm-DriverSignature.ps1 -TargetDrive "W:\"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetDrive,

    [Parameter(Mandatory = $false)]
    [switch]$Online
)

if (-not (Get-Command Get-DriverInventory -ErrorAction SilentlyContinue)) {
    function global:Get-DriverInventory {
        [CmdletBinding()]
        param(
            [switch]$Online,
            [string]$Path
        )

        if ($Online) {
            return Get-WindowsDriver -Online
        }
        return Get-WindowsDriver -Path $Path
    }
}

function Invoke-DriverSignatureAudit {
    [CmdletBinding()]
    param(
        [string]$TargetDrive,
        [switch]$Online
    )

    $ErrorActionPreference = 'Stop'

    try {
        if ($Online) {
            Write-Output "Auditando firma digital de controladores en modo Online (sistema en ejecución)..."
            $DriverInventory = Get-DriverInventory -Online
        }
        elseif ($TargetDrive) {
            if (-not (Test-Path -Path $TargetDrive)) {
                throw "La ruta de imagen offline especificada no existe: $TargetDrive"
            }
            Write-Output "Auditando firma digital de controladores en modo Offline sobre: $TargetDrive..."
            $DriverInventory = Get-DriverInventory -Path $TargetDrive
        }
        else {
            throw "Debe especificar -Online o -TargetDrive para determinar el alcance de la auditoría."
        }

        $UnsignedDrivers = $DriverInventory | Where-Object { $_.Signed -eq $false }

        if ($UnsignedDrivers.Count -gt 0) {
            Write-Output "ALERTA: Se detectaron $($UnsignedDrivers.Count) controlador(es) sin firma digital válida:"
            foreach ($Driver in $UnsignedDrivers) {
                Write-Output "  - $($Driver.OriginalFileName) | Proveedor: $($Driver.ProviderName) | ClassName: $($Driver.ClassName)"
            }

            throw "SEGURIDAD CRÍTICA: Inyección de driver(es) no firmado(s) detectada. Abortando conforme a la estrategia Total Control Driver Strategy (Sección 7.3)."
        }

        Write-Output "Auditoría de firma digital completada exitosamente. Todos los controladores inyectados cuentan con firma válida ($($DriverInventory.Count) driver(s) verificados)."

        return $DriverInventory

    } catch {
        throw "ERROR CRÍTICO EN AUDITORÍA DE FIRMA DE DRIVERS: $_"
    }
}

# Guarda de invocación
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-DriverSignatureAudit -TargetDrive $TargetDrive -Online:$Online
}
