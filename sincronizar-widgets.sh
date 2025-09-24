#!/data/data/com.termux/files/usr/bin/bash

# ========================================
# Sincronizador de Widgets para Termux
# Sistema de versionado con GitHub
# ========================================

# CONFIGURACIÓN (personaliza esta URL con tu repositorio)
REPO_URL="https://github.com/MarioDiazRamos/widgets-termux.git"  # Tu repositorio configurado
CARPETA_WIDGETS="$HOME/widgets-termux"
CARPETA_SHORTCUTS="$HOME/.shortcuts"

# Colores para output
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
SIN_COLOR='\033[0m'

echo -e "${AZUL}🔧 Sincronizador de Widgets Termux${SIN_COLOR}"
echo "===================================="

# Funciones para mostrar mensajes
mostrar_info() { echo -e "${AZUL}[INFO]${SIN_COLOR} $1"; }
mostrar_exito() { echo -e "${VERDE}[ÉXITO]${SIN_COLOR} $1"; }
mostrar_advertencia() { echo -e "${AMARILLO}[ADVERTENCIA]${SIN_COLOR} $1"; }
mostrar_error() { echo -e "${ROJO}[ERROR]${SIN_COLOR} $1"; }

# Verificar si git está instalado
if ! command -v git &> /dev/null; then
    mostrar_error "Git no está instalado. Instálalo con: pkg install git"
    exit 1
fi

# Crear directorio .shortcuts si no existe
if [ ! -d "$CARPETA_SHORTCUTS" ]; then
    mostrar_info "Creando directorio $CARPETA_SHORTCUTS"
    mkdir -p "$CARPETA_SHORTCUTS"
fi

# Asegurar que .shortcuts esté en PATH
if [[ ":$PATH:" != *":$HOME/.shortcuts:"* ]]; then
    mostrar_info "Añadiendo ~/.shortcuts al PATH"
    export PATH="$HOME/.shortcuts:$PATH"
    echo 'export PATH="$HOME/.shortcuts:$PATH"' >> ~/.bashrc
fi

# Verificar si es primera vez (clonar) o actualización (pull)
if [ ! -d "$CARPETA_WIDGETS" ]; then
    mostrar_info "Primera vez: clonando repositorio..."
    if git clone "$REPO_URL" "$CARPETA_WIDGETS"; then
        mostrar_exito "Repositorio clonado exitosamente"
    else
        mostrar_error "Error al clonar el repositorio. Verifica la URL y tu conexión."
        exit 1
    fi
else
    mostrar_info "Actualizando repositorio existente..."
    cd "$CARPETA_WIDGETS"
    
    # Verificar si es un repositorio Git válido
    if [ ! -d ".git" ]; then
        mostrar_advertencia "No es un repositorio Git válido. Reinicializando..."
        git init
        git remote add origin "$REPO_URL"
        git config user.name "termux-user"
        git config user.email "user@termux.local"
    fi
    
    # Intentar actualizar
    if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
        mostrar_exito "Repositorio actualizado exitosamente"
    else
        mostrar_advertencia "No se pudo hacer pull. Descargando archivos individualmente..."
        # Fallback: descargar archivos críticos manualmente
        curl -sL "${REPO_URL/github.com/raw.githubusercontent.com}/main/agentevoz" -o "agentevoz"
        curl -sL "${REPO_URL/github.com/raw.githubusercontent.com}/main/agente.py" -o "agente.py"
        curl -sL "${REPO_URL/github.com/raw.githubusercontent.com}/main/descarga.sh" -o "descarga.sh"
        mostrar_info "Archivos principales descargados"
    fi
fi

# Contadores
scripts_procesados=0
scripts_nuevos=0
scripts_actualizados=0

mostrar_info "Procesando scripts..."

