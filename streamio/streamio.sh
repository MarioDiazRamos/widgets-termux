#!/data/data/com.termux/files/usr/bin/bash
# Script para iniciar Streamio en Termux de forma automática y robusta

PROYECTO_DIR="$HOME/Proyectos/streamio"
TEMP_DIR="$PROYECTO_DIR/temp"
LOG_FILE="$TEMP_DIR/servidor.log"
PID_FILE="$TEMP_DIR/servidor.pid"
PUERTO=5000
HOST="0.0.0.0"

cd "$PROYECTO_DIR" || { echo "No existe el directorio $PROYECTO_DIR"; exit 1; }
mkdir -p "$TEMP_DIR"

# Instalar dependencias solo si faltan
if ! command -v python > /dev/null; then
    pkg install -y python
fi
if ! command -v pip > /dev/null; then
    pkg install -y python-pip
fi
if ! pip show flask > /dev/null 2>&1; then
    pip install flask flask-cors requests beautifulsoup4
fi
if ! command -v peerflix > /dev/null; then
    npm install -g peerflix
fi

iniciar() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Streamio ya está en ejecución (PID $PID)"
            echo "Accede en: http://localhost:$PUERTO"
            exit 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    echo "Iniciando Streamio..."
    # Obtener IP local
    if command -v ifconfig >/dev/null 2>&1; then
        IP_LOCAL=$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2}' | head -n1)
    fi
    nohup python server.py > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2
    echo "Streamio iniciado (PID $(cat $PID_FILE))."
    if [ -n "$IP_LOCAL" ]; then
        echo "Accede desde cualquier dispositivo: http://$IP_LOCAL:$PUERTO"
    fi
    echo "Acceso local: http://127.0.0.1:$PUERTO"
    echo "Logs: $LOG_FILE"
}

detener() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID" && echo "Streamio detenido (PID $PID)."
        else
            echo "El PID $PID no está corriendo."
        fi
        rm -f "$PID_FILE"
    else
        echo "No se encontró PID. ¿El servidor está iniciado?"
    fi
}

case "$1" in
    detener|stop)
        detener
        ;;
    iniciar|start)
        iniciar
        ;;
    *)
        echo "Uso: streamio [start|stop]"
        exit 1
        ;;
esac
