#!/data/data/com.termux/files/usr/bin/bash
PROYECTO_DIR="$HOME/Proyectos/karaoke"
TEMP_DIR="$PROYECTO_DIR/temp"
PID_ARCHIVO="$TEMP_DIR/servidor.pid"
LOG_ARCHIVO="$TEMP_DIR/servidor.log"
PUERTO=8080
HOST="0.0.0.0"
SERVIDOR_PY="server.py"


cd "$PROYECTO_DIR" || { echo "No existe el directorio $PROYECTO_DIR"; exit 1; }
# Crear carpeta temp si no existe
mkdir -p "$TEMP_DIR"

iniciar_servidor() {
    if [ -f "$PID_ARCHIVO" ]; then
        PID_ANT=$(cat "$PID_ARCHIVO")
        if ps -p "$PID_ANT" > /dev/null 2>&1; then
            echo "El servidor ya está en ejecución (PID $PID_ANT)."
            echo "Accede desde cualquier dispositivo: http://<IP>:$PUERTO"
            echo "Consulta tu IP con: ifconfig'"
            exit 0
        else
            rm -f "$PID_ARCHIVO"
        fi
    fi
    # Obtener IP local
    if command -v ifconfig >/dev/null 2>&1; then
        IP_LOCAL=$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2}' | head -n1)
    fi
    echo "Iniciando servidor en segundo plano..."
    if [ -n "$IP_LOCAL" ]; then
        echo "Accede desde cualquier dispositivo: http://$IP_LOCAL:$PUERTO"
    fi
    echo "Acceso local: http://127.0.0.1:$PUERTO"
    python "$SERVIDOR_PY" &> "$LOG_ARCHIVO" &
    echo $! > "$PID_ARCHIVO"
    sleep 1
    echo "Servidor iniciado (PID $(cat $PID_ARCHIVO))."
    echo "Logs: $LOG_ARCHIVO"
    echo "Para detener: karaoke stop Ó ./karaoke.sh stop"
}

detener_servidor() {
    if [ -f "$PID_ARCHIVO" ]; then
        PID=$(cat "$PID_ARCHIVO")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID" && echo "Servidor detenido (PID $PID)."
        else
            echo "El PID $PID no está corriendo."
        fi
        rm -f "$PID_ARCHIVO"
    else
        echo "No se encontró PID. ¿El servidor está iniciado?"
    fi
}

case "$1" in
    detener|stop) detener_servidor ;;
    *) iniciar_servidor ;;
esac