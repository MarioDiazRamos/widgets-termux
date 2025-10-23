#!/data/data/com.termux/files/usr/bin/bash
# Widget profesional del clima para Termux
NOMBRE_SCRIPT="Clima Termux"
VERSION="1.1"
ROJO='\033[0;31m'; VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; AZUL='\033[0;34m'; MORADO='\033[0;35m'; CYAN='\033[0;36m'; SIN_COLOR='\033[0m'

info() { echo -e "${AZUL}$1${SIN_COLOR}"; }
exito() { echo -e "${VERDE}$1${SIN_COLOR}"; }
advertencia() { echo -e "${AMARILLO}$1${SIN_COLOR}"; }
error() { echo -e "${ROJO}$1${SIN_COLOR}"; }
encabezado() { echo -e "${CYAN}$NOMBRE_SCRIPT v$VERSION${SIN_COLOR}\n"; }

verificar_dependencias() {
    # Instala solo si faltan
    source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh" 2>/dev/null || true
    ensure_cmd curl curl
    ensure_cmd jq jq
    ensure_cmd termux-location termux-api
    ensure_cmd termux-notification termux-api
    exito "Dependencias verificadas"
}

obtener_ubicacion() {
    info "Obteniendo ubicación..."
    local ubicacion=$(termux-location -p gps -r once 2>/dev/null | head -1)
    [ -z "$ubicacion" ] || [ "$ubicacion" = "{}" ] && ubicacion=$(termux-location -p network -r once 2>/dev/null | head -1)
    [ -z "$ubicacion" ] || [ "$ubicacion" = "{}" ] && { error "No se pudo obtener la ubicación"; info "Activa permisos de ubicación"; return 1; }
    echo "$ubicacion"
}

obtener_clima() {
    local lat="$1" lon="$2"
    info "Consultando clima para ($lat, $lon)..."
    local url="https://api.open-meteo.com/v1/forecast"
    local params="latitude=${lat}&longitude=${lon}&current_weather=true&hourly=precipitation_probability,temperature_2m&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1"
        local clima_data
        if ! clima_data=$(curl -s "${url}?${params}" --connect-timeout 10); then error "Error al obtener datos del clima"; return 1; fi
        if [ -z "$clima_data" ]; then error "Error al obtener datos del clima"; return 1; fi
    echo "$clima_data"
}

interpretar_clima() {
    case "$1" in
        0) echo "Despejado";; 1|2|3) echo "Parcialmente nublado";; 45|48) echo "Neblina";; 51|53|55) echo "Llovizna";; 56|57) echo "Llovizna helada";; 61|63|65) echo "Lluvia";; 66|67) echo "Lluvia helada";; 71|73|75) echo "Nieve";; 77) echo "Granizo";; 80|81|82) echo "Chubascos";; 85|86) echo "Nevadas";; 95|96|99) echo "Tormenta";; *) echo "Clima variable";;
    esac
}

generar_recomendacion() {
    local codigo="$1" temp="$2" lluvia="$3"
    [ "$lluvia" -gt 70 ] && echo "Lleva paraguas, alta probabilidad de lluvia" && return
    [ "$lluvia" -gt 40 ] && echo "Considera paraguas, puede llover" && return
    [ "$codigo" -ge 80 ] && [ "$codigo" -le 99 ] && echo "Evita actividades al aire libre, tormentas posibles" && return
    [ "$temp" -gt 30 ] && echo "Usa protector solar, día caluroso" && return
    [ "$temp" -lt 0 ] && echo "Mucho abrigo, bajo cero" && return
    [ "$temp" -lt 10 ] && echo "Abrígate bien, hace frío" && return
    [ "$codigo" -eq 0 ] && echo "Perfecto para actividades al aire libre" && return
    echo "Buen día para salir"
}

