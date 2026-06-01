#!/bin/bash
# ============================================================================
# Airbyte Local Management Script
# Gestión completa de Airbyte para Ingeniería de Datos
# ============================================================================

set -e

# Configuración de detección de Docker/Compose (multiplataforma)
DOCKER_CMD=(docker)
COMPOSE_CMD=()
AIRBYTE_PORT_FILE="$HOME/.airbyte/abctl/airbyte-port"
AIRBYTE_PORT=8000

USE_COLORS=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${CI:-}" ]; then
    USE_COLORS=1
fi

if [ "$USE_COLORS" -eq 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

is_wsl2() {
    grep -qi microsoft /proc/version 2>/dev/null || uname -r | grep -qi microsoft
}

run_docker() {
    "${DOCKER_CMD[@]}" "$@"
}

check_command() {
    command -v "$1" &> /dev/null
}

configure_docker_access() {
    if run_docker ps >/dev/null 2>&1; then
        DOCKER_CMD=(docker)
        return 0
    fi

    if check_command sudo && sudo docker ps >/dev/null 2>&1; then
        DOCKER_CMD=(sudo docker)
        return 0
    fi

    if ! is_wsl2 && check_command sudo; then
        echo "[INFO] Intentando activar servicio Docker..."
        sudo systemctl enable docker --now || true
        if run_docker ps >/dev/null 2>&1; then
            DOCKER_CMD=(docker)
            return 0
        fi
        if sudo docker ps >/dev/null 2>&1; then
            DOCKER_CMD=(sudo docker)
            return 0
        fi
    fi

    return 1
}

configure_compose_command() {
    if run_docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD=("${DOCKER_CMD[@]}" compose)
        return 0
    fi

    if check_command docker-compose; then
        if [ "${DOCKER_CMD[0]}" = "sudo" ]; then
            COMPOSE_CMD=(sudo docker-compose)
        else
            COMPOSE_CMD=(docker-compose)
        fi
        return 0
    fi

    return 1
}

get_airbyte_port() {
    local detected_port

    if [ -f "$AIRBYTE_PORT_FILE" ]; then
        detected_port=$(tr -d '[:space:]' < "$AIRBYTE_PORT_FILE")
        if [ -n "$detected_port" ]; then
            AIRBYTE_PORT="$detected_port"
            return 0
        fi
    fi

    if run_docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'airbyte-abctl'; then
        detected_port=$(run_docker port airbyte-abctl-server 8000/tcp 2>/dev/null | head -n1 | awk -F: '{print $NF}')
        if [ -n "$detected_port" ]; then
            AIRBYTE_PORT="$detected_port"
            return 0
        fi
    fi

    AIRBYTE_PORT=8000
    return 1
}

airbyte_url() {
    echo "http://localhost:${AIRBYTE_PORT}"
}

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
print_info() {
    printf '%b\n' "${BLUE}[INFO]${NC} $1"
}

print_success() {
    printf '%b\n' "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    printf '%b\n' "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    printf '%b\n' "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "============================================"
    echo "$1"
    echo "============================================"
    echo ""
}

# ============================================================================
# GESTIÓN DE SERVICIOS
# ============================================================================

start_airbyte() {
    print_header "Iniciando Airbyte"
    
    # Verificar si ya está corriendo
    if run_docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'airbyte-abctl'; then
        print_warning "Airbyte ya está en ejecución"
        get_airbyte_port >/dev/null 2>&1 || true
        print_info "URL: $(airbyte_url)"
        return 0
    fi
    
    print_info "Iniciando servicios de Airbyte..."
    
    # Verificar que Docker esté corriendo (solo en Linux nativo)
    if ! is_wsl2; then
        if ! sudo systemctl is-active --quiet docker; then
            print_info "Iniciando Docker..."
            sudo systemctl start docker
        fi
    else
        print_info "WSL2 detectado: asumiendo que Docker está gestionado por Docker Desktop o por la distro."
    fi
    
    # Iniciar el cluster de Kubernetes (kind)
    if run_docker ps -a --format '{{.Names}}' | grep -q 'airbyte-abctl-control-plane'; then
        print_info "Iniciando cluster existente..."
        run_docker start airbyte-abctl-control-plane
        sleep 5
    else
        print_error "No se encontró instalación de Airbyte. Ejecuta primero ./airbyte-setup.sh"
        return 1
    fi
    
    print_success "Airbyte iniciado correctamente"
    get_airbyte_port >/dev/null 2>&1 || true
    print_info "Accede en: $(airbyte_url)"
}

stop_airbyte() {
    print_header "Deteniendo Airbyte"
    
    if ! run_docker ps --format '{{.Names}}' | grep -q 'airbyte-abctl'; then
        print_warning "Airbyte no está en ejecución"
        return 0
    fi
    
    print_info "Deteniendo servicios de Airbyte..."
    
    # Detener el cluster
    if run_docker ps --format '{{.Names}}' | grep -q 'airbyte-abctl-control-plane'; then
        run_docker stop airbyte-abctl-control-plane
    fi
    
    print_success "Airbyte detenido correctamente"
}

restart_airbyte() {
    print_header "Reiniciando Airbyte"
    stop_airbyte
    sleep 3
    start_airbyte
}

status_airbyte() {
    print_header "Estado de Airbyte"
    
    # Verificar Docker
    if run_docker ps >/dev/null 2>&1; then
        print_success "Docker: Accesible"
    else
        print_error "Docker: No accesible desde esta sesión"
    fi
    
    # Verificar contenedor principal
    if run_docker ps --format '{{.Names}}' | grep -q 'airbyte-abctl-control-plane'; then
        print_success "Airbyte Cluster: En ejecución"
        
        # Mostrar recursos
        echo ""
        print_info "Contenedores de Airbyte:"
        run_docker ps --filter "name=airbyte" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        # Estado del cluster con abctl
        if command -v abctl &> /dev/null; then
            echo ""
            print_info "Estado detallado del cluster:"
            abctl local status 2>/dev/null || true
        fi
    else
        print_warning "Airbyte Cluster: Detenido"
    fi
    
    # Uso de recursos
    echo ""
    print_info "Uso de recursos:"
    run_docker stats --no-stream --filter "name=airbyte" --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || print_warning "No hay contenedores de Airbyte corriendo"
}

# ============================================================================
# CREDENCIALES Y ACCESO
# ============================================================================

get_credentials() {
    print_header "Credenciales de Airbyte"
    
    if command -v abctl &> /dev/null; then
        abctl local credentials
    else
        print_error "abctl no está instalado"
        return 1
    fi
    
    echo ""
    get_airbyte_port >/dev/null 2>&1 || true
    print_info "URL de acceso: $(airbyte_url)"
}

# ============================================================================
# GESTIÓN DE DATOS Y BACKUPS
# ============================================================================

backup_airbyte() {
    print_header "Backup de Airbyte"
    
    BACKUP_DIR="$HOME/airbyte-backups"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/airbyte_backup_$TIMESTAMP"
    
    mkdir -p "$BACKUP_DIR"
    
    print_info "Creando backup en: $BACKUP_PATH"
    
    # Backup de configuración y datos
    if [ -d "$HOME/.airbyte/abctl" ]; then
        tar -czf "$BACKUP_PATH.tar.gz" -C "$HOME/.airbyte" abctl/
        print_success "Backup completado: $BACKUP_PATH.tar.gz"
        
        # Mostrar tamaño
        SIZE=$(du -h "$BACKUP_PATH.tar.gz" | cut -f1)
        print_info "Tamaño del backup: $SIZE"
    else
        print_error "No se encontró la instalación de Airbyte"
        return 1
    fi
}

restore_airbyte() {
    print_header "Restaurar Airbyte desde Backup"
    
    BACKUP_DIR="$HOME/airbyte-backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "No se encontró directorio de backups: $BACKUP_DIR"
        return 1
    fi
    
    # Listar backups disponibles
    print_info "Backups disponibles:"
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || {
        print_error "No hay backups disponibles"
        return 1
    }
    
    echo ""
    read -p "Ingresa el nombre del archivo de backup a restaurar: " BACKUP_FILE
    
    if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        print_error "Archivo no encontrado: $BACKUP_DIR/$BACKUP_FILE"
        return 1
    fi
    
    print_warning "ADVERTENCIA: Esto sobrescribirá la configuración actual"
    read -p "¿Continuar? (s/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_info "Restauración cancelada"
        return 0
    fi
    
    # Detener Airbyte
    stop_airbyte
    
    # Restaurar
    print_info "Restaurando backup..."
    tar -xzf "$BACKUP_DIR/$BACKUP_FILE" -C "$HOME/.airbyte/"
    
    print_success "Backup restaurado correctamente"
    print_info "Inicia Airbyte con: $0 start"
}

# ============================================================================
# ACTUALIZACIONES
# ============================================================================

update_airbyte() {
    print_header "Actualizar Airbyte"
    
    print_info "Versión actual de abctl:"
    abctl version
    
    echo ""
    print_warning "Se actualizará abctl y luego Airbyte"
    read -p "¿Continuar? (s/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_info "Actualización cancelada"
        return 0
    fi
    
    # Crear backup antes de actualizar
    print_info "Creando backup de seguridad..."
    backup_airbyte
    
    # Actualizar abctl
    print_info "Actualizando abctl..."
    curl -LsfS https://get.airbyte.com | bash -
    
    print_info "Nueva versión de abctl:"
    abctl version
    
    # Actualizar Airbyte
    print_info "Actualizando Airbyte..."
    abctl local install --upgrade 2>/dev/null || {
        print_warning "Flag --upgrade no disponible. Reinstalando..."
        abctl local install
    }
    
    print_success "Actualización completada"
}

uninstall_airbyte() {
    print_header "Desinstalación completa de Airbyte"

    echo "Esta acción eliminará Airbyte, su estado local y el puerto persistido."
    echo "No borrará Docker ni tus backups personales."
    echo ""
    read -p "¿Continuar? (s/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_info "Desinstalación cancelada"
        return 0
    fi

    print_info "Deshabilitando auto-inicio si está configurado..."
    disable_autostart >/dev/null 2>&1 || true

    if command -v abctl &> /dev/null; then
        print_info "Ejecutando desinstalación asistida con abctl..."
        abctl local uninstall || print_warning "abctl devolvió un error durante la desinstalación; continuaré con la limpieza local."
    else
        print_warning "abctl no está instalado; se omitirá la desinstalación asistida."
    fi

    print_info "Eliminando contenedores y volúmenes residuales de Airbyte..."
    residual_containers=$(run_docker ps -aq --filter "name=airbyte" 2>/dev/null || true)
    if [ -n "$residual_containers" ]; then
        run_docker rm -f $residual_containers >/dev/null 2>&1 || true
    fi

    residual_volumes=$(run_docker volume ls -q 2>/dev/null | grep '^airbyte' || true)
    if [ -n "$residual_volumes" ]; then
        run_docker volume rm $residual_volumes >/dev/null 2>&1 || true
    fi

    print_info "Eliminando estado local persistido..."
    rm -rf "$HOME/.airbyte/abctl" 2>/dev/null || sudo rm -rf "$HOME/.airbyte/abctl" 2>/dev/null || true

    print_success "Desinstalación completa finalizada"
}

# ============================================================================
# LOGS Y DEBUGGING
# ============================================================================

view_logs() {
    print_header "Logs de Airbyte"
    
    if ! run_docker ps --format '{{.Names}}' | grep -q 'airbyte-abctl'; then
        print_error "Airbyte no está en ejecución"
        return 1
    fi
    
    echo "Selecciona el componente:"
    echo "  1) Logs del cluster (kind)"
    echo "  2) Logs de todos los pods"
    echo "  3) Logs de un pod específico"
    echo "  4) Logs en tiempo real (seguir)"
    echo ""
    read -p "Opción [1-4]: " -n 1 -r
    echo
    
    case $REPLY in
        1)
            run_docker logs airbyte-abctl-control-plane --tail 100
            ;;
        2)
            run_docker exec airbyte-abctl-control-plane kubectl logs -n airbyte-abctl --all-containers=true --tail=50
            ;;
        3)
            print_info "Pods disponibles:"
            run_docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl
            echo ""
            read -p "Nombre del pod: " POD_NAME
            run_docker exec airbyte-abctl-control-plane kubectl logs -n airbyte-abctl "$POD_NAME" --tail=100
            ;;
        4)
            print_info "Siguiendo logs del cluster (Ctrl+C para salir)..."
            run_docker logs -f airbyte-abctl-control-plane
            ;;
        *)
            print_error "Opción inválida"
            ;;
    esac
}

