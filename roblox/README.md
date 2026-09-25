# Dimensional Rift for Roblox

The Roblox rebuild of the 3D browser game in `web3d/rift3d.html`. The game's design
data is exported from the web build rather than retyped, the combat rules are ported
line for line and tested against the web build's numbers, and there is a playable
first slice: pick a character, fight waves, use your five techniques and your
ultimate.

> **Status:** everything here builds, lints, formats and passes its tests outside
> Studio. **None of it has been run inside Roblox Studio yet.** Expect a first
> session of small fixes. See *What was checked* below.

## Before you publish: the characters are someone else's

Naruto, Jujutsu Kaisen and Marvel characters are owned by Shueisha/Viz, Shueisha/
MAPPA and Disney. A Roblox experience that uses their names, likenesses and
technique names can be taken down under Roblox's Terms of Use and by DMCA notices,
and rightsholders do file them against anime battleground games. Building and
testing privately is fine. Before you publish, decide on original names and looks.
The popular battleground games use characters *inspired by* a series with different
names (a "Hero Hunter", not a named hero). Names and looks all come from
`web3d/rift3d.html` through the exporter, so you rename them in one place.

## Opening it

**The quick way:** open `build/DimensionalRift.rbxlx` in Roblox Studio and press Play.
To regenerate it, run `npm run build:roblox` from the repo root (needs Rojo).

