#!/bin/bash
# create_waydroid_run.sh
# Genera el archivo ejecutable one-click 'waydroid_installer.run'

set -e

OUTPUT_FILE="waydroid_installer.run"

echo "🛠️ Generando el instalador auto-extraíble: $OUTPUT_FILE (con YAD, Launcher y YAD-SUDO)"

# -----------------------------------------------------------------------------
# 1. Crear el Wrapper de Inicio (con el marcador de payload)
# -----------------------------------------------------------------------------
cat > "$OUTPUT_FILE" << 'EOF_WRAPPER'
#!/bin/bash
# Waydroid Installer - Script auto-extraíble
# -----------------------------------------------------------------------------
set -e

# Marcador que indica dónde empieza el payload (¡NO CAMBIAR ESTA LÍNEA!)
PAYLOAD_LINE=$(awk '/^# --- PAYLOAD START ---$/ {print NR + 1; exit 0; }' "$0")
# Capturamos el usuario real (no root)
WAYDROID_USER=$(logname)

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

echo "WAYDROID_USER=$WAYDROID_USER" > "$TMP_DIR/config.env"

# 4. Ejecutar el payload. Usamos YAD para mostrar el progreso.
if command -v yad &>/dev/null; then
    echo "Abriendo ventana de progreso..."
    
    # Ejecutamos el payload y redirigimos STDOUT a YAD para mostrar el progreso
    # Añadimos --width, --height y --center, y --auto-close
    "$PAYLOAD_SCRIPT" 2>&1 | yad --title="Instalador Waydroid" \
        --text="Iniciando instalación... Por favor, espere." \
        --progress --pulsate --auto-close --auto-kill \
        --width=500 --height=250 --center
    
    # Después de que YAD se cierra (porque el pipe se cerró), imprimimos el mensaje final
    # YAD --auto-close se asegura de que la terminal se cierre cuando el payload termine.

else
    echo "YAD no detectado (se instalará pronto). Continuando en la terminal..."
    "$PAYLOAD_SCRIPT"
fi

# 5. Limpiar el directorio temporal al salir
rm -rf "$TMP_DIR"

exit $?

# --- PAYLOAD START ---
EOF_WRAPPER

# -----------------------------------------------------------------------------
# 2. Adjuntar el Payload de Instalación (El script que hace el trabajo real)
# -----------------------------------------------------------------------------
cat >> "$OUTPUT_FILE" << 'EOF_PAYLOAD_MODIFIED'
#!/bin/bash
# Script de instalación de Waydroid (Payload interno)
# -----------------------------------------------------------------------------
set -e

# Definir la ruta del script auxiliar y del launcher (rutas de root)
HELPER_SCRIPT_PATH="/usr/local/bin/waydroid-gservices-helper.sh"
DESKTOP_FILE_PATH="/usr/share/applications/Waydroid_Gplay_Activator.desktop"
# Obtener el nombre de usuario del wrapper si existe, si no, usar logname
WAYDROID_USER=""
if [ -f "$PWD/config.env" ]; then
    . "$PWD/config.env"
fi
if [ -z "$WAYDROID_USER" ]; then
    WAYDROID_USER=$(logname)
fi

# Función para reportar progreso a YAD
progress_step() {
    local STEP_NUM=$1
    local STEP_TOTAL=$2
    local MESSAGE=$3
    # YAD usa números de 0 a 100
    local PERCENTAGE=$((STEP_NUM * 100 / STEP_TOTAL))
    echo "$PERCENTAGE"
    echo "# $MESSAGE"
}

# La salida de YAD va a STDOUT, el cual está siendo pipeado a YAD --progress
echo "🚀 Iniciando la instalación automatizada de Waydroid..."
progress_step 0 10 "Iniciando..."


# -----------------------------------------------------------------------------
# 0. Verificación de Compatibilidad
# -----------------------------------------------------------------------------
progress_step 1 10 "Verificando la compatibilidad del sistema operativo..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "❌ No se pudo determinar el sistema operativo. Abortando."
    exit 1
fi

if [ "$ID" != "debian" ]; then
    echo "❌ Distribución no compatible. ID: $ID"
    exit 1
fi

REQUIRED_VERSION=12
CURRENT_VERSION=${VERSION_ID%.*}

if [ "$CURRENT_VERSION" -lt "$REQUIRED_VERSION" ]; then
    echo "❌ Versión de Debian no compatible. Versión actual: $CURRENT_VERSION"
    exit 1
fi
progress_step 2 10 "Sistema operativo compatible: Debian $CURRENT_VERSION."


# -----------------------------------------------------------------------------
# 1. Instalación de Pre-requisitos (Añadimos YAD)
# -----------------------------------------------------------------------------
progress_step 3 10 "Instalando paquetes: curl, ca-certificates, ufw, yad..."
apt update
if ! apt install curl ca-certificates ufw yad -y; then
    echo "❌ Error al instalar paquetes base."
    exit 1
fi
progress_step 4 10 "Paquetes pre-requisitos y YAD instalados."


# -----------------------------------------------------------------------------
# 2. Añadir el Repositorio Oficial de Waydroid
# -----------------------------------------------------------------------------
WAYDROID_DISTRO_ARG="bookworm"
progress_step 5 10 "Añadiendo el repositorio oficial de Waydroid..."
if ! curl -s https://repo.waydro.id | bash -s "$WAYDROID_DISTRO_ARG"; then
    echo "❌ Error al añadir el repositorio de Waydroid."
    exit 1
fi
apt update
progress_step 6 10 "Repositorio de Waydroid añadido."


