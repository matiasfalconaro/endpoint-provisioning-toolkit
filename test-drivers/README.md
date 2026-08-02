## Ejecución automatizada (recomendado)

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-drivers\Run-AllTests.ps1
```

Corre los 5 escenarios en orden, valida exit code y contenido del log contra
lo esperado, restaura `manifest.json` automáticamente (incluso si algún test
falla a mitad de camino), archiva los logs de la corrida en
`test-drivers\logs_<timestamp>\`, y muestra un resumen PASS/FAIL al final.

Nota: el "Test 1 - Happy Path (integridad real)" es esperado que falle
si `Invoke-DeploymentTask.ps1` tiene cambios locales sin reflejar aún en
`manifest.json` (es decir, antes de mergear la rama y que CI regenere el
manifiesto). No es un bug del orquestador.
