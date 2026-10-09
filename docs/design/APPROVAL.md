# Design approval

Two designer/reviewer pairs ran for five rounds each (a designer draft, then a reviewer checking it against the code and the designer revising, three rounds in one run and two more in a second; 20 agents in all). After round 5 the agents were stopped, as asked, and the lead reviewed the results.

| Track | Document | Round scores | Final reviewer verdict | Lead verdict |
| --- | --- | --- | --- | --- |
| Characters and enemies | `characters.md` (about 20,700 words) | 6.5, 6.5, 7, 7.5, 7.5 | Buildable; 3 IP items left | **Approved with conditions**, applied |
| Worlds, buildings and walkways | `worlds.md` (about 23,600 words) | 7, 6.5, 8.3, 7.8, 8 | Buildable; 2 items left | **Approved with conditions**, applied |

## Why approve now

Both final reviewers checked the designs line by line against the code (file and line references, part and light budgets, R15 sizes, the enemy AI, spawn pads, swing-ray coverage with a script that follows `Movement.findAnchor`) and found them technically buildable. What stopped their approval was five specific items, each with a stated fix. Another full round would have cost two more hours of agents to change a handful of colours, pieces and numbers, so the lead applied the fixes directly. They are listed at the top of each document.

## What the designs deliver

**Characters and enemies**
- A visual language: silhouette rules (one read above the shoulders, one back element, heroes asymmetric and enemies symmetric), five body presets, and a palette per universe. Friend, foe, alpha, elite, stitched, ally and boss can be told apart at a glance.
- A kit of part-built costume pieces with sizes, hosts and offsets, a face made of SurfaceGuis (no more smiling enemies), and emblems. Every figure is under the part budget: players top out at 14 parts, 24 enemies stay within the Highlight limit.
- Every one of the 46 characters written out in full (colours, pieces, one signature detail), none inheriting the generated franchise data.
- Multi-part creatures for all five enemy shapes, human enemy variety by grade, markers for alphas, elites (by affix) and bosses, and the three finale bosses (Hyakunui stitched down the middle from Nuime and Patchwork, the Tempest Fox, the Unbidden with its adaptation tiles).
- Fixes for real bugs found on the way: hair on the face side, costume parts catching raycasts, elites painted entirely in the affix colour, head scale ignored.

**Worlds**
- Rings (plaza, streets, district, skyline), loop routes, climbable walkways, stairs, ramps and rooftop bridges within Humanoid limits, cover, landmarks, and spawn pads kept clear of buildings.
- A navigation layer so enemies that cannot climb still reach and threaten players on high ground (a thrown attack), and collision groups so rails stop bodies but not shots.
- A plan for each of the ten worlds with coordinates, set pieces and budgets (largest 511 parts and 27 lights, against caps of 900 and 60), with swing anchors that pass the real ray fan at every point.

## Build order

1. Worlds first: `Layouts.luau` and its tests, the kit in `Arenas.luau`, the new `Waves.spawnSpot`, the navigation layer, then each world, one commit per world.
2. Characters: `Costumes`/`Kit` modules and tests, the face system, players, then enemies and markers, then the finale bosses.
3. A review pass on each, the place file rebuilt, and a play session in Studio.