troubleshoot() {
    print_header "Diagnóstico de Problemas"
    
    # Docker
    print_info "1. Verificando Docker..."
    if run_docker ps >/dev/null 2>&1; then
        print_success "Docker está accesible"
        run_docker version --format 'Versión: {{.Server.Version}}' 2>/dev/null || true
    else
        print_error "Docker no está accesible desde esta sesión"
        if ! is_wsl2; then
            print_info "Intenta: sudo systemctl start docker"
        else
            print_info "En WSL2 asegúrate de que Docker Desktop tenga la integración habilitada o que el daemon esté disponible en la distro."
        fi
    fi
    
    echo ""
    
    # Cluster
    print_info "2. Verificando cluster de Airbyte..."
    if run_docker ps --format '{{.Names}}' | grep -q 'airbyte-abctl-control-plane'; then
        print_success "Cluster está corriendo"
        
        # Verificar pods
        print_info "Estado de los pods:"
        run_docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl 2>/dev/null || print_error "No se pudo obtener estado de pods"
    else
        print_error "Cluster no está corriendo"
        print_info "Intenta: $0 start"
    fi
    
    echo ""
    
    # Recursos
    print_info "3. Verificando recursos del sistema..."
    echo "Memoria:"
    free -h | grep Mem
    echo ""
    echo "Disco:"
    df -h / | grep -v Filesystem
    
    echo ""
    
    # Puertos
    get_airbyte_port >/dev/null 2>&1 || true
    print_info "4. Verificando puerto ${AIRBYTE_PORT}..."
    if netstat -tuln 2>/dev/null | grep -q ":${AIRBYTE_PORT}" || ss -tuln 2>/dev/null | grep -q ":${AIRBYTE_PORT}"; then
        print_success "Puerto ${AIRBYTE_PORT} está en uso (Airbyte escuchando)"
    else
        print_warning "Puerto ${AIRBYTE_PORT} no está en uso"
    fi
    
    echo ""
    
    # Archivos de configuración
    print_info "5. Verificando archivos de configuración..."
    if [ -d "$HOME/.airbyte/abctl" ]; then
        print_success "Directorio de configuración existe"
        SIZE=$(du -sh "$HOME/.airbyte/abctl" | cut -f1)
        print_info "Tamaño total: $SIZE"
    else
        print_error "No se encontró directorio de configuración"
    fi
}

