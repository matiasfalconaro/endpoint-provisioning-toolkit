BeforeAll {
    # Stub para entornos sin el modulo Appx disponible (runners de CI, maquinas
    # de desarrollo sin la imagen de Windows con este modulo cargado)
    if (-not (Get-Command 'Get-AppxProvisionedPackage' -ErrorAction SilentlyContinue)) {
        function global:Get-AppxProvisionedPackage { param([string]$Path) }
    }
    if (-not (Get-Command 'Remove-AppxProvisionedPackage' -ErrorAction SilentlyContinue)) {
        function global:Remove-AppxProvisionedPackage { param([string]$Path, [string]$PackageName) }
    }

    . "$PSScriptRoot\..\..\src\debloat\Remove-AppxBloatware.ps1"
}

Describe "Remove-AppxBloatware" {

    Context "Sin paquetes de bloatware en la imagen" {
        BeforeEach {
            Mock Get-AppxProvisionedPackage { @() }
        }

        It "termina sin invocar Remove-AppxProvisionedPackage si no hay nada que remover" {
            Mock Remove-AppxProvisionedPackage { }
            { Invoke-AppxBloatwareRemoval -TargetDrive "C:\" } | Should -Not -Throw
            Should -Invoke Remove-AppxProvisionedPackage -Times 0 -Exactly
        }
    }

    Context "Todos los paquetes se remueven exitosamente" {
        BeforeEach {
            Mock Get-AppxProvisionedPackage {
                @(
                    [PSCustomObject]@{ DisplayName = 'Microsoft.ZuneVideo';  PackageName = 'Microsoft.ZuneVideo_1.0' },
                    [PSCustomObject]@{ DisplayName = 'Microsoft.BingNews';   PackageName = 'Microsoft.BingNews_1.0' },
                    [PSCustomObject]@{ DisplayName = 'Microsoft.GamingApp';  PackageName = 'Microsoft.GamingApp_1.0' }
                )
            }
            Mock Remove-AppxProvisionedPackage { }
        }

        It "invoca Remove-AppxProvisionedPackage una vez por cada paquete encontrado" {
            { Invoke-AppxBloatwareRemoval -TargetDrive "C:\" } | Should -Not -Throw
            Should -Invoke Remove-AppxProvisionedPackage -Times 3 -Exactly
        }
    }

    Context "Fallo parcial: algunos paquetes no se pueden remover" {
        BeforeEach {
            Mock Get-AppxProvisionedPackage {
                @(
                    [PSCustomObject]@{ DisplayName = 'Microsoft.ZuneVideo'; PackageName = 'Microsoft.ZuneVideo_1.0' },
                    [PSCustomObject]@{ DisplayName = 'Microsoft.BingNews';  PackageName = 'Microsoft.BingNews_1.0' }
                )
            }
            # El primero falla, el segundo tiene exito — el script debe intentar
            # ambos antes de lanzar el throw, no abortar en el primero que falla.
            Mock Remove-AppxProvisionedPackage {
                param([string]$Path, [string]$PackageName)
                if ($PackageName -eq 'Microsoft.ZuneVideo_1.0') {
                    throw "Acceso denegado al remover el paquete"
                }
            }
        }

        It "intenta remover todos los paquetes aunque falle uno, luego lanza excepcion con detalle" {
            { Invoke-AppxBloatwareRemoval -TargetDrive "C:\" } | Should -Throw "*parcialmente fallida*"
            # Confirma que se intentaron ambos (no se aborto en el primero)
            Should -Invoke Remove-AppxProvisionedPackage -Times 2 -Exactly
        }
    }

    Context "Paquetes que no estan en la lista de bloatware no se tocan" {
        BeforeEach {
            Mock Get-AppxProvisionedPackage {
                @(
                    # Este esta en la lista
                    [PSCustomObject]@{ DisplayName = 'Microsoft.ZuneVideo'; PackageName = 'Microsoft.ZuneVideo_1.0' },
                    # Estos NO estan en la lista y no deben tocarse
                    [PSCustomObject]@{ DisplayName = 'Microsoft.WindowsCalculator'; PackageName = 'Microsoft.WindowsCalculator_1.0' },
                    [PSCustomObject]@{ DisplayName = 'Microsoft.Photos'; PackageName = 'Microsoft.Photos_1.0' }
                )
            }
            Mock Remove-AppxProvisionedPackage { }
        }

        It "solo remueve los paquetes que coinciden con la lista de bloatware" {
            Invoke-AppxBloatwareRemoval -TargetDrive "C:\"
            # Solo ZuneVideo debe removerse, no Calculator ni Photos
            Should -Invoke Remove-AppxProvisionedPackage -Times 1 -Exactly
        }
    }
}
