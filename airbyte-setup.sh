#!/bin/bash
# Script de configuración para Airbyte en un entorno local en Ubuntu. 
# https://docs.airbyte.com/platform/using-airbyte/getting-started/oss-quickstart

# Otorgar permisos de ejecución al script antes de ejecutarlo:
# chmod +x airbyte-setup.sh
# Luego, ejecuta el script:
# ./airbyte-setup.sh

# ----------------------------------------
# Configuración Global y Manejo de Errores
# ----------------------------------------
set -e          # Detener ejecución si cualquier comando falla
set -u          # Error si se usan variables no definidas
set -o pipefail # Detectar errores en pipes

# Variables de configuración editables
AIRBYTE_PORT_FILE="$HOME/.airbyte/abctl/airbyte-port"
AIRBYTE_PORT=8000
AIRBYTE_HOST="10.10.0.2" # IP donde se servirá Airbyte
ASSUME_YES=0

# ----------------------------------------
# Funciones auxiliares (Definidas al inicio)
# ----------------------------------------
USE_COLORS=0
USE_SPINNER=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${CI:-}" ]; then
    USE_COLORS=1
    USE_SPINNER=1
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

log_info() {
    printf '%b\n' "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    printf '%b\n' "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    printf '%b\n' "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

run_with_spinner() {
    local message="$1"
    shift

    if [ "$USE_SPINNER" -ne 1 ]; then
        "$@"
        return $?
    fi

    local spinner_chars='|/-\\'
    local spinner_pid
    local exit_code=0

    printf '%b\n' "${BLUE}[INFO]${NC} $message"

    (
        "$@"
    ) &
    spinner_pid=$!

    while kill -0 "$spinner_pid" 2>/dev/null; do
        for char in $(printf '%s' "$spinner_chars" | fold -w1); do
            if ! kill -0 "$spinner_pid" 2>/dev/null; then
                break
            fi
            printf '\r%b[INFO]%b %s %s' "$BLUE" "$NC" "$char" "$message"
            sleep 0.1
        done
    done

    wait "$spinner_pid" || exit_code=$?
    printf '\r\033[K'

    if [ "$exit_code" -eq 0 ]; then
        printf '%b\n' "${GREEN}[SUCCESS]${NC} $message"
    fi

    return "$exit_code"
}

DOCKER_CMD=(docker)
COMPOSE_CMD=()
DOCKER_CONFIG_DIR=""

is_wsl2() {
    grep -qi microsoft /proc/version 2>/dev/null || uname -r | grep -qi microsoft
}

run_docker() {
    "${DOCKER_CMD[@]}" "$@"
}

run_compose() {
    "${COMPOSE_CMD[@]}" "$@"
}

# Envoltura inteligente para ejecutar abctl con los permisos correctos de la sesión actual
run_abctl() {
    if run_docker ps >/dev/null 2>&1; then
        abctl "$@"
    elif getent group docker >/dev/null 2>&1 && check_command sg; then
        sg docker -c "export BROWSER=echo; abctl $(printf '%q ' "$@")"
    else
        sudo abctl "$@"
    fi
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
        log_info "Intentando iniciar Docker en este host..."
        sudo systemctl enable docker --now

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
    # Validar si el plugin moderno 'docker compose' responde correctamente
    if run_docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD=("${DOCKER_CMD[@]}" compose)
        return 0
    fi

    return 1
}

prepare_wsl2_docker_config() {
    if ! is_wsl2; then
        return 0
    fi

    DOCKER_CONFIG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/airbyte-docker-config.XXXXXX")
    printf '%s\n' '{}' > "$DOCKER_CONFIG_DIR/config.json"
    export DOCKER_CONFIG="$DOCKER_CONFIG_DIR"

    log_info "WSL2 detectado: usando una configuración temporal de Docker para evitar el helper de Windows."
}

cleanup_wsl2_docker_config() {
    if [ -n "$DOCKER_CONFIG_DIR" ] && [ -d "$DOCKER_CONFIG_DIR" ]; then
        rm -rf "$DOCKER_CONFIG_DIR"
    fi
}

trap cleanup_wsl2_docker_config EXIT

is_port_available() {
    local port="$1"

    if command -v ss >/dev/null 2>&1 && ss -tuln 2>/dev/null | grep -q ":${port} "; then
        return 1
    fi

    if command -v netstat >/dev/null 2>&1 && netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        return 1
    fi

    return 0
}

select_airbyte_port() {
    local candidate
    local candidates=("$AIRBYTE_PORT" 8000 18080 19080 28080 38080 48080)

    for candidate in "${candidates[@]}"; do
        if is_port_available "$candidate"; then
            AIRBYTE_PORT="$candidate"
            return 0
        fi
    done

    return 1
}

save_airbyte_port() {
    mkdir -p "$HOME/.airbyte/abctl"
    printf '%s\n' "$AIRBYTE_PORT" > "$AIRBYTE_PORT_FILE"
}

load_airbyte_port() {
    if [ -f "$AIRBYTE_PORT_FILE" ]; then
        local saved_port
        saved_port=$(tr -d '[:space:]' < "$AIRBYTE_PORT_FILE")
        if [ -n "$saved_port" ]; then
            AIRBYTE_PORT="$saved_port"
        fi
    fi
}

# ----------------------------------------
# Procesamiento de Argumentos de Entrada
# ----------------------------------------
while [ "$#" -gt 0 ]; do
    case "$1" in
        -y|--yes|--non-interactive)
            ASSUME_YES=1
            ;;
        --help|-h)
            cat <<'EOF'
