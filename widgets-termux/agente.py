# agente.py
# Script principal para agente Termux con configuración interactiva de API key
# Ver código en la edición anterior (ya actualizado para pedir y guardar API key)

import requests
import json
import subprocess
import shlex
import os

# Configuración interactiva de API_KEY
CONFIG_PATH = os.path.expanduser("~/.agente_config.json")
def pedir_api_key():
    print("\nPara usar el agente necesitas tu propia API key de Gemini.")
    print("1. Ve a https://aistudio.google.com/app/apikey\n2. Genera tu clave y pégala aquí.")
    api = input("Pega tu API key: ").strip()
    if not api:
        print("No se ingresó clave. Saliendo."); exit(1)
    with open(CONFIG_PATH, "w") as f:
        json.dump({"API_KEY": api}, f)
    return api

def cargar_api_key():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH) as f:
                return json.load(f)["API_KEY"]
        except Exception:
            pass
    return pedir_api_key()

API_KEY = cargar_api_key()
MODELO = "gemini-2.0-flash"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODELO}:generateContent?key={API_KEY}"

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
    datos = {
        "contents": [
            {"parts": [{"text": PROMPT_SISTEMA + "\nUsuario: " + instruccion}]}
        ]
    }
    try:
        r = requests.post(URL, headers={"Content-Type": "application/json"}, data=json.dumps(datos))
        r.raise_for_status()
        respuesta = r.json()
    except Exception as e:
        return None, f"Error de conexión con la API: {e}"
    if "candidates" not in respuesta:
        return None, f"Respuesta inválida de la API:\n{json.dumps(respuesta, indent=2)}"
    comando = respuesta["candidates"][0]["content"]["parts"][0]["text"].strip()
    return comando, None

def ejecutar_comando(comando):
    if any(p in comando for p in PELIGROSOS):
        return "Comando bloqueado por seguridad."
    try:
        resultado = subprocess.run(shlex.split(comando), capture_output=True, text=True, shell=False, timeout=20)
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