obtener_ciudad() {
    local lat="$1" lon="$2"
    local geo_url="https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=es"
        local geo_data
        if ! geo_data=$(curl -s "$geo_url" --connect-timeout 5); then echo "Ubicación actual"; return; fi
        if [ -n "$geo_data" ]; then
            local ciudad=$(echo "$geo_data" | jq -r '.city // .locality // .countryName // "Ubicación actual"' 2>/dev/null)
            if [ "$ciudad" != "null" ] && [ -n "$ciudad" ]; then echo "$ciudad"; return; fi
        fi
    echo "Ubicación actual"
}

mostrar_clima() {
    encabezado
    verificar_dependencias || return 1
        local ubicacion_json
        if ! ubicacion_json=$(obtener_ubicacion); then return 1; fi
    local lat=$(echo "$ubicacion_json" | jq -r '.latitude' 2>/dev/null)
    local lon=$(echo "$ubicacion_json" | jq -r '.longitude' 2>/dev/null)
    [ "$lat" = "null" ] || [ "$lon" = "null" ] || [ -z "$lat" ] || [ -z "$lon" ] && { error "Error al procesar coordenadas"; return 1; }
    exito "Ubicación: $lat, $lon"
        local ciudad
        if ! ciudad=$(obtener_ciudad "$lat" "$lon"); then return 1; fi
        local clima_json
        if ! clima_json=$(obtener_clima "$lat" "$lon"); then return 1; fi
    local temp_actual=$(echo "$clima_json" | jq -r '.current_weather.temperature' 2>/dev/null)
    local codigo_clima=$(echo "$clima_json" | jq -r '.current_weather.weathercode' 2>/dev/null)
    local velocidad_viento=$(echo "$clima_json" | jq -r '.current_weather.windspeed' 2>/dev/null)
    local temp_max=$(echo "$clima_json" | jq -r '.daily.temperature_2m_max[0]' 2>/dev/null)
    local temp_min=$(echo "$clima_json" | jq -r '.daily.temperature_2m_min[0]' 2>/dev/null)
    local prob_lluvia=$(echo "$clima_json" | jq -r '.daily.precipitation_probability_max[0]' 2>/dev/null)
    [ "$temp_actual" = "null" ] || [ -z "$temp_actual" ] && { error "Error al procesar datos del clima"; return 1; }
    local descripcion_clima=$(interpretar_clima "$codigo_clima")
    local recomendacion=$(generar_recomendacion "$codigo_clima" "${temp_actual%.*}" "${prob_lluvia:-0}")
    echo -e "\n${CYAN}Ubicación:${SIN_COLOR} $ciudad"
    echo -e "${MORADO}Temperatura:${SIN_COLOR} ${temp_actual}°C (Max: ${temp_max}°C, Min: ${temp_min}°C)"
    echo -e "${AZUL}Condición:${SIN_COLOR} $descripcion_clima"
    echo -e "${VERDE}Viento:${SIN_COLOR} ${velocidad_viento} km/h"
    echo -e "${AMARILLO}Prob. lluvia:${SIN_COLOR} ${prob_lluvia:-0}%"
    echo -e "${VERDE}Recomendación:${SIN_COLOR} $recomendacion\n"
    local titulo="Clima en $ciudad"
    local contenido="${temp_actual}°C - $descripcion_clima\nLluvia: ${prob_lluvia:-0}%\n$recomendacion"
    termux-notification --title "$titulo" --content "$contenido" --priority high --ongoing false
    exito "Resumen del clima completo"
    return 0
}

ayuda() {
    echo -e "\n${AZUL}Uso:${SIN_COLOR}\n  $(basename $0)          - Mostrar clima actual\n  $(basename $0) --help   - Mostrar esta ayuda\n\n${AZUL}Descripción:${SIN_COLOR}\n  Muestra el clima actual usando GPS y API gratuita.\n\n${AZUL}Dependencias:${SIN_COLOR}\n  termux-api, curl, jq\n\n${AZUL}Instalación:${SIN_COLOR}\n  pkg install termux-api curl jq\n  Instala Termux:API desde Play Store\n"
}

main() {
    case "${1:-}" in
        --help|-h|help) ayuda ;;
        "") mostrar_clima ;;
        *) error "Opción desconocida: $1"; ayuda; exit 1 ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then main "$@"; fi
