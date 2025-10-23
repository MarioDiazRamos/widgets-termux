#!/data/data/com.termux/files/usr/bin/bash
# Sincronizador automático de widgets-termux
# Clean Code, español, compacto y KISS

REPO_URL="https://github.com/MarioDiazRamos/widgets-termux.git"
CARPETA_WIDGETS="$HOME/Proyectos/widgets-termux"

command -v git >/dev/null || { echo "Git no instalado. Ejecuta: pkg install git"; exit 1; }
if [ ! -d "$CARPETA_WIDGETS" ]; then
    git clone "$REPO_URL" "$CARPETA_WIDGETS" || { echo "Error al clonar repo"; exit 1; }
else
    cd "$CARPETA_WIDGETS" && git pull origin main || git pull origin master || { echo "Error al actualizar repo"; exit 1; }
fi
echo "Sincronización completada."

# --- Permisos y wrappers automáticos ---
CARPETA_SHORTCUTS="$HOME/.shortcuts"
CARPETA_BIN="$HOME/bin"

mkdir -p "$CARPETA_SHORTCUTS"
mkdir -p "$CARPETA_BIN"

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

echo "Permisos y accesos automáticos configurados. Ejecuta 'termux-reload-settings' si es necesario."