'use strict';

const path = require('path');
const { junkRules } = require('./junkRules');
const { classify, isBlocked } = require('./safety');
const { homeDir, pathExists, directorySize, fsp } = require('./fsUtil');

async function enumerateTopLevel(target, rule) {
  let entries;
  try {
    entries = await fsp.readdir(target, { withFileTypes: true });
  } catch {
    const size = await directorySize(target);
    if (size <= 0) return [];
    const safety = classify(target, rule.safety);
    if (safety === 'blocked') return [];
    return [
      {
        path: target,
        name: path.basename(target),
        byteSize: size,
        safety,
        category: rule.category,
        explanation: rule.explanation,
        isDirectory: true,
      },
    ];
  }

  const results = [];
  for (const ent of entries) {
    const full = path.join(target, ent.name);
    if (isBlocked(full) || ent.isSymbolicLink()) continue;
    let size = 0;
    let modifiedAt = null;
    try {
      const st = await fsp.lstat(full);
      modifiedAt = st.mtimeMs;
      if (ent.isDirectory()) size = await directorySize(full);
      else if (ent.isFile()) size = st.size;
      else continue;
    } catch {
      continue;
    }
    if (size <= 0) continue;
    const safety = classify(full, rule.safety);
    if (safety === 'blocked') continue;
    results.push({
      path: full,
      name: ent.name,
      byteSize: size,
      safety,
      category: rule.category,
      explanation: rule.explanation,
      modifiedAt,
      isDirectory: ent.isDirectory(),
    });
  }
  return results;
}

async function scanJunk(onProgress) {
  const home = homeDir();
  const rules = junkRules();
  const items = [];
  let visited = 0;

  for (const rule of rules) {
    const target = path.isAbsolute(rule.relativePath)
      ? rule.relativePath
      : path.join(home, rule.relativePath);
    if (!(await pathExists(target))) continue;
    visited += 1;
    onProgress?.({ pathsVisited: visited, currentPath: target });

    const safety = classify(target, rule.safety);
    if (safety === 'blocked') continue;

    const children = await enumerateTopLevel(target, rule);
    items.push(...children);
  }

  items.sort((a, b) => b.byteSize - a.byteSize);
  return items;
}

module.exports = { scanJunk };
