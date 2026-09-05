// Kuchiyose no Jutsu: Summoning Contracts.
// Instead of catching creatures, defeating a boss unlocks their Summoning
// Scroll. In battle the player spends Spirit Energy to call the beast for a
// single massive action.

export const SUMMONS = Object.freeze({
  divine_dogs: {
    id: 'divine_dogs', name: 'Divine Dogs', unlockedBy: 'megumi', origin: 'jjk',
    nature: 'earth', power: 70, cost: 15, accuracy: 0.95,
    effects: [],
    desc: 'Megumi\'s shikigami. Twin hounds tear into the enemy (Earth melee).',
  },
  ninja_hounds: {
    id: 'ninja_hounds', name: 'Ninja Hounds', unlockedBy: 'kakashi', origin: 'naruto',
    nature: 'physical', power: 35, cost: 12, accuracy: 1,
    effects: [{ type: 'status', status: 'paralyzed', chance: 1, duration: 3, target: 'target' }],
    desc: 'Kakashi\'s tracking pack. Pins the enemy down and Paralyzes.',
  },
  gamabunta: {
    id: 'gamabunta', name: 'Gamabunta', unlockedBy: 'jiraiya', origin: 'naruto',
    nature: 'water', power: 100, cost: 25, accuracy: 0.9,
    effects: [],
    desc: 'The Chief Toad. A colossal Water Gun.',
  },
  kurama: {
    id: 'kurama', name: 'Kurama (Nine-Tails)', unlockedBy: 'kurama', origin: 'naruto',
    nature: 'fire', power: 150, cost: 40, accuracy: 0.95, tags: ['ultimate'],
    effects: [{ type: 'status', status: 'burned', chance: 0.5, duration: 3, target: 'target' }],
    desc: 'Tailed Beast Bomb. Ultimate summon.',
  },
  mahoraga: {
    id: 'mahoraga', name: 'Mahoraga', unlockedBy: 'mahoraga', origin: 'jjk',
    nature: 'cursed', power: 130, cost: 40, accuracy: 1, tags: ['ultimate'],
    effects: [],
    desc: 'The Eight-Handled Sword Divergent Sila Divine General. Never misses.',
  },
});

export function getSummon(id) {
  const s = SUMMONS[id];
  if (!s) throw new Error(`Unknown summon: ${id}`);
  return s;
}

/** Summon scrolls unlocked by defeating the given boss id. */
export function scrollsUnlockedBy(bossId) {
  return Object.values(SUMMONS).filter((s) => s.unlockedBy === bossId).map((s) => s.id);
}
