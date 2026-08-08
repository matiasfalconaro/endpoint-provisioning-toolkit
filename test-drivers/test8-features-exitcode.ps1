powershell -NoProfile -ExecutionPolicy Bypass -File ".\test-drivers\mocks\Enable-WindowsOptionalFeatures.MockFail.ps1"
exit $LASTEXITCODE
