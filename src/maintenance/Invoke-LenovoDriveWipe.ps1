<#
.SYNOPSIS
    Ejecuta la sanitización de almacenamiento bajo el estándar NIST SP 800-88 Rev. 1 (Purge/Clear).
.DESCRIPTION
    Invoca la instrucción nativa NVMe Sanitize/Cryptographic Erase (ses=1) o sobreescritura
    verificada (diskpart clean all) y la llamada UEFI Lenovo previa autenticación por BIOS.
.PARAMETER SupervisorPassword
    Contraseña de Supervisor de BIOS configurada como SecureString.
.PARAMETER Method
    Método de borrado: 'NfmePurge' (Default/NVMe ses=1), 'DiskpartClear' (Clean All) o 'LenovoUefiWipe'.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$SupervisorPassword,

    [Parameter(Mandatory = $false)]
    [ValidateSet('NvmePurge', 'DiskpartClear', 'LenovoUefiWipe')]
    [string]$Method = 'NvmePurge'
)

function Invoke-SecureDriveWipe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$SupervisorPassword,

        [Parameter(Mandatory = $false)]
        [string]$Method = 'NvmePurge'
    )

    $ErrorActionPreference = 'Stop'

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SupervisorPassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    try {
        $PhysicalDisk = Get-PhysicalDisk | Where-Object { $_.BusType -in @('NVMe', 'SATA') } | Select-Object -First 1
        if ($null -eq $PhysicalDisk) {
            throw "No se detectó un disco físico válido para sanitizar."
        }

        Write-Host "Iniciando sanitización NIST SP 800-88 Rev. 1 sobre: $($PhysicalDisk.Model) [$($PhysicalDisk.BusType)]" -ForegroundColor Yellow

        switch ($Method) {
            'NvmePurge' {
                if ($PhysicalDisk.BusType -ne 'NVMe') {
                    throw "El método NvmePurge requiere un bus NVMe. El disco detectado es $($PhysicalDisk.BusType)."
                }
                Write-Host "Ejecutando NVMe Format con Crypto Erase / Sanitize (ses=1)..." -ForegroundColor Cyan
                # Invocación CLI nativa NVMe en entorno WinPE / Linux Admin Tool
                $NvmeCmd = "nvme format /dev/nvme0n1 --ses=1 --force"
                $Process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $NvmeCmd" -Wait -NoNewWindow -PassThru
                if ($Process.ExitCode -ne 0) {
                    throw "Falló la ejecución de 'nvme format --ses=1'. Código de salida: $($Process.ExitCode)"
                }
                Write-Output "Sanitización NIST SP 800-88 Rev. 1 (Purge) completada con éxito vía NVMe Command Set."
            }

            'DiskpartClear' {
                Write-Host "Ejecutando sobreescritura completa (Diskpart Clean All)..." -ForegroundColor Cyan
                $DiskpartScript = Join-Path $env:TEMP "diskpart_clean_all.txt"
                "select disk $($PhysicalDisk.DeviceId)`nclean all" | Out-File -FilePath $DiskpartScript -Encoding ascii
                
                $Process = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$DiskpartScript`"" -Wait -NoNewWindow -PassThru
                Remove-Item -Path $DiskpartScript -Force -ErrorAction SilentlyContinue
                
                if ($Process.ExitCode -ne 0) {
                    throw "Falló la ejecución de 'diskpart clean all'. Código de salida: $($Process.ExitCode)"
                }
                Write-Output "Sanitización NIST SP 800-88 Rev. 1 (Clear) completada con éxito vía sobreescritura Diskpart."
            }

            'LenovoUefiWipe' {
                $LenovoWmi = Get-CimClass -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -ErrorAction SilentlyContinue
                if ($null -eq $LenovoWmi) {
                    throw "El proveedor CIM de Lenovo (root\wmi:Lenovo_SetBiosSetting) no está disponible."
                }

                $WipeResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = "SecureWipe,Enable;" }
                if ($WipeResult.return -ne "Success") {
                    throw "No se pudo habilitar 'SecureWipe' en la BIOS. Código: $($WipeResult.return)"
                }

                $AuthResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SetBiosSetting" -MethodName "SetBiosSetting" -Arguments @{ Parameter = "Supervisor Password,Set,$PlainPassword;" }
                if ($AuthResult.return -ne "Success") {
                    throw "Autenticación de BIOS fallida. Retorno: $($AuthResult.return)"
                }

                $SaveResult = Invoke-CimMethod -Namespace "root\wmi" -ClassName "Lenovo_SaveBiosSettings" -MethodName "SaveBiosSettings"
                if ($SaveResult.return -ne "Success") {
                    throw "Falla al persistir la instrucción de borrado en la NVRAM. Retorno: $($SaveResult.return)"
                }

                Write-Output "Instrucción de borrado seguro programada en UEFI para el próximo reinicio."
            }
        }

    } catch {
        throw "ERROR CRÍTICO EN DECOMISIONAMIENTO / DRIVE WIPE: $_"
    } finally {
        if ($BSTR -ne [System.IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
        $PlainPassword = $null
        [System.GC]::Collect()
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $PSBoundParameters.ContainsKey('SupervisorPassword')) {
    Invoke-SecureDriveWipe -SupervisorPassword $SupervisorPassword -Method $Method
}
