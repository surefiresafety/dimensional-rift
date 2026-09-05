// Replays the Minute 10-15 tutorial fight exactly as scripted:
//   1. Normal attack barely scratches the Cursed Toad.
//   2. Web-Stun paralyzes it and lowers its defense.
//   3. Kakashi (guest ally) automatically follows up and defeats it.
//   4. The player absorbs Acid Spit.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBattle } from '../src/combat/battle.js';
import { spawn } from '../src/combat/entities.js';
import { createRng } from '../src/combat/rng.js';

function setup(seed) {
  const player = spawn('player', { skills: ['web_stun'], learnedSkills: ['web_stun'] });
  const kakashi = spawn('kakashi');
  const toad = spawn('cursed_toad');
  return { player, kakashi, toad, battle: createBattle({ player, allies: [kakashi], enemies: [toad], rng: createRng(seed) }) };
}

test('normal attacks do very little to the Cursed Toad', () => {
  const { battle, toad } = setup(1);
  const ev = battle.act({ type: 'attack' });
  const hit = ev.find((e) => e.type === 'damage' && e.target === 'cursed_toad');
  assert.ok(hit.amount <= 4, `expected a scratch, got ${hit.amount}`);
  assert.ok(toad.hp > toad.maxHp * 0.9);
  // Kakashi does NOT follow up while the toad's defense is intact.
  assert.ok(!ev.some((e) => e.type === 'follow-up'));
});

test('Web-Stun -> Kakashi follow-up -> victory -> absorb Acid Spit (all seeds)', () => {
  for (let seed = 1; seed <= 50; seed++) {
    const { battle, player, toad } = setup(seed);
    battle.act({ type: 'attack' }); // the game nudges the player toward a Skill after this
    const ev = battle.act({ type: 'skill', skill: 'web_stun' });
    assert.ok(ev.some((e) => e.type === 'status' && e.status === 'rooted'), `seed ${seed}: toad rooted`);
    assert.ok(ev.some((e) => e.type === 'stage' && e.stat === 'def'), `seed ${seed}: toad def lowered`);
    assert.ok(ev.some((e) => e.type === 'follow-up' && e.source === 'kakashi'), `seed ${seed}: Kakashi followed up`);
    assert.equal(toad.hp, 0, `seed ${seed}: toad defeated`);
    assert.equal(battle.result?.outcome, 'win', `seed ${seed}`);
    assert.deepEqual(battle.result.absorbed, ['acid_spit']);
    assert.ok(player.skills.includes('acid_spit'));
    const absorb = ev.find((e) => e.type === 'absorb');
    assert.match(absorb.text, /Skill Unlocked: Acid Spit \(Water\/Cursed Damage\)/);
  }
});
