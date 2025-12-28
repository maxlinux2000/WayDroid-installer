# 🚀 Instalador One-Click de Waydroid con Google Play Services para Debian 12

## 📝 Descripción del Proyecto

Este proyecto proporciona un instalador auto-extraíble de un solo clic (`.run`) diseñado para simplificar la configuración completa de **Waydroid** en sistemas Debian 12 (Bookworm) y sus derivadas.

El objetivo es automatizar los pasos de instalación, configuración del *firewall* (UFW) y, lo más importante, facilitar la activación de **Google Play Services** (Play Store) mediante el proceso de registro del Android ID.

### Compatibilidad y Arquitectura

* **Sistema Operativo:** Debian 12 (Bookworm) y derivadas (ej. Ubuntu, Mint).
* **Arquitectura Soportada:** **AMD64** (procesadores Intel/AMD).
* **⚠️ Aviso de Compatibilidad ARM64:** Esta versión del script **no ha sido probada y no se garantiza que funcione** correctamente en arquitecturas **ARM64** (ej. Raspberry Pi 5), debido a variaciones en la instalación del *kernel* de `binder_linux` y `anbox-modules-dkms`.

## 📦 Componentes Generados

El instalador genera automáticamente los siguientes componentes clave en el sistema:

1.  **Waydroid GPlay Services Activator:** Un lanzador que ejecuta un *script* en terminal para obtener el Android ID necesario para el registro.
2.  **Waydroid Restart:** Un lanzador para detener y reiniciar la sesión de Waydroid de forma segura (`stop` -> `sleep 3` -> `start`).

## ⚙️ Guía de Uso del Instalador

### Paso 1: Obtener y Ejecutar el Instalador

1.  Descargue el archivo `waydroid_installer_YYYY-MM-DD.run` (generado por `create_waydroid_run.sh`).
2.  Dele permisos de ejecución y ejecútelo desde la terminal (se elevará automáticamente a `sudo`):

    ```bash
    chmod +x waydroid_installer_*.run
    ./waydroid_installer_*.run
    ```
3.  Siga las instrucciones en la terminal. El *script* instalará todas las dependencias, Waydroid, configurará UFW y, al finalizar, le preguntará si desea **reiniciar** el sistema. **Se recomienda reiniciar.**

### Paso 2: Obtener y Registrar el Android ID

Este es el paso crucial para activar Google Play Store.

1.  **Inicie Waydroid:** Busque en su menú de aplicaciones "Waydroid" y ejecútalo (**Waydroid show-full-ui**) una vez para que se cree la base de datos necesaria para el Android ID. Luego ciérrelo.
2.  **Ejecute el Lanzador Activador:** Busque en el menú de aplicaciones:
    * **`Waydroid GPlay Services Activator`**
3.  El lanzador abrirá una terminal que le pedirá su contraseña de `sudo`.
4.  La terminal mostrará la **Android ID** de 16 dígitos.
5.  Siga las instrucciones que aparecen en la terminal:
    * Copie la **Android ID**.
    * Abra el enlace de registro de Google: `https://www.google.com/android/uncertified`
    * Pegue la ID en el campo **Google Services Framework Android ID** y pulse **'Register'**.

### Paso 3: Reiniciar la Sesión de Waydroid

Después de registrar la ID en el sitio web de Google, espere unos minutos (a veces 1-2 minutos) para que el registro se propague. Luego, debe reiniciar la sesión de Waydroid.

1.  Busque en el menú de aplicaciones:
    * **`Waydroid Restart`**
2.  Este lanzador detendrá la sesión de Waydroid, esperará 3 segundos y la volverá a iniciar (`waydroid session stop` -> `waydroid session start`).

Una vez completado, inicie Waydroid de nuevo. Google Play Store debería estar disponible y funcionando correctamente.

## 💻 Bloques de Código de Referencia

Aquí están los *scripts* principales para referencia y mantenimiento.

### `create_waydroid_run.sh`

