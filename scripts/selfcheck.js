'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { isBlocked, classify, canTrash } = require('../src/core/safety');
const { collapseNested } = require('../src/core/cleaner');
const { partialHash, fullHash, findDuplicates } = require('../src/core/duplicates');
const { formatBytes } = require('../src/core/format');

function demo() {
  assert.strictEqual(isBlocked('/System/Library'), true);
  assert.strictEqual(isBlocked('/usr/bin'), true);
  assert.strictEqual(isBlocked('/'), true);
  assert.strictEqual(isBlocked(path.join(os.homedir(), 'Library/Caches/foo')), false);
  assert.strictEqual(classify('/System/foo', 'safe'), 'blocked');
  assert.strictEqual(classify(path.join(os.homedir(), 'tmp'), 'safe'), 'safe');

  assert.deepStrictEqual(
    collapseNested(['/a/b', '/a/b/c', '/a/d']),
    ['/a/b', '/a/d']
  );

  assert.ok(formatBytes(1536).includes('KB'));

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cleanmac-'));
  const a = path.join(dir, 'a.bin');
  const b = path.join(dir, 'b.bin');
  const payload = Buffer.alloc(2 * 1024 * 1024, 7);
  fs.writeFileSync(a, payload);
  fs.writeFileSync(b, payload);

  return Promise.all([partialHash(a), fullHash(a), fullHash(b)]).then(async ([pa, fa, fb]) => {
    assert.ok(pa && pa.length === 64);
    assert.strictEqual(fa, fb);

    const groups = await findDuplicates(
      [
        { path: a, byteSize: payload.length, safety: 'safe', name: 'a.bin' },
        { path: b, byteSize: payload.length, safety: 'safe', name: 'b.bin' },
      ],
      { minimumBytes: 1024 }
    );
    assert.strictEqual(groups.length, 1);
    assert.strictEqual(groups[0].files.length, 2);

    assert.strictEqual(
      canTrash({ path: '/System/x', safety: 'safe' }),
      false
    );

    fs.rmSync(dir, { recursive: true, force: true });
    console.log('selfcheck ok');
  });
}

demo().catch((err) => {
  console.error(err);
  process.exit(1);
});
