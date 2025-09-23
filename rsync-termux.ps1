# ========================================
# Script PowerShell alternativo usando rsync
# Para sincronización más eficiente
# ========================================

param(
    [string]$Accion = "ayuda",
    [string]$IP_Termux = "",
    [string]$Usuario = "",
    [switch]$Simulacion,
    [switch]$Forzar
)

# Configuración
$REPO_LOCAL = ".\widgets-termux"
$PUERTO_TERMUX = "8022"

function Escribir-ColorTexto {
    param([string]$Texto, [string]$Color = "White")
    $colores = @{"Rojo"="Red";"Verde"="Green";"Amarillo"="Yellow";"Azul"="Blue";"Blanco"="White"}
    Write-Host $Texto -ForegroundColor $colores[$Color]
}

function Verificar-Rsync {
    if (Get-Command rsync -ErrorAction SilentlyContinue) {
        return $true
    } else {
        Escribir-ColorTexto "❌ rsync no está disponible" "Rojo"
        Escribir-ColorTexto "💡 Instala rsync con WSL o usando Chocolatey:" "Amarillo"
        Escribir-ColorTexto "   choco install rsync" "Amarillo"
        return $false
    }
}

function Sincronizar-ATermux {
    param([string]$IP, [string]$Usuario)
    
    if (-not $IP -or -not $Usuario) {
        Escribir-ColorTexto "❌ IP y usuario son requeridos" "Rojo"
        return
    }
    
    if (-not (Verificar-Rsync)) { return }
    
    Escribir-ColorTexto "🔄 Sincronizando con Termux ($IP)" "Azul"
    
    $argumentosRsync = @(
        "-avz",                          # archive, verbose, compress
        "--progress",                    # mostrar progreso
        "-e", "ssh -p $PUERTO_TERMUX",   # usar SSH con puerto específico
        "--exclude=.git",                # excluir carpeta .git
        "--exclude=*.tmp",               # excluir archivos temporales
        "--exclude=*.log"                # excluir logs
    )
    
    if ($Simulacion) {
        $argumentosRsync += "--dry-run"
        Escribir-ColorTexto "🧪 Modo simulación (dry-run)" "Amarillo"
    }
    
    $origen = "$REPO_LOCAL\"
    $destino = "${Usuario}@${IP}:~/widgets-termux/"
    
    Escribir-ColorTexto "📁 Origen: $origen" "Blanco"
    Escribir-ColorTexto "🎯 Destino: $destino" "Blanco"
    
    try {
        & rsync $argumentosRsync $origen $destino
        
        if ($LASTEXITCODE -eq 0) {
            if (-not $Simulacion) {
                Escribir-ColorTexto "✅ Sincronización completada" "Verde"
                
                # Ejecutar script de activación en Termux
                Escribir-ColorTexto "🔄 Activando widgets..." "Azul"
                $comandoActivar = "chmod +x ~/sincronizar-widgets.sh && ~/sincronizar-widgets.sh"
                ssh -p $PUERTO_TERMUX "${Usuario}@${IP}" $comandoActivar
                
                Escribir-ColorTexto "✅ Widgets activados" "Verde"
            } else {
                Escribir-ColorTexto "✅ Simulación completada" "Verde"
            }
        } else {
            Escribir-ColorTexto "❌ Error en la sincronización (código: $LASTEXITCODE)" "Rojo"
        }
    }
    catch {
        Escribir-ColorTexto "❌ Error ejecutando rsync: $($_.Exception.Message)" "Rojo"
    }
}

