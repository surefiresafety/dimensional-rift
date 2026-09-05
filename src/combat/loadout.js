// Skill loadout management: The Rule of Four.
import { MAX_EQUIPPED_SKILLS, getSkill } from './skills.js';

export function learnSkill(c, skillId) {
  getSkill(skillId);
  if (!c.learnedSkills.includes(skillId)) c.learnedSkills.push(skillId);
  if (!c.skills.includes(skillId) && c.skills.length < MAX_EQUIPPED_SKILLS) c.skills.push(skillId);
  return c;
}

/** Equip a learned skill, optionally replacing the one in `slot`. */
export function equipSkill(c, skillId, slot = null) {
  if (!c.learnedSkills.includes(skillId)) throw new Error(`${c.name} hasn't learned ${skillId}`);
  if (c.skills.includes(skillId)) return c;
  if (slot !== null) {
    if (slot < 0 || slot >= MAX_EQUIPPED_SKILLS) throw new Error('Invalid slot');
    c.skills[slot] = skillId;
    return c;
  }
  if (c.skills.length >= MAX_EQUIPPED_SKILLS) {
    throw new Error(`Only ${MAX_EQUIPPED_SKILLS} skills can be equipped. Choose one to replace.`);
  }
  c.skills.push(skillId);
  return c;
}

export function unequipSkill(c, skillId) {
  c.skills = c.skills.filter((s) => s !== skillId);
  return c;
}
