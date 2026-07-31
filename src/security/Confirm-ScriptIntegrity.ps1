<#
.SYNOPSIS
    Genera o valida el manifiesto de integridad de hashes SHA-256 de los scripts del repositorio.
.DESCRIPTION
    Calcula la huella criptográfica SHA-256 de los archivos en src/ y templates/,
    comprará los resultados contra el archivo manifest.json central y notifica cualquier alteración.
.PARAMETER Action
    Determina si se genera un nuevo manifiesto ('Generate') o si se audita el repositorio ('Validate').
.PARAMETER ManifestPath
    Ruta oficial al archivo de manifiesto centralizado.
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
    [string]$SourcePath = "\\NAS-CORP01\Deployment\Scripts"
)

$ErrorActionPreference = 'Stop'

try {
    # 1. Modo Generación de Manifiesto
    if ($Action -eq "Generate") {
        Write-Output "Generando manifiesto de hashes SHA-256 desde: $SourcePath..."
        $Files = Get-ChildItem -Path $SourcePath -Include "*.ps1", "*.xml", "*.template", "*.ini" -Recurse
        
        $ManifestData = @{}
        foreach ($File in $Files) {
            $RelativePath = $File.FullName.Replace($SourcePath, "").TrimStart('\')
            $Hash = (Get-FileHash -Path $File.FullName -Algorithm SHA256).Hash
            $ManifestData[$RelativePath] = $Hash
        }

        $ManifestData | ConvertTo-Json -Depth 3 | Out-File -FilePath $ManifestPath -Encoding utf8
        Write-Output "Manifiesto SHA-256 generado exitosamente en: $ManifestPath"
        return
    }

    # 2. Modo Validación de Integridad Pre-Ejecución
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
