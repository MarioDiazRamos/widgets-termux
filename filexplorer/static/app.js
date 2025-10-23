
const listaArchivos = document.getElementById('lista-archivos');
const rutaActualElemento = document.getElementById('ruta-actual');
const botonAtras = document.getElementById('boton-regresar');
const modalEditor = document.getElementById('modal-editor');
const nombreArchivoEditor = document.getElementById('nombre-archivo-editor');
const contenidoArchivoEditor = document.getElementById('contenido-archivo');
const botonGuardar = document.getElementById('boton-guardar');
const botonCerrar = document.getElementById('boton-cerrar');
const entradaBusqueda = document.getElementById('entrada-busqueda');
const botonBuscar = document.getElementById('boton-buscar');
const alternarRegex = document.getElementById('alternar-regex');
const cajaResultados = document.getElementById('resultados-busqueda');
const listaResultados = document.getElementById('lista-resultados');

let rutaActual = '';
let archivoActivo = '';
let idBusqueda = null;

const formatearTamano = (bytes) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const tamanos = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + tamanos[i];
};

const obtenerIcono = (elemento) => {
    if (elemento.tipo === 'carpeta') return '📁';
    const extension = elemento.nombre.split('.').pop().toLowerCase();
    switch (extension) {
        case 'py':
        case 'sh':
        case 'js':
            return '📄';
        case 'png':
        case 'jpg':
        case 'jpeg':
        case 'gif':
            return '🖼️';
        case 'mp4':
        case 'mov':
        case 'mkv':
            return '🎬';
        case 'mp3':
        case 'wav':
        case 'ogg':
            return '🎵';
        case 'zip':
        case 'rar':
        case '7z':
            return '📦';
        case 'pdf':
            return '📘';
        default:
            return '❓';
    }
};

const mostrarEditor = (nombre, contenido) => {
    nombreArchivoEditor.textContent = nombre;
    contenidoArchivoEditor.value = contenido;
    modalEditor.classList.remove('oculto');
    contenidoArchivoEditor.focus();
};

const ocultarEditor = () => {
    modalEditor.classList.add('oculto');
};

const abrirArchivoTexto = async (ruta, nombre) => {
    try {
        const respuesta = await fetch(`/api/leer_archivo?path=${encodeURIComponent(ruta)}`);
        const datos = await respuesta.json();
        if (respuesta.status !== 200) {
            alert(`Error: ${datos.error}`);
            return;
        }
        archivoActivo = ruta;
        mostrarEditor(nombre, datos.contenido);
    } catch (error) {
        alert('Error al leer el archivo.');
    }
};

const abrirArchivoExterno = async (ruta) => {
    try {
        const respuesta = await fetch(`/api/abrir_externo?path=${encodeURIComponent(ruta)}`);
        const datos = await respuesta.json();
        if (respuesta.status !== 200) {
            alert(`Error: ${datos.error}`);
        }
    } catch (error) {
        alert('Error al intentar abrir el archivo.');
    }
};

const guardarArchivo = async () => {
    const contenido = contenidoArchivoEditor.value;
    const respuesta = await fetch(`/api/guardar_archivo`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            path: archivoActivo,
            content: contenido
        })
    });
    const datos = await respuesta.json();
    if (datos.exito) {
        alert('Archivo guardado con éxito.');
        ocultarEditor();
        listarArchivos(rutaActual);
    } else {
        alert(`Error al guardar: ${datos.error}`);
    }
};


const listarArchivos = async (ruta = '') => {
    try {
        rutaActual = ruta;
        rutaActualElemento.textContent = `/${ruta}`;
        botonAtras.style.display = ruta === '' ? 'none' : 'inline-block';
    listaArchivos.innerHTML = `<div class='mensaje'>Cargando...</div>`;
        const respuesta = await fetch(`/api/lista?path=${encodeURIComponent(ruta)}`);
        const datos = await respuesta.json();
        if (respuesta.status !== 200) {
            listaArchivos.innerHTML = `<div class="message error">${datos.error}</div>`;
            return;
        }
        listaArchivos.innerHTML = '';
        datos.elementos.forEach(elemento => {
            const elementoDiv = document.createElement('div');
            elementoDiv.className = 'elemento-archivo';
            elementoDiv.innerHTML = `
                <span class='icono-archivo'>${obtenerIcono(elemento)}</span>
                <span class='nombre-archivo'>${elemento.nombre}</span>
                <span class='meta-archivo'>${elemento.tipo === 'archivo' ? formatearTamano(elemento.tamano) : ''}</span>
            `;
            elementoDiv.addEventListener('click', () => {
                if (elemento.tipo === 'carpeta') {
                    listarArchivos(elemento.ruta);
                } else if (elemento.es_texto) {
                    abrirArchivoTexto(elemento.ruta, elemento.nombre);
                } else {
                    abrirArchivoExterno(elemento.ruta);
                }
            });
            listaArchivos.appendChild(elementoDiv);
        });
    } catch (error) {
    listaArchivos.innerHTML = `<div class='mensaje error'>Error al conectar con el servidor.</div>`;
    }
};


const iniciarBusqueda = async () => {
    const consulta = entradaBusqueda.value;
    if (!consulta) return;
    listaResultados.innerHTML = `<div class='mensaje'>Buscando...</div>`;
    cajaResultados.classList.remove('oculto');
    const respuesta = await fetch(`/api/buscar?query=${encodeURIComponent(consulta)}&regex=${alternarRegex.checked}`);
    const datos = await respuesta.json();
    if (respuesta.status !== 200) {
    listaResultados.innerHTML = `<div class='mensaje error'>${datos.error}</div>`;
        return;
    }
    idBusqueda = datos.id_trabajo;
    verificarResultadosBusqueda();
};

const verificarResultadosBusqueda = async () => {
    if (!idBusqueda) return;
    const respuesta = await fetch(`/api/resultados_busqueda/${idBusqueda}`);
    const datos = await respuesta.json();
    if (datos.estado === 'pendiente') {
        setTimeout(verificarResultadosBusqueda, 1000);
    } else if (datos.estado === 'completado') {
        mostrarResultados(datos.resultados);
        idBusqueda = null;
    } else if (datos.estado === 'error') {
        listaResultados.innerHTML = `<div class="message error">${datos.mensaje}</div>`;
        idBusqueda = null;
    }
};

const mostrarResultados = (resultados) => {
    listaResultados.innerHTML = '';
    if (resultados.length === 0) {
        listaResultados.innerHTML = `<div class='mensaje'>No se encontraron resultados.</div>`;
        return;
    }
    resultados.forEach(resultado => {
        const resultadoDiv = document.createElement('div');
        resultadoDiv.className = 'elemento-resultado';
        resultadoDiv.innerHTML = `
            <div class='nombre-archivo'>${resultado.archivo}:${resultado.linea}</div>
            <div class='coincidencia'>${resultado.coincidencia}</div>
        `;
        resultadoDiv.addEventListener('click', () => {
            abrirArchivoTexto(resultado.archivo, resultado.archivo.split('/').pop());
        });
        listaResultados.appendChild(resultadoDiv);
    });
};


botonAtras.addEventListener('click', () => {
    const rutaPadre = rutaActual.split('/').slice(0, -1).join('/');
    listarArchivos(rutaPadre);
});
botonGuardar.addEventListener('click', guardarArchivo);
botonCerrar.addEventListener('click', ocultarEditor);
botonBuscar.addEventListener('click', iniciarBusqueda);
entradaBusqueda.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') iniciarBusqueda();
});

listarArchivos();
