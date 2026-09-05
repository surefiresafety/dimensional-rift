import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBattle, computeDamage, effectiveStat } from '../src/combat/battle.js';
import { spawn } from '../src/combat/entities.js';
import { createRng } from '../src/combat/rng.js';
import { getSkill, MAX_EQUIPPED_SKILLS } from '../src/combat/skills.js';
import { learnSkill, equipSkill } from '../src/combat/loadout.js';

const fixedRng = () => ({ next: () => 0.5, chance: () => true, range: (a, b) => b, pick: (arr) => arr[0] });

function playerWith(skills, overrides = {}) {
  return spawn('player', { skills, learnedSkills: skills, ...overrides });
}

test('super-effective nature doubles damage, resisted halves it', () => {
  const p = playerWith(['fireball', 'water_dragon']);
  const windFoe = spawn('rogue_ninja', { nature: 'wind' });
  const waterFoe = spawn('rogue_ninja', { nature: 'water' });
  const neutral = spawn('rogue_ninja', { nature: 'earth' });
  const fb = getSkill('fireball');
  const se = computeDamage({ attacker: p, defender: windFoe, move: fb, rng: null });
  const nve = computeDamage({ attacker: p, defender: waterFoe, move: fb, rng: null });
  const n = computeDamage({ attacker: p, defender: neutral, move: fb, rng: null });
  assert.equal(se.multiplier, 2);
  assert.equal(nve.multiplier, 0.5);
  assert.equal(n.multiplier, 1);
  assert.ok(se.damage > n.damage && n.damage > nve.damage);
});

test('Naruto and JJK moves drain the same Spirit Energy pool', () => {
  const p = playerWith(['shadow_clone', 'black_flash'], { maxSe: 30, se: 30 });
  const foe = spawn('rogue_ninja');
  const b = createBattle({ player: p, enemies: [foe], rng: fixedRng() });
  b.act({ type: 'skill', skill: 'shadow_clone' });
  assert.equal(p.se, 30 - getSkill('shadow_clone').cost);
  b.act({ type: 'skill', skill: 'black_flash' });
  assert.equal(p.se, 30 - getSkill('shadow_clone').cost - getSkill('black_flash').cost);
  assert.throws(() => b.act({ type: 'skill', skill: 'black_flash' }), /Not enough Spirit Energy/);
});

test('Web-Stun roots the enemy for a turn and lowers Defense', () => {
  const p = playerWith(['web_stun']);
  const foe = spawn('rogue_ninja', { spd: 10 });
  const b = createBattle({ player: p, enemies: [foe], rng: fixedRng() });
  const hpBefore = p.hp;
  const events = b.act({ type: 'skill', skill: 'web_stun' });
  assert.equal(foe.stages.def, -1);
  assert.ok(events.some((e) => e.type === 'skip' && e.reason === 'rooted'), 'enemy lost its turn');
  assert.equal(p.hp, hpBefore, 'rooted enemy could not attack');
  // Webbed speed is heavily reduced.
  assert.ok(effectiveStat(foe, 'spd') < foe.spd);
  // Root wears off after one turn; webbed lasts longer.
  b.act({ type: 'guard' });
  assert.equal(foe.statuses.rooted, undefined);
  assert.ok(foe.statuses.webbed);
});

test('Web-Shooters can Root (50%) and always sharply lower Speed', () => {
  const p = playerWith(['web_shooters']);
  const foe = spawn('rogue_ninja');
  const rootRng = fixedRng(); // chance() always true -> root procs
  createBattle({ player: p, enemies: [foe], rng: rootRng }).act({ type: 'skill', skill: 'web_shooters' });
  assert.equal(foe.stages.spd, -2);
  assert.ok(foe.statuses.rooted !== undefined || foe.statuses.webbed !== undefined);

  const p2 = playerWith(['web_shooters']);
  const foe2 = spawn('rogue_ninja', { spd: 1 });
  const noRootRng = { ...fixedRng(), chance: (x) => x >= 0.95 }; // accuracy passes, 50% root fails
  createBattle({ player: p2, enemies: [foe2], rng: noRootRng }).act({ type: 'skill', skill: 'web_shooters' });
  assert.equal(foe2.stages.spd, -2);
  assert.equal(foe2.statuses.rooted, undefined);
});

test('Spider-Sense / Sharingan dodge the next attack, even a Domain Expansion', () => {
  for (const buff of ['spider_sense', 'sharingan']) {
    const p = playerWith([buff]);
    const dagon = spawn('jogo', { name: 'Dagon', nature: 'water', skills: ['dagon_domain'], ai: ['dagon_domain'], spd: 1, bossId: null });
    const b = createBattle({ player: p, enemies: [dagon], rng: fixedRng() });
    const events = b.act({ type: 'skill', skill: buff });
    assert.ok(events.some((e) => e.type === 'move' && e.move === 'dagon_domain'));
    assert.ok(events.some((e) => e.type === 'dodge'), `${buff} dodged`);
    assert.equal(p.hp, p.maxHp);
    // Buff is consumed: the next domain lands.
    const e2 = b.act({ type: 'guard' });
    assert.ok(!e2.some((e) => e.type === 'dodge'));
    assert.ok(p.hp < p.maxHp);
  }
});

test('Web Swing Kick does double damage to a webbed target', () => {
  const p = playerWith(['web_swing_kick']);
  const foe = spawn('rogue_ninja');
  const move = getSkill('web_swing_kick');
  const plain = computeDamage({ attacker: p, defender: foe, move, rng: null });
  foe.statuses.webbed = 2;
  const webbed = computeDamage({ attacker: p, defender: foe, move, rng: null });
  assert.equal(webbed.multiplier, plain.multiplier * 2);
});

