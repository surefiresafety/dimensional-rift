// The Rule of Four: equip up to 4 of the skills you have absorbed.
import { SKILLS, MAX_EQUIPPED_SKILLS } from '../combat/skills.js';
import { NATURE_INFO } from '../combat/natures.js';
import { equipSkill, unequipSkill } from '../combat/loadout.js';

export function createSkillsMenu({ root, player }) {
  function render() {
    const rows = player.learnedSkills.map((id) => {
      const s = SKILLS[id];
      const slot = player.skills.indexOf(id);
      const equipped = slot >= 0;
      return `<div class="row">
        <span class="slot">${equipped ? `#${slot + 1}` : ''}</span>
        <button data-id="${id}">${equipped ? 'Unequip' : 'Equip'}</button>
        <b>${NATURE_INFO[s.nature].icon} ${s.name}</b> <span>(${s.cost} SE · ${s.origin})</span> <span style="opacity:.7">${s.desc}</span>
      </div>`;
    }).join('');
    root.innerHTML = `<h3>Skills — ${player.skills.length}/${MAX_EQUIPPED_SKILLS} equipped (The Rule of Four)</h3>
      <p style="opacity:.75;margin:0 0 8px">Only ${MAX_EQUIPPED_SKILLS} skills can be active at once. Swap them to match the boss you're facing. Press TAB to close.</p>
      ${rows || '<i>No skills learned yet.</i>'}
      <p style="opacity:.75">Summoning Scrolls: ${player.scrolls.length ? player.scrolls.join(', ') : 'none yet — defeat bosses to earn them.'}</p>`;
    root.querySelectorAll('button').forEach((b) => {
      b.onclick = () => {
        const id = b.dataset.id;
        try {
          if (player.skills.includes(id)) unequipSkill(player, id);
          else equipSkill(player, id);
        } catch (e) { alert(e.message); }
        render();
      };
    });
  }
  return {
    get open() { return !root.hidden; },
    toggle() { root.hidden = !root.hidden; if (!root.hidden) render(); },
  };
}
