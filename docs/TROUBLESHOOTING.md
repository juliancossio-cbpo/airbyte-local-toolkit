# 🛠️ Guía de Solución de Problemas - Airbyte

Esta guía cubre los problemas más comunes al instalar y ejecutar Airbyte en WSL2 y sistemas Ubuntu/Debian nativos.

---

## 📑 Índice

1. [Problemas de Pre-requisitos](#-problemas-de-pre-requisitos)
2. [Problemas de Instalación](#-problemas-de-instalación)
3. [Problemas de Docker](#-problemas-de-docker)
4. [Problemas de Red](#-problemas-de-red)
5. [Problemas de Airbyte](#-problemas-de-airbyte)
6. [Problemas de Rendimiento](#-problemas-de-rendimiento)
7. [Problemas Específicos de WSL2](#-problemas-específicos-de-wsl2)
8. [Verificaciones de Diagnóstico](#-verificaciones-de-diagnóstico)

---

## 🔴 Problemas de Pre-requisitos

### WSL2 no está habilitado o es WSL1

**Síntomas:**

- El script no funciona correctamente
- Problemas con Docker
- Performance muy bajo

**Solución:**

```powershell
# En PowerShell como Administrador
# Verificar versión de WSL
wsl -l -v

# Si dice VERSION 1, actualizar a WSL2
wsl --set-version Ubuntu-22.04 2
wsl --set-default-version 2

# Reiniciar WSL
wsl --shutdown
wsl
```

**Verificar:**

```powershell
wsl -l -v
# Debe mostrar VERSION 2
```

---

### Sistema operativo no soportado

**Síntomas:**

- Script falla con error de sistema no soportado

**Causa:**

- No estás usando Ubuntu/Debian o WSL2 con Ubuntu

**Solución:**

```bash
# Verificar tu distribución
lsb_release -a

# Versiones soportadas:
# Ubuntu: 20.04, 22.04, 24.04
# Debian: 11 (Bullseye), 12 (Bookworm)
```

Si usas otra distribución, necesitarás adaptar los scripts o instalar Ubuntu/Debian.

---

### No hay suficiente espacio en disco

**Síntomas:**

- Error durante la instalación: "No space left on device"
- Docker falla al descargar imágenes

**Verificar espacio:**

```bash
# Ver espacio disponible
df -h ~

# Necesitas al menos 10 GB libres
```

**Soluciones:**

```bash
# 1. Limpiar paquetes no necesarios
sudo apt autoremove -y
sudo apt clean

# 2. Limpiar Docker (si ya está instalado)
docker system prune -a

# 3. Eliminar archivos temporales
sudo rm -rf /tmp/*
rm -rf ~/.cache/*

# 4. Ver qué está ocupando espacio
du -sh /* 2>/dev/null | sort -hr | head -20
```

**Para WSL2 específicamente:**

```powershell
# En PowerShell como Administrador (WSL debe estar detenido)
wsl --shutdown

# Compactar disco virtual de WSL2
Optimize-VHD -Path $env:LOCALAPPDATA\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_*\LocalState\ext4.vhdx -Mode Full

# O usar diskpart manualmente
diskpart
select vdisk file="C:\Users\TuUsuario\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_...\LocalState\ext4.vhdx"
compact vdisk
exit
```

---

### Usuario sin permisos sudo

**Síntomas:**

- Script falla con "Permission denied"
- No puedes ejecutar comandos con sudo

**Solución:**

```bash
# Verificar permisos sudo
sudo -v

# Si falla, agregar tu usuario al grupo sudo
su -
usermod -aG sudo $USUARIO
exit

# Cerrar sesión y volver a entrar
exit
# volver a abrir WSL o terminal
```

---

### Puerto 8000 ya está en uso

Si el instalador detecta que 8000 está ocupado, probará un puerto alterno libre y guardará la elección en `~/.airbyte/abctl/airbyte-port`.

**Síntomas:**

- Airbyte no puede iniciar
- Error: "Address already in use"

**Identificar proceso:**

```bash
# Con lsof
sudo lsof -i :8000

# Con netstat
sudo netstat -tulpn | grep 8000

# Con ss (más moderno)
ss -tuln | grep 8000
```

**Soluciones:**

```bash
# Opción 1: Detener el proceso que usa el puerto
sudo kill -9 <PID>

# Opción 2: Cambiar el puerto de Airbyte
abctl local install --port=8080

# Actualizar acceso:
# http://localhost:8080
```

---

## 🔴 Problemas de Instalación

### Error: "Package not found" o "Unable to locate package"

**Síntomas:**

- apt install falla para Docker u otro paquete

**Solución:**

```bash
# Actualizar lista de paquetes
sudo apt update

# Si hay errores de repositorios, actualizar keys
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys <KEY_ID>

# Reinstalar repositorios base
sudo apt install -y --reinstall software-properties-common
```

---

### Error: "bash: ./airbyte-setup.sh: /bin/bash^M: bad interpreter"

**Causa:**

- Archivos creados en Windows con finales de línea CRLF

**Solución:**

```bash
# Convertir finales de línea a Unix (LF)
sed -i 's/\r$//' airbyte-setup.sh
sed -i 's/\r$//' airbyte-management.sh

# O usar dos2unix si está disponible
dos2unix airbyte-setup.sh airbyte-management.sh

# Verificar formato
file airbyte-setup.sh
# Debe decir "... with LF line terminators" (no CRLF)
```

---

### Instalación se queda colgada en el navegador

**Síntomas:**

- Script se detiene al intentar abrir el navegador

**Solución:**

El script ya incluye `BROWSER=echo` y `--no-browser` pero si usas una versión antigua:

```bash
# Editar el script y asegurar que tenga:
export BROWSER=echo
abctl local install --no-browser
```

---

## 🔴 Problemas de Docker

### Error: "Docker daemon is not running"

**Nota para WSL2 con Docker Desktop:**

Si estás en WSL2, el script usa el Docker disponible dentro de WSL2 y no depende de un Docker nativo de Windows. Si además usas Docker Desktop, asegúrate de que la integración con esta distribución esté habilitada; en ese caso, podrás ver los contenedores desde Docker Desktop, pero el flujo operativo sigue ejecutándose desde WSL2.

**Verificar instalación:**

```bash
# Ver si Docker está instalado
docker --version

# Ver estado del servicio
sudo systemctl status docker
```

**Soluciones:**

```bash
# Iniciar Docker
sudo systemctl start docker

# Habilitar auto-inicio
sudo systemctl enable docker

# Verificar que inició correctamente
sudo systemctl status docker

# Si falla, ver logs
sudo journalctl -u docker --no-pager | tail -50
```

### Error: `docker-credential-desktop.exe` o `exec format error` en WSL2

**Síntomas:**

- `abctl` no puede crear el cluster de kind
- El pull de imágenes falla con `error getting credentials`
- Aparece `fork/exec /usr/bin/docker-credential-desktop.exe: exec format error`

**Causa habitual:**

- El cliente Docker dentro de WSL2 está leyendo una configuración generada por Docker Desktop para Windows

**Solución aplicada por el script:**

- El instalador crea una configuración temporal de Docker dentro de WSL2 para evitar el helper de Windows durante la instalación

**Si sigue ocurriendo:**

```bash
# Verificar que no estés forzando una configuración de Docker de Windows
echo "$DOCKER_CONFIG"

# Revisar tu config actual
cat ~/.docker/config.json

# Si ves credHelpers o credsStore apuntando a desktop.exe, muévelo o corrígelo para WSL2
```

---

### Error: "Permission denied" al ejecutar Docker

**Síntomas:**

- Comandos docker requieren sudo
- Error: "Got permission denied while trying to connect to the Docker daemon socket"

**Solución:**

```bash
# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Aplicar cambios SIN reiniciar sesión
newgrp docker

# O usar sg
sg docker -c "docker ps"

# Para que sea permanente, cerrar sesión y volver a entrar
exit
# volver a abrir terminal/WSL
```

**Verificar:**

```bash
# Este comando debe funcionar SIN sudo
docker ps
```

---

### Docker falla al descargar imágenes

**Síntomas:**

- Error: "TLS handshake timeout"
- Error: "net/http: request canceled"

**Soluciones:**

```bash
# Verificar conectividad
ping -c 3 registry-1.docker.io

# Reiniciar Docker
sudo systemctl restart docker

# Limpiar caché de Docker
docker system prune -a

# Configurar DNS en Docker (crear/editar /etc/docker/daemon.json)
sudo mkdir -p /etc/docker
echo '{
  "dns": ["8.8.8.8", "8.8.4.4"]
}' | sudo tee /etc/docker/daemon.json

sudo systemctl restart docker
```

---

## 🔴 Problemas de Red

### Problemas de red/conectividad en WSL2

**Síntomas:**

- No hay acceso a Internet desde WSL2
- No puedes hacer ping a servidores externos
- apt update falla

**Soluciones:**

```bash
# 1. Verificar DNS
cat /etc/resolv.conf

# 2. Agregar DNS manualmente
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo  "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf

# 3. Reiniciar servicios de red
sudo service networking restart

# 4. Reiniciar WSL completamente (desde PowerShell)
# wsl --shutdown
# wsl
```

**Solución permanente para DNS en WSL2:**

```bash
# Deshabilitar auto-generación de resolv.conf
sudo sh -c 'echo "[network]" > /etc/wsl.conf'
sudo sh -c 'echo "generateResolvConf = false" >> /etc/wsl.conf'

# Eliminar resolv.conf existente
sudo rm /etc/resolv.conf

# Crear nuevo con DNS de Google
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf

# Hacer inmutable para que no se sobrescriba
sudo chattr +i /etc/resolv.conf
```

Reiniciar WSL:

```powershell
wsl --shutdown
wsl
```

---

### No puedo acceder a `http://localhost:8000` desde Windows

**Síntomas:**

- Airbyte funciona en WSL2 pero no puedes acceder desde el navegador de Windows

**Verificar:**

```bash
# Desde WSL2
curl http://localhost:8000
# Debe retornar HTML de Airbyte
```

**Soluciones:**

```bash
# Ver puertos expuestos
netstat -tuln | grep 8000

# Verificar que WSL2 está en el modo correcto
# En PowerShell:
# Get-NetAdapter
```

**Si sigue sin funcionar:**

```powershell
# Desde PowerShell como Administrador
# Reiniciar WSL
wsl --shutdown
wsl

# Verificar que localhostForwarding está habilitado
# En .wslconfig (C:\Users\TuUsuario\.wslconfig):
# [wsl2]
# localhostForwarding=true

# Reiniciar WSL
wsl --shutdown
wsl
```

**Alternativa - Usar IP de WSL2:**

```bash
# Desde WSL2, obtener IP
ip addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1

# Acceder desde Windows usando la IP WSL2
# http://<IP_WSL2>:8000
```

---

## 🔴 Problemas de Airbyte

### Airbyte no inicia

**Diagnóstico completo:**

```bash
# Usar el script de troubleshooting
./scripts/airbyte-management.sh troubleshoot

# O manualmente:

# 1. Verificar Docker
sudo systemctl status docker

# 2. Ver si hay proceso de Airbyte
ps aux | grep abctl

# 3. Ver logs de Airbyte
./scripts/airbyte-management.sh logs

# 4. Verificar instalación de abctl
abctl version
```

**Soluciones:**

```bash
# Reiniciar Airbyte
./scripts/airbyte-management.sh restart

# Si falla, reinstalar
./scripts/airbyte-management.sh stop
abctl local uninstall
./airbyte-setup.sh
```

---

### Airbyte se detiene después de un tiempo

**Síntomas:**

- Airbyte funciona inicialmente pero se detiene solo

**Causas comunes:**

- Falta de recursos (RAM/CPU)
- Problemas de red
- Disco lleno

**Soluciones:**

```bash
# 1. Verificar recursos
docker stats

# 2. Ver logs de crash
./scripts/airbyte-management.sh logs | grep -i error

# 3. Verificar espacio en disco
df -h

# 4. Reiniciar con más recursos (en .wslconfig para WSL2)
# memory=6GB
# processors=4

# 5. Usar modo de bajos recursos
abctl local install --low-resource-mode
```

---

### Error al crear conexiones o ejecutar syncs

**Verificar:**

```bash
# Ver estado de la API
./scripts/airbyte-management.sh test-api

# Ver logs en tiempo real
./scripts/airbyte-management.sh logs -f

# Verificar conectores instalados
# Desde la UI: Settings → Sources/Destinations
```

**Soluciones:**

```bash
# Actualizar Airbyte
./scripts/airbyte-management.sh update

# Limpiar y reiniciar
./scripts/airbyte-management.sh cleanup
./scripts/airbyte-management.sh restart
```

---

## 🔴 Problemas de Rendimiento

### Airbyte es muy lento

**Causas:**

- Recursos limitados
- Uso de archivos en /mnt/c/ en WSL2 (muy lento)
- Muchos logs acumulados

**Soluciones:**

```bash
# 1. Verificar ubicación de datos
pwd
# Asegúrate de estar en /home/ NO en /mnt/c/

# 2. Limpiar logs y recursos
./scripts/airbyte-management.sh cleanup

# 3. Ver uso de recursos
docker stats

# 4. Configurar bajos recursos
abctl local install --low-resource-mode

# 5. Limitar workers concurrentes
# Desde UI: Settings → Workspace Settings
# Max concurrent jobs: 2

# 6. Para WSL2, verificar .wslconfig
# memory=6GB
# processors=4
# swap=2GB
```

---

### Docker consume mucha memoria

```bash
# Ver uso de memoria
docker stats

# Limpiar imágenes no usadas
docker system prune -a

# Limpiar volúmenes
docker volume prune

# Limitar memoria de Docker (en daemon.json)
sudo sh -c 'echo "{
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"10m\",
    \"max-file\": \"3\"
  }
}" > /etc/docker/daemon.json'

sudo systemctl restart docker
```

---

## 🔴 Problemas Específicos de WSL2

### WSL2 no inicia o se queda colgado

```powershell
# En PowerShell como Administrador

# Reiniciar WSL
wsl --shutdown
wsl

# Ver estado de distribuciones
wsl -l -v

# Reiniciar distribución específica
wsl -t Ubuntu-22.04
wsl -d Ubuntu-22.04

# Si sigue sin funcionar, reiniciar servicio LxssManager
net stop LxssManager
net start LxssManager
```

---

### Error: "The system cannot find the file specified"

**Causa:**

- Distribución WSL2 corrupta o mal instalada

**Solución:**

```powershell
# Ver distribuciones instaladas
wsl -l -v

# Desregistr ar y re-instalar (ESTO BORRA TODO)
wsl --unregister Ubuntu-22.04

# Reinstalar
wsl --install -d Ubuntu-22.04
```

---

### WSL2 consume mucha memoria en Windows

**Configurar límites en .wslconfig:**

Crear/editar `C:\Users\TuUsuario\.wslconfig`:

```ini
[wsl2]
# Limitar memoria (ajustar según tu RAM)
memory=4GB

# Limitar procesadores
processors=2

# Swap
swap=1GB

# Liberar memoria no usada
vmIdleTimeout=60000
```

Aplicar cambios:

```powershell
wsl --shutdown
wsl
```

---

## 🔴 Verificaciones de Diagnóstico

### Script de diagnóstico completo

```bash
#!/bin/bash

echo "=== DIAGNÓSTICO COMPLETO ==="
echo ""

echo "1. Sistema Operativo:"
lsb_release -a 2>/dev/null || cat /etc/os-release
echo ""

echo "2. Espacio en Disco:"
df -h ~ | grep -v tmpfs
echo ""

echo "3. Memoria RAM:"
free -h
echo ""

echo "4. Docker:"
docker --version
sudo systemctl status docker --no-pager
echo ""

echo "5. Docker Compose:"
docker-compose --version
echo ""

echo "6. Airbyte CLI:"
abctl version
echo ""

echo "7. Puertos en uso:"
sudo netstat -tuln | grep -E ':(8000|8080)'
echo ""

echo "8. Procesos de Airbyte:"
ps aux | grep -i airbyte | grep -v grep
echo ""

echo "9. Conectividad:"
ping -c 2 google.com
echo ""

echo "10. DNS:"
cat /etc/resolv.conf
echo ""

echo "11. Grupos del usuario:"
groups
echo ""

echo "12. Permisos de Docker socket:"
ls -l /var/run/docker.sock
echo ""

echo "=== FIN DEL DIAGNÓSTICO ==="
```

**Guardar y ejecutar:**

```bash
chmod +x diagnostico.sh
./diagnostico.sh > diagnostico.log 2>&1

# Ver resultado
cat diagnostico.log
```

---

## 📞 Obtener Ayuda Adicional

Si ninguna de estas soluciones funciona:

1. **Ejecutar diagnóstico completo** (script arriba)
2. **Revisar logs detallados:**

   ```bash
   ./scripts/airbyte-management.sh logs > airbyte.log
   ```

3. **Documentación oficial:**
   - `https://docs.airbyte.com/`
   - `https://docs.airbyte.com/deploying-airbyte/local-deployment`

4. **Comunidad:**
   - Slack: `https://slack.airbyte.com/`
   - Forum: `https://discuss.airbyte.io/`
   - GitHub Issues: `https://github.com/airbytehq/airbyte/issues`

5. **Crear issue con:**
   - Output del diagnóstico completo
   - Logs de Airbyte
   - Descripción detallada del problema
   - Pasos para reproducir

---

## ✅ Checklist de Verificación Rápida

Antes de reportar un problema, verifica:

- [ ] WSL2 está habilitado (si aplica)
- [ ] Sistema operativo es Ubuntu/Debian soportado
- [ ] Hay al menos 10 GB de espacio libre
- [ ] Docker está instalado y corriendo
- [ ] Usuario está en el grupo `docker`
- [ ] Puerto 8000 está libre
- [ ] Hay conexión a Internet
- [ ] DNS funciona correctamente
- [ ] Scripts tienen permisos de ejecución
- [ ] Archivos tienen finales de línea Unix (LF)

---

**¿Resolviste tu problema o encontraste una nueva solución? ¡Contribuye a esta guía!**
