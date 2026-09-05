// Turn-based battle engine.
//
// Usage:
//   const b = createBattle({ player, allies: [kakashi], enemies: [toad], rng });
//   b.options()            -> what the player can do right now
//   b.act({ type:'skill', skill:'web_stun' }) -> resolves the whole round,
//                             returns an array of events for the UI/log
//   b.result               -> null while running, else { outcome, absorbed, scrolls }
import { effectiveness, SUPER_EFFECTIVE, NOT_VERY_EFFECTIVE } from './natures.js';
import { stageMultiplier, clampStage, STATUS, PARALYSIS_SKIP_CHANCE, WEBBED_SPEED_MULTIPLIER } from './status.js';
import { getSkill, MAX_EQUIPPED_SKILLS } from './skills.js';
import { getSummon, scrollsUnlockedBy } from './summons.js';
import { getItem } from './items.js';
import { isAlive } from './entities.js';
import { createRng } from './rng.js';

const MAHORAGA_ADAPT_STEP = 0.5;
const MAHORAGA_ADAPT_FLOOR = 0.125;
const CRIT_MULTIPLIER = 1.5;
const DOT_STATUSES = [STATUS.POISONED, STATUS.BURNED];

export function effectiveStat(c, stat) {
  let v = c[stat] * stageMultiplier(c.stages[stat]);
  if (stat === 'spd' && c.statuses[STATUS.WEBBED]) v *= WEBBED_SPEED_MULTIPLIER;
  return Math.max(1, Math.floor(v));
}

/**
 * Damage formula (Pokémon-style, tuned for small numbers).
 * Returns { damage, multiplier, crit, notes }.
 */
export function computeDamage({ attacker, defender, move, rng, natureOverride }) {
  const nature = natureOverride ?? move.nature;
  const power = move.power ?? 0;
  if (power <= 0) return { damage: 0, multiplier: 1, crit: false, notes: [] };

  const atk = effectiveStat(attacker, 'atk');
  const def = effectiveStat(defender, 'def');
  const levelTerm = (2 * attacker.level) / 5 + 2;
  let dmg = (levelTerm * power * (atk / def)) / 50 + 2;

  const notes = [];
  let multiplier = effectiveness(nature, defender.nature);
  if (multiplier >= SUPER_EFFECTIVE) notes.push('super-effective');
  else if (multiplier <= NOT_VERY_EFFECTIVE) notes.push('not-very-effective');

  if (move.bonus && defender.statuses[move.bonus.ifTargetStatus]) {
    multiplier *= move.bonus.multiplier;
    notes.push('bonus');
  }
  if (defender.traits?.adapts && defender.adaptations[nature]) {
    multiplier *= defender.adaptations[nature];
    notes.push('adapted');
  }
  if (defender.statuses[STATUS.GUARDING]) {
    multiplier *= 0.5;
    notes.push('guarded');
  }
  const crit = Boolean(move.tags?.includes('crit'));
  if (crit) multiplier *= CRIT_MULTIPLIER;

  const roll = rng ? rng.range(0.85, 1.0) : 1;
  const damage = Math.max(1, Math.floor(dmg * multiplier * roll));
  return { damage, multiplier, crit, notes };
}

