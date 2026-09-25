#!/usr/bin/env node
// Exports the game's design data from the 3D browser build into Luau modules
// for the Roblox project, so there is one source of truth for every technique,
// character, enemy and world.
//
//   node tools/export-roblox.js        (or: npm run export:roblox)
//
// It reads web3d/rift3d.html, lifts each data table out of the game script by
// its declaration, evaluates them in an isolated context (with a stand-in for
// THREE.Vector3, the only engine type the tables use), runs the same boss
// generator the browser runs, and writes roblox/src/shared/Data/*.luau.
// Numbers stay in the web build's units; the Roblox side scales distances with
// Config.STUDS_PER_UNIT so the data never has to be edited twice.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const HTML = join(ROOT, 'web3d', 'rift3d.html');
// ROBLOX_EXPORT_OUT lets the freshness test export somewhere else and compare.
const OUT = process.env.ROBLOX_EXPORT_OUT || join(ROOT, 'roblox', 'src', 'shared', 'Data');

const html = readFileSync(HTML, 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
const game = scripts.find((s) => s.includes('const SKILLS = {'));
if (!game) throw new Error('Could not find the game script in rift3d.html');

// ---- Lifting a declaration out of the source -------------------------------
// Walks forward from the start of the value, tracking brackets and skipping
// strings, template literals and comments, until the statement ends.
function endOfExpression(src, i) {
  let depth = 0;
  for (; i < src.length; i++) {
    const c = src[i], n = src[i + 1];
    if (c === '/' && n === '/') { i = src.indexOf('\n', i); if (i < 0) return src.length; continue; }
    if (c === '/' && n === '*') { i = src.indexOf('*/', i + 2) + 1; continue; }
    if (c === "'" || c === '"' || c === '`') {
      for (i++; i < src.length && src[i] !== c; i++) if (src[i] === '\\') i++;
      continue;
    }
    if (c === '{' || c === '[' || c === '(') depth++;
    else if (c === '}' || c === ']' || c === ')') depth--;
    else if (c === ';' && depth === 0) return i;
  }
  throw new Error('Unterminated expression');
}
function declaration(name) {
  const m = new RegExp(`(^|\\n)(const|let) ${name} = `).exec(game);
  if (!m) throw new Error(`${name} is not declared in rift3d.html`);
  const start = m.index + m[0].length;
  return `const ${name} = ${game.slice(start, endOfExpression(game, start))};`;
}
function block(opening) {
  const start = game.indexOf(opening);
  if (start < 0) throw new Error(`Could not find: ${opening}`);
  return game.slice(start, endOfExpression(game, start) + 1);
}

const TABLES = ['BEATS', 'NATURE', 'MAX_SLOTS', 'OUTPUT_TIERS', 'ARSENALS', 'SKILLS', 'STYLES', 'GRADES', 'ENEMIES',
  'MAPS', 'MAP_IDS', 'PORTAL_COLOR', 'CHARACTERS', 'ENEMY_LOOKS', 'E_ACTION', 'WORLD_OF', 'WORLD_LABEL', 'ARMY_TIERS',
  'SYM_LINES', 'SYM_IDLE', 'BOND_MAX', 'WEB_SLINGERS'];

let source = TABLES.map(declaration).join('\n');
// A map names the function that builds its geometry; Roblox gets the name.
source = source.replace(/\bbuild: (build\w+)/g, "build: '$1'");
// The three curse characters borrow their looks from the *C entries, all on
// one line of three statements; take the whole line, not the first statement.
{
  const at = game.indexOf('CHARACTERS.jogo = CHARACTERS.jogoC;');
  if (at < 0) throw new Error('The character alias line is missing');
  source += '\n' + game.slice(at, game.indexOf('\n', at));
}
source += '\nconst BOSS_IDS = [], ALPHA_IDS = [];\n' + block('(function buildBosses() {');
source += `\n({ ${[...TABLES, 'BOSS_IDS', 'ALPHA_IDS'].join(', ')} });`;

class Vector3 { constructor(x = 0, y = 0, z = 0) { Object.assign(this, { x, y, z }); } }
const data = vm.runInNewContext(source, { THREE: { Vector3 } }, { filename: 'rift3d-data.js' });

// ---- Writing Luau ------------------------------------------------------------
const COLOR_KEY = /(color|col|sig|skin|hair|top|bottom|sleeves|eye|brow|belt|buckle|sash|cape|collar|hood|uniform|cuff|tie|necktie|vest|headband|sandals|shoulders|mask|masklower|tendrils|claws|tentacles|streaks|spider|metalarm|floor|edge|sky|suncolor|fogcolor|hemisky|hemiground|lens|goggles|specs|tiespots|blindfold)$/i;
const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
const RESERVED = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local',
  'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while', 'continue', 'type', 'export']);

