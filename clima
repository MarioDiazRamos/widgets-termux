#!/data/data/com.termux/files/usr/bin/bash

# ===================================================
# Widget del Clima para Termux
# Obtiene el clima actual usando ubicación GPS y API gratuita
# ===================================================

# Configuración del script
NOMBRE_SCRIPT="Widget Clima"
VERSION="1.0"

# Colores para output
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
MORADO='\033[0;35m'
CYAN='\033[0;36m'
SIN_COLOR='\033[0m'

# Función para mostrar mensajes con colores
mostrar_info() { echo -e "${AZUL}[INFO]${SIN_COLOR} $1"; }
mostrar_exito() { echo -e "${VERDE}[ÉXITO]${SIN_COLOR} $1"; }
mostrar_advertencia() { echo -e "${AMARILLO}[ADVERTENCIA]${SIN_COLOR} $1"; }
mostrar_error() { echo -e "${ROJO}[ERROR]${SIN_COLOR} $1"; }

# Función para mostrar encabezado
mostrar_encabezado() {
    echo -e "${CYAN}=============================${SIN_COLOR}"
    echo -e "${CYAN}🌤️  $NOMBRE_SCRIPT v$VERSION${SIN_COLOR}"
    echo -e "${CYAN}=============================${SIN_COLOR}"
    echo ""
}

# Función para verificar dependencias
verificar_dependencias() {
    local deps=("curl" "jq" "termux-location" "termux-notification")
    local faltantes=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            faltantes+=("$dep")
        fi
    done
    
    if [ ${#faltantes[@]} -gt 0 ]; then
        mostrar_error "Dependencias faltantes: ${faltantes[*]}"
        mostrar_info "Instala con: pkg install termux-api curl jq"
        mostrar_info "También asegúrate de tener Termux:API instalada desde Play Store"
        return 1
    fi
    
    mostrar_exito "Dependencias verificadas ✓"
    return 0
}

# Función para obtener ubicación actual
obtener_ubicacion() {
    mostrar_info "📍 Obteniendo ubicación GPS..."
    
    # Obtener ubicación con timeout
    local ubicacion=$(termux-location -p gps -r once 2>/dev/null | head -1)
    
    if [ -z "$ubicacion" ] || [ "$ubicacion" = "{}" ]; then
        mostrar_advertencia "GPS no disponible, intentando con red..."
        ubicacion=$(termux-location -p network -r once 2>/dev/null | head -1)
    fi
    
    if [ -z "$ubicacion" ] || [ "$ubicacion" = "{}" ]; then
        mostrar_error "No se pudo obtener la ubicación"
        mostrar_info "Verifica que los permisos de ubicación estén habilitados"
        return 1
    fi
    
    echo "$ubicacion"
}

# Función para obtener datos del clima
obtener_clima() {
    local lat="$1"
    local lon="$2"
    
    mostrar_info "🌡️ Consultando clima para ubicación ($lat, $lon)..."
    
    # API Open-Meteo (completamente gratuita, sin registro)
    local url="https://api.open-meteo.com/v1/forecast"
    local params="latitude=${lat}&longitude=${lon}&current_weather=true&hourly=precipitation_probability,temperature_2m&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1"
    
    local clima_data=$(curl -s "${url}?${params}" --connect-timeout 10)
    
    if [ $? -ne 0 ] || [ -z "$clima_data" ]; then
        mostrar_error "Error al obtener datos del clima"
        return 1
    fi
    
    echo "$clima_data"
}

# Función para interpretar código del clima
interpretar_clima() {
    local codigo="$1"
    
    case "$codigo" in
        0) echo "☀️ Despejado" ;;
        1|2|3) echo "⛅ Parcialmente nublado" ;;
        45|48) echo "🌫️ Neblinoso" ;;
        51|53|55) echo "🌦️ Llovizna" ;;
        56|57) echo "🌨️ Llovizna helada" ;;
        61|63|65) echo "🌧️ Lluvia" ;;
        66|67) echo "🌧️ Lluvia helada" ;;
        71|73|75) echo "❄️ Nieve" ;;
        77) echo "🌨️ Granizo" ;;
        80|81|82) echo "🌦️ Chubascos" ;;
        85|86) echo "❄️ Nevadas" ;;
        95|96|99) echo "⛈️ Tormenta" ;;
        *) echo "🌤️ Clima variable" ;;
    esac
}

# Función para generar recomendación
generar_recomendacion() {
    local codigo="$1"
    local temp="$2"
    local lluvia="$3"
    
    # Recomendaciones basadas en clima
    if [ "$lluvia" -gt 70 ]; then
        echo "🌂 Lleva paraguas, alta probabilidad de lluvia"
    elif [ "$lluvia" -gt 40 ]; then
        echo "☔ Considera llevar paraguas, puede llover"
    elif [ "$codigo" -ge 80 ] && [ "$codigo" -le 99 ]; then
        echo "⛈️ Evita actividades al aire libre, tormentas posibles"
    elif [ "$temp" -gt 30 ]; then
        echo "🧴 Usa protector solar, día caluroso"
    elif [ "$temp" -lt 10 ]; then
        echo "🧥 Abrígate bien, hace frío"
    elif [ "$temp" -lt 0 ]; then
        echo "❄️ Mucho abrigo, temperatura bajo cero"
    elif [ "$codigo" -eq 0 ]; then
        echo "😎 Perfecto para actividades al aire libre"
    else
        echo "👍 Buen día para salir"
    fi
}

