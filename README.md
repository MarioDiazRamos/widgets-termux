# 🚀 Sistema de Widgets Termux - Versionado con GitHub

Sistema completo para administrar y versionar scripts de Termux Widgets usando GitHub como intermediario, permitiendo desarrollo desde PC y sincronización automática.

## 📋 Características

- ✅ **Versionado completo** con Git y GitHub
- ✅ **Desarrollo desde PC** con sincronización automática  
- ✅ **Enlaces simbólicos** para mantener estructura de Termux
- ✅ **Actualizaciones automáticas** programadas
- ✅ **Respaldo y restauración** completa
- ✅ **Múltiples dispositivos** sincronizados
- ✅ **Interfaz en español** para mayor facilidad de uso

## 🏗️ Estructura del Sistema

```
📁 Termux (Android)
├── ~/widgets-termux/                # Repositorio Git clonado
│   ├── descarga.sh                  # Scripts versionados
│   ├── agente.py                    # 
│   └── otros-scripts.sh             # 
├── ~/.shortcuts/                    # Carpeta de widgets (enlaces simbólicos)
│   ├── descarga -> ~/widgets-termux/descarga.sh
│   ├── agente -> ~/widgets-termux/agente.py  
│   └── otros-scripts -> ~/widgets-termux/otros-scripts.sh
├── ~/sincronizar-widgets.sh         # Script de sincronización principal
└── ~/actualizador-automatico.sh     # Script de actualizaciones automáticas

📁 PC (Windows)
├── 📁 widgets-termux/               # Repositorio local para desarrollo
│   ├── descarga.sh                  # Edición y desarrollo
│   ├── agente.py                    # 
│   └── otros-scripts.sh             # 
├── sincronizar-pc.ps1               # Script de sincronización SCP
├── rsync-termux.ps1                 # Script de sincronización Rsync
└── plantilla-script.sh              # Plantilla para nuevos scripts

☁️ GitHub Repository
└── https://github.com/tu-usuario/widgets-termux.git
```

## 🚀 Instalación y Configuración

### 1. Configuración inicial en Termux

```bash
# Descargar script de sincronización
curl -O https://raw.githubusercontent.com/tu-usuario/widgets-termux/main/sincronizar-widgets.sh

# Dar permisos
chmod +x sincronizar-widgets.sh

# Editar la URL del repositorio en el script
nano sincronizar-widgets.sh
# Cambiar: REPO_URL="https://github.com/tu-usuario/widgets-termux.git"

# Ejecutar primera sincronización
./sincronizar-widgets.sh
```

### 2. Configuración en PC (Windows)

```powershell
# Configuración inicial del repositorio local
.\sincronizar-pc.ps1 configurar

# Configurar repositorio remoto
cd widgets-termux
git remote add origin https://github.com/tu-usuario/widgets-termux.git
```

### 3. Configurar SSH en Termux (opcional para PC)

```bash
# Instalar OpenSSH
pkg install openssh

# Iniciar servidor SSH
sshd

# Ver IP del dispositivo
ip addr show wlan0
```

## 📱 Uso Diario

### Desde Termux

```bash
# Actualizar scripts manualmente
~/sincronizar-widgets.sh

# Ver estado del auto-actualizador
~/actualizador-automatico.sh estado

# Programar actualizaciones automáticas
~/actualizador-automatico.sh programar

# Verificar actualizaciones disponibles
~/actualizador-automatico.sh verificar

# Actualizar inmediatamente
~/actualizador-automatico.sh ahora
```

### Desde PC

```powershell
# Ver estado del repositorio local
.\sincronizar-pc.ps1 estado

# Enviar cambios a Termux (requiere SSH configurado)
.\sincronizar-pc.ps1 desplegar 192.168.1.100 tu-usuario

# Usar rsync para sincronización más eficiente
.\rsync-termux.ps1 enviar 192.168.1.100 tu-usuario

# Modo vigilancia (sincronización automática)
.\rsync-termux.ps1 vigilar 192.168.1.100 tu-usuario
```

## 🔄 Flujos de Trabajo

### Agregar un nuevo script

**Opción A: Desde PC**
1. Crear/editar script en `widgets-termux/`
2. `git add . && git commit -m "Nuevo script"`
3. `git push origin main`
4. En Termux: `~/sincronizar-widgets.sh`

**Opción B: Desarrollo directo en Termux**
1. Editar en `~/widgets-termux/`
2. `git add . && git commit -m "Cambios"`
3. `git push origin main`
4. `~/sincronizar-widgets.sh`

