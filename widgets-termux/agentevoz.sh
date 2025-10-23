#!/data/data/com.termux/files/usr/bin/bash
# Wrapper para agentevoz.py con verificación de dependencias
source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
ensure_cmd python python
ensure_cmd termux-tts-speak termux-api
ensure_cmd termux-speech-to-text termux-api
ensure_python_module requests
cd "$HOME/Proyectos/widgets-termux"
python agentevoz.py "$@"