Uso: ./airbyte-setup.sh [--yes]

Opciones:
  -y, --yes, --non-interactive   Ejecuta sin pedir confirmaciones y usa valores seguros por defecto.
EOF
            exit 0
            ;;
        *)
            log_error "Argumento no reconocido: $1"
            exit 1
            ;;
    esac
    shift
done

# ----------------------------------------
# Verificaciones previas
# ----------------------------------------
log_info "Iniciando setup de Airbyte..."

# Verificar que es un sistema basado en Debian/Ubuntu
if [ ! -f /etc/debian_version ]; then
    log_error "Este script está diseñado para sistemas Debian/Ubuntu."
    exit 1
fi

# Verificar que se tiene acceso a sudo
if ! sudo -n true 2>/dev/null; then
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
        log_error "Se requiere sudo sin interacción para continuar. Abre una terminal interactiva o configura sudo antes de ejecutar el instalador."
        exit 1
    fi

    log_info "Se requieren permisos de sudo. Por favor, ingresa tu contraseña:"
    sudo -v
fi

log_success "Verificaciones previas completadas."

# ----------------------------------------
# 1. Actualizar el sistema e instalar dependencias
# ----------------------------------------
run_with_spinner "Actualizando sistema e instalando dependencias" sudo apt update
run_with_spinner "Actualizando paquetes del sistema" sudo apt upgrade -y
run_with_spinner "Instalando curl y git" sudo apt install -y curl git

# Verificar si Docker ya está instalado
if check_command docker; then
    log_info "Docker ya está instalado. Versión:"
    run_docker --version
else
    log_info "Instalando Docker..."
    run_with_spinner "Instalando Docker" sudo apt install -y docker.io
    log_success "Docker instalado correctamente."
fi

if ! configure_docker_access; then
    if is_wsl2; then
        log_error "No se pudo acceder a Docker en WSL2. Verifica la integración de Docker Desktop para esta distro o que el daemon esté disponible."
    else
        log_error "No se pudo acceder a Docker. Verifica que el servicio esté activo y que tu usuario tenga permisos."
    fi
    exit 1
fi

prepare_wsl2_docker_config

