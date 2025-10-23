import os
import shlex
import uuid
import time
import pathlib
import threading
import subprocess
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

# Configuración
DESCARGAS = os.path.expanduser("/storage/emulated/0/Download")
VIDEOS = os.path.expanduser("/storage/emulated/0/Movies/Finales")
DESTINO = VIDEOS
HOST = "0.0.0.0"
PUERTO = 8080

app = Flask(__name__, static_folder="static", static_url_path="/static")
CORS(app)

TRABAJOS = {}
BLOQUEO_TRABAJOS = threading.Lock()

# Carpeta interna para logs y temporales
DIR_TEMP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "temp")
os.makedirs(DIR_TEMP, exist_ok=True)
DIR_LOGS = DIR_TEMP  # Para compatibilidad con el resto del código


# Utilidades
def listar_archivos(directorio, extensiones):
    resultado = []
    p = pathlib.Path(directorio)
    if not p.exists():
        return resultado
    for f in sorted(p.iterdir()):
        if f.is_file() and any(f.name.lower().endswith(ext) for ext in extensiones):
            resultado.append({"nombre": f.name, "ruta": str(f)})
    return resultado


def ruta_valida(ruta, permitidos):
    abspath = os.path.abspath(ruta)
    for d in permitidos:
        if os.path.commonpath([abspath, os.path.abspath(d)]) == os.path.abspath(d):
            if os.path.exists(abspath):
                return abspath
    return None


def ejecutar_subproceso(comando, id_trabajo):
    log = os.path.join(DIR_LOGS, f"{id_trabajo}.log")
    with open(log, "wb") as logf:
        proc = subprocess.Popen(comando, stdout=logf, stderr=subprocess.STDOUT)
    with BLOQUEO_TRABAJOS:
        TRABAJOS[id_trabajo]["proceso"] = proc
    proc.wait()
    with BLOQUEO_TRABAJOS:
        TRABAJOS[id_trabajo]["estado"] = "finalizado"


# Rutas API
@app.route("/")
def inicio():
    return send_from_directory("static", "index.html")


@app.route("/api/listar_audios", methods=["GET"])
def listar_audios():
    return jsonify(listar_archivos(DESCARGAS, [".m4a", ".flac"]))


@app.route("/api/listar_videos", methods=["GET"])
def listar_videos():
    return jsonify(listar_archivos(VIDEOS, [".mp4"]))


@app.route("/api/estado/<id_trabajo>", methods=["GET"])
def estado_trabajo(id_trabajo):
    with BLOQUEO_TRABAJOS:
        trabajo = TRABAJOS.get(id_trabajo)
        if not trabajo:
            return jsonify({"error": "no encontrado"}), 404
        proc = trabajo.get("proceso")
        estado = (
            "ejecutando"
            if proc and proc.poll() is None
            else trabajo.get("estado", "finalizado")
        )
        return jsonify(
            {
                "id_trabajo": id_trabajo,
                "estado": estado,
                "comando": trabajo.get("comando"),
                "salida": trabajo.get("ruta_salida"),
            }
        )


@app.route("/api/log_trabajo/<id_trabajo>", methods=["GET"])
def log_trabajo(id_trabajo):
    log = os.path.join(DIR_LOGS, f"{id_trabajo}.log")
    if os.path.exists(log):
        return send_from_directory(DIR_LOGS, f"{id_trabajo}.log")
    else:
        return jsonify({"error": "log no encontrado"}), 404


# Transponer audio sobre video
@app.route("/api/transponer", methods=["POST"])
def _buscar_archivo_video(video_name):
    """Busca un archivo de video por nombre."""
    if isinstance(video_name, str) and video_name.startswith("/"):
        return ruta_valida(video_name, [VIDEOS])

    for v in listar_archivos(VIDEOS, [".mp4"]):
        if v["nombre"] == video_name:
            return v["ruta"]
    return None


def _buscar_archivo_audio(audio_name):
    """Busca un archivo de audio por nombre."""
    if isinstance(audio_name, str) and audio_name.startswith("/"):
        return ruta_valida(audio_name, [DESCARGAS])

    for a in listar_archivos(DESCARGAS, [".m4a", ".flac"]):
        if a["nombre"] == audio_name:
            return a["ruta"]
    return None


