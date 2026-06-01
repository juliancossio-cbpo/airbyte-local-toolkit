# Guía Completa de Airbyte para Ingeniería de Datos

## 📋 Índice

- [Instalación Inicial](#instalación-inicial)
- [Acceso Rápido](#acceso-rápido)
- [Comandos Básicos](#-comandos-básicos)
- [Gestión de Servicios](#-gestión-de-servicios)
- [API y Automatización](#-api-y-automatización)
- [Backups y Recuperación](#-backups-y-recuperación)
- [Monitoreo y Logs](#-monitoreo-y-logs)
- [Optimización y Troubleshooting](#-optimización-y-troubleshooting)
- [Actualizaciones](#-actualizaciones)
- [Integración CI/CD](#-integración-cicd)
- [Comandos Avanzados](#️-comandos-avanzados)
- [Referencias Rápidas](#-referencias-rápidas)
- [Soporte y Recursos](#-soporte-y-recursos)
- [Notas Finales](#-notas-finales)

---

## 🚀 Inicio Rápido

### Instalación Inicial

```bash
# Ejecutar script de instalación
./airbyte-setup.sh

# Dar permisos al script de gestión
chmod +x airbyte-management.sh
```

### Acceso Rápido

```bash
# URL de la interfaz web
# Usa el puerto elegido por el instalador si 8000 estaba ocupado
http://localhost:8000

# Obtener credenciales
abctl local credentials

# Usar script de gestión (menú interactivo)
./airbyte-management.sh

# Usar script de gestión (comando directo)
./airbyte-management.sh start
```

---

## 📦 Comandos Básicos

### Gestión de Servicios con abctl

```bash
# Ver versión de abctl
abctl version

# Instalar Airbyte
abctl local install

# Desinstalar Airbyte
abctl local uninstall

# Ver estado del cluster
abctl local status

# Obtener credenciales
abctl local credentials
```

### Gestión con el Script de Management

```bash
# Iniciar Airbyte
./airbyte-management.sh start

# Detener Airbyte
./airbyte-management.sh stop

# Reiniciar Airbyte
./airbyte-management.sh restart

# Ver estado completo
./airbyte-management.sh status

# Ver credenciales
./airbyte-management.sh credentials

# Desinstalar completamente Airbyte
./airbyte-management.sh uninstall

# Limpiar logs, backups e imágenes no utilizadas
./airbyte-management.sh cleanup
```

---

## 🔧 Gestión de Servicios

### Docker y Kubernetes (Kind)

```bash
# Ver contenedores de Airbyte
docker ps --filter "name=airbyte"

# Ver todos los contenedores (incluyendo detenidos)
docker ps -a --filter "name=airbyte"

# Ver logs del contenedor principal
docker logs airbyte-abctl-control-plane

# Seguir logs en tiempo real
docker logs -f airbyte-abctl-control-plane

# Ejecutar comandos dentro del cluster
docker exec -it airbyte-abctl-control-plane /bin/sh

# Ver pods de Kubernetes
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl

# Ver servicios
docker exec airbyte-abctl-control-plane kubectl get services -n airbyte-abctl

# Describir un pod específico
docker exec airbyte-abctl-control-plane kubectl describe pod <pod-name> -n airbyte-abctl

# Ver recursos del cluster
docker exec airbyte-abctl-control-plane kubectl top pods -n airbyte-abctl
```

### Auto-inicio del Sistema

```bash
# Habilitar auto-inicio usando el script
./airbyte-management.sh enable-autostart

# Verificar estado del servicio
sudo systemctl status airbyte-local

# Ver logs del servicio
sudo journalctl -u airbyte-local -f

# Deshabilitar auto-inicio
./airbyte-management.sh disable-autostart
```

### Inicio Manual Después de Reinicio

```bash
# Verificar que Docker está corriendo
sudo systemctl status docker

# Iniciar Docker si está detenido
sudo systemctl start docker

# Iniciar el contenedor de Airbyte
docker start airbyte-abctl-control-plane

# Verificar que está corriendo
docker ps | grep airbyte

# Acceder a la interfaz
curl http://localhost:8000
```

---

## 🔌 API y Automatización

### Endpoints Principales de la API

```bash
# Health Check
curl http://localhost:8000/api/v1/health

# Listar workspaces
curl -X POST http://localhost:8000/api/v1/workspaces/list \
  -H "Content-Type: application/json" \
  -d '{}'

# Obtener información de un workspace
curl -X POST http://localhost:8000/api/v1/workspaces/get \
  -H "Content-Type: application/json" \
  -d '{"workspaceId": "YOUR_WORKSPACE_ID"}'

# Listar conexiones
curl -X POST http://localhost:8000/api/v1/connections/list \
  -H "Content-Type: application/json" \
  -d '{"workspaceId": "YOUR_WORKSPACE_ID"}'

# Disparar sincronización manual
curl -X POST http://localhost:8000/api/v1/connections/sync \
  -H "Content-Type: application/json" \
  -d '{"connectionId": "YOUR_CONNECTION_ID"}'

# Ver estado de un job
curl -X POST http://localhost:8000/api/v1/jobs/get \
  -H "Content-Type: application/json" \
  -d '{"id": "JOB_ID"}'
```

### Generar Script de Python para API

```bash
# Generar script de ejemplo
./airbyte-management.sh generate-api-script

# Instalar dependencias
pip install requests

# Editar y ejecutar
nano airbyte-api-example.py
python3 airbyte-api-example.py
```

### Script Bash para Automatización

```bash
#!/bin/bash
# sync-all-connections.sh - Sincronizar todas las conexiones

WORKSPACE_ID="your-workspace-id"
API_URL="http://localhost:8000/api/v1"

# Obtener todas las conexiones
CONNECTIONS=$(curl -s -X POST "$API_URL/connections/list" \
  -H "Content-Type: application/json" \
  -d "{\"workspaceId\": \"$WORKSPACE_ID\"}" | \
  jq -r '.connections[].connectionId')

# Sincronizar cada conexión
for CONNECTION_ID in $CONNECTIONS; do
  echo "Sincronizando conexión: $CONNECTION_ID"
  curl -X POST "$API_URL/connections/sync" \
    -H "Content-Type: application/json" \
    -d "{\"connectionId\": \"$CONNECTION_ID\"}"
  sleep 5
done
```

### Configuración de Webhooks

```bash
# Airbyte puede enviar webhooks cuando se completan sincronizaciones
# Configurar en la UI o mediante API:

curl -X POST http://localhost:8000/api/v1/web_backend/connections/update \
  -H "Content-Type: application/json" \
  -d '{
    "connectionId": "YOUR_CONNECTION_ID",
    "webhookUrl": "https://your-webhook-endpoint.com/notify"
  }'
```

---

## 💾 Backups y Recuperación

### Crear Backups

```bash
# Backup completo usando el script
./airbyte-management.sh backup

# Backup manual de la configuración
tar -czf airbyte-backup-$(date +%Y%m%d).tar.gz ~/.airbyte/abctl/

# Backup de volúmenes de Docker
docker run --rm \
  --volumes-from airbyte-abctl-control-plane \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/airbyte-volumes-$(date +%Y%m%d).tar.gz /var/lib/containerd
```

### Restaurar Backups

```bash
# Restaurar usando el script (interactivo)
./airbyte-management.sh restore

# Restaurar manualmente
# 1. Detener Airbyte
./airbyte-management.sh stop

# 2. Restaurar archivos
tar -xzf airbyte-backup-20260215.tar.gz -C ~/

# 3. Reiniciar Airbyte
./airbyte-management.sh start
```

### Backup Automatizado con Cron

```bash
# Editar crontab
crontab -e

# Agregar backup diario a las 2 AM
0 2 * * * /path/to/airbyte-local-toolkit/scripts/airbyte-management.sh backup >> /var/log/airbyte-backup.log 2>&1

# Backup semanal con limpieza
0 3 * * 0 /path/to/airbyte-local-toolkit/scripts/airbyte-management.sh backup && find ~/airbyte-backups -name "*.tar.gz" -mtime +30 -delete
```

### Exportar/Importar Configuraciones

```bash
# Exportar configuración de una conexión (mediante la API)
curl -X POST http://localhost:8000/api/v1/connections/get \
  -H "Content-Type: application/json" \
  -d '{"connectionId": "YOUR_CONNECTION_ID"}' > connection-config.json

# Crear una nueva conexión con la configuración exportada
curl -X POST http://localhost:8000/api/v1/connections/create \
  -H "Content-Type: application/json" \
  -d @connection-config.json
```

---

## 📊 Monitoreo y Logs

### Ver Logs

```bash
# Ver logs usando el script (interactivo)
./airbyte-management.sh logs

# Logs del cluster principal
docker logs airbyte-abctl-control-plane --tail 100

# Logs de un pod específico
docker exec airbyte-abctl-control-plane kubectl logs -n airbyte-abctl <pod-name>

# Logs de todos los pods
docker exec airbyte-abctl-control-plane kubectl logs -n airbyte-abctl --all-containers=true

# Seguir logs en tiempo real
docker exec airbyte-abctl-control-plane kubectl logs -n airbyte-abctl <pod-name> -f

# Logs con timestamps
docker logs airbyte-abctl-control-plane --timestamps

# Logs desde hace 1 hora
docker logs airbyte-abctl-control-plane --since 1h
```

### Monitoreo de Recursos

```bash
# Ver uso de recursos de los contenedores
docker stats --filter "name=airbyte"

# Ver uso de recursos de pods
docker exec airbyte-abctl-control-plane kubectl top pods -n airbyte-abctl

# Ver nodos del cluster
docker exec airbyte-abctl-control-plane kubectl top nodes

# Uso de disco
df -h ~/.airbyte/abctl/data/

# Ver volúmenes de Docker
docker volume ls | grep airbyte
docker volume inspect <volume-name>
```

### Métricas y Alertas

```bash
# Verificar el estado de las conexiones vía API
curl -X POST http://localhost:8000/api/v1/connections/list \
  -H "Content-Type: application/json" \
  -d '{"workspaceId": "YOUR_WORKSPACE_ID"}' | \
  jq '.connections[] | {name: .name, status: .status}'

# Script de monitoreo básico
cat > monitor-airbyte.sh << 'EOF'
#!/bin/bash
while true; do
  if ! curl -s http://localhost:8000/api/v1/health | grep -q "available"; then
    echo "$(date): Airbyte no está respondiendo!" | tee -a /var/log/airbyte-monitor.log
    # Aquí puedes agregar notificaciones (email, Slack, etc.)
  fi
  sleep 60
done
EOF

chmod +x monitor-airbyte.sh
```

---

## 🔍 Optimización y Troubleshooting

### Diagnóstico de Problemas

```bash
# Diagnóstico completo
./airbyte-management.sh troubleshoot

# Verificar conectividad
curl -I http://localhost:8000

# Ver eventos del cluster
docker exec airbyte-abctl-control-plane kubectl get events -n airbyte-abctl --sort-by='.lastTimestamp'

# Verificar configuración de pods
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl -o wide

# Describir pod con problemas
docker exec airbyte-abctl-control-plane kubectl describe pod <pod-name> -n airbyte-abctl
```

### Problemas Comunes y Soluciones

```bash
# 1. Airbyte no inicia
# - Verificar Docker
sudo systemctl status docker
sudo systemctl start docker

# - Verificar logs
docker logs airbyte-abctl-control-plane --tail 50

# 2. Puerto 8000 no responde
# - Verificar que el puerto está en uso
netstat -tuln | grep 8000
ss -tuln | grep 8000

# - Verificar firewall (si aplica)
sudo ufw status
sudo ufw allow 8000

# 3. Pods en estado CrashLoopBackOff
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl
docker exec airbyte-abctl-control-plane kubectl logs <pod-name> -n airbyte-abctl --previous

# 4. Problemas de permisos
sudo chown -R $USER:$USER ~/.airbyte/abctl/

# 5. Falta de espacio en disco
docker system prune -a
./airbyte-management.sh cleanup

# 6. Reinicio completo (último recurso)
./airbyte-management.sh stop
docker rm -f airbyte-abctl-control-plane
rm -rf ~/.airbyte/abctl/
./airbyte-setup.sh
```

### Optimización de Rendimiento

```bash
# 1. Aumentar recursos del cluster (editar configuración)
# Crear archivo de valores personalizado
cat > custom-values.yaml << EOF
resources:
  server:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
  worker:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
EOF

# Reinstalar con valores personalizados
abctl local install --values custom-values.yaml

# 2. Limpiar logs antiguos regularmente
./airbyte-management.sh cleanup

# 3. Configurar límites de sincronización
# (Hacer en la UI o mediante API para cada conexión)

# 4. Modo de bajos recursos
abctl local install --low-resource-mode
```

---

## 🔄 Actualizaciones

### Actualizar Airbyte

```bash
# Actualizar usando el script
./airbyte-management.sh update

# Actualizar manualmente
# 1. Backup primero
./airbyte-management.sh backup

# 2. Actualizar abctl
curl -LsfS https://get.airbyte.com | bash -

# 3. Actualizar Airbyte
abctl local install

# 4. Verificar versión
abctl version
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl
```

### Rollback a Versión Anterior

```bash
# 1. Desinstalar versión actual
abctl local uninstall

# 2. Restaurar backup
./airbyte-management.sh restore

# 3. Instalar versión específica
abctl local install --chart-version <version>
```

---

## 🔗 Integración CI/CD

### GitHub Actions

```yaml
# .github/workflows/airbyte-sync.yml
name: Airbyte Sync

on:
  schedule:
    - cron: '0 2 * * *' # Diario a las 2 AM
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Airbyte Sync
        run: |
          curl -X POST http://your-airbyte-server:8000/api/v1/connections/sync \
            -H "Content-Type: application/json" \
            -d '{"connectionId": "${{ secrets.AIRBYTE_CONNECTION_ID }}"}'
```

### GitLab CI

```yaml
# .gitlab-ci.yml
airbyte_sync:
  stage: sync
  script:
    - |
      curl -X POST http://localhost:8000/api/v1/connections/sync \
        -H "Content-Type: application/json" \
        -d "{\"connectionId\": \"$AIRBYTE_CONNECTION_ID\"}"
  only:
    - schedules
```

### Script de Deployment

```bash
#!/bin/bash
# deploy-airbyte-config.sh
# Desplegar configuraciones de Airbyte desde Git

set -e

CONFIG_REPO="https://github.com/your-org/airbyte-configs.git"
CONFIG_DIR="/tmp/airbyte-configs"

# Clonar repositorio de configuraciones
git clone "$CONFIG_REPO" "$CONFIG_DIR"

# Aplicar configuraciones
for config in "$CONFIG_DIR"/connections/*.json; do
  echo "Desplegando configuración: $(basename $config)"
  curl -X POST http://localhost:8000/api/v1/connections/create \
    -H "Content-Type: application/json" \
    -d @"$config"
done

# Limpiar
rm -rf "$CONFIG_DIR"
```

---

## 🛠️ Comandos Avanzados

### Acceso Directo a la Base de Datos

```bash
# Conectar a PostgreSQL de Airbyte
docker exec -it airbyte-abctl-control-plane kubectl exec -it -n airbyte-abctl \
  $(docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl -l app=airbyte-db -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U airbyte

# Queries útiles
# Ver todas las tablas
\dt

# Ver conexiones configuradas
SELECT * FROM connection;

# Ver histórico de sincronizaciones
SELECT * FROM job ORDER BY created_at DESC LIMIT 10;
```

### Manipulación de Volúmenes

```bash
# Listar volúmenes de Airbyte
docker volume ls | grep airbyte

# Inspeccionar un volumen
docker volume inspect <volume-name>

# Backup de un volumen específico
docker run --rm \
  -v <volume-name>:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/volume-backup.tar.gz /data

# Restaurar un volumen
docker run --rm \
  -v <volume-name>:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/volume-backup.tar.gz -C /
```

### Configuración de Red Avanzada

```bash
# Exponer Airbyte en la red local (CUIDADO: solo en redes confiables)
# Editar el ingress
docker exec airbyte-abctl-control-plane kubectl edit ingress -n airbyte-abctl

# Port forwarding alternativo
docker exec airbyte-abctl-control-plane kubectl port-forward -n airbyte-abctl \
  service/airbyte-abctl-server 8000:8000 --address 0.0.0.0

# Verificar servicios de red
docker exec airbyte-abctl-control-plane kubectl get services -n airbyte-abctl
```

### Scripts de Utilidad

```bash
# Exportar todas las configuraciones
cat > export-all-configs.sh << 'EOF'
#!/bin/bash
WORKSPACE_ID="your-workspace-id"
OUTPUT_DIR="airbyte-export-$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

# Exportar sources
curl -X POST http://localhost:8000/api/v1/sources/list \
  -H "Content-Type: application/json" \
  -d "{\"workspaceId\": \"$WORKSPACE_ID\"}" > "$OUTPUT_DIR/sources.json"

# Exportar destinations
curl -X POST http://localhost:8000/api/v1/destinations/list \
  -H "Content-Type: application/json" \
  -d "{\"workspaceId\": \"$WORKSPACE_ID\"}" > "$OUTPUT_DIR/destinations.json"

# Exportar connections
curl -X POST http://localhost:8000/api/v1/connections/list \
  -H "Content-Type: application/json" \
  -d "{\"workspaceId\": \"$WORKSPACE_ID\"}" > "$OUTPUT_DIR/connections.json"

echo "Configuraciones exportadas a $OUTPUT_DIR"
EOF

chmod +x export-all-configs.sh
```

---

## 📚 Referencias Rápidas

### Variables de Entorno Útiles

```bash
# Configurar nivel de logging
export AIRBYTE_LOG_LEVEL=DEBUG

# Deshabilitar telemetría
export AIRBYTE_TELEMETRY=false

# Configurar timeout
export AIRBYTE_SYNC_TIMEOUT=3600
```

### Puertos Utilizados

- **8000**: Interfaz web de Airbyte
- **8001**: API de Airbyte
- **7233**: Temporal (motor de workflows)

### Ubicaciones Importantes

```bash
# Configuración de Airbyte
~/.airbyte/abctl/

# Datos de Airbyte
~/.airbyte/abctl/data/

# Kubeconfig
~/.airbyte/abctl/abctl.kubeconfig

# Logs del sistema
/var/log/ (dentro del contenedor)
```

### Comandos One-Liners Útiles

```bash
# Ver todas las conexiones activas
docker exec airbyte-abctl-control-plane kubectl get all -n airbyte-abctl

# Reinicio rápido
docker restart airbyte-abctl-control-plane

# Ver uso de CPU y memoria actual
docker stats --no-stream airbyte-abctl-control-plane

# Verificar salud rápidamente
curl -s http://localhost:8000/api/v1/health | jq

# Contar número de sincronizaciones hoy
curl -s -X POST http://localhost:8000/api/v1/jobs/list | jq '[.jobs[] | select(.createdAt | startswith("2026-02-15"))] | length'
```

---

## 🆘 Soporte y Recursos

- **Documentación oficial**: `https://docs.airbyte.com/`
- **API Reference**: `https://airbyte-public-api-docs.s3.us-east-2.amazonaws.com/rapidoc-api-docs.html`
- **Slack Community**: `https://slack.airbyte.com/`
- **GitHub Issues**: `https://github.com/airbytehq/airbyte/issues`

---

## 📝 Notas Finales

Este documento cubre los comandos más comunes para gestionar Airbyte en un entorno local. Para casos de uso específicos o problemas no cubiertos aquí, consulta la documentación oficial o el script de gestión incluido.

**Script principal**: `airbyte-management.sh` - Proporciona un menú interactivo para todas estas operaciones.
