#!/data/data/com.termux/files/usr/bin/bash

# Wrapper para Streamio (Flask + peerflix)

if [ -f "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
fi

ensure_storage 2>/dev/null || true
ensure_cmd python python 2>/dev/null || true
# peerflix requiere Node.js; npm viene con nodejs en Termux
ensure_cmd node nodejs 2>/dev/null || true
ensure_cmd npm nodejs 2>/dev/null || true

SCRIPT="$HOME/Proyectos/streamio/streamio.sh"
if [ ! -f "$SCRIPT" ]; then
  echo "No se encuentra $SCRIPT. Re-sincroniza con: bash ~/Proyectos/widgets-termux/sync.sh"
  exit 1
fi

exec bash "$SCRIPT" "$@"
