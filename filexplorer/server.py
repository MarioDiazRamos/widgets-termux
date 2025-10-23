
import os
import subprocess
import threading
from pathlib import Path
from datetime import datetime
from flask import Flask, jsonify, send_from_directory, request

aplicacion = Flask(__name__, static_url_path='/static')
DIRECTORIO_RAIZ = Path.home()
EXTENSIONES_TEXTO = ['.txt', '.log', '.sh', '.py', '.js', '.css', '.html', '.md', '.json', '.yaml', '.yml', '.cfg', '.conf']
DIRECTORIO_TEMP = Path(__file__).parent / 'temp'
DIRECTORIO_TEMP.mkdir(exist_ok=True)
DIRECTORIO_RESULTADOS = DIRECTORIO_TEMP

def es_archivo_texto(nombre):
    return Path(nombre).suffix.lower() in EXTENSIONES_TEXTO

# --- Endpoints existentes (sin cambios) ---

@aplicacion.route('/api/lista')
def listar_directorio():
    try:
        ruta = request.args.get('path', '')
        ruta_segura = Path(DIRECTORIO_RAIZ, ruta).resolve()
        if not ruta_segura.is_relative_to(DIRECTORIO_RAIZ):
            return jsonify({'error': 'Acceso denegado.'}), 403
        elementos = []
        for elemento in ruta_segura.iterdir():
            if elemento.is_dir():
                elementos.append({
                    'nombre': elemento.name,
                    'tipo': 'carpeta',
                    'ruta': str(elemento.relative_to(DIRECTORIO_RAIZ)),
                })
            elif elemento.is_file():
                try:
                    tam = elemento.stat().st_size
                    mod = datetime.fromtimestamp(elemento.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                except Exception:
                    tam = 0
                    mod = 'N/A'
                elementos.append({
                    'nombre': elemento.name,
                    'tipo': 'archivo',
                    'ruta': str(elemento.relative_to(DIRECTORIO_RAIZ)),
                    'tamano': tam,
                    'modificado': mod,
                    'es_texto': es_archivo_texto(elemento.name)
                })
        elementos.sort(key=lambda x: (x['tipo'] != 'carpeta', x['nombre'].lower()))
        return jsonify({'ruta_actual': str(ruta_segura.relative_to(DIRECTORIO_RAIZ)), 'elementos': elementos})
    
    except FileNotFoundError:
        return jsonify({'error': 'Ruta no encontrada.'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@aplicacion.route('/api/leer_archivo')
def leer_archivo():
    try:
        ruta = request.args.get('path', '')
        ruta_segura = Path(DIRECTORIO_RAIZ, ruta).resolve()
        if not ruta_segura.is_relative_to(DIRECTORIO_RAIZ) or not ruta_segura.is_file():
            return jsonify({'error': 'Archivo no válido.'}), 403
        if not es_archivo_texto(ruta_segura.name):
            return jsonify({'error': 'Este tipo de archivo no se puede editar.'}), 400
        with open(ruta_segura, 'r', encoding='utf-8') as f:
            contenido = f.read()
        return jsonify({'contenido': contenido})
    except FileNotFoundError:
        return jsonify({'error': 'Archivo no encontrado.'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@aplicacion.route('/api/guardar_archivo', methods=['POST'])
def guardar_archivo():
    try:
        datos = request.json
        ruta = datos.get('path', '')
        contenido = datos.get('content', '')
        ruta_segura = Path(DIRECTORIO_RAIZ, ruta).resolve()
        if not ruta_segura.is_relative_to(DIRECTORIO_RAIZ) or not ruta_segura.is_file():
            return jsonify({'error': 'Ruta no válida.'}), 403
        if not es_archivo_texto(ruta_segura.name):
            return jsonify({'error': 'Este tipo de archivo no se puede editar.'}), 400
        with open(ruta_segura, 'w', encoding='utf-8') as f:
            f.write(contenido)
        return jsonify({'mensaje': 'Archivo guardado con éxito.', 'exito': True})
    except Exception as e:
        return jsonify({'error': str(e), 'exito': False}), 500

@aplicacion.route('/api/abrir_externo')
def abrir_externo():
    try:
        ruta = request.args.get('path', '')
        ruta_segura = Path(DIRECTORIO_RAIZ, ruta).resolve()
        if not ruta_segura.is_relative_to(DIRECTORIO_RAIZ) or not ruta_segura.is_file():
            return jsonify({'error': 'Archivo no válido.'}), 403
        subprocess.run(['termux-open', str(ruta_segura)], check=True)
        return jsonify({'mensaje': 'Comando de apertura ejecutado.', 'exito': True})
    except FileNotFoundError:
        return jsonify({'error': 'Archivo no encontrado.'}), 404
    except Exception as e:
        return jsonify({'error': f'Error al intentar abrir el archivo: {str(e)}', 'exito': False}), 500


def ejecutar_busqueda(consulta, id_trabajo, es_regex):
    archivo_resultados = DIRECTORIO_RESULTADOS / f'{id_trabajo}.json'
    try:
        cmd = ['rg']
        if not es_regex:
            cmd.append('-F')
        cmd.extend([consulta, str(DIRECTORIO_RAIZ)])
        resultado = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lineas = resultado.stdout.strip().split('\n')
        resultados = []
        for linea in lineas:
            partes = linea.split(':', 2)
            if len(partes) >= 3:
                resultados.append({'archivo': partes[0], 'linea': partes[1], 'coincidencia': partes[2]})
    except FileNotFoundError:
        cmd = ['grep', '-n', '-r', '-F', consulta, str(DIRECTORIO_RAIZ)]
        resultado = subprocess.run(cmd, capture_output=True, text=True)
        lineas = resultado.stdout.strip().split('\n')
        resultados = []
        for linea in lineas:
            partes = linea.split(':', 2)
            if len(partes) >= 3:
                resultados.append({'archivo': partes[0], 'linea': partes[1], 'coincidencia': partes[2]})
    except Exception as e:
        resultados = [{'error': str(e)}]
    with open(archivo_resultados, 'w') as f:
        import json
        json.dump(resultados, f)


@aplicacion.route('/api/buscar', methods=['GET'])
def iniciar_busqueda():
    consulta = request.args.get('query', '')
    es_regex = request.args.get('regex', 'false').lower() == 'true'
    if not consulta:
        return jsonify({'error': 'La consulta no puede estar vacía.'}), 400
    id_trabajo = os.urandom(16).hex()
    hilo = threading.Thread(target=ejecutar_busqueda, args=(consulta, id_trabajo, es_regex))
    hilo.start()
    return jsonify({'id_trabajo': id_trabajo})

@aplicacion.route('/api/resultados_busqueda/<id_trabajo>')
def obtener_resultados_busqueda(id_trabajo):
    archivo_resultados = DIRECTORIO_RESULTADOS / f'{id_trabajo}.json'
    if not archivo_resultados.exists():
        return jsonify({'estado': 'pendiente'})
    try:
        with open(archivo_resultados, 'r') as f:
            import json
            resultados = json.load(f)
        return jsonify({'estado': 'completado', 'resultados': resultados})
    except Exception as e:
        return jsonify({'estado': 'error', 'mensaje': str(e)})


# --- Endpoint principal de la UI (sin cambios) ---

@aplicacion.route('/')
def servir_index():
    return send_from_directory('static', 'index.html')

if __name__ == '__main__':
    aplicacion.run(host='0.0.0.0', port=5000)
