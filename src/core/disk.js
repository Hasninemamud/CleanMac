'use strict';

const path = require('path');
const { execFile } = require('child_process');
const { promisify } = require('util');
const { classify, isBlocked } = require('./safety');
const { homeDir, pathExists, shallowFolderSize, fsp } = require('./fsUtil');

const execFileAsync = promisify(execFile);

async function volumeUsage(mount = '/') {
  try {
    const { stdout } = await execFileAsync('df', ['-k', mount]);
    const lines = stdout.trim().split('\n');
    if (lines.length < 2) return { total: 0, free: 0, used: 0 };
    const parts = lines[1].split(/\s+/);
    // Filesystem 1K-blocks Used Available Capacity iused ifree %iused Mounted
    const totalK = Number(parts[1]) || 0;
    const usedK = Number(parts[2]) || 0;
    const availK = Number(parts[3]) || 0;
    return {
      total: totalK * 1024,
      free: availK * 1024,
      used: usedK * 1024,
    };
  } catch {
    return { total: 0, free: 0, used: 0 };
  }
}

function classifyHomeItem(name) {
  const n = name.toLowerCase();
  if (n === 'documents' || n === 'desktop' || n === 'downloads') return 'documents';
  if (n === 'library') return 'caches';
  if (n === 'applications' || n.endsWith('.app')) return 'apps';
  return 'other';
}

async function scanOverview(onProgress) {
  const home = homeDir();
  const volume = await volumeUsage(home);
  const categoryBytes = { apps: 0, documents: 0, caches: 0, other: 0 };
  const topFolders = [];
  let visited = 0;

  let children = [];
  try {
    children = await fsp.readdir(home, { withFileTypes: true });
  } catch {
    children = [];
  }

  for (const ent of children) {
    if (ent.name.startsWith('.')) continue;
    const full = path.join(home, ent.name);
    if (isBlocked(full) || ent.isSymbolicLink()) continue;
    visited += 1;
    onProgress?.({ pathsVisited: visited, currentPath: full });

    let size = 0;
    try {
      if (ent.isDirectory()) size = await shallowFolderSize(full);
      else if (ent.isFile()) size = (await fsp.lstat(full)).size;
    } catch {
      continue;
    }

    const category = classifyHomeItem(ent.name);
    categoryBytes[category] = (categoryBytes[category] || 0) + size;
    topFolders.push({
      path: full,
      name: ent.name,
      byteSize: size,
      isDirectory: ent.isDirectory(),
    });
  }

  const apps = '/Applications';
  if (await pathExists(apps)) {
    const appsSize = await shallowFolderSize(apps);
    categoryBytes.apps += appsSize;
    topFolders.push({ path: apps, name: 'Applications', byteSize: appsSize, isDirectory: true });
  }

  topFolders.sort((a, b) => b.byteSize - a.byteSize);

  return {
    totalBytes: volume.total,
    freeBytes: volume.free,
    usedBytes: volume.used,
    categoryBytes,
    topFolders: topFolders.slice(0, 30),
  };
}

async function collectLargeFiles(root, { minBytes = 50 * 1024 * 1024, maxFiles = 5000 } = {}, onProgress) {
  const items = [];
  let visited = 0;
  const stack = [root];

  while (stack.length && items.length < maxFiles) {
    const current = stack.pop();
    if (isBlocked(current)) continue;
    let entries;
    try {
      entries = await fsp.readdir(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const ent of entries) {
      const full = path.join(current, ent.name);
      if (isBlocked(full) || ent.isSymbolicLink()) continue;
      visited += 1;
      if (visited % 200 === 0) onProgress?.({ pathsVisited: visited, currentPath: full });

      try {
        if (ent.isDirectory()) {
          // Skip heavy package bundles internals
          if (ent.name.endsWith('.app') || ent.name.endsWith('.framework')) continue;
          stack.push(full);
        } else if (ent.isFile()) {
          const st = await fsp.lstat(full);
          if (st.size < minBytes) continue;
          const safety = classify(full, 'review');
          if (safety === 'blocked') continue;
          items.push({
            path: full,
            name: ent.name,
            byteSize: st.size,
            safety,
            category: 'other',
            explanation: 'Large file',
            modifiedAt: st.mtimeMs,
            isDirectory: false,
          });
          if (items.length >= maxFiles) break;
        }
      } catch {
        /* skip */
      }
    }
  }

  items.sort((a, b) => b.byteSize - a.byteSize);
  return items;
}

module.exports = { volumeUsage, scanOverview, collectLargeFiles };