**The way to keep working on it** is [Rojo](https://rojo.space), which syncs these
files into Studio as you edit:

```bash
cd roblox
rokit install          # installs rojo, selene, stylua and lune at the versions in rokit.toml
rojo serve             # then, in Studio: Plugins > Rojo > Connect
```

## Layout

| Path | In Roblox | What it is |
| --- | --- | --- |
| `src/shared/Data/*.luau` | `ReplicatedStorage.Shared.Data` | **Generated** by `npm run export:roblox`. Every technique, character, enemy, boss and world. Do not edit these by hand. |
| `src/shared/Rules.luau` | `ReplicatedStorage.Shared.Rules` | The combat maths: the nature wheel, damage, armour, crits, cost, cooldowns, status effects, waves. No Roblox APIs, so it runs under Lune. |
| `src/shared/Config.luau` | | Roblox-only tuning. Holds `STUDS_PER_UNIT = 2.4`, the conversion from web-build units to studs. |
| `src/shared/Progression.luau` | | What a player keeps: levels, Rift Shards, the roster, loadouts, the daily streak, quests, best waves. No Roblox APIs, so it runs under Lune. |
| `src/shared/Remotes.luau` | | The eight RemoteEvents, the one RemoteFunction (`Ask`), and what each carries. |
| `src/shared/Signature.luau` | | The E key for the characters whose signature is a technique. |
| `src/server/` | `ServerScriptService.Server` | `Combat` (state, hitting enemies and players), `Abilities` (one handler per technique type, the basic attack, output charge), `Symbiote` (suit, hunger, bond, detaching), `Projectiles` (swept hits), `Enemies` (spawning and AI), `Waves` (and the world rotation), `World` (lighting and a placeholder arena), `Looks` (bodies and hair), `ProfileStore` and `Profiles` (saving), `Progress` (rewards, quests, unlocks, boards, badges). |
| `src/client/` | `StarterPlayerScripts.Client` | `Hud`, `Select` (character select with universe filters, search, locks and unlocking), `Hub` (the J menu), `Loadout` (L), `Profile` (the client's copy of its progress), `Fx` (draws what the server reports), `Input`, `TouchPad` (phones), `Movement` (web-swing and flight). |
| `tests/` | | Lune tests: `lune run tests/run` (or `npm run test:roblox`). |

## How it fits together

- **The server decides everything.** A client sends only *which slot* and *which
  direction it is aiming*. The server checks cooldowns, spends Spirit Energy, finds
  what was hit and deals the damage. It limits casts to about 12 a second per player,
  accepts an E cast only if it is that character's own, and only accepts a short
  direction vector with finite values.
- **The client draws.** Projectiles are replayed from the start position and velocity
  the server used. Damage numbers, rings, beams, slashes and domains come in as `Fx`
  events.
- **Movement is the one exception.** The client already controls its own character's
  physics in Roblox, so web-swinging (a real `RopeConstraint` on an anchor found by the
  web build's fan of rays) and flight (a `LinearVelocity`) run on the client.
- **Units.** The data stays in web-build units and is scaled by `STUDS_PER_UNIT` where
  it is used. Change it in one place.

## What is ported

| | |
| --- | --- |
| Characters | All 46, with their five techniques, pools, passives' numbers, energy and ultimates |
| Technique types | All 21, so all 282 techniques can be cast: projectile, melee, dash, beam, trap, pull, yank, teleport, buff, heal, shield, evade, freeze, clones, domain, toggle, self (decoy), rewind (Reverse Time), switch (weapon and suit sets), possess (Body Swap), devour (Feed) |
| Basic attack | Left click (or the Hit button, or R2). The style's own m1 and reach, Yuji's Black Flash chance, or the drawn weapon's m1, knockback, armour piercing and soul cut |
| Weapon and suit sets | Toji, Maki, Iron Man and Top Hat switch with the technique in their slot, Yuji with R. The drawn one changes the basic attack and scales every technique marked `weaponScaled` (damage, cost, cooldown, reach, knockback, barrier breaking, the chain's pull, the soul cut) |
| Output charge | Hold B: a tap is Minimum Output, 5 s Medium, 10 s Maximum, which also blasts everything within 14 units. The next technique spends it |
| The symbiote | Suit health and its regeneration, hunger (it gets hungrier, says so, and hits harder the hungrier it is), Feed, the takeover when hunger hits zero (it transforms and feeds itself until it is over 55), the bond (fire and sound strip it, starving strips it, time alone restores it), coming off at zero bond, F to put it back on within a minute, Ironthread if you do not |
| Ultimates | All technique ultimates, plus the Venom / Anti-Venom / Sukuna transforms and Mahoraga |
| Combat rules | Nature wheel, armour, defence-down, buffs, lifesteal (including Berserker Rage's), crits and their ramp, knockback, enrage, burn/poison/bleed, root/paralyse/webbed/stun, shields with reflect and heal, Infinity, evasion |
| Enemies | All 118, including the 46 character bosses and 32 alphas, with melee, ranged bursts and arcs, summons and enrage |
| Worlds | All 9 worlds' waves, boss ladders and filler, their lighting and fog, and a placeholder skyline |
| Screens | HUD (health, energy, a status line for the drawn weapon, stored charge, suit, hunger and bond, ability rail with cooldowns, wave, log, banner) and Select Character |
| Controls | Left click (basic attack), 1–5, G, E (signature), Q (dodge), B (hold to charge), R (Yuji's weapons), F (put the symbiote back on), J (menu), L (loadout), M (characters). Gamepad: R2 hit, L2 signature, Y ultimate, X dodge, B charge. Phones get a touch pad with cooldowns. |

## The fight

| | |
| --- | --- |
| Enemies notice you | Every wave arrives spread over the arena in small packs, out of sight. An enemy wanders near where it arrived until a player comes within `Config.ENEMY_NOTICE` (18 units, about 43 studs; 26 for bosses), it is hit, or a packmate nearby spots someone. A "!" pops over it. Past `ENEMY_LEASH` (60 units) it gives up. All in `Rules.aiStep`, tested branch by branch. |
| Every attack is announced | A pulsing ring under the enemy before it lands: red a swing (0.7 s, bosses 0.9 s), yellow a shot, orange a charge. A stun cancels it, and a swing is followed by a recovery to punish. |
| Dodge | Q (X on a gamepad, DODGE on phones): a quick dash, untouchable for 0.4 s, 1.1 s cooldown. |
| Elites | From wave 3 some enemies are Frenzied, Armored, Giant, Vampiric or Volatile (explodes when it dies), outlined in colour: double experience and guaranteed shards. |
| Drops | Health, Spirit Energy and Rift Shard orbs that drift to you. |
| Combos | Hits within 3 s chain, ranked D to SSS on the HUD, and pay out experience and shards when they end. |
| Radar | Enemies within 70 units: yellow unaware, red hunting, bosses bigger. A boss hunting you gets a health bar across the top. |
| Worlds | Nine themed arenas built from parts and terrain (`Arenas.luau`): a neon Times Square at night, a burning ruin, two temple academies, a star tomb, a desert, rock country, islands and a thunderstorm, each with weather, cover, a skyline, things to swing from and the rift portal. |
| Feel | Enemies animate (Roblox's default R15 set), topple and fade when they die; sounds for hits, casts, warnings and level-ups (`Config.SOUNDS`); camera shake; a down screen; a countdown between waves; a report when a world is cleared. Music per world in `Config.MUSIC` (empty until you paste ids). |

## Keeping players coming back

Everything below is saved per player in a DataStore (`RiftProfiles_v1`) and checked
by the server; clients only ever ask.

| | |
| --- | --- |
| Saving | Loaded on join, saved every 90 s, on leaving and on shutdown. A session lock stops two servers writing the same player: a second server waits up to a minute for the first to let go and never forces a live lock (a player still held is asked to rejoin), takes over a lock untouched for five minutes (its server is gone), and a server that lost the lock can never overwrite newer progress. Saves for one player never overlap, and nothing is written after the save on leaving. Failed reads and writes are retried. In Studio without API access it falls back to memory and says so; a live server never does. |
| Levels and Rift Shards | Experience and shards from every kill (more for alphas, story bosses and character bosses), every wave cleared and every world cleared (much more the first time). Each level pays shards. |
| The roster | Six starters from all three universes (Threadrunner, Ren Tsumuji, Kurobane, Haru Takane, Kage Inukai, Hammer Maiden). Everyone else joins when you beat their boss in the rift, or for 350 Rift Shards (900 for the ten premium characters). Locked cards say how to win them. "Continue as …" puts you straight back in as your last character. |
| Absorbed techniques and loadouts | Techniques absorbed from enemies are kept, and the loadout screen (L) puts any of them in any character's five slots. Saved per character. |
| Daily reward | A seven-day calendar that grows every day in a row (day 7 is the big one) and starts again after a missed day. The menu opens on it when one is waiting. |
| Daily quests | Three a day, the same for a player on every server that day, from eight kinds (defeat enemies, alphas and bosses, clear waves, use techniques, land Black Flashes, deal damage, basic attacks, charged techniques). One swap a day for 25 shards. A red dot on MENU when something can be claimed. |
| Worlds | Clearing a world's last wave (its boss ladder) moves everyone through the rift to the next world and opens it for travel from the menu's Worlds tab. Best wave per world is kept. |
| Upgrades | Five permanent upgrades bought with shards, for every character: Vitality, Power, Spirit, Swiftness, Fortune, each level dearer than the last. |
| First run | Six tips that move on as the new player does each thing, then never again. |
| Global boards | Best wave and total experience, top ten, in the menu (OrderedDataStores). |
| Badges | Seven: first visit, first character boss, first world cleared, levels 10 and 25, a seven-day streak, fifteen characters. Create them on the Creator Dashboard and paste the ids into `Config.BADGES`; an id of 0 is skipped. |
| Friends | +10% experience for each friend on the same server, up to three. |
| Stats | Kills, bosses, waves, worlds, techniques, crits, damage, best combo, time played, per-world bests, in the menu. |
| Player list and names | `leaderstats` shows Level and Best Wave; the name over each player's head shows their level. |

## What is not ported yet

Rough priority order:

1. **The symbiote's voice** goes to the combat log rather than a speech bubble.
2. **The Shadow Clone army.** Multi Shadow Clone makes its usual three to five
   helpers; the charged 1,000 / 5,000 / 10,000 army needs a cheaper kind of minion
   than a humanoid first.
3. **A body for the decoy and for Body Swap.** Shadow Clone's decoy works (it takes
   the next hit) but has no second body on screen, and a worn enemy keeps its own
   look.
4. **Hand-built arenas.** `Arenas` builds each world from parts and terrain. A Model
   named after a map id (`times_square`, `jujutsu_high`, …) under
   `ServerStorage.Maps` replaces the built one automatically.
5. **Music.** `Config.MUSIC` is empty: paste Creator Store sound ids per world.
6. **Looks.** Bodies are R15 in each character's colours with a hair shape made from
   parts. For real hair and clothes, put catalog asset ids in `Looks.ACCESSORIES`. The
   select screen shows colour strips rather than spinning 3D previews (`ViewportFrame`
   is the next step).
7. **Enemy shapes.** Toads, blobs, wraiths, golems and imps are a body shape over a
   hidden R15 walker. It works, but proper models or MeshParts would look better.
8. **Conditions.** In the web build a run sometimes rolls a random event. The first
   one is Visitors: a UFO tries to abduct you. The two greys, the craft, and the
   Abduction Ray and Probe Pistol they drop are already in the exported data. The
   craft's behaviour (tracking, warning, beam, lift, abduction) is not ported yet.
9. **Multiplayer modes.** Co-op works by default: everyone on a server shares the
   waves. Versus does not exist yet.
10. **The Visitors' craft** walks like a person.
11. **Perfect dodges.** The web build rewards a dodge made during Spider-Sense;
    the Roblox dodge does not yet.
12. **Monetisation.** No game passes or developer products. Shards are earned only.

## Keeping the two builds in step

The web build is still the source of truth for design. After changing a technique,
character or enemy there:

```bash
npm run export:roblox   # rewrites roblox/src/shared/Data
npm test                # fails if you forget: test/roblox-export.test.js compares a fresh export
npm run test:roblox     # the Luau rules and data checks
```

## What was checked

- `rojo build` produces the place file.
- `stylua --check` passes on all hand-written code.
- `luau-lsp analyze` (1.70.0) type-checks every script in strict mode against
  Roblox's full API definitions: no errors, no warnings. It catches misspelled
  properties and deprecated calls; it caught one of each here.

  ```bash
  rojo sourcemap default.project.json -o sourcemap.json
  luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions @roblox=globalTypes.d.luau src
  ```

  `globalTypes.d.luau` comes from the luau-lsp repository (`scripts/`).
- 65 Lune tests pass. They check the ported rules against the web build's own formulas
  (damage over time matches to the point over several seconds at 60 fps), check
  that every exported reference resolves, check the progression rules (levels,
  rewards, the streak across a missed day, quests, loadouts, unlocks), and run the
  save system against a fake DataStore (a live lock waited on and never forced, a
  dead one taken, a last save landing while the next server waits, a server that
  lost its lock refused, a store that keeps failing, an old save repaired).
- The repo's node suite, including the export freshness test.

**Not checked:** anything that needs the Roblox engine to be running: physics, the
humanoid AI, networking, how the HUD looks, and the swing's feel. That needs one play
session in Studio.
