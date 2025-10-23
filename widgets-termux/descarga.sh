
#!/data/data/com.termux/files/usr/bin/bash

solicitar_dato() {
  local mensaje="$1"
  local variable
  read -p "$mensaje" variable
  echo "$variable"
}


animar_barra() {
  local ancho=30
  local paso=0
  while :; do
    local barra=""
    for ((i=0; i<$ancho; i++)); do
      if (( i < paso )); then
        barra+="="
      elif (( i == paso )); then
        barra+=">"
      else
        barra+=" "
      fi
    done
    printf "\r[%s] Procesando..." "$barra"
    paso=$(( (paso + 1) % ancho ))
    sleep 0.1
  done
}


descargar_audio() {
  local comando="$1"
  echo "Ejecutando: $comando" >> "$ARCHIVO_LOG"
  animar_barra &
  local pid_barra=$!
  eval "$comando" >> "$ARCHIVO_LOG" 2>&1
  kill $pid_barra 2>/dev/null
  wait $pid_barra 2>/dev/null
  printf "\r%-60s\n" ""
  return $?
}

descargar_fallback() {
  echo "Intentando formato alternativo..."
  local mejor_linea mejor_id info args_comunes
  mejor_linea=$(yt-dlp -F "$URL_YOUTUBE" 2>/dev/null | grep "audio only" | sort -k3 -nr | head -n 1)
  mejor_id=$(echo "$mejor_linea" | awk '{print $1}')
  info=$(echo "$mejor_linea" | awk '{$1=""; print $0}')
  args_comunes="--embed-thumbnail --add-metadata --metadata-from-title '%(artist)s - %(title)s' --yes-playlist -o '$CARPETA_DESTINO/%(artist,NA=Varios)s - %(title)s.%(ext)s' '$URL_YOUTUBE'"
  if [ -n "$mejor_id" ]; then
    echo "Usando formato alternativo: ID: $mejor_id | Info:$info" | tee -a "$ARCHIVO_LOG"
    if [ "$OPCION" = "1" ]; then
      yt-dlp -f "$mejor_id" -x --audio-format flac $args_comunes >> "$ARCHIVO_LOG" 2>&1
    else
      yt-dlp -f "$mejor_id" $args_comunes >> "$ARCHIVO_LOG" 2>&1
    fi
  else
    echo "No se encontró ningún formato alternativo." | tee -a "$ARCHIVO_LOG"
  fi
}

URL_YOUTUBE=$(solicitar_dato "Pega el URL de YouTube: ")
echo
echo "Elige el formato de descarga:"
echo "1) Convertir a FLAC (máxima calidad de audio)"
echo "2) Mantener formato original (más ligero, igual calidad)"
echo
echo "3) Actualizar librerías (ffmpeg y yt-dlp)"
OPCION=$(solicitar_dato "Opción [1/2/3]: ")

CARPETA_DESTINO="/storage/emulated/0/Music/Descargas"
mkdir -p "$CARPETA_DESTINO"
ARCHIVO_LOG="$CARPETA_DESTINO/descarga.log"
> "$ARCHIVO_LOG"

args_comunes="--embed-thumbnail --add-metadata --metadata-from-title '%(artist)s - %(title)s' --yes-playlist -o '$CARPETA_DESTINO/%(artist,NA=Varios)s - %(title)s.%(ext)s' '$URL_YOUTUBE'"
if [ "$OPCION" = "1" ]; then
  descargar_audio "yt-dlp -f bestaudio -x --audio-format flac $args_comunes" || descargar_fallback
elif [ "$OPCION" = "2" ]; then
  descargar_audio "yt-dlp -f bestaudio $args_comunes" || descargar_fallback
elif [ "$OPCION" = "3" ]; then
  echo "Actualizando librerías ffmpeg y yt-dlp..."
  pkg update -y && pkg upgrade -y
  pkg install -y ffmpeg
  pip install --upgrade yt-dlp
  echo "Librerías actualizadas. Reinicia el script para intentar la descarga nuevamente."
  exit 0
else
  echo "Opción no válida. Cancela la descarga."
  exit 1
fi

echo
echo "Proceso terminado. Archivos descargados en: $CARPETA_DESTINO"