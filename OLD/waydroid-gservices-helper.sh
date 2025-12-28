#!/bin/bash
# waydroid-gservices-helper.sh
# Extrae el ID de Android, maneja la contraseña de SUDO, y muestra el diálogo de registro con YAD.

# Pedir la contraseña de sudo con YAD de forma segura
SUDO_PASS=$(yad --center --title="Waydroid SUDO" --text="Ingrese su contraseña de usuario para acceder a Waydroid ID:" --entry --hide-text --undecorated)

if [ -z "$SUDO_PASS" ]; then
    yad --center --title="Error" --text="Contraseña no proporcionada. Operación cancelada." --button="Aceptar"
    exit 1
fi


# Intentar obtener el Android ID usando la contraseña con sudo -kS (no guardada)
# Asegúrese de que Waydroid esté iniciado ANTES.
ANDROID_ID=$(echo "$SUDO_PASS" | sudo -kS waydroid shell -- sh -c "sqlite3 /data/data/*/*/gservices.db 'select value from main where name = \"android_id\";'" 2>/dev/null | tail -n 1)

if [ -z "$ANDROID_ID" ]; then
    yad --center --title="Error de Waydroid ID" --text="No se pudo obtener el Android ID.\n\nAsegúrese de que Waydroid se haya iniciado al menos una vez, y que la contraseña sea correcta.\n\nComando fallido: 'sudo waydroid shell...'" --button="Aceptar"
    exit 1
fi

# El texto a mostrar en YAD
DIALOG_TEXT="<b>Paso 1: Obtener Android ID</b>\n\nAndroid ID: <span foreground=\"red\"><b>$ANDROID_ID</b></span>\n\n\n<b>Paso 2: Registrar en Google insertando el Android ID en el campo Google Services Framework Android ID</b>\n\nUse la cadena de números de arriba para registrar el dispositivo en su Cuenta de Google en el siguiente enlace. Este paso es necesario para activar Google Play Services y poder usar el PlayStore.\n\n<b><a href=\"https://www.google.com/android/uncertified\">Abrir Registro de Dispositivos Google</a></b>\n\n\nDespués de registrarlo (puede tardar unos minutos), reinicie Waydroid."

# Comando para el botón de reinicio
RESTART_COMMAND="waydroid session stop"

# Mostramos el diálogo de YAD con el ID y el botón de acción
# Usamos width=600 y height=400 para una mejor visualización del texto
yad --center --title="Activación de Google Play Services"     --text="$DIALOG_TEXT"     --image="dialog-information"     --buttons-layout=center     --button="Reiniciar Waydroid!"     --button="Cerrar:0"     --width=600 --height=400

exit 0

