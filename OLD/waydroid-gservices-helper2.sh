#!/bin/bash
# waydroid-gservices-helper.sh
# Extrae el ID de Android, maneja la contraseña de SUDO, y muestra el diálogo de registro con YAD.

# Pedir la contraseña de sudo con YAD de forma segura
SUDO_PASS=$(yad --center --title="Waydroid SUDO" --text="Ingrese su contraseña de usuario para acceder a Waydroid ID:\n\n(Asegúrese de que Waydroid se haya iniciado al menos una vez)" --entry --hide-text --undecorated)
#"
if [ -z "$SUDO_PASS" ]; then
    yad --center --title="Error" --text="Contraseña no proporcionada. Operación cancelada." --button="Aceptar"
    exit 1
fi

# Intentar obtener el Android ID usando la contraseña con sudo -kS (no guardada)
ANDROID_ID=$(echo "$SUDO_PASS" | sudo -kS waydroid shell -- sh -c "sqlite3 /data/data/*/*/gservices.db 'select value from main where name = \"android_id\";'" 2>/dev/null | tail -n 1)

if [ -z "$ANDROID_ID" ]; then
    yad --center --title="Error de Waydroid ID" --text="No se pudo obtener el Android ID.\n\nAsegúrese de que Waydroid se haya iniciado al menos una vez, y que la contraseña sea correcta.\n\nComando fallido: 'sudo waydroid shell...'" --button="Aceptar"
    exit 1
fi


# --- Secciones de Texto para el Diálogo YAD --form ---

# 1. Texto introductorio
INTRO_TEXT="<b>Paso 1: Obtener Android ID</b>\n\nAndroid ID se ha extraído correctamente."

# 2. Texto de registro y reinicio (Incluye el enlace)
# Usamos un campo de texto simple sin formato HTML en YAD --form para mejor compatibilidad.
REGISTRATION_TEXT="Paso 2: Registrar en Google\n\nUse la cadena de números de arriba para registrar el dispositivo en su Cuenta de Google en el siguiente enlace. Este paso es necesario para activar Google Play Services y poder usar el PlayStore.\n\nDespués de registrarlo (puede tardar unos minutos), reinicie Waydroid."

LINK_BUTTON="<a href=\"https://www.google.com/android/uncertified\">Abrir Registro de Dispositivos Google</a>"

# Comando para el botón de reinicio
RESTART_COMMAND="waydroid session stop"

# Mostramos el diálogo de YAD usando --form
yad --center --title="Activación de Google Play Services" \
    --image="dialog-information" \
    --buttons-layout=center \
    --button="Reiniciar Waydroid!$RESTART_COMMAND" \
    --button="Cerrar:0" \
    --width=650 --height=450 \
    --text-align=center \
    --form \
    --field="INTRO:TXT" "${INTRO_TEXT}" \
    --field="Android ID (Copiar):RO" "${ANDROID_ID}" \
    --field="REGISTRATION_INFO:TXT" "${REGISTRATION_TEXT}" \
    --field="LINK:LBL" "${LINK_BUTTON}"
    
exit 0
