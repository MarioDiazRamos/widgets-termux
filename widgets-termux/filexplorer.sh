#!/data/data/com.termux/files/usr/bin/bash

# Wrapper para FileXplorer (Flask)
# Asegura dependencias mínimas y delega al launcher del proyecto

# Cargar utilidades si existen
if [ -f "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
fi

ensure_storage 2>/dev/null || true
ensure_cmd python python 2>/dev/null || true
ensure_python_module flask 2>/dev/null || true
# ripgrep acelera búsquedas si está; opcional
ensure_cmd rg ripgrep 2>/dev/null || true

SCRIPT="$HOME/Proyectos/filexplorer/filexplorer.sh"
if [ ! -f "$SCRIPT" ]; then
  echo "No se encuentra $SCRIPT. Re-sincroniza con: bash ~/Proyectos/widgets-termux/sync.sh"
  exit 1
fi

exec bash "$SCRIPT" "$@"