function luauString(s) {
  return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') + '"';
}
function luauKey(k) {
  return IDENT.test(k) && !RESERVED.has(k) ? k : `[${luauString(k)}]`;
}
function luauNumber(n, key) {
  if (n === Infinity) return 'math.huge';
  if (n === -Infinity) return '-math.huge';
  if (Number.isNaN(n)) throw new Error(`NaN at ${key}`);
  if (key && COLOR_KEY.test(key) && Number.isInteger(n) && n >= 0 && n <= 0xffffff) return '0x' + n.toString(16).padStart(6, '0');
  return String(n);
}
function luau(v, indent = '', key = '') {
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'number') return luauNumber(v, key);
  if (typeof v === 'boolean') return String(v);
  if (typeof v === 'string') return luauString(v);
  if (typeof v === 'function') throw new Error(`A function reached the export at ${key}`);
  const inner = indent + '\t';
  if (Array.isArray(v)) {
    if (!v.length) return '{}';
    const flat = v.every((x) => typeof x !== 'object' || x === null);
    if (flat) return '{ ' + v.map((x) => luau(x, inner, key)).join(', ') + ' }';
    return '{\n' + v.map((x) => inner + luau(x, inner, key) + ',').join('\n') + '\n' + indent + '}';
  }
  const entries = Object.entries(v).filter(([, x]) => x !== undefined && typeof x !== 'function');
  if (!entries.length) return '{}';
  return '{\n' + entries.map(([k, x]) => `${inner}${luauKey(k)} = ${luau(x, inner, k)},`).join('\n') + '\n' + indent + '}';
}

const HEADER = (what) => `--!strict
-- GENERATED by tools/export-roblox.js from web3d/rift3d.html. Do not edit by hand:
-- change the web build and re-run \`npm run export:roblox\`.
--
-- ${what}
-- Distances, ranges and speeds are in web-build units; scale them with
-- Config.STUDS_PER_UNIT at the point of use. Colours are 0xRRGGBB integers;
-- turn them into Color3 with Palette.color().

`;

const MODULES = {
  Skills: ['Every technique: nature, cost, cooldown, type and its numbers.', data.SKILLS],
  Styles: ['Every playable character: name, blurb, passives, pool, equipped slots, ultimate.', data.STYLES],
  Enemies: ['Every enemy, including the generated character bosses (boss_<id>) and alphas (<id>_alpha).', data.ENEMIES],
  Characters: ['How each character looks: palette and costume flags, keyed by style id.', data.CHARACTERS],
  EnemyLooks: ['Costumes for the human-shaped enemies and every character boss.', data.ENEMY_LOOKS],
  Maps: ['The nine worlds: name, lighting, spawn, waves (boss ladder included) and filler.', data.MAPS],
  Arsenals: ['Switchable weapon and suit sets (Toji, Maki, Iron Man, ...).', data.ARSENALS],
  Rules: ['Small shared tables: the nature wheel, grades, tiers, signatures and worlds.', {
    MAX_SLOTS: data.MAX_SLOTS, BEATS: data.BEATS, NATURE: data.NATURE, GRADES: data.GRADES,
    OUTPUT_TIERS: data.OUTPUT_TIERS, ARMY_TIERS: data.ARMY_TIERS, BOND_MAX: data.BOND_MAX,
    E_ACTION: data.E_ACTION, WORLD_OF: data.WORLD_OF, WORLD_LABEL: data.WORLD_LABEL,
    MAP_IDS: data.MAP_IDS, PORTAL_COLOR: data.PORTAL_COLOR, BOSS_IDS: data.BOSS_IDS, ALPHA_IDS: data.ALPHA_IDS,
    SYM_LINES: data.SYM_LINES, SYM_IDLE: data.SYM_IDLE, WEB_SLINGERS: data.WEB_SLINGERS,
  }],
};

mkdirSync(OUT, { recursive: true });
for (const [name, [what, value]] of Object.entries(MODULES)) {
  writeFileSync(join(OUT, `${name}.luau`), HEADER(what) + 'return ' + luau(value) + '\n');
}
const count = (o) => Object.keys(o).length;
console.log(`Exported to ${OUT.startsWith(ROOT) ? OUT.slice(ROOT.length + 1) : OUT}: ${count(data.STYLES)} characters, ${count(data.SKILLS)} techniques, ` +
  `${count(data.ENEMIES)} enemies (${data.BOSS_IDS.length} character bosses, ${data.ALPHA_IDS.length} alphas), ${data.MAP_IDS.length} worlds.`);
