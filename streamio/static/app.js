document.getElementById('form-buscar').onsubmit = async function(e) {
  e.preventDefault();
  const q = document.getElementById('q').value.trim();
  if (!q) return;
  const res = await fetch(`/search?q=${encodeURIComponent(q)}`);
  const datos = await res.json();
  const resultados = document.getElementById('resultados');
  resultados.innerHTML = '';
  if (!datos || Object.keys(datos).length === 0) {
    resultados.innerHTML = '<div class="alert alert-warning">Sin resultados.</div>';
    return;
  }
  Object.keys(datos).forEach(fuente => {
    const fuenteData = datos[fuente];
    Object.keys(fuenteData).forEach(tipo => {
      const grupo = fuenteData[tipo];
      if (!Array.isArray(grupo) || grupo.length === 0) return;
      const seccion = document.createElement('div');
      seccion.className = 'mb-4';
      seccion.innerHTML = `<h4 class="mb-2">${fuente} - ${tipo.charAt(0).toUpperCase() + tipo.slice(1)}</h4>`;
      const fila = document.createElement('div');
      fila.className = 'd-flex flex-wrap gap-3';
      grupo.forEach(item => {
        const div = document.createElement('div');
        div.className = 'card mb-2 d-flex flex-column align-items-center';
        let poster = '';
        if (item.poster) {
          poster = `<img src="${item.poster}" alt="Poster" style="width:120px;height:180px;border-radius:8px;margin:8px 0;object-fit:cover;">`;
        }
        div.innerHTML = `
          ${poster}
          <div class="card-body p-2 text-center">
            <h6 class="card-title mb-1">${item.titulo || item.title}</h6>
            <div class="small text-secondary mb-1">${item.year ? item.year : ''}</div>
            <p class="card-text mb-1">Seeds: ${item.seeds || 0}</p>
            <button class="btn btn-success btn-sm" onclick="play('${item.magnet}')">Play</button>
          </div>
        `;
        fila.appendChild(div);
      });
      seccion.appendChild(fila);
      resultados.appendChild(seccion);
    });
  });
};

async function play(magnet) {
  const res = await fetch(`/stream?magnet=${encodeURIComponent(magnet)}`);
  const datos = await res.json();
  const playerDiv = document.getElementById('player');
  if (datos.url) {
    let html = '';
    if (datos.compatible) {
      html += `<video src="${datos.url}" controls autoplay style="width:100%;max-width:600px;"></video>`;
    }
    html += `<div class="alert ${datos.compatible ? 'alert-success' : 'alert-warning'} mt-2">${datos.msg || ''}</div>`;
    html += `<a href="intent://${datos.url.replace('http://','')}#Intent;scheme=http;package=org.videolan.vlc;end" class="btn btn-warning mt-2">Abrir en VLC</a>`;
    playerDiv.innerHTML = html;
  } else {
    playerDiv.innerHTML = '<div class="alert alert-danger">No se pudo iniciar el stream.</div>';
  }
}
