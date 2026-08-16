<#
.SYNOPSIS
    Recupera el secreto de Supervisor de BIOS desde el atributo gestionado de AD DS
    (Anexo B, Opción C.2). Aplica únicamente post-Join de dominio (Fase 2 en adelante).
.PARAMETER ComputerObjectDN
    Distinguished Name del objeto de equipo en AD DS.
.PARAMETER SkipExecution
    Uso exclusivo de pruebas unitarias (dot-source).
.OUTPUTS
    System.Security.SecureString
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ComputerObjectDN,

    [switch]$SkipExecution
)

function Get-BiosSecretFromAdGroupSecret {
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'El valor se recibe como texto plano desde el atributo AD msDS-BiosSupervisorSecret; no existe alternativa sin cambiar el modelo de almacenamiento en el esquema. Transporte cifrado vía LDAPS y reposo cifrado vía BitLocker en los DC.')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerObjectDN
    )

    $ErrorActionPreference = 'Stop'

    try {
        Write-DeploymentLog -Level Info -Message "Consultando atributo gestionado de BIOS para $ComputerObjectDN"

        $adObject = Get-ADComputer -Identity $ComputerObjectDN -Properties 'msDS-BiosSupervisorSecret'
        $encryptedValue = $adObject.'msDS-BiosSupervisorSecret'

        if (-not $encryptedValue) {
            Write-DeploymentLog -Level Error -Message "Atributo msDS-BiosSupervisorSecret vacío o no homologado en el esquema"
            throw "Atributo msDS-BiosSupervisorSecret vacío para $ComputerObjectDN"
        }

        $secureString = ConvertTo-SecureString -String $encryptedValue -AsPlainText -Force
        # Nota: el valor almacenado en AD ya se asume cifrado a nivel de transporte (LDAPS)
        # y de reposo (BitLocker en los DC). No se persiste copia local.

        Write-DeploymentLog -Level Info -Message "Secreto recuperado desde AD DS correctamente"
        return $secureString
    }
    catch {
        Write-DeploymentLog -Level Error -Message "Fallo al recuperar secreto desde AD DS: $($_.Exception.Message)"
        throw
    }
}

if (-not $SkipExecution) {
    if (-not $ComputerObjectDN) {
        throw "El parámetro -ComputerObjectDN es obligatorio cuando se ejecuta el script directamente."
    }
    Get-BiosSecretFromAdGroupSecret -ComputerObjectDN $ComputerObjectDN
}
