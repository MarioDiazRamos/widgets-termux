#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🎙️ Agente de Voz Termux-Android
Basado en agente.py pero con capacidades de reconocimiento y síntesis de voz
Ejecuta comandos de Termux usando comandos de voz en español

Dependencias: termux-api
Instalación: pkg install termux-api python
"""

import os
import requests
import json
import subprocess
import shlex
import sys
import time
import threading

# === CONFIGURACIÓN ===
API_KEY = "AIzaSyANFE_esHNO9LmdS_lqYPW69xxP25Av9N4"
MODEL = "gemini-2.0-flash"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}"

# Colores para output
ROJO = '\033[0;31m'
VERDE = '\033[0;32m'
AMARILLO = '\033[1;33m'
AZUL = '\033[0;34m'
MORADO = '\033[0;35m'
CYAN = '\033[0;36m'
SIN_COLOR = '\033[0m'

# Prompt del sistema optimizado para comandos de voz
SYSTEM_PROMPT = """Eres un agente de voz ejecutándose dentro de Termux en Android.
Tu trabajo es convertir las instrucciones de voz del usuario en comandos ejecutables.

Reglas:
- Responde SOLO con un comando válido para Termux (Linux) o termux-api.
- NO incluyas explicaciones, Markdown ni bloques bash.
- Interpreta comandos de voz naturales en español.
- Para YouTube: usa "termux-open-url" para abrir videos/música.
- Para aplicaciones: usa "am start" con intents de Android.
- No uses tuberías (|), awk, grep, jq ni expresiones complejas.
- Si no puedes hacerlo en Termux/Android, responde: echo "No puedo hacerlo en Termux/Android".
- Asegúrate de que los comandos sean simples, seguros y ejecutables.

