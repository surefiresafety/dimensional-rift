// Dimensional Rift — tutorial prototype orchestrator.
// Minute 0-3  bedroom: interaction tutorial (TV news, door)
// Minute 3-7  Times Square: meet Spider-Man, receive Web-Shooter (Web-Stun)
// Minute 7-10 portal -> Konoha training grounds, meet Kakashi
// Minute 10-15 tutorial fight vs Cursed Toad, absorb Acid Spit
import { SCENES, DIALOGUE, ENCOUNTERS } from './script.js';
import { createOverworld } from './overworld.js';
import { createDialogue } from './dialogue.js';
import { createBattleUI } from './battle-ui.js';
import { createSkillsMenu } from './skills-menu.js';
import { spawn } from '../combat/entities.js';
import { learnSkill } from '../combat/loadout.js';
import { createRng } from '../combat/rng.js';

const $ = (sel) => document.querySelector(sel);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const rng = createRng(Date.now() % 100000);
const player = spawn('player');
const flags = { sawNews: false, webShooter: false, toadBeaten: false, hokage: false };
let sceneId = null;
let busy = false;

const world = createOverworld({ canvas: $('#map'), hud: $('#hud') });
const dialogue = createDialogue({ root: $('#dialogue'), onFlag: (f) => { if (f === 'webShooter') { learnSkill(player, 'web_stun'); updateHud(); toast('Skill Unlocked: Web-Stun'); } } });
const battleUI = createBattleUI({ root: $('#battle') });
const skillsMenu = createSkillsMenu({ root: $('#skills-menu'), player });

function toast(text, ms = 2200) {
  const t = $('#toast'); t.textContent = text; t.hidden = false;
  setTimeout(() => { t.hidden = true; }, ms);
}
async function fade(on) {
  const f = $('#fade'); f.classList.remove('flash'); f.classList.toggle('on', on); await sleep(550);
}
async function flash() {
  const f = $('#fade'); f.classList.add('flash'); f.classList.add('on'); await sleep(120); f.classList.remove('on'); await sleep(200); f.classList.remove('flash');
}
function updateHud() {
  world.setHud(`HP ${player.hp}/${player.maxHp}   Spirit Energy ${player.se}/${player.maxSe}   Skills: ${player.skills.length ? player.skills.join(', ') : '(none)'}`);
}

async function goto(id, start = null) {
  await fade(true);
  sceneId = id;
  world.load(SCENES[id], start);
  updateHud();
  await fade(false);
  if (SCENES[id].intro && !flags[`intro_${id}`]) { flags[`intro_${id}`] = true; await dialogue.show(SCENES[id].intro); }
}

async function startBattle(enemyIds, { allies = [], tutorial = false } = {}) {
  const enemies = enemyIds.map((id) => spawn(id));
  await flash();
  const result = await battleUI.run({ player, allies, enemies, rng, tutorial });
  if (result.outcome === 'lose') {
    player.hp = player.maxHp; player.se = player.maxSe;
    for (const k of Object.keys(player.statuses)) delete player.statuses[k];
    await dialogue.show([{ speaker: '', text: 'You black out... and wake up back at the training posts, fully healed. Try a different strategy!' }]);
  }
  // Statuses and stat stages reset after a battle.
  for (const k of Object.keys(player.statuses)) delete player.statuses[k];
  player.stages = { atk: 0, def: 0, spd: 0 };
  updateHud();
  world.draw();
  return result;
}

// --- Scene interaction handlers -------------------------------------------

async function interact() {
  const t = world.facingTile();
  if (sceneId === 'bedroom') {
    if (t.ch === 'P') { flags.sawNews = true; await dialogue.show(DIALOGUE.news); }
    else if (t.ch === 'W') await dialogue.show([{ speaker: 'You', text: 'The whole sky is glitching purple. That can\'t be good.' }]);
  } else if (sceneId === 'nyc') {
    if (t.ch === 'S' && !flags.webShooter) {
      await dialogue.show(DIALOGUE.spidey);
      await flash(); await flash();
      await goto('konoha');
      await konohaOpening();
    } else if (t.ch === 'X') await dialogue.show([{ speaker: 'Spider-Man', text: 'Don\'t touch that! Talk to me first, kid.' }]);
    else if (t.ch === 'C') await dialogue.show([{ speaker: '', text: 'An abandoned car. The engine is still warm.' }]);
  } else if (sceneId === 'konoha') {
    if (t.ch === 'T') await dialogue.show([{ speaker: '', text: 'A wooden training post, covered in kunai marks.' }]);
    else if (t.ch === 'B') await dialogue.show(DIALOGUE.boulder);
    else if (t.ch === 'K') await dialogue.show([{ speaker: 'Kakashi', text: 'The Hokage\'s office is to the north-east. Don\'t wander into the tall grass unprepared.' }]);
  }
}

async function konohaOpening() {
  await dialogue.show(DIALOGUE.konohaWake);
  world.setTile(world.player.x + 3, world.player.y, 'K');
  const kakashi = spawn('kakashi');
  const result = await startBattle(['cursed_toad'], { allies: [kakashi], tutorial: true });
  if (result.outcome === 'win') {
    flags.toadBeaten = true;
    await dialogue.show(DIALOGUE.afterToad);
  } else {
    await konohaOpening();
  }
}

async function onStep(step) {
  if (sceneId === 'bedroom' && step.tile === 'D') {
    if (!flags.sawNews) { world.move('up'); await dialogue.show(DIALOGUE.doorLocked); return; }
    await goto('nyc');
  } else if (sceneId === 'konoha') {
    if (step.tile === 'H' && !flags.hokage) { flags.hokage = true; await dialogue.show(DIALOGUE.hokage); }
    else if (step.tile === 'E') {
      if (!flags.encounterHint) { flags.encounterHint = true; await dialogue.show(DIALOGUE.encounterHint); }
      if (rng.chance(0.3)) await startBattle([rng.pick(ENCOUNTERS)]);
    }
  }
}

async function onBlocked(step) {
  if (sceneId === 'konoha' && step.tile === 'G') {
    if (!player.learnedSkills.includes('web_stun')) { await dialogue.show(DIALOGUE.gapNoWeb); return; }
    await dialogue.show(DIALOGUE.gap);
    const dir = step.y > world.player.y ? 'down' : 'up';
    world.setTile(step.x, step.y, ','); world.move(dir); world.move(dir); world.setTile(step.x, step.y, 'G');
  }
}

// --- Input ------------------------------------------------------------------

const KEYS = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right', w: 'up', s: 'down', a: 'left', d: 'right', W: 'up', S: 'down', A: 'left', D: 'right' };
document.addEventListener('keydown', async (ev) => {
  if (ev.key === 'Tab') { ev.preventDefault(); if (!busy && !dialogue.active && flags.toadBeaten) skillsMenu.toggle(); return; }
  if (skillsMenu.open) return;
  if (dialogue.active) { if ([' ', 'Enter', 'e', 'E'].includes(ev.key)) { ev.preventDefault(); dialogue.advance(); } return; }
  if (busy || !$('#battle').hidden) return;
  if ([' ', 'Enter', 'e', 'E'].includes(ev.key)) { ev.preventDefault(); busy = true; try { await interact(); } finally { busy = false; } return; }
  const dir = KEYS[ev.key];
  if (!dir) return;
  ev.preventDefault();
  busy = true;
  try {
    const step = world.move(dir);
    if (step.moved) await onStep(step); else await onBlocked(step);
  } finally { busy = false; }
});

// --- Boot -------------------------------------------------------------------
goto('bedroom');