# Instalar Docker Compose Plugin (v2) si no está disponible
if ! configure_compose_command; then
    log_info "Docker Compose no detectado. Intentando instalar..."
    
    # Intentar instalar el paquete nativo de Ubuntu 24.04 (docker-compose-v2), el oficial o el antiguo
    run_with_spinner "Instalando Docker Compose" bash -lc '
        sudo apt-get update && \
        (sudo apt-get install -y docker-compose-v2 || \
         sudo apt-get install -y docker-compose-plugin || \
         sudo apt-get install -y docker-compose)
    '
    
    # Volver a verificar tras el intento de instalación
    if configure_compose_command; then
        log_success "Docker Compose configurado correctamente. Versión:"
        run_compose version
    fi
else
    log_info "Docker Compose ya está instalado y configurado. Versión:"
    run_compose version
fi

# ------------------------------
# 2. Habilitar el servicio de Docker
# ------------------------------
if is_wsl2; then
    log_info "Entorno WSL2 detectado: se omite la gestión del servicio Docker local."
else
    log_info "Habilitando y arrancando servicio Docker..."
    sudo systemctl enable docker --now

    # Verificar que Docker está corriendo
    if ! sudo systemctl is-active --quiet docker; then
        log_error "Docker no se pudo iniciar correctamente."
        exit 1
    fi

    log_success "Servicio Docker está activo."
fi

# ------------------------------
# 3. Configurar permisos de Docker
# ------------------------------
log_info "Configurando permisos de Docker para el usuario actual..."

# Verificar si el usuario ya está en el grupo docker
if getent group docker >/dev/null 2>&1 && groups "$USER" | grep -q '\bdocker\b'; then
    log_info "El usuario ya pertenece al grupo docker."
elif getent group docker >/dev/null 2>&1; then
    log_info "Agregando usuario al grupo docker..."
    sudo usermod -aG docker "$USER"
    log_success "Usuario agregado al grupo docker."
else
    log_info "El grupo docker no existe en este entorno. Se omite la reasignación de grupos."
fi

# ------------------------------
# 4. Instalar Airbyte CLI (abctl)
# ------------------------------
log_info "Instalando Airbyte CLI (abctl)..."

if check_command abctl; then
    log_info "abctl ya está instalado. Versión actual:"
    run_abctl version
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
        log_info "Modo no interactivo: se conservará la versión actual de abctl."
        log_info "Saltando instalación de abctl."
    else
        read -p "¿Deseas reinstalar abctl? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            curl -LsfS https://get.airbyte.com | bash -
            log_success "abctl reinstalado correctamente."
        else
            log_info "Saltando instalación de abctl."
        fi
    fi
else
    run_with_spinner "Instalando Airbyte CLI (abctl)" bash -lc 'set -o pipefail; curl -LsfS https://get.airbyte.com | bash -'
    log_success "abctl instalado correctamente."
fi

# Validar instalación de Airbyte CLI
log_info "Validando instalación de abctl..."
run_abctl version

# ------------------------------
# 5. Instalar Airbyte Core en el entorno local
# ------------------------------
log_info "Verificando instalación existente de Airbyte..."
load_airbyte_port

# Verificar si Airbyte ya está instalado
if run_docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'airbyte-abctl'; then
    log_info "Se detectó una instalación existente de Airbyte."
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
        log_info "Modo no interactivo: se conservará la instalación actual."
        log_info "Airbyte está ejecutándose en: http://${AIRBYTE_HOST}:${AIRBYTE_PORT}"
        exit 0
    fi

    echo ""
    echo "Opciones disponibles:"
    echo "  1) Mantener instalación actual y salir"
    echo "  2) Desinstalar y reinstalar limpiamente (BORRARÁ TODOS LOS DATOS)"
    echo "  3) Intentar reparar instalación actual"
    echo ""
    read -p "Selecciona una opción [1-3]: " -n 1 -r
    echo
    
    case $REPLY in
        2)
            log_info "Desinstalando Airbyte existente..."
            run_abctl local uninstall || true
            
            log_info "Limpiando archivos de configuración y datos..."
            sudo rm -rf ~/.airbyte/abctl/data || true
            
            log_info "Esperando a que se complete la desinstalación..."
            sleep 5
            
            log_success "Desinstalación completada. Procediendo con instalación limpia..."
            ;;
        3)
            log_info "Intentando reparar permisos..."
            sudo chown -R "$USER:$USER" ~/.airbyte/abctl/data 2>/dev/null || true
            log_info "Reparación completada. Intentando continuar con instalación..."
            ;;
        1|*)
            log_info "Manteniendo instalación actual."
            echo ""
            log_info "Airbyte está ejecutándose en: http://${AIRBYTE_HOST}:${AIRBYTE_PORT}"
            echo -n "Credenciales: " && run_abctl local credentials
            exit 0
            ;;
    esac
