# Airbyte Local Toolkit

**airbyte-local-toolkit** es una forma guiada de levantar y operar Airbyte en local con una experiencia pensada para WSL2 y Ubuntu/Debian nativos. El objetivo es simple: instalar rápido, verificar que todo quedó bien y luego administrar Airbyte sin tener que recordar comandos dispersos.

## 🚀 Get Started

Si quieres llegar a Airbyte funcionando lo antes posible, sigue este flujo:

> Recomendación práctica: en Ubuntu/Debian nativo o en una VM Linux (AWS, GCP, DigitalOcean, etc.) el flujo es más directo. En WSL2 también funciona, pero debe ejecutarse desde WSL2 con Docker integrado o con Docker Desktop habilitado para esa distro.

### 1. Prepara el entorno

- Usa WSL2 con Ubuntu 22.04+ en Windows, o Ubuntu/Debian nativo compatible
- Verifica que tengas al menos 10 GB libres, `sudo` y red estable
- Si estás en WSL2, el script usa Docker desde la propia distro WSL2; Docker Desktop solo sirve como integración/visor si tienes la integración habilitada

### 2. Instala

```bash
chmod +x airbyte-setup.sh scripts/airbyte-management.sh
./airbyte-setup.sh
```

### 3. Entra a Airbyte

```bash
./scripts/airbyte-management.sh credentials
```

- Abre la URL que te indique el instalador o el script de gestión; si `8000` estaba ocupado, se habrá elegido otro puerto libre automáticamente
- Usa el correo que quieras registrar en el primer acceso
- La contraseña es la que te muestra el comando de credenciales

### 4. Operación diaria

```bash
./scripts/airbyte-management.sh status
./scripts/airbyte-management.sh start
./scripts/airbyte-management.sh stop
./scripts/airbyte-management.sh backup
./scripts/airbyte-management.sh logs
```

## Qué incluye

- Instalación automatizada de Docker, Docker Compose y Airbyte CLI
- Gestión diaria con un script unificado para start, stop, status y restart
- Backups, restauración y actualización segura
- Diagnóstico y troubleshooting orientados a WSL2 y Linux nativo
- Ejemplos para automatización con API y Python

## Cómo leer esta guía

1. Primero revisa los pre-requisitos si aún no confirmaste tu entorno.
2. Luego usa el flujo de inicio rápido para instalar y validar.
3. Después entra en la documentación detallada si necesitas ajustar, depurar o automatizar.

> El instalador guarda el puerto elegido en `~/.airbyte/abctl/airbyte-port` para que el script de gestión pueda reutilizarlo.

---

## ⚠️ Pre-requisitos del Sistema

Antes de ejecutar los scripts de instalación, asegúrate de cumplir con los siguientes requisitos según tu sistema operativo.

### 🖥️ Requisitos Mínimos de Hardware

| Recurso | Mínimo | Recomendado |
| ------- | ------ | ----------- |
| **RAM** | 4 GB | 8 GB o más |
| **CPU** | 2 cores | 4 cores o más |
| **Disco** | 10 GB libres | 30 GB o más |

### 🪟 Para Windows 10/11 con WSL2

Si estás usando **Windows con WSL2**, sigue estos pasos:

#### 1. Habilitar WSL2

```powershell
# Abrir PowerShell como Administrador y ejecutar:
wsl --install

# O si WSL ya está instalado, actualizar a WSL2:
wsl --set-default-version 2
```

#### 2. Instalar Ubuntu en WSL2

```powershell
# Listar distribuciones disponibles
wsl --list --online

# Instalar Ubuntu 22.04 (recomendado)
wsl --install -d Ubuntu-22.04

# O instalar Ubuntu 24.04
wsl --install -d Ubuntu-24.04
```

#### 3. Verificar Instalación de WSL2

```powershell
# Verificar que está usando WSL2
wsl -l -v

# Debería mostrar VERSION 2 para tu distribución
# NAME            STATE           VERSION
# Ubuntu-22.04    Running         2
```

#### 4. Configurar WSL2 (Opcional pero Recomendado)