# -----------------------------------------------------------------------------
# 3. Instalación de Waydroid
# -----------------------------------------------------------------------------
progress_step 7 10 "Instalando Waydroid..."
if ! apt install waydroid -y; then
    echo "❌ Error al instalar el paquete 'waydroid'."
    exit 1
fi
progress_step 8 10 "Waydroid instalado correctamente."


# -----------------------------------------------------------------------------
# 4. Configuración y Activación del Firewall (UFW)
# -----------------------------------------------------------------------------
progress_step 8 10 "Configurando firewall UFW..."
ufw allow 53/udp
ufw allow 53/tcp
ufw allow 67/udp
ufw default allow FORWARD

if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
fi
progress_step 9 10 "UFW configurado y activo."


# -----------------------------------------------------------------------------
# 5. Creación del Script Auxiliar de Activación (waydroid-gservices-helper.sh)
# -----------------------------------------------------------------------------
progress_step 9 10 "Creando script auxiliar de activación de Google Play (manejo de SUDO)..."

# NOTA: Usamos EOF para escribir el script auxiliar.
# El script auxiliar ahora maneja la contraseña de sudo con YAD --entry.
cat > "$HELPER_SCRIPT_PATH" << EOF_HELPER
#!/bin/bash
# waydroid-gservices-helper.sh
# Extrae el ID de Android, maneja la contraseña de SUDO, y muestra el diálogo de registro con YAD.

# Pedir la contraseña de sudo con YAD de forma segura
SUDO_PASS=\$(yad --center --title="Waydroid SUDO" --text="Ingrese su contraseña de usuario para acceder a Waydroid ID:" --entry --hide-text --undecorated)

if [ -z "\$SUDO_PASS" ]; then
    yad --center --title="Error" --text="Contraseña no proporcionada. Operación cancelada." --button="Aceptar"
    exit 1
fi

# Intentar obtener el Android ID usando la contraseña con sudo -kS (no guardada)
# Asegúrese de que Waydroid esté iniciado ANTES.
ANDROID_ID=\$(echo "\$SUDO_PASS" | sudo -kS waydroid shell -- sh -c "sqlite3 /data/data/*/*/gservices.db 'select value from main where name = \"android_id\";'" 2>/dev/null | tail -n 1)

if [ -z "\$ANDROID_ID" ]; then
    yad --center --title="Error de Waydroid ID" --text="No se pudo obtener el Android ID.\n\nAsegúrese de que Waydroid se haya iniciado al menos una vez, y que la contraseña sea correcta.\n\nComando fallido: 'sudo waydroid shell...'" --button="Aceptar"
    exit 1
fi

# El texto a mostrar en YAD
DIALOG_TEXT="<b>Paso 1: Obtener Android ID</b>\n\nAndroid ID: <span foreground=\"red\"><b>$ANDROID_ID</b></span>\n\n\n<b>Paso 2: Registrar en Google</b>\n\nUse la cadena de números de arriba para registrar el dispositivo en su Cuenta de Google en el siguiente enlace. Este paso es necesario para activar Google Play Services.\n\n<b><a href=\"https://www.google.com/android/uncertified\">Abrir Registro de Dispositivos Google</a></b>\n\n\nDespués de registrarlo (puede tardar unos minutos), reinicie Waydroid."

# Comando para el botón de reinicio
RESTART_COMMAND="waydroid session stop"

# Mostramos el diálogo de YAD con el ID y el botón de acción
# Usamos width=600 y height=400 para una mejor visualización del texto
yad --center --title="Activación de Google Play Services" \
    --text="\$DIALOG_TEXT" \
    --image="dialog-information" \
    --buttons-layout=center \
    --button="Reiniciar Waydroid!$RESTART_COMMAND" \
    --button="Cerrar:0" \
    --width=600 --height=400

exit 0
EOF_HELPER

chmod +x "$HELPER_SCRIPT_PATH"
progress_step 9 10 "Script auxiliar $HELPER_SCRIPT_PATH creado."


# -----------------------------------------------------------------------------
# 6. Creación del Launcher .desktop
# -----------------------------------------------------------------------------
progress_step 9 10 "Creando lanzador de escritorio para el usuario $WAYDROID_USER..."

# NOTA: El lanzador se crea en /usr/share/applications para que sea accesible para todos los usuarios.
cat > "$DESKTOP_FILE_PATH" << EOF_DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Waydroid GPlay Services Activator
Comment=Obtiene el Android ID y activa Google Play Services en Waydroid (Requiere Waydroid iniciado)
Exec=bash -c "su -c $HELPER_SCRIPT_PATH $WAYDROID_USER"
Exec=$HELPER_SCRIPT_PATH
Icon=android
Terminal=false
Categories=System;
Keywords=Waydroid;Android;Google Play;
EOF_DESKTOP

progress_step 10 10 "Launcher $DESKTOP_FILE_PATH creado."


# -----------------------------------------------------------------------------
# 7. Finalización
# -----------------------------------------------------------------------------
echo "🎉 10/10: Instalación de Waydroid completada."
echo ""
echo "❗ IMPORTANTE: Es necesario reiniciar el sistema."
echo "   Para usar Google Play, ejecute el lanzador 'Waydroid GPlay Services Activator'."
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
chmod +x "$OUTPUT_FILE"

echo "---"
echo "✅ Generación finalizada. El archivo listo para distribuir es: $OUTPUT_FILE"
echo "Para usarlo, ejecute: ./$OUTPUT_FILE (se encargará de todo)."

