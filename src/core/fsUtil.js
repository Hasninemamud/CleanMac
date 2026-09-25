'use strict';

const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const { isBlocked } = require('./safety');

async function pathExists(p) {
  try {
    await fsp.access(p);
    return true;
  } catch {
    return false;
  }
}

async function fileSize(p) {
  try {
    const st = await fsp.lstat(p);
    if (!st.isFile() && !st.isSymbolicLink()) return 0;
    return st.size;
  } catch {
    return 0;
  }
}

/** Recursive dir size. Skips blocked paths and symlink dirs. */
async function directorySize(dir, { maxEntries = 200_000 } = {}) {
  if (isBlocked(dir)) return 0;
  let total = 0;
  let count = 0;
  const stack = [dir];

  while (stack.length) {
    const current = stack.pop();
    let entries;
    try {
      entries = await fsp.readdir(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const ent of entries) {
      count += 1;
      if (count > maxEntries) return total;
      const full = path.join(current, ent.name);
      if (isBlocked(full)) continue;
      try {
        if (ent.isSymbolicLink()) continue;
        if (ent.isDirectory()) {
          stack.push(full);
        } else if (ent.isFile()) {
          const st = await fsp.lstat(full);
          total += st.size;
        }
      } catch {
        /* permission / race */
      }
    }
  }
  return total;
}

/** Shallow: sum immediate children sizes (dirs fully sized). */
async function shallowFolderSize(dir) {
  if (isBlocked(dir)) return 0;
  let total = 0;
  let entries;
  try {
    entries = await fsp.readdir(dir, { withFileTypes: true });
  } catch {
    return 0;
  }
  for (const ent of entries) {
    const full = path.join(dir, ent.name);
    if (isBlocked(full) || ent.isSymbolicLink()) continue;
    try {
      if (ent.isDirectory()) total += await directorySize(full);
      else if (ent.isFile()) total += (await fsp.lstat(full)).size;
    } catch {
      /* skip */
    }
  }
  return total;
}

function homeDir() {
  return process.env.HOME || require('os').homedir();
}

module.exports = {
  pathExists,
  fileSize,
  directorySize,
  shallowFolderSize,
  homeDir,
  fs,
  fsp,
  path,
};