export function createBattle({ player, allies = [], enemies = [], rng = createRng(1), canRun = true }) {
  const state = {
    player,
    allies,
    enemies,
    rng,
    round: 0,
    result: null,
    log: [],
    canRun: canRun && !enemies.some((e) => e.bossId),
  };

  const events = [];
  const emit = (e) => {
    events.push(e);
    state.log.push(e);
  };

  const livingEnemies = () => enemies.filter(isAlive);
  const livingAllies = () => allies.filter(isAlive);
  const enemyTarget = () => livingEnemies()[0] ?? null;

  const usesSe = (c) => c.side === 'player' || c.maxSe > 0;
  const canAfford = (c, cost) => !usesSe(c) || c.se >= cost;

  function options() {
    const p = player;
    return {
      attack: true,
      skills: p.skills.map((id) => {
        const s = getSkill(id);
        return { id, name: s.name, cost: s.cost, nature: s.nature, kind: s.kind, desc: s.desc, affordable: p.se >= s.cost };
      }),
      summons: p.scrolls.map((id) => {
        const s = getSummon(id);
        return { id, name: s.name, cost: s.cost, nature: s.nature, desc: s.desc, affordable: p.se >= s.cost };
      }),
      items: Object.entries(p.items).filter(([, n]) => n > 0).map(([id, count]) => ({ id, name: getItem(id).name, desc: getItem(id).desc, count })),
      run: state.canRun,
      guard: true,
    };
  }

  // ---- status helpers ----
  function applyEffects(effects, { user, target }) {
    for (const ef of effects) {
      const who = ef.target === 'self' ? user : target;
      if (!who || !isAlive(who)) continue;
      if (ef.type === 'status') {
        if (ef.chance < 1 && !rng.chance(ef.chance)) continue;
        if (!who.statuses[ef.status]) {
          who.statuses[ef.status] = ef.duration;
          emit({ type: 'status', target: who.id, status: ef.status, text: `${who.name} is ${statusVerb(ef.status)}!` });
        }
      } else if (ef.type === 'stage') {
        if (ef.chance < 1 && !rng.chance(ef.chance)) continue;
        const before = who.stages[ef.stat];
        who.stages[ef.stat] = clampStage(before + ef.delta);
        if (who.stages[ef.stat] !== before) {
          const dir = ef.delta > 0 ? 'rose' : 'fell';
          const sharp = Math.abs(ef.delta) >= 2 ? ' sharply' : '';
          emit({ type: 'stage', target: who.id, stat: ef.stat, delta: ef.delta, text: `${who.name}'s ${statName(ef.stat)}${sharp} ${dir}!` });
        }
      } else if (ef.type === 'heal') {
        const amount = Math.floor(who.maxHp * ef.percent);
        const healed = Math.min(amount, who.maxHp - who.hp);
        who.hp += healed;
        emit({ type: 'heal', target: who.id, amount: healed, text: `${who.name} recovered ${healed} HP.` });
      }
    }
  }

  function dealDamage(attacker, defender, move) {
    if (defender.statuses[STATUS.EVASIVE]) {
      delete defender.statuses[STATUS.EVASIVE];
      emit({ type: 'dodge', target: defender.id, text: `${defender.name} dodged it completely!` });
      return false;
    }
    if (defender.statuses[STATUS.DECOY]) {
      delete defender.statuses[STATUS.DECOY];
      emit({ type: 'decoy', target: defender.id, text: `${defender.name}'s Shadow Clone took the hit and vanished!` });
      return false;
    }
    const { damage, multiplier, crit, notes } = computeDamage({ attacker, defender, move, rng });
    if (damage > 0) {
      defender.hp = Math.max(0, defender.hp - damage);
      const parts = [];
      if (notes.includes('super-effective')) parts.push("It's super effective!");
      if (notes.includes('not-very-effective')) parts.push("It's not very effective...");
      if (notes.includes('bonus')) parts.push('Webbed target took double damage!');
      if (notes.includes('adapted')) parts.push(`${defender.name} has adapted to it...`);
      if (notes.includes('guarded')) parts.push(`${defender.name} guarded.`);
      if (crit) parts.push('Critical hit!');
      emit({ type: 'damage', source: attacker.id, target: defender.id, amount: damage, multiplier, notes, text: `${defender.name} took ${damage} damage. ${parts.join(' ')}`.trim() });
      if (defender.traits?.adapts) {
        const n = move.nature;
        defender.adaptations[n] = Math.max(MAHORAGA_ADAPT_FLOOR, (defender.adaptations[n] ?? 1) * MAHORAGA_ADAPT_STEP);
        emit({ type: 'adapt', target: defender.id, nature: n, text: `${defender.name} is adapting to ${n} attacks!` });
      }
      if (!isAlive(defender)) emit({ type: 'defeated', target: defender.id, text: `${defender.name} was defeated!` });
    }
    return true;
  }

  function useMove(user, move, target, label = 'used') {
    if (usesSe(user)) user.se -= move.cost ?? 0;
    emit({ type: 'move', source: user.id, target: target?.id ?? null, move: move.id, nature: move.nature, text: `${user.name} ${label} ${move.name}!` });
    const kind = move.kind ?? 'attack';
    if (kind === 'buff' || kind === 'heal') {
      applyEffects(move.effects ?? [], { user, target: user });
      return;
    }
    if (!target || !isAlive(target)) return;
    if ((move.accuracy ?? 1) < 1 && !rng.chance(move.accuracy)) {
      emit({ type: 'miss', source: user.id, target: target.id, text: `${user.name}'s ${move.name} missed!` });
      return;
    }
    let connected = true;
    if ((move.power ?? 0) > 0) connected = dealDamage(user, target, move);
    else if (target.statuses[STATUS.EVASIVE]) {
      delete target.statuses[STATUS.EVASIVE];
      emit({ type: 'dodge', target: target.id, text: `${target.name} dodged it completely!` });
      connected = false;
    }
    if (connected) applyEffects(move.effects ?? [], { user, target });
  }

  function startTurn(c) {
    // Returns false if the combatant loses its turn.
    let canAct = true;
    if (c.statuses[STATUS.ROOTED]) {
      emit({ type: 'skip', target: c.id, reason: 'rooted', text: `${c.name} is stuck in webs and can't move!` });
      canAct = false;
    } else if (c.statuses[STATUS.PARALYZED] && rng.chance(PARALYSIS_SKIP_CHANCE)) {
      emit({ type: 'skip', target: c.id, reason: 'paralyzed', text: `${c.name} is paralyzed and can't move!` });
      canAct = false;
    }
    for (const s of Object.keys(c.statuses)) {
      if (DOT_STATUSES.includes(s)) continue; // DoT counts down at end of round
      c.statuses[s] -= 1;
      if (c.statuses[s] <= 0) {
        delete c.statuses[s];
        if (s !== STATUS.EVASIVE && s !== STATUS.DECOY && s !== STATUS.GUARDING) {
          emit({ type: 'status-end', target: c.id, status: s, text: `${c.name} is no longer ${statusAdj(s)}.` });
        }
      }
    }
    return canAct;
  }

  function endOfRound() {
    for (const c of [player, ...allies, ...enemies]) {
      if (!isAlive(c)) continue;
      if (c.statuses[STATUS.POISONED]) {
        const d = Math.max(1, Math.floor(c.maxHp / 8));
        c.hp = Math.max(0, c.hp - d);
        emit({ type: 'dot', target: c.id, status: 'poisoned', amount: d, text: `${c.name} is hurt by poison (${d}).` });
      }
      if (c.statuses[STATUS.BURNED]) {
        const d = Math.max(1, Math.floor(c.maxHp / 16));
        c.hp = Math.max(0, c.hp - d);
        emit({ type: 'dot', target: c.id, status: 'burned', amount: d, text: `${c.name} is hurt by its burn (${d}).` });
      }
      if (!isAlive(c)) emit({ type: 'defeated', target: c.id, text: `${c.name} was defeated!` });
      for (const s of DOT_STATUSES) {
        if (!c.statuses[s]) continue;
        c.statuses[s] -= 1;
        if (c.statuses[s] <= 0) {
          delete c.statuses[s];
          emit({ type: 'status-end', target: c.id, status: s, text: `${c.name} is no longer ${statusAdj(s)}.` });
        }
      }
    }
  }

  function checkEnd() {
    if (state.result) return true;
    if (!isAlive(player)) {
      state.result = { outcome: 'lose', absorbed: [], scrolls: [] };
      emit({ type: 'end', outcome: 'lose', text: `${player.name} collapsed...` });
      return true;
    }
    if (livingEnemies().length === 0) {
      const absorbed = [];
      const scrolls = [];
      for (const e of enemies) {
        if (e.absorbable && !player.learnedSkills.includes(e.absorbable)) {
          player.learnedSkills.push(e.absorbable);
          if (player.skills.length < MAX_EQUIPPED_SKILLS) player.skills.push(e.absorbable);
          absorbed.push(e.absorbable);
          const s = getSkill(e.absorbable);
          emit({ type: 'absorb', skill: e.absorbable, from: e.id, text: `You absorbed the ${e.name}'s energy! Skill Unlocked: ${s.name} (${natureLabel(s.nature)}${s.origin === 'cursed-spirit' ? '/Cursed' : ''} Damage).` });
        }
        if (e.bossId) {
          for (const id of scrollsUnlockedBy(e.bossId)) {
            if (!player.scrolls.includes(id)) {
              player.scrolls.push(id);
              scrolls.push(id);
              emit({ type: 'scroll', summon: id, from: e.id, text: `Summoning Scroll obtained: ${getSummon(id).name}!` });
            }
          }
        }
      }
      state.result = { outcome: 'win', absorbed, scrolls };
      emit({ type: 'end', outcome: 'win', text: 'Victory!' });
      return true;
    }
    return false;
  }

  function guestFollowUps(target) {
    for (const g of livingAllies()) {
      if (!g.guest) continue;
      const t = isAlive(target) ? target : enemyTarget();
      if (!t) return;
      const defDown = t.stages.def < 0;
      let skillId = null;
      if (g.guest.trigger === 'always') skillId = g.guest.skill;
      else if (g.guest.trigger === 'target-def-down' && defDown) skillId = g.guest.skill;
      if (!skillId) {
        if (g.guest.fallback && g.guest.trigger === 'always') skillId = g.guest.fallback;
        else continue;
      }
      if (!canAfford(g, getSkill(skillId).cost)) skillId = g.guest.fallback ?? null;
      if (!skillId) continue;
      emit({ type: 'follow-up', source: g.id, text: `${g.name} follows up!` });
      const move = g.guest.sureHit ? { ...getSkill(skillId), accuracy: 1 } : getSkill(skillId);
      useMove(g, move, t);
      if (checkEnd()) return;
    }
  }

  function enemyAct(e) {
    if (!startTurn(e)) return;
    const pool = (e.ai ?? ['strike']).filter((id) => canAfford(e, getSkill(id).cost));
    const skillId = pool.length ? rng.pick(pool) : 'strike';
    const move = getSkill(skillId);
    const targets = [player, ...livingAllies()].filter(isAlive);
    // Enemies prefer the player, but a guest may draw fire 25% of the time.
    const target = targets.length > 1 && rng.chance(0.25) ? rng.pick(targets.slice(1)) : player;
    useMove(e, move, move.target === 'self' ? e : target);
  }

  function playerAct(action) {
    const target = enemyTarget();
    switch (action.type) {
      case 'attack':
        useMove(player, getSkill('strike'), target);
        break;
      case 'skill': {
        if (!player.skills.includes(action.skill)) throw new Error(`Skill not equipped: ${action.skill}`);
        const move = getSkill(action.skill);
        if (player.se < move.cost) throw new Error(`Not enough Spirit Energy for ${move.name}`);
        useMove(player, move, move.target === 'self' ? player : target);
        break;
      }
      case 'summon': {
        if (!player.scrolls.includes(action.summon)) throw new Error(`No scroll for: ${action.summon}`);
        const s = getSummon(action.summon);
        if (player.se < s.cost) throw new Error(`Not enough Spirit Energy to summon ${s.name}`);
        emit({ type: 'summon', summon: s.id, text: `Kuchiyose no Jutsu! ${s.name} appears!` });
        useMove(player, { ...s, kind: 'attack' }, target, 'commands');
        break;
      }
      case 'item': {
        const item = getItem(action.item);
        if (!(player.items[action.item] > 0)) throw new Error(`No ${item.name} left`);
        player.items[action.item] -= 1;
        emit({ type: 'item', item: item.id, text: `${player.name} used ${item.name}.` });
        if (item.effect.hp) {
          const healed = Math.min(item.effect.hp, player.maxHp - player.hp);
          player.hp += healed;
          emit({ type: 'heal', target: player.id, amount: healed, text: `${player.name} recovered ${healed} HP.` });
        }
        if (item.effect.se) {
          const got = Math.min(item.effect.se, player.maxSe - player.se);
          player.se += got;
          emit({ type: 'restore-se', target: player.id, amount: got, text: `${player.name} recovered ${got} Spirit Energy.` });
        }
        if (item.effect.cure) {
          for (const s of ['poisoned', 'burned', 'paralyzed', 'rooted', 'webbed']) delete player.statuses[s];
          emit({ type: 'cure', target: player.id, text: `${player.name} was cured of all ailments.` });
        }
        break;
      }
      case 'guard':
        player.statuses[STATUS.GUARDING] = 1;
        emit({ type: 'guard', target: player.id, text: `${player.name} braces for impact.` });
        break;
      case 'run': {
        if (!state.canRun) {
          emit({ type: 'run-fail', text: "You can't run from this fight!" });
          break;
        }
        const fastest = Math.max(...livingEnemies().map((e) => effectiveStat(e, 'spd')));
        const p = Math.max(0.1, Math.min(0.95, 0.5 + (effectiveStat(player, 'spd') - fastest) / 100));
        if (rng.chance(p)) {
          state.result = { outcome: 'fled', absorbed: [], scrolls: [] };
          emit({ type: 'end', outcome: 'fled', text: 'Got away safely!' });
        } else {
          emit({ type: 'run-fail', text: "Couldn't get away!" });
        }
        break;
      }
      default:
        throw new Error(`Unknown action type: ${action.type}`);
    }
    return target;
  }

  /**
   * Resolve one full round given the player's chosen action.
   * Returns the events generated this round.
   */
  function act(action) {
    if (state.result) throw new Error('Battle is over');
    events.length = 0;
    state.round += 1;
    emit({ type: 'round', round: state.round, text: `— Round ${state.round} —` });

    // Build turn order by effective speed. Guests act as follow-ups to the
    // player rather than on their own initiative.
    const order = [player, ...livingEnemies()].sort((a, b) => effectiveStat(b, 'spd') - effectiveStat(a, 'spd'));

    for (const c of order) {
      if (state.result) break;
      if (!isAlive(c)) continue;
      if (c === player) {
        if (!startTurn(player)) continue;
        const target = playerAct(action);
        if (checkEnd()) break;
        guestFollowUps(target);
        if (checkEnd()) break;
      } else {
        enemyAct(c);
        if (checkEnd()) break;
      }
    }
    if (!state.result) {
      endOfRound();
      checkEnd();
    }
    return [...events];
  }

  return {
    state,
    get result() { return state.result; },
    get round() { return state.round; },
    options,
    act,
    computeDamage: (attacker, defender, move) => computeDamage({ attacker, defender, move, rng: null }),
  };
}

// ---- text helpers ----
function statName(s) {
  return { atk: 'Attack', def: 'Defense', spd: 'Speed' }[s] ?? s;
}
function natureLabel(n) {
  return n.charAt(0).toUpperCase() + n.slice(1);
}
function statusVerb(s) {
  return {
    rooted: 'rooted in place', paralyzed: 'paralyzed', webbed: 'covered in webs', poisoned: 'poisoned',
    burned: 'burned', evasive: 'ready to dodge', decoy: 'protected by a Shadow Clone', guarding: 'guarding',
  }[s] ?? s;
}
function statusAdj(s) {
  return { rooted: 'rooted', paralyzed: 'paralyzed', webbed: 'webbed', poisoned: 'poisoned', burned: 'burned' }[s] ?? s;
}
