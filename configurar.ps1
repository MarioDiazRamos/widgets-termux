# Configuración rápida para nuevo repositorio de Widgets Termux

Write-Host "📁 Configurando repositorio de Widgets Termux..." -ForegroundColor Blue

# Verificar si Git está disponible
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Git no está instalado. Por favor instala Git para Windows." -ForegroundColor Red
    exit 1
}

# Inicializar Git si es necesario
if (-not (Test-Path ".git")) {
    Write-Host "🌱 Inicializando Git..." -ForegroundColor Green
    git init
    git add .
    git commit -m "Commit inicial - Repositorio de Widgets Termux"
}

Write-Host "✅ Repositorio configurado" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Próximos pasos:" -ForegroundColor Yellow
Write-Host "1. Crea un repositorio en GitHub llamado 'widgets-termux'"
Write-Host "2. Configura el remote de GitHub:"
Write-Host "   git remote add origin https://github.com/tu-usuario/widgets-termux.git"
Write-Host ""
Write-Host "3. Sube el repositorio:"
Write-Host "   git push -u origin main"
Write-Host ""
Write-Host "4. En Termux, descarga sincronizar-widgets.sh:"
Write-Host "   curl -O https://raw.githubusercontent.com/tu-usuario/widgets-termux/main/sincronizar-widgets.sh"
Write-Host ""
Write-Host "5. Edita la URL en el script y ejecuta la primera sincronización:"
Write-Host "   chmod +x sincronizar-widgets.sh"
Write-Host "   nano sincronizar-widgets.sh  # Editar REPO_URL"
Write-Host "   ./sincronizar-widgets.sh"