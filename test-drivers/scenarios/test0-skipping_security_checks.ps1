<#
.SYNOPSIS
    [USO EXCLUSIVO PARA DEBUGGING LOCAL] Happy path omitiendo validaciones SHA-256/Authenticode.
.DESCRIPTION
    Este driver omite deliberadamente los controles de integridad y firma de
    Invoke-DeploymentTask.ps1. NO representa el comportamiento del entorno de
    producción. Para la validación estricta equivalente a produccion, ver
    test11-strict_validation.ps1.
#>

& ".\src\core\Invoke-DeploymentTask.ps1" `
    -TaskName "Test-HappyPath" `
    -ScriptPath ".\src\features\Enable-WindowsOptionalFeatures.ps1" `
    -ManifestPath ".\manifest.json" `
    -SkipIntegrityValidation `
    -SkipSignatureValidation `
    -ScriptBlock { Write-Host 'Simulando tarea...' }
exit $LASTEXITCODE