### Restaurar en dispositivo nuevo

```bash
# Instalar dependencias
pkg update && pkg install git termux-api

# Descargar script de sincronización
curl -O https://raw.githubusercontent.com/tu-usuario/widgets-termux/main/sincronizar-widgets.sh
chmod +x sincronizar-widgets.sh

# Editar URL del repo y ejecutar
nano sincronizar-widgets.sh
./sincronizar-widgets.sh
```

## 🛠️ Scripts Incluidos

### `sincronizar-widgets.sh`
- **Función**: Script principal de sincronización para Termux
- **Ubicación**: `~/sincronizar-widgets.sh`
- **Uso**: `./sincronizar-widgets.sh`
- **Características**:
  - Clona repositorio en primera ejecución
  - Actualiza con `git pull` en siguientes usos
  - Crea enlaces simbólicos automáticamente
  - Da permisos ejecutables
  - Detecta y limpia enlaces rotos
  - Muestra estadísticas de proceso

### `actualizador-automatico.sh`
- **Función**: Automatización y programación de actualizaciones
- **Ubicación**: `~/actualizador-automatico.sh`
- **Comandos**:
  - `ahora` - Actualizar inmediatamente
  - `programar` - Programar actualizaciones (cada 6h)
  - `cancelar` - Cancelar auto-actualizaciones
  - `estado` - Ver estado y logs
  - `verificar` - Solo verificar actualizaciones

### `sincronizar-pc.ps1` (PC)
- **Función**: Sincronización desde PC usando SCP
- **Comandos**:
  - `configurar` - Configuración inicial
  - `enviar` - Enviar cambios a Termux
  - `recibir` - Recibir cambios desde Termux
  - `desplegar` - Enviar + activar en Termux
  - `estado` - Estado del repositorio local

### `rsync-termux.ps1` (PC)
- **Función**: Sincronización eficiente con rsync
- **Comandos**:
  - `enviar` - Sincronizar hacia Termux
  - `recibir` - Sincronizar desde Termux
  - `vigilar` - Vigilancia y sync automático
- **Opciones**: `-Simulacion`, `-Forzar`

### `plantilla-script.sh`
- **Función**: Plantilla para crear nuevos scripts
- **Incluye**:
  - Estructura básica con colores
  - Funciones de utilidad comunes
  - Verificación de dependencias
  - Manejo de entrada de usuario
  - Sistema de notificaciones

## 🔧 Personalización

### Variables importantes

**En `sincronizar-widgets.sh`:**
```bash
REPO_URL="https://github.com/tu-usuario/widgets-termux.git"
CARPETA_WIDGETS="$HOME/widgets-termux"
CARPETA_SHORTCUTS="$HOME/.shortcuts"
```

**En scripts de PC:**
```powershell
$REPO_LOCAL = ".\widgets-termux"
$PUERTO_TERMUX = "8022"
```

### Filtros de archivos

Los scripts excluyen automáticamente:
- `README.md`, `LICENSE`, `.gitignore`
- Archivos temporales (`.tmp`, `.log`)
- Carpeta `.git`
- Archivos de configuración (`configurar-*`, `instrucciones-*`)

## 🚨 Solución de Problemas

### Widget no muestra scripts nuevos
```bash
# Verificar enlaces
ls -la ~/.shortcuts/

# Recrear enlaces
~/sincronizar-widgets.sh

# Reiniciar widget o dispositivo
```

### Error de permisos SSH
```bash
# Regenerar claves SSH
ssh-keygen -t rsa -b 4096

# Verificar servidor SSH
ps aux | grep sshd
```

### Conflictos de Git
```bash
# Resetear cambios locales
cd ~/widgets-termux
git reset --hard origin/main

# O hacer merge manual
git pull --no-ff
```

## 📈 Scripts de Ejemplo Incluidos

### `descarga.sh` - Descargador de YouTube
- Descarga música de YouTube en formato FLAC o original
- Incluye metadatos y miniaturas
- Organiza por álbum y número de pista

### `agente.py` - Agente con IA Gemini
- Convierte instrucciones en comandos ejecutables
- Filtros de seguridad incorporados
- Confirmación antes de ejecutar comandos

## 🤝 Cómo Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

---

**💡 Tip**: Usa la plantilla `plantilla-script.sh` para crear nuevos scripts con estructura consistente.

**⚠️ Importante**: Siempre haz backup de tus scripts importantes antes de experimentar.