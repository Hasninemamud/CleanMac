'use strict';

const path = require('path');
const { canTrash, isBlocked, standardize } = require('./safety');

function collapseNested(paths) {
  const sorted = [...paths].map(standardize).sort((a, b) => a.length - b.length);
  const kept = [];
  for (const p of sorted) {
    const covered = kept.some(
      (parent) => p === parent || p.startsWith(parent.endsWith('/') ? parent : parent + '/')
    );
    if (!covered) kept.push(p);
  }
  return kept;
}

function friendlyError(filePath, err) {
  const name = path.basename(filePath).toLowerCase();
  const locked =
    name === 'cache.db' ||
    name.startsWith('cache.db-') ||
    name.endsWith('.sqlite') ||
    name.endsWith('.sqlite-wal') ||
    name.endsWith('.sqlite-shm');
  if (locked) return 'File may be locked — quit the owning app and try again';
  return err?.message || String(err);
}

/**
 * @param {Array} items
 * @param {string[]} selectedPaths
 * @param {(p: string) => Promise<void>} trashFn
 */
async function trashSelected(items, selectedPaths, trashFn) {
  const selectedSet = new Set(selectedPaths.map(standardize));
  const selectedItems = items.filter((it) => selectedSet.has(standardize(it.path)) && canTrash(it));
  const urls = collapseNested(selectedItems.map((it) => it.path));

  const trashed = [];
  const failed = [];

  for (const p of urls) {
    if (isBlocked(p)) {
      failed.push({ path: p, error: 'System path — deletion blocked' });
      continue;
    }
    try {
      await trashFn(p);
      trashed.push(p);
    } catch (err) {
      failed.push({ path: p, error: friendlyError(p, err) });
    }
  }

  return { trashed, failed };
}

module.exports = { trashSelected, collapseNested, friendlyError };
