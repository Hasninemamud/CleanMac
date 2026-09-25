const META = {
  home: { title: 'Overview', subtitle: 'Disk usage at a glance' },
  junk: { title: 'Junk', subtitle: 'Caches, logs, and leftovers' },
  large: { title: 'Large files', subtitle: 'Files over 50 MB in your home folder' },
  dupes: { title: 'Duplicates', subtitle: 'Identical copies — keep one, trash the rest' },
};

const CATEGORY_LABELS = {
  userCaches: 'Caches',
  logs: 'Logs',
  trash: 'Trash',
  xcode: 'Xcode',
  packageManagers: 'Packages',
  browsers: 'Browsers',
  other: 'Other',
};

const state = {
  tab: 'home',
  junk: [],
  large: [],
  dupes: [],
  selection: new Map(),
  selectionSource: null,
  busy: false,
};

function formatBytes(n) {
  const bytes = Number(n) || 0;
  if (bytes < 1024) return `${bytes} B`;
  const units = ['KB', 'MB', 'GB', 'TB'];
  let v = bytes / 1024;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i += 1;
  }
  return `${v.toFixed(v >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
}

function escapeAttr(s) {
  return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
}

function setStatus(msg, busy = false) {
  const el = document.getElementById('status');
  el.textContent = msg;
  el.classList.toggle('busy', busy);
}

function getTheme() {
  return document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('cleanmac-theme', theme);
  document.getElementById('theme-label').textContent = theme === 'dark' ? 'Light' : 'Dark';
  cleanmac.setTheme?.(theme);
}

function initTheme() {
  applyTheme(getTheme());
  document.getElementById('theme-toggle').addEventListener('click', () => {
    applyTheme(getTheme() === 'dark' ? 'light' : 'dark');
  });
}

function stagger(nodes) {
  [...nodes].forEach((el, i) => {
    el.style.animationDelay = `${Math.min(i, 16) * 0.03}s`;
  });
}

function switchTab(tab) {
  state.tab = tab;
  document.querySelectorAll('.nav').forEach((b) => {
    b.classList.toggle('active', b.dataset.tab === tab);
  });
  document.querySelectorAll('.panel').forEach((p) => {
    p.classList.toggle('active', p.id === `panel-${tab}`);
  });
  const m = META[tab] || { title: tab, subtitle: '' };
  const title = document.getElementById('title');
  title.textContent = m.title;
  title.style.animation = 'none';
  void title.offsetWidth;
  title.style.animation = '';
  document.getElementById('subtitle').textContent = m.subtitle;
  refreshDock();
}

document.querySelectorAll('.nav').forEach((btn) => {
  btn.addEventListener('click', () => switchTab(btn.dataset.tab));
});

document.querySelectorAll('.tool[data-go]').forEach((btn) => {
  btn.addEventListener('click', () => {
    const tab = btn.dataset.go;
    switchTab(tab);
    if (tab === 'junk') document.getElementById('btn-junk').click();
    if (tab === 'large') document.getElementById('btn-large').click();
    if (tab === 'dupes') document.getElementById('btn-dupes').click();
  });
});

cleanmac.onProgress((p) => {
  if (!p?.currentPath) return;
  const short = p.currentPath.length > 48 ? `…${p.currentPath.slice(-44)}` : p.currentPath;
  setStatus(short, true);
});

function clearSelection() {
  state.selection.clear();
  state.selectionSource = null;
  document.querySelectorAll('.item-list input[type=checkbox], #dupe-groups input[type=checkbox]').forEach((inp) => {
    inp.checked = false;
  });
  refreshDock();
}

function syncSelection(source, rootSel, byPath) {
  state.selection.clear();
  state.selectionSource = source;
  document.querySelectorAll(`${rootSel} input[type=checkbox]:checked`).forEach((inp) => {
    state.selection.set(inp.value, byPath.get(inp.value)?.byteSize || 0);
  });
  if (!state.selection.size) state.selectionSource = null;
  refreshDock();
}

function refreshDock() {
  const dock = document.getElementById('dock');
  const n = state.selection.size;
  if (!n || state.tab === 'home' || state.selectionSource !== state.tab) {
    dock.hidden = true;
    return;
  }
  dock.hidden = false;
  let bytes = 0;
  state.selection.forEach((b) => { bytes += b; });
  document.getElementById('dock-count').textContent =
    `${n} selected${bytes ? ` · ${formatBytes(bytes)}` : ''}`;
}

document.getElementById('dock-clear').addEventListener('click', clearSelection);

function confirmTrash(count) {
  return new Promise((resolve) => {
    const modal = document.getElementById('modal');
    document.getElementById('modal-body').textContent =
      `${count} item${count === 1 ? '' : 's'} will move to Trash.`;
    modal.hidden = false;
    const done = (ok) => {
      modal.hidden = true;
      document.getElementById('modal-confirm').onclick = null;
      resolve(ok);
    };
    document.getElementById('modal-confirm').onclick = () => done(true);
    modal.querySelectorAll('[data-close]').forEach((el) => {
      el.onclick = () => done(false);
    });
  });
}

async function doTrash(items) {
  const selected = [...state.selection.keys()];
  if (!selected.length) return;
  if (!(await confirmTrash(selected.length))) return;
  setStatus('Moving to Trash…');
  state.busy = true;
  try {
    const result = await cleanmac.trash({ items, selectedPaths: selected });
    const ok = result.trashed?.length || 0;
    const fail = result.failed?.length || 0;
    setStatus(`Trashed ${ok}${fail ? `, ${fail} failed` : ''}`);
    clearSelection();
    return result;
  } finally {
    state.busy = false;
  }
}

document.getElementById('dock-trash').addEventListener('click', async () => {
  if (state.selectionSource === 'junk') {
    await doTrash(state.junk);
    state.junk = await cleanmac.scanJunk();
    renderJunk();
  } else if (state.selectionSource === 'large') {
    const sel = new Set(state.selection.keys());
    await doTrash(state.large);
    state.large = state.large.filter((i) => !sel.has(i.path));
    renderLarge();
  } else if (state.selectionSource === 'dupes') {
    await doTrash(state.dupes.flatMap((g) => g.files));
    document.getElementById('btn-dupes').click();
  }
});

async function runOverview() {
  setStatus('Scanning…', true);
  try {
    const data = await cleanmac.overview();
    const pct = data.totalBytes ? Math.min(100, (data.usedBytes / data.totalBytes) * 100) : 0;
    const freeEl = document.getElementById('disk-free');
    freeEl.textContent = formatBytes(data.freeBytes);
    freeEl.classList.remove('pop');
    void freeEl.offsetWidth;
    freeEl.classList.add('pop');
    document.getElementById('disk-used').textContent = `Used ${formatBytes(data.usedBytes)}`;
    document.getElementById('disk-total').textContent = `Total ${formatBytes(data.totalBytes)}`;
    document.getElementById('disk-used-bar').style.width = '0%';
    requestAnimationFrame(() => {
      document.getElementById('disk-used-bar').style.width = `${pct}%`;
    });

    const list = document.getElementById('overview-rows');
    list.innerHTML = '';
    (data.topFolders || []).slice(0, 10).forEach((f) => {
      const li = document.createElement('li');
      li.innerHTML = `<span title="${escapeAttr(f.path)}">${escapeAttr(f.name)}</span><span class="size">${formatBytes(f.byteSize)}</span>`;
      list.appendChild(li);
    });
    stagger(list.children);
    setStatus('Ready');
  } catch (err) {
    setStatus(err.message || 'Scan failed');
  }
}

document.getElementById('btn-rescan').addEventListener('click', runOverview);

function renderJunk() {
  const empty = document.getElementById('junk-empty');
  const shell = document.getElementById('junk-shell');
  const rows = document.getElementById('junk-rows');
  rows.innerHTML = '';
  if (!state.junk.length) {
    empty.hidden = false;
    shell.hidden = true;
    return;
  }
  empty.hidden = true;
  shell.hidden = false;
  const byPath = new Map(state.junk.map((i) => [i.path, i]));

  state.junk.forEach((item) => {
    const li = document.createElement('li');
    li.innerHTML = `
      <input type="checkbox" value="${escapeAttr(item.path)}" data-safety="${item.safety}" />
      <div class="name" title="${escapeAttr(item.path)}">
        <div>${escapeAttr(item.name)}</div>
        <div class="meta">${CATEGORY_LABELS[item.category] || item.category}</div>
      </div>
      <span class="badge ${item.safety}">${item.safety}</span>
      <div class="end">
        <span class="size">${formatBytes(item.byteSize)}</span>
        <button class="link" type="button" data-reveal="${escapeAttr(item.path)}">Reveal</button>
      </div>`;
    rows.appendChild(li);
  });

  rows.querySelectorAll('input').forEach((inp) => {
    inp.addEventListener('change', () => syncSelection('junk', '#junk-rows', byPath));
  });
  rows.querySelectorAll('[data-reveal]').forEach((btn) => {
    btn.addEventListener('click', () => cleanmac.reveal(btn.dataset.reveal));
  });
  stagger(rows.children);
}

document.getElementById('btn-junk').addEventListener('click', async () => {
  if (state.busy) return;
  state.busy = true;
  setStatus('Scanning junk…', true);
  try {
    state.junk = await cleanmac.scanJunk();
    clearSelection();
    renderJunk();
    const total = state.junk.reduce((s, i) => s + i.byteSize, 0);
    setStatus(`${state.junk.length} items · ${formatBytes(total)}`);
  } finally {
    state.busy = false;
  }
});

document.getElementById('junk-select-safe').addEventListener('change', (e) => {
  document.querySelectorAll('#junk-rows input[data-safety=safe]').forEach((inp) => {
    inp.checked = e.target.checked;
  });
  syncSelection('junk', '#junk-rows', new Map(state.junk.map((i) => [i.path, i])));
});

function renderLarge() {
  const empty = document.getElementById('large-empty');
  const shell = document.getElementById('large-shell');
  const rows = document.getElementById('large-rows');
  rows.innerHTML = '';
  if (!state.large.length) {
    empty.hidden = false;
    shell.hidden = true;
    return;
  }
  empty.hidden = true;
  shell.hidden = false;
  const byPath = new Map(state.large.map((i) => [i.path, i]));

  state.large.forEach((item) => {
    const li = document.createElement('li');
    li.innerHTML = `
      <input type="checkbox" value="${escapeAttr(item.path)}" />
      <div class="name" title="${escapeAttr(item.path)}">
        <div>${escapeAttr(item.name)}</div>
        <div class="meta">${escapeAttr(item.path)}</div>
      </div>
      <span></span>
      <div class="end">
        <span class="size">${formatBytes(item.byteSize)}</span>
        <button class="link" type="button" data-reveal="${escapeAttr(item.path)}">Reveal</button>
      </div>`;
    rows.appendChild(li);
  });

  rows.querySelectorAll('input').forEach((inp) => {
    inp.addEventListener('change', () => syncSelection('large', '#large-rows', byPath));
  });
  rows.querySelectorAll('[data-reveal]').forEach((btn) => {
    btn.addEventListener('click', () => cleanmac.reveal(btn.dataset.reveal));
  });
  stagger(rows.children);
}

document.getElementById('btn-large').addEventListener('click', async () => {
  if (state.busy) return;
  state.busy = true;
  setStatus('Finding large files…', true);
  try {
    state.large = await cleanmac.scanLarge({ minBytes: 50 * 1024 * 1024 });
    clearSelection();
    renderLarge();
    setStatus(`${state.large.length} files`);
  } finally {
    state.busy = false;
  }
});

function renderDupes() {
  const empty = document.getElementById('dupes-empty');
  const root = document.getElementById('dupe-groups');
  root.innerHTML = '';
  if (!state.dupes.length) {
    empty.hidden = false;
    root.hidden = true;
    return;
  }
  empty.hidden = true;
  root.hidden = false;
  const byPath = new Map();
  state.dupes.forEach((g) => g.files.forEach((f) => byPath.set(f.path, f)));

  state.dupes.forEach((group) => {
    const box = document.createElement('div');
    box.className = 'dupe-group';
    box.innerHTML = `<h3>${group.files.length} copies · ${formatBytes(group.byteSize)} each · ~${formatBytes(group.reclaimableBytes)}</h3>`;
    group.files.forEach((f, fi) => {
      const label = document.createElement('label');
      label.innerHTML = `<input type="checkbox" value="${escapeAttr(f.path)}" ${fi > 0 ? 'checked' : ''} />
        <span class="path" title="${escapeAttr(f.path)}">${escapeAttr(f.path)}</span>`;
      box.appendChild(label);
    });
    root.appendChild(box);
  });

  syncSelection('dupes', '#dupe-groups', byPath);
  root.querySelectorAll('input').forEach((inp) => {
    inp.addEventListener('change', () => syncSelection('dupes', '#dupe-groups', byPath));
  });
  stagger(root.children);
}

document.getElementById('btn-dupes').addEventListener('click', async () => {
  if (state.busy) return;
  state.busy = true;
  setStatus('Collecting files…', true);
  try {
    const files = await cleanmac.scanLarge({ minBytes: 1 * 1024 * 1024 });
    setStatus(`Checking ${files.length} files…`, true);
    state.dupes = await cleanmac.findDuplicates(files);
    clearSelection();
    renderDupes();
    setStatus(`${state.dupes.length} groups`);
  } finally {
    state.busy = false;
  }
});

initTheme();
runOverview();
