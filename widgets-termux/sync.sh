#!/data/data/com.termux/files/usr/bin/bash
# Sincronizador automático de proyectos (widgets-termux)
# Clean Code, español, compacto y KISS

REPO_URL="https://github.com/MarioDiazRamos/Proyectos.git"
CARPETA_REPO="$HOME/Proyectos"
CARPETA_WIDGETS="$CARPETA_REPO/widgets-termux"

command -v git >/dev/null || { echo "Git no instalado. Ejecuta: pkg install git"; exit 1; }
if [ ! -d "$CARPETA_REPO/.git" ]; then
    git clone "$REPO_URL" "$CARPETA_REPO" || { echo "Error al clonar repo"; exit 1; }
else
    cd "$CARPETA_REPO" && git pull origin main || git pull origin master || { echo "Error al actualizar repo"; exit 1; }
fi
echo "Sincronización completada."

# --- Permisos y wrappers automáticos ---
CARPETA_SHORTCUTS="$HOME/.shortcuts"
CARPETA_BIN="$HOME/bin"

mkdir -p "$CARPETA_SHORTCUTS"
mkdir -p "$CARPETA_BIN"

# Permisos amplios en todo el repositorio de Proyectos (lectura/escritura para usuario y ejecución donde aplique)
chmod -R u+rwX,go+rX "$CARPETA_REPO" 2>/dev/null
# Asegurar ejecutable en scripts comunes
find "$CARPETA_REPO" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod u+x {} + 2>/dev/null

for s in "$CARPETA_WIDGETS"/*; do
    [ ! -f "$s" ] && continue
    chmod 755 "$s"
    nombre=$(basename "$s")
    # Wrapper en .shortcuts
    ln -sf "$s" "$CARPETA_SHORTCUTS/$nombre"
    # Wrapper en bin (sin extensión)
    nombre_bin="${nombre%.*}"
    ln -sf "$s" "$CARPETA_BIN/$nombre_bin"
done

echo "Permisos y accesos automáticos configurados."

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