```bash
#!/bin/bash
# create_waydroid_run.sh
# Genera el archivo ejecutable one-click 'waydroid_installer.run' (SOLO TERMINAL)

DATE=$(date '+%Y-%m-%d')

set -e

OUTPUT_FILE="waydroid_installer_$DATE.run"

echo "🛠️ Generando el instalador auto-extraíble: $OUTPUT_FILE (SOLO TERMINAL y Launcher de Reinicio)"

# -----------------------------------------------------------------------------
# 1. Crear el Wrapper de Inicio
# -----------------------------------------------------------------------------
cat > "$OUTPUT_FILE" << 'EOF_WRAPPER'
#!/bin/bash
# Waydroid Installer - Script auto-extraíble
# -----------------------------------------------------------------------------
set -e

# Marcador que indica dónde empieza el payload (¡NO CAMBIAR ESTA LÍNEA!)
PAYLOAD_LINE=$(awk '/^# --- PAYLOAD START ---$/ {print NR + 1; exit 0; }' "$0")
WAYDROID_USER=$(logname)

# Comprobar si se está ejecutando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "🚨 Este script debe ejecutarse con permisos de root (sudo)."
    echo "Pediremos sudo para continuar."
    
    # Intentar re-ejecutar el script con sudo
    exec sudo "$0" "$@"
    
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

# Crear archivo de configuración simple para pasar el usuario
echo "WAYDROID_USER=$WAYDROID_USER" > "$TMP_DIR/config.env"

# 4. Ejecutar el payload en la terminal (sin YAD)
"$PAYLOAD_SCRIPT"

# 5. Limpiar el directorio temporal al salir
rm -rf "$TMP_DIR"

exit $?

# --- PAYLOAD START ---
EOF_WRAPPER

# -----------------------------------------------------------------------------
# 2. Adjuntar el Payload de Instalación (SOLO TERMINAL)
# -----------------------------------------------------------------------------
cat >> "$OUTPUT_FILE" << 'EOF_PAYLOAD_MODIFIED'
#!/bin/bash
# Script de instalación de Waydroid (Payload interno - SOLO TERMINAL)
# -----------------------------------------------------------------------------
set -e

HELPER_SCRIPT_PATH="/usr/local/bin/waydroid-gservices-helper.sh"
RESTART_SCRIPT_PATH="/usr/local/bin/waydroid-restart.sh"
DESKTOP_ACTIVATOR_PATH="/usr/share/applications/Waydroid_Gplay_Activator.desktop"
DESKTOP_RESTART_PATH="/usr/share/applications/Waydroid_Restart.desktop"

# Obtener el nombre de usuario del wrapper
WAYDROID_USER=""
if [ -f "$PWD/config.env" ]; then
    . "$PWD/config.env"
fi
if [ -z "$WAYDROID_USER" ]; then
    WAYDROID_USER=$(logname)
fi

echo "🚀 Iniciando la instalación automatizada de Waydroid..."
echo "---"

# -----------------------------------------------------------------------------
# 0. Verificación de Compatibilidad
# -----------------------------------------------------------------------------
echo "[0/7] Verificando la compatibilidad del sistema operativo..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "❌ Error: No se pudo determinar el sistema operativo. Abortando."
    exit 1
fi

if [ "$ID" != "debian" ]; then
    echo "❌ Error: Distribución no compatible. Este instalador es para Debian (versión 12 o superior). ID: $ID"
    exit 1
fi

REQUIRED_VERSION=12
CURRENT_VERSION=${VERSION_ID%.*}

if [ "$CURRENT_VERSION" -lt "$REQUIRED_VERSION" ]; then
    echo "❌ Error: Versión de Debian no compatible. Versión mínima requerida: Debian $REQUIRED_VERSION. Actual: $CURRENT_VERSION"
    exit 1
fi
echo "✅ Sistema operativo compatible: Debian $CURRENT_VERSION."
echo "---"


# -----------------------------------------------------------------------------
# 1. Instalación de Pre-requisitos
# -----------------------------------------------------------------------------
echo "[1/7] Instalando paquetes pre-requisitos: curl, ca-certificates, ufw..."
apt update
if ! apt install curl ca-certificates ufw -y; then
    echo "❌ Error al instalar paquetes base."
    exit 1
fi
echo "✅ Paquetes pre-requisitos instalados."
echo "---"


# -----------------------------------------------------------------------------
# 2. Añadir el Repositorio Oficial de Waydroid
# -----------------------------------------------------------------------------
WAYDROID_DISTRO_ARG="bookworm"
echo "[2/7] Añadiendo el repositorio oficial de Waydroid (forzando '$WAYDROID_DISTRO_ARG')..."
if ! curl -s [https://repo.waydro.id](https://repo.waydro.id) | bash -s "$WAYDROID_DISTRO_ARG"; then
    echo "❌ Error al añadir el repositorio de Waydroid."
    exit 1
fi
apt update
echo "✅ Repositorio de Waydroid añadido."
echo "---"


# -----------------------------------------------------------------------------
# 3. Instalación de Waydroid
# -----------------------------------------------------------------------------
echo "[3/7] Instalando Waydroid..."
if ! apt install waydroid -y; then
    echo "❌ Error al instalar el paquete 'waydroid'."
    exit 1
fi
echo "✅ Waydroid instalado correctamente."
echo "---"


# -----------------------------------------------------------------------------
# 3.1 Instalación de python3-pyclipper para que funcione el copy/paste
#     entre waydroid y linux
# -----------------------------------------------------------------------------

apt install -t python3-pyclipper

# -----------------------------------------------------------------------------
# 4. Configuración y Activación del Firewall (UFW)
# -----------------------------------------------------------------------------
echo "[4/7] Configurando firewall UFW..."
ufw allow 53/udp
ufw allow 53/tcp
ufw allow 67/udp
ufw default allow FORWARD

# AÑADIR REGLA PARA ESCRITORIO REMOTO (RDP - Puerto 3389)
ufw allow 3389/tcp

if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
fi
echo "✅ UFW configurado y activo."
echo "---"


# -----------------------------------------------------------------------------
# 5. Creación del Script Auxiliar de Activación (waydroid-gservices-helper.sh)
# -----------------------------------------------------------------------------
echo "[5/7] Creando script auxiliar de activación de Google Play..."

# INTEGRACIÓN EXACTA del script proporcionado
cat > "$HELPER_SCRIPT_PATH" << 'EOF_HELPER'
#!/bin/bash
# waydroid-gservices-helper.sh (Terminal Version)
# Extrae el ID de Android y muestra las instrucciones.
clear
echo ""
echo "======================================================================"
echo "          Activación de Google Play Services para Waydroid"
echo "======================================================================"
echo "❗ IMPORTANTE: Antes de continuar, inicie Waydroid al menos una vez:"
echo "              Escriba 'waydroid show-full-ui' y espere a que cargue."
echo "              Luego ciérrelo antes de continuar."
echo "----------------------------------------------------------------------"
echo "Se requiere su contraseña de usuario para acceder a la ID de Android (sudo)."
read -r -s -p "Contraseña de usuario: " SUDO_PASS
echo ""

# Intentar obtener el Android ID usando la contraseña con sudo -kS (no guardada)
ANDROID_ID=$(echo "$SUDO_PASS" | sudo -kS waydroid shell -- sh -c "sqlite3 /data/data/*/*/gservices.db 'select value from main where name = \"android_id\";'" 2>/dev/null | tail -n 1)
echo ANDROID_ID=$ANDROID_ID
# Limpiar la variable de contraseña
SUDO_PASS=""

# Validar la salida: buscamos un número de 16 dígitos hexadecimales.
if [ -z "$ANDROID_ID" ]; then
    echo "❌ ERROR CRÍTICO: No se pudo obtener el Android ID (debe ser un número de 16 dígitos)."
    echo "   Causas: Waydroid no iniciado, contraseña incorrecta, o base de datos no creada."
    echo "   Por favor, inicie Waydroid, inténtelo de nuevo."
    echo "----------------------------------------------------------------------"
    exit 1
fi

echo ""
echo "✅ ID DE ANDROID EXTRAÍDA CORRECTAMENTE:"
echo "----------------------------------------------------------------------"
echo "Android ID: $ANDROID_ID"
echo "----------------------------------------------------------------------"
echo "PASO 2: REGISTRO DE GOOGLE PLAY SERVICES"
echo "----------------------------------------------------------------------"
echo "a. Copia la ID de Android que aparece arriba."
echo "b. Abre el siguiente enlace en tu navegador:"
echo "		[https://www.google.com/android/uncertified](https://www.google.com/android/uncertified)"
echo "c. Pega la ID de Android en el campo de 'Google Services Framework Android ID'."
echo "d. Presiona 'Register'."
echo "----------------------------------------------------------------------"
echo "PASO 3: REINICIAR WAYDROID"
echo "----------------------------------------------------------------------"
echo "Después de registrar la ID y esperar unos minutos, usa el lanzador 'Waydroid Restart'."
echo "Reinicia seleccionando en las Apps Waydroid Restart"
echo "----------------------------------------------------------------------"
echo ""
read -r -p "Presiona [Enter] para finalizar la visualización de este mensaje."
exit 0
EOF_HELPER

chmod +x "$HELPER_SCRIPT_PATH"
echo "✅ Script auxiliar $HELPER_SCRIPT_PATH creado."
echo "---"


# -----------------------------------------------------------------------------
# 6. Creación del Script de Reinicio (waydroid-restart.sh)
# -----------------------------------------------------------------------------
echo "[6/7] Creando script de reinicio rápido de Waydroid..."

cat > "$RESTART_SCRIPT_PATH" << 'EOF_RESTART'
#!/bin/bash
# waydroid-restart.sh
# Detiene la sesión, espera y la reinicia.

echo "======================================================================"
echo "                Reiniciando Waydroid (Stop -> Start)"
echo "======================================================================"

# Detener la sesión
echo "1. Deteniendo sesión de Waydroid..."
waydroid session stop

# Esperar 3 segundos
echo "2. Esperando 3 segundos..."
sleep 3

# Iniciar la sesión
echo "3. Iniciando nueva sesión de Waydroid..."
waydroid session start

echo "✅ Sesión de Waydroid reiniciada. Cierre esta terminal y ejecute Waydroid."
read -r -p "Presione [Enter] para cerrar."
EOF_RESTART

chmod +x "$RESTART_SCRIPT_PATH"
echo "✅ Script de reinicio $RESTART_SCRIPT_PATH creado."
echo "---"


# -----------------------------------------------------------------------------
# 7. Creación de Launchers (.desktop)
# -----------------------------------------------------------------------------
echo "[7/7] Creando lanzadores .desktop..."

# Launcher para el Activador de Google Play (Terminal)
cat > "$DESKTOP_ACTIVATOR_PATH" << EOF_ACTIVATOR
[Desktop Entry]
Version=1.0
Type=Application
Name=Waydroid GPlay Services Activator
Comment=Obtiene el Android ID para activar Google Play Services (Requiere Terminal)
Exec=x-terminal-emulator -e $HELPER_SCRIPT_PATH
Icon=android
Terminal=false
Categories=System;
Keywords=Waydroid;Android;Google Play;
EOF_ACTIVATOR
echo "   -> Launcher: $DESKTOP_ACTIVATOR_PATH creado."


# Launcher para el Reinicio Rápido
cat > "$DESKTOP_RESTART_PATH" << EOF_RESTART_LAUNCHER
[Desktop Entry]
Version=1.0
Type=Application
Name=Waydroid Restart
Comment=Detiene, espera e inicia la sesión de Waydroid (Útil después de activar Google Play)
Exec=x-terminal-emulator -e $RESTART_SCRIPT_PATH
Icon=android
Terminal=false
Categories=System;
Keywords=Waydroid;Android;Reiniciar;
EOF_RESTART_LAUNCHER
echo "   -> Launcher: $DESKTOP_RESTART_PATH creado."
echo "✅ Lanzadores .desktop creados."
echo "---"


# -----------------------------------------------------------------------------
# 8. Finalización
# -----------------------------------------------------------------------------
echo "🎉 [FINALIZADO] Instalación de Waydroid completada."
echo ""
echo "❗ IMPORTANTE: Es necesario reiniciar el sistema."
echo "   Para la activación final de Google Play, use los lanzadores después de reiniciar."
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
echo "Para usarlo, ejecute: ./$OUTPUT_FILE (se encargará de todo en la terminal)."