# ============================================================================
# API Y AUTOMATIZACIÓN
# ============================================================================

test_api() {
    print_header "Prueba de API de Airbyte"
    
    print_info "Verificando acceso a la API..."
    
    # Obtener credenciales
    CREDS=$(abctl local credentials 2>/dev/null)
    CLIENT_ID=$(echo "$CREDS" | grep "Client-Id:" | awk '{print $2}')
    CLIENT_SECRET=$(echo "$CREDS" | grep "Client-Secret:" | awk '{print $2}')
    
    if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
        print_error "No se pudieron obtener las credenciales"
        return 1
    fi
    
    print_success "Credenciales obtenidas"
    
    # Test de conexión
    print_info "Probando endpoint /health..."
    get_airbyte_port >/dev/null 2>&1 || true
    RESPONSE=$(curl -s "$(airbyte_url)/api/v1/health")
    
    if echo "$RESPONSE" | grep -q "available"; then
        print_success "API está respondiendo correctamente"
        echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    else
        print_error "La API no está respondiendo correctamente"
        echo "Respuesta: $RESPONSE"
    fi
}

generate_api_script() {
    print_header "Generar Script de Ejemplo para API"
    
    SCRIPT_FILE="airbyte-api-example.py"
    
    cat > "$SCRIPT_FILE" << 'EOF'
#!/usr/bin/env python3
"""
Script de ejemplo para interactuar con la API de Airbyte
Requiere: pip install requests
"""

import requests
import json
from typing import Dict, Any

class AirbyteAPI:
    def __init__(self, base_url: str = "http://localhost:8000", client_id: str = "", client_secret: str = ""):
        self.base_url = base_url
        self.client_id = client_id
        self.client_secret = client_secret
        self.session = requests.Session()
        
    def get_health(self) -> Dict[str, Any]:
        """Verificar el estado de salud de Airbyte"""
        response = self.session.get(f"{self.base_url}/api/v1/health")
        return response.json()
    
    def list_workspaces(self) -> Dict[str, Any]:
        """Listar todos los workspaces"""
        response = self.session.post(
            f"{self.base_url}/api/v1/workspaces/list",
            headers={"Content-Type": "application/json"},
            json={}
        )
        return response.json()
    
    def list_connections(self, workspace_id: str) -> Dict[str, Any]:
        """Listar todas las conexiones de un workspace"""
        response = self.session.post(
            f"{self.base_url}/api/v1/connections/list",
            headers={"Content-Type": "application/json"},
            json={"workspaceId": workspace_id}
        )
        return response.json()
    
    def trigger_sync(self, connection_id: str) -> Dict[str, Any]:
        """Disparar una sincronización manual"""
        response = self.session.post(
            f"{self.base_url}/api/v1/connections/sync",
            headers={"Content-Type": "application/json"},
            json={"connectionId": connection_id}
        )
        return response.json()
    
    def get_connection_status(self, connection_id: str) -> Dict[str, Any]:
        """Obtener el estado de una conexión"""
        response = self.session.post(
            f"{self.base_url}/api/v1/connections/get",
            headers={"Content-Type": "application/json"},
            json={"connectionId": connection_id}
        )
        return response.json()

# Ejemplo de uso
if __name__ == "__main__":
    # Configurar credenciales (obtenerlas con: abctl local credentials)
    client_id = "TU_CLIENT_ID"
    client_secret = "TU_CLIENT_SECRET"
    
    # Crear cliente API
    api = AirbyteAPI(client_id=client_id, client_secret=client_secret)
    
    try:
        # Verificar salud
        health = api.get_health()
        print("Estado de Airbyte:", json.dumps(health, indent=2))
        
        # Listar workspaces
        workspaces = api.list_workspaces()
        print("\nWorkspaces:", json.dumps(workspaces, indent=2))
        
        # Si tienes un workspace_id, puedes listar conexiones
        # workspace_id = "tu-workspace-id"
        # connections = api.list_connections(workspace_id)
        # print("\nConexiones:", json.dumps(connections, indent=2))
        
    except Exception as e:
        print(f"Error: {e}")
EOF

    chmod +x "$SCRIPT_FILE"
    print_success "Script creado: $SCRIPT_FILE"
    print_info "Edita el archivo y agrega tus credenciales antes de ejecutarlo"
    print_info "Instala dependencias con: pip install requests"
}

