# ✅ Checklist de Pre-requisitos - Airbyte Setup

Use este documento para verificar rápidamente que su sistema cumple con todos los requisitos antes de ejecutar el script de instalación.

---

## 📋 Checklist Rápido

### Para Usuarios de WSL2 en Windows 10/11

- [ ] WSL2 está habilitado y configurado
- [ ] Ubuntu 22.04 (o superior) está instalado en WSL2
- [ ] Sistema actualizado (`sudo apt update && sudo apt upgrade -y`)
- [ ] Al menos 10 GB de espacio libre en disco
- [ ] Puerto 8000 disponible
- [ ] Permisos sudo configurados
- [ ] Conexión a internet activa

### Para Usuarios de Ubuntu/Debian Nativo

- [ ] Ubuntu 20.04+ o Debian 11+ instalado
- [ ] Sistema actualizado (`sudo apt update && sudo apt upgrade -y`)
- [ ] Al menos 10 GB de espacio libre en disco
- [ ] Puerto 8000 disponible
- [ ] Permisos sudo configurados
- [ ] Conexión a internet activa

### Para Usuarios de una VM Aislada

- [ ] Ubuntu Server 24.04 LTS instalado en la VM
- [ ] Red funcional con salida a internet
- [ ] Al menos 10 GB de espacio libre en disco
- [ ] Puerto 8000 disponible o redirección configurada
- [ ] Permisos sudo configurados
- [ ] Docker accesible desde la VM

---

## 🔍 Comandos de Verificación Rápida

Ejecuta estos comandos uno por uno para verificar cada requisito:

### 1. Verificar Sistema Operativo

```bash
# Para Ubuntu
lsb_release -a

# Para verificar si es WSL2
uname -r | grep -i microsoft
# Si retorna algo, estás en WSL

# Para verificar versión de WSL (desde PowerShell en Windows)
# wsl -l -v
```

**✅ Resultado esperado:** Ubuntu 20.04+, Debian 11+, Ubuntu Server 24.04 LTS en VM aislada, o WSL2 con Docker Desktop integrado o Docker Engine local

---

### 2. Verificar Espacio en Disco

```bash
df -h ~
```

**✅ Resultado esperado:** Al menos 10 GB disponibles (Avail column)

---

### 3. Verificar Puerto 8000

```bash
# Opción 1
netstat -tuln | grep 8000

# Opción 2
ss -tuln | grep 8000

# Opción 3
sudo lsof -i :8000
```

**✅ Resultado esperado:** No debe retornar ningún resultado (puerto libre)

---

### 4. Verificar Permisos Sudo

```bash
sudo whoami
```

**✅ Resultado esperado:** Debe retornar `root`

---

### 5. Verificar Conexión a Internet

```bash
# Ping básico
ping -c 3 google.com

# Verificar acceso a repositorio de Airbyte
curl -I https://get.airbyte.com
```

**✅ Resultado esperado:** Respuestas exitosas sin errores

---

### 6. Verificar Versiones de Herramientas (Opcional)

Estas herramientas serán instaladas por el script si no existen, pero puedes verificar si ya las tienes:

```bash
# Docker
docker --version

# Docker Compose
docker-compose --version
# o
docker compose version

# curl
curl --version

# git
git --version

# abctl (Airbyte CLI)
abctl version
```

**✅ Resultado esperado:** Si ya están instalados, verás las versiones. Si no, el script las instalará.

---

## 🪟 Verificaciones Específicas para WSL2

### 1. Verificar que es WSL2 (no WSL1)

```powershell
# En PowerShell (Windows)
wsl -l -v
```

**✅ Resultado esperado:**

```bash
  NAME            STATE           VERSION
* Ubuntu-22.04    Running         2
```

El `VERSION` debe ser `2`, no `1`.

---

### 2. Verificar Configuración de WSL2

```powershell
# En PowerShell (Windows)
# Ver archivo de configuración si existe
cat $env:USERPROFILE\.wslconfig
```

**✅ Configuración recomendada** (crear si no existe):

```ini
[wsl2]
memory=6GB
processors=4
swap=2GB
localhostForwarding=true
```

---

### 3. Verificar Acceso al Sistema de Archivos de WSL

```bash
# Desde WSL
pwd
# Debería estar en /home/tu_usuario/

# Verificar que NO estás trabajando en /mnt/c/
# Trabajar en /mnt/c/ es más lento
```

**✅ Resultado esperado:** Deberías estar en `/home/jasrockr/` o similar, NO en `/mnt/c/`

---

## 🐧 Verificaciones Específicas para Ubuntu/Debian Nativo

### 1. Verificar Grupo Docker (si ya tienes Docker)

```bash
groups $USER | grep docker
```

**✅ Resultado esperado:** Si Docker ya está instalado, deberías ver `docker` en la lista. Si no, el script lo configurará.

---

### 2. Verificar systemd

```bash
ps --no-headers -o comm 1
```

**✅ Resultado esperado:** `systemd` (necesario para servicios)

---

### 3. Verificar Arquitectura del Sistema

```bash
uname -m
```

