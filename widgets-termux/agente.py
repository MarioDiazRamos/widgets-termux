# agente.py
"""
Agente de IA para Termux con integración de Gemini.

Este módulo proporciona un agente conversacional que permite interactuar
con la API de Gemini para obtener respuestas inteligentes y ejecutar
comandos de sistema de forma segura en Termux.

Funcionalidades principales:
- Configuración automática de API key
- Procesamiento de instrucciones en lenguaje natural
- Ejecución segura de comandos del sistema
- Interfaz de línea de comandos interactiva
"""
# Script principal para agente Termux con configuración interactiva de API key
# Ver código en la edición anterior (ya actualizado para pedir y guardar API key)

import json
import os
import shlex
import subprocess
import sys

import requests

# Configuración interactiva de API_KEY
CONFIG_PATH = os.path.expanduser("~/.agente_config.json")


def pedir_api_key():
    """
    Solicita al usuario su API key de Google Gemini de forma interactiva.

    Muestra instrucciones para obtener la clave y la guarda en un archivo
    de configuración local para uso futuro.

    Returns:
        str: La API key proporcionada por el usuario.

    Raises:
        SystemExit: Si el usuario no proporciona una API key válida.
    """
    print("\nPara usar el agente necesitas tu propia API key de Gemini.")
    print(
        "1. Ve a https://aistudio.google.com/app/apikey\n2. Genera tu clave y pégala aquí."
    )
    api = input("Pega tu API key: ").strip()
    if not api:
        print("No se ingresó clave. Saliendo.")
        sys.exit(1)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump({"API_KEY": api}, f)
    return api


def cargar_api_key():
    """
    Carga la API key desde el archivo de configuración.

    Intenta cargar la API key desde ~/.agente_config.json. Si el archivo
    no existe o está corrupto, solicita una nueva API key al usuario.

    Returns:
        str: La API key cargada o una nueva proporcionada por el usuario.
    """
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

PROMPT_SISTEMA = (
    "Eres un agente ejecutándose en Termux (Android). "
    "Convierte instrucciones del usuario en comandos ejecutables. "
    "Responde solo con comandos válidos para Termux o termux-api. "
    "No incluyas explicaciones ni markdown. "
    "No uses tuberías, awk, grep, jq ni expresiones complejas. "
    "Si no puedes hacerlo, responde: echo 'No puedo hacerlo en Termux/Android'. "
    "Comandos simples, seguros y de una sola línea."
)

PELIGROSOS = ["rm -rf", "mkfs", ":(){:|:&};:", "dd if=", ">:"]


def pedir_comando(instruccion):
    """
    Solicita a la API de Gemini que genere un comando basado en la instrucción.

    Args:
        instruccion (str): La instrucción del usuario en lenguaje natural.

    Returns:
        tuple: Una tupla (respuesta, error) donde:
            - respuesta (str|None): La respuesta de la API o None si hay error
            - error (str|None): Mensaje de error o None si es exitoso
    """
    datos = {
        "contents": [
            {"parts": [{"text": PROMPT_SISTEMA + "\nUsuario: " + instruccion}]}
        ]
    }
    try:
        r = requests.post(
            URL,
            headers={"Content-Type": "application/json"},
            data=json.dumps(datos),
            timeout=10,
        )
        r.raise_for_status()
        respuesta = r.json()
    except Exception as e:
        return None, f"Error de conexión con la API: {e}"
    if "candidates" not in respuesta:
        return None, f"Respuesta inválida de la API:\n{json.dumps(respuesta, indent=2)}"
    comando = respuesta["candidates"][0]["content"]["parts"][0]["text"].strip()
    return comando, None


def ejecutar_comando(comando):
    """
    Ejecuta un comando de sistema de forma segura con timeout.

    Args:
        comando (str): El comando a ejecutar.

    Returns:
        str: La salida del comando o mensaje de error.

    Note:
        Utiliza shlex.split() para evitar inyección de comandos y
        aplica un timeout de 20 segundos para evitar bloqueos.
    """
    if any(p in comando for p in PELIGROSOS):
        return "Comando bloqueado por seguridad."
    try:
        resultado = subprocess.run(
            shlex.split(comando),
            capture_output=True,
            text=True,
            shell=False,
            timeout=20,
        )
        salida = resultado.stdout.strip()
        error = resultado.stderr.strip()
        if not salida and not error:
            return "Comando ejecutado (sin salida)."
        return (salida if salida else "") + ("\nError: " + error if error else "")
    except subprocess.TimeoutExpired:
        return "El comando tardó demasiado y fue interrumpido."
    except Exception as e:
        return f"Error ejecutando el comando: {e}"


def main():
    """
    Función principal que ejecuta el bucle interactivo del agente.

    Maneja la interfaz de línea de comandos, procesa las instrucciones
    del usuario y coordina las llamadas a la API y ejecución de comandos.
    """
    print("Agente Termux-Android listo. Escribe 'exit' para salir.\n")
    while True:
        instruccion = input(">> ")
        if instruccion.lower().strip() in ["exit", "quit", "salir"]:
            print("Hasta luego.")
            break
        comando, error = pedir_comando(instruccion)
        if error:
            print(error)
            continue
        print(f"\nComando sugerido:\n{comando}\n")
        confirmar = input("¿Quieres ejecutar este comando? (s/n): ").lower().strip()
        if confirmar != "s":
            print("Cancelado por el usuario.\n")
            continue
        salida = ejecutar_comando(comando)
        print(f"Salida:\n{salida}\n")


if __name__ == "__main__":
    main()
