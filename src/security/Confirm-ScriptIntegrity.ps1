<#
.SYNOPSIS
    Genera o valida el manifiesto de integridad de hashes SHA-256 de los scripts del repositorio.
.DESCRIPTION
    Calcula la huella criptográfica SHA-256 de los archivos en src/ y templates/,
    compara los resultados contra el archivo manifest.json central y notifica cualquier alteración.
.PARAMETER Action
    Determina si se genera un nuevo manifiesto ('Generate') o si se audita el repositorio ('Validate').
.PARAMETER ManifestPath
    Ruta oficial al archivo de manifiesto centralizado.
.PARAMETER SourcePath
    Raíz del repositorio (no de src/ directamente). Si se omite, se resuelve automáticamente
    en base a la ubicación de este script. Compatible con Windows PowerShell 5.1 (WinPE/Task
    Sequence) y PowerShell 7 (CI): no depende de [System.IO.Path]::GetRelativePath, que no
    existe en .NET Framework.
.EXAMPLE
    .\Confirm-ScriptIntegrity.ps1 -Action Validate
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Generate", "Validate")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$ManifestPath = "\\NAS-CORP01\Deployment\manifest.json",

    [Parameter(Mandatory = $false)]
    [string]$SourcePath
)

$ErrorActionPreference = 'Stop'

# Resolución robusta de SourcePath
if (-not $SourcePath) {
    $SourcePath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).ProviderPath
} else {
    $SourcePath = (Resolve-Path -LiteralPath $SourcePath).ProviderPath
}
$SourcePath = $SourcePath.TrimEnd('\', '/')

# Cálculo de ruta relativa sin GetRelativePath
function Get-NormalizedRelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )
    if (-not $FullPath.StartsWith($BasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "No se puede calcular ruta relativa: '$FullPath' no está dentro de '$BasePath'."
    }
    $Relative = $FullPath.Substring($BasePath.Length).TrimStart('\', '/')
    return $Relative -replace '\\', '/'
}

# Alcance explícito: solo src/ y templates/, tal como documenta el docstring
function Get-ScopedTargetFiles {
    param([string]$RepoRoot)

    $ScanFolders = @("src", "templates") | ForEach-Object {
        Join-Path $RepoRoot $_
    } | Where-Object { Test-Path $_ }

    if ($ScanFolders.Count -eq 0) {
        throw "No se encontraron las carpetas 'src' ni 'templates' bajo: $RepoRoot"
    }

    return $ScanFolders | ForEach-Object {
        Get-ChildItem -Path $_ -Include "*.ps1", "*.xml", "*.template", "*.ini" -Recurse
    }
}

try {
    # Modo Generación de Manifiesto
    if ($Action -eq "Generate") {
        Write-Output "Generando manifiesto de hashes SHA-256 desde: $SourcePath (src/, templates/)..."

        $Files = Get-ScopedTargetFiles -RepoRoot $SourcePath

        $ManifestData = @{}
        foreach ($File in $Files) {
            $RelativePath = Get-NormalizedRelativePath -BasePath $SourcePath -FullPath $File.FullName
            $Hash = (Get-FileHash -Path $File.FullName -Algorithm SHA256).Hash
            $ManifestData[$RelativePath] = $Hash
        }

        $ManifestData | ConvertTo-Json -Depth 3 | Out-File -FilePath $ManifestPath -Encoding utf8
        Write-Output "Manifiesto SHA-256 generado exitosamente en: $ManifestPath ($($ManifestData.Count) archivos)"
        return
    }

    # Modo Validación de Integridad Pre-Ejecución
    if (-not (Test-Path -Path $ManifestPath)) {
        throw "SEGURIDAD CRÍTICA: No se encontró el manifiesto de integridad en '$ManifestPath'."
    }

    Write-Output "Cargando manifiesto de integridad y verificando hashes SHA-256..."
    $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json

    $CorruptedFiles = @()

    foreach ($Item in $Manifest.PSObject.Properties) {
        $FilePath = Join-Path -Path $SourcePath -ChildPath $Item.Name

        if (-not (Test-Path -Path $FilePath)) {
            Write-Output "FALTA ARCHIVO: $FilePath"
            $CorruptedFiles += $Item.Name
            continue
        }

        $CurrentHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
        if ($CurrentHash -ne $Item.Value) {
            Write-Output "DISCREPANCIA DE HASH: $($Item.Name) (Esperado: $($Item.Value) | Actual: $CurrentHash)"
            $CorruptedFiles += $Item.Name
        }
    }

    if ($CorruptedFiles.Count -gt 0) {
        throw "FALLA DE INTEGRIDAD: Se detectaron $($CorruptedFiles.Count) archivos alterados o faltantes en el repositorio. Ejecución abortada."
    }

    Write-Output "Validación de integridad completada con éxito. Todos los hashes SHA-256 coinciden."

} catch {
    throw "ERROR CRÍTICO EN CONTROL DE INTEGRIDAD: $_"
}
