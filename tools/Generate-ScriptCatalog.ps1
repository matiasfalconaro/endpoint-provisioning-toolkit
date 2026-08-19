[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$OutputPath = "$RepoRoot\docs\reference\script-catalog.md",
    [string[]]$IncludePaths = @('src', 'templates')
)

$ErrorActionPreference = 'Stop'

function Get-ScriptMetadata {
    param([System.IO.FileInfo]$File)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $File.FullName, [ref]$tokens, [ref]$errors
    )

    if ($errors) {
        Write-Warning "Errores de sintaxis en $($File.FullName): omitido"
        return $null
    }

    # Intentar help a nivel de script
    $helpAst = $ast.GetHelpContent()

    # Fallback: buscar la primera función definida y tomar su help
    $funcAst = $null
    if (-not $helpAst.Synopsis) {
        $funcAst = $ast.Find(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true
        ) | Select-Object -First 1

        if ($funcAst) {
            $helpAst = $funcAst.GetHelpContent()
        }
    }

    # Parámetros: preferir el param() a nivel de script; si no hay
    $paramBlock = $ast.ParamBlock
    if (-not $paramBlock -and $funcAst) {
        $paramBlock = $funcAst.Body.ParamBlock
    }

    $mandatoryParams = @()
    if ($paramBlock) {
        foreach ($p in $paramBlock.Parameters) {
            $isMandatory = $p.Attributes |
                Where-Object { $_.TypeName.Name -eq 'Parameter' } |
                ForEach-Object {
                    $_.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }
                }
            if ($isMandatory) {
                $typeName = $p.StaticType.Name
                $mandatoryParams += "-$($p.Name.VariablePath.UserPath) ($typeName)"
            }
        }
    }

    $synopsisText = 'sin SYNOPSIS documentado'
    if ($helpAst.Synopsis) {
        $synopsisText = ($helpAst.Synopsis.Trim() -replace '\s+', ' ')
    }

    [PSCustomObject]@{
        Script     = $File.Name
        Proposito  = $synopsisText
        Ruta       = ($File.FullName.Substring($RepoRoot.Length + 1) -replace '\\', '/')
        Parametros = if ($mandatoryParams) { $mandatoryParams -join ', ' } else { 'N/A' }
    }
}

$files = foreach ($path in $IncludePaths) {
    Get-ChildItem -Path (Join-Path $RepoRoot $path) -Recurse -Include *.ps1, *.psm1 -File -ErrorAction SilentlyContinue
}

$rows = $files | ForEach-Object { Get-ScriptMetadata -File $_ } | Where-Object { $_ } | Sort-Object Ruta

$titulo = "Catalogo de Scripts"
$aviso  = "No editar manualmente. Generado por tools/Generate-ScriptCatalog.ps1 desde comment-based help."

$md = New-Object System.Collections.Generic.List[string]
$md.Add("$titulo")
$md.Add("")
$md.Add("> $aviso")
$md.Add("")
$md.Add("| Script | Proposito | Ruta | Parametros Obligatorios |")
$md.Add("|---|---|---|---|")
foreach ($r in $rows) {
    $md.Add("| ``$($r.Script)`` | $($r.Proposito) | ``$($r.Ruta)`` | $($r.Parametros) |")
}

$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

$md -join "`n" | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Catalogo generado: $OutputPath ($($rows.Count) scripts)"
