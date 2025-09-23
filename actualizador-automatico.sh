#!/data/data/com.termux/files/usr/bin/bash

# ========================================
# Actualizador automático de widgets
# Puede ejecutarse desde cron o termux-job-scheduler
# ========================================

SCRIPT_SINCRONIZACION="$HOME/sincronizar-widgets.sh"
ARCHIVO_LOG="$HOME/.widgets-termux-sync.log"
MAX_LINEAS_LOG=100

# Función para log con timestamp
log_con_tiempo() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$ARCHIVO_LOG"
}

# Función para mantener el log limitado
limpiar_log() {
    if [ -f "$ARCHIVO_LOG" ] && [ $(wc -l < "$ARCHIVO_LOG") -gt $MAX_LINEAS_LOG ]; then
        tail -n $MAX_LINEAS_LOG "$ARCHIVO_LOG" > "${ARCHIVO_LOG}.tmp"
        mv "${ARCHIVO_LOG}.tmp" "$ARCHIVO_LOG"
    fi
}

# Verificar conectividad antes de sincronizar
verificar_internet() {
    if ping -c 1 8.8.8.8 >/dev/null 2>&1 || ping -c 1 google.com >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Mostrar uso si se ejecuta con parámetros incorrectos
mostrar_uso() {
    echo "📱 Actualizador Automático de Widgets Termux"
    echo ""
    echo "Uso:"
    echo "  $0 ahora         - Actualizar ahora"
    echo "  $0 programar     - Programar actualización automática"
    echo "  $0 cancelar      - Cancelar actualización automática"
    echo "  $0 estado        - Ver estado y últimos logs"
    echo "  $0 verificar     - Solo verificar si hay actualizaciones"
    echo ""
}

# Función para verificar actualizaciones sin aplicarlas
verificar_actualizaciones() {
    CARPETA_WIDGETS="$HOME/widgets-termux"
    
    if [ ! -d "$CARPETA_WIDGETS" ]; then
        echo "❌ Repositorio no inicializado. Ejecuta el script de sincronización primero."
        return 1
    fi
    
    cd "$CARPETA_WIDGETS"
    
    # Fetch para obtener cambios remotos
    git fetch origin >/dev/null 2>&1
    
    # Comparar commits
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "🔄 Hay actualizaciones disponibles"
        log_con_tiempo "Actualizaciones disponibles detectadas"
        return 0
    else
        echo "✅ Los widgets están actualizados"
        log_con_tiempo "No hay actualizaciones disponibles"
        return 1
    fi
}

# Función para actualizar ahora
actualizar_ahora() {
    echo "🔄 Iniciando actualización automática..."
    log_con_tiempo "Iniciando actualización automática"
    
    if ! verificar_internet; then
        echo "❌ Sin conexión a Internet"
        log_con_tiempo "ERROR: Sin conexión a Internet"
        return 1
    fi
    
    if [ ! -f "$SCRIPT_SINCRONIZACION" ]; then
        echo "❌ Script de sincronización no encontrado: $SCRIPT_SINCRONIZACION"
        log_con_tiempo "ERROR: Script de sincronización no encontrado"
        return 1
    fi
    
    # Ejecutar script de sincronización
    if bash "$SCRIPT_SINCRONIZACION" >/dev/null 2>&1; then
        echo "✅ Widgets actualizados correctamente"
        log_con_tiempo "Widgets actualizados correctamente"
        
        # Opcional: enviar notificación
        if command -v termux-notification >/dev/null; then
            termux-notification --title "Widgets Termux" --content "Scripts actualizados automáticamente"
        fi
        return 0
    else
        echo "❌ Error al actualizar widgets"
        log_con_tiempo "ERROR: Fallo en la actualización"
        return 1
    fi
}

# Función para programar actualizaciones automáticas
programar_actualizaciones() {
    if ! command -v termux-job-scheduler >/dev/null; then
        echo "❌ termux-job-scheduler no disponible. Instálalo con: pkg install termux-api"
        return 1
    fi
    
    # Programar para ejecutar cada 6 horas
    termux-job-scheduler --job-id 1001 \
                        --period-ms 21600000 \
                        --persisted true \
                        --script "$0 ahora"
    
    if [ $? -eq 0 ]; then
        echo "✅ Actualización automática programada (cada 6 horas)"
        log_con_tiempo "Actualización automática programada"
    else
        echo "❌ Error al programar actualización automática"
        log_con_tiempo "ERROR: No se pudo programar actualización automática"
    fi
}

# Función para cancelar actualizaciones automáticas
cancelar_actualizaciones() {
    if command -v termux-job-scheduler >/dev/null; then
        termux-job-scheduler --cancel --job-id 1001
        echo "✅ Actualización automática cancelada"
        log_con_tiempo "Actualización automática cancelada"
    else
        echo "❌ termux-job-scheduler no disponible"
    fi
}

# Función para mostrar estado y logs
mostrar_estado() {
    echo "📊 Estado del sistema de widgets"
    echo "================================="
    
    # Verificar estado del repositorio
    CARPETA_WIDGETS="$HOME/widgets-termux"
    if [ -d "$CARPETA_WIDGETS" ]; then
        cd "$CARPETA_WIDGETS"
        echo "📁 Repositorio: Inicializado"
        echo "🌿 Rama actual: $(git branch --show-current 2>/dev/null || echo 'desconocida')"
        echo "🔗 Último commit: $(git log -1 --format='%h - %s' 2>/dev/null || echo 'No disponible')"
        
        # Contar scripts
        CANTIDAD_SCRIPTS=$(find "$CARPETA_WIDGETS" -maxdepth 1 -type f ! -name "README.md" ! -name ".*" ! -name "configurar-*" ! -name "instrucciones-*" | wc -l)
        echo "📄 Scripts disponibles: $CANTIDAD_SCRIPTS"
        
        # Verificar enlaces
        CANTIDAD_SHORTCUTS=$(find "$HOME/.shortcuts" -type l 2>/dev/null | wc -l)
        echo "🔗 Enlaces activos: $CANTIDAD_SHORTCUTS"
    else
        echo "📁 Repositorio: No inicializado"
    fi
    
    echo ""
    echo "📋 Últimos 5 logs:"
    echo "=================="
    if [ -f "$ARCHIVO_LOG" ]; then
        tail -n 5 "$ARCHIVO_LOG"
    else
        echo "No hay logs disponibles"
    fi
    
    echo ""
    echo "⏰ Trabajos programados:"
    echo "======================="
    if command -v termux-job-scheduler >/dev/null; then
        termux-job-scheduler --list | grep -A 5 -B 5 "1001" || echo "No hay trabajos programados"
    else
        echo "termux-job-scheduler no disponible"
    fi
}

# Manejo de parámetros
case "${1:-}" in
    "ahora")
        actualizar_ahora
        limpiar_log
        ;;
    "programar")
        programar_actualizaciones
        ;;
    "cancelar")
        cancelar_actualizaciones
        ;;
    "estado")
        mostrar_estado
        ;;
    "verificar")
        verificar_actualizaciones
        ;;
    *)
        mostrar_uso
        exit 1
        ;;
esac