# ============================================================================
# AUTO-INICIO EN EL SISTEMA
# ============================================================================

enable_autostart() {
    print_header "Habilitar Auto-Inicio de Airbyte"
    
    SERVICE_FILE="/etc/systemd/system/airbyte-local.service"
    
    if is_wsl2; then
        print_error "Auto-inicio no soportado en WSL2 vía systemd. Configura el arranque en Docker Desktop o en el host nativo."
        return 1
    fi

    print_info "Creando servicio systemd..."

    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Airbyte Local Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start airbyte-abctl-control-plane
ExecStop=/usr/bin/docker stop airbyte-abctl-control-plane
User=$USER

[Install]
WantedBy=multi-user.target
EOF

    print_info "Habilitando servicio..."
    sudo systemctl daemon-reload
    sudo systemctl enable airbyte-local.service
    
    print_success "Auto-inicio habilitado"
    print_info "Airbyte se iniciará automáticamente después de cada reinicio"
    print_info "Comandos útiles:"
    echo "  - Verificar estado: sudo systemctl status airbyte-local"
    echo "  - Deshabilitar: sudo systemctl disable airbyte-local"
}

disable_autostart() {
    print_header "Deshabilitar Auto-Inicio de Airbyte"
    
    SERVICE_FILE="/etc/systemd/system/airbyte-local.service"
    
    if [ ! -f "$SERVICE_FILE" ]; then
        print_warning "El servicio de auto-inicio no está configurado"
        return 0
    fi
    
    if is_wsl2; then
        print_warning "Auto-inicio via systemd no configurado en WSL2. No hay nada que deshabilitar."
        return 0
    fi

    print_info "Deshabilitando servicio..."
    sudo systemctl disable airbyte-local.service
    sudo systemctl stop airbyte-local.service 2>/dev/null || true
    
    print_info "Eliminando archivo de servicio..."
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    
    print_success "Auto-inicio deshabilitado"
}

