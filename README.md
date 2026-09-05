# Dimensional Rift

A 2D top-down, turn-based RPG prototype. A portal opens over New York and pulls the
player into a multiverse collapse spanning **New York City**, the **Hidden Leaf
Village** and **Jujutsu High**. Pokémon-style exploration and collection, with the
combat systems of *Naruto*, *Jujutsu Kaisen* and *Marvel's Spider-Man*.

No build step, no dependencies. Plain HTML + ES modules.

```bash
npm start          # http://localhost:8080  (play the 15-minute tutorial)
npm test           # 19 combat-engine tests (node --test)
npm run export:rpgmaker   # build/rpgmaker/*.json for an RPG Maker MZ project
```

Controls: **Arrows / WASD** move · **Space / Enter / E** interact · **Tab** skill loadout.

## What's here

| Path | What it is |
| --- | --- |
| `src/combat/natures.js` | The Chakra Nature wheel (Fire > Wind > Lightning > Earth > Water > Fire). 2x on weakness, 0.5x on resistance. |
| `src/combat/skills.js` | Every Jutsu, Cursed Technique and Spider-Man gadget, all priced in **Spirit Energy**. `MAX_EQUIPPED_SKILLS = 4` (the Rule of Four). |
| `src/combat/status.js` | Crowd control: Rooted, Paralyzed, Webbed, Poisoned, Burned, Evasive (Sharingan / Spider-Sense), Shadow-Clone decoy, Guard; stat stages. |
| `src/combat/summons.js` | Summoning Contracts (Kuchiyose): Divine Dogs, Ninja Hounds, Gamabunta, Kurama, Mahoraga. Unlocked by beating the matching boss. |
| `src/combat/entities.js` | Roster: player, guest allies (Kakashi, Spider-Man, Gojo), enemies and bosses. Enemies carry an `absorbable` skill the player copies on defeat. |
| `src/combat/battle.js` | The turn engine: speed order, damage formula, matchup multipliers, statuses, guest follow-ups, summons, items, run, Mahoraga adaptation, power absorption. |
| `src/combat/loadout.js` | Learn / equip / unequip skills under the Rule of Four. |
| `src/game/` | The playable tutorial: overworld, dialogue, battle UI, skills menu, scene script. |
| `docs/DESIGN.md` | The full design: type chart, copy system, Spirit Energy, summons, Spider-Man HMs, status effects. |
| `docs/TUTORIAL_SCRIPT.md` | The minute-by-minute opening (0–15 min) as implemented. |
| `tools/export-rpgmaker.js` | Converts skills, summons, enemies and the element chart into RPG Maker MZ data shapes. |
| `test/` | Engine tests, including a 50-seed replay of the tutorial fight. |

## Using the engine on its own

```js
import { createBattle, spawn, createRng, learnSkill } from './src/combat/index.js';

const player = spawn('player');
learnSkill(player, 'web_stun');
const battle = createBattle({ player, allies: [spawn('kakashi')], enemies: [spawn('cursed_toad')], rng: createRng(7) });

battle.act({ type: 'attack' });                 // barely scratches it
battle.act({ type: 'skill', skill: 'web_stun' }); // roots it, lowers DEF, Kakashi follows up with Chidori
battle.result; // { outcome: 'win', absorbed: ['acid_spit'], scrolls: [] }
```

Actions: `{type:'attack'}`, `{type:'skill', skill}`, `{type:'summon', summon}`, `{type:'item', item}`,
`{type:'guard'}`, `{type:'run'}`. Every `act()` resolves a full round and returns the events
(`move`, `damage`, `status`, `stage`, `dodge`, `follow-up`, `absorb`, `scroll`, `end`, ...) so any
front end can render them.