# Función para obtener nombre de ciudad (geocodificación inversa)
obtener_ciudad() {
    local lat="$1"
    local lon="$2"
    
    # API gratuita de geocodificación inversa
    local geo_url="https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=es"
    local geo_data=$(curl -s "$geo_url" --connect-timeout 5)
    
    if [ $? -eq 0 ] && [ -n "$geo_data" ]; then
        local ciudad=$(echo "$geo_data" | jq -r '.city // .locality // .countryName // "Ubicación actual"' 2>/dev/null)
        if [ "$ciudad" != "null" ] && [ -n "$ciudad" ]; then
            echo "$ciudad"
            return
        fi
    fi
    
    echo "Ubicación actual"
}

# Función principal del clima
mostrar_clima() {
    mostrar_encabezado
    
    # Verificar dependencias
    if ! verificar_dependencias; then
        return 1
    fi
    
    # Obtener ubicación
    local ubicacion_json=$(obtener_ubicacion)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Extraer latitud y longitud
    local lat=$(echo "$ubicacion_json" | jq -r '.latitude' 2>/dev/null)
    local lon=$(echo "$ubicacion_json" | jq -r '.longitude' 2>/dev/null)
    
    if [ "$lat" = "null" ] || [ "$lon" = "null" ] || [ -z "$lat" ] || [ -z "$lon" ]; then
        mostrar_error "Error al procesar coordenadas de ubicación"
        return 1
    fi
    
    mostrar_exito "📍 Ubicación: $lat, $lon"
    
    # Obtener nombre de ciudad
    local ciudad=$(obtener_ciudad "$lat" "$lon")
    
    # Obtener datos del clima
    local clima_json=$(obtener_clima "$lat" "$lon")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Extraer datos relevantes
    local temp_actual=$(echo "$clima_json" | jq -r '.current_weather.temperature' 2>/dev/null)
    local codigo_clima=$(echo "$clima_json" | jq -r '.current_weather.weathercode' 2>/dev/null)
    local velocidad_viento=$(echo "$clima_json" | jq -r '.current_weather.windspeed' 2>/dev/null)
    local temp_max=$(echo "$clima_json" | jq -r '.daily.temperature_2m_max[0]' 2>/dev/null)
    local temp_min=$(echo "$clima_json" | jq -r '.daily.temperature_2m_min[0]' 2>/dev/null)
    local prob_lluvia=$(echo "$clima_json" | jq -r '.daily.precipitation_probability_max[0]' 2>/dev/null)
    
    # Verificar que se obtuvieron los datos
    if [ "$temp_actual" = "null" ] || [ -z "$temp_actual" ]; then
        mostrar_error "Error al procesar datos del clima"
        return 1
    fi
    
    # Interpretar código del clima
    local descripcion_clima=$(interpretar_clima "$codigo_clima")
    
    # Generar recomendación
    local recomendacion=$(generar_recomendacion "$codigo_clima" "${temp_actual%.*}" "${prob_lluvia:-0}")
    
    # Mostrar resumen en terminal
    echo ""
    echo -e "${CYAN}📍 Ubicación:${SIN_COLOR} $ciudad"
    echo -e "${MORADO}🌡️  Temperatura:${SIN_COLOR} ${temp_actual}°C (Max: ${temp_max}°C, Min: ${temp_min}°C)"
    echo -e "${AZUL}☁️  Condición:${SIN_COLOR} $descripcion_clima"
    echo -e "${VERDE}💨 Viento:${SIN_COLOR} ${velocidad_viento} km/h"
    echo -e "${AMARILLO}☔ Prob. lluvia:${SIN_COLOR} ${prob_lluvia:-0}%"
    echo ""
    echo -e "${VERDE}💡 Recomendación:${SIN_COLOR} $recomendacion"
    echo ""
    
    # Crear notificación
    local titulo="🌤️ Clima en $ciudad"
    local contenido="${temp_actual}°C - $descripcion_clima\n☔ Lluvia: ${prob_lluvia:-0}%\n💡 $recomendacion"
    
    termux-notification \
        --title "$titulo" \
        --content "$contenido" \
        --priority high \
        --ongoing false
    
    mostrar_exito "✅ Resumen del clima completo"
    
    return 0
}

# Función de ayuda
mostrar_ayuda() {
    echo ""
    echo -e "${AZUL}Uso:${SIN_COLOR}"
    echo "  $(basename $0)          - Mostrar clima actual"
    echo "  $(basename $0) --help   - Mostrar esta ayuda"
    echo ""
    echo -e "${AZUL}Descripción:${SIN_COLOR}"
    echo "  Widget que obtiene tu ubicación actual via GPS y muestra"
    echo "  el clima con temperatura, condiciones y recomendaciones."
    echo ""
    echo -e "${AZUL}Dependencias:${SIN_COLOR}"
    echo "  • termux-api (termux-location, termux-notification)"
    echo "  • curl (para consultas HTTP)"
    echo "  • jq (para procesar JSON)"
    echo ""
    echo -e "${AZUL}Instalación:${SIN_COLOR}"
    echo "  pkg install termux-api curl jq"
    echo "  También instala Termux:API desde Play Store"
    echo ""
}

# Script principal
main() {
    case "${1:-}" in
        --help|-h|help)
            mostrar_ayuda
            ;;
        "")
            mostrar_clima
            ;;
        *)
            mostrar_error "Opción desconocida: $1"
            mostrar_ayuda
            exit 1
            ;;
    esac
}

# Ejecutar función principal
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi