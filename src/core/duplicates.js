'use strict';

const crypto = require('crypto');
const fs = require('fs');
const { createReadStream } = require('fs');

const PARTIAL_LEN = 65_536;

function partialHash(filePath) {
  return new Promise((resolve) => {
    const hash = crypto.createHash('sha256');
    const stream = createReadStream(filePath, { start: 0, end: PARTIAL_LEN - 1 });
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('error', () => resolve(null));
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

function fullHash(filePath) {
  return new Promise((resolve) => {
    const hash = crypto.createHash('sha256');
    const stream = createReadStream(filePath);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('error', () => resolve(null));
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

/**
 * Progressive duplicate detect: size → partial SHA-256 → full SHA-256.
 * @param {Array<{path:string,byteSize:number,safety:string,name?:string}>} files
 */
async function findDuplicates(files, { minimumBytes = 1_048_576 } = {}, onProgress) {
  const candidates = files.filter((f) => f.byteSize >= minimumBytes && f.safety !== 'blocked');
  const bySize = new Map();
  for (const f of candidates) {
    const list = bySize.get(f.byteSize) || [];
    list.push(f);
    bySize.set(f.byteSize, list);
  }

  const sizeGroups = [...bySize.values()].filter((g) => g.length > 1);
  const partialBuckets = new Map();
  let visited = 0;

  for (const group of sizeGroups) {
    for (const file of group) {
      visited += 1;
      if (visited % 20 === 0) onProgress?.({ pathsVisited: visited, currentPath: file.path });
      const partial = await partialHash(file.path);
      if (!partial) continue;
      const key = `${file.byteSize}-${partial}`;
      const list = partialBuckets.get(key) || [];
      list.push(file);
      partialBuckets.set(key, list);
    }
  }

  const groups = [];
  for (const bucket of partialBuckets.values()) {
    if (bucket.length < 2) continue;
    const byFull = new Map();
    for (const file of bucket) {
      visited += 1;
      onProgress?.({ pathsVisited: visited, currentPath: file.path });
      const full = await fullHash(file.path);
      if (!full) continue;
      const list = byFull.get(full) || [];
      list.push(file);
      byFull.set(full, list);
    }
    for (const matches of byFull.values()) {
      if (matches.length < 2) continue;
      const byteSize = matches[0].byteSize;
      groups.push({
        byteSize,
        reclaimableBytes: byteSize * (matches.length - 1),
        files: matches,
      });
    }
  }

  groups.sort((a, b) => b.reclaimableBytes - a.reclaimableBytes);
  return groups;
}

module.exports = { findDuplicates, partialHash, fullHash };