def _tiempo_a_segundos(tiempo_str):
    """Convierte una cadena de tiempo a segundos."""
    tiempo_str = tiempo_str.strip()
    if ":" in tiempo_str:
        partes = tiempo_str.split(":")
        if len(partes) == 2:
            m = float(partes[0])
            s = float(partes[1])
            return m * 60.0 + s
    return float(tiempo_str)


def _parsear_intervalos(intervalos_str):
    """Parsea la cadena de intervalos y retorna una lista de tuplas (inicio, fin)."""
    segmentos = []
    for raw in [s.strip() for s in intervalos_str.split(",") if s.strip()]:
        if "-" not in raw:
            continue
        inicio_raw, fin_raw = raw.split("-", 1)

        try:
            ssec = _tiempo_a_segundos(inicio_raw)
            esec = _tiempo_a_segundos(fin_raw)
        except Exception:
            continue

        if esec > ssec:
            segmentos.append((ssec, esec))
    return segmentos


def _generar_filtros_audio(segmentos, ganancia):
    """Genera los filtros de audio para FFmpeg."""
    filtros = []
    cuenta = 0
    for ssec, esec in segmentos:
        inicio_ms = int(round(ssec * 1000.0))
        filtros.append(
            f"[1:a]atrim=start={ssec}:end={esec},asetpts=PTS-STARTPTS,"
            f"volume={ganancia},adelay={inicio_ms}|{inicio_ms}[s{cuenta}]"
        )
        cuenta += 1

    entradas_mix = "[0:a]" + "".join(f"[s{i}]" for i in range(cuenta))
    filtros.append(
        f"{entradas_mix}amix=inputs={cuenta+1}:duration=first:dropout_transition=0[aout]"
    )
    return ";".join(filtros)


def _construir_comando_ffmpeg(ruta_video, ruta_audio, filtro_complejo, salida, datos):
    """Construye el comando FFmpeg con los parámetros especificados."""
    calidad = datos.get("output_quality", "media")
    velocidad = datos.get("output_speed", "equilibrada")
    crf_map = {"alta": "18", "media": "23", "baja": "28"}
    preset_map = {"rapida": "veryfast", "equilibrada": "medium", "lenta": "slow"}
    crf = crf_map.get(calidad, "23")
    preset = preset_map.get(velocidad, "medium")

    return [
        "ffmpeg", "-y", "-ss", "0", "-i", ruta_video,
        "-ss", "0", "-i", ruta_audio, "-filter_complex", filtro_complejo,
        "-map", "0:v", "-map", "[aout]", "-c:v", "libx264",
        "-preset", preset, "-crf", crf, "-c:a", "aac",
        "-b:a", "192k", "-shortest", salida,
    ]


def transponer_audio():
    datos = request.json or {}
    video = datos.get("video")
    audio = datos.get("audio")
    intervalos = datos.get("intervals", "")
    ganancia = float(datos.get("overlay_gain", 1.0))

    # Buscar archivos
    ruta_video = _buscar_archivo_video(video)
    ruta_audio = _buscar_archivo_audio(audio)

    if not ruta_video or not ruta_audio:
        return jsonify({"error": "video o audio no encontrado"}), 400

    # Parsear intervalos
    segmentos = _parsear_intervalos(intervalos)
    if not segmentos:
        return jsonify({"error": "intervalos no válidos"}), 400

    # Generar filtros y comando
    filtro_complejo = _generar_filtros_audio(segmentos, ganancia)
    base = os.path.splitext(os.path.basename(ruta_audio))[0]
    salida = os.path.join(DESTINO, f"{base}_transpuesto_{int(time.time())}.mp4")
    comando = _construir_comando_ffmpeg(ruta_video, ruta_audio, filtro_complejo, salida, datos)

    # Crear trabajo
    id_trabajo = str(uuid.uuid4())
    with BLOQUEO_TRABAJOS:
        TRABAJOS[id_trabajo] = {
            "proceso": None,
            "ruta_salida": salida,
            "comando": " ".join(shlex.quote(c) for c in comando),
            "inicio": time.time(),
            "estado": "ejecutando",
        }

    threading.Thread(
        target=ejecutar_subproceso, args=(comando, id_trabajo), daemon=True
    ).start()

    return jsonify({"id_trabajo": id_trabajo, "salida": salida})


# Mezclar audio y video (karaoke)
@app.route("/api/karaoke", methods=["POST"])
def _obtener_parametros_calidad(datos):
    """Obtiene los parámetros de calidad y velocidad de codificación."""
    calidad = datos.get("output_quality", "media")
    velocidad = datos.get("output_speed", "equilibrada")
    crf_map = {"alta": "18", "media": "23", "baja": "28"}
    preset_map = {"rapida": "veryfast", "equilibrada": "medium", "lenta": "slow"}
    return crf_map.get(calidad, "23"), preset_map.get(velocidad, "medium")


def _buscar_video_para_karaoke(ruta_video):
    """Busca y valida un archivo de video para karaoke."""
    if not ruta_video:
        return None

    if isinstance(ruta_video, str) and ruta_video.startswith("/"):
        return ruta_valida(ruta_video, [VIDEOS])

    for v in listar_archivos(VIDEOS, [".mp4"]):
        if v["nombre"] == ruta_video:
            return v["ruta"]
    return None


def _construir_comando_con_video(video_completo, ruta_audio, datos, salida_final, crf, preset):
    """Construye el comando FFmpeg para mezclar video y audio."""
    opcion_sincronizar = int(datos.get("sync_option", 1))
    retardo_sincro = float(datos.get("sync_delay", 0))
    inicio_audio = float(datos.get("audio_start_sec", 0))

    comando = ["ffmpeg", "-y", "-ss", "0", "-i", video_completo, "-ss", "0", "-i", ruta_audio]

    if inicio_audio > 0:
        comando += ["-ss", str(inicio_audio)]

    # Aplicar opciones de sincronización
    if opcion_sincronizar == 1:
        comando += ["-map", "0:v:0", "-map", "1:a:0"]
    elif opcion_sincronizar == 2:
        comando += ["-ss", str(retardo_sincro), "-map", "0:v:0", "-map", "1:a:0"]
    else:
        comando += ["-itsoffset", str(retardo_sincro), "-map", "0:v:0", "-map", "1:a:0"]

    # Añadir opciones de codificación
    comando += [
        "-c:v", "libx264", "-preset", preset, "-crf", crf,
        "-c:a", "aac", "-b:a", "192k", "-shortest", salida_final,
    ]
    return comando


def _construir_comando_solo_audio(ruta_audio, datos, salida_final):
    """Construye el comando FFmpeg para procesar solo audio."""
    inicio_audio = float(datos.get("audio_start_sec", 0))
    comando = ["ffmpeg", "-y", "-ss", "0", "-i", ruta_audio]

    if inicio_audio > 0:
        comando += ["-ss", str(inicio_audio)]

    comando += ["-c:a", "aac", "-b:a", "192k", salida_final]
    return comando


def mezclar_karaoke():
    datos = request.json or {}
    audio = datos.get("audio")
    ruta_video = datos.get("video_path")

    # Buscar archivo de audio
    ruta_audio = _buscar_archivo_audio(audio)
    if not ruta_audio:
        return jsonify({"error": "audio no encontrado"}), 400

    # Generar nombre de salida
    base_nombre = os.path.splitext(os.path.basename(ruta_audio))[0]
    salida_final = os.path.join(DESTINO, f"{base_nombre}_final_{int(time.time())}.mp4")

    # Obtener parámetros de calidad
    crf, preset = _obtener_parametros_calidad(datos)

    # Construir comando según si hay video o no
    if ruta_video:
        video_completo = _buscar_video_para_karaoke(ruta_video)
        if not video_completo:
            return jsonify({"error": "video no encontrado"}), 400
        comando = _construir_comando_con_video(
            video_completo, ruta_audio, datos, salida_final, crf, preset
        )
    else:
        comando = _construir_comando_solo_audio(ruta_audio, datos, salida_final)

    # Crear y ejecutar trabajo
    id_trabajo = str(uuid.uuid4())
    with BLOQUEO_TRABAJOS:
        TRABAJOS[id_trabajo] = {
            "proceso": None,
            "ruta_salida": salida_final,
            "comando": " ".join(shlex.quote(x) for x in comando),
            "inicio": time.time(),
            "estado": "ejecutando",
        }

    threading.Thread(
        target=ejecutar_subproceso, args=(comando, id_trabajo), daemon=True
    ).start()

    return jsonify({"id_trabajo": id_trabajo, "salida": salida_final})


# Ejecución del servidor
if __name__ == "__main__":
    os.makedirs(DESCARGAS, exist_ok=True)
    os.makedirs(VIDEOS, exist_ok=True)
    os.makedirs(DESTINO, exist_ok=True)
    print(f"Servidor iniciado en {HOST}:{PUERTO}")
    app.run(host=HOST, port=PUERTO)
