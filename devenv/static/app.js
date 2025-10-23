
const $ = (s) => document.querySelector(s);
const healthOut = $('#healthOut');
const explorerList = $('#explorer-list');
const breadcrumb = $('#breadcrumb');
const mkdirPath = $('#mkdirPath');
const createPath = $('#createPath');
const moveSrc = $('#moveSrc');
const moveDst = $('#moveDst');
const delPath = $('#delPath');
const delRecursive = $('#delRecursive');
const jobCmd = $('#jobCmd');
const jobId = $('#jobId');
const jobOut = $('#jobOut');
let currentPath = '';
let selectedRow = null;

const fmtSize = (n) => {
  if (n == null) return '';
  const units = ['B','KB','MB','GB','TB'];
  let i=0; let x = n;
  while (x >= 1024 && i < units.length-1) { x /= 1024; i++; }
  return `${x.toFixed(1)} ${units[i]}`;
};


async function api(path, opts={}) {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...opts
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`${res.status}: ${t}`);
  }
  return res.json();
}



async function listPath(p) {
  currentPath = typeof p === 'string' ? p : currentPath || '';
  const data = await api(`/api/fs/list?path=${encodeURIComponent(currentPath)}`);
  renderBreadcrumb(currentPath);
  renderExplorerList(data);
}

function renderBreadcrumb(path) {
  const parts = path.replace(/\\/g,'/').split('/').filter(Boolean);
  let acc = '';
  breadcrumb.innerHTML = '';
  const root = document.createElement('a');
  root.textContent = 'Home';
  root.href = '#';
  root.onclick = (e) => { e.preventDefault(); listPath(''); };
  breadcrumb.appendChild(root);
  parts.forEach((part, idx) => {
    acc += '/' + part;
    const sep = document.createElement('span');
    sep.className = 'breadcrumb-sep';
    sep.textContent = '›';
    breadcrumb.appendChild(sep);
    const crumb = document.createElement('a');
    crumb.textContent = part;
    crumb.href = '#';
    crumb.onclick = (e) => { e.preventDefault(); listPath(acc); };
    breadcrumb.appendChild(crumb);
  });
}

function explorerIcon(isDir) {
  return isDir
    ? `<svg class="explorer-icon folder" viewBox="0 0 20 20"><rect x="2" y="6" width="16" height="10" rx="2" fill="#fbbf24"/><rect x="2" y="4" width="7" height="4" rx="1.5" fill="#ffe082"/></svg>`
    : `<svg class="explorer-icon file" viewBox="0 0 20 20"><rect x="4" y="3" width="12" height="14" rx="2" fill="#7dd3fc"/><rect x="6" y="6" width="8" height="2" rx="1" fill="#fff"/><rect x="6" y="10" width="8" height="2" rx="1" fill="#fff"/></svg>`;
}

function renderExplorerList(data) {
  let rows = (data.entries || []).map((e, idx) => {
    return `<tr data-path="${e.path}" data-idx="${idx}" data-dir="${e.is_dir ? 1 : 0}">
      <td>${explorerIcon(e.is_dir)}<span class="explorer-fname">${e.name}</span></td>
      <td>${e.is_dir ? 'Carpeta' : 'Archivo'}</td>
      <td style="text-align:right">${e.is_dir ? '' : fmtSize(e.size)}</td>
      <td>${new Date(e.mtime*1000).toLocaleString()}</td>
      <td><button class="explorer-action" data-action="delete" title="Borrar">🗑️</button></td>
    </tr>`;
  }).join('');
  explorerList.innerHTML = `
    <table>
      <thead><tr><th>Nombre</th><th>Tipo</th><th>Tamaño</th><th>Modificado</th><th>Acción</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
  `;
  // Selección y doble clic
  explorerList.querySelectorAll('tr[data-path]').forEach(row => {
    row.addEventListener('click', (e) => {
      if (selectedRow) selectedRow.classList.remove('selected');
      row.classList.add('selected');
      selectedRow = row;
    });
    row.addEventListener('dblclick', (e) => {
      if (row.dataset.dir === '1') {
        listPath(row.dataset.path);
      }
    });
  });
  // Acción borrar
  explorerList.querySelectorAll('.explorer-action[data-action="delete"]').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const tr = btn.closest('tr');
      if (!tr) return;
      if (!confirm('¿Borrar ' + tr.querySelector('.explorer-fname').textContent + '?')) return;
      await api('/api/fs/delete', { method:'POST', body: JSON.stringify({ path: tr.dataset.path, recursive: tr.dataset.dir === '1' }) });
      await listPath(currentPath);
    });
  });
}

