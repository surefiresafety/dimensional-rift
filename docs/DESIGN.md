# Dimensional Rift — Design

**Genre:** 2D top-down turn-based RPG.
**Concept:** A crossover adventure through portals connecting New York City, the Hidden Leaf
Village and Jujutsu High. Pokémon exploration and collection meets the combat and magic systems
of *Jujutsu Kaisen*, *Naruto* and *Marvel*.

**Plot:** A mysterious portal opens in New York and pulls the player into a multiverse collapse.
Guided at first by Spider-Man, the player discovers they can absorb and copy powers from other
dimensions. They travel between worlds, team up with mentors (Kakashi, Gojo) and defeat rogue
enemies to seal the rifts. The villain behind it is Mahito fused with Orochimaru.

---

## 1. Chakra Natures — the type matchup wheel

Every Naruto jutsu and every JJK cursed technique is mapped onto one of five natures, so the two
universes share a single rock-paper-scissors wheel.

| Nature | Beats | Weak to | Examples |
| --- | --- | --- | --- |
| 🔥 Fire | Wind | Water | Jogo's Disaster Flames, Uchiha Fireball, Kurama |
| 🌪️ Wind | Lightning | Fire | Sukuna's Cleave / Dismantle, Rasenshuriken, Rasengan |
| ⚡ Lightning | Earth | Wind | Kashimo's Energy, Chidori |
| 🪨 Earth | Water | Lightning | Hanami's Roots, Mud Wall, Divine Dogs |
| 💧 Water | Fire | Earth | Dagon's Domain, Water Dragon, Gamabunta, Acid Spit |

* Hitting a weakness deals **2x**. Hitting a resistance deals **0.5x**. Anything else is neutral.
* **Physical** (Strike, webs, shuriken) and **Cursed** (Black Flash, Mahoraga) sit outside the
  wheel and are always neutral.

Implemented in `src/combat/natures.js` (`effectiveness`, `matchupChart`).

## 2. The Copy system — collection without Pokéballs

The player builds an arsenal by **absorbing the technique of a defeated enemy**. Each enemy
template carries an `absorbable` skill; on victory it is added to `learnedSkills` and, if there is
room, auto-equipped.

| Defeat | Learn |
| --- | --- |
| Cursed Toad | Acid Spit (Water / Cursed) |
| Grade 4 Cursed Spirit | Poison Spit |
| Rogue Ninja | Shadow Clone Jutsu |
| Kakashi | Sharingan |
| Jiraiya | Rasengan |
| Jogo | Disaster Flames |

**The Rule of Four.** Only **4** skills can be equipped at once (`MAX_EQUIPPED_SKILLS`). The
player swaps them in the Skills menu (Tab) to match the boss ahead. `src/combat/loadout.js`.

## 3. Summoning Contracts — the "monsters" on your team

*Kuchiyose no Jutsu* replaces catching creatures. Beating a boss drops their **Summoning Scroll**;
in battle the player spends Spirit Energy to call the beast for one massive action.

| Defeat | Scroll | Effect |
| --- | --- | --- |
| Megumi (JJK) | Divine Dogs | Earth melee, power 70 |
| Kakashi (Naruto) | Ninja Hounds | Pins the target: guaranteed Paralyze |
| Jiraiya (Naruto) | Gamabunta | Water, power 100 |
| Kurama (ultimate) | Nine-Tails | Fire, power 150, often Burns |
| Mahoraga (ultimate) | Mahoraga | Cursed, power 130, never misses |

**Mahoraga as a boss adapts:** every time a nature hits it, that nature's damage against it is
halved (floor 12.5%). The player has to rotate natures instead of spamming one move.

## 4. Spirit Energy — one unified MP bar

Chakra, Cursed Energy and Web Fluid are the same pool: **Spirit Energy (SE)**. Shadow Clone
(Naruto), Black Flash (JJK) and Web-Shooters (Marvel) all drain it. Big moves (Rasenshuriken 22,
Dagon's Domain 25, Kurama 40) force a choice between a nuke now and a heal or buff later.

Enemies without a Spirit Energy pool (cursed spirits) cast for free; enemies with one pay like the
player does.

## 5. Spider-Man — crowd control master and the HM replacement

### In combat (status effects)

| Skill | Effect |
| --- | --- |
| Web-Stun | Target loses its next turn (Rooted), Speed drops (Webbed) and Defense −1. The tutorial skill. |
| Web-Shooters | Speed −2 stages, Webbed, **50% chance to Root** (skip a turn). |
| Spider-Sense | Dodge the next attack completely, even a Domain Expansion. |
| Web Swing Kick | Physical; **double damage** on a Webbed target. |

Naruto's **Sharingan** works the same way as Spider-Sense: 100% dodge for one turn to survive an
ultimate. Other statuses: Paralyzed (25% to lose a turn), Poisoned (1/8 max HP per round), Burned
(1/16), Shadow Clone decoy (absorbs one hit), Guard (halves damage).

### In the overworld (replacing HMs)

* **Web-Swing** crosses gaps, rivers and broken bridges (`G` tiles). Needs the Web-Shooter.
* **Web-Pull** yanks boulders (`B` tiles) out of cave mouths. Learned from Spider-Man later.

## 6. Combat loop

Classic menu: **Attack · Skill · Item · Run**, plus **Summon** and **Guard**. Turn order is by
effective Speed (Webbed = 40% Speed). Guest allies such as Kakashi are "Ally/Guest" battlers: they
act as automatic **follow-ups** after the player's action. Kakashi's trigger is
*target-defense-down*, so the tutorial plays exactly as scripted: Web-Stun lowers the toad's
defense, Kakashi's Chidori finishes it.

Damage: `((2·Lv/5 + 2) · Power · Atk/Def) / 50 + 2`, times the nature multiplier, web bonus,
adaptation, guard and crit, times a 0.85–1.0 roll. Every battle takes a seeded RNG, so fights are
replayable and testable.

## 7. World progression (planned)

1. **New York City** — tutorial, Spider-Man, Web-Stun. Return later for Web-Pull and Marvel bosses.
2. **Hidden Leaf Village** — Kakashi as mentor. Bosses: Kakashi (Ninja Hounds), Jiraiya (Gamabunta).
   Rogue ninja drop Shadow Clone, Chidori, Fireball.
3. **Jujutsu High** — Gojo as mentor. Bosses: Megumi (Divine Dogs), Jogo, Hanami, Dagon, Kashimo.
4. **Finale** — Mahito × Orochimaru; ultimate summons Kurama and Mahoraga.
