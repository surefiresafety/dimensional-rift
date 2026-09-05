// Bundles the ES-module game into a single HTML file (build/dimensional-rift.html)
// that runs from file:// or any host, plus an <html>-less fragment used for
// publishing as an Artifact. Zero dependencies: a tiny module registry.
import { readFile, writeFile, mkdir } from 'node:fs/promises';

const ROOT = new URL('..', import.meta.url).pathname;
const MODULES = [
  'src/combat/rng.js', 'src/combat/natures.js', 'src/combat/status.js', 'src/combat/skills.js',
  'src/combat/summons.js', 'src/combat/items.js', 'src/combat/entities.js', 'src/combat/loadout.js',
  'src/combat/battle.js', 'src/game/script.js', 'src/game/dialogue.js', 'src/game/overworld.js',
  'src/game/battle-ui.js', 'src/game/skills-menu.js', 'src/game/main.js',
];
const key = (p) => p.split('/').pop().replace(/\.js$/, '');

function transform(src) {
  const names = [];
  src = src.replace(/import\s*\{([^}]*)\}\s*from\s*'([^']+)';/g, (_, spec, from) => {
    const fields = spec.split(',').map((s) => s.trim()).filter(Boolean).map((s) => s.replace(/\s+as\s+/, ': '));
    return `const { ${fields.join(', ')} } = __mod('${key(from)}');`;
  });
  src = src.replace(/^export\s+(async\s+)?(function|const|let|class)\s+([A-Za-z_$][\w$]*)/gm, (_, a, kw, name) => {
    names.push(name);
    return `${a ?? ''}${kw} ${name}`;
  });
  if (/^export\s/m.test(src)) throw new Error('Unhandled export form:\n' + src.match(/^export\s.*$/m)[0]);
  return `${src}\nObject.assign(exports, { ${names.join(', ')} });`;
}

let js = `(() => {\nconst __defs = {}, __cache = {};\nconst __mod = (k) => __cache[k] ?? (__cache[k] = (() => { const e = {}; __defs[k](e); return e; })());\n`;
for (const m of MODULES) {
  js += `__defs['${key(m)}'] = (exports) => {\n${transform(await readFile(ROOT + m, 'utf8'))}\n};\n`;
}
js += `__mod('main');\n})();\n`;

const html = await readFile(ROOT + 'index.html', 'utf8');
const css = await readFile(ROOT + 'style.css', 'utf8');
const body = html.match(/<body>([\s\S]*)<\/body>/)[1].replace(/<script type="module"[^>]*><\/script>/, '');
const fragment = `<title>Dimensional Rift</title>\n<style>\n${css}</style>\n${body}\n<script>\n${js}</script>\n`;
const standalone = `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8" />\n<meta name="viewport" content="width=device-width, initial-scale=1" />\n<title>Dimensional Rift</title>\n<style>\n${css}</style>\n</head>\n<body>\n${body}\n<script>\n${js}</script>\n</body>\n</html>\n`;

await mkdir(ROOT + 'build', { recursive: true });
await writeFile(ROOT + 'build/dimensional-rift.html', standalone);
await writeFile(ROOT + 'build/artifact.html', fragment);
console.log('Bundled to build/dimensional-rift.html and build/artifact.html');