function Sincronizar-DeTermux {
    param([string]$IP, [string]$Usuario)
    
    if (-not $IP -or -not $Usuario) {
        Escribir-ColorTexto "❌ IP y usuario son requeridos" "Rojo"
        return
    }
    
    if (-not (Verificar-Rsync)) { return }
    
    Escribir-ColorTexto "📥 Descargando desde Termux ($IP)" "Azul"
    
    $argumentosRsync = @(
        "-avz",
        "--progress",
        "-e", "ssh -p $PUERTO_TERMUX",
        "--exclude=.git"
    )
    
    if ($Simulacion) {
        $argumentosRsync += "--dry-run"
        Escribir-ColorTexto "🧪 Modo simulación (dry-run)" "Amarillo"
    }
    
    $origen = "${Usuario}@${IP}:~/widgets-termux/"
    $destino = "$REPO_LOCAL\"
    
    if (-not (Test-Path $REPO_LOCAL)) {
        New-Item -ItemType Directory -Path $REPO_LOCAL | Out-Null
    }
    
    try {
        & rsync $argumentosRsync $origen $destino
        
        if ($LASTEXITCODE -eq 0) {
            Escribir-ColorTexto "✅ Descarga completada" "Verde"
        } else {
            Escribir-ColorTexto "❌ Error en la descarga (código: $LASTEXITCODE)" "Rojo"
        }
    }
    catch {
        Escribir-ColorTexto "❌ Error ejecutando rsync: $($_.Exception.Message)" "Rojo"
    }
}

function Vigilar-Y-Sincronizar {
    param([string]$IP, [string]$Usuario)
    
    Escribir-ColorTexto "👀 Modo vigilancia activado" "Azul"
    Escribir-ColorTexto "💡 Los cambios se sincronizarán automáticamente" "Amarillo"
    Escribir-ColorTexto "Press Ctrl+C para detener" "Amarillo"
    
    $ultimaSync = Get-Date
    
    while ($true) {
        Start-Sleep -Seconds 5
        
        # Verificar si hay cambios
        if (Test-Path $REPO_LOCAL) {
            Set-Location $REPO_LOCAL
            $cambios = git status --porcelain 2>$null
            
            if ($cambios) {
                $ahora = Get-Date
                if (($ahora - $ultimaSync).TotalSeconds -gt 30) {  # Esperar al menos 30 segundos
                    Escribir-ColorTexto "🔄 Cambios detectados, sincronizando..." "Amarillo"
                    Sincronizar-ATermux -IP $IP -Usuario $Usuario
                    $ultimaSync = $ahora
                }
            }
        }
    }
}

function Mostrar-Uso {
    Escribir-ColorTexto "🔧 Herramienta Rsync para Widgets Termux" "Azul"
    Escribir-ColorTexto "=========================================" "Azul"
    Write-Host ""
    Write-Host "Uso:"
    Write-Host "  .\rsync-termux.ps1 enviar <IP> <usuario>     - Enviar cambios a Termux"
    Write-Host "  .\rsync-termux.ps1 recibir <IP> <usuario>    - Recibir desde Termux"
    Write-Host "  .\rsync-termux.ps1 vigilar <IP> <usuario>    - Vigilar y sincronizar auto"
    Write-Host ""
    Write-Host "Opciones:"
    Write-Host "  -Simulacion    - Simular sin hacer cambios"
    Write-Host "  -Forzar        - Forzar sin confirmación"
    Write-Host ""
    Write-Host "Ejemplos:"
    Write-Host "  .\rsync-termux.ps1 enviar 192.168.1.100 miusuario"
    Write-Host "  .\rsync-termux.ps1 recibir 192.168.1.100 miusuario -Simulacion"
    Write-Host "  .\rsync-termux.ps1 vigilar 192.168.1.100 miusuario"
    Write-Host ""
}

# Ejecutar acción
switch ($Accion.ToLower()) {
    "enviar" { Sincronizar-ATermux -IP $IP_Termux -Usuario $Usuario }
    "recibir" { Sincronizar-DeTermux -IP $IP_Termux -Usuario $Usuario }
    "vigilar" { Vigilar-Y-Sincronizar -IP $IP_Termux -Usuario $Usuario }
    default { Mostrar-Uso }
}