#!/data/data/com.termux/files/usr/bin/bash
# Wrapper para agente.py con verificación de dependencias
source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
ensure_cmd python python
ensure_python_module requests
cd "$HOME/Proyectos/widgets-termux" || exit
python agente.py "$@"