fi

log_info "Instalando Airbyte Core en el entorno local..."
log_info "Este proceso puede tardar varios minutos..."
if ! select_airbyte_port; then
    log_error "No se encontró un puerto libre para Airbyte. Libera $AIRBYTE_PORT o un puerto alterno y vuelve a intentarlo."
    exit 1
fi

log_info "Puerto de acceso seleccionado: $AIRBYTE_PORT"
save_airbyte_port

# Función corregida para instalar Airbyte con deshabilitación de cookies seguras en ambas rutas
install_airbyte() {
    export BROWSER=echo
    
    if run_docker ps &> /dev/null; then
        run_with_spinner "Instalando Airbyte Core" bash -lc "abctl local install --no-browser --port '$AIRBYTE_PORT' --host '$AIRBYTE_HOST' --insecure-cookies 2>/dev/null || abctl local install --port '$AIRBYTE_PORT' --host '$AIRBYTE_HOST' --insecure-cookies"
    elif getent group docker >/dev/null 2>&1 && sudo run_docker ps &> /dev/null; then
        log_info "Aplicando permisos del grupo docker de forma temporal..."
        run_with_spinner "Instalando Airbyte Core (sg docker)" sg docker -c "export BROWSER=echo; abctl local install --no-browser --port '$AIRBYTE_PORT' --host '$AIRBYTE_HOST' --insecure-cookies 2>/dev/null || abctl local install --port '$AIRBYTE_PORT' --host '$AIRBYTE_HOST' --insecure-cookies"
    else
        log_error "No hay acceso operativo a Docker para ejecutar abctl."
        return 1
    fi
}

install_airbyte
log_success "Airbyte Core instalado correctamente."

# -------------------------------
# 6. Mostrar credenciales de Airbyte
# -------------------------------
log_info "Obteniendo credenciales de Airbyte..."
run_abctl local credentials

# -------------------------------
# Finalización
# -------------------------------
echo ""
echo "========================================="
log_success "¡Airbyte se ha instalado correctamente!"
echo "========================================="
echo ""
log_info "Accede a Airbyte en: http://${AIRBYTE_HOST}:${AIRBYTE_PORT}"
echo ""
log_info "IMPORTANTE: En el primer acceso deberás:"
log_info "  1. Ingresar tu correo electrónico"
log_info "  2. Usar la contraseña mostrada arriba para iniciar sesión"
echo ""
log_info "NOTA: Si experimentas problemas con permisos de Docker en esta sesión,"
log_info "      cierra y abre una nueva terminal para que los cambios de grupo se apliquen completamente."
echo ""
log_info "Comandos útiles:"
echo "  - Ver estado: abctl local status"
echo "  - Detener/Remover: abctl local uninstall"
echo "  - Ver credenciales: abctl local credentials"
echo ""


# Comandos de desinstalación manual (si es necesario):
# ----------------------------------
# 1. Desinstalar completamente:
#   abctl local uninstall

# 2. Limpiar archivos de configuración y datos (ADVERTENCIA: BORRARÁ TODOS LOS DATOS):
#   sudo rm -rf ~/.airbyte/abctl/data

# 3. Verificar que no queden contenedores o volúmenes residuales:
#   docker ps -a | grep airbyte
#   docker volume ls | grep airbyte

# 4. Eliminar contenedores o volúmenes residuales (si es necesario):
#   docker rm -f <container_id>
#   docker volume rm <volume_name>

# 5. Reinstalar con el script después de limpiar:
#   ./airbyte-setup.sh