Ejemplos de comandos de voz:
"abre youtube con despacito" -> termux-open-url "https://www.youtube.com/results?search_query=despacito"
"pon música de rock" -> termux-open-url "https://www.youtube.com/results?search_query=rock+music"
"abre whatsapp" -> am start -n com.whatsapp/com.whatsapp.HomeActivity
"dime la batería" -> termux-battery-status
"vibra el teléfono" -> termux-vibrate -d 2000
"toma una foto" -> termux-camera-photo ~/foto.jpg
"graba audio" -> termux-microphone-record ~/audio.wav
"""

# === FUNCIONES DE VOZ ===

def verificar_termux_api():
    """Verifica si termux-api está instalado"""
    try:
        subprocess.run(["termux-tts-speak", "--help"], capture_output=True, timeout=5)
        return True
    except:
        return False

def hablar(texto, velocidad=1.0):
    """Convierte texto a voz usando termux-tts-speak"""
    try:
        # Limpiar texto para TTS
        texto_limpio = texto.replace('\033[0;31m', '').replace('\033[0;32m', '').replace('\033[1;33m', '').replace('\033[0;34m', '').replace('\033[0;35m', '').replace('\033[0;36m', '').replace('\033[0m', '')
        
        subprocess.run([
            "termux-tts-speak", 
            "-l", "es-ES",  # Idioma español
            "-r", str(velocidad),  # Velocidad
            texto_limpio
        ], timeout=10)
        return True
    except Exception as e:
        print(f"{ROJO}❌ Error en síntesis de voz: {e}{SIN_COLOR}")
        return False

def escuchar_voz():
    """Reconoce voz usando termux-speech-to-text"""
    print(f"{CYAN}🎙️ Escuchando... (habla ahora){SIN_COLOR}")
    hablar("Te escucho")
    
    try:
        # Ejecutar reconocimiento de voz
        result = subprocess.run([
            "termux-speech-to-text", 
            "-l", "es-ES"  # Idioma español
        ], capture_output=True, text=True, timeout=15)
        
        if result.returncode == 0 and result.stdout.strip():
            texto = result.stdout.strip()
            print(f"{VERDE}🎙️ Escuché: {texto}{SIN_COLOR}")
            return texto
        else:
            print(f"{AMARILLO}⚠️ No pude entender lo que dijiste{SIN_COLOR}")
            hablar("No pude entenderte, repite por favor")
            return None
            
    except subprocess.TimeoutExpired:
        print(f"{AMARILLO}⚠️ Tiempo de espera agotado{SIN_COLOR}")
        hablar("No escuché nada")
        return None
    except Exception as e:
        print(f"{ROJO}❌ Error en reconocimiento de voz: {e}{SIN_COLOR}")
        hablar("Error en el micrófono")
        return None

def mostrar_comandos_voz():
    """Muestra ejemplos de comandos de voz disponibles"""
    ejemplos = [
        "🎵 Música y YouTube:",
        "  • 'abre youtube con despacito'",
        "  • 'pon música de rock'",
        "  • 'busca videos de gatos'",
        "",
        "📱 Aplicaciones:",
        "  • 'abre whatsapp'",
        "  • 'abre telegram'",
        "  • 'abre la cámara'",
        "",
        "⚙️ Sistema:",
        "  • 'dime la batería'",
        "  • 'vibra el teléfono'",
        "  • 'toma una foto'",
        "  • 'graba audio'",
        "",
        "🗣️ Control:",
        "  • 'ayuda' o 'comandos'",
        "  • 'salir' o 'exit'"
    ]
    
    print(f"\n{AZUL}📋 Comandos de Voz Disponibles:{SIN_COLOR}")
    for ejemplo in ejemplos:
        print(ejemplo)
    print()

# === FUNCIÓN PARA CONSULTAR GEMINI ===
def pedir_comando(prompt):
    """Solicita comando a Gemini basado en el prompt de voz"""
    data = {
        "contents": [
            {"parts": [{"text": SYSTEM_PROMPT + "\nUsuario (por voz): " + prompt}]}
        ]
    }
    try:
        r = requests.post(URL, headers={"Content-Type": "application/json"}, data=json.dumps(data), timeout=10)
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
    """Ejecuta el comando de forma segura"""
    # Lista de comandos peligrosos a filtrar
    PELIGROSOS = ["rm -rf", "mkfs", ":(){:|:&};:", "dd if=", ">:", "format", "delete"]

    if any(p in cmd.lower() for p in PELIGROSOS):
        return "⚠ Comando bloqueado por seguridad."

    try:
        # Para comandos de termux-api y Android, usar shell=True
        if cmd.startswith(("termux-", "am start", "pm ")):
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        else:
            # Para otros comandos, usar shlex para mayor seguridad
            result = subprocess.run(shlex.split(cmd), capture_output=True, text=True, timeout=20)
            
        salida = result.stdout.strip()
        error = result.stderr.strip()
        
        if result.returncode == 0:
            if salida == "" and error == "":
                return "✅ Comando ejecutado correctamente."
            return (salida if salida else "") + ("\n⚠ " + error if error else "")
        else:
            return f"❌ Error (código {result.returncode}): {error if error else 'Sin mensaje de error'}"
            
    except subprocess.TimeoutExpired:
        return "⚠ El comando tardó demasiado y fue interrumpido."
    except Exception as e:
        return f"❌ Error ejecutando el comando: {e}"

# === FUNCIÓN PARA PROCESAR COMANDO DE VOZ ===
def procesar_comando_voz(texto_voz):
    """Procesa un comando de voz completo"""
    # Comandos especiales
    if any(palabra in texto_voz.lower() for palabra in ["ayuda", "comandos", "help"]):
        mostrar_comandos_voz()
        hablar("Te muestro los comandos disponibles")
        return
    
    if any(palabra in texto_voz.lower() for palabra in ["salir", "exit", "cerrar", "terminar"]):
        print(f"{VERDE}👋 Cerrando agente de voz...{SIN_COLOR}")
        hablar("Hasta luego")
        return "exit"
    
    # Obtener comando de Gemini
    print(f"{AZUL}🤖 Procesando: {texto_voz}{SIN_COLOR}")
    hablar("Procesando tu solicitud")
    
    cmd, error = pedir_comando(texto_voz)
    if error:
        print(f"{ROJO}{error}{SIN_COLOR}")
        hablar("Error al procesar tu solicitud")
        return
    
    print(f"{MORADO}🤖 Comando sugerido: {cmd}{SIN_COLOR}")
    
    # Confirmación automática para comandos seguros, manual para otros
    comandos_seguros = ["termux-battery-status", "termux-vibrate", "termux-open-url", "echo"]
    
    if any(cmd.startswith(seguro) for seguro in comandos_seguros):
        confirmar = True
        print(f"{VERDE}✅ Ejecutando automáticamente (comando seguro){SIN_COLOR}")
    else:
        print(f"{AMARILLO}¿Ejecutar este comando? Di 'sí' o 'no'{SIN_COLOR}")
        hablar("¿Ejecuto este comando?")
        
        confirmacion = escuchar_voz()
        if confirmacion and any(palabra in confirmacion.lower() for palabra in ["sí", "si", "ok", "dale", "hazlo", "ejecuta"]):
            confirmar = True
            print(f"{VERDE}✅ Confirmado por voz{SIN_COLOR}")
        else:
            confirmar = False
            print(f"{AMARILLO}❎ Cancelado{SIN_COLOR}")
            hablar("Comando cancelado")
    
    if confirmar:
        # Ejecutar comando
        print(f"{CYAN}⚙️ Ejecutando...{SIN_COLOR}")
        salida = ejecutar_comando(cmd)
        print(f"{VERDE}📜 Resultado: {salida}{SIN_COLOR}")
        
        # Respuesta por voz
        if "✅" in salida:
            hablar("Comando ejecutado correctamente")
        elif "❌" in salida:
            hablar("Hubo un error al ejecutar el comando")
        elif "⚠" in salida:
            hablar("Comando ejecutado con advertencias")
        else:
            # Para resultados con datos, leer los primeros caracteres
            resultado_corto = salida[:100] if len(salida) > 100 else salida
            hablar(f"Resultado: {resultado_corto}")

# === LOOP PRINCIPAL DE VOZ ===
def main():
    """Bucle principal del agente de voz"""
    print(f"{CYAN}🎙️ Agente de Voz Termux-Android Iniciado{SIN_COLOR}")
    print("=" * 45)
    
    # Verificar termux-api
    if not verificar_termux_api():
        print(f"{ROJO}❌ termux-api no está instalado o no funciona{SIN_COLOR}")
        print(f"{AMARILLO}Instala con: pkg install termux-api{SIN_COLOR}")
        print(f"{AMARILLO}También asegúrate de tener la app Termux:API instalada{SIN_COLOR}")
        return
    
    print(f"{VERDE}✅ termux-api detectado correctamente{SIN_COLOR}")
    hablar("Agente de voz listo")
    
    mostrar_comandos_voz()
    
    print(f"{CYAN}🎤 Di 'empezar' para activar el micrófono o 'salir' para terminar{SIN_COLOR}")
    
    while True:
        try:
            # Esperar comando inicial por teclado o voz
            entrada = input(f"\n{AZUL}>> Presiona Enter para hablar (o escribe 'salir'): {SIN_COLOR}")
            
            if entrada.lower().strip() in ["salir", "exit", "quit"]:
                print(f"{VERDE}👋 Hasta luego{SIN_COLOR}")
                hablar("Hasta luego")
                break
                
            # Activar reconocimiento de voz
            texto_voz = escuchar_voz()
            
            if texto_voz:
                resultado = procesar_comando_voz(texto_voz)
                if resultado == "exit":
                    break
            
            time.sleep(0.5)  # Pausa breve entre comandos
            
        except KeyboardInterrupt:
            print(f"\n{AMARILLO}⚠️ Interrupción del usuario{SIN_COLOR}")
            hablar("Interrupción del usuario")
            break
        except Exception as e:
            print(f"{ROJO}❌ Error inesperado: {e}{SIN_COLOR}")
            hablar("Error inesperado")

# === FUNCIÓN PARA MODO CONTINUO ===
def modo_continuo():
    """Modo de escucha continua (experimental)"""
    print(f"{MORADO}🔄 Modo continuo activado - di 'agente' para activar{SIN_COLOR}")
    hablar("Modo continuo activado, di agente para hablar conmigo")
    
    while True:
        try:
            # Escuchar palabra de activación
            audio = escuchar_voz()
            if audio and "agente" in audio.lower():
                hablar("¿Qué necesitas?")
                comando = escuchar_voz()
                if comando:
                    resultado = procesar_comando_voz(comando)
                    if resultado == "exit":
                        break
            
            time.sleep(1)  # Pausa entre escuchas
            
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