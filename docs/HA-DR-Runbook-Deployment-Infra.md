# Failover NAS-CORP01/WDS-MDT — Infraestructura de Despliegue HA/DR

**Responsable:** N2 (ejecución) / N3 (aprobación y custodia)

---

## 1. Componentes

| Componente                     | Primario                 | Secundario                   | Sincronización                           |
|--------------------------------|--------------------------|------------------------------|------------------------------------------|
| Repositorio (Drivers/WIM/Logs) | NAS-CORP01               | NAS-CORP02                   | DFS-R / SOFS                             |
| Despliegue (WDS/MDT)           | MDT-SRV01                | MDT-SRV02                    | DFS-R sobre Deployment Share             |
| MDTDB/CMDB                     | SQL primaria             | Réplica AlwaysOn             | SQL Server AlwaysOn AG                   |
| Resolución de nombres          | DEPLOY-VIP.empresa.local | ídem, resuelve a nodo activo | DFS-N o Round Robin DNS con health check |

---

## 2. Triggers de Failover

- `NAS-CORP01` sin respuesta a ping/SMB por más de 5 min.
- Servicio WDS en `MDT-SRV01` en estado `Detenido` o `No responde`.
- Fallo confirmado de la instancia SQL primaria de MDTDB.
- Mantenimiento programado del nodo primario (conmutación planeada).

---

## 3. Conmutación

### 3.1 Almacenamiento (DFS-N / SOFS)

```powershell
Get-DfsrState -ComputerName NAS-CORP02
```
Si la réplica está `Normal`, DFS-N conmuta automáticamente. Si se usa Round Robin DNS sin DFS-N:

```powershell
Remove-DnsServerResourceRecord -ZoneName "empresa.local" -Name "DEPLOY-VIP" `
    -RRType A -RecordData <IP_NAS-CORP01> -Force
```

Verificar:
```powershell
Resolve-DnsName DEPLOY-VIP.empresa.local
```

### 3.2 Servicio de Despliegue (WDS/MDT)

```powershell
Get-Service WDSServer -ComputerName MDT-SRV02
```
Si IP Helper apunta directo a `MDT-SRV01` (no vía VIP), actualizar en switches de distribución a `MDT-SRV02`. Si el failover de SQL AlwaysOn no fue automático:

```sql
ALTER AVAILABILITY GROUP [AG-MDTDB] FAILOVER;
```

### 3.3 Validación

1. Arranque PXE de prueba (equipo de laboratorio): recibe Task Sequence, asigna perfil vía MAC/UUID contra CMDB replicada, logs en `\\NAS-CORP02\Deployment\Logs\`.
2. Registrar en log de incidentes: hora de detección, hora de conmutación, componente afectado, resultado de prueba PXE.

---

## 4. Prueba Trimestral de Failover

**Objetivo:** validar el failover completo dentro de un RTO ≤ 15 min, sin afectar producción.

1. N3 programa la ventana; se notifica a N1/N2 para evitar PXE de producción durante la prueba.
2. Simular caída: detener WDS en `MDT-SRV01` (no apagar el servidor salvo prueba de mayor alcance aprobada por N3); deshabilitar interfaz de `NAS-CORP01` o revocar registro DNS.
3. Ejecutar conmutación (Sección 3), cronometrando cada paso.
4. Arranque PXE de prueba (Sección 3.3).
5. Restaurar nodo primario y confirmar backlog de replicación en 0 antes de cerrar la prueba.

### Registro mínimo por prueba

| Campo                                      | Detalle        |
|--------------------------------------------|----------------|
| Fecha                                      |                |
| Ejecutor (N2) / Aprobador (N3)             |                |
| Hora inicio falla / conmutación completada |                |
| RTO real observado                         |                |
| Resultado PXE                              | Passed / Failed|
| Backlog post-restauración                  |                |
| Incidencias / acciones correctivas         |                |

Archivar en `\\NAS-CORP01\Deployment\Logs\DRTests\` (o nodo activo equivalente).

---

## 5. Falla de Ambos Nodos

Si `NAS-CORP01` y `NAS-CORP02` son inaccesibles simultáneamente, se activa el plan de contingencia de tercer nivel (clave MAK / Subscription Activation / medio USB standalone MDT), dado que no hay infraestructura Server-Side disponible para sostener Zero-Touch estándar.