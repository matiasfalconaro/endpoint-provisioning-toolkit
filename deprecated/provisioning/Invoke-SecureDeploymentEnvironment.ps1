# CREACIÓN Y GESTIÓN DE ENTORNO TEMPORAL SEGURO

# Generación de ruta temporal única por sesión de despliegue
$DeploymentID = [System.Guid]::NewGuid().ToString().Substring(0,8)
$WorkDir = "C:\IT_Deployment_$DeploymentID"

New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null

# Exclusión temporal delimitada a la carpeta de la sesión
Add-MpPreference -ExclusionPath $WorkDir
Write-Host "Directorio de trabajo configurado en: $WorkDir" -ForegroundColor Green

try {
    # EJECUCIÓN DE TAREAS DE PROVISIONAMIENTO Y CONFIGURACIÓN
    Write-Host "Ejecutando tareas de provisionamiento dentro de $WorkDir..." -ForegroundColor Cyan

} finally {
    # REVOCACIÓN DE SEGURIDAD Y LIMPIEZA GARANTIZADA (CLEANUP)
    Write-Host "Iniciando proceso de restauración de seguridad y limpieza..." -ForegroundColor Yellow

    # Revoque de exclusión en Microsoft Defender
    Remove-MpPreference -ExclusionPath $WorkDir -ErrorAction SilentlyContinue

    # Eliminación de forma segura el directorio temporal y sus contenidos
    if (Test-Path -Path $WorkDir) {
        Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Validación: La exclusión fue efectivamente retirada
    $RemainingExclusions = (Get-MpPreference).ExclusionPath
    if ($RemainingExclusions -contains $WorkDir) {
        Write-Error "CRÍTICO: No se pudo retirar la exclusión de Defender para $WorkDir. Revisar manualmente."
    } else {
        Write-Host "Seguridad restablecida: Exclusión temporal removida exitosamente." -ForegroundColor Green
    }
}
