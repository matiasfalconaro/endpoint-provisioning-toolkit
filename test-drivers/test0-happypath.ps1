& ".\src\core\Invoke-DeploymentTask.ps1" `
    -TaskName "Test-HappyPath" `
    -ScriptPath ".\src\features\Enable-WindowsOptionalFeatures.ps1" `
    -ManifestPath ".\manifest.json" `
    -SkipIntegrityValidation `
    -SkipSignatureValidation `
    -ScriptBlock { Write-Host 'Simulando tarea...' }
exit $LASTEXITCODE
