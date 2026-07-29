# LIMPIEZA NATIVA DE PAQUETES APPX / BLOATWARE

# Nombres de paquetes/patrones de bloatware
$BloatwareList = @(
    "Microsoft.ZuneVideo",
    "Microsoft.ZuneMusic",
    "Microsoft.GetHelp",
    "Microsoft.BingNews",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.GamingApp",
    "Microsoft.XboxApp"
)

# Compilación de la lista -> patrón Regex unificado
$RegexPattern = ($BloatwareList -join '|')

# Desaprovisionamiento de la imagen base
# Nota: Se evalúa 'DisplayName' y 'PackageName' para prevenir fallos por valores nulos en WinPE
$ProvisionedApps = Get-AppxProvisionedPackage -Online | Where-Object {
    $_.DisplayName -match $RegexPattern -or $_.PackageName -match $RegexPattern
}

foreach ($App in $ProvisionedApps) {
    $AppName = if ($App.DisplayName) { $App.DisplayName } else { $App.PackageName }
    Write-Host "Removiendo paquete provisionado de la imagen base: $AppName" -ForegroundColor Yellow
    
    Remove-AppxProvisionedPackage -Online -PackageName $App.PackageName -ErrorAction SilentlyContinue | Out-Null
}

# Remoción de AppX del perfil actual y perfiles existentes
$InstalledApps = Get-AppxPackage -AllUsers | Where-Object {
    $_.Name -match $RegexPattern
}

foreach ($App in $InstalledApps) {
    Write-Host "Removiendo AppX instalado en perfiles: $($App.Name)" -ForegroundColor Yellow
    
    # Remoción de paquete para todos los usuarios registrados en el endpoint
    Remove-AppxPackage -Package $App.PackageFullName -AllUsers -ErrorAction SilentlyContinue | Out-Null
}
