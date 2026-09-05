// Consumables for the Item command.
export const ITEMS = Object.freeze({
  onigiri: { id: 'onigiri', name: 'Onigiri', desc: 'Restores 40 HP.', effect: { hp: 40 } },
  soldier_pill: { id: 'soldier_pill', name: 'Soldier Pill', desc: 'Restores 20 Spirit Energy.', effect: { se: 20 } },
  cursed_tea: { id: 'cursed_tea', name: 'Cursed Tea', desc: 'Cures all status ailments.', effect: { cure: true } },
});

export function getItem(id) {
  const i = ITEMS[id];
  if (!i) throw new Error(`Unknown item: ${id}`);
  return i;
}
