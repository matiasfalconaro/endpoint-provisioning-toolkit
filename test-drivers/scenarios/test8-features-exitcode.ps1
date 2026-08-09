powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\..\mocks\Enable-WindowsOptionalFeatures.MockFail.ps1"
exit $LASTEXITCODE