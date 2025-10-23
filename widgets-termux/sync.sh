#!/data/data/com.termux/files/usr/bin/bash
# Sincronizador automático de proyectos (widgets-termux)
# Clean Code, español, compacto y KISS

REPO_URL="https://github.com/MarioDiazRamos/Proyectos.git"
CARPETA_REPO="$HOME/Proyectos"
CARPETA_WIDGETS="$CARPETA_REPO/widgets-termux"

command -v git >/dev/null || { echo "Git no instalado. Ejecuta: pkg install git"; exit 1; }

# --- Clonado/actualización robusta ---
timestamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "now")
if [ ! -d "$CARPETA_REPO/.git" ]; then
    if [ -d "$CARPETA_REPO" ] && [ "$(ls -A \"$CARPETA_REPO\")" != "" ]; then
        echo "Directorio existente y no es repo git. Moviendo a respaldo: $CARPETA_REPO.bak-$timestamp"
        mv "$CARPETA_REPO" "$CARPETA_REPO.bak-$timestamp" || { echo "No se pudo respaldar carpeta existente"; exit 1; }
    fi
    git clone "$REPO_URL" "$CARPETA_REPO" || { echo "Error al clonar repo"; exit 1; }
else
    cd "$CARPETA_REPO" || { echo "No se pudo entrar a $CARPETA_REPO"; exit 1; }
    git remote set-url origin "$REPO_URL" >/dev/null 2>&1 || true
    git fetch origin || { echo "Error al hacer fetch"; exit 1; }
    # Preferir main, si no existe usar master
    if git rev-parse --verify origin/main >/dev/null 2>&1; then
        git checkout -q main 2>/dev/null || git checkout -qb main || true
        git reset --hard origin/main || { echo "Error al sincronizar con origin/main"; exit 1; }
    elif git rev-parse --verify origin/master >/dev/null 2>&1; then
        git checkout -q master 2>/dev/null || git checkout -qb master || true
        git reset --hard origin/master || { echo "Error al sincronizar con origin/master"; exit 1; }
    else
        echo "No se encontró rama remota main/master"; exit 1
    fi
fi
echo "Sincronización completada."

# --- Permisos y wrappers automáticos ---
CARPETA_SHORTCUTS="$HOME/.shortcuts"
CARPETA_BIN="$HOME/bin"
PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
PREFIX_BIN="$PREFIX_DIR/bin"

mkdir -p "$CARPETA_SHORTCUTS"
mkdir -p "$CARPETA_BIN"
mkdir -p "$PREFIX_BIN"

# Permisos amplios en todo el repositorio de Proyectos (lectura/escritura para usuario y ejecución donde aplique)
chmod -R u+rwX,go+rX "$CARPETA_REPO" 2>/dev/null
# Normalizar finales de línea (quitar CRLF) y asegurar ejecutables
find "$CARPETA_REPO" -type f \( -name "*.sh" -o -name "*.py" \) -exec sed -i 's/\r$//' {} + 2>/dev/null
find "$CARPETA_REPO" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod u+x {} + 2>/dev/null

for s in "$CARPETA_WIDGETS"/*; do
    [ ! -f "$s" ] && continue
    nombre=$(basename "$s")
    ext="${nombre##*.}"
    base="${nombre%.*}"

    # Determinar destino en bin: para .sh usar nombre sin extensión, para .py omitir (usa su wrapper .sh), otros igual
    case "$ext" in
        sh)
            target="$s"
            nombre_bin="$base"
            ;;
        py)
            # saltar .py para evitar ejecutar sin shebang; se espera wrapper .sh
            ln -sf "$s" "$CARPETA_SHORTCUTS/$nombre"  # accesible desde widgets si se requiere
            continue
            ;;
        *)
            target="$s"
            nombre_bin="$nombre"
            ;;
    esac

    chmod 755 "$target"
    # Wrapper en .shortcuts con el nombre original (incluida extensión)
    ln -sf "$target" "$CARPETA_SHORTCUTS/$nombre"
    # Wrapper en bin y PREFIX/bin con nombre_bin
    ln -sf "$target" "$CARPETA_BIN/$nombre_bin"
    ln -sf "$target" "$PREFIX_BIN/$nombre_bin"
done

echo "Permisos y accesos automáticos configurados."

# Limpiar enlaces rotos en binarios y accesos
for d in "$CARPETA_BIN" "$PREFIX_BIN" "$CARPETA_SHORTCUTS"; do
    find "$d" -xtype l -exec rm -f {} + 2>/dev/null || true
done

# --- Asegurar PATH incluye ~/bin ---
PROFILE_FILE="$HOME/.profile"
grep -q 'export PATH="$HOME/bin:$PATH"' "$PROFILE_FILE" 2>/dev/null || {
    echo 'export PATH="$HOME/bin:$PATH"' >> "$PROFILE_FILE"
    echo "PATH actualizado en ~/.profile (requiere reiniciar la sesión de shell)."
}

# --- Conceder acceso a almacenamiento si aún no está ---
if [ ! -d "$HOME/storage/shared" ]; then
    command -v termux-setup-storage >/dev/null && termux-setup-storage || true
fi

# --- Dependencias mínimas (instalar solo si faltan) ---
ensure_cmd() { command -v "$1" >/dev/null || pkg install -y "$2" >/dev/null 2>&1; }
ensure_python_module() { python -c "import $1" >/dev/null 2>&1 || python -m pip install --user "$1" >/dev/null 2>&1; }

# Paquetes base
ensure_cmd python python
ensure_cmd ffmpeg ffmpeg
ensure_cmd termux-battery-status termux-api
# Herramientas multimedia opcionales utilizadas por scripts
command -v yt-dlp >/dev/null 2>&1 || python -m pip install --user yt-dlp >/dev/null 2>&1
# Módulos Python comunes
ensure_python_module requests

echo "Entorno verificado. Si no ves cambios en accesos, ejecuta: termux-reload-settings"
