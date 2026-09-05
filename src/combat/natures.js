// Chakra Natures: the elemental "type matchup" wheel.
// Fire > Wind > Lightning > Earth > Water > Fire
// Both Naruto jutsu and JJK cursed techniques are mapped onto these five
// natures so they share one combat wheel. PHYSICAL and CURSED are neutral.

export const NATURES = Object.freeze({
  FIRE: 'fire',
  WIND: 'wind',
  LIGHTNING: 'lightning',
  EARTH: 'earth',
  WATER: 'water',
  PHYSICAL: 'physical',
  CURSED: 'cursed',
});

// nature -> the nature it beats
export const BEATS = Object.freeze({
  fire: 'wind',
  wind: 'lightning',
  lightning: 'earth',
  earth: 'water',
  water: 'fire',
});

export const NATURE_INFO = Object.freeze({
  fire: { icon: '🔥', label: 'Fire', color: '#ff6b3d' },
  wind: { icon: '🌪️', label: 'Wind', color: '#8fe3c9' },
  lightning: { icon: '⚡', label: 'Lightning', color: '#ffe45c' },
  earth: { icon: '🪨', label: 'Earth', color: '#c9a068' },
  water: { icon: '💧', label: 'Water', color: '#5aa9ff' },
  physical: { icon: '👊', label: 'Physical', color: '#dddddd' },
  cursed: { icon: '👁️', label: 'Cursed', color: '#b06cff' },
});

export const SUPER_EFFECTIVE = 2;
export const NOT_VERY_EFFECTIVE = 0.5;

/**
 * Effectiveness multiplier of an attacking nature against a defending nature.
 * Defender may have no nature (null) -> neutral.
 */
export function effectiveness(attackNature, defendNature) {
  if (!attackNature || !defendNature) return 1;
  if (!(attackNature in BEATS) || !(defendNature in BEATS)) return 1;
  if (BEATS[attackNature] === defendNature) return SUPER_EFFECTIVE;
  if (BEATS[defendNature] === attackNature) return NOT_VERY_EFFECTIVE;
  return 1;
}

/** Full 5x5 chart, handy for UI and for the RPG Maker exporter. */
export function matchupChart() {
  const elemental = Object.keys(BEATS);
  return elemental.map((atk) => ({
    nature: atk,
    beats: BEATS[atk],
    weakTo: elemental.find((d) => BEATS[d] === atk),
    row: Object.fromEntries(elemental.map((def) => [def, effectiveness(atk, def)])),
  }));
}
