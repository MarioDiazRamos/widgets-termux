#!/data/data/com.termux/files/usr/bin/bash
source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
ensure_storage
ensure_cmd ffmpeg ffmpeg
command -v yt-dlp >/dev/null 2>&1 || python -m pip install --user yt-dlp >/dev/null 2>&1

CARPETA_AUDIOS="/storage/emulated/0/Download"
CARPETA_VIDEOS="/storage/emulated/0/Movies/Finales"
CARPETA_DESTINO="/storage/emulated/0/Movies/Finales"
GANANCIA_FRAGMENTO="1.0"
mkdir -p "$CARPETA_DESTINO"

seleccionar_audio() {
    local tipo="$1"
    echo "\nBuscando archivos de audio en: $CARPETA_AUDIOS\n"
    if [ "$tipo" = "flac" ]; then
        mapfile -t archivos < <(find "$CARPETA_AUDIOS" -maxdepth 1 -type f \( -iname "*.m4a" -o -iname "*.flac" \) | sort)
    else
        mapfile -t archivos < <(find "$CARPETA_AUDIOS" -maxdepth 1 -type f -iname "*.m4a" | sort)
    fi
    [ ${#archivos[@]} -eq 0 ] && echo "No se encontraron archivos de audio compatibles." && return 1
    for i in "${!archivos[@]}"; do echo "$((i+1))) $(basename "${archivos[$i]}")"; done
    echo
    read -p "Elige el número del archivo de audio: " seleccion
    [[ ! "$seleccion" =~ ^[0-9]+$ ]] || [ "$seleccion" -lt 1 ] || [ "$seleccion" -gt "${#archivos[@]}" ] && echo "Selección no válida." && return 1
    ARCHIVO_AUDIO="${archivos[$((seleccion-1))]}"
    NOMBRE_AUDIO=$(basename "$ARCHIVO_AUDIO" | sed 's/\.[^.]*$//')
    echo "\nAudio seleccionado: $NOMBRE_AUDIO"
    NOMBRE_AUDIO=$(basename "$ARCHIVO_AUDIO" | sed 's/\.[^.]*$//')
    echo "\nAudio seleccionado: $NOMBRE_AUDIO"
    echo "🎶 Audio seleccionado: $M4A_NAME"
    echo "\nBuscando videos MP4 en: $CARPETA_VIDEOS\n"
    mapfile -t videos < <(find "$CARPETA_VIDEOS" -maxdepth 1 -type f -iname "*.mp4" | sort)
    [ ${#videos[@]} -eq 0 ] && echo "No se encontraron videos .mp4." && return 1
    for i in "${!videos[@]}"; do echo "$((i+1))) $(basename "${videos[$i]}")"; done
    echo
    read -p "Elige el número del video MP4: " seleccion
    [[ ! "$seleccion" =~ ^[0-9]+$ ]] || [ "$seleccion" -lt 1 ] || [ "$seleccion" -gt "${#videos[@]}" ] && echo "Selección no válida." && return 1
    ARCHIVO_VIDEO="${videos[$((seleccion-1))]}"
    echo "\nVideo seleccionado: $(basename "$ARCHIVO_VIDEO")"
        return 1
    fi
    ARCHIVO_VIDEO="${VIDEOS[$((SELECCION_VIDEO-1))]}"
    echo "\nVideo seleccionado: $(basename "$ARCHIVO_VIDEO")"
}
    VIDEO_TEMP="$CARPETA_DESTINO/video_temp.mp4"
    echo "Descargando video..."
    yt-dlp -f "bestvideo+bestaudio[ext=m4a]/best" --merge-output-format mp4 -o "$VIDEO_TEMP" "$url"
    [ ! -f "$VIDEO_TEMP" ] && echo "Error al descargar el video." && return
    echo "\nOpciones de sincronización:"
    echo "1) Iniciar ambos al mismo tiempo"
    echo "2) Retrasar video X segundos"
    echo "3) Retrasar audio X segundos"
    read -p "Opción (1-3): " opcion
    retardo=0
    case "$opcion" in
        2) read -p "Segundos para retrasar el video: " retardo ;;
        3) read -p "Segundos para retrasar el audio: " retardo ;;
    esac
    FINAL_OUTPUT="$CARPETA_DESTINO/${NOMBRE_AUDIO}_final.mp4"
    echo "\nProcesando y uniendo video y audio..."
    case "$opcion" in
        1) ffmpeg -y -i "$VIDEO_TEMP" -i "$ARCHIVO_AUDIO" -map 0:v:0 -map 1:a:0 -c:v copy -c:a copy -shortest "$FINAL_OUTPUT" ;;
        2) ffmpeg -y -ss "$retardo" -i "$VIDEO_TEMP" -i "$ARCHIVO_AUDIO" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 192k -shortest "$FINAL_OUTPUT" ;;
        3) ffmpeg -y -i "$VIDEO_TEMP" -itsoffset "$retardo" -i "$ARCHIVO_AUDIO" -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 192k -shortest "$FINAL_OUTPUT" ;;
    esac
    rm -f "$VIDEO_TEMP"
    echo "\nVideo final creado: $FINAL_OUTPUT"
                -map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 192k -shortest "$FINAL_OUTPUT" ;;
    esac
    rm -f "$VIDEO_TEMP"
    echo "\nVideo final creado:"
    echo "   $FINAL_OUTPUT"
    echo "\nIngresa los intervalos (ejemplo: 1:02-1:04,2:03-2:06)"
    echo "Formato: minuto:segundo (1:03) o segundos (63)"
    read -p "Intervalos: " intervalos
    filter=""; IFS=',' read -ra segmentos <<< "$intervalos"; n=0
    for seg in "${segmentos[@]}"; do
        seg="$(echo "$seg" | sed 's/^ *//;s/ *$//')"
        ini="${seg%-*}"; fin="${seg#*-}"
        ini_s=$(awk -F: '{if(NF==2) printf("%.3f", $1*60+$2); else printf("%.3f", $1)}' <<< "$ini")
        fin_s=$(awk -F: '{if(NF==2) printf("%.3f", $1*60+$2); else printf("%.3f", $1)}' <<< "$fin")
        [[ ! "$ini_s" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [[ ! "$fin_s" =~ ^[0-9]+(\.[0-9]+)?$ ]] && echo "Intervalo inválido: $seg" && continue
        if ! awk -v s="$ini_s" -v e="$fin_s" 'BEGIN{if(e>s) exit 0; else exit 1}'; then echo "Intervalo inválido: $seg"; continue; fi
        ini_ms=$(awk -v s="$ini_s" 'BEGIN{printf("%d", s*1000)}')
        filter+="[1:a]atrim=start=${ini_s}:end=${fin_s},asetpts=PTS-STARTPTS,volume=${GANANCIA_FRAGMENTO},adelay=${ini_ms}|${ini_ms}[s${n}];"
        n=$((n+1))
    done
    [ "$n" -eq 0 ] && echo "No hay intervalos válidos." && return
    mix="[0:a]"; for i in $(seq 0 $((n-1))); do mix+="[s${i}]"; done
    total=$((n+1))
    filter+="${mix}amix=inputs=${total}:duration=first:dropout_transition=0[aout]"
    FINAL_OUTPUT="$CARPETA_DESTINO/${NOMBRE_AUDIO}_transpuesto.mp4"
    echo "\nProcesando transposición..."
    ffmpeg -y -i "$ARCHIVO_VIDEO" -i "$ARCHIVO_AUDIO" -filter_complex "$filter" -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 192k -shortest "$FINAL_OUTPUT"
    [ $? -ne 0 ] && echo "Error durante ffmpeg." && return
    echo "\nAudio transpuesto sobre el video: $FINAL_OUTPUT"
        "$FINAL_OUTPUT"
    if [ $? -ne 0 ]; then
        echo "Ocurrió un error durante ffmpeg."
        return
    fi
    echo "\nAudio transpuesto sobre el video (solo en los intervalos):"
    echo "   $FINAL_OUTPUT"
}

# --- MENÚ PRINCIPAL ---
while true; do
    clear
    read -p "Elige una opción: " opcion
    case "$opcion" in
        1) modo_karaoke ;;
        2) modo_transponer ;;
        3) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción inválida."; sleep 1 ;;
    esac
    echo
    read -p "Presiona Enter para volver al menú..." _
    case "$OPCION_MENU" in
        1) modo_karaoke ;;
        2) modo_transponer ;;
        3) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción inválida."; sleep 1 ;;
    esac
    echo ""
    read -p "Presiona Enter para volver al menú..." temp
done
