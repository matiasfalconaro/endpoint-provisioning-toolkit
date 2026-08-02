& ".\src\core\Invoke-DeploymentTask.ps1" `
    -TaskName "Test-NoPath" `
    -ScriptBlock { Write-Host 'esto no deberia importar' }
exit $LASTEXITCODE