document.querySelector('#btnHealth').addEventListener('click', async () => {
  healthOut.textContent = 'Consultando...';
  try {
    const data = await api('/api/health');
    healthOut.textContent = JSON.stringify(data, null, 2);
  } catch (e) {
    healthOut.textContent = String(e);
  }
});


$('#btnList').addEventListener('click', () => listPath(currentPath));
$('#btnUp').addEventListener('click', () => {
  const up = currentPath.replace(/\/+$/,'').split('/').slice(0,-1).join('/');
  listPath(up);
});


$('#btnMkdir').addEventListener('click', async () => {
  try {
    if (!mkdirPath.value) return;
    await api('/api/fs/mkdir', { method:'POST', body: JSON.stringify({ path: (currentPath ? currentPath + '/' : '') + mkdirPath.value }) });
    mkdirPath.value = '';
    await listPath(currentPath);
  } catch (e) { alert(e); }
});

$('#btnCreate').addEventListener('click', async () => {
  try {
    if (!createPath.value) return;
    await api('/api/fs/create', { method:'POST', body: JSON.stringify({ path: (currentPath ? currentPath + '/' : '') + createPath.value, content: '' }) });
    createPath.value = '';
    await listPath(currentPath);
  } catch (e) { alert(e); }
});

document.querySelector('#btnMove').addEventListener('click', async () => {
  try {
    await api('/api/fs/move', { method:'POST', body: JSON.stringify({ src: moveSrc.value, dst: moveDst.value }) });
    await listPath(pathInput.value);
  } catch (e) { alert(e); }
});

document.querySelector('#btnDelete').addEventListener('click', async () => {
  try {
    await api('/api/fs/delete', { method:'POST', body: JSON.stringify({ path: delPath.value, recursive: delRecursive.checked }) });
    await listPath(pathInput.value);
  } catch (e) { alert(e); }
});

document.querySelector('#btnStartJob').addEventListener('click', async () => {
  jobOut.textContent = 'Iniciando job...';
  const cmd = jobCmd.value.trim();
  try {
    const data = await api('/api/jobs/start', { method:'POST', body: JSON.stringify(cmd ? { cmd } : {}) });
    jobId.value = data.id;
    jobOut.textContent = JSON.stringify(data, null, 2);
  } catch (e) {
    jobOut.textContent = String(e);
  }
});

document.querySelector('#btnStatus').addEventListener('click', async () => {
  if (!jobId.value) return;
  try {
    const data = await api(`/api/jobs/status/${jobId.value}`);
    jobOut.textContent = JSON.stringify(data, null, 2);
  } catch (e) { jobOut.textContent = String(e); }
});

document.querySelector('#btnStop').addEventListener('click', async () => {
  if (!jobId.value) return;
  try {
    const data = await api(`/api/jobs/stop/${jobId.value}`, { method:'POST' });
    jobOut.textContent = JSON.stringify(data, null, 2);
  } catch (e) { jobOut.textContent = String(e); }
});

document.querySelector('#btnLog').addEventListener('click', async () => {
  if (!jobId.value) return;
  try {
    const data = await api(`/api/jobs/log/${jobId.value}?tail=200`);
    jobOut.textContent = data.log || '';
  } catch (e) { jobOut.textContent = String(e); }
});


// Inicial: listar HOME
listPath('');
