// Status effects and stat stages (crowd control).
// Stages work like Pokémon: -6..+6, each stage scales a stat.

export const STAGE_MULTIPLIER = Object.freeze({
  '-6': 0.25, '-5': 0.29, '-4': 0.33, '-3': 0.4, '-2': 0.5, '-1': 0.67,
  '0': 1, '1': 1.5, '2': 2, '3': 2.5, '4': 3, '5': 3.5, '6': 4,
});

export function clampStage(n) {
  return Math.max(-6, Math.min(6, n));
}

export function stageMultiplier(stage) {
  return STAGE_MULTIPLIER[String(clampStage(stage))];
}

// Status effect ids. Each has a duration in turns (counted down at the
// affected combatant's end of turn) unless noted.
export const STATUS = Object.freeze({
  // Skip turns entirely (Web-Shooter "Root", Web-Stun).
  ROOTED: 'rooted',
  // 25% chance to lose the turn each turn (Ninja Hounds, Chidori graze).
  PARALYZED: 'paralyzed',
  // Speed heavily reduced and counts as "webbed" for Web Swing Kick bonus.
  WEBBED: 'webbed',
  // Damage over time (Acid Spit / Poison Spit).
  POISONED: 'poisoned',
  // Damage over time (Disaster Flames).
  BURNED: 'burned',
  // Guaranteed dodge of the next incoming attack (Sharingan / Spider-Sense).
  EVASIVE: 'evasive',
  // Shadow Clone decoy: absorbs the next hit entirely.
  DECOY: 'decoy',
  // Guarding: halves incoming damage for one turn.
  GUARDING: 'guarding',
});

export const STATUS_INFO = Object.freeze({
  rooted: { label: 'Rooted', icon: '🕸️', desc: 'Cannot act.' },
  paralyzed: { label: 'Paralyzed', icon: '⚡', desc: '25% chance to lose each turn.' },
  webbed: { label: 'Webbed', icon: '🕷️', desc: 'Speed greatly reduced; takes extra damage from Web Swing Kick.' },
  poisoned: { label: 'Poisoned', icon: '☠️', desc: 'Loses 1/8 max HP each turn.' },
  burned: { label: 'Burned', icon: '🔥', desc: 'Loses 1/16 max HP each turn.' },
  evasive: { label: 'Evasive', icon: '👁️', desc: 'Dodges the next attack completely.' },
  decoy: { label: 'Shadow Clone', icon: '👥', desc: 'A clone absorbs the next hit.' },
  guarding: { label: 'Guarding', icon: '🛡️', desc: 'Incoming damage halved this turn.' },
});

export const PARALYSIS_SKIP_CHANCE = 0.25;
export const WEBBED_SPEED_MULTIPLIER = 0.4;