Crear el archivo `.wslconfig` en `C:\Users\TuUsuario\.wslconfig`:

```ini
[wsl2]
# Limitar memoria RAM (ajustar según tu sistema)
memory=6GB

# Limitar procesadores
processors=4

# Habilitar swap
swap=2GB

# Deshabilitar localhost forwarding si hay problemas
localhostForwarding=true
```

Reiniciar WSL después de crear el archivo:

```powershell
wsl --shutdown
wsl
```

#### 5. Actualizar paquetes en Ubuntu WSL2

```bash
# Dentro de WSL2 Ubuntu
sudo apt update && sudo apt upgrade -y
```

### 🐧 Para Ubuntu/Debian Nativo

Si estás usando **Ubuntu o Debian nativamente** (no WSL):

#### 1. Verificar Versión del Sistema

```bash
# Ubuntu
lsb_release -a

# Debian
cat /etc/debian_version

# Versiones soportadas:
# Ubuntu: 20.04, 22.04, 24.04
# Debian: 11 (Bullseye), 12 (Bookworm)
```

#### 2. Actualizar Sistema

```bash
sudo apt update && sudo apt upgrade -y
```

#### 3. Verificar permisos sudo

```bash
# Tu usuario debe tener permisos sudo
sudo -v

# Si no tienes permisos sudo, agrégalos:
su -
usermod -aG sudo tu_usuario
exit
```

### 📦 Dependencias que el Script Instalará Automáticamente

El script `airbyte-setup.sh` instalará automáticamente las siguientes herramientas si no están presentes:

#### Herramientas Principales

- **curl** - Para descargar archivos
- **git** - Control de versiones
- **Docker** (docker.io) - Motor de contenedores
- **Docker Compose** - Orquestación de contenedores
- **Airbyte CLI (abctl)** - Herramienta de gestión de Airbyte

#### Herramientas Opcionales (Recomendadas)

Para usar todas las funcionalidades del toolkit, considera instalar:

```bash
# jq - Para procesar JSON desde línea de comandos
sudo apt install -y jq

# net-tools - Para diagnóstico de red (netstat)
sudo apt install -y net-tools

# python3 y pip - Para scripts de automatización de API
sudo apt install -y python3 python3-pip

# Módulo requests de Python (para scripts de API)
pip3 install requests
```

### ✅ Verificaciones Previas

Antes de ejecutar el script de instalación, verifica lo siguiente:

#### 1. Espacio en Disco

```bash
# Verificar espacio disponible
df -h ~

# Deberías tener al menos 10 GB libres
```

#### 2. Conexión a Internet

```bash
# Verificar conectividad
ping -c 3 google.com

# Verificar acceso a repositorios de Docker
curl -I https://get.airbyte.com
```

#### 3. Permisos de Usuario

```bash
# Verificar que tienes permisos sudo
sudo whoami
# Debería retornar: root
```

#### 4. Puertos Disponibles

```bash
# Verificar que el puerto 8000 está libre
ss -tuln | grep 8000
# o
netstat -tuln | grep 8000

# Si el comando no retorna nada, el puerto está libre
# Si retorna algo, otro servicio está usando el puerto 8000
```

### 🔍 Sistemas No Soportados

Los scripts **NO son compatibles** con:

- ❌ Windows nativo (sin WSL)
- ❌ macOS (requiere ajustes en los scripts)
- ❌ Distribuciones Linux no basadas en Debian (Arch, Fedora, CentOS, etc.)
- ❌ WSL1 (se requiere WSL2)
- ❌ Arquitecturas ARM (se requiere x86_64/amd64)

### 🚨 Consideraciones Importantes para WSL2

#### Limitaciones de WSL2

