const ITEMS = [
  { id: 'caches', label: 'Application caches', found: '1.2 GB' },
  { id: 'logs', label: 'Logs', found: '340 MB' },
  { id: 'browser', label: 'Browser caches', found: '890 MB' },
  { id: 'temp', label: 'Temporary files', found: '210 MB' },
  { id: 'dev', label: 'Developer caches', found: '2.4 GB' },
];

const STEP_MS = 900;
const HOLD_MS = 2200;

function setMarkStates(activeIndex) {
  const list = document.getElementById('scan-list');
  [...list.children].forEach((li, i) => {
    li.classList.remove('pending', 'active', 'done');
    if (i < activeIndex) li.classList.add('done');
    else if (i === activeIndex) li.classList.add('active');
    else li.classList.add('pending');
  });
}

function runCycle() {
  const status = document.getElementById('scan-status');
  const spinner = document.getElementById('scan-spinner');
  const found = document.getElementById('scan-found');
  let i = 0;
  let totalBytes = 0;

  spinner.classList.remove('done');
  status.textContent = 'Scanning…';
  found.textContent = 'Finding reclaimable space…';
  setMarkStates(0);

  const tick = () => {
    if (i >= ITEMS.length) {
      setMarkStates(ITEMS.length);
      spinner.classList.add('done');
      status.textContent = 'Scan complete';
      found.textContent = `About ${formatTotal(totalBytes)} ready to review`;
      setTimeout(runCycle, HOLD_MS);
      return;
    }

    setMarkStates(i);
    status.textContent = 'Scanning…';
    found.textContent = `Checking ${ITEMS[i].label}…`;

    setTimeout(() => {
      totalBytes += parseFound(ITEMS[i].found);
      found.textContent = `${ITEMS[i].label}: ${ITEMS[i].found}`;
      i += 1;
      setTimeout(tick, 280);
    }, STEP_MS);
  };

  tick();
}

function parseFound(s) {
  const m = String(s).match(/([\d.]+)\s*(GB|MB)/i);
  if (!m) return 0;
  const n = parseFloat(m[1]);
  return m[2].toUpperCase() === 'GB' ? n * 1024 : n;
}

function formatTotal(mb) {
  if (mb >= 1024) return `${(mb / 1024).toFixed(1)} GB`;
  return `${Math.round(mb)} MB`;
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('#scan-list li').forEach((li) => li.classList.add('pending'));
  runCycle();
});
