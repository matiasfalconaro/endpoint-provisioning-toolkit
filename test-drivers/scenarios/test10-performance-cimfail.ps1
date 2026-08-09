if ($env:ALLOW_HAZARDOUS_TESTS -ne 'true') {
    Write-Host "Este test requiere `$env:ALLOW_HAZARDOUS_TESTS = 'true'. Abortando por seguridad." -ForegroundColor Red
    exit 1
}
& "$PSScriptRoot\..\mocks\Get-PerformanceHealthStatus.MockFail.ps1"
exit $LASTEXITCODE
