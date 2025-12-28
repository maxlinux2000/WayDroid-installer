# 1. Crear el script wrapper de inicio
cat > waydroid_installer.run << 'EOF_WRAPPER'
#!/bin/bash
# Waydroid Installer - Script auto-extraíble
# -----------------------------------------------------------------------------
set -e

# Marcador que indica dónde empieza el payload (¡NO CAMBIAR ESTA LÍNEA!)
PAYLOAD_LINE=$(awk '/^# --- PAYLOAD START ---$/ {print NR + 1; exit 0; }' "$0")

# Comprobar si se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "🚨 Este script debe ejecutarse con permisos de root (sudo)."
    echo "Pediremos sudo para continuar."
    
    # Intentar re-ejecutar el script con sudo
    exec sudo "$0" "$@"
    
    # Si exec tiene éxito, el script termina aquí. Si falla, se comprobará de nuevo.
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ No se pudieron obtener permisos de root. Abortando."
        exit 1
    fi
fi

# Directorio temporal y nombre del payload
TMP_DIR=$(mktemp -d)
PAYLOAD_SCRIPT="$TMP_DIR/installer_payload.sh"

echo "Instalador Waydroid: Extrayendo archivos a $TMP_DIR..."

# 2. Extraer el payload a un archivo temporal
tail -n +$PAYLOAD_LINE "$0" > "$PAYLOAD_SCRIPT"

# 3. Dar permisos de ejecución
chmod +x "$PAYLOAD_SCRIPT"

# 4. Ejecutar el payload
if "$PAYLOAD_SCRIPT"; then
    echo "✅ Instalación finalizada."
else
    echo "❌ La instalación ha fallado. Revisar los errores anteriores."
fi

# 5. Limpiar el directorio temporal al salir
rm -rf "$TMP_DIR"

exit $?

# --- PAYLOAD START ---
EOF_WRAPPER

# 2. Adjuntar el payload (el script de instalación modificado con la verificación)
cat >> waydroid_installer.run << 'EOF_PAYLOAD_MODIFIED'
#!/bin/bash
# Script de instalación de Waydroid (Payload interno)
# -----------------------------------------------------------------------------
set -e

# Se asume que este script ya se ejecuta con permisos de root por el script wrapper.

echo "🚀 Iniciando la instalación automatizada de Waydroid..."
echo "---"

# -----------------------------------------------------------------------------
# 0. Verificación de Compatibilidad
# -----------------------------------------------------------------------------
echo "🔍 0/5: Verificando la compatibilidad del sistema operativo..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "❌ No se pudo determinar el sistema operativo. Abortando."
    exit 1
fi

# ID_LIKE a menudo es "debian" en derivados, pero comprobaremos Debian directamente.
if [ "$ID" != "debian" ]; then
    echo "❌ Distribución no compatible."
    echo "Este instalador está diseñado para Debian (versión 12 o superior)."
    echo "Su ID de distribución es: $ID"
    exit 1
fi

# El soporte estable se garantiza a partir de Bookworm (12)
REQUIRED_VERSION=12
CURRENT_VERSION=${VERSION_ID%.*} # Tomamos solo el número principal si hay un decimal

if [ "$CURRENT_VERSION" -lt "$REQUIRED_VERSION" ]; then
    echo "❌ Versión de Debian no compatible."
    echo "Versión mínima requerida: Debian $REQUIRED_VERSION (Bookworm)."
    echo "Su versión actual es: Debian $CURRENT_VERSION."
    exit 1
fi

echo "✅ Sistema operativo compatible: Debian $CURRENT_VERSION."
echo "---"


# -----------------------------------------------------------------------------
# 1. Instalación de Pre-requisitos
# -----------------------------------------------------------------------------
echo "📦 1/5: Instalando paquetes pre-requisitos: curl, ca-certificates, ufw..."
apt update
if ! apt install curl ca-certificates ufw -y; then
    echo "❌ Error al instalar los paquetes base. Verifique su conexión o los repositorios."
    exit 1
fi
echo "✅ Paquetes pre-requisitos instalados."
echo "---"

# -----------------------------------------------------------------------------
# 2. Añadir el Repositorio Oficial de Waydroid
# -----------------------------------------------------------------------------
# Usamos 'bookworm' para Debian 12/Trixie/Sid, ya que el repo de Waydroid es compatible.
WAYDROID_DISTRO_ARG="bookworm"
echo "➕ 2/5: Añadiendo el repositorio oficial de Waydroid (forzando '$WAYDROID_DISTRO_ARG')..."
if ! curl -s https://repo.waydro.id | bash -s "$WAYDROID_DISTRO_ARG"; then
    echo "❌ Error al añadir el repositorio de Waydroid para '$WAYDROID_DISTRO_ARG'."
    exit 1
fi

apt update
echo "✅ Repositorio de Waydroid añadido y lista de paquetes actualizada."
echo "---"

# -----------------------------------------------------------------------------
# 3. Instalación de Waydroid
# -----------------------------------------------------------------------------
echo "📱 3/5: Instalando Waydroid..."
if ! apt install waydroid -y; then
    echo "❌ Error al instalar el paquete 'waydroid'. Esto podría indicar un problema con el repositorio o la conexión."
    exit 1
fi
echo "✅ Waydroid instalado correctamente."
echo "---"

# -----------------------------------------------------------------------------
# 4. Configuración y Activación del Firewall (UFW)
# -----------------------------------------------------------------------------
echo "🔒 4/5: Configurando reglas del firewall UFW para Waydroid..."

# Permitir tráfico DNS y DHCP
ufw allow 53/udp
ufw allow 53/tcp
ufw allow 67/udp

# Permitir forwarding (crucial para el tráfico entre el host y el contenedor)
ufw default allow FORWARD

echo "✅ Reglas de UFW configuradas."

# Activar UFW
if ! ufw status | grep -q "Status: active"; then
    echo "🔥 Activando UFW. Se forzará la activación sin preguntar."
    ufw --force enable
fi
echo "✅ UFW configurado y activo."
echo "---"

# -----------------------------------------------------------------------------
# 5. Finalización
# -----------------------------------------------------------------------------
echo "🎉 5/5: Instalación de Waydroid completada."
echo ""
echo "❗ IMPORTANTE: Es necesario reiniciar el sistema."
echo "   El nuevo initrd se ha generado y debe cargarse al inicio."
echo "   Recuerde seleccionar Wayland en la pantalla de login."
echo ""
read -r -p "¿Desea reiniciar ahora? (s/n): " REBOOT_CHOICE

if [[ "$REBOOT_CHOICE" =~ ^[Ss]$ ]]; then
    echo "Reiniciando el sistema en 5 segundos..."
    sleep 5
    reboot
else
    echo "Por favor, reinicie su sistema manualmente lo antes posible para completar la instalación."
fi

exit 0
EOF_PAYLOAD_MODIFIED

# 3. Dar permisos de ejecución al instalador final
chmod +x waydroid_installer.run
echo "El instalador 'waydroid_installer.run' con comprobación de compatibilidad ha sido creado."

