"""
Servidor de streaming para torrents - Alternativa a Stremio.

Este servidor proporciona una API REST para buscar y hacer streaming de torrents
usando varios scrapers y peerflix como backend de streaming.

Endpoints principales:
- GET /search?q=<query>: Busca torrents en múltiples fuentes
- GET /stream?magnet=<magnet>: Inicia streaming de un torrent
- GET /static/<file>: Sirve archivos estáticos

Funcionalidades:
- Búsqueda distribuida en múltiples scrapers (YTS, 1337x, TPB)
- Streaming directo usando peerflix
- Selección automática del mejor archivo
- Limpieza automática de archivos temporales
- CORS habilitado para uso desde navegador
"""

# Servidor principal Streamio (alternativa a Stremio+Torrentio)
# Clean code, español, Flask, integración bash, torrent y scrapers
import os
import re
import socket
import subprocess
import threading
import time
import logging
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from scrapers import yts, tpb, x1337

app = Flask(__name__, static_folder="static", static_url_path="/static")
CORS(app)


TEMP_DIR = os.path.join(os.path.dirname(__file__), "temp")
os.makedirs(TEMP_DIR, exist_ok=True)
logging.basicConfig(filename=os.path.join(TEMP_DIR, "error.log"), level=logging.ERROR)
logging.basicConfig(filename=os.path.join(TEMP_DIR, "error.log"), level=logging.ERROR)


# --- API de búsqueda ---
def _buscar_en_scrapers(query):
    """Realiza búsqueda en todos los scrapers disponibles."""
    resultados = []
    resultados += yts.buscar(query)
    resultados += tpb.buscar(query)
    resultados += x1337.buscar(query)
    return resultados


def _normalizar_resultados(resultados):
    """Normaliza los campos de los resultados de búsqueda."""
    for r in resultados:
        if "fuente" not in r:
            r["fuente"] = "YTS"
        if "tipo" not in r:
            r["tipo"] = "pelicula"
        if "year" not in r:
            r["year"] = ""
    return resultados


def _agrupar_por_fuente_y_tipo(resultados):
    """Agrupa los resultados por fuente y tipo."""
    agrupados = {}
    for r in resultados:
        fuente = r["fuente"]
        tipo = r["tipo"]
        if fuente not in agrupados:
            agrupados[fuente] = {}
        if tipo not in agrupados[fuente]:
            agrupados[fuente][tipo] = []
        agrupados[fuente][tipo].append(r)
    return agrupados


def _ordenar_resultados_agrupados(agrupados):
    """Ordena cada grupo por seeds y año."""
    for fuente in agrupados:
        for tipo in agrupados[fuente]:
            agrupados[fuente][tipo].sort(
                key=lambda x: (int(x.get("seeds", 0)), x.get("year", "")), reverse=True
            )
    return agrupados


@app.route("/search")
def search():
    q = request.args.get("q", "")
    if not q:
        return jsonify({"error": "Falta parámetro q"}), 400

    # Pipeline de procesamiento de búsqueda
    resultados = _buscar_en_scrapers(q)
    resultados = _normalizar_resultados(resultados)
    agrupados = _agrupar_por_fuente_y_tipo(resultados)
    agrupados = _ordenar_resultados_agrupados(agrupados)

    return jsonify(agrupados)


# --- API de streaming ---
def _obtener_lista_archivos(magnet):
    """Obtiene la lista de archivos del magnet y selecciona el mejor."""
    try:
        list_cmd = ["peerflix", magnet, "--list"]
        list_out = subprocess.check_output(list_cmd, text=True, timeout=15)
        files = [line.strip() for line in list_out.splitlines() if line.strip()]
        return files
    except Exception as e:
        logging.error("Error obteniendo lista de archivos: %s", e)
        return []


def _seleccionar_archivo_principal(files):
    """Selecciona el mejor archivo de la lista, priorizando .mp4/.webm."""
    if not files:
        return "", 0, ""

    main_file = files[0]
    file_idx = 0

    # Priorizar archivos .mp4 y .webm
    for i, fname in enumerate(files):
        if fname.lower().endswith(".mp4") or fname.lower().endswith(".webm"):
            main_file = fname
            file_idx = i
            break

    ext = os.path.splitext(main_file)[1].lower()
    return main_file, file_idx, ext


def _obtener_ip_local():
    """Obtiene la IP local del sistema (no localhost)."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip_local = s.getsockname()[0]
        s.close()
        return ip_local
    except Exception:
        return "127.0.0.1"


def _generar_respuesta_stream(ip_local, port, ext):
    """Genera la respuesta JSON para el stream."""
    url = f"http://{ip_local}:{port}"
    compatible = ext in [".mp4", ".webm"]

    mensaje = (
        "Formato compatible para navegador"
        if compatible
        else "Este formato puede no reproducirse en el navegador. "
        "Usa VLC si hay problemas."
    )

    return jsonify(
        {
            "url": url,
            "compatible": compatible,
            "ext": ext,
            "msg": mensaje,
        }
    )


@app.route("/stream")
def stream():
    magnet = request.args.get("magnet", "")
    if not magnet:
        return jsonify({"error": "Falta magnet"}), 400

    try:
        # Obtener y seleccionar archivo
        files = _obtener_lista_archivos(magnet)
        _, file_idx, ext = _seleccionar_archivo_principal(files)

        # Lanzar peerflix con el archivo seleccionado
        port = _lanzar_peerflix_idx(magnet, file_idx)
        if not port:
            logging.error("No se pudo iniciar stream para magnet: %s", magnet)
            return jsonify({"error": "No se pudo iniciar stream"}), 500

        # Obtener IP y generar respuesta
        ip_local = _obtener_ip_local()
        return _generar_respuesta_stream(ip_local, port, ext)

    except Exception as e:
        logging.error("Error en /stream: %s", e)
        return jsonify({"error": "Error interno en el servidor"}), 500


def _obtener_puerto_libre():
    """Obtiene un puerto disponible del sistema."""
    s = socket.socket()
    s.bind(("", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def _construir_comando_peerflix(magnet, port, file_idx=None):
    """Construye el comando base para peerflix."""
    cmd = [
        "peerflix",
        magnet,
        "--port",
        str(port),
        "--path",
        TEMP_DIR,
        "--hostname",
        "0.0.0.0",
        "--remove",
    ]
    if file_idx is not None:
        cmd.extend(["--file", str(file_idx)])
    return cmd


def _detectar_puerto_real(proc, port_fallback, timeout=10):
    """Detecta el puerto real desde la salida de peerflix."""
    if not proc.stdout:
        return port_fallback

    start = time.time()
    while time.time() - start < timeout:
        line = proc.stdout.readline()
        if not line:
            time.sleep(0.1)
            continue
        m = re.search(r"network address.*:(\d+)", line)
        if m:
            return int(m.group(1))
    return port_fallback


def _cleanup_temp_files():
    """Limpia archivos temporales en un hilo separado."""

    def cleanup():
        try:
            for root, _, files in os.walk(TEMP_DIR):
                for f in files:
                    os.remove(os.path.join(root, f))
        except Exception as e:
            logging.error("Error limpiando archivos temporales: %s", e)

    threading.Thread(target=cleanup, daemon=True).start()


def _lanzar_peerflix_idx(magnet, file_idx):
    port = _obtener_puerto_libre()
    cmd = _construir_comando_peerflix(magnet, port, file_idx)

    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        real_port = _detectar_puerto_real(proc, port)
        _cleanup_temp_files()
        return real_port
    except Exception as e:
        logging.error("Error en _lanzar_peerflix_idx: %s", e)
        return None


def _lanzar_peerflix(magnet):
    """Lanza peerflix y detecta el puerto real desde la salida."""
    port = _obtener_puerto_libre()
    cmd = _construir_comando_peerflix(magnet, port)

    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        real_port = _detectar_puerto_real(proc, port)
        _cleanup_temp_files()
        return real_port
    except Exception as e:
        logging.error("Error en _lanzar_peerflix: %s", e)
        return None


# --- UI principal y archivos estáticos ---
@app.route("/")
def index():
    return send_from_directory("static", "index.html")


@app.route("/app.js")
def app_js():
    return send_from_directory("static", "app.js")


@app.route("/style.css")
def style_css():
    return send_from_directory("static", "style.css")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
