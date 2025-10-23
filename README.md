# Guía Rápida Widgets Termux

Este repositorio contiene scripts y utilidades para automatizar Termux en Android.


## Instalación y uso 


1. Instala dependencias:
   ```bash
   pkg update && pkg install git termux-api python
   ```
2. Clona el repositorio completo en la carpeta Proyectos:
  ```bash
  mkdir -p ~/Proyectos
  cd ~/Proyectos
  git clone https://github.com/MarioDiazRamos/widgets-termux.git
  ```
3. Sincroniza y configura todo automáticamente:
  ```bash
  bash ~/Proyectos/widgets-termux/sync.sh
  ```
  Esto dará permisos, creará accesos y wrappers en ~/.shortcuts y ~/bin. No necesitas configurar nada más.

4. (Opcional) Ejecuta:
   ```bash
   termux-reload-settings
   ```
   para que los accesos aparezcan en el menú de Termux.

5. Ejecuta cualquier script desde la terminal, widgets o menú.

6. Si algún script requiere API key, sigue las instrucciones en pantalla la primera vez.

---
Para dudas, consulta INSTRUCCIONES-CONFIGURACION.md o abre un issue en el repositorio.


## 📱 Uso Diario

```bash
# Sincronizar y actualizar scripts
~/sync.sh

# Ejecutar scripts disponibles
~/descarga.sh
~/karaoke.sh
~/agente.py
~/dork.py
~/doit.sh
~/clima.sh
~/apariencia.sh
~/slow.sh
# ...y otros según el menú y accesos directos
```

## 🛠️ Scripts Incluidos

### `sync.sh`
- **Función**: Script principal de sincronización para Termux
- **Ubicación**: `~/sync.sh`
- **Uso**: `./sync.sh`
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

**En `sync.sh`:**
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
~/sync.sh

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