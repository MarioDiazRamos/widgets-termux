# 🔧 Instrucciones de Configuración del Sistema de Widgets Termux

## ✅ Archivos creados exitosamente

Todos los archivos del sistema han sido creados en la carpeta:
`C:\Users\maryc\OneDrive - Universidad de Guanajuato\Escritorio\Scripts Wigets Termux`

### 📄 Lista de archivos:
- `sincronizar-widgets.sh` - Script principal para Termux
- `actualizador-automatico.sh` - Actualizador automático para Termux  
- `sincronizar-pc.ps1` - Sincronización desde PC (SCP)
- `rsync-termux.ps1` - Sincronización eficiente (Rsync)
- `descarga.sh` - Tu script de descarga de YouTube
- `agente.py` - Tu agente con IA Gemini
- `plantilla-script.sh` - Plantilla para nuevos scripts
- `README.md` - Documentación completa
- `.gitignore` - Filtros de archivos para Git
- `configurar.ps1` - Script de configuración automática

---

## 📋 PASOS PARA COMPLETAR LA CONFIGURACIÓN

### Paso 1: Instalar Git (si no lo tienes)
```powershell
# Opción A: Descargar desde https://git-scm.com/download/win
# Opción B: Usar winget (Windows 10/11)
winget install --id Git.Git -e --source winget

# Opción C: Usar Chocolatey (si lo tienes instalado)
choco install git
```

### Paso 2: Configurar Git (primera vez solamente)
```powershell
git config --global user.name "Tu Nombre"
git config --global user.email "tu-email@ejemplo.com"
```

### Paso 3: Crear repositorio en GitHub
1. Ve a https://github.com/new
2. Nombre del repositorio: `widgets-termux`
3. **¡IMPORTANTE!** Marca como **Privado** 🔒
4. No agregues README, .gitignore o licencia (ya están incluidos)
5. Haz clic en "Create repository"

### Paso 4: Configurar repositorio local
```powershell
# En la carpeta actual, ejecutar:
git init
git add .
git commit -m "Commit inicial - Sistema de Widgets Termux"

# Agregar el repositorio remoto (cambia TU-USUARIO por tu usuario de GitHub)
git remote add origin https://github.com/TU-USUARIO/widgets-termux.git

# Subir archivos a GitHub
git push -u origin main
```

### Paso 5: Configurar Termux (en tu teléfono Android)
```bash
# 1. Instalar dependencias
pkg update && pkg upgrade
pkg install git termux-api curl

# 2. Descargar script de sincronización
curl -O https://raw.githubusercontent.com/TU-USUARIO/widgets-termux/main/sincronizar-widgets.sh

# 3. Dar permisos ejecutables
chmod +x sincronizar-widgets.sh

# 4. Editar URL del repositorio
nano sincronizar-widgets.sh
# Cambiar la línea: REPO_URL="https://github.com/TU-USUARIO/widgets-termux.git"

# 5. Ejecutar primera sincronización
./sincronizar-widgets.sh

# 6. (Opcional) Configurar actualizaciones automáticas
curl -O https://raw.githubusercontent.com/TU-USUARIO/widgets-termux/main/actualizador-automatico.sh
chmod +x actualizador-automatico.sh
./actualizador-automatico.sh programar
```

### Paso 6: Verificar funcionamiento
```bash
# En Termux, verificar que los scripts estén vinculados:
ls -la ~/.shortcuts/

# Deberías ver:
# descarga -> /data/data/com.termux/files/home/widgets-termux/descarga.sh
# agente -> /data/data/com.termux/files/home/widgets-termux/agente.py
```

### Paso 7: Actualizar widget
1. **Reinicia tu dispositivo Android** O
2. **Quita y vuelve a agregar el widget de Termux** a la pantalla de inicio
3. El widget ahora debería mostrar botones para "descarga" y "agente"

---

## 🎯 Flujo de trabajo diario

### Para agregar nuevos scripts:
1. **Desde PC**: Crea/edita archivos en la carpeta, luego:
   ```powershell
   git add .
   git commit -m "Nuevo script: nombre-script"
   git push origin main
   ```

2. **En Termux**: Actualiza con:
   ```bash
   ~/sincronizar-widgets.sh
   ```

### Para desarrollo remoto (opcional):
```powershell
# Si tienes SSH configurado en Termux:
.\sincronizar-pc.ps1 desplegar 192.168.1.XXX tu-usuario

# Para vigilancia automática:
.\rsync-termux.ps1 vigilar 192.168.1.XXX tu-usuario
```

---

## 🆘 Solución de problemas

### Si el widget no muestra los scripts:
```bash
# Verificar enlaces:
ls -la ~/.shortcuts/

# Recrear enlaces:
~/sincronizar-widgets.sh

# Reiniciar widget o dispositivo
```

### Si git no funciona en Termux:
```bash
pkg install git
git config --global user.name "Tu Nombre"
git config --global user.email "tu-email@ejemplo.com"
```

### Si hay problemas de permisos:
```bash
chmod +x ~/widgets-termux/*
chmod +x ~/.shortcuts/*
```

---

## 🎉 ¡Listo!

Una vez completados estos pasos, tendrás:
- ✅ Repositorio privado en GitHub con todos tus scripts
- ✅ Sistema de sincronización automática
- ✅ Widgets funcionando en Termux
- ✅ Respaldo seguro de todos tus scripts
- ✅ Capacidad de desarrollo desde PC

**¡Tu sistema de Widgets Termux versionado está completo!** 🚀