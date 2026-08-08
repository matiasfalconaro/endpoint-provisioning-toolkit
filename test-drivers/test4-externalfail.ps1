& ".\src\core\Invoke-DeploymentTask.ps1" `
    -TaskName "Test-ExternalFail" `
    -ScriptPath ".\src\features\Enable-WindowsOptionalFeatures.ps1" `
    -ManifestPath ".\manifest.json" `
    -SkipIntegrityValidation `
    -SkipSignatureValidation `
    -ScriptBlock { cmd.exe /c exit 87 }
exit $LASTEXITCODE