# ============================================================================
# LIMPIEZA Y MANTENIMIENTO
# ============================================================================

cleanup_airbyte() {
    print_header "Limpieza de Airbyte"
    
    echo "Opciones de limpieza:"
    echo "  1) Limpiar logs antiguos"
    echo "  2) Limpiar backups antiguos (más de 30 días)"
    echo "  3) Limpiar imágenes Docker no utilizadas"
    echo "  4) Limpieza completa (todo lo anterior)"
    echo ""
    read -p "Selecciona una opción [1-4]: " -n 1 -r
    echo
    
    case $REPLY in
        1)
            print_info "Limpiando logs..."
            run_docker exec airbyte-abctl-control-plane sh -c "find /var/log -name '*.log' -mtime +7 -delete" 2>/dev/null || print_warning "No se pudieron limpiar logs"
            print_success "Logs limpiados"
            ;;
        2)
            print_info "Limpiando backups antiguos..."
            find "$HOME/airbyte-backups" -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || print_warning "No hay backups antiguos"
            print_success "Backups antiguos eliminados"
            ;;
        3)
            print_info "Limpiando imágenes Docker no utilizadas..."
            run_docker image prune -a -f --filter "until=720h"
            print_success "Imágenes limpiadas"
            ;;
        4)
            print_info "Realizando limpieza completa..."
            run_docker exec airbyte-abctl-control-plane sh -c "find /var/log -name '*.log' -mtime +7 -delete" 2>/dev/null || true
            find "$HOME/airbyte-backups" -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
            run_docker image prune -a -f --filter "until=720h"
            print_success "Limpieza completa finalizada"
            ;;
        *)
            print_error "Opción inválida"
            ;;
    esac
}