**✅ Resultado esperado:** `x86_64` o `amd64` (NO `arm`, `arm64`, `aarch64`)

---

## 🚨 Problemas Comunes y Soluciones

### ❌ WSL es versión 1, no 2

**Solución:**

```powershell
# En PowerShell como Administrador
wsl --set-version Ubuntu-22.04 2
wsl --set-default-version 2
```

---

### ❌ Puerto 8000 está ocupado

**Identificar qué lo está usando:**

```bash
sudo lsof -i :8000
```

**Soluciones:**

1. Detener el servicio que usa el puerto
2. O usar un puerto diferente para Airbyte:

```bash
abctl local install --port=8080
```

---

### ❌ No hay suficiente espacio

**Liberar espacio:**

```bash
# Limpiar paquetes
sudo apt autoremove
sudo apt clean

# Limpiar Docker (si ya está instalado)
docker system prune -a

# Ver qué está ocupando espacio
du -sh ~/* | sort -h
```

---

### ❌ Sin permisos sudo

**Solución:**

```bash
# Cambiar a root
su -

# Agregar usuario al grupo sudo
usermod -aG sudo tu_usuario

# Salir y volver a entrar
exit
```

---

### ❌ No hay conexión a internet

**Para WSL2:**

```bash
# Verificar DNS
cat /etc/resolv.conf

# Reiniciar red
sudo service networking restart

# Si persiste, desde PowerShell:
wsl --shutdown
wsl
```

**Para Ubuntu/Debian nativo:**

```bash
# Verificar conexión
ip addr show
ping 8.8.8.8

# Reiniciar servicio de red
sudo systemctl restart NetworkManager
```

---

## ✅ Script de Auto-verificación

Copia y pega este script para verificar todos los requisitos automáticamente:

```bash
#!/bin/bash
# check-prerequisites.sh

echo "================================"
echo "Verificador de Pre-requisitos"
echo "================================"
echo ""

# Función de verificación
check() {
    if [ $? -eq 0 ]; then
        echo "✅ $1: OK"
        return 0
    else
        echo "❌ $1: FALLO"
        return 1
    fi
}

# 1. Sistema operativo
echo "1. Verificando sistema operativo..."
[ -f /etc/debian_version ] || [ -f /etc/lsb-release ]
check "Sistema Debian/Ubuntu"

# 2. Espacio en disco
echo ""
echo "2. Verificando espacio en disco..."
SPACE=$(df -h ~ | awk 'NR==2 {print $4}' | sed 's/G//')
if (( $(echo "$SPACE > 10" | bc -l) )); then
    echo "✅ Espacio en disco: ${SPACE}GB disponibles"
else
    echo "❌ Espacio en disco: Solo ${SPACE}GB disponibles (se necesitan 10GB)"
fi

# 3. Puerto 8000
echo ""
echo "3. Verificando puerto 8000..."
if ! netstat -tuln 2>/dev/null | grep -q ':8000' && ! ss -tuln 2>/dev/null | grep -q ':8000'; then
    echo "✅ Puerto 8000: Disponible"
else
    echo "❌ Puerto 8000: Ocupado"
fi

# 4. Permisos sudo
echo ""
echo "4. Verificando permisos sudo..."
sudo -n true 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Permisos sudo: OK"
else
    echo "⚠️  Permisos sudo: Requiere contraseña (normal)"
    sudo -v
    check "Permisos sudo"
fi

# 5. Conexión a internet
echo ""
echo "5. Verificando conexión a internet..."
ping -c 1 google.com &>/dev/null
check "Conexión a internet"

# 6. Curl (para verificar acceso a Airbyte)
echo ""
echo "6. Verificando acceso a repositorio de Airbyte..."
curl -sI https://get.airbyte.com | head -1 | grep -q "200"
check "Acceso a get.airbyte.com"

# 7. Arquitectura
echo ""
echo "7. Verificando arquitectura del sistema..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    echo "✅ Arquitectura: $ARCH (Compatible)"
else
    echo "❌ Arquitectura: $ARCH (No compatible - se requiere x86_64/amd64)"
fi

# Resumen
echo ""
echo "================================"
echo "Verificación completada"
echo "================================"
echo ""
echo "Si todos los checks son ✅, puedes proceder con la instalación:"
echo "  ./airbyte-setup.sh"
echo ""
echo "Si hay algún ❌, revisa la sección de troubleshooting en README.md"
```

**Para usar el script de auto-verificación:**

```bash
# Guardar el script
cat > check-prerequisites.sh << 'EOF'
[copiar el script de arriba]
EOF

# Dar permisos
chmod +x check-prerequisites.sh

# Ejecutar
./check-prerequisites.sh
```

---

## 📝 Resumen

Una vez que todos los checks estén en ✅, estás listo para ejecutar:

```bash
./airbyte-setup.sh
```

Si tienes algún ❌, consulta:

- La sección de **Troubleshooting** en el [README.md](README.md)
- La sección de **Pre-requisitos** detallada en el [README.md](README.md)
- El comando de **diagnóstico**: `./airbyte-management.sh troubleshoot` (después de instalar)

---

**¡Buena suerte con tu instalación de Airbyte! 🚀**

