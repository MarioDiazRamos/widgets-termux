#!/data/data/com.termux/files/usr/bin/bash

echo "Iniciando configuración de Termux..."

# Instalar solo si faltan (idempotente)
source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
ensure_cmd git git
ensure_cmd curl curl
ensure_cmd wget wget
ensure_cmd python python
ensure_cmd neovim neovim
ensure_cmd bat bat
ensure_cmd lsd lsd
ensure_cmd micro micro
ensure_cmd mpv mpv
ensure_cmd termux-battery-status termux-api
grep -q "alias ls='lsd -lah --icon=auto'" ~/.bashrc || echo "alias ls='lsd -lah --icon=auto'" >> ~/.bashrc
grep -q "alias ll='lsd -lah --icon=auto'" ~/.bashrc || echo "alias ll='lsd -lah --icon=auto'" >> ~/.bashrc
grep -q "alias la='lsd -a --icon=auto'" ~/.bashrc || echo "alias la='lsd -a --icon=auto'" >> ~/.bashrc
grep -q "alias cat='bat --paging=never'" ~/.bashrc || echo "alias cat='bat --paging=never'" >> ~/.bashrc
cat >> ~/.bashrc << 'EOF'
RESET="\[\e[0m\]"
BOLD="\[\e[1m\]"
RED="\[\e[31m\]"
GREEN="\[\e[32m\]"
BLUE="\[\e[34m\]"
YELLOW="\[\e[33m\]"
CYAN="\[\e[36m\]"
export PS1="${BOLD}${BLUE}\u@\h${RESET}:${BOLD}${GREEN}\w${RESET}\$ "
EOF
mkdir -p ~/.config/bat
grep -q "truecolor" ~/.config/bat/config 2>/dev/null || echo "truecolor" >> ~/.config/bat/config
mkdir -p ~/.config/micro/colorschemes
curl -L https://raw.githubusercontent.com/zyedidia/micro/master/runtime/colorschemes/monokai.micro -o ~/.config/micro/colorschemes/monokai.micro
EXPLORADOR="$HOME/explorador_prof.sh"
cat > "$EXPLORADOR" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
ROOT="/storage/emulated/0"
CURRENT="$ROOT"
LIST_MODE="folders_only"

# Colores
RESET="\e[0m"
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"


# Función para reproducir música/video
reproducir_multimedia() {
    local FILE="$1"
    case "${FILE##*.}" in
        mp3|m4a|wav|flac) termux-media-player play "$FILE" ;;
        mp4|mkv|avi|webm) mpv --fs "$FILE" ;;
        *) termux-open "$FILE" ;;
    esac
}

# Función para listar contenido
listar_contenido() {
    clear
    echo -e "${BOLD}${CYAN}Directorio actual:${RESET} ${GREEN}$CURRENT${RESET}"
    echo -e "${YELLOW}----------------------------------------------${RESET}"

    if [ "$LIST_MODE" == "folders_only" ]; then
        mapfile -t ITEMS < <(find "$CURRENT" -maxdepth 1 -mindepth 1 -type d | sort)
    else
        mapfile -t ITEMS < <(find "$CURRENT" -maxdepth 1 -mindepth 1 | sort)
    fi

    declare -A ITEM_MAP
    INDEX=1

    # Opciones especiales
    if [ "$CURRENT" != "$ROOT" ]; then
        echo -e "${BOLD}${RED}0) Volver al directorio anterior${RESET}"
    fi

    if [ "$LIST_MODE" == "folders_only" ]; then
        echo -e "${BOLD}$INDEX) Listar archivos y carpetas${RESET}"
        INDEX=$((INDEX + 1))
    fi

    # Mostrar items
    for ITEM in "${ITEMS[@]}"; do
        BASENAME=$(basename "$ITEM")
        if [ -d "$ITEM" ]; then
            echo -e "${BOLD}${BLUE}$INDEX) $BASENAME${RESET}"
        else
            echo -e "${CYAN}$INDEX) $BASENAME${RESET}"
        fi
        ITEM_MAP[$INDEX]="$ITEM"
        INDEX=$((INDEX + 1))
    done

    echo
    echo -e "${YELLOW}Elige un número para entrar/abrir un archivo, 'q' para salir${RESET}"
    echo -e "${YELLOW}----------------------------------------------${RESET}"

    # Leer elección
    read -p "Opción: " CHOICE

    if [[ "$CHOICE" =~ ^[Qq]$ ]]; then
        echo -e "${GREEN}Saliendo...${RESET}"
        exit 0
    fi

    # Volver al directorio anterior
    if [ "$CHOICE" == "0" ] && [ "$CURRENT" != "$ROOT" ]; then
        CURRENT=$(dirname "$CURRENT")
        LIST_MODE="folders_only"
        return
    fi

    # Cambiar modo a listar todo
    if [ "$LIST_MODE" == "folders_only" ] && [ "$CHOICE" == "1" ]; then
        LIST_MODE="all"
        return
    fi

    # Entrar carpeta o abrir archivo
    SELECTED="${ITEM_MAP[$CHOICE]}"
    if [ -z "$SELECTED" ]; then
        echo -e "${RED}Opción inválida.${RESET}"
        sleep 1
        return
    fi
    if [ -d "$SELECTED" ]; then
        CURRENT="$SELECTED"
        LIST_MODE="folders_only"
    else
        reproducir_multimedia "$SELECTED"
        read -p "Presiona Enter para continuar..." dummy
    fi
}

# Bucle principal
while true; do listar_contenido; done
EOF
chmod +x "$EXPLORADOR"
echo "Configuración completada."
echo "Explorador de archivos: $EXPLORADOR"
echo "Terminal lista con colores, ls moderno, bat y prompt tipo IDE"
echo "Cierra y abre Termux para aplicar los cambios"
