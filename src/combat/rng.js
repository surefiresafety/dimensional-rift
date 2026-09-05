// Deterministic pseudo-random generator (mulberry32).
// Battles take an RNG so tests and replays are reproducible.
export function createRng(seed = 1) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    chance: (p) => next() < p,
    range: (min, max) => min + (max - min) * next(),
    pick: (arr) => arr[Math.floor(next() * arr.length)],
  };
}