test('Shadow Clone decoy absorbs one hit', () => {
  const p = playerWith(['shadow_clone']);
  const foe = spawn('rogue_ninja', { spd: 1, ai: ['shuriken'] });
  const b = createBattle({ player: p, enemies: [foe], rng: fixedRng() });
  const ev = b.act({ type: 'skill', skill: 'shadow_clone' });
  assert.ok(ev.some((e) => e.type === 'decoy'));
  assert.equal(p.hp, p.maxHp);
});

test('poison ticks each round and can defeat', () => {
  const p = playerWith(['poison_spit'], { atk: 1 });
  const foe = spawn('cursed_spirit_grade4', { maxHp: 8, hp: 4, ai: ['strike'], atk: 1 });
  const b = createBattle({ player: p, enemies: [foe], rng: fixedRng() });
  b.act({ type: 'skill', skill: 'poison_spit' });
  assert.ok(foe.statuses.poisoned);
  let rounds = 0;
  while (!b.result && rounds < 10) { b.act({ type: 'guard' }); rounds++; }
  assert.equal(b.result.outcome, 'win');
});

test('summoning contracts: beating a boss unlocks the scroll, summon costs Spirit Energy', () => {
  const p = playerWith(['rasenshuriken'], { maxSe: 100, se: 100, atk: 200, level: 50 });
  const jiraiya = spawn('jiraiya', { hp: 1 });
  const b = createBattle({ player: p, enemies: [jiraiya], rng: fixedRng() });
  assert.equal(b.options().run, false, 'cannot run from a boss');
  b.act({ type: 'skill', skill: 'rasenshuriken' });
  assert.equal(b.result.outcome, 'win');
  assert.deepEqual(b.result.scrolls, ['gamabunta']);
  assert.ok(p.scrolls.includes('gamabunta'));
  assert.ok(p.learnedSkills.includes('rasengan'), 'copied Rasengan from Jiraiya');

  // Now use Gamabunta against Jogo (fire): water beats fire.
  const jogo = spawn('jogo', { spd: 1 });
  const b2 = createBattle({ player: p, enemies: [jogo], rng: fixedRng() });
  const seBefore = p.se;
  const ev = b2.act({ type: 'summon', summon: 'gamabunta' });
  assert.ok(ev.some((e) => e.type === 'summon'));
  const dmg = ev.find((e) => e.type === 'damage' && e.target === 'jogo');
  assert.equal(dmg.multiplier, 2);
  assert.equal(p.se, seBefore - 25);
});

test('Ninja Hounds summon paralyzes', () => {
  const p = playerWith([], { scrolls: ['ninja_hounds'], maxSe: 50, se: 50 });
  const foe = spawn('rogue_ninja', { spd: 1 });
  const b = createBattle({ player: p, enemies: [foe], rng: fixedRng() });
  b.act({ type: 'summon', summon: 'ninja_hounds' });
  assert.ok(foe.statuses.paralyzed);
});

test('Mahoraga adapts: repeated natures lose effectiveness', () => {
  const p = playerWith(['fireball'], { maxSe: 999, se: 999, level: 40, atk: 90 });
  const m = spawn('mahoraga', { ai: ['strike'], atk: 1 });
  const b = createBattle({ player: p, enemies: [m], rng: fixedRng() });
  const d1 = b.act({ type: 'skill', skill: 'fireball' }).find((e) => e.type === 'damage' && e.target === 'mahoraga').amount;
  const d2 = b.act({ type: 'skill', skill: 'fireball' }).find((e) => e.type === 'damage' && e.target === 'mahoraga').amount;
  const d3 = b.act({ type: 'skill', skill: 'fireball' }).find((e) => e.type === 'damage' && e.target === 'mahoraga').amount;
  assert.ok(d2 < d1 && d3 < d2, `damage should fall: ${d1} ${d2} ${d3}`);
  assert.equal(m.adaptations.fire, 0.125);
  // A fresh nature is still full power.
  learnSkill(p, 'chidori');
  const dc = b.act({ type: 'skill', skill: 'chidori' }).find((e) => e.type === 'damage' && e.target === 'mahoraga').amount;
  assert.ok(dc > d3);
});

test('Rule of Four: only four skills can be equipped', () => {
  const p = spawn('player');
  for (const s of ['web_stun', 'acid_spit', 'shadow_clone', 'fireball', 'chidori']) learnSkill(p, s);
  assert.equal(p.learnedSkills.length, 5);
  assert.equal(p.skills.length, MAX_EQUIPPED_SKILLS);
  assert.throws(() => equipSkill(p, 'chidori'), /Only 4 skills/);
  equipSkill(p, 'chidori', 0);
  assert.equal(p.skills[0], 'chidori');
  assert.equal(p.skills.length, 4);
});

test('items: Onigiri heals, Soldier Pill restores Spirit Energy, run works on non-boss', () => {
  const p = playerWith([], { hp: 10, se: 0 });
  const foe = spawn('rogue_ninja', { spd: 1, ai: ['shuriken'], atk: 1 });
  const b = createBattle({ player: p, enemies: [foe], rng: { ...fixedRng(), chance: () => false } });
  b.act({ type: 'item', item: 'onigiri' });
  assert.ok(p.hp >= 40 + 10 - 5);
  assert.equal(p.items.onigiri, 1);
  b.act({ type: 'item', item: 'soldier_pill' });
  assert.equal(p.se, 20);
  const b2 = createBattle({ player: p, enemies: [spawn('rogue_ninja')], rng: fixedRng() });
  b2.act({ type: 'run' });
  assert.equal(b2.result.outcome, 'fled');
});

test('seeded rng is reproducible', () => {
  const a = createRng(42); const b = createRng(42);
  for (let i = 0; i < 20; i++) assert.equal(a.next(), b.next());
});