1. **Rendimiento de I/O**: Trabaja con archivos dentro del sistema de archivos de WSL (`/home/`) y no en Windows (`/mnt/c/`) para mejor rendimiento
2. **Networking**: El puerto 8000 será accesible desde Windows vía `localhost:8000`
3. **Recursos**: WSL2 usa virtualización, asegúrate de configurar `.wslconfig` apropiadamente
4. **Docker Desktop**: si usas WSL2, Docker Desktop es compatible siempre que la integración con la distro esté habilitada; si prefieres un entorno totalmente autónomo, usa Docker Engine dentro de WSL2

  Nota práctica: cuando el script se ejecuta dentro de WSL2, trabaja contra el Docker disponible en WSL2. Si tienes Docker Desktop integrado, podrás ver los contenedores desde Docker Desktop, pero el control real sigue saliendo desde WSL2.

#### Acceso a Archivos desde Windows

```bash
# Desde Windows, puedes acceder a los archivos de WSL en:
\\wsl.localhost\Ubuntu-22.04\home\tu_usuario\

# O desde WSL puedes acceder a archivos de Windows en:
/mnt/c/Users/TuUsuario/
```

### 📝 Resumen de Pasos Pre-Instalación

**Para WSL2 en Windows:**

1. ✅ Habilitar WSL2
2. ✅ Instalar Ubuntu 22.04 desde Microsoft Store o PowerShell
3. ✅ Configurar `.wslconfig` (opcional)
4. ✅ Actualizar paquetes: `sudo apt update && sudo apt upgrade -y`
5. ✅ Verificar espacio en disco y puertos
6. ✅ Continuar con el bloque de instalación rápida más arriba

**Para Ubuntu/Debian Nativo:**

1. ✅ Verificar versión del sistema (20.04+)
2. ✅ Actualizar paquetes: `sudo apt update && sudo apt upgrade -y`
3. ✅ Verificar permisos sudo
4. ✅ Verificar espacio en disco y puertos
5. ✅ Continuar con el bloque de instalación rápida más arriba

### 📋 Checklist de Verificación Automatizada

Para una verificación completa y automatizada de todos los pre-requisitos, consulta:

👉 **[docs/PRE-REQUISITOS.md](docs/PRE-REQUISITOS.md)** - Incluye:

- Checklist completo paso a paso
- Comandos de verificación rápida
- Script de auto-verificación
- Soluciones a problemas comunes de pre-requisitos

---

## 📂 Estructura del Proyecto

```markdown
test-airbyte/
├── airbyte-setup.sh           # Script de instalación inicial
├── scripts/
│   └── airbyte-management.sh  # Script de gestión completa
├── docs/
│   ├── PRE-REQUISITOS.md      # Verificación de pre-requisitos
│   ├── GUIA-COMANDOS.md       # Referencia completa de comandos
│   └── TROUBLESHOOTING.md     # Guía de solución de problemas
├── README.md                  # Documentación principal
└── .gitignore                 # Archivos a ignorar en Git
```

---

## 📂 Archivos del Proyecto

### 1. `airbyte-setup.sh`

Script de instalación inicial de Airbyte con todas las dependencias y configuraciones necesarias.

**Características:**

- Instalación automatizada de Docker, Docker Compose y Airbyte CLI
- Manejo de errores robusto
- Detección de instalaciones existentes con opciones de reparación/reinstalación
- Configuración automática de permisos de Docker
- Sin necesidad de reiniciar la terminal

**Uso:**

```bash
chmod +x airbyte-setup.sh
./airbyte-setup.sh
```

### 2. `scripts/airbyte-management.sh`

Script completo de gestión de Airbyte para operaciones diarias, mantenimiento y automatización.

**Características:**

- **Gestión de Servicios**: Iniciar, detener, reiniciar, ver estado
- **Backups y Restauración**: Crear backups automatizados, restaurar desde backup
- **Actualizaciones**: Actualizar Airbyte y abctl de forma segura
- **Logs y Debugging**: Ver logs, diagnóstico de problemas
- **API y Automatización**: Probar API, generar scripts de ejemplo
- **Auto-inicio**: Configurar Airbyte para iniciar automáticamente con el sistema
- **Mantenimiento**: Limpieza de logs, backups antiguos, imágenes Docker

**Uso:**

