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
| `src/shared/Remotes.luau` | | The six RemoteEvents and what each carries. |
| `src/shared/Signature.luau` | | The E key for the characters whose signature is a technique. |
| `src/server/` | `ServerScriptService.Server` | `Combat` (state, hitting enemies and players), `Abilities` (one handler per technique type), `Projectiles` (swept hits), `Enemies` (spawning and AI), `Waves`, `World` (lighting and a placeholder arena), `Looks` (bodies and hair). |
| `src/client/` | `StarterPlayerScripts.Client` | `Hud`, `Select` (character select with universe filters and search), `Fx` (draws what the server reports), `Input`, `Movement` (web-swing and flight). |
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
| Technique types | 16 of 21, which covers 272 of the 280 techniques: projectile, melee, dash, beam, trap, pull, yank, teleport, buff, heal, shield, evade, freeze, clones, domain, toggle |
| Ultimates | All technique ultimates, plus the Venom / Anti-Venom / Sukuna transforms and Mahoraga |
| Combat rules | Nature wheel, armour, defence-down, buffs, lifesteal (including Berserker Rage's), crits and their ramp, knockback, enrage, burn/poison/bleed, root/paralyse/webbed/stun, shields with reflect and heal, Infinity, evasion |
| Enemies | All 116, including the 46 character bosses and 32 alphas, with melee, ranged bursts and arcs, summons and enrage |
| Worlds | All 9 worlds' waves, boss ladders and filler, their lighting and fog, and a placeholder skyline |
| Screens | HUD (health, energy, ability rail with cooldowns, wave, log, banner) and Select Character |
| Controls | 1–5, G, E / right mouse (signature), M. ContextActionService also adds touch buttons for phones. |

## What is not ported yet

Rough priority order:

1. **Five technique types.** 7 equipped techniques use them and say "not in the Roblox
   build yet" when cast. `switch` (Toji, Maki, Iron Man and Top Hat's weapon and suit
   sets, with `Data/Arsenals`), `rewind` (Sasuke's Reverse Time), `possess` (Kenjaku),
   `devour` (Venom's Feed) and `self` (a decoy).
2. **The symbiote systems:** suit health, hunger, bond, the takeover at under 100 HP,
   detaching, the lines of text, auto-tendrils (R), Doc Ock's arms.
3. **Output charge (B)** and the Shadow Clone army. Ability handlers already take the
   multiplier (`B`); nothing sets it yet.
4. **The real arenas.** `World` builds a ring of blocks. Build each world in Studio as
   a Model named after its map id (`times_square`, `jujutsu_high`, …) under
   `ServerStorage.Maps`, and it replaces the placeholder automatically.
5. **Gates between worlds (Q), the world map (N) and the loadout screen (Tab).**
   Absorbed techniques are recorded (`learned`) but cannot be slotted yet.
6. **Looks.** Bodies are R15 in each character's colours with a hair shape made from
   parts. For real hair and clothes, put catalog asset ids in `Looks.ACCESSORIES`. The
   select screen shows colour strips rather than spinning 3D previews (`ViewportFrame`
   is the next step).
7. **Enemy shapes.** Toads, blobs, wraiths, golems and imps are a body shape over a
   hidden R15 walker. It works, but proper models or MeshParts would look better.
8. **Multiplayer modes.** Co-op works by default: everyone on a server shares the
   waves. Versus does not exist yet.
9. **Saving** (DataStoreService): unlocked techniques and progress.

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
- `luau-lsp analyze` type-checks every script against Roblox's API definitions, in
  strict mode.
- 22 Lune tests pass. They check the ported rules against the web build's own formulas
  (damage over time matches to the point over several seconds at 60 fps), and check
  that every exported reference resolves.
- The repo's node suite, including the export freshness test.

**Not checked:** anything that needs the Roblox engine to be running: physics, the
humanoid AI, networking, how the HUD looks, and the swing's feel. That needs one play
session in Studio.
