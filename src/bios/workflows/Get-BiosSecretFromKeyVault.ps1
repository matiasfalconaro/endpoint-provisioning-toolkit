<#
.SYNOPSIS
    Recupera el secreto de Supervisor de BIOS desde Azure Key Vault vía Managed Identity,
    sin persistencia local (Anexo B, Opción C.1).
.PARAMETER VaultName
    Nombre del Key Vault dedicado a Infraestructura.
.PARAMETER SecretName
    Nombre del secreto que contiene la contraseña de Supervisor de BIOS.
.PARAMETER SkipExecution
    Uso exclusivo de pruebas unitarias (dot-source).
.OUTPUTS
    System.Security.SecureString
.NOTES
    Requiere Managed Identity asignada al servidor MDT/MECM o al agente de la TS.
    El valor NUNCA se escribe a disco ni a la salida estándar en texto plano.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$VaultName,

    [Parameter(Mandatory = $false)]
    [string]$SecretName,

    [switch]$SkipExecution
)

function Get-BiosSecretFromKeyVault {
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName
    )

    $ErrorActionPreference = 'Stop'

    try {
        Write-DeploymentLog -Level Info -Message "Solicitando secreto '$SecretName' desde Key Vault '$VaultName'"

        # Autenticación implícita vía Managed Identity del contexto de ejecución.
        $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText:$false

        if (-not $secret) {
            Write-DeploymentLog -Level Error -Message "Key Vault no devolvió un secreto válido"
            throw "Key Vault no devolvió un secreto válido para '$SecretName'"
        }

        Write-DeploymentLog -Level Info -Message "Secreto recuperado correctamente (no se registra el valor)"
        return $secret.SecretValue   # SecureString
    }
    catch {
        Write-DeploymentLog -Level Error -Message "Fallo al recuperar secreto de Key Vault: $($_.Exception.Message)"
        throw
    }
    finally {
        # No hay buffer local que purgar: el valor nunca sale del contexto SecureString.
    }
}

if (-not $SkipExecution) {
    if (-not $VaultName -or -not $SecretName) {
        throw "Los parámetros -VaultName y -SecretName son obligatorios cuando se ejecuta el script directamente."
    }
    Get-BiosSecretFromKeyVault -VaultName $VaultName -SecretName $SecretName
}
