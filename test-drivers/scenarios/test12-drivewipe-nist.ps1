if ($env:ALLOW_HAZARDOUS_TESTS -ne 'true') {
    Write-Host "Este test requiere `$env:ALLOW_HAZARDOUS_TESTS = 'true' (simula operaciones de borrado de disco). Abortando por seguridad." -ForegroundColor Red
    exit 1
}
& "$PSScriptRoot\..\mocks\Invoke-LenovoDriveWipe.MockNist.ps1"
exit $LASTEXITCODE
