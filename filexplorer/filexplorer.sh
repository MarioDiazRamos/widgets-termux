

#!/bin/bash
PROYECTO_DIR="$HOME/Proyectos/filexplorer"
PID_ARCHIVO="$PROYECTO_DIR/filexplorer.pid"
LOG_ARCHIVO="$PROYECTO_DIR/filexplorer.log"
PUERTO=5000

iniciar_servidor() {
  if [ -f "$PID_ARCHIVO" ]; then
    PID_EXISTENTE=$(cat "$PID_ARCHIVO")
    echo "El servidor ya está en ejecución. PID: $PID_EXISTENTE"
    exit 1
  fi
  echo "Iniciando servidor..."
  # Obtener IP local
  if command -v ifconfig >/dev/null 2>&1; then
    IP_LOCAL=$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2}' | head -n1)
  fi
  echo "Iniciando servidor en segundo plano..."
  if [ -n "$IP_LOCAL" ]; then
    echo "Accede desde cualquier dispositivo: http://$IP_LOCAL:$PUERTO"
  fi
  echo "Acceso local: http://127.0.0.1:$PUERTO"
  nohup python3 "$PROYECTO_DIR/server.py" > "$LOG_ARCHIVO" 2>&1 &
  echo $! > "$PID_ARCHIVO"
  echo "Logs: $LOG_ARCHIVO"
}

detener_servidor() {
  if [ ! -f "$PID_ARCHIVO" ]; then
    echo "El servidor no está en ejecución."
    exit 1
  fi
  PID=$(cat "$PID_ARCHIVO")
  if [ -z "$PID" ]; then
    echo "No se encontró PID. El servidor no está corriendo."
    rm "$PID_ARCHIVO"
    exit 1
  fi
  echo "Deteniendo servidor (PID: $PID)..."
  kill "$PID" 2>/dev/null || echo "No se pudo detener el proceso (PID: $PID). Puede que ya no esté corriendo."
  rm "$PID_ARCHIVO"
  echo "Servidor detenido."
}

case "$1" in
  iniciar|start)
    iniciar_servidor
    ;;
  detener|stop)
    detener_servidor
    ;;
  *)
    echo "Uso: explorer {start|stop}"
    exit 1
    ;;
esac