# ============================================================================
# MENÚ PRINCIPAL
# ============================================================================

show_menu() {
    print_header "Herramienta de Gestión de Airbyte - Para Ingeniería de Datos"
    
    echo "GESTIÓN DE SERVICIOS:"
    echo "  1)  Iniciar Airbyte"
    echo "  2)  Detener Airbyte"
    echo "  3)  Reiniciar Airbyte"
    echo "  4)  Ver estado de Airbyte"
    echo "  5)  Ver credenciales"
    echo ""
    echo "BACKUPS Y RESTAURACIÓN:"
    echo "  6)  Crear backup"
    echo "  7)  Restaurar desde backup"
    echo ""
    echo "ACTUALIZACIONES:"
    echo "  8)  Actualizar Airbyte"
    echo ""
    echo "LOGS Y DEBUGGING:"
    echo "  9)  Ver logs"
    echo "  10) Diagnóstico de problemas"
    echo ""
    echo "API Y AUTOMATIZACIÓN:"
    echo "  11) Probar API"
    echo "  12) Generar script de ejemplo para API"
    echo ""
    echo "AUTO-INICIO:"
    echo "  13) Habilitar auto-inicio en el sistema"
    echo "  14) Deshabilitar auto-inicio"
    echo ""
    echo "DESINSTALACIÓN:"
    echo "  15) Desinstalar Airbyte completamente"
    echo ""
    echo "MANTENIMIENTO:"
    echo "  16) Limpieza y mantenimiento"
    echo ""
    echo "  0)  Salir"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Resolver acceso a Docker/Compose antes de ejecutar acciones
    configure_docker_access || print_warning "No se pudo acceder a Docker desde esta sesión; algunas acciones fallarán."
    configure_compose_command >/dev/null 2>&1 || true

    if [ $# -eq 0 ]; then
        # Modo interactivo
        while true; do
            show_menu
            read -p "Selecciona una opción: " choice
            echo ""
            
            case $choice in
                1) start_airbyte ;;
                2) stop_airbyte ;;
                3) restart_airbyte ;;
                4) status_airbyte ;;
                5) get_credentials ;;
                6) backup_airbyte ;;
                7) restore_airbyte ;;
                8) update_airbyte ;;
                9) view_logs ;;
                10) troubleshoot ;;
                11) test_api ;;
                12) generate_api_script ;;
                13) enable_autostart ;;
                14) disable_autostart ;;
                15) uninstall_airbyte ;;
                16) cleanup_airbyte ;;
                0) print_info "¡Hasta luego!"; exit 0 ;;
                *) print_error "Opción inválida" ;;
            esac
            
            echo ""
            read -p "Presiona Enter para continuar..."
        done
    else
        # Modo comando directo
        case $1 in
            start) start_airbyte ;;
            stop) stop_airbyte ;;
            restart) restart_airbyte ;;
            status) status_airbyte ;;
            credentials) get_credentials ;;
            backup) backup_airbyte ;;
            restore) restore_airbyte ;;
            update) update_airbyte ;;
            logs) view_logs ;;
            troubleshoot) troubleshoot ;;
            test-api) test_api ;;
            generate-api-script) generate_api_script ;;
            enable-autostart) enable_autostart ;;
            disable-autostart) disable_autostart ;;
            uninstall) uninstall_airbyte ;;
            cleanup) cleanup_airbyte ;;
            *)
                echo "Uso: $0 {start|stop|restart|status|credentials|backup|restore|update|logs|troubleshoot|test-api|generate-api-script|enable-autostart|disable-autostart|uninstall|cleanup}"
                echo "O ejecuta sin argumentos para el menú interactivo"
                exit 1
                ;;
        esac
    fi
}

# Ejecutar
main "$@"