```bash
chmod +x scripts/airbyte-management.sh

# Menú interactivo
./scripts/airbyte-management.sh

# Comandos directos
./scripts/airbyte-management.sh start
./scripts/airbyte-management.sh stop
./scripts/airbyte-management.sh status
./scripts/airbyte-management.sh backup
./scripts/airbyte-management.sh update
```

### 3. `docs/GUIA-COMANDOS.md`

Guía completa de referencia con todos los comandos, APIs y mejores prácticas para Ingeniería de Datos.

**Contenido:**

- Comandos básicos y avanzados
- Gestión de servicios con Docker y Kubernetes
- API REST de Airbyte con ejemplos
- Backups automatizados y recuperación ante desastres
- Monitoreo, logs y métricas
- Optimización y troubleshooting
- Integración con CI/CD (GitHub Actions, GitLab CI)
- Scripts de automatización

**Uso:**

```bash
# Ver en el terminal
cat docs/GUIA-COMANDOS.md

# O abrir con tu editor favorito
code docs/GUIA-COMANDOS.md
```

### 4. `docs/PRE-REQUISITOS.md`

Guía de verificación completa de pre-requisitos con checklist y script de auto-verificación.

**Contenido:**

- Checklist rápido para WSL2 y Ubuntu/Debian nativo
- Comandos de verificación paso a paso
- Script automatizado de verificación de pre-requisitos
- Soluciones a problemas comunes de configuración
- Verificaciones específicas para WSL2 y sistemas nativos

**Uso:**

```bash
# Ver guía completa
cat docs/PRE-REQUISITOS.md

# Ejecutar verificación automatizada (extraer el script del documento)
# El script verifica: SO, espacio, puertos, sudo, internet, arquitectura
```

### 5. `docs/TROUBLESHOOTING.md`

Guía completa de solución de problemas para todos los escenarios comunes.

**Contenido:**

- Problemas de pre-requisitos
- Problemas de instalación
- Problemas de Docker
- Problemas de red
- Problemas de Airbyte
- Problemas de rendimiento
- Problemas específicos de WSL2
- Scripts de diagnóstico completo

**Uso:**

```bash
# Ver guía de troubleshooting
cat docs/TROUBLESHOOTING.md

# Buscar problema específico
grep -i "error específico" docs/TROUBLESHOOTING.md
```

---

## 📋 Flujo de Trabajo Típico para Ingeniería de Datos

### Setup Inicial de Conexión

1. **Acceder a Airbyte**: `http://localhost:8000`
2. **Crear Source**: Configurar tu fuente de datos (PostgreSQL, MySQL, API, etc.)
3. **Crear Destination**: Configurar tu destino (Data Warehouse, Data Lake, etc.)
4. **Crear Connection**: Configurar sincronización entre Source y Destination
5. **Definir Schedule**: Configurar frecuencia de sincronización

### Automatización con API

```bash
# Generar script de Python para la API
./scripts/airbyte-management.sh generate-api-script

# Editar y agregar credenciales
nano airbyte-api-example.py

# Ejecutar
python3 airbyte-api-example.py
```

### Monitoreo Continuo

```bash
# Script de monitoreo en background
cat > monitor.sh << 'EOF'
#!/bin/bash
while true; do
  ./scripts/airbyte-management.sh status >> /var/log/airbyte-monitor.log
  sleep 300  # Cada 5 minutos
done
EOF

chmod +x monitor.sh
nohup ./monitor.sh &
```

### Backups Automatizados

```bash
# Configurar backup diario con cron
crontab -e

# Agregar línea (reemplaza /path/to/airbyte-local-toolkit por la ruta real):
# 0 2 * * * /path/to/airbyte-local-toolkit/scripts/airbyte-management.sh backup
```

---

## 🔧 Configuración del Sistema para Auto-Inicio

Para que Airbyte inicie automáticamente después de un reinicio del sistema:

```bash
# Habilitar auto-inicio
./scripts/airbyte-management.sh enable-autostart

# Verificar
sudo systemctl status airbyte-local
```

---

## 🌐 Acceso Remoto (Opcional)

