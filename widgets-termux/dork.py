# dork.py
# Script principal para generación de Google Dorks con configuración interactiva de API key
# Ver código en la edición anterior (ya actualizado para pedir y guardar API key)

import os, requests, json, datetime, urllib.parse, subprocess

# Configuración interactiva de API_KEY
CONFIG_PATH = os.path.expanduser("~/.dork_config.json")
def pedir_api_key():
    print("\nPara usar este script necesitas tu propia API key de Gemini.")
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

CLAVE_API = cargar_api_key()
MODELO = "gemini-2.0-flash"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODELO}:generateContent?key={CLAVE_API}"
PROMPT_SISTEMA = (
    "Eres un asistente que genera Google Dorks para uso legítimo. "
    "Responde solo en español y solo con JSON válido, sin texto adicional. "
    "Genera hasta 12 dorks variados y útiles."
)
# ...resto del código original...
