#!/data/data/com.termux/files/usr/bin/sh
set -eu

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV="$APP_DIR/.venv"
LOG_DIR="$APP_DIR/logs"
PID_FILE="$APP_DIR/server.pid"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-5000}"

ensure_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Python no está instalado. En Termux: pkg install -y python"
    exit 1
  fi
}

ensure_venv() {
  if [ ! -d "$VENV" ]; then
    echo "Creando entorno virtual..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --upgrade pip wheel
  fi
}

install_deps() {
  # Instalar dependencias solo si no están presentes
  if ! "$VENV/bin/pip" show flask >/dev/null 2>&1; then
    echo "Instalando dependencias..."
    "$VENV/bin/pip" install --upgrade flask
  fi
}

start() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Ya está en ejecución con PID $(cat "$PID_FILE")"
    exit 0
  fi
  mkdir -p "$LOG_DIR"
  ensure_python
  ensure_venv
  install_deps
  # Obtener IP local usando ifconfig (wlan0, eth0)
  IP_MANUAL="${IP_MANUAL:-}"
  if [ -n "$IP_MANUAL" ]; then
    IP_LOCAL="$IP_MANUAL"
  elif command -v ifconfig >/dev/null 2>&1; then
    IP_LOCAL=$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2}' | head -n1)
    [ -z "$IP_LOCAL" ] && IP_LOCAL="127.0.0.1"
  else
    IP_LOCAL="127.0.0.1"
  fi
  if [ "$IP_LOCAL" = "127.0.0.1" ]; then
    echo "No se pudo obtener la IP de red. Usa IP_MANUAL=tu_ip devenv start para definirla manualmente."
  fi
  echo "Iniciando servidor en $HOST:$PORT ..."
  echo "Accede desde cualquier dispositivo: http://$IP_LOCAL:$PORT"
  echo "Acceso local: http://127.0.0.1:$PORT"
  HOST="$HOST" PORT="$PORT" FLASK_ENV=development \
    "$VENV/bin/python" "$APP_DIR/server.py" \
    >> "$LOG_DIR/app.out" 2>> "$LOG_DIR/app.err" &
  echo $! > "$PID_FILE"
  echo "Iniciado. PID $(cat "$PID_FILE"). Logs: $LOG_DIR"
  echo "Para detener: devenv stop ó devenv.sh stop"
  if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "http://127.0.0.1:$PORT"
  fi
}

stop() {
  if [ -f "$PID_FILE" ]; then
    PID="$(cat "$PID_FILE")"
    if kill -0 "$PID" 2>/dev/null; then
      echo "Deteniendo PID $PID..."
      kill "$PID"
      sleep 1
      if kill -0 "$PID" 2>/dev/null; then
        echo "Forzando detención..."
        kill -9 "$PID" || true
      fi
    fi
    rm -f "$PID_FILE"
    echo "Detenido."
  else
    echo "No hay PID registrado. ¿Está corriendo?"
  fi
}

status() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "En ejecución. PID $(cat "$PID_FILE")."
  else
    echo "No está en ejecución."
    exit 1
  fi
}

logs() {
  echo "Mostrando últimas líneas de logs (Ctrl+C para salir):"
  tail -n 200 -f "$LOG_DIR/app.out" "$LOG_DIR/app.err"
}

usage() {
  echo "Uso: devenv {start|stop|status|logs}"
}

cmd="${1:-}"
case "$cmd" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  logs) logs ;;
  *) usage; exit 1 ;;
esac
