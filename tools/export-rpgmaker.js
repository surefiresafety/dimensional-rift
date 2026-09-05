// Exports the combat data in RPG Maker MZ-friendly shapes so the same design
// can be pasted into an MZ project (data/Skills.json entries + the Elements
// list for System.json). Output: build/rpgmaker/*.json
import { mkdir, writeFile } from 'node:fs/promises';
import { SKILLS } from '../src/combat/skills.js';
import { SUMMONS } from '../src/combat/summons.js';
import { BEATS, NATURE_INFO, matchupChart } from '../src/combat/natures.js';
import { ROSTER } from '../src/combat/entities.js';

const ELEMENTS = ['', 'Physical', 'Fire', 'Wind', 'Lightning', 'Earth', 'Water', 'Cursed'];
const elementId = (nature) => ELEMENTS.indexOf(nature.charAt(0).toUpperCase() + nature.slice(1));

// MZ state ids we reserve for our statuses (1 = Knockout, 2 = Guard are built in).
const STATE_IDS = { rooted: 11, paralyzed: 12, webbed: 13, poisoned: 14, burned: 15, evasive: 16, decoy: 17 };
const PARAM_IDS = { atk: 2, def: 3, spd: 6 };

function mzEffects(effects = []) {
  return effects.map((e) => {
    if (e.type === 'status') return { code: 21, dataId: STATE_IDS[e.status], value1: e.chance, value2: 0 };
    if (e.type === 'stage') return { code: e.delta > 0 ? 31 : 32, dataId: PARAM_IDS[e.stat], value1: Math.abs(e.delta), value2: 0 };
    if (e.type === 'heal') return { code: 11, dataId: 0, value1: e.percent, value2: 0 };
    return null;
  }).filter(Boolean);
}

function mzSkill(id, s) {
  const attack = s.kind === 'attack';
  return {
    id, name: s.name, description: s.desc, iconIndex: 0,
    stypeId: 1, // "Magic" -> renamed to Spirit Energy in System.json
    mpCost: s.cost, tpCost: 0,
    scope: s.target === 'self' ? 11 : 1, occasion: 1, speed: 0, successRate: Math.round((s.accuracy ?? 1) * 100), repeats: 1, tpGain: 0, hitType: s.nature === 'physical' ? 1 : 2,
    animationId: 0, message1: ` uses ${s.name}!`, message2: '',
    damage: attack
      ? { type: 1, elementId: elementId(s.nature), formula: `${s.power} * a.atk / b.def`, variance: 15, critical: Boolean(s.tags?.includes('crit')) }
      : { type: 0, elementId: 0, formula: '0', variance: 0, critical: false },
    effects: mzEffects(s.effects),
    note: `<origin:${s.origin}>${s.tags?.length ? `<tags:${s.tags.join(',')}>` : ''}${s.bonus ? `<bonus:${s.bonus.ifTargetStatus}x${s.bonus.multiplier}>` : ''}`,
  };
}

const skills = [null];
let id = 1;
for (const s of Object.values(SKILLS)) skills.push(mzSkill(id++, s));
for (const s of Object.values(SUMMONS)) skills.push({ ...mzSkill(id++, { ...s, kind: 'attack', target: 'enemy' }), note: `<summon:${s.id}><unlockedBy:${s.unlockedBy}>` });

// Element rates for the wheel: 200% vs weakness, 50% vs resistance. MZ applies
// element rate traits (code 11) to the *defender*, so emit per-nature trait sets.
const elementTraits = Object.fromEntries(Object.keys(BEATS).map((def) => {
  const weakTo = Object.keys(BEATS).find((a) => BEATS[a] === def);
  return [def, [
    { code: 11, dataId: elementId(weakTo), value: 2.0 },
    { code: 11, dataId: elementId(BEATS[def]), value: 0.5 },
  ]];
}));

const enemies = Object.values(ROSTER).filter((r) => r.side === 'enemy').map((r, i) => ({
  id: i + 1, name: r.name, params: [r.maxHp, r.maxSe ?? 0, r.atk, r.def, r.atk, r.def, r.spd, 10],
  traits: r.nature && elementTraits[r.nature] ? elementTraits[r.nature] : [],
  note: `${r.absorbable ? `<absorb:${r.absorbable}>` : ''}${r.bossId ? `<boss:${r.bossId}>` : ''}${r.traits?.adapts ? '<adapts>' : ''}`,
}));

await mkdir('build/rpgmaker', { recursive: true });
await writeFile('build/rpgmaker/Skills.json', JSON.stringify(skills, null, 2));
await writeFile('build/rpgmaker/Enemies.json', JSON.stringify(enemies, null, 2));
await writeFile('build/rpgmaker/System.elements.json', JSON.stringify({ elements: ELEMENTS, skillTypes: ['', 'Spirit Energy'], stateIds: STATE_IDS, elementTraits, chart: matchupChart(), natureInfo: NATURE_INFO }, null, 2));
console.log(`Exported ${skills.length - 1} skills and ${enemies.length} enemies to build/rpgmaker/`);
