#!/data/data/com.termux/files/usr/bin/bash

# Script de descarga con opciones
read -p "Pega el URL de YouTube: " URL

echo ""
echo "Elige el formato de descarga:"
echo "1) Convertir a FLAC (máxima calidad de audio)"
echo "2) Mantener formato original (más ligero, igual calidad)"
echo ""
read -p "Opción [1/2]: " OPCION

if [ "$OPCION" == "1" ]; then
    yt-dlp -f bestaudio -x --audio-format flac \
    --embed-thumbnail \
    --add-metadata \
    --metadata-from-title "%(artist)s - %(title)s" \
    --yes-playlist \
    -o "/storage/emulated/0/Music/%(album)s/%(track_number)s - %(title)s.%(ext)s" \
    "$URL"

elif [ "$OPCION" == "2" ]; then
    yt-dlp -f bestaudio \
    --embed-thumbnail \
    --add-metadata \
    --metadata-from-title "%(artist)s - %(title)s" \
    --yes-playlist \
    -o "/storage/emulated/0/Music/%(album)s/%(track_number)s - %(title)s.%(ext)s" \
    "$URL"

else
    echo "Opción no válida. Cancela la descarga."
fi