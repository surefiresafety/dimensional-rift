// Combatant factory and the character roster.
import { MAX_EQUIPPED_SKILLS } from './skills.js';

/**
 * Create a live combatant from a template.
 * @param {object} t template
 * @param {object} [overrides]
 */
export function createCombatant(t, overrides = {}) {
  const base = { ...t, ...overrides };
  const c = {
    id: base.id,
    name: base.name,
    side: base.side ?? 'enemy', // 'player' | 'ally' | 'enemy'
    nature: base.nature ?? null,
    level: base.level ?? 5,
    maxHp: base.maxHp,
    hp: base.hp ?? base.maxHp,
    maxSe: base.maxSe ?? 0,
    se: base.se ?? base.maxSe ?? 0,
    atk: base.atk,
    def: base.def,
    spd: base.spd,
    stages: { atk: 0, def: 0, spd: 0 },
    statuses: {}, // status -> remaining turns
    // Skills this combatant knows and the ones it has equipped (Rule of Four).
    learnedSkills: [...(base.learnedSkills ?? base.skills ?? [])],
    skills: [...(base.skills ?? [])].slice(0, MAX_EQUIPPED_SKILLS),
    // Summoning scrolls (ids into SUMMONS).
    scrolls: [...(base.scrolls ?? [])],
    items: { ...(base.items ?? {}) },
    // Enemy AI hint: list of skill ids it uses, or 'strike'.
    ai: base.ai ?? null,
    // Guest ally behaviour: { trigger:'target-def-down'|'always', skill, fallback, sureHit }
    guest: base.guest ?? null,
    // Skill the player copies when this combatant is defeated.
    absorbable: base.absorbable ?? null,
    // Boss id used by summoning contracts.
    bossId: base.bossId ?? null,
    // Traits: e.g. { adapts: true } for Mahoraga.
    traits: { ...(base.traits ?? {}) },
    adaptations: {}, // nature -> resistance multiplier (Mahoraga)
    tags: [...(base.tags ?? [])],
  };
  return c;
}

export function isAlive(c) {
  return c.hp > 0;
}

// --- Roster ---------------------------------------------------------------

export const ROSTER = Object.freeze({
  player: {
    id: 'player', name: 'Rift Walker', side: 'player', nature: null, level: 5,
    maxHp: 90, maxSe: 30, atk: 18, def: 14, spd: 16,
    skills: [], learnedSkills: [], scrolls: [],
    items: { onigiri: 2, soldier_pill: 1 },
  },

  // Guest allies (RPG Maker "guest" battlers): act automatically.
  kakashi: {
    id: 'kakashi', name: 'Kakashi Hatake', side: 'ally', nature: 'lightning', level: 30,
    maxHp: 220, maxSe: 80, atk: 60, def: 30, spd: 40,
    skills: ['chidori', 'shuriken'],
    guest: { trigger: 'target-def-down', skill: 'chidori', fallback: 'shuriken', sureHit: true },
  },
  spiderman: {
    id: 'spiderman', name: 'Spider-Man', side: 'ally', nature: null, level: 25,
    maxHp: 180, maxSe: 60, atk: 34, def: 26, spd: 48,
    skills: ['web_shooters', 'web_swing_kick'],
    guest: { trigger: 'always', skill: 'web_swing_kick', fallback: 'web_shooters' },
  },
  gojo: {
    id: 'gojo', name: 'Satoru Gojo', side: 'ally', nature: 'cursed', level: 50,
    maxHp: 400, maxSe: 200, atk: 70, def: 50, spd: 60,
    skills: ['black_flash'],
    guest: { trigger: 'always', skill: 'black_flash' },
  },

  // Tutorial enemy. Ninjutsu barely works on it (high def), so the game
  // pushes the player toward Web-Stun.
  cursed_toad: {
    id: 'cursed_toad', name: 'Cursed Toad', side: 'enemy', nature: 'water', level: 4,
    maxHp: 40, atk: 14, def: 40, spd: 8,
    skills: ['acid_spit', 'strike'], ai: ['acid_spit', 'strike'],
    absorbable: 'acid_spit', tags: ['cursed-spirit'],
  },
  cursed_spirit_grade4: {
    id: 'cursed_spirit_grade4', name: 'Grade 4 Cursed Spirit', side: 'enemy', nature: 'earth', level: 3,
    maxHp: 40, atk: 12, def: 10, spd: 9,
    skills: ['strike', 'poison_spit'], ai: ['strike', 'poison_spit'],
    absorbable: 'poison_spit', tags: ['cursed-spirit'],
  },
  rogue_ninja: {
    id: 'rogue_ninja', name: 'Rogue Ninja', side: 'enemy', nature: 'lightning', level: 8,
    maxHp: 80, maxSe: 30, atk: 20, def: 16, spd: 20,
    skills: ['shuriken', 'shadow_clone'], ai: ['shuriken', 'shadow_clone'],
    absorbable: 'shadow_clone',
  },

  // Bosses (defeat -> Summoning Scroll)
  megumi: {
    id: 'megumi', name: 'Megumi Fushiguro', side: 'enemy', nature: 'earth', level: 15, bossId: 'megumi',
    maxHp: 200, maxSe: 60, atk: 30, def: 24, spd: 26,
    skills: ['hanami_roots', 'strike'], ai: ['hanami_roots', 'strike'],
  },
  kakashi_boss: {
    id: 'kakashi_boss', name: 'Kakashi Hatake', side: 'enemy', nature: 'lightning', level: 30, bossId: 'kakashi',
    maxHp: 260, maxSe: 80, atk: 42, def: 30, spd: 40,
    skills: ['chidori', 'shuriken', 'sharingan'], ai: ['chidori', 'shuriken', 'sharingan'],
    absorbable: 'sharingan',
  },
  jiraiya: {
    id: 'jiraiya', name: 'Jiraiya', side: 'enemy', nature: 'water', level: 40, bossId: 'jiraiya',
    maxHp: 320, maxSe: 100, atk: 48, def: 34, spd: 30,
    skills: ['rasengan', 'fireball'], ai: ['rasengan', 'fireball'],
    absorbable: 'rasengan',
  },
  jogo: {
    id: 'jogo', name: 'Jogo', side: 'enemy', nature: 'fire', level: 35, bossId: 'jogo',
    maxHp: 300, maxSe: 100, atk: 50, def: 28, spd: 28,
    skills: ['disaster_flames'], ai: ['disaster_flames'],
    absorbable: 'disaster_flames', tags: ['cursed-spirit'],
  },
  kurama: {
    id: 'kurama', name: 'Kurama', side: 'enemy', nature: 'fire', level: 60, bossId: 'kurama',
    maxHp: 900, maxSe: 300, atk: 80, def: 50, spd: 45,
    skills: ['fireball', 'strike'], ai: ['fireball', 'strike'], tags: ['ultimate-boss'],
  },
  mahoraga: {
    id: 'mahoraga', name: 'Mahoraga', side: 'enemy', nature: 'cursed', level: 60, bossId: 'mahoraga',
    maxHp: 800, maxSe: 0, atk: 85, def: 55, spd: 35,
    skills: ['strike'], ai: ['strike'], tags: ['ultimate-boss'],
    // Mahoraga adapts: every nature that hits it becomes less effective.
    traits: { adapts: true },
  },
});

export function spawn(id, overrides = {}) {
  const t = ROSTER[id];
  if (!t) throw new Error(`Unknown roster entry: ${id}`);
  return createCombatant(t, overrides);
}
