# ========================================
# Script PowerShell para sincronizar desde PC
# Widgets Termux - Sync desde Windows
# ========================================

param(
    [string]$Accion = "ayuda",
    [string]$IP_Termux = "",
    [string]$Usuario = "",
    [string]$RutaRepo = ".",
    [switch]$Forzar
)

# Configuración (personaliza estas variables)
$REPO_LOCAL = ".\widgets-termux"    # Carpeta local del repositorio
$PUERTO_TERMUX = "8022"             # Puerto SSH de Termux (por defecto 8022)

# Colores para output
function Escribir-ColorTexto {
    param([string]$Texto, [string]$Color = "White")
    
    $colores = @{
        "Rojo" = "Red"
        "Verde" = "Green" 
        "Amarillo" = "Yellow"
        "Azul" = "Blue"
        "Blanco" = "White"
        "Cian" = "Cyan"
    }
    
    Write-Host $Texto -ForegroundColor $colores[$Color]
}

function Mostrar-Uso {
    Escribir-ColorTexto "🔧 Herramienta de Sincronización PC-Termux" "Azul"
    Escribir-ColorTexto "=============================================" "Azul"
    Write-Host ""
    Write-Host "Uso:"
    Write-Host "  .\sincronizar-pc.ps1 configurar               - Configuración inicial"
    Write-Host "  .\sincronizar-pc.ps1 enviar <IP> <usuario>    - Enviar cambios a Termux"
    Write-Host "  .\sincronizar-pc.ps1 recibir <IP> <usuario>   - Recibir cambios desde Termux"
    Write-Host "  .\sincronizar-pc.ps1 desplegar <IP> <usuario> - Enviar + activar en Termux"
    Write-Host "  .\sincronizar-pc.ps1 estado                   - Estado del repositorio local"
    Write-Host ""
    Write-Host "Parámetros:"
    Write-Host "  <IP>      - IP del dispositivo Android (ej: 192.168.1.100)"
    Write-Host "  <usuario> - Usuario SSH de Termux (generalmente el mismo nombre)"
    Write-Host "  -Forzar   - Forzar operación sin confirmación"
    Write-Host ""
    Write-Host "Ejemplos:"
    Write-Host "  .\sincronizar-pc.ps1 desplegar 192.168.1.100 miusuario"
    Write-Host "  .\sincronizar-pc.ps1 enviar 192.168.1.100 miusuario -Forzar"
    Write-Host ""
}

function Verificar-Requisitos {
    # Verificar git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Escribir-ColorTexto "❌ Git no está instalado o no está en PATH" "Rojo"
        return $false
    }
    
    # Verificar scp (viene con Git for Windows)
    if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
        Escribir-ColorTexto "❌ SCP no está disponible (instala Git for Windows)" "Rojo"
        return $false
    }
    
    return $true
}

function Configurar-Repositorio {
    Escribir-ColorTexto "🔧 Configuración inicial" "Azul"
    
    if (-not (Verificar-Requisitos)) {
        return
    }
    
    if (Test-Path $REPO_LOCAL) {
        Escribir-ColorTexto "📁 Carpeta $REPO_LOCAL ya existe" "Amarillo"
        
        if (-not $Forzar) {
            $respuesta = Read-Host "¿Deseas continuar? (s/n)"
            if ($respuesta -ne "s" -and $respuesta -ne "S") {
                Escribir-ColorTexto "❌ Operación cancelada" "Rojo"
                return
            }
        }
    } else {
        Escribir-ColorTexto "📁 Creando carpeta $REPO_LOCAL" "Verde"
        New-Item -ItemType Directory -Path $REPO_LOCAL | Out-Null
    }
    
    Set-Location $REPO_LOCAL
    
    # Inicializar git si no existe
    if (-not (Test-Path ".git")) {
        Escribir-ColorTexto "🌱 Inicializando repositorio Git" "Verde"
        git init
        
        # Crear README.md básico
        @"
# Widgets Termux

Este repositorio contiene scripts para Termux Widgets.

## Estructura

- Cada archivo en la raíz es un script ejecutable
- Los scripts se sincronizan automáticamente con `~/.shortcuts/` en Termux
- Usa enlaces simbólicos para mantener versionado

## Uso

1. Edita o agrega scripts en esta carpeta
2. Haz commit y push a GitHub
3. Ejecuta el script de sincronización en Termux

## Scripts incluidos

"@ | Out-File -Encoding UTF8 "README.md"
        
        git add README.md
        git commit -m "Commit inicial con README"
        
        Escribir-ColorTexto "✅ Repositorio inicializado" "Verde"
        Escribir-ColorTexto "💡 Recuerda configurar el remote de GitHub:" "Amarillo"
        Escribir-ColorTexto "   git remote add origin https://github.com/tu-usuario/widgets-termux.git" "Amarillo"
    }
    
    Escribir-ColorTexto "✅ Configuración completada" "Verde"
}