Para acceder a Airbyte desde otras máquinas en tu red local:

```bash
# ADVERTENCIA: Solo hacer esto en redes confiables

# Port forwarding
docker exec airbyte-abctl-control-plane kubectl port-forward -n airbyte-abctl \
  service/airbyte-abctl-server 8000:8000 --address 0.0.0.0 &

# Acceder desde otra máquina
# http://<IP-DE-TU-SERVIDOR>:8000
```

---

## 📊 Casos de Uso Comunes

### 1. Sincronización de Base de Datos a Data Warehouse

```markdown
PostgreSQL (Source)
    ↓
Airbyte Connection (Transformación + Sincronización)
    ↓
BigQuery/Snowflake (Destination)
```

### 2. Agregación de Datos de Múltiples APIs

```markdown
Stripe API (Source 1)
Salesforce API (Source 2)     →  Airbyte  →  Data Lake (S3/GCS)
Google Analytics (Source 3)
```

### 3. Replicación de Datos para Analytics

```markdown
MySQL Producción (Source)
    ↓
Airbyte (Replicación incremental)
    ↓
PostgreSQL Analytics (Destination)
```

---

## 🛠️ Troubleshooting Rápido

Para solución de problemas detallada, consulta la **[Guía Completa de Troubleshooting](docs/TROUBLESHOOTING.md)**.

### Problemas Comunes Rápidos

#### WSL2 no está habilitado o es WSL1

```powershell
# En PowerShell como Administrador
# Verificar versión de WSL
wsl -l -v

# Si dice VERSION 1, actualizar a WSL2
wsl --set-version Ubuntu-22.04 2
wsl --set-default-version 2
```

#### Error: "Docker daemon is not running"

```bash
# Verificar si Docker está instalado
docker --version

# Si no está instalado, el script lo instalará
# Si está instalado pero no corre:
sudo systemctl start docker
sudo systemctl enable docker

# Verificar estado
sudo systemctl status docker
```

#### Error: "Permission denied" al ejecutar Docker

```bash
# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Aplicar cambios sin reiniciar
newgrp docker

# O cerrar sesión y volver a entrar
```

#### Puerto 8000 ya está en uso

```bash
# Identificar qué proceso está usando el puerto
sudo lsof -i :8000
# o
sudo netstat -tulpn | grep 8000

# Detener el proceso o cambiar el puerto de Airbyte
# Para cambiar puerto (en instalación):
abctl local install --port=8080
```

#### No hay suficiente espacio en disco

```bash
# Verificar espacio
df -h ~

# Limpiar espacio en WSL2
# Eliminar paquetes no necesarios
sudo apt autoremove
sudo apt clean

# Limpiar Docker
docker system prune -a

# En Windows, puedes compactar el disco virtual de WSL2
# Desde PowerShell (WSL debe estar detenido):
wsl --shutdown
Optimize-VHD -Path $env:LOCALAPPDATA\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_*\LocalState\ext4.vhdx -Mode Full
```

#### Problemas de red/conectividad en WSL2

```bash
# Reiniciar servicios de red en WSL2
sudo service networking restart

# Verificar DNS
cat /etc/resolv.conf

# Si hay problemas de DNS, agregar manualmente:
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# Reiniciar WSL desde PowerShell
wsl --shutdown
wsl
```

### Airbyte no inicia

```bash
# Diagnóstico completo
./scripts/airbyte-management.sh troubleshoot

# Verificar Docker
sudo systemctl status docker
sudo systemctl start docker

# Reiniciar Airbyte
./scripts/airbyte-management.sh restart
```

### No puedo acceder a `http://localhost:8000`

```bash
# Verificar que Airbyte está corriendo
./scripts/airbyte-management.sh status

# Verificar puerto
netstat -tuln | grep 8000

# Ver logs
./scripts/airbyte-management.sh logs
```

### Problemas de rendimiento

```bash
# Limpiar recursos no utilizados
./scripts/airbyte-management.sh cleanup

# Ver uso de recursos
docker stats

# Considerar modo de bajos recursos
abctl local install --low-resource-mode
```

