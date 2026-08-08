& ".\src\core\Invoke-DeploymentTask.ps1" `
    -TaskName "Test-Tamper" `
    -ScriptPath ".\src\features\Enable-WindowsOptionalFeatures.ps1" `
    -ManifestPath ".\manifest.json" `
    -SkipSignatureValidation `
    -ScriptBlock { Write-Host 'no deberia llegar aca' }
exit $LASTEXITCODE
