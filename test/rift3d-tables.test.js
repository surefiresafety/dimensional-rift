// The 3D build keeps its whole design in a handful of very large object
// literals inside one HTML file. A duplicate key in one of those is legal
// JavaScript and completely silent: the later entry simply replaces the
// earlier one, and a character quietly loses a technique. That has happened,
// so it is checked.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const SRC = new URL('../web3d/rift3d.html', import.meta.url);
const html = readFileSync(SRC, 'utf8');

/** Top-level keys of `const <name> = { ... };`, read to its closing brace. */
function tableKeys(name) {
  const start = html.indexOf(`const ${name} = {`);
  assert.ok(start >= 0, `${name} not found in rift3d.html`);
  const end = html.indexOf('\n};', start);
  assert.ok(end > start, `${name} has no closing brace`);
  return [...html.slice(start, end).matchAll(/^ {2}([A-Za-z_$][\w$]*):\s*\{/gm)].map((m) => m[1]);
}

function duplicates(keys) {
  const seen = new Set(), dupes = new Set();
  for (const k of keys) (seen.has(k) ? dupes : seen).add(k);
  return [...dupes];
}

for (const table of ['SKILLS', 'STYLES', 'ENEMIES', 'CHARACTERS', 'MAPS', 'ARSENALS']) {
  test(`rift3d: ${table} has no duplicate keys`, () => {
    const keys = tableKeys(table);
    assert.ok(keys.length > 0, `${table} parsed as empty`);
    assert.deepEqual(duplicates(keys), [], `${table} defines a key twice; the second one wins and the first is lost`);
  });
}

test('rift3d: every technique a character equips exists', () => {
  const skills = new Set(tableKeys('SKILLS'));
  const stylesStart = html.indexOf('const STYLES = {');
  const styles = html.slice(stylesStart, html.indexOf('\n};', stylesStart));
  const missing = [];
  // pool: [...] / slots: [...] / ultimate: { skill: '...' }
  for (const m of styles.matchAll(/\b(pool|slots):\s*\[([^\]]*)\]/g)) {
    for (const q of m[2].matchAll(/'([\w$]+)'/g)) if (!skills.has(q[1])) missing.push(q[1]);
  }
  for (const m of styles.matchAll(/ultimate:\s*\{\s*skill:\s*'([\w$]+)'/g)) if (!skills.has(m[1])) missing.push(m[1]);
  assert.deepEqual([...new Set(missing)], []);
});