---

## 📚 Recursos Adicionales

### Documentación

- **Documentación Oficial**: `https://docs.airbyte.com/`
- **API Documentation**: `https://reference.airbyte.com/`
- **Connector Catalog**: `https://docs.airbyte.com/integrations/`

### Conectores Populares

**Sources (Fuentes):**

- PostgreSQL, MySQL, MongoDB
- Salesforce, HubSpot, Stripe
- Google Analytics, Google Ads
- AWS S3, Google Cloud Storage
- REST API (genérico)

**Destinations (Destinos):**

- BigQuery, Snowflake, Redshift
- PostgreSQL, MySQL
- AWS S3, Google Cloud Storage
- Elasticsearch
- dbt Cloud

### Comunidad

- **Slack**: `https://slack.airbyte.com/`
- **GitHub**: `https://github.com/airbytehq/airbyte`
- **Forum**: `https://discuss.airbyte.io/`

---

## ⚙️ Configuraciones Avanzadas

### Variables de Entorno

```bash
# Agregar al ~/.bashrc o ~/.zshrc

# Deshabilitar telemetría
export AIRBYTE_TELEMETRY=false

# Aumentar timeouts
export AIRBYTE_SYNC_TIMEOUT=7200

# Nivel de logging
export AIRBYTE_LOG_LEVEL=DEBUG
```

### Optimización de Recursos

Para sistemas con recursos limitados:

```bash
# Instalar en modo de bajos recursos
abctl local install --low-resource-mode

# Limitar workers concurrentes (ajustar en la UI)
# Settings → Workspace → Max concurrent jobs: 2
```

---

## 🔐 Seguridad

### Mejores Prácticas

1. **No exponer Airbyte a Internet sin autenticación adicional**
2. **Usar HTTPS en producción (requiere reverse proxy)**
3. **Rotar credenciales periódicamente**
4. **Hacer backups cifrados para datos sensibles**
5. **Limitar acceso de red con firewall**

### Backup Cifrado

```bash
# Crear backup cifrado
./scripts/airbyte-management.sh backup
gpg -c ~/airbyte-backups/airbyte_backup_*.tar.gz

# Restaurar backup cifrado
gpg -d airbyte_backup_*.tar.gz.gpg > airbyte_backup.tar.gz
./scripts/airbyte-management.sh restore
```

---

## 📈 Roadmap y Próximas Mejoras

- [ ] Integración con Terraform para IaC
- [ ] Dashboard de monitoreo con Grafana
- [ ] Alertas vía Slack/Email
- [ ] Ejemplos de dbt integration
- [ ] Scripts de testing de conexiones
- [ ] Configuración de alta disponibilidad

---

## 🤝 Contribuciones

Si encuentras bugs o tienes sugerencias de mejora:

1. Documenta el problema o sugerencia
2. Crea un issue o pull request
3. Comparte tus scripts y configuraciones útiles

---

## 📄 Licencia

Este toolkit es de código abierto. Úsalo y modifícalo según tus necesidades.

Los scripts están diseñados para facilitar el trabajo de la Ingeniería de Datos con Airbyte en entornos locales y de desarrollo.

---

## 🎯 Resumen de Comandos Críticos

```bash
# Instalación
./airbyte-setup.sh

# Gestión diaria
./scripts/airbyte-management.sh start
./scripts/airbyte-management.sh stop
./scripts/airbyte-management.sh status

# Backups
./scripts/airbyte-management.sh backup
./scripts/airbyte-management.sh restore

# Mantenimiento
./scripts/airbyte-management.sh update
./scripts/airbyte-management.sh cleanup
./scripts/airbyte-management.sh troubleshoot

# API
./scripts/airbyte-management.sh test-api
./scripts/airbyte-management.sh generate-api-script

# Auto-inicio
./scripts/airbyte-management.sh enable-autostart

# Credenciales
./scripts/airbyte-management.sh credentials
```

---

**¡Listo para comenzar con Airbyte! 🚀**  
