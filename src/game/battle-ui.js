// DOM battle screen driving the combat engine.
import { createBattle } from '../combat/battle.js';
import { NATURE_INFO } from '../combat/natures.js';
import { STATUS_INFO } from '../combat/status.js';

const STEP_MS = 420;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function createBattleUI({ root }) {
  const enemiesEl = root.querySelector('#enemies');
  const partyEl = root.querySelector('#party');
  const logEl = root.querySelector('#log');
  const menuEl = root.querySelector('#menu');
  const hintEl = root.querySelector('#tutorial-hint');

  function card(c) {
    const cls = c.side === 'enemy' ? 'enemy' : c.side === 'ally' ? 'ally' : 'player';
    const nat = c.nature ? `${NATURE_INFO[c.nature].icon} ${NATURE_INFO[c.nature].label}` : '';
    const statuses = Object.keys(c.statuses).map((s) => `${STATUS_INFO[s]?.icon ?? ''}${STATUS_INFO[s]?.label ?? s}`).join(' ');
    const stages = Object.entries(c.stages).filter(([, v]) => v !== 0).map(([k, v]) => `${k.toUpperCase()} ${v > 0 ? '+' : ''}${v}`).join(' ');
    const se = c.maxSe > 0 && c.side === 'player' ? `<div class="bar se"><i style="width:${(100 * c.se) / c.maxSe}%"></i></div><div>Spirit Energy ${c.se}/${c.maxSe}</div>` : '';
    return `<div class="card ${cls}" data-id="${c.id}">
      <div class="name">${c.name} <small>Lv${c.level} ${nat}</small></div>
      <div class="bar"><i style="width:${(100 * c.hp) / c.maxHp}%"></i></div>
      <div>HP ${c.hp}/${c.maxHp}</div>${se}
      <div class="statuses">${statuses} ${stages}</div>
    </div>`;
  }

  function render(state) {
    enemiesEl.innerHTML = state.enemies.map(card).join('');
    partyEl.innerHTML = [state.player, ...state.allies].map(card).join('');
  }

  function log(text, cls = '') {
    const d = document.createElement('div');
    d.className = cls; d.textContent = text;
    logEl.appendChild(d);
    logEl.scrollTop = logEl.scrollHeight;
  }

  function hint(text) {
    hintEl.textContent = text; hintEl.hidden = !text;
  }

  async function playEvents(events, state) {
    for (const e of events) {
      const cls = { round: 'round', absorb: 'gold', scroll: 'gold', end: 'gold', damage: e.target === state.player.id ? 'bad' : '', dodge: 'good', 'follow-up': 'good', status: e.target === state.player.id ? 'bad' : 'good', stage: e.target === state.player.id ? '' : 'good' }[e.type] ?? '';
      log(e.text, cls);
      render(state);
      if (e.type === 'damage') {
        const el = root.querySelector(`.card[data-id="${e.target}"]`);
        el?.classList.add('hit');
      }
      if (e.type === 'absorb') root.querySelector(`.card[data-id="${state.player.id}"]`)?.classList.add('glow');
      if (e.type !== 'round') await sleep(STEP_MS);
    }
  }

  function menuButtons(items, onPick) {
    menuEl.innerHTML = '';
    for (const it of items) {
      const b = document.createElement('button');
      b.innerHTML = `${it.label}${it.sub ? `<small>${it.sub}</small>` : ''}`;
      b.disabled = Boolean(it.disabled);
      if (it.pulse) b.classList.add('pulse');
      b.onclick = () => onPick(it);
      menuEl.appendChild(b);
    }
  }

  /** Ask the player for an action. Resolves with an engine action. */
  function chooseAction(battle, tutorial) {
    const opts = battle.options();
    return new Promise((resolve) => {
      const main = () => {
        menuEl.className = '';
        menuButtons([
          { label: '👊 Attack', sub: 'Strike', pulse: tutorial?.step === 'attack', action: { type: 'attack' } },
          { label: '✨ Skill', sub: `${opts.skills.length} equipped`, pulse: tutorial?.step === 'skill', disabled: !opts.skills.length, action: 'skills' },
          { label: '🎒 Item', sub: `${opts.items.length} kinds`, disabled: !opts.items.length, action: 'items' },
          { label: '🏃 Run', sub: opts.run ? '' : 'Boss!', disabled: !opts.run, action: { type: 'run' } },
          { label: '📜 Summon', sub: `${opts.summons.length} scrolls`, disabled: !opts.summons.length, action: 'summons' },
          { label: '🛡️ Guard', sub: 'Halve damage', action: { type: 'guard' } },
        ], (it) => {
          if (it.action === 'skills') sub(opts.skills.map((s) => ({ label: `${NATURE_INFO[s.nature].icon} ${s.name}`, sub: `${s.cost} SE · ${s.desc}`, disabled: !s.affordable, pulse: tutorial?.step === 'skill' && s.id === 'web_stun', action: { type: 'skill', skill: s.id } })));
          else if (it.action === 'items') sub(opts.items.map((i) => ({ label: i.name, sub: `x${i.count} · ${i.desc}`, action: { type: 'item', item: i.id } })));
          else if (it.action === 'summons') sub(opts.summons.map((s) => ({ label: `${NATURE_INFO[s.nature].icon} ${s.name}`, sub: `${s.cost} SE · ${s.desc}`, disabled: !s.affordable, action: { type: 'summon', summon: s.id } })));
          else resolve(it.action);
        });
      };
      const sub = (items) => {
        menuEl.className = 'sub';
        menuButtons([...items, { label: '← Back', action: 'back' }], (it) => (it.action === 'back' ? main() : resolve(it.action)));
      };
      main();
    });
  }

  /**
   * Run a full battle. `tutorial` enables the scripted hints for the first fight.
   * Resolves with the battle result.
   */
  async function run({ player, allies = [], enemies = [], rng, tutorial = false }) {
    const battle = createBattle({ player, allies, enemies, rng });
    root.hidden = false;
    root.classList.add('shatter');
    logEl.innerHTML = '';
    menuEl.innerHTML = '';
    render(battle.state);
    log(`${enemies.map((e) => e.name).join(', ')} appeared!`, 'gold');
    const tut = tutorial ? { step: 'attack' } : null;
    if (tut) hint('Tutorial: try a normal Attack first.');
    await sleep(600);
    root.classList.remove('shatter');

    while (!battle.result) {
      const action = await chooseAction(battle, tut);
      hint('');
      menuEl.innerHTML = '';
      const events = battle.act(action);
      await playEvents(events, battle.state);
      if (tut && tut.step === 'attack' && action.type === 'attack') {
        tut.step = 'skill';
        log('Your attacks barely scratch it! Open SKILL and use Web-Stun.', 'gold');
        hint('Your attack did almost nothing! Use a SKILL → Web-Stun.');
      } else if (tut && action.type === 'skill') {
        tut.step = null;
      }
    }
    await sleep(500);
    hint('');
    root.hidden = true;
    return battle.result;
  }

  return { run };
}
