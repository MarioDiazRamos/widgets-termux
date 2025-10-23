document.addEventListener('DOMContentLoaded', () => {
    // Configuración avanzada FFMPEG
    const formularioAvanzado = document.getElementById('formulario-ffmpeg-avanzado');
    const entradaArgumentosExtra = document.getElementById('argumentos-ffmpeg-extra');
    formularioAvanzado.addEventListener('submit', (e) => {
        e.preventDefault();
        localStorage.setItem('ffmpeg_extra_args', entradaArgumentosExtra.value);
        mostrarToast('Configuración avanzada guardada.', 'exito');
    });
    entradaArgumentosExtra.value = localStorage.getItem('ffmpeg_extra_args') || '';

    // Selectores de archivos
    const selectorVideoTransponer = document.getElementById('transponer-video');
    const selectorAudioTransponer = document.getElementById('transponer-audio');
    const selectorAudioKaraoke = document.getElementById('karaoke-audio');
    const selectorVideoKaraoke = document.getElementById('karaoke-video');

    // Previsualización de archivos
    function mostrarPrevisualizacion(select, divPrevisualizacion, tipo) {
        const archivo = select.value;
        if (!archivo) {
            divPrevisualizacion.innerHTML = '';
            return;
        }
        let url = `/static/${archivo}`;
        if (tipo === 'video') {
            divPrevisualizacion.innerHTML = `<video src="${url}" controls style="max-width:100%;max-height:120px;"></video>`;
        } else if (tipo === 'audio') {
            divPrevisualizacion.innerHTML = `<audio src="${url}" controls style="width:100%;"></audio>`;
        }
    }
    selectorVideoTransponer.addEventListener('change', () => {
        mostrarPrevisualizacion(selectorVideoTransponer, document.getElementById('previsualizacion-transponer-video'), 'video');
    });
    selectorAudioTransponer.addEventListener('change', () => {
        mostrarPrevisualizacion(selectorAudioTransponer, document.getElementById('previsualizacion-transponer-audio'), 'audio');
    });
    selectorVideoKaraoke.addEventListener('change', () => {
        mostrarPrevisualizacion(selectorVideoKaraoke, document.getElementById('previsualizacion-karaoke-video'), 'video');
    });
    selectorAudioKaraoke.addEventListener('change', () => {
        mostrarPrevisualizacion(selectorAudioKaraoke, document.getElementById('previsualizacion-karaoke-audio'), 'audio');
    });

    // Progreso visual
    const contenedorBarraProgreso = document.getElementById('contenedor-barra-progreso');
    const barraProgreso = document.getElementById('barra-progreso');
    const etiquetaProgreso = document.getElementById('etiqueta-progreso');
    let intervaloProgreso = null;
    function iniciarProgreso() {
        if (intervaloProgreso) clearInterval(intervaloProgreso);
        contenedorBarraProgreso.style.display = 'block';
        let porcentaje = 0;
        barraProgreso.style.width = '0%';
        etiquetaProgreso.textContent = 'Procesando...';
        intervaloProgreso = setInterval(() => {
            porcentaje = Math.min(porcentaje + Math.random() * 10, 95);
            barraProgreso.style.width = porcentaje + '%';
            if (porcentaje >= 95) clearInterval(intervaloProgreso);
        }, 800);
    }
    function detenerProgreso() {
        if (intervaloProgreso) clearInterval(intervaloProgreso);
        contenedorBarraProgreso.style.display = 'none';
        barraProgreso.style.width = '0%';
        etiquetaProgreso.textContent = '';
    }

    // Historial de trabajos
    const contenedorHistorialTrabajos = document.getElementById('contenedor-historial-trabajos');
    const botonActualizarHistorial = document.getElementById('boton-actualizar-historial');
    async function cargarHistorialTrabajos() {
        // No existe /api/jobs_history en el backend, así que mostramos un placeholder
        contenedorHistorialTrabajos.innerHTML = '<p class="placeholder">No hay historial de trabajos aún.</p>';
    }
    botonActualizarHistorial.addEventListener('click', cargarHistorialTrabajos);
    cargarHistorialTrabajos();

    // Formularios
    const formularioTransponer = document.getElementById('formulario-transponer');
    const formularioKaraoke = document.getElementById('formulario-karaoke');
    const contenedorTrabajos = document.getElementById('contenedor-trabajos');
    const plantillaTrabajo = document.getElementById('plantilla-trabajo');
    const opcionesSincronizacion = document.querySelectorAll('input[name="opcion_sincronizacion"]');
    const botonActualizarTrabajos = document.getElementById('boton-actualizar-trabajos');
    let trabajosActivos = new Set();

    // --- FUNCIONES DE API ---
    async function llamadaApi(url, opciones = {}) {
        try {
            const respuesta = await fetch(url, opciones);
            if (!respuesta.ok) {
                const errorData = await respuesta.json();
                throw new Error(errorData.error || `Error ${respuesta.status}`);
            }
            return await respuesta.json();
        } catch (error) {
            console.error('Error en la llamada API:', error);
            alert(`Error: ${error.message}`);
            return null;
        }
    }

    async function cargarArchivosMedios(endpoint, selects) {
        // Adaptar endpoints a español
        let endpointReal = endpoint;
        if (endpoint === '/api/list_videos') endpointReal = '/api/listar_videos';
        if (endpoint === '/api/list_audios') endpointReal = '/api/listar_audios';
        let archivos = null;
        try {
            archivos = await llamadaApi(endpointReal);
        } catch (e) {
            archivos = null;
        }
        for (const select of selects) {
            select.innerHTML = '';
            let etiqueta = endpointReal.includes('audio') ? 'audio' : 'video';
            if (!archivos) {
                const opt = document.createElement('option');
                opt.value = '';
                opt.disabled = true;
                opt.selected = true;
                opt.textContent = `Error al cargar archivos de ${etiqueta}. Verifica conexión o permisos.`;
                select.appendChild(opt);
                continue;
            }
            if (!Array.isArray(archivos) || archivos.length === 0) {
                const opt = document.createElement('option');
                opt.value = '';
                opt.disabled = true;
                opt.selected = true;
                opt.textContent = `No hay archivos de ${etiqueta} disponibles.`;
                select.appendChild(opt);
                continue;
            }
            if (select.id === 'karaoke-video') {
                const opt = document.createElement('option');
                opt.value = '';
                opt.textContent = '-- Sin video --';
                select.appendChild(opt);
            } else {
                const opt = document.createElement('option');
                opt.value = '';
                opt.disabled = true;
                opt.selected = true;
                opt.textContent = `Selecciona un ${etiqueta}...`;
                select.appendChild(opt);
            }
            archivos.forEach(archivo => {
                if (!archivo.nombre) return;
                const opcion = document.createElement('option');
                opcion.value = archivo.nombre;
                opcion.textContent = archivo.nombre;
                select.appendChild(opcion);
            });
        }
    }

    // --- LÓGICA DE INTERFAZ ---
    function actualizarVisibilidadDelay() {
        const entradaDelay = document.getElementById('karaoke-delay-sinc');
        const opcionSeleccionada = document.querySelector('input[name="opcion_sincronizacion"]:checked').value;
        if (opcionSeleccionada === '2' || opcionSeleccionada === '3') {
            entradaDelay.disabled = false;
        } else {
            entradaDelay.disabled = true;
            entradaDelay.value = 0;
        }
    }

    function agregarTrabajoUI(jobid, datosTrabajo) {
        if (contenedorTrabajos.querySelector('.placeholder')) {
            contenedorTrabajos.innerHTML = '';
        }
        const clon = plantillaTrabajo.content.cloneNode(true);
        const tarjetaTrabajo = clon.querySelector('.tarjeta-trabajo');
        tarjetaTrabajo.dataset.jobid = jobid;
        tarjetaTrabajo.querySelector('.id-trabajo').textContent = jobid;
        tarjetaTrabajo.querySelector('.salida-trabajo').textContent = datosTrabajo.salida;
        tarjetaTrabajo.querySelector('.comando-trabajo').textContent = datosTrabajo.comando;
        tarjetaTrabajo.querySelector('.enlace-log-trabajo').href = `/api/log_trabajo/${jobid}`;
        const estado = tarjetaTrabajo.querySelector('.estado-trabajo');
        estado.innerHTML = `<i class='fa-solid fa-spinner fa-spin'></i> EN PROCESO`;
        contenedorTrabajos.prepend(tarjetaTrabajo);
        trabajosActivos.add(jobid);
    }

    // --- NOTIFICACIONES TOAST ---
    function mostrarToast(mensaje, tipo = 'exito') {
        const contenedor = document.getElementById('contenedor-toast');
        if (!contenedor) return;
        const toast = document.createElement('div');
        toast.className = `toast toast-${tipo}`;
        toast.innerHTML = `
            <span>${tipo === 'exito' ? '<i class="fa-solid fa-check"></i>' : '<i class="fa-solid fa-xmark"></i>'}</span>
            <span>${mensaje}</span>
            <button class="cerrar-toast boton-neon" title="Cerrar">&times;</button>
        `;
        toast.querySelector('.cerrar-toast').onclick = () => contenedor.removeChild(toast);
        contenedor.appendChild(toast);
        setTimeout(() => {
            if (contenedor.contains(toast)) contenedor.removeChild(toast);
        }, 4000);
    }

    async function actualizarEstadoTrabajo(jobid) {
        const tarjetaTrabajo = contenedorTrabajos.querySelector(`.tarjeta-trabajo[data-jobid="${jobid}"]`);
        if (!tarjetaTrabajo) return;
        const datosEstado = await llamadaApi(`/api/estado/${jobid}`);
        if (!datosEstado) {
            trabajosActivos.delete(jobid);
            return;
        }
        const estado = datosEstado.estado;
        const estadoElemento = tarjetaTrabajo.querySelector('.estado-trabajo');
        tarjetaTrabajo.dataset.estado = estado;
        if (estado === 'finalizado') {
            estadoElemento.innerHTML = `<i class='fa-solid fa-check'></i> COMPLETADO`;
            mostrarToast('Trabajo completado correctamente.', 'exito');
            detenerProgreso();
        } else if (estado === 'error') {
            estadoElemento.innerHTML = `<i class='fa-solid fa-xmark'></i> ERROR`;
            mostrarToast('Hubo un error en el trabajo.', 'error');
            detenerProgreso();
        } else {
            estadoElemento.innerHTML = `<i class='fa-solid fa-spinner fa-spin'></i> EN PROCESO`;
            iniciarProgreso();
        }
        estadoElemento.dataset.estado = estado;
        if (estado === 'finalizado' || estado === 'error') {
            trabajosActivos.delete(jobid);
        }
    }

    function actualizarTodosTrabajos() {
        if (trabajosActivos.size === 0) return;
        for (const jobid of trabajosActivos) {
            actualizarEstadoTrabajo(jobid);
        }
        if (trabajosActivos.size > 0) {
            iniciarProgreso();
        } else {
            detenerProgreso();
        }
    }

    // --- MANEJADORES DE EVENTOS ---
    formularioTransponer.addEventListener('submit', async (e) => {
        e.preventDefault();
        const datos = Object.fromEntries(new FormData(formularioTransponer).entries());
        datos.overlay_gain = parseFloat(datos.overlay_gain);
        const extraArgs = localStorage.getItem('ffmpeg_extra_args');
        if (extraArgs) datos.ffmpeg_extra_args = extraArgs;
        const resultado = await llamadaApi('/api/transponer', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });
        if (resultado && resultado.jobid) {
            const detalles = await llamadaApi(`/api/status/${resultado.jobid}`);
            if (detalles) {
                agregarTrabajoUI(resultado.jobid, detalles);
                iniciarProgreso();
            }
            formularioTransponer.reset();
        }
    });

    formularioKaraoke.addEventListener('submit', async (e) => {
        e.preventDefault();
        const datos = Object.fromEntries(new FormData(formularioKaraoke).entries());
        datos.sync_option = parseInt(datos.sync_option);
        datos.sync_delay = parseFloat(datos.sync_delay) || 0;
        datos.audio_start_sec = parseFloat(datos.audio_start_sec) || 0;
        if (!datos.video_path) delete datos.video_path;
        const extraArgs = localStorage.getItem('ffmpeg_extra_args');
        if (extraArgs) datos.ffmpeg_extra_args = extraArgs;
        const resultado = await llamadaApi('/api/karaoke', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });
        if (resultado && resultado.jobid) {
            const detalles = await llamadaApi(`/api/status/${resultado.jobid}`);
            if (detalles) {
                agregarTrabajoUI(resultado.jobid, detalles);
                iniciarProgreso();
            }
            formularioKaraoke.reset();
        }
    });

    selectorVideoTransponer.addEventListener('change', (e) => {
        const nombre = e.target.value.split('\\').pop();
        document.getElementById('transponer-video-filename').textContent = nombre;
    });
    selectorAudioTransponer.addEventListener('change', (e) => {
        const nombre = e.target.value.split('\\').pop();
        document.getElementById('transponer-audio-filename').textContent = nombre;
    });
    selectorVideoKaraoke.addEventListener('change', (e) => {
        const nombre = e.target.value.split('\\').pop();
        document.getElementById('karaoke-video-filename').textContent = nombre;
    });
    selectorAudioKaraoke.addEventListener('change', (e) => {
        const nombre = e.target.value.split('\\').pop();
        document.getElementById('karaoke-audio-filename').textContent = nombre;
    });
    opcionesSincronizacion.forEach(radio => {
        radio.addEventListener('change', actualizarVisibilidadDelay);
    });
    botonActualizarTrabajos.addEventListener('click', actualizarTodosTrabajos);
    // --- CARGA INICIAL DE ARCHIVOS ---
    cargarArchivosMedios('/api/listar_videos', [selectorVideoTransponer, selectorVideoKaraoke]);
    cargarArchivosMedios('/api/listar_audios', [selectorAudioTransponer, selectorAudioKaraoke]);
});