# Procesar cada script en el repositorio
for ruta_script in "$CARPETA_WIDGETS"/*; do
    # Saltar si no es archivo
    [ ! -f "$ruta_script" ] && continue
    
    # Obtener nombre del script
    nombre_script=$(basename "$ruta_script")
    
    # Saltar archivos de configuración y documentación
    case "$nombre_script" in
        README.md|.git*|*.md|LICENSE|configurar-*|INSTRUCCIONES-*|*.ps1)
            continue
            ;;
    esac
    
    ruta_shortcut="$CARPETA_SHORTCUTS/$nombre_script"
    
    # Para archivos .py, crear enlace sin extensión también
    if [[ "$nombre_script" == *.py ]]; then
        nombre_sin_extension="${nombre_script%.py}"
        ruta_shortcut_sin_ext="$CARPETA_SHORTCUTS/$nombre_sin_extension"
        
        # Crear enlace sin extensión
        if [ -L "$ruta_shortcut_sin_ext" ]; then
            if [ "$(readlink "$ruta_shortcut_sin_ext")" = "$ruta_script" ]; then
                mostrar_info "✓ $nombre_sin_extension (ya vinculado)"
            else
                rm "$ruta_shortcut_sin_ext"
                ln -s "$ruta_script" "$ruta_shortcut_sin_ext"
                mostrar_info "Revinculado $nombre_sin_extension"
            fi
        else
            ln -s "$ruta_script" "$ruta_shortcut_sin_ext"
            mostrar_info "Vinculando nuevo script: $nombre_sin_extension"
            scripts_nuevos=$((scripts_nuevos + 1))
        fi
        chmod +x "$ruta_shortcut_sin_ext" 2>/dev/null
    fi
    
    # Crear enlace con nombre completo
    if [ -L "$ruta_shortcut" ]; then
        # Ya existe, verificar si apunta al lugar correcto
        if [ "$(readlink "$ruta_shortcut")" = "$ruta_script" ]; then
            mostrar_info "✓ $nombre_script (ya vinculado)"
            scripts_actualizados=$((scripts_actualizados + 1))
        else
            mostrar_advertencia "Revinculando $nombre_script"
            rm "$ruta_shortcut"
            ln -s "$ruta_script" "$ruta_shortcut"
            scripts_actualizados=$((scripts_actualizados + 1))
        fi
    elif [ -f "$ruta_shortcut" ]; then
        # Existe un archivo real, hacer respaldo y crear enlace
        mostrar_advertencia "Respaldando archivo existente: $nombre_script → ${nombre_script}.respaldo"
        mv "$ruta_shortcut" "${ruta_shortcut}.respaldo"
        ln -s "$ruta_script" "$ruta_shortcut"
        scripts_nuevos=$((scripts_nuevos + 1))
    else
        # No existe, crear enlace nuevo
        mostrar_info "Vinculando nuevo script: $nombre_script"
        ln -s "$ruta_script" "$ruta_shortcut"
        scripts_nuevos=$((scripts_nuevos + 1))
    fi
    
    # Dar permisos ejecutables al script original y al enlace
    chmod +x "$ruta_script"
    chmod +x "$ruta_shortcut" 2>/dev/null
    scripts_procesados=$((scripts_procesados + 1))
done

echo ""
echo "===================================="
mostrar_exito "¡Sincronización completada!"
echo ""
echo "📊 Estadísticas:"
echo "   • Scripts procesados: $scripts_procesados"
echo "   • Scripts nuevos: $scripts_nuevos" 
echo "   • Scripts actualizados: $scripts_actualizados"
echo ""

# Verificar si hay scripts huérfanos en .shortcuts
mostrar_info "Verificando scripts huérfanos..."
huerfanos=0
for shortcut in "$CARPETA_SHORTCUTS"/*; do
    [ ! -L "$shortcut" ] && continue
    if [ ! -f "$(readlink "$shortcut")" ]; then
        mostrar_advertencia "Enlace roto encontrado: $(basename "$shortcut")"
        huerfanos=$((huerfanos + 1))
    fi
done

if [ $huerfanos -gt 0 ]; then
    echo ""
    read -p "¿Deseas limpiar los $huerfanos enlaces rotos? (s/n): " limpiar
    if [ "$limpiar" = "s" ] || [ "$limpiar" = "S" ]; then
        for shortcut in "$CARPETA_SHORTCUTS"/*; do
            [ ! -L "$shortcut" ] && continue
            if [ ! -f "$(readlink "$shortcut")" ]; then
                rm "$shortcut"
                mostrar_info "Eliminado enlace roto: $(basename "$shortcut")"
            fi
        done
        mostrar_exito "Enlaces rotos limpiados"
    fi
fi

echo ""
mostrar_exito "🎉 ¡Widgets listos para usar desde el widget de Termux!"
mostrar_info "💡 Recuerda reiniciar el widget o el dispositivo para ver los cambios"