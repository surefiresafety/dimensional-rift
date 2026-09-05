// Skill (Jutsu / Cursed Technique / Spider-Man gadget) definitions.
// Every skill costs Spirit Energy from the same unified pool, regardless of
// which universe it comes from.
//
// Fields:
//   id, name, origin ('naruto' | 'jjk' | 'marvel' | 'cursed-spirit')
//   nature   - chakra nature used for the matchup wheel
//   kind     - 'attack' | 'buff' | 'debuff' | 'heal'
//   power    - base damage (attack only)
//   cost     - Spirit Energy cost
//   accuracy - 0..1 (attack/debuff)
//   target   - 'enemy' | 'self' | 'ally'
//   effects  - array of side effects applied on hit:
//       { type:'status', status, chance, duration, target:'target'|'self' }
//       { type:'stage',  stat:'atk'|'def'|'spd', delta, chance, target }
//       { type:'heal',   percent }
//   tags     - free-form tags used by rules (e.g. 'web', 'ultimate')
//   bonus    - optional { ifTargetStatus, multiplier }

export const SKILLS = Object.freeze({
  // --- Basic ---
  strike: {
    id: 'strike', name: 'Strike', origin: 'basic', nature: 'physical', kind: 'attack',
    power: 20, cost: 0, accuracy: 1, target: 'enemy', effects: [],
    desc: 'A plain punch. Does very little to anything cursed.',
  },

  // --- Marvel / Spider-Man: crowd control ---
  web_stun: {
    id: 'web_stun', name: 'Web-Stun', origin: 'marvel', nature: 'physical', kind: 'debuff',
    power: 10, cost: 4, accuracy: 1, target: 'enemy', tags: ['web'],
    effects: [
      { type: 'status', status: 'rooted', chance: 1, duration: 1, target: 'target' },
      { type: 'status', status: 'webbed', chance: 1, duration: 3, target: 'target' },
      { type: 'stage', stat: 'def', delta: -1, chance: 1, target: 'target' },
    ],
    desc: 'Webs the enemy: they lose their next turn, their Speed drops and their Defense is lowered.',
  },
  web_shooters: {
    id: 'web_shooters', name: 'Web-Shooters', origin: 'marvel', nature: 'physical', kind: 'debuff',
    power: 0, cost: 6, accuracy: 0.95, target: 'enemy', tags: ['web'],
    effects: [
      { type: 'stage', stat: 'spd', delta: -2, chance: 1, target: 'target' },
      { type: 'status', status: 'webbed', chance: 1, duration: 3, target: 'target' },
      { type: 'status', status: 'rooted', chance: 0.5, duration: 1, target: 'target' },
    ],
    desc: 'Drastically lowers the enemy\'s Speed. 50% chance to Root them (skip a turn).',
  },
  spider_sense: {
    id: 'spider_sense', name: 'Spider-Sense', origin: 'marvel', nature: 'physical', kind: 'buff',
    power: 0, cost: 8, accuracy: 1, target: 'self',
    effects: [{ type: 'status', status: 'evasive', chance: 1, duration: 1, target: 'self' }],
    desc: 'Tingling! Dodge the next attack completely, even a Domain Expansion.',
  },
  web_swing_kick: {
    id: 'web_swing_kick', name: 'Web Swing Kick', origin: 'marvel', nature: 'physical', kind: 'attack',
    power: 45, cost: 7, accuracy: 0.95, target: 'enemy', tags: ['web'],
    bonus: { ifTargetStatus: 'webbed', multiplier: 2 },
    effects: [],
    desc: 'A swinging kick. Double damage if the enemy is trapped in webs.',
  },

  // --- Naruto: ninjutsu ---
  fireball: {
    id: 'fireball', name: 'Fireball Jutsu', origin: 'naruto', nature: 'fire', kind: 'attack',
    power: 55, cost: 10, accuracy: 0.95, target: 'enemy',
    effects: [{ type: 'status', status: 'burned', chance: 0.2, duration: 3, target: 'target' }],
    desc: 'Uchiha signature. May Burn.',
  },
  chidori: {
    id: 'chidori', name: 'Chidori', origin: 'naruto', nature: 'lightning', kind: 'attack',
    power: 70, cost: 14, accuracy: 0.9, target: 'enemy',
    effects: [{ type: 'status', status: 'paralyzed', chance: 0.3, duration: 3, target: 'target' }],
    desc: 'A thousand birds. May Paralyze.',
  },
  rasenshuriken: {
    id: 'rasenshuriken', name: 'Rasenshuriken', origin: 'naruto', nature: 'wind', kind: 'attack',
    power: 95, cost: 22, accuracy: 0.9, target: 'enemy', tags: ['ultimate'],
    effects: [],
    desc: 'A spinning blade of wind chakra. Very costly.',
  },
  rasengan: {
    id: 'rasengan', name: 'Rasengan', origin: 'naruto', nature: 'wind', kind: 'attack',
    power: 65, cost: 12, accuracy: 0.95, target: 'enemy',
    effects: [],
    desc: 'A dense sphere of spinning chakra.',
  },
  mud_wall: {
    id: 'mud_wall', name: 'Mud Wall Jutsu', origin: 'naruto', nature: 'earth', kind: 'buff',
    power: 0, cost: 6, accuracy: 1, target: 'self',
    effects: [{ type: 'stage', stat: 'def', delta: 2, chance: 1, target: 'self' }],
    desc: 'Raise a wall of earth. Defense sharply rises.',
  },
  water_dragon: {
    id: 'water_dragon', name: 'Water Dragon Jutsu', origin: 'naruto', nature: 'water', kind: 'attack',
    power: 75, cost: 16, accuracy: 0.9, target: 'enemy',
    effects: [],
    desc: 'A dragon made of water crashes down.',
  },
  shadow_clone: {
    id: 'shadow_clone', name: 'Shadow Clone Jutsu', origin: 'naruto', nature: 'physical', kind: 'buff',
    power: 0, cost: 9, accuracy: 1, target: 'self',
    effects: [{ type: 'status', status: 'decoy', chance: 1, duration: 2, target: 'self' }],
    desc: 'A clone takes the next hit for you.',
  },
  sharingan: {
    id: 'sharingan', name: 'Sharingan', origin: 'naruto', nature: 'physical', kind: 'buff',
    power: 0, cost: 8, accuracy: 1, target: 'self',
    effects: [{ type: 'status', status: 'evasive', chance: 1, duration: 1, target: 'self' }],
    desc: 'See the attack before it lands: dodge rate becomes 100% for one turn.',
  },
  shuriken: {
    id: 'shuriken', name: 'Shuriken', origin: 'naruto', nature: 'physical', kind: 'attack',
    power: 30, cost: 2, accuracy: 1, target: 'enemy',
    effects: [],
    desc: 'A thrown blade. Cheap and reliable.',
  },

  // --- JJK: cursed techniques ---
  black_flash: {
    id: 'black_flash', name: 'Black Flash', origin: 'jjk', nature: 'cursed', kind: 'attack',
    power: 60, cost: 12, accuracy: 0.8, target: 'enemy', tags: ['crit'],
    effects: [],
    desc: 'A spark of black. Critical when it connects.',
  },
  disaster_flames: {
    id: 'disaster_flames', name: 'Disaster Flames', origin: 'jjk', nature: 'fire', kind: 'attack',
    power: 80, cost: 18, accuracy: 0.9, target: 'enemy',
    effects: [{ type: 'status', status: 'burned', chance: 0.5, duration: 3, target: 'target' }],
    desc: 'Jogo\'s volcanic technique. Often Burns.',
  },
  dismantle: {
    id: 'dismantle', name: 'Dismantle', origin: 'jjk', nature: 'wind', kind: 'attack',
    power: 60, cost: 10, accuracy: 0.95, target: 'enemy',
    effects: [],
    desc: 'Sukuna\'s invisible slashes.',
  },
  cleave: {
    id: 'cleave', name: 'Cleave', origin: 'jjk', nature: 'wind', kind: 'attack',
    power: 90, cost: 20, accuracy: 0.85, target: 'enemy', tags: ['ultimate'],
    effects: [],
    desc: 'One slash that adjusts to the target\'s toughness.',
  },
  kashimo_energy: {
    id: 'kashimo_energy', name: 'Mythical Beast Amber', origin: 'jjk', nature: 'lightning', kind: 'attack',
    power: 85, cost: 18, accuracy: 0.9, target: 'enemy',
    effects: [{ type: 'status', status: 'paralyzed', chance: 0.4, duration: 3, target: 'target' }],
    desc: 'Kashimo\'s electric cursed energy. Often Paralyzes.',
  },
  hanami_roots: {
    id: 'hanami_roots', name: 'Cursed Roots', origin: 'jjk', nature: 'earth', kind: 'attack',
    power: 55, cost: 10, accuracy: 0.95, target: 'enemy',
    effects: [{ type: 'status', status: 'rooted', chance: 0.3, duration: 1, target: 'target' }],
    desc: 'Hanami\'s roots burst from the ground. May Root.',
  },
  dagon_domain: {
    id: 'dagon_domain', name: 'Coffin of the Iron Mountain', origin: 'jjk', nature: 'water', kind: 'attack',
    power: 100, cost: 25, accuracy: 1, target: 'enemy', tags: ['ultimate', 'domain'],
    effects: [],
    desc: 'Dagon\'s Domain Expansion. A sure-hit tidal wave.',
  },
  reverse_cursed: {
    id: 'reverse_cursed', name: 'Reverse Cursed Technique', origin: 'jjk', nature: 'cursed', kind: 'heal',
    power: 0, cost: 15, accuracy: 1, target: 'self',
    effects: [{ type: 'heal', percent: 0.5 }],
    desc: 'Multiply negative energy to heal 50% HP.',
  },

  // --- Absorbed from cursed spirits ---
  acid_spit: {
    id: 'acid_spit', name: 'Acid Spit', origin: 'cursed-spirit', nature: 'water', kind: 'attack',
    power: 40, cost: 5, accuracy: 0.95, target: 'enemy',
    effects: [{ type: 'status', status: 'poisoned', chance: 0.5, duration: 3, target: 'target' }],
    desc: 'Water/Cursed damage copied from a Cursed Toad. May Poison.',
  },
  poison_spit: {
    id: 'poison_spit', name: 'Poison Spit', origin: 'cursed-spirit', nature: 'water', kind: 'attack',
    power: 30, cost: 4, accuracy: 0.95, target: 'enemy',
    effects: [{ type: 'status', status: 'poisoned', chance: 0.8, duration: 3, target: 'target' }],
    desc: 'Nearly always Poisons.',
  },
});

export const MAX_EQUIPPED_SKILLS = 4; // The Rule of Four.

export function getSkill(id) {
  const s = SKILLS[id];
  if (!s) throw new Error(`Unknown skill: ${id}`);
  return s;
}
