import os
import requests
import json
import subprocess
import shlex

# === CONFIGURACIÓN ===
API_KEY = "AIzaSyANFE_esHNO9LmdS_lqYPW69xxP25Av9N4"
MODEL = "gemini-2.0-flash"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"

# Prompt del sistema (instrucciones al modelo)
SYSTEM_PROMPT = """Eres un agente ejecutándose dentro de Termux en Android.
Tu trabajo es convertir las instrucciones del usuario en comandos ejecutables.

Reglas:
- Responde SOLO con un comando válido para Termux (Linux) o termux-api.
- NO incluyas explicaciones, Markdown ni bloques bash.
- No uses tuberías (|), awk, grep, jq ni expresiones complejas que puedan colgarse.
- Si no puedes hacerlo en Termux/Android, responde con: echo "No puedo hacerlo en Termux/Android".
- Asegúrate de que los comandos sean simples, seguros y ejecutables en una sola línea.

Ejemplos:
Usuario: dime la batería
Respuesta: termux-battery-status

Usuario: crea un archivo hola.txt con hola
Respuesta: echo "hola" > hola.txt

Usuario: vibra el teléfono
Respuesta: termux-vibrate -d 2000
"""

# === FUNCIÓN PARA CONSULTAR GEMINI ===
def pedir_comando(prompt):
    data = {
        "contents": [
            {"parts": [{"text": SYSTEM_PROMPT + "\nUsuario: " + prompt}]}
        ]
    }
    try:
        r = requests.post(URL, headers={"Content-Type": "application/json"}, data=json.dumps(data))
        r.raise_for_status()
        response = r.json()
    except Exception as e:
        return None, f"❌ Error al conectar con la API: {e}"

    if "candidates" not in response:
        return None, f"❌ Respuesta inválida de la API:\n{json.dumps(response, indent=2)}"

    cmd = response["candidates"][0]["content"]["parts"][0]["text"].strip()
    return cmd, None

# === FUNCIÓN PARA EJECUTAR EL COMANDO ===
def ejecutar_comando(cmd):
    # Lista de comandos peligrosos a filtrar (puedes personalizarla)
    PELIGROSOS = ["rm -rf", "mkfs", ":(){:|:&};:", "dd if=", ">:"]

    if any(p in cmd for p in PELIGROSOS):
        return "⚠ Comando bloqueado por seguridad."

    try:
        # Ejecutar usando subprocess (más seguro que os.system)
        result = subprocess.run(shlex.split(cmd), capture_output=True, text=True, shell=False, timeout=20)
        salida = result.stdout.strip()
        error = result.stderr.strip()
        if salida == "" and error == "":
            return "✅ Comando ejecutado (sin salida)."
        return (salida if salida else "") + ("\n⚠ " + error if error else "")
    except subprocess.TimeoutExpired:
        return "⚠ El comando tardó demasiado y fue interrumpido."
    except Exception as e:
        return f"❌ Error ejecutando el comando: {e}"

# === LOOP PRINCIPAL ===
def main():
    print("🤖 Agente Termux-Android listo. Escribe 'exit' para salir.\n")
    while True:
        prompt = input(">> ")
        if prompt.lower().strip() in ["exit", "quit", "salir"]:
            print("👋 Hasta luego.")
            break

        # Pedir comando al modelo
        cmd, error = pedir_comando(prompt)
        if error:
            print(error)
            continue

        print(f"\n🤖 Comando sugerido:\n{cmd}\n")

        # Confirmación opcional para mayor seguridad
        confirm = input("¿Quieres ejecutar este comando? (s/n): ").lower().strip()
        if confirm != "s":
            print("❎ Cancelado por el usuario.\n")
            continue

        # Ejecutar y mostrar salida
        salida = ejecutar_comando(cmd)
        print(f"📜 Salida:\n{salida}\n")


if __name__ == "__main__":
    main()