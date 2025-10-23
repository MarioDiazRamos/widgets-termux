#!/data/data/com.termux/files/usr/bin/bash
# Cambiar velocidad de un video sin bc
source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
ensure_cmd ffmpeg ffmpeg


solicitar_dato() {
    local mensaje="$1"
    local variable
    read -p "$mensaje" variable
    echo "$variable"
}

VIDEO_ENTRADA=$(solicitar_dato "Ruta del video: ")
PORCENTAJE_VELOCIDAD=$(solicitar_dato "Velocidad en % (ej. 93 para 93%): ")


if [ ! -f "$VIDEO_ENTRADA" ]; then
    echo "El archivo no existe."
    exit 1
fi


calcular_decimal() {
    awk "BEGIN {print $1/100}"
}

calcular_setpts() {
    awk "BEGIN {print 1/$1}"
}

VELOCIDAD_DECIMAL=$(echo "$PORCENTAJE_VELOCIDAD" | calcular_decimal)
VALOR_SETPTS=$(echo "$VELOCIDAD_DECIMAL" | calcular_setpts)


NOMBRE_DIRECTORIO=$(dirname "$VIDEO_ENTRADA")
NOMBRE_BASE=$(basename "$VIDEO_ENTRADA")
SALIDA="$NOMBRE_DIRECTORIO/${NOMBRE_BASE%.*}_vel${PORCENTAJE_VELOCIDAD}.mp4"


echo "Ajustando velocidad al ${PORCENTAJE_VELOCIDAD}%..."

if ffmpeg -y -i "$VIDEO_ENTRADA" \
    -filter_complex "[0:v]setpts=${VALOR_SETPTS}*PTS[v];[0:a]atempo=${VELOCIDAD_DECIMAL}[a]" \
    -map "[v]" -map "[a]" \
    "$SALIDA"; then
    echo "Video creado: $SALIDA"
else
    echo "Error al ajustar la velocidad."
fi

