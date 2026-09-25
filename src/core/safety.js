'use strict';

const BLOCKED_PREFIXES = [
  '/System',
  '/usr',
  '/bin',
  '/sbin',
  '/private/var/db',
  '/Library/Apple',
  '/Library/OSAnalytics',
  '/Library/Updates',
];

function standardize(path) {
  if (!path) return '';
  // Collapse // and trailing slashes except root
  let p = path.replace(/\/+/g, '/');
  if (p.length > 1 && p.endsWith('/')) p = p.slice(0, -1);
  return p;
}

function isBlocked(path) {
  const standardized = standardize(path);
  if (standardized === '/' || standardized === '/private') return true;
  for (const prefix of BLOCKED_PREFIXES) {
    if (standardized === prefix || standardized.startsWith(prefix + '/')) return true;
  }
  if (standardized.startsWith('/Applications/') && (standardized.endsWith('.app') || standardized.includes('.app/'))) {
    return true;
  }
  return false;
}

function classify(path, intended = 'safe') {
  if (isBlocked(path)) return 'blocked';
  return intended;
}

function canTrash(item) {
  return item.safety !== 'blocked' && !isBlocked(item.path);
}

module.exports = { isBlocked, classify, canTrash, standardize };
