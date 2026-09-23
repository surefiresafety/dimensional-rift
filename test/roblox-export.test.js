// The Roblox project's data is generated from the web build. If someone
// changes a technique in web3d/rift3d.html and forgets to re-export, the two
// games quietly disagree; this catches it.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname;
const COMMITTED = join(ROOT, 'roblox', 'src', 'shared', 'Data');

test('roblox: the exported data matches web3d/rift3d.html (run `npm run export:roblox`)', () => {
  const out = mkdtempSync(join(tmpdir(), 'rift-export-'));
  try {
    execFileSync(process.execPath, [join(ROOT, 'tools', 'export-roblox.js')], { env: { ...process.env, ROBLOX_EXPORT_OUT: out } });
    const fresh = readdirSync(out).sort();
    assert.deepEqual(fresh, readdirSync(COMMITTED).sort(), 'the set of data modules changed');
    for (const f of fresh) {
      assert.equal(readFileSync(join(out, f), 'utf8'), readFileSync(join(COMMITTED, f), 'utf8'), `${f} is stale`);
    }
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
});
