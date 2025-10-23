#!/data/data/com.termux/files/usr/bin/bash

# ===================================================
# Plantilla básica para scripts de Termux Widgets
# Copia este archivo y personalízalo según tus necesidades
# ===================================================

# Configuración del script
NOMBRE_SCRIPT="Mi Script"
VERSION="1.0"

# Colores para output (opcional)
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
SIN_COLOR='\033[0m'

# Función para mostrar mensajes con colores
mostrar_info() { echo -e "${AZUL}[INFO]${SIN_COLOR} $1"; }
mostrar_exito() { echo -e "${VERDE}[ÉXITO]${SIN_COLOR} $1"; }
mostrar_advertencia() { echo -e "${AMARILLO}[ADVERTENCIA]${SIN_COLOR} $1"; }
mostrar_error() { echo -e "${ROJO}[ERROR]${SIN_COLOR} $1"; }

# Función para mostrar encabezado
mostrar_encabezado() {
    echo -e "${AZUL}=========================${SIN_COLOR}"
    echo -e "${AZUL}📱 $NOMBRE_SCRIPT v$VERSION${SIN_COLOR}"
    echo -e "${AZUL}=========================${SIN_COLOR}"
    echo ""
}

# Función para verificar dependencias
verificar_dependencias() {
    local deps=("curl" "jq" "termux-notification")  # Personaliza según necesites
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            mostrar_error "Dependencia faltante: $dep"
            mostrar_info "Instala con: pkg install $dep"
            return 1
        fi
    done
    
    mostrar_exito "Dependencias verificadas"
    return 0
}

# Función para solicitar input del usuario
obtener_entrada_usuario() {
    local prompt="$1"
    local predeterminado="$2"
    local resultado
    
    if [ -n "$predeterminado" ]; then
        read -p "$prompt [$predeterminado]: " resultado
        echo "${resultado:-$predeterminado}"
    else
        read -p "$prompt: " resultado
        echo "$resultado"
    fi
}

# Función para confirmar acción
confirmar_accion() {
    local mensaje="$1"
    local respuesta
    
    read -p "$mensaje (s/n): " respuesta
    case "$respuesta" in
        [sS]|[sS][iI]|[yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Función para enviar notificación (opcional)
enviar_notificacion() {
    local titulo="$1"
    local mensaje="$2"
    
    if command -v termux-notification &> /dev/null; then
        termux-notification --title "$titulo" --content "$mensaje"
    fi
}

# Función principal del script
main() {
    mostrar_encabezado
    
    # Verificar dependencias
    if ! verificar_dependencias; then
        exit 1
    fi
    
    # Tu lógica principal aquí
    mostrar_info "Iniciando $NOMBRE_SCRIPT..."
    
    # Ejemplo: solicitar input
    # ENTRADA_USUARIO=$(obtener_entrada_usuario "Ingresa un valor")
    # mostrar_info "Valor ingresado: $ENTRADA_USUARIO"
    
    # Ejemplo: confirmar acción
    # if confirmar_accion "¿Continuar con la operación?"; then
    #     mostrar_exito "Operación confirmada"
    # else
    #     mostrar_advertencia "Operación cancelada"
    #     exit 0
    # fi
    
    # Aquí va tu código principal
    # ...
    
    # Ejemplo: enviar notificación al final
    # enviar_notificacion "$NOMBRE_SCRIPT" "Operación completada exitosamente"
    
    mostrar_exito "¡$NOMBRE_SCRIPT completado!"
}

# Punto de entrada
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi