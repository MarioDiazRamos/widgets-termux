"""
Agente de voz para Termux con integración de Gemini y TTS/STT.

Este módulo proporciona un agente conversacional de voz que permite:
- Conversión de texto a voz (TTS) usando termux-tts-speak
- Conversión de voz a texto (STT) usando termux-speech-to-text
- Procesamiento inteligente con API de Gemini
- Ejecución segura de comandos del sistema
- Interfaz de comandos por voz

Requiere permisos de micrófono y Termux:API instalado.
"""

import json
import os
import shlex
import subprocess
import sys
import time

import requests

# === CONFIGURACIÓN ===
CONFIG_PATH = os.path.expanduser("~/.agentevoz_config.json")


def pedir_api_key():
    """
    Solicita al usuario su API key de Google Gemini de forma interactiva.

    Returns:
        str: La API key proporcionada por el usuario.
    """
    print("\nPara usar el agente de voz necesitas tu propia API key de Gemini.")
    print("1. Ve a https://aistudio.google.com/app/apikey")
    print("2. Genera tu clave y pégala aquí.")
    api = input("Pega tu API key: ").strip()
    if not api:
        print("No se ingresó clave. Saliendo.")
        sys.exit(1)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump({"API_KEY": api}, f)
    return api


def cargar_api_key():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, encoding="utf-8") as f:
                return json.load(f)["API_KEY"]
        except (KeyError, json.JSONDecodeError, IOError):
            # Si el archivo está corrupto o no tiene la clave, lo regeneramos
            print("Archivo de configuración inválido, solicitando nueva API key...")
    return pedir_api_key()


API_KEY = cargar_api_key()
MODELO = "gemini-2.0-flash"
BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
URL = f"{BASE_URL}/{MODELO}:generateContent?key={API_KEY}"
ROJO = "\033[0;31m"
VERDE = "\033[0;32m"
AMARILLO = "\033[1;33m"
AZUL = "\033[0;34m"
MORADO = "\033[0;35m"
CYAN = "\033[0;36m"
SIN_COLOR = "\033[0m"
PROMPT_SISTEMA = (
    "Eres un agente de voz en Termux Android. "
    "Convierte instrucciones de voz en comandos ejecutables. "
    "Responde solo con comandos válidos para Termux o termux-api, "
    "sin explicaciones ni markdown. "
    "No uses tuberías, awk, grep, jq ni expresiones complejas. "
    "Si no puedes hacerlo, responde: echo 'No puedo hacerlo en Termux/Android'. "
    "Comandos simples, seguros y ejecutables."
)

# === FUNCIONES DE VOZ ===


def verificar_termux_api():
    try:
        subprocess.run(["termux-tts-speak", "--help"], capture_output=True, timeout=5)
        return True
    except Exception:
        return False


def hablar(texto, velocidad=1.0):
    try:
        # Eliminar códigos de color del texto
        colores = [ROJO, VERDE, AMARILLO, AZUL, MORADO, CYAN, SIN_COLOR]
        texto_limpio = texto
        for color in colores:
            texto_limpio = texto_limpio.replace(color, "")
        subprocess.run(
            ["termux-tts-speak", "-l", "es-ES", "-r", str(velocidad), texto_limpio],
            timeout=10,
        )
        return True
    except Exception as e:
        print(f"{ROJO}Error en síntesis de voz: {e}{SIN_COLOR}")
        return False


def escuchar_voz():
    print(f"{CYAN}Escuchando...{SIN_COLOR}")
    hablar("Te escucho")
    try:
        result = subprocess.run(
            ["termux-speech-to-text", "-l", "es-ES"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode == 0 and result.stdout.strip():
            texto = result.stdout.strip()
            print(f"{VERDE}Escuché: {texto}{SIN_COLOR}")
            return texto
        print(f"{AMARILLO}No pude entender lo que dijiste{SIN_COLOR}")
        hablar("No pude entenderte, repite por favor")
        return None
    except subprocess.TimeoutExpired:
        print(f"{AMARILLO}Tiempo de espera agotado{SIN_COLOR}")
        hablar("No escuché nada")
        return None
    except Exception as e:
        print(f"{ROJO}Error en reconocimiento de voz: {e}{SIN_COLOR}")
        hablar("Error en el micrófono")
        return None


def mostrar_comandos_voz():
    ejemplos = [
        "Música y YouTube:",
        "  - 'abre youtube con despacito'",
        "  - 'pon música de rock'",
        "  - 'busca videos de gatos'",
        "Aplicaciones:",
        "  - 'abre whatsapp'",
        "  - 'abre telegram'",
        "  - 'abre la cámara'",
        "Sistema:",
        "  - 'dime la batería'",
        "  - 'vibra el teléfono'",
        "  - 'toma una foto'",
        "  - 'graba audio'",
        "Control:",
        "  - 'ayuda' o 'comandos'",
        "  - 'salir' o 'exit'",
    ]
    print(f"\n{AZUL}Comandos de Voz Disponibles:{SIN_COLOR}")
    for ejemplo in ejemplos:
        print(ejemplo)
    print()


def pedir_comando(prompt):
    data = {
        "contents": [{"parts": [{"text": PROMPT_SISTEMA + "\nUsuario: " + prompt}]}]
    }
    try:
        r = requests.post(
            URL,
            headers={"Content-Type": "application/json"},
            data=json.dumps(data),
            timeout=10,
        )
        r.raise_for_status()
        response = r.json()
    except Exception as e:
        return None, f"Error al conectar con la API: {e}"
    if "candidates" not in response:
        resp_dump = json.dumps(response, indent=2)
        return None, f"Respuesta inválida de la API:\n{resp_dump}"
    # Obtener el comando del texto de la respuesta
    content = response["candidates"][0]["content"]
    parts = content["parts"][0]
    cmd = parts["text"].strip()
    return cmd, None


def ejecutar_comando(cmd):
    peligrosos = ["rm -rf", "mkfs", ":(){:|:&};:", "dd if=", ">:", "format", "delete"]
    if any(p in cmd.lower() for p in peligrosos):
        return "Comando bloqueado por seguridad."
    try:
        # Usar siempre shlex.split() para evitar inyección de comandos
        if cmd.startswith(("termux-", "am start", "pm ")):
            result = subprocess.run(
                shlex.split(cmd), capture_output=True, text=True, timeout=30
            )
        else:
            result = subprocess.run(
                shlex.split(cmd), capture_output=True, text=True, timeout=20
            )
        salida = result.stdout.strip()
        error = result.stderr.strip()
        if result.returncode == 0:
            if salida == "" and error == "":
                return "Comando ejecutado correctamente."
            return (salida if salida else "") + ("\n" + error if error else "")
        error_msg = error if error else "Sin mensaje de error"
        return f"Error (código {result.returncode}): {error_msg}"
    except subprocess.TimeoutExpired:
        return "El comando tardó demasiado y fue interrumpido."
    except Exception as e:
        return f"Error ejecutando el comando: {e}"


def _manejar_comandos_especiales(texto_voz):
    """Maneja comandos especiales como ayuda o salir."""
    if any(palabra in texto_voz.lower() for palabra in ["ayuda", "comandos", "help"]):
        mostrar_comandos_voz()
        hablar("Te muestro los comandos disponibles")
        return "help"

    palabras_salida = ["salir", "exit", "cerrar", "terminar"]
    if any(palabra in texto_voz.lower() for palabra in palabras_salida):
        print(f"{VERDE}Cerrando agente de voz...{SIN_COLOR}")
        hablar("Hasta luego")
        return "exit"

    return None


def _es_comando_seguro(cmd):
    """Verifica si un comando es considerado seguro para ejecución automática."""
    comandos_seguros = [
        "termux-battery-status",
        "termux-vibrate",
        "termux-open-url",
        "echo",
    ]
    return cmd and any(cmd.startswith(seguro) for seguro in comandos_seguros)


def _obtener_confirmacion_usuario():
    """Solicita confirmación del usuario por voz."""
    print(f"{AMARILLO}¿Ejecutar este comando? Di 'sí' o 'no'{SIN_COLOR}")
    hablar("¿Ejecuto este comando?")
    confirmacion = escuchar_voz()

    palabras_confirmacion = ["sí", "si", "ok", "dale", "hazlo", "ejecuta"]
    if confirmacion and any(
        palabra in confirmacion.lower() for palabra in palabras_confirmacion
    ):
        print(f"{VERDE}Confirmado por voz{SIN_COLOR}")
        return True
    else:
        print(f"{AMARILLO}Cancelado{SIN_COLOR}")
        hablar("Comando cancelado")
        return False


def _ejecutar_y_reportar_comando(cmd):
    """Ejecuta el comando y reporta el resultado al usuario."""
    print(f"{CYAN}Ejecutando...{SIN_COLOR}")
    salida = ejecutar_comando(cmd)
    print(f"{VERDE}Resultado: {salida}{SIN_COLOR}")

    if "ejecutado correctamente" in salida:
        hablar("Comando ejecutado correctamente")
    elif "error" in salida:
        hablar("Hubo un error al ejecutar el comando")
    elif "advertencia" in salida:
        hablar("Comando ejecutado con advertencias")
    else:
        resultado_corto = salida[:100] if len(salida) > 100 else salida
        hablar(f"Resultado: {resultado_corto}")


def procesar_comando_voz(texto_voz):
    # Manejar comandos especiales primero
    resultado_especial = _manejar_comandos_especiales(texto_voz)
    if resultado_especial:
        return resultado_especial

    # Procesar comando normal
    print(f"{AZUL}Procesando: {texto_voz}{SIN_COLOR}")
    hablar("Procesando tu solicitud")

    cmd, error = pedir_comando(texto_voz)
    if error:
        print(f"{ROJO}{error}{SIN_COLOR}")
        hablar("Error al procesar tu solicitud")
        return

    print(f"{MORADO}Comando sugerido: {cmd}{SIN_COLOR}")

    # Determinar si necesita confirmación
    if _es_comando_seguro(cmd):
        confirmar = True
        print(f"{VERDE}Ejecutando automáticamente (comando seguro){SIN_COLOR}")
    elif cmd:
        confirmar = _obtener_confirmacion_usuario()
    else:
        confirmar = False

    # Ejecutar si está confirmado
    if confirmar and cmd:
        _ejecutar_y_reportar_comando(cmd)


def main():
    print(f"{CYAN}Agente de Voz Termux-Android Iniciado{SIN_COLOR}")
    print("=" * 45)
    if not verificar_termux_api():
        print(f"{ROJO}termux-api no está instalado o no funciona{SIN_COLOR}")
        print(f"{AMARILLO}Instala con: pkg install termux-api{SIN_COLOR}")
        print(f"{AMARILLO}Asegúrate de tener la app Termux:API instalada{SIN_COLOR}")
        return
    print(f"{VERDE}termux-api detectado correctamente{SIN_COLOR}")
    hablar("Agente de voz listo")
    mostrar_comandos_voz()
    instruccion = "Di 'empezar' para activar el micrófono o 'salir' para terminar"
    print(f"{CYAN}{instruccion}{SIN_COLOR}")
    while True:
        try:
            prompt = f"\n{AZUL}>> Presiona Enter para hablar (o escribe 'salir'): {SIN_COLOR}"
            entrada = input(prompt)
            if entrada.lower().strip() in ["salir", "exit", "quit"]:
                print(f"{VERDE}Hasta luego{SIN_COLOR}")
                hablar("Hasta luego")
                break
            texto_voz = escuchar_voz()
            if texto_voz:
                resultado = procesar_comando_voz(texto_voz)
                if resultado == "exit":
                    break
            time.sleep(0.5)
        except KeyboardInterrupt:
            print(f"\n{AMARILLO}Interrupción del usuario{SIN_COLOR}")
            hablar("Interrupción del usuario")
            break
        except Exception as e:
            print(f"{ROJO}Error inesperado: {e}{SIN_COLOR}")
            hablar("Error inesperado")


def modo_continuo():
    msg = "Modo continuo activado - di 'agente' para activar"
    print(f"{MORADO}{msg}{SIN_COLOR}")
    hablar("Modo continuo activado, di agente para hablar conmigo")
    while True:
        try:
            audio = escuchar_voz()
            if audio and "agente" in audio.lower():
                hablar("¿Qué necesitas?")
                comando = escuchar_voz()
                if comando:
                    resultado = procesar_comando_voz(comando)
                    if resultado == "exit":
                        break
            time.sleep(1)
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"{ROJO}Error en modo continuo: {e}{SIN_COLOR}")
            time.sleep(2)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--continuo":
        modo_continuo()
    else:
        main()
