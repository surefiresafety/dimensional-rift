# The first 15 minutes (as implemented in `src/game/`)

## Minute 0–3 · The New York Anomaly — movement & interaction tutorial
**Scene:** the player's bedroom in New York City. The sky through the window glows a glitchy purple.
**Gameplay:** walk with the arrows. Pressing the action key at the TV gives the news report:
> "A massive energy spike detected in Times Square!"

This teaches interaction. The front door is soft-locked until the news has been seen ("I should
check the TV first"), then walking through it triggers a screen fade.

## Minute 3–7 · Meeting Spider-Man — receiving the first ability
**Scene:** a small street map. Cars are abandoned. In the centre of the road Spider-Man is
exhausted, holding a glowing dimensional tear shut with his webs.

> **Spidey:** Hey, kid! Little dangerous out here for a stroll! Whatever is on the other side of this portal is leaking some really bad energy.
> **Player:** I want to help!
> **Spidey:** No way, you don't even have a... wait, look out!
> *(A small Cursed Spirit crawls out of the portal.)*
> **Spidey:** I can't let go of the portal! Here, catch!

**Gameplay:** Spider-Man tosses a spare Web-Shooter. Prompt: **"You equipped the Web-Shooter!
(Skill Unlocked: Web-Stun)"**.

## Minute 7–10 · The portal to Konoha — map transition & plot
The player raises the Web-Shooter but the portal destabilizes. Loud sound, screen flash, and both
the player and the monster are sucked through. The map changes completely: a grassy clearing with
wooden training posts, the Hidden Leaf Village training grounds.

> **Player:** Where am I? This isn't New York...
> *(The Cursed Spirit lands in front of him.)*
> **???:** Hey! Duck!
> *(A shuriken flies past and hits the monster. Kakashi Hatake steps out of the trees.)*
> **Kakashi:** I don't know what that thing is... but my ninjutsu isn't working on it. Kid, whatever you have on your wrist, use it now!

## Minute 10–15 · The tutorial fight & first capture — the core loop
The screen shatters into the first turn-based battle against a **Cursed Toad** (Water, DEF 40).

1. The menu pulses on **Attack**. A normal Strike does ~2 damage of 40.
2. The game prompts: *"Your attack did almost nothing! Use a SKILL → Web-Stun."*
3. **Web-Stun** roots the toad (it loses its turn), webs it and lowers its Defense.
4. With Defense lowered, **Kakashi automatically follows up** (guest battler, trigger
   *target-defense-down*) with a sure-hit Chidori and defeats it.

**Aftermath:** a golden glow surrounds the player.
> **System:** You absorbed the Cursed Toad's energy! Skill Unlocked: Acid Spit (Water/Cursed Damage).
> **Kakashi:** You copied its power? Incredible... you have a strange chakra, kid. Come with me to the Hokage's office. We need to figure out how to get you home.

After this the training grounds open up: a river to **Web-Swing** across, a boulder that needs
**Web-Pull**, tall grass with random encounters (Grade 4 Cursed Spirit, Rogue Ninja, Cursed Toad)
that drop new skills, the Skills menu (Tab) for the Rule of Four, and the Hokage's office marker
that ends the prototype.

`test/tutorial.test.js` replays steps 1–4 against 50 RNG seeds to guarantee the scripted outcome.