function Enviar-ATermux {
    param([string]$IP, [string]$Usuario)
    
    if (-not $IP -or -not $Usuario) {
        Escribir-ColorTexto "❌ IP y usuario son requeridos" "Rojo"
        Mostrar-Uso
        return
    }
    
    Escribir-ColorTexto "📤 Enviando cambios a Termux ($IP)" "Azul"
    
    if (-not (Test-Path $REPO_LOCAL)) {
        Escribir-ColorTexto "❌ Repositorio local no encontrado: $REPO_LOCAL" "Rojo"
        return
    }
    
    # Hacer commit de cambios pendientes
    Set-Location $REPO_LOCAL
    $estado = git status --porcelain
    if ($estado) {
        Escribir-ColorTexto "📝 Commitando cambios locales..." "Amarillo"
        git add .
        $mensajeCommit = "Auto-commit desde PC - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git commit -m $mensajeCommit
    }
    
    # Enviar carpeta completa por SCP
    $rutaRemota = "${Usuario}@${IP}:~/widgets-termux/"
    Escribir-ColorTexto "🚀 Transfiriendo archivos..." "Azul"
    
    try {
        scp -P $PUERTO_TERMUX -r "$REPO_LOCAL\*" $rutaRemota
        Escribir-ColorTexto "✅ Archivos transferidos exitosamente" "Verde"
    }
    catch {
        Escribir-ColorTexto "❌ Error al transferir archivos: $($_.Exception.Message)" "Rojo"
        return
    }
}

function Desplegar-EnTermux {
    param([string]$IP, [string]$Usuario)
    
    # Primero hacer envío
    Enviar-ATermux -IP $IP -Usuario $Usuario
    
    # Luego ejecutar sincronización en Termux
    Escribir-ColorTexto "🔄 Activando widgets en Termux..." "Azul"
    
    $comandoSSH = "chmod +x ~/sincronizar-widgets.sh && ~/sincronizar-widgets.sh"
    
    try {
        ssh -p $PUERTO_TERMUX "${Usuario}@${IP}" $comandoSSH
        Escribir-ColorTexto "✅ Widgets activados en Termux" "Verde"
        Escribir-ColorTexto "💡 Reinicia el widget para ver los cambios" "Amarillo"
    }
    catch {
        Escribir-ColorTexto "❌ Error al activar widgets: $($_.Exception.Message)" "Rojo"
        Escribir-ColorTexto "💡 Ejecuta manualmente en Termux: ~/sincronizar-widgets.sh" "Amarillo"
    }
}

function Recibir-DeTermux {
    param([string]$IP, [string]$Usuario)
    
    if (-not $IP -or -not $Usuario) {
        Escribir-ColorTexto "❌ IP y usuario son requeridos" "Rojo"
        Mostrar-Uso
        return
    }
    
    Escribir-ColorTexto "📥 Descargando cambios desde Termux ($IP)" "Azul"
    
    $rutaRemota = "${Usuario}@${IP}:~/widgets-termux/*"
    
    if (-not (Test-Path $REPO_LOCAL)) {
        New-Item -ItemType Directory -Path $REPO_LOCAL | Out-Null
    }
    
    try {
        scp -P $PUERTO_TERMUX -r $rutaRemota $REPO_LOCAL
        Escribir-ColorTexto "✅ Archivos descargados exitosamente" "Verde"
        
        Set-Location $REPO_LOCAL
        Escribir-ColorTexto "📝 Commitando cambios..." "Amarillo"
        git add .
        $mensajeCommit = "Cambios desde Termux - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git commit -m $mensajeCommit
        
        Escribir-ColorTexto "✅ Cambios commitados localmente" "Verde"
    }
    catch {
        Escribir-ColorTexto "❌ Error al descargar archivos: $($_.Exception.Message)" "Rojo"
    }
}

function Mostrar-Estado {
    Escribir-ColorTexto "📊 Estado del repositorio local" "Azul"
    Escribir-ColorTexto "===============================" "Azul"
    
    if (-not (Test-Path $REPO_LOCAL)) {
        Escribir-ColorTexto "❌ Repositorio local no encontrado" "Rojo"
        Escribir-ColorTexto "💡 Ejecuta: .\sincronizar-pc.ps1 configurar" "Amarillo"
        return
    }
    
    Set-Location $REPO_LOCAL
    
    # Información del repositorio
    Escribir-ColorTexto "📁 Ruta: $(Get-Location)" "Blanco"
    
    try {
        $rama = git branch --show-current
        Escribir-ColorTexto "🌿 Rama: $rama" "Blanco"
        
        $ultimoCommit = git log -1 --format="%h - %s (%cr)"
        Escribir-ColorTexto "🔗 Último commit: $ultimoCommit" "Blanco"
        
        $cantidadScripts = (Get-ChildItem -File | Where-Object { $_.Name -notmatch '\.(md|txt|gitignore)$' }).Count
        Escribir-ColorTexto "📄 Scripts: $cantidadScripts" "Blanco"
        
        # Estado de cambios
        $estado = git status --porcelain
        if ($estado) {
            Escribir-ColorTexto "⚠️  Cambios pendientes:" "Amarillo"
            git status --short
        } else {
            Escribir-ColorTexto "✅ Sin cambios pendientes" "Verde"
        }
    }
    catch {
        Escribir-ColorTexto "⚠️  No es un repositorio Git válido" "Amarillo"
    }
}

# Ejecutar acción según parámetro
switch ($Accion.ToLower()) {
    "configurar" { Configurar-Repositorio }
    "enviar" { Enviar-ATermux -IP $IP_Termux -Usuario $Usuario }
    "recibir" { Recibir-DeTermux -IP $IP_Termux -Usuario $Usuario }
    "desplegar" { Desplegar-EnTermux -IP $IP_Termux -Usuario $Usuario }
    "estado" { Mostrar-Estado }
    default { Mostrar-Uso }
}