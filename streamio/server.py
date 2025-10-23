# Servidor principal Streamio (alternativa a Stremio+Torrentio)
# Clean code, español, Flask, integración bash, torrent y scrapers
import os
import re
import socket
import subprocess
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
@app.route("/search")
def search():
    q = request.args.get("q", "")
    if not q:
        return jsonify({"error": "Falta parámetro q"}), 400
    # Buscar en scrapers
    resultados = []
    resultados += yts.buscar(q)
    resultados += tpb.buscar(q)
    resultados += x1337.buscar(q)
    # Normalizar fuente
    for r in resultados:
        if "fuente" not in r:
            r["fuente"] = "YTS"
        if "tipo" not in r:
            r["tipo"] = "pelicula"
        if "year" not in r:
            r["year"] = ""
    # Agrupar por fuente y tipo
    agrupados = {}
    for r in resultados:
        fuente = r["fuente"]
        tipo = r["tipo"]
        if fuente not in agrupados:
            agrupados[fuente] = {}
        if tipo not in agrupados[fuente]:
            agrupados[fuente][tipo] = []
        agrupados[fuente][tipo].append(r)
    # Ordenar cada grupo por seeds y año
    for fuente in agrupados:
        for tipo in agrupados[fuente]:
            agrupados[fuente][tipo].sort(
                key=lambda x: (int(x.get("seeds", 0)), x.get("year", "")), reverse=True
            )
    return jsonify(agrupados)


# --- API de streaming ---
@app.route("/stream")
def stream():
    magnet = request.args.get("magnet", "")
    if not magnet:
        return jsonify({"error": "Falta magnet"}), 400
    try:
        # Obtener lista de archivos y priorizar .mp4/.webm
        list_cmd = ["peerflix", magnet, "--list"]
        try:
            list_out = subprocess.check_output(list_cmd, text=True, timeout=15)
            files = [line.strip() for line in list_out.splitlines() if line.strip()]
            main_file = files[0] if files else ""
            file_idx = 0
            for i, fname in enumerate(files):
                if fname.lower().endswith(".mp4") or fname.lower().endswith(".webm"):
                    main_file = fname
                    file_idx = i
                    break
            ext = os.path.splitext(main_file)[1].lower()
        except Exception as e:
            logging.error(f"Error obteniendo lista de archivos: {e}")
            ext = ""
            file_idx = 0
        # Lanzar peerflix con el archivo seleccionado
        port = _lanzar_peerflix_idx(magnet, file_idx)
        if not port:
            logging.error(f"No se pudo iniciar stream para magnet: {magnet}")
            return jsonify({"error": "No se pudo iniciar stream"}), 500
        # Obtener IP local (no localhost)
        import socket

        ip_local = None
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip_local = s.getsockname()[0]
            s.close()
        except Exception:
            ip_local = "127.0.0.1"
        url = f"http://{ip_local}:{port}"
        compatible = ext in [".mp4", ".webm"]
        return jsonify(
            {
                "url": url,
                "compatible": compatible,
                "ext": ext,
                "msg": (
                    "Formato compatible para navegador"
                    if compatible
                    else "Este formato puede no reproducirse en el navegador. "
                         "Usa VLC si hay problemas."
                ),
            }
        )
    except Exception as e:
        logging.error(f"Error en /stream: {e}")
        return jsonify({"error": "Error interno en el servidor"}), 500


def _lanzar_peerflix_idx(magnet, file_idx):
    import socket

    s = socket.socket()
    s.bind(("", 0))
    port = s.getsockname()[1]
    s.close()
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
        "--file",
        str(file_idx),
    ]
    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        real_port = None
        start = time.time()
        if proc.stdout:
            while time.time() - start < 10:
                line = proc.stdout.readline()
                if not line:
                    time.sleep(0.1)
                    continue
                m = re.search(r"network address.*:(\d+)", line)
                if m:
                    real_port = int(m.group(1))
                    break
        if not real_port:
            real_port = port

        def cleanup_temp():
            try:
                for root, dirs, files in os.walk(TEMP_DIR):
                    for f in files:
                        os.remove(os.path.join(root, f))
            except Exception as e:
                logging.error(f"Error limpiando archivos temporales: {e}")

        import threading

        threading.Thread(target=cleanup_temp, daemon=True).start()
        return real_port
    except Exception as e:
        logging.error(f"Error en _lanzar_peerflix_idx: {e}")
        return None


def _lanzar_peerflix(magnet):
    # Lanza peerflix y detecta el puerto real desde la salida

    s = socket.socket()
    s.bind(("", 0))
    port = s.getsockname()[1]
    s.close()
    cmd = [
        "peerflix",
        magnet,
        "--port",
        str(port),
        "--path",
        TEMP_DIR,
        "--hostname",
        "0.0.0.0",
        "--remove",  # Elimina archivos temporales al terminar
    ]
    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        # Leer la salida para detectar el puerto real
        real_port = None
        start = time.time()
        if proc.stdout:
            while time.time() - start < 10:
                line = proc.stdout.readline()
                if not line:
                    time.sleep(0.1)
                    continue
                m = re.search(r"network address.*:(\d+)", line)
                if m:
                    real_port = int(m.group(1))
                    break
        if not real_port:
            real_port = port

        # Limpieza automática de archivos temporales después de cada stream
        def cleanup_temp():
            try:
                for root, dirs, files in os.walk(TEMP_DIR):
                    for f in files:
                        os.remove(os.path.join(root, f))
            except Exception as e:
                logging.error(f"Error limpiando archivos temporales: {e}")

        import threading

        threading.Thread(target=cleanup_temp, daemon=True).start()
        # Dejar peerflix corriendo en background
        return real_port
    except Exception as e:
        logging.error(f"Error en _lanzar_peerflix: {e}")
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
