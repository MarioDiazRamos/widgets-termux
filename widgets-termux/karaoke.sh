#!/data/data/com.termux/files/usr/bin/bash

# Wrapper para proyecto Karaoke (delegación al launcher del proyecto)

# Dependencias mínimas y acceso a almacenamiento
if [ -f "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
fi

ensure_storage 2>/dev/null || true
ensure_cmd python python 2>/dev/null || true
ensure_cmd ffmpeg ffmpeg 2>/dev/null || true
# yt-dlp es útil para descargas dentro del proyecto
command -v yt-dlp >/dev/null 2>&1 || python -m pip install --user yt-dlp >/dev/null 2>&1 || true

SCRIPT="$HOME/Proyectos/karaoke/karaoke.sh"
if [ ! -f "$SCRIPT" ]; then
  echo "No se encuentra $SCRIPT. Re-sincroniza con: bash ~/Proyectos/widgets-termux/sync.sh"
  exit 1
fi

exec bash "$SCRIPT" "$@"
