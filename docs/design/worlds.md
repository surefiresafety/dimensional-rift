# Dimensional Rift world layout, buildings and walkways: design revision 4

## R. Changes in revision 4

### Blocking items

| # | Reviewer item | Resolution | Where |
|---|---|---|---|
| 1a | Colony overpass joint gaps | Decks shortened to the **inner-edge chord 15.9 u** (2·40·tan 11.25°), so neighbours never overlap and never z-fight. **9 pier caps 6 × 8.94 × 0.5 at h 6.6–7.1** cover every V (at most 3.2 u wide at the outer edge, well inside the cap's ±3). Outer rails are 19.1 u and inner rails 16.0 u, so both rail lines close. The trusses move off the piers, where they ran into the deck underside, to the outer edge. | §2.1 `chordRing`, §3.5 |
| 1b | Kyoto wall corner cracks | Flats stay 44.7 u. **8 corner bastions 5 × 5, h 0–6.6, at r 59.5 on bearings 22.5 + 45k, yaw −b** cover the 1.28 u crack and the flats' inner overlap. They are walkable, 0.1 u proud of the walk, and stand 1.9 u out from the outer face. Outer rails are 46.0 u. | §3.4 |
| 1c | Vault gallery and Tideline lengths | Gallery: 12 decks of **26.3 u** (inner edge), centred on 30k, plus 12 joint caps 4.5 × 7.94 at 15 + 30k. Tideline: 16 decks of **21.9 u**, centred on 22.5k, plus 16 caps 3.5 × 6.17, with outer rails of **23.9 u**. Vault wall flats are 29.5 u (2·55·tan 15°), with 12 pilasters at the vertices. **New spec check 2b** samples the outer edge of every walk, including the vertex bisectors, and requires support under each sample. It passes all four rings with 0 failures, and it fails 292 Colony samples without the caps and 70 Kyoto samples without the bastions. I used inner-edge decks plus caps rather than the 29.5 / 23.9 overlap because overlapping decks leave coplanar tops that z-fight. The outer-edge lengths are still used for the rails. | §2.1, §3.3, §3.8, §4.5 |
| 2 | `spawnSpot` code | Rewritten in full. It uses a local in-place Fisher-Yates `shuffle`, shuffles the fresh pools, and walks the `all` fallback in sorted LRU order with no shuffle. `used` is cleared whenever the `Nav` instance changes, so it is keyed per build. `centre` is ignored when Nav exists. `spawnCurrent` passes the `boss` it already computes (Waves.luau line 94). | §4.2 |
| 3 | Kyoto gate stairs | Flights move to **x ±(7..18.4)**, z 49.5..52.5. Each has a **3 × 3 landing at x ±(4..7), h 6.5**, flush with the S wall-walk and the gatehouse deck, and a **rail on x = ±4**. The last torii was at z 50.3, where its beam overlapped the landing and rail, so the torii spacing becomes 4.6 (z 16 → 48.2). | §3.4 |
| 4 | Hills versus structures | `hill()` takes `Layouts[theme].hills = { minGround, keepOut }`: storm 66, desert 66, earth 60. Keep-out sectors are rejected by bearing plus the hill's own angular half-width. The Quarry Stone Gate moves in to z 49.5..53.5 so earth passes at 60. **Spec check 9:** minGround ≥ the largest non-backdrop footprint radius + 4, and every `keep` backdrop piece sits inside a keep-out sector. | §4.1, §4.5, §3.6, §3.7, §3.9 |
| 5 | Naming contradictions | `THEME_BUDGET` is removed everywhere. The budget is **`Layouts[theme].budget`**. The toss profile is only ever **`Nav.toss(e)`**, which returns a fresh table every call. | §3, §4.1, §4.3, §4.4 |
| 6 | Missing yaws | There is now a yaw convention (§0.1). Transit shelters: **(24, 8) yaw 90, (8, 24) yaw 0**, which leaves a 1.0 u gap to pad (32, 11). Leaning Block: **6° roll about +Z, pivot on the east bottom edge**, with its roof slope and stair plate given. Seam FillBlocks: **yaw −b** on b = θ ± 13.33°, θ. Also given: Kyoto tower-ramp run bearings, the Thunderspire bridges, Colony tilted towers and the Mistreach hulls. | §0.1, §3.1, §3.4, §3.5, §3.8–3.10 |

### Improvements

| Improvement | Status |
|---|---|
| Perches at 20–40 u cannot be reached by swinging | **Adopted.** They are relabelled **flight-only perches** (§1.3). They are not part of any route, and the reach fallback still covers anyone standing on one. |
| Keep tree crowns queryable | **Adopted** with a **`Foliage`** collision group: CanCollide false, CanQuery true, not collidable with `ShotRay`. Swing rays hit crowns, shots and dashes pass through them, and Nav casts use `RespectCanCollide`. |
| Port the real fan into the Lune spec | **Adopted** (check 4). It uses ray–OBB and ray–sphere tests with the exact `findAnchor` constants. The distance rule stays only as a designer pre-check. |
| Crossarms on thin masts | **Adopted.** Every anchor mast under 2 u wide gets a **crossarm pair**: 2 query-only bars 6 × 0.5 × 0.5 at yaw 45° and 135°, top 1 u below the mast top. Parts are recounted. |
| Academy hero sightline and rails | **Adopted.** The check is visual: rails **count** as blockers, the eye is at h 3.0, and there is a 0.3 u margin. The Academy N cloister rails get a 6 u **Hall Window** gap at x −3..3. |
| Seam hero set piece | **Adopted.** **The Spindle**: a 70 u needle through a thimble, standing on a thread spool at (0, −60). It replaces the stitched pillar on bearing 270. |

### Also fixed while checking

- **Colony trusses.** They stood against piers under the deck, so climbing them only reached the deck underside. They move to the deck's outer edge.
- **Colony sign gantries.** They become cantilevers on one mast at r 50.2. A post at r 39 on bearing 225 would have stood inside pad (−22, −22)'s clear box.
- **Mistreach Tideline.** At top 0.4 it intruded 0.1 u into the outer corners of the (33, −36) B and (−33, −36) clear boxes. Its top is lowered to **0.3**, which is below the pad threshold. The caps (top 0.4) clear those boxes by 0.76 u and 2.76 u.
- **Thunderspire bridge.** "About 6 u" is replaced by exact endpoints.

### Carried from revision 3 (unchanged)

- Rails use the `Rail`/`ShotRay` collision groups.
- Layouts live in hand-written `src/shared/Layouts.luau`, and the world names change in `web3d/rift3d.html`.
- The Dunewatch citadel bridges are dropped.
- Every anchor is fixed data.
- `Nav.clearSpot` handles summons.
- `shotReady` gains `or e.tossing == true`.
- Boss pads sit at r ≥ 34.
- There is 1 pad table per world.
- Terrain colours are reset each build.
- `Spin` is driven by CollectionService.

---

## 0. What the code allows

| Fact | Source | What it means for layout |
|---|---|---|
| The spawn is at `C` + (0, +2) u, via `CFrame.new(pos)`, so **the player faces −Z**. | `World.spawnPoint` | The hero stands on the −Z axis, framed by the portal. |
| `spawnSpot` has no Y. Enemies spawn with +4 studs of lift, in packs of 3 with ±4 u jitter. Bosses spawn alone. | `Waves` | Pads need a clear box: 12 × 5 × 12 u for normal pads, 16 × 7 × 16 u for boss pads. |
| Enemies use `MoveTo` only and never jump. Notice and reach are 3D. Shooting happens at 4.5 < dist < 42. About 91 of 217 enemies are `ranged`. Nothing flies. | `Enemies.think`, `Rules.aiStep` line 476 | The navigation in §4.3 is required. |
| **CanQuery is ignored when CanCollide is true.** Collision groups do filter raycasts through `RaycastParams.CollisionGroup`, and `RaycastParams.RespectCanCollide` skips CanCollide-false parts. No collision groups are in use today. | engine, grep | Rails go in the `Rail` group, tree crowns in the `Foliage` group, and shot rays use the `ShotRay` group. |
| Swing: elevations 25–80° in 9 steps, 5 yaws (±0.9, ±0.45, 0 rad), reach 60 u (`ROPE_REACH`), hit more than 4 u above the root, score = 2·Y + forward, rope = 0.92 × distance, default group. | `Movement.findAnchor` (lines 40–75) | A hit at distance D needs a top of at least 0.47·D + 4. The arc clears the start height only for rays at 66° or steeper, so **a swing never lands a player on a perch 20–40 u up**. Adjacent rays are 26° apart, so a 1.6 u mast is often missed; masts need crossarms. |
| The Humanoid steps about 2 studs and walks 30° wedges. Truss sizes snap to 2 studs. | engine | Ramp run = 1.75 × rise. |
| `SIGNS` contains "DAILY BUGLE" and "RAMEN ICHIBAN". The portal segments are CanQuery true. | `Arenas.luau` | Both are fixed in §4.1. |
| `src/shared/Data/*` is generated, and `test/roblox-export.test.js:19` compares it against a fresh export. | README, test | New data goes outside `Data`. Names are changed in `rift3d.html`. |
| `Terrain:Clear()` does not reset `SetMaterialColor` (`Arenas.luau:442`, `:854`). | engine | Colours are reset per build. |

### 0.1 Coordinates

- Positions are `(x, z)` in units from C, and `h` is height in units. 1 u = 2.4 studs.
- **N = −Z, S = +Z, E = +X.** Bearing 0 = E, 90 = S, 180 = W, 270 = N (as in `around()`).
- **Yaw convention.** `yaw` is in degrees and is applied as `CFrame.Angles(0, math.rad(yaw), 0)`. At yaw 0 a part's Size.X runs along world X. At yaw 90 its Size.X runs along world −Z (N–S).
  - A **radial piece** on bearing b (chord decks, caps, bastions, pilasters, radial ramps) uses `CFrame.new(around(b, r)) * CFrame.Angles(0, -math.rad(b), 0)`, with Size.X radial and Size.Z tangential. In the tables this is written as "yaw −b".
  - A **run bearing** is the direction a ramp or stair climbs from foot to top.

### 0.2 IP clean-up

- **World names**, edited in `web3d/rift3d.html` and then re-exported. Ids, `build` keys and saved progress are unchanged, and the web build shows the same names.

  | Old | New |
  |---|---|
  | Land of Wind | **Dunewatch** |
  | Land of Earth | **Quarry Hollow** |
  | Land of Water | **Mistreach** |
  | Land of Lightning | **Thunderspire** |

  `roblox/README.md` line 95 changes to "once Thunderspire is cleared".
- **Signs:** "DAILY BUGLE" becomes **"MIDTOWN LEDGER"**, and "RAMEN ICHIBAN" becomes **"NOODLE BAR 88"**.
- **Colony:** no dome and no crimson. It is an **amber quarantine fence**: 10 pylons with light-curtain Beams between them. The board reads **"BLOCK 01 · HEADCOUNT"** with the rows "PRESENT", "MISSING" and "CURFEW".
- **Buildings** use real vernacular styles only: ksar and windcatcher, quarry cliff dwellings, a stilt fishing village with a lighthouse, and a cliff monastery. There are no crests, village symbols or kanji emblems.
- **Out of track:** the internal keys `buildJujutsuHigh`, `buildCullingColony`, `boss_gojo` and `boss_sukuna` replicate to clients and should be renamed in a separate data pass.

---

## 1. Layout principles (all ten worlds)

### 1.1 Rings

| Ring | r (u) | Job | Rules |
|---|---|---|---|
| R0 Rift Plaza | 0–12 | Spawn, portal | Nothing collidable below h 3 except the floor. No pads. |
| R1 Threshold | 12–20 | Framing, anchor bases, access to hero pieces | No pads. |
| R2 Districts | 20–50 | The fight | Lanes between districts at least 6 u. All pads. Boss pads at r ≥ 34. |
| R3 Edge | 50–60 | Boundary as a place | Walls, galleries, boardwalks, usually carrying the upper route. |
| R4 Backdrop | 60–150 | Skyline and terrain | Terrain hills only beyond `hills.minGround` (desert 66, earth 60, storm 66), and never inside a keep-out sector (§4.1). |

### 1.2 Routes

- **Ground loop:** continuous at r ≈ 30–42, at least 6 u wide.
- **Upper route:** at h 5–10, either a loop or a U that comes down by ramps at both ends.
  - Every walk sample point has an **access top within 25 u**.
  - Accesses are ramps or stairs at least 3 u wide, or a truss. The main accesses are at least 4 u wide.
- **Sightlines:** from each upper-route sample (every 6 u, at +1.5 u), every pad within 30 u is visible to a `ShotRay`-group ray.
- **No pad sits under a deck.**
- **Continuous walking surface:** every walk is supported across its full width, including the outer edge at polygon joints (spec check 2b). Chord polygons are built with `chordRing` (§2.1).
- **Gates** are at least 5 u wide and at least 6 u tall.

### 1.3 Buildings versus the AI

- R2 buildings are convex rectangles: short side 14 u or less, long side 24 u or less, at least 6 u apart.
- Ground floors are open colonnades.
- **Upper-route edges are rails** in the `Rail` group: they stop bodies but not shots or dashes. Rails leave 3 u gaps at access tops and bridge ends.
- **Flight-only perches.** These are tops at 20 u or more with no ramp, stair or truss: the Beacon roof, the pagoda tiers, the Quarry gate lintel, the Crane jib, the Thunderspire spire and pinnacle tops, the Seam fragments and the Spindle.
  - Swinging cannot land a player on them (§0), so only characters with `Movement.startFlight` reach them.
  - They are **not part of any route** and are not counted as walks.
  - The reach fallback (§4.3) still covers a player standing on one.

### 1.4 Cover and landmarks

- **Cover:** 2–4 pieces at least 2.2 u tall in each 20 × 20 u cell of R2, taking up no more than about 20% of the floor.
- **Scatter** (canes, blossoms, boulders, crates, cairns) is seeded and **rejected inside any pad's clear box plus 0.5 u**, inside footprints, within 3 u of walks or access pieces, and **within 2 u (in plan) of the hero sightline segment** from C to the hero, so seeded cover never breaks check 7.
- **Landmarks:** a hero on −Z, one silhouette per district, and a beacon in fog worlds.

### 1.5 Swing anchors: the fan gate

**The gate is the real `findAnchor` fan, and every grid point must pass it.** This exact rule is used in three places: here, in the audit (§4.4) and in spec check 4 (§4.5).

1. **Grid points.** Every point with x and z both multiples of 10 and 20 ≤ r ≤ 50. That is 72 points per world before any are skipped.
2. **Floor.** The floor is the highest `h1` of the `floor = true` footprints containing the point: terraces, the Academy podium, the Vault dais steps and the Quarry benches. If none contains it, the floor is 0. The root is placed at floor + 1.25 u.
3. **Skipped points.** A point is skipped when it lies inside, in plan, a CanCollide footprint that is not a `floor` footprint and that spans any height between floor + 3 and floor + 16 (`h1 > floor + 3` and `h0 < floor + 16`). The plan test includes the boundary, with a 0.01 u tolerance.
   - This covers points inside a building, points on a ramp or stair that rises more than 3 u, and **points under a deck, cap, landing, cloister roof, bridge or board**. From such a point every ray hits an underside or a wall, and a player would step out before swinging.
   - Points under something that starts 16 u or more above the floor **do count**. Examples are the Vault ribs, the Colony gantry beams and the Colony water-tower tank.
   - Query-only parts (cores, Foliage crowns, crossarms, Hem shards) never cause a skip.
4. **Facings.** The root faces N, E, S and W in turn, and each time the §4.5 port of `Movement.findAnchor` runs. It uses 9 elevations × 5 yaws, a 60 u reach, the "more than 4 u above the root" test and score = 2·y + forward. A facing passes when its **chosen** hit, meaning the best score and not the highest hit, is at least floor + 16.
5. **A point passes when at least 3 of its 4 facings pass. Every non-skipped point must pass.**

**Geometry.** The fan tests every non-decor footprint: solids, rails, cores, crossarms, lamp banks and backdrop pieces. Foliage crowns are tested as spheres, and ramps as wedges. Terrain and seeded scatter are left out. The in-game audit (§4.4) casts against the built arena, so it sees them.

**Why the gate is hard, and the pattern that passes it.** Each facing samples only three families of directions, with 9 rays in each:
- dead ahead (yaw 0);
- 28–70° off the facing at 22–62° up (yaw ±0.45);
- 54–82° off the facing at 15–38° up (yaw ±0.9).

An anchor 1–27° off a facing is therefore invisible to that facing, and a thin anchor between two samples is missed. A point next to a low roof or wall also has its "best score" taken by a 6–14 u hit, which is what the reviewer saw in the Academy north court. The one world that already passed, the Crossroads, shows the pattern that works. Revision 5 applies it everywhere:
- **(a) Inward anchors in R1**, at r 12–17 and 24–30 u tall: the Crossroads pylons, Academy pillars, Dunewatch gnomons, Mistreach fog-bell towers, Thunderspire threshold rods and Seam Hem shards.
- **(b) An outer ring of wide masses 30 u tall or more** at r 55–68: towers, cedars, ksar towers, sea stacks and storm stones.
- **(c) A wide or crowned anchor inside every court** that a roof or hall closes off, such as the Academy courtyard and north-court cedars.

**Thin masts.**
- Any mast under 2 u wide still gets a **crossarm pair**: 2 bars 6 × 0.5 × 0.5 in the Core flag set, at yaw 45 and 135, crossing on the mast axis with their top 1 u below the mast top. Colour: galvanised grey RGB(120, 124, 130) Metal. On the Thunderspire rod towers they are copper RGB(184, 115, 51).
- The reviewer was right that crossarms alone do not fix the blind wedge. No point in revision 5 passes on a crossarm alone: every facing that the gate counts is carried by a mass, a crown or a lamp bank. The one exception is the Seam, where crossarms are backed by the Hem shards.
- A **lamp bank** is the other thin-mast head: a Core-set panel 6 wide × 3 tall × 0.6 at the mast top, facing C (yaw −b). It is used on the Colony north floodlights.

**Margin (informational, not a gate).** Each world's swing line also reports **jitter-weak** points. A point is jitter-weak when it passes but at least one of the 4 points 1.5 u away (N, E, S, W) does not. This shows how far a `Layouts` file can drift from the numbers in §3 before check 4 notices.

**How the numbers in §3 were produced.** They come from the designer's scratch model. It uses the exact fan (the §4.5 code), with every piece in §3 as an oriented box at its stated size, yaw and heights. Ramps and stairs are boxes of half their rise, vertical cylinders are exact, and crowns are spheres. As a sensitivity check the ramps were also run as full-rise boxes, and the gate still passes in all ten worlds. **The distance rule of revisions 2–4 has been deleted**, including its use as a pre-check, because it disagreed with the fan in 9 of the 10 worlds.

---

## 2. Building and walkway kit

### Part flag sets

| Set | CanCollide | CanQuery | CanTouch | CastShadow | CollisionGroup |
|---|---|---|---|---|---|
| **Solid** (`part()`) | true | true | true | true | Default |
| **Decor** | false | false | false | false | Default |
| **Rail** | true | true | false | true | **`Rail`** (not collidable with `ShotRay`) |
| **Core** (anchor) | false | true | false | false | Default. Shots stop on it; it reads as foliage. Crossarms use this set too. |
| **Foliage** (cedar and pine crowns) | false | true | false | true | **`Foliage`** (not collidable with `ShotRay`). Swing rays hit it (default group). Shots, dashes and knockback pass through it. Nav casts skip it through `RespectCanCollide`. |

### 2.1 Access and walkways

| Piece | Function | Dimensions (u) | Parts |
|---|---|---|---|
| Ramp | `ramp(k, foot, dir, w, rise)` | w 3–8; run = 1.75·rise; rise ≤ 7 | 1 wedge. Writes a `Link`. |
| Tangential ramp | `ramp(..., landing=true)` | A ramp running parallel to a raised edge, plus a **w × w landing** flush with the top, so there is a full w-wide doorway | 2 |
| Stairs | `stairs(k, foot, dir, w, rise)` | Hidden wedge plus decor treads, `min(8, ceil(rise/0.6))` of them | ≤ 9 |
| **Switchback** | `switchback(k, top, dir, w, rise)` | **Two parallel flights side by side**, each rising rise/2 over a run of 0.875·rise. A w × 2w landing at the far end at h = rise/2. **Footprint 2w × (0.875·rise + w).** The upper flight's top abuts the deck edge. | 3 |
| Ledge stair (in line) | `ledgeStair(k, ...)` | ramp 1, landing, ramp 2, and a top landing in one line | 4 |
| Truss ladder | `ladder(k, foot, face, hU)` | `TrussPart` 2 × H × 2 studs, NoSupports. H = hU·2.4 rounded up to an even number of studs; base sunk so the top sits 0.4 studs above the deck. Footprint 0.83 × 0.83 u. | 1 |
| Deck | `deck(k, x, z, w, d, h, posts)` | slab 0.5 thick, posts 0.6 | 1 + 0/2/4 |
| Rail | `rail(k, a, b, style)` | panel 0.3 × 1.1, or timber (2 bars) | 1 / 2 |
| Flat bridge | `bridge(..., "flat")` | 3 wide, span ≤ 24, slope ≤ 12° | 3 |
| Arched bridge | `bridge(..., "arch")` | 2 wedges rising 1.5, crown deck, 2 rails; span ≤ 16; footprint is span + 0.6 by 3 | 5 |
| Rope bridge | `bridge(..., "rope")` | 2.5 plank deck, 2 rope rails, 2 posts; span ≤ 28 | 5 |
| Archway / gate | `arch(k, cf, span, h)` | piers 1.5 × h × 1.5 plus lintel; opening ≥ 5 × 6 | 3 |
| Ring inlay | `ring(k, r, colour)` | neon disc plus dark disc | 2 decor |
| **Chord ring** | `chordRing(k, s)` with `s = { b0, b1, n, rIn, rOut, top, t, capW, capT, rails }` | n chord decks between bearings b0 and b1, each on bearing b0 + (i + ½)·step, yaw −b. **Deck length = 2·rIn·tan(step/2)** (the inner-edge chord), so neighbours never overlap and no two tops are coplanar. Depth rOut − rIn, thickness t, top `top`. **Joint caps** go on every joint bearing b0 + j·step (for an open U, both ends too). Each cap is capW tangential × (rOut/cos(step/2) − rIn) radial, yaw −b, thickness 0.5, **top = top + capT** (0.1 by default). capW ≥ 2·(rOut − rIn)·tan(step/2) + 1 is asserted. **Rails:** outer rails 2·rOut·tan(step/2) long at rOut − 0.15; inner rails 2·(rIn + 0.3)·tan(step/2) long at rIn + 0.15. Both close at the joints. `rails.gaps` lists {bearing, edge, from, to} openings in u from the joint. | n + caps + rails |

### 2.2 Street furniture and cover

All CanQuery true unless marked decor.

| Piece | Dimensions (u) | Parts | Lights |
|---|---|---|---|
| Market stall | counter 4 × 1.1 × 1.5; 2 posts 0.3 × 3; awning (decor); goods (decor). Footprint 4 × 1.5 × 3.2. | 5 | 1 per 2 stalls |
| Crate | 2.4 cube | 1 | 0 |
| Shipping container | 6 long × 2.5 wide × 2.6 tall, plus a decor stripe | 2 | 0 |
| Jersey barrier | 4 × 0.8 × 1.2 | 1 | 0 |
| Car | 4.5 × 2 × 1.6: body, glass, 2 axles, headlamp (decor) | 5 | 0 |
| Wrecked car | same footprint, plus `Fire` | 4 | 0 |
| Street lamp | pole 0.5 square × 7, neon bulb (decor) | 2 | 1 on every second lamp |
| Stone lantern | 1 × 1 × 2.4, glowing box (decor) | 2 | 1 |
| Floodlight / mast | 1.2–1.6 square, 20–22 tall, head (decor), **crossarm pair** (§1.5) | 4–5 | 0–1 |
| Torii | the existing `torii()`: posts at **x ±3**, beam 9 wide, top at 7.4 | 4 | 0 |

### 2.3 Buildings and anchors

| Type | Dimensions (u) | Composition | Parts | Lights |
|---|---|---|---|---|
| B1 Tower | 12–24 wide, 30–110 tall | body, ≤ 3 window bands (decor), roof | ≤ 5 | 0 (+1 with a billboard, +1 decor part) |
| B2 Walk-up | 12 × 12, roof at h 9 | body, 4 roof rails, 22-stud truss, 2 bands (decor), tank (to 11.4), door (decor) | 10 | 0–1 |
| B3 Arcade | 14 × 10, open ground storey 5 tall, roof at h 9 | back wall, side wall, 3 columns, upper mass, counter, sign (decor), 4 rails, truss | 13 | 1 |
| B4 Pavilion hall | w 16–26, d 12–16, h 7–10 | podium, step wedge, 2 treads (decor), 6 posts, back wall, 2 roof tiers, ridge | 14 | 1 |
| B5 Watchtower | 6 × 6 deck at h 10–13, total 18–26 | 5 × 5 core, deck, 4 rails, 2 posts, roof, truss | 10 | 1 |
| B6 Mudbrick house | 9 × 9, roof at h 5 / 6.2 / 7.4 | body, 2 edge rails, door (decor), window (decor), roof clutter (decor) | 6 | 0 |
| B7 Stilt house | deck 14 × 12 at h 0.4; house 11 × 9 × 6 | deck, 4 stilts, body, 2 roofs, door glow (decor) | 9 | 1 |
| **Dorm** (Academy) | 22 × 14 × 8, balcony 2 wide at h 5 | body, roof slab, balcony slab, timber balcony rail (2), 2 balcony posts, 2 window bands (decor), door (decor) | 10 | 1 |
| **Tea pavilion** (Kyoto) | deck 8 × 8 at h 1.5 | deck, 4 stilts, step ramp (rise 1.5), 4 posts, roof | 11 | 1 |
| Windcatcher | 3.5 × 3.5 × 20–26 | core, 2 vents (decor) | 3 | 0 |
| Cedar / pine (anchor) | h 30–44 | Solid trunk 1.6 across (pine 1.2) up to 0.55·h, Wood RGB(92, 64, 44). **3 crown balls in the Foliage set**: Ball parts of diameter 0.26·h, 0.21·h and 0.15·h centred at 0.62·h, 0.77·h and 0.90·h, Grass material, cedar RGB(46, 74, 52) and pine RGB(38, 64, 48). **`Anchor` core**: Cylinder 1.2 across from 0.55·h to 0.95·h (hit height **0.95·h**). | 5 | 0 |
| Broadleaf / blossom / palm | h 10–16 | Trunk plus crown (decor). Palm: trunk to 14, 4 fronds (decor), not an anchor. The crowns stay decor, because a 10–16 u hit only gives a dragging swing. | 4 / 5 | 0 |
| Backdrop cedar | h 30–40 | trunk plus 2 balls (decor) | 3 | 0 |
| Anchor mast | 1.6 square, 20–40 tall | `spire()` plus a **crossarm pair** | 4 | 0–1 |

---

## 3. The ten worlds

**Conventions:**
- **B** marks a boss pad (16 × 7 × 16 u clear, r ≥ 34). Every other pad clears 12 × 5 × 12 u.
- `h` is only given when a pad is not on the ground.
- Counts include the portal (29 parts, 1 light), the weather part and the `Nav` part: 31 parts and 1 light.
- **Budget** means `Layouts[theme].budget` (parts / lights), the `warn` threshold in §4.1.
- **Min gap** is the smallest distance between a pad's clear box and any part.

### 3.1 Times Square: "The Crossroads" (city, night)

**Grid**
- North–south avenue (|x| < 6) and east–west street (|z| < 5), out to 100.
- **Ring Street** is the band where |x| or |z| is 30–38. It is the ground loop.

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| **The Beacon** (hero) | (0, −26): x −4..4, z −30..−22, 36 tall. 4 corner columns 1.5 × 6, then the upper mass from h 6 to 36. | You see north through its open legs. Three SurfaceGui screens face south. Neon crown (decor). Flight-only roof. |
| Neon Theatre (B3) | x 13..27, z −23..−13; truss on the south face at x 20.5 | "NOW SHOWING". Roof at 9. |
| **Red Steps** | x −26..−10, z −25..−14. Deck 16 × 4 at h 4 (z −25..−21); ramp z −21..−14 running down to the south | 7 neon tread edges (decor). Rails on the back and sides. 6 u lane to the Beacon. |
| Market Alley | Stall rows at x −16 and −26 (footprints x −17..−15 and −27..−25), z 16..28, 3 stalls each | |
| Transit Plaza | Kiosk 6 × 4 × 2.4 at (18, 18), yaw 0. Shelters 4 × 2 × 3 (Size.X = 4): **(24, 8) at yaw 90** (x 23..25, z 6..10, open face west) and **(8, 24) at yaw 0** (x 6..10, z 23..25, open face north). Planters 2.4 × 1.2 at yaw 0: (12, 21), (21, 12), (27, 20), (20, 27). Shelter glass RGB(150, 200, 220) Glass, transparency 0.5; frame RGB(60, 64, 70) Metal. | Subway mouth (decor). Shelter (24, 8) is 1.0 u from pad (32, 11)'s box (x 26..38) and 2.75 u from lamp (20, 7.5). |
| Billboard pylons | (±12, ±12), 1.6 × 26, crossarm pair at h 24.5–25 | Crossarm ends reach 2.1 u from the axis, all inside R1 |

**High Line (upper loop, h 9)**
- 8 walk-ups (B2) at (±16, ±46) and (±46, ±16).
- 4 corner decks, solid 14 × 14 × 9, at (±46, ±46).
  - Each has a **switchback** (w 4, rise 9) that starts at the deck's outer x face and runs outward: |x| 53..64.9, z 42..50 around the corner line.
- Sky-bridges of 20 u at (0, ±46) and (±46, 0), with underside at 8.6.
- 8 corner bridges of 17 u.
- 8 trusses on the Ring Street faces (22 studs). The largest gap to an access is about 16 u.

**Cover**

| Type | Positions (x, z, yaw) |
|---|---|
| Cars | (34,−18,90), (−34,−18,90), (36,21,90), (−35,24,90), (18,34,0), (−16,36,0), (12,−34,0), (−18,−36,0), (34,−44,90), (−34,44,90) |
| Jersey barriers | (37,−26,90), (−36,20,0), (22,38,90), (−22,38,90), (36,−22,0), (−38,−20,0), (−12,−37,90), (−22,−30,90) |
| Street lamps (16, 8 lit) | (±8.5, ±20), (±8.5, ±54), (±20, ±7.5), (±54, ±7.5) |

**Dressing**
- Dashes cut to 20, 4 crosswalks, and a ring inlay at r 12.
- Near towers (14 × 14) at (62,−26) h 44, (62,26) 38, (−62,−26) 40, (−62,26) 48, (26,−62) 50, (−26,−62) 36, (26,62) 42, (−26,62) 46.
- 10 seeded far towers at 80–100 (not counted as anchors). 8 billboards.

**Anchors:** Beacon 36; pylons 26; near towers 36–50.

**Swing gate (fan, §1.5):** 53 points (19 skipped: inside walk-ups and corner decks, or under sky-bridges), **0 fail**, 48 of them 4 of 4. Jitter-weak: 4, at (20, −10), (20, 20), (30, 40) and (40, 30). The revision 4 geometry already passed, so nothing changes. This world is the pattern the others now follow: R1 pylons, plus a ring of wide towers at r 62–68.

**Pads** (12, 4 boss; min gap 0.5 u)

| | | | |
|---|---|---|---|
| (0, −40) B | (40, 0) B | (−40, 0) B | (0, 40) B |
| (30, −30) | (−32, −32) | (30, 30) | (−32, 35) |
| (26, −33) | (−24, 0) | (32, 11) | (−32, 9) |

**Height:** Red Steps 4, Theatre 9, High Line 9; the Beacon roof (36) by flight only.

**Budget: 501 parts / 31 lights** (budget 540 / 36)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Ring inlay, crosswalks, dashes | 38 | 0 |
| Beacon | 9 | 1 |
| Pylons (with crossarms) | 16 | 4 |
| Theatre | 13 | 1 |
| Red Steps | 12 | 0 |
| Stalls | 30 | 3 |
| Transit plaza | 12 | 1 |
| Walk-ups | 80 | 4 |
| Corner decks | 36 | 0 |
| Bridges | 36 | 0 |
| Cars | 50 | 0 |
| Jersey barriers | 8 | 0 |
| Lamps | 32 | 8 |
| Towers | 90 | 0 |
| Billboards | 8 | 8 |
| **Total** | **501** | **31** |

### 3.2 Tokyo Sorcery Academy: "The Hidden Campus" (afternoon)

| Piece | Position and size | Notes |
|---|---|---|
| Rift Court | Gravel terrain; 4 stone lanterns at (±9, ±9) | |
| **Cloister** (upper loop, h 5) | Roofs 5 wide × 0.5 on the rectangle x ±30, z −24..+22: N run z −26.5..−21.5, S run z 19.5..24.5, E/W runs x ±(27.5..32.5). 26 posts 0.8 × 5 on the outer edge, rails on both roof edges. **Hall Window:** both N-run rails (z −26.35 and z −21.65) break for x −3..3, so each is 2 segments of 27 u. The 4 hanging lanterns (decor, lit) hang under the N and S runs at x ±12. | Open at ground level. The window keeps the hero sightline clear of rails (§4.5 check 7): the eye line crosses the N run at h 5.64–6.25, above the roof (5) but below rail tops (6.1). |
| Cloister accesses (8; max gap 22 u) | **N corner ramps**: 3 wide, x ±(28.5..31.5), foot at z −35.25, top at z −26.5. **S corner ramps**: z 20.5..23.5, from x ±41.25 up to ±32.5. **Inner tangential ramps with 3 × 3 landings**: N at z −21.5..−18.5, **x 4→12.75 (landing x 12.75..15.75)**, run bearing 0; S at z 16.5..19.5, x −8→−16.75 (landing to −19.75). **2 dorm bridges** (2.5 u, flat). | **Revision 5:** the N ramp moved 4 u west. At x 8..19.75 its 5 u landing stood 0.25 u from grid point (20, −20), and with the N run overhead that point had no N or W facing. The ramp's east end is now 4.25 u from that point. The N run's largest gap to an access top drops from 24.1 to 22.1 u. |
| **Main Hall** (hero) | Podium x −14..14, z −53..−35, h 3. Stair 14 wide at z −35..−29.75. Hall 24 × 14 × 8 on the podium at x −12..12, z −51..−37; roof top 14. | `hero = { x = 0, z = -44, top = 14, ids = { "hall", "podium", "hall-stair" } }` |
| Bell Tower (B5, stretched) | x −27..−21, z −53..−47. Deck at 12 by a 30-stud truss; roof at 26. | |
| South Gate | Torii at z 27 and 58 (posts x ±3). Gatehouse at (0, 48): piers 4 × 6 × 10 at x ±(3..7), deck at 6, roof at 10, 16-stud truss. **Upper storey (new):** a block 14 × 7.5 × 6 at x −7..7, z 45..51, h 10–18, in plaster RGB(232, 226, 214) SmoothPlastic with 2 dark window bands (decor), under an **upper roof 16 × 1 × 8** at x −8..8, z 44..52, h 18–19, in Slate RGB(58, 62, 70). | Opening 6 × 6. The storey gives (0, 40) a south facing: its 73° ray now hits the storey face at 17.7. Before, the lower roof capped every hit at 10.5. |
| Dorms | x ±(37..51), z −21..1, 22 × 14 × 8, long axis on Z. Balcony x ±(35..37) at h 5. | Parts in §2.3 |
| Training ring | Mud disc r 12 at (−28, 38); **6 posts 0.8 × 3 at r 12** on bearings 30 + 60k | Boss stage |
| Pond garden | Water r 8 at (32, 36); arched bridge north–south at x 32, z 28..44; rocks at (41, 30), (23, 41), (40, 43) | Reflecting pool (§4.1) |
| Training pillars | (±18, ±14): **3 × 3 × 26** (was 2 × 19), timber RGB(92, 64, 44) Wood, each with a **crossarm pair 8 × 0.5 × 0.5** (Core set, yaw 45 and 135, h 24.5–25) in the same wood | Pad (±20, 4)'s box ends at z ±10, 2.5 u from the pillar face. Widening the pillars was worth more than the crossarms: at 2 u they sat in the fan's blind wedge from most of the courtyard. |
| Training stones (8) | **(±5, −13)**, (±24, −12), (±8, 15), (±24, 14); each 2 × 1.2 × 3 | The north pair moved in from (±8, −14) to clear the courtyard cedars by 2 u |
| **Path lanterns** (6, 3 lit) | x ±5.5 at z 53, 62, 66 | Moved clear of the (0, 36) boss box |
| Old cedars (18) | NE (34,−38) h40, (40,−42) 44, (46,−37) 36; NW mirrored; SE (46,26) 38, (50,34) 42, (44,44) 36; SW (−46,26) 38, (−44,34) 42, (−52,20) 36; gate (±12, 56) 34; **courtyard (±10, −16) 40; north court (±11, −31) 40** (new) | Core hit at 0.95·h. **Courtyard pair:** the trunks stand 1.7 u from the N inner ramp's side (z −18.5). The lowest crown ball (radius 5.2, centre h 24.8) clears the N-run rails (6.1) by 13.5 u. **North-court pair:** the trunks stand 3.2 u from the hall stair (x ±7) and the podium (z −35), 3.7 u from the N run, and 4.2 u from pad (±22, −40)'s box. **Hero sightline:** the nearest of these trunks is 9.2 u from the eye line (x = 0), and the nearest crown ball is 22 u from it. |
| Backdrop | 24 cedars at 90–140; terrain mountains | |

**Anchors:** pillars 26 (with crossarms); Bell Tower 26; gatehouse storey 19; cedar cores 32.3–41.8, with crowns.

**Swing gate (fan, §1.5):** 41 points (31 skipped: under the cloister roofs, on the podium under the hall, inside the dorms, or on the ramps), **0 fail**, 36 of them 4 of 4. Jitter-weak: 0. The revision 4 geometry failed 10 points: (0, −20), (±10, −20), (±20, −20), (0, −30), (±10, −30), (±20, −30) and (0, 40). The reviewer's list also included (±30, −30) and (10, −20). Under the §1.5 rule those points are skipped because they lie on the N corner ramps and the moved N inner ramp, but they pass 4 of 4 even when counted.
- **North court (z −30).** The hall (top 14) fills the north, the N-run roof shadows the south, and the NE and NW cedars sit 9–17° off the E and W facings, inside the blind wedge. The north-court cedars fix this: the E and W facings of (0, −30) now take the far cedar's crown at 25.1.
- **Courtyard (z −20).** The N-run roof closes the north. The courtyard cedars give the E and W facings a crown at 22–24.
- **(20, −20)** was the landing pocket, fixed by moving the N inner ramp.

**Pads** (10, 4 boss; min gap 0.5 u)

| | | | | |
|---|---|---|---|---|
| (−28, 38) B | (0, 36) B | (42, 10) B | (−42, 10) B | (20, 4) |
| (−20, 4) | (22, −40) | (−22, −40) | (39, −29) | (−39, −29) |

**Height:** cloister 5, balconies 5, gatehouse 6, podium 3, Bell Tower 12.

**Budget: 366 parts / 17 lights** (budget 400 / 20)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Stone lanterns | 8 | 4 |
| Cloister (4 roofs, 26 posts, 10 rails, 8 ramps, 2 landings) | 50 | 0 |
| Hanging lanterns | 4 | 4 |
| Main Hall | 17 | 1 |
| Bell Tower | 11 | 1 |
| Gatehouse (with the upper storey and roof) | 9 | 1 |
| Torii | 8 | 0 |
| Dorms | 20 | 2 |
| Ring posts | 6 | 0 |
| Pond | 8 | 0 |
| Pillars (4 × (pillar + 2 crossarms)) | 12 | 0 |
| Stones | 8 | 0 |
| Cedars (18 × 5) | 90 | 0 |
| Backdrop | 72 | 0 |
| Path lanterns | 12 | 3 |
| **Total** | **366** | **17** |

### 3.3 Tombs of the Star Vault: "The Ribbed Vault" (night)

**Vault**
- 12 pillars 3 × 3 at r 34 on bearings 30k, from the floor to h 57.
- 12 radial ribs 3 × 1.5 with the **underside at h 57**, from r 12 to r 34.
- A crown ring and an outer ring beam. The oculus over r < 12 is open, with stars visible through it and between the ribs.
- Nothing extends past r 60: the wall's outer vertices are at 59.0 and the pilasters reach 59.9.

**Swing check** (unchanged from revision 2)
- The 73.1° ray hits a rib at 58.3 u, giving a 53.6 rope. The arc bottoms out 2.1 u above the starting root height.
- Any rib hit gives a rope of 55.2 or less, against 55.75 of height, so no rib swing drags on the floor.

**Star chains** (new)
- 4 query-only cores (a Cylinder 1.2 across, h 30–40) at r 20 on bearings 45 + 90k, one over each crystal grove.
- A Beam chain runs from each core to its rib (0 parts). A neon star (decor) hangs at the bottom.
- Steep hits (73° or more) give ropes of about 28 u: quicker, livelier swings inside the colonnade. Shallow hits behave like any mast.

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| **Keeper's Dais** (hero) | (0, −26): 5 stepped discs of r 12 → 6.4, each 0.6 u high, top at 3. Seat 5 × 5 × 6 at (0, −35) on the steps (z −37.5..−32.5). Orb (decor). 8 stars hanging on Beams. | |
| Star-chart floor | Inlays at r 16 and 30 | |
| **Processional Gallery** (upper loop, **h 8**) | `chordRing{ b0 = -15, b1 = 345, n = 12, rIn = 49, rOut = 55, top = 8, t = 0.4, capW = 4.5 }`. That gives **12 decks 26.3 × 6** (2·49·tan 15° = 26.26) centred on bearings **30k**, yaw −b, underside 7.6. **12 joint caps 4.5 × 7.94 × 0.5** on bearings **15 + 30k**, spanning r 49 → 56.94 (the wall's inner vertex), h 7.6–8.1. The widest outer V is 3.2 u, inside the cap's ±2.25. **12 posts at r 49 on bearings 30k** (in line with the pillars). **Inner rail only:** 12 × 26.4 u at r 49.15, with 4 u gaps at the 8 ramp landings. The outer edge is the wall. Deck: Slate RGB(58, 52, 70); caps: bronze RGB(140, 110, 60) Metal. | The gates under it are 6.5 tall. Every gate flat is centred under a deck. The cap on bearing 45 is 0.3 u above the (28.3, 28.3) B box (top 7.3). |
| Gallery accesses | **8 tangential ramps**, 4 wide, rise 8, run 14, at r 45–49 on bearings 22.5 + 45k, each with a 4 × 4 landing flush against the deck edge | Largest gap about 20 u |
| Outer wall | **12 flats centred on bearings 30k**, apothem 55–57, **26 tall** (was 16), each **29.5 u** long (2·55·tan 15°, the inner-face chord, so the flats never overlap). The 4 cardinal flats (bearings 0, 90, 180, 270) are Star Gates (opening 6 × 6.5) with lit braziers. **12 pilasters 3 × 3 × 27 at r 58.4 on bearings 15 + 30k, yaw −b**, cover the 1.07 u outer-corner cracks and rise 1 u above the wall. Wall: RGB(46, 42, 58) Slate, with a **clerestory band** from h 16 to 26: the same flat part, plus one decor strip per flat (29.5 × 0.6 × 0.1, neon RGB(150, 140, 220), Transparency 0.4) at h 21 on the inner face. Pilasters: RGB(70, 62, 84) Slate with a neon star-point (decor) on top. | **Revision 5:** at 16 u the wall capped every outward hit below 16. Points at r 41 between two pillars, such as (40, ±10) and (±10, ±40), got 13.5–15.9 on 3 of 4 facings. At 26 u those facings hit the wall at 17–25. The ribs are unchanged, and the sky still shows through the oculus and between the ribs above the wall. The strips add 12 decor parts. |
| Crystal groves | **r 20** on bearings 45 + 90k; 5 crystals each inside a 6 × 6 × 4 patch | 1 light each |
| Braziers | 3 at r 38 on bearings 15, 105 and 195 | 1 light each |
| Sarcophagi | 8 pairs at r 30 on bearings 22.5 + 45k; each pair about 7 × 7 × 2.4 | Cover |

**Anchors:** ribs 57; pillars 57; outer wall 26 and pilasters 27; star-chain cores 30–40.

**Swing gate (fan, §1.5):** 60 points (12 skipped: the 12 grid points at r 50, all under the gallery deck, underside 7.6), **0 fail**, all 60 of them 4 of 4. Jitter-weak: 0. The revision 4 geometry failed 8 points, (±40, ±10) and (±10, ±40), each with 1 facing.

**Pads** (11, 4 boss; min gap 0.5 u)

| | | | |
|---|---|---|---|
| (28.3, 28.3) B | (−28.3, 28.3) B | (−28.3, −28.3) B | (28.3, −28.3) B |
| (24, 0) | (0, 24) | (−24, 0) | (0, −26, h 3), dais top |
| (42, 0) | (0, 42) | (−42, 0) | |

**Height:** dais 3, gallery 8, star chains, ribs.

**Budget: 324 parts / 13 lights** (budget 340 / 16)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Pillars | 48 | 0 |
| Ribs and rings | 36 | 0 |
| Dais | 15 | 1 |
| Inlays | 4 | 0 |
| Gallery (12 decks, 12 caps, 12 rails, 12 posts, 8 ramps, 8 landings) | 64 | 0 |
| Wall and niches | 32 | 0 |
| Clerestory strips (decor) | 12 | 0 |
| Pilasters | 12 | 0 |
| Gate braziers | 4 | 4 |
| Crystals | 20 | 4 |
| Braziers | 6 | 3 |
| Sarcophagi | 32 | 0 |
| Star chains (4 cores, 4 stars) | 8 | 0 |
| **Total** | **324** | **13** |

### 3.4 Kyoto Imperial Academy: "The Walled Compound" (dusk, blossom)

**Octagonal wall (upper loop, h 6.5)**
- Apothem 54, flats centred on bearings 45k (yaw −b), each flat 44.7 long.
- 3 thick (inner face at apothem 52.5) and 6.5 tall. Wall-walk 3 wide.
- **Outer rail:** 8 × 46.0 u (= 2·55.5·tan 22.5°) at apothem 55.35, closing at the vertices, with 3 u gaps at the tower trusses.
- **Corner bastions (new):** 8 blocks 5 × 5, h 0 → **6.6**, centred at **r 59.5 on bearings 22.5 + 45k, yaw −b**, so their radial span is r 57–62 and tangential span ±2.5.
  - **The crack is covered.** A 44.7 u flat ends 0.64 u short of the true outer corner, which leaves a crack at the outer face 1.28 u wide. In bastion coordinates that crack lies within ±0.64 lateral and r 58.45–60.07.
  - **The inner overlap is covered.** The flats' coplanar inner overlap lies between r 56.83 and 58.45 and is hidden under the bastion top, apart from a sliver 0.17 u deep near the inner vertex.
  - **The bastions never enter the courtyard.** Their innermost corners, for example (19.50, 53.62) and (24.12, 51.70) at bearing 67.5, stay beyond apothem 52.5 of some flat.
  - The walk crosses the bastion top with a 0.1 u step. Each bastion stands 1.9 u proud of the outer face.
  - Colour: stone RGB(118, 112, 104) Cobblestone, with the top paved flush like the wall-walk. There is no decor on the walking surface.

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| Main gate | S flat: an 8 u gap (x −4..4) bridged by the gatehouse deck at x −4..4, z 52.5..55.5 (underside 6, top 6.5), with a roof on 4 posts to 10. **Stair flights** (3 wide, rise 6.5, run 11.4) on the inner face at **x ±(7..18.4), z 49.5..52.5**: the foot is at x ±18.4 and the run bearing is 180 for the east flight and 0 for the west. **Landings** are solid blocks 3 × 3 at **x ±(4..7), z 49.5..52.5, h 0 → 6.5**, flush with the S wall-walk (z 52.5..55.5) and with the gatehouse deck. Each landing has a **Rail on its gate-facing edge** at x ±4.15, from z 49.5 to 52.5, h 6.5–7.6. Landing: plaster RGB(232, 226, 214) SmoothPlastic. | Opening 8 × 6. You climb west (east flight) onto the landing, turn south onto the wall-walk, and turn again onto the gatehouse deck. The last torii's beam (z 47.75..48.65, x ±4.5) is 0.85 u north of the landing. The (±24, 32) B boxes end at z 40, 9.5 u away. |
| **Watchtowers** (B5) | Outside the wall at the diagonal flats' midpoints, apothem 58.5: (±41.4, ±41.4). The door is at the wall-walk. **The truss is on the tower's inner face, standing on the wall-walk: h 6.5 → 13, 16 studs** (the outer rail has a 3 u gap there). Roof at 20. | |
| Wall accesses (9; max gap about 20 u) | Tangential ramps (3 × 11.4) with 3 × 3 landings, centred at (51, 0), (−51, 0) and (0, −51). **Tower ramps** (3 × 11.4 plus a 3 × 3 landing) run along the diagonal flat at apothem 51, from the foot toward the tower to the top and landing toward the E or W vertex. Run bearings: **(43.1, 29.0) 315°; (43.1, −29.0) 45°; (−43.1, 29.0) 225°; (−43.1, −29.0) 135°.** Plus the 2 gate stairs. | The landing's far end reaches 18.7 u along the flat from its midpoint. Pad (45, −14)'s box corner is at 21.9, which leaves a 3.2 u gap. |
| **Five-Tier Pagoda** (hero) | (0, −38): base 12 × 12 (x −6..6, z −44..−32), 6 u per tier, top at 36. Ledge 16 × 16 at h 6 with rails. Stair 6 wide at z −30..−19.5. | |
| Thousand-Gate Path | 8 torii (posts x ±3, yaw 0) at **z 16 + 4.6k**, up to **48.2** | Respaced so the last beam clears the gate landings |
| Lecture halls (B4) | **18 × 12**: x ±(20..38), z −20..−8 | Shortened 2 u to free (±45, −14) |
| **Bamboo grove** | 36 canes 0.5 across, 14–22 tall, plus 18 tufts (decor). Seeded in the SW quadrant (x −50..−20, z 4..34, apothem ≤ 49.5), rejected inside pad boxes plus 0.5, which leaves the (−36, 20) clearing | |
| Pond garden | Water r 9 at (36, 18); red arch at x 36, z 10..26; tea pavilion (§2.3) on a deck at x 32..40, z 0..8; 4 rocks | |
| Old cedars (h 34, core 32.3) | (±38, −28), (±20, 44), (±46, 4), (±14, 10) | |
| **Ring cedars** (8, new) | h **44** (core hit 41.8; crown balls of diameter 11.4 / 9.2 / 6.6 centred at h 27.3 / 33.9 / 39.6). Outside the wall: **r 63** on bearings **0, 56.25, 123.75, 180, 236.25, 303.75**, which puts them at (63, 0), (35.0, 52.4), (−35.0, 52.4), (−63, 0), (−35.0, −52.4) and (35.0, −52.4); and **r 67** on bearings **45 and 135**, at (47.4, 47.4) and (−47.4, 47.4), behind the two south watchtowers. Same trunk and crown build and colours as §2.3. | Each trunk is at least 6.3 u outside the outer wall face (apothem 55.5) and at least 4.7 u from a bastion or tower. The crowns start at h 21.6, well above the walk (6.5) and the tower roofs (20). They replace 8 of the 12 decor backdrop cedars. **Why:** from r 40–50 the outward facings saw only the 6.5 u wall and bastions, and the 20 u towers sat in the blind wedge. The ring gives every outward facing a crown at 22–38. |
| Blossom trees | 14 seeded at r 22–30 | |
| Stone lanterns | 8 at r 24 on bearings 22.5 + 45k | |
| Backdrop | 4 decor cedars (was 12); mountains | |

**Anchors:** pagoda 36; towers 20; old cedars 32.3; ring cedars 41.8, with crowns.

**Swing gate (fan, §1.5):** 52 points (20 skipped: on the pagoda stair and ledge, inside the lecture halls and tea pavilion, on the wall-access and tower ramps, and (0, 30) under a torii beam), **0 fail**, 43 of them 4 of 4. Jitter-weak: 2, at (0, 20) and (0, 50), both on the torii path. The revision 4 geometry failed 3 points: (±40, −10) and (30, 0). The reviewer's (±40, 30) and (±50, 0) lie on the tower ramps and the E/W wall-access ramps, so they are skipped. They pass anyway if counted: 4 of 4 and 3 of 4.

**Pads** (11, 4 boss; min gap 1.0 u)

| | | | | |
|---|---|---|---|---|
| (26, −30) B | (−26, −30) B | (24, 32) B | (−24, 32) B | (15, −28) |
| (−15, −28) | (24, 0) | (−24, 0) | (−36, 20), bamboo clearing | (45, −14) |
| (−45, −14) | | | | |

**Height:** wall-walk 6.5, towers 13, pagoda ledge 6, tea deck 1.5.

**Budget: 462 parts / 18 lights** (budget 500 / 21)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Wall (8 flats, 8 outer rails, 2 gate returns) | 18 | 0 |
| Corner bastions | 8 | 0 |
| Ramps and landings | 14 | 0 |
| Gate stairs (2 × 9), gate landings (2), landing rails (2) | 22 | 0 |
| Gatehouse | 7 | 1 |
| Towers | 40 | 4 |
| Pagoda | 24 | 1 |
| Torii | 32 | 0 |
| Halls | 28 | 2 |
| Bamboo | 54 | 0 |
| Pond | 20 | 1 |
| Blossoms | 56 | 0 |
| Lanterns | 16 | 8 |
| Old cedars (8 × 5) | 40 | 0 |
| Ring cedars (8 × 5) | 40 | 0 |
| Backdrop (4 decor cedars × 3) | 12 | 0 |
| **Total** | **462** | **18** |

### 3.5 Survival Colony: "The Sealed Block" (dusk, ash)

**The Broken Overpass (upper U, h 7)**
- `chordRing{ b0 = 180, b1 = 360, n = 8, rIn = 40, rOut = 48, top = 7, t = 0.8, capW = 6 }`.
- **8 chord decks of 15.9 × 8** (2·40·tan 11.25° = 15.91) at r 40–48, centred on bearings 191.25 + 22.5k, yaw −b. Top at 7, underside 6.2.
- **9 piers, each 2 × 2 × 7**, at r 44 on the joint bearings 180 + 22.5k.
- **9 pier caps ("expansion plates") 6 × 0.5 × 8.94**, one on each joint bearing, yaw −b.
  - Each runs radially from r 40 to 48.94 (= 48 / cos 11.25°, the outer vertex), at h 6.6–7.1, so it is 0.1 u proud of the deck.
  - The widest V between two decks is 3.2 u at the outer edge (±1.6 around the joint), inside the cap's ±3.
  - Caps: DiamondPlate RGB(88, 90, 94). Decks: Concrete RGB(128, 124, 118).
- **Concrete rails on both edges:**
  - Outer rails are 8 × **19.1 u** at r 47.85 and inner rails 8 × **16.0 u** at r 40.15, so both rail lines close at every joint.
  - Gaps: outer rails at the two on-ramps (8 u, centred on 354° and 186°); the switchback top (4 u, from 0 to +4 u clockwise of the 247.5° joint); and the 2 trusses (3 u, centred on 202.5° and 337.5°). Inner rail at the Fallen Span (8 u, centred on 303.75°).
- Check: along every deck, samples at r 40.1, 44 and 47.9 and on each joint bisector out to r 48.8 all land on a deck or a cap (spec check 2b).
- Pads: the 337.5° and 225° caps overlap the (32, −12) and (−22, −22) boxes in plan only. At h 6.6 they are 1.3 u above the normal-pad headroom of 5.3, exactly like the deck underside at 6.2.

**Accesses** (6; max gap about 21.6 u)
- **Radial on-ramps**, 8 wide, rise 7, running outward from r 48 to r 60.25 on bearings **354°** and **186°**.
- **Fallen Span:** an inward spur from the inner edge at (22.2, −33.3, h 7) down to (14.4, −21.6), 8 wide, 26.6° slope, **run bearing 303.7** (from foot to top). The loop above it stays whole. It clears the caps at 292.5° and 315° by at least 1.3° at r 40.
- **Switchback** (w 4, rise 7) running outward from r 48 on bearing 247.5, footprint 8 × 10.1.
- **Trusses** (18 studs, 7.5 u) **on the deck's outer edge**, facing inward, on joint bearings 202.5° and 337.5°, centred at r 49.36 so they touch the cap end at 48.94.
  - They are at (−45.6, −18.9) and (45.6, −18.9). In revision 3 they stood against the piers under the deck, so climbing them ended at the deck underside.

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| Sign gantries (cantilever) | On joint bearings 225° and 315°: **1 mast 1.2 × 1.2 × 22 at r 50.2**, yaw −b, at (∓35.5, −35.5). **Beam 11 × 1 × 1** (top 22) from r 39.5 to 50.5 over the deck. **Sign panel 8 × 3 × 0.3** hanging under the beam at h 16–19, with a SurfaceGui ("EXIT 7", "ZONE CLOSED") in white on RGB(24, 96, 60) Road-green, plus 1 PointLight. Steel: RGB(120, 124, 130) Metal. | Replaces the 2-post frame: a post at r 39 on 225° would have stood inside pad (−22, −22)'s box, whose corner is at r 39.6. The beam is the crossarm. Anchor: r 44, top 22. |
| **Headcount Board** (hero) | (0, −30): board 20 × 10 from h 12 to 22, text "BLOCK 01 · HEADCOUNT". Legs are 2-truss pairs at x ±9 (z −30.5..−29.5, 30 studs). Catwalk 20 × 2 at h 12 on the south face, reached by the legs. | |
| **Container Yard** (SE) | See the table below | Court at (28, 31) |
| The Leaning Block | **Arcade** (B3, 14 × 10, roof 9): built upright on x −45..−31, z 28..38, then the whole model is rolled **6° about the +Z axis through the pivot (x −31, h 0)**, the east bottom edge: `pivot * CFrame.Angles(0, 0, math.rad(6)) * pivot:Inverse()`. The west side sinks 1.46 u into the ground, and the roof slopes from h 8.95 at x −31.94 down to h 7.49 at x −45.86 (6°, walkable). Its footprint is an OBB of x −45.9..−31, z 28..38, h −1.5..8.95. **Annex** x −30..−22, z 28..38, h 6. **Rubble ramp** x −28..−24, z 38..48.5, run bearing 270, onto the annex. **Stairs** (rise 3, 3 wide) on the annex roof, z 29..32, foot at x −25.2, top at x −30.45 at h 9, run bearing 180. **Stair plate** 2 × 0.4 × 3 (solid, yaw 0) at x −32.4..−30.4, z 29..32, top 9: it bridges the 1.5 u gap to the leaning roof edge and sits 0.1 u above the roof. Arcade: brick RGB(120, 72, 58); annex: Concrete RGB(110, 108, 104). | Pads: (−40, 13) B's box ends at z 21, 7 u from the block. |
| Scrap Market | Rows at **x −40 and −32**, stalls at z −14, −8, −2 (footprint z −16..0) | |
| **Quarantine fence** | 10 pylons (1.6 × 14 with an amber neon head) at r 100. **Beams** between neighbouring pylons: amber, `LightEmission 1`, width 20 studs, Transparency 0.6, 0 parts. | Replaces the dome |
| Floodlight masts (22) | (±48, 24), (±24, 46), each with a crossarm pair at h 20.5–21 | |
| **North floodlights** (2, new) | At **r 54 on bearings 255 and 285**, i.e. (−14.0, −52.2) and (14.0, −52.2). Each is a mast 1.2 × 1.2 × 24, steel RGB(60, 64, 70) Metal, topped by a **lamp bank**: a Core-set panel 0.6 (radial) × 3 (tall) × 6 (tangential) at h 21–24, yaw −b, facing C, in the same steel. The lamp bank has a decor neon face 5.6 × 2.6 in RGB(255, 236, 190) and 1 SpotLight (Range 60, Angle 50, aimed at C). | They stand 2.3 u clear of the switchback footprint (bearing 247.5) and 7 u clear of the (0, −66) tower. They give the south yard's N facings, and (±10, −20), a wide target in the blind band between the Board and the gantries. |
| **Block cistern** (water tower, new) | Centred at **(0, 20)**. 4 legs 0.8 × 0.8 × 17 at (±2.8, 17.2) and (±2.8, 22.8), steel RGB(120, 124, 130) Metal. **Tank:** Cylinder 9 across, **h 17–23**, stood upright with `CFrame.Angles(0, 0, math.pi/2)`, rusted steel RGB(112, 84, 64) CorrodedMetal, with a SurfaceGui stencil "01" in RGB(230, 226, 214). **Cap:** Cylinder 5.4 across, h 23–25, RGB(90, 70, 56) CorrodedMetal. Ladder (decor) on the north leg pair. | This is the SE yard anchor the reviewer asked for, placed centrally so that it also serves the south court. The open legs are cover-light and do not block the lanes. Pad clearances: (0, 40) B's box is 7.5 u away, (−14, 28)'s box 3.5 u, and (22, 6)'s box 13 u. The tank underside is at 17, one unit above the 16 u gate, so the points beneath it, (0, 20) and (0, 30), count and pass: their N facings hit the underside at 17. |
| Burning barrels | (±13, ±13) | 2 lit |
| Cover | 14 wrecked cars, 10 jersey barriers, 12 rubble blocks (seeded, with rejection) | |
| Skyline | **10 fixed towers 14 × 14 × 34** at (±64, −4), (±52, −40), (0, −66), (±34, 62), plus 3 new ones upright at **r 68 on bearings 30, 90 and 150**: (58.9, 34.0), (0, 68) and (−58.9, 34.0), yaw −b. The new three have the same build as the first seven: Concrete RGB(92, 90, 88), 2 dead window bands (decor) and a roof clutter block. There are also 15 seeded tilted towers at 70–110 (not counted as anchors). Each is placed at `CFrame.new(around(b, r)) * CFrame.Angles(0, -math.rad(b), 0) * CFrame.Angles(0, 0, -math.rad(tilt)) * CFrame.new(0, h/2, 0)`, with tilt = rng(4, 10), so it leans outward about its tangential axis. | |

**Container Yard** (each container 6 × 2.5 × 2.6)

| Container | Footprint | Height | Access |
|---|---|---|---|
| A | x 17.75..20.25, z 24..30 | G stacked on it, top 5.2 | Ramp to G faces **west**: x 8.65..17.75, z 25.5..28.5, rise 5.2 |
| B | x 17.75..20.25, z 30.5..36.5 | 2.6 | |
| C | x 35.75..38.25, z 24..30 | 2.6 | |
| D | x 35.75..38.25, z 32..38 | H stacked on it, top 5.2 | Ramp to H faces **east**: x 38.25..47.35, z 33.5..36.5 |
| E | x 25..31, z 19.75..22.25 | 2.6 | Ramp faces **north**: x 26.5..29.5, z 15.2..19.75 |
| F | x 25..31, z 39.75..42.25 | 2.6 | |

**Anchors:** board 22; gantries 22; floodlights 22 (crossarms); north floodlights 24 (lamp banks); the cistern tank 17–25; the 10 fixed towers 34.

**Swing gate (fan, §1.5):** 52 points, **0 fail**, 35 of them 4 of 4. Jitter-weak: 1, at (−30, 40).
- **Skipped: 20.** 13 are **under the overpass decks and caps** (the 13 grid points at r 40–48 on the north half; the rule in §1.5 skips them because the underside is at 6.2–6.6). 3 are under the Headcount Board. The other 4 are on the Fallen Span, inside the arcade, at the annex edge, or on the edge of container A.
- **Revision 4 failed 12:** (±50, 0), (±30, 0), (−40, 20), (−30, 40), (−20, 30), (±10, 20), (0, 20), (0, 30) and (30, 40).
- The reviewer's (30, 20) and (30, 40) now pass 4 of 4, getting 23–29 from the cistern, the new (58.9, 34) tower and the (48, 24) mast.

**Pads** (10, 3 boss; min gap 1.0 u; none under the deck)

| | | | | |
|---|---|---|---|---|
| (0, 40) B | (40, 13) B | (−40, 13) B | (28, 31), yard court | (−22, −22) |
| (32, −12) | (0, −23) | (−14, 28) | (−20, −2) | (22, 6) |

**Height:** overpass 7, catwalk 12, containers 2.6 and 5.2, annex 6, arcade about 9.

**Budget: 431 parts / 20 lights** (budget 460 / 24)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Overpass (8 decks, 9 piers, 9 caps, 16 rails, 2 ramps, span, switchback, 2 trusses) | 52 | 0 |
| Gantries (2 × mast, beam, sign) | 6 | 2 |
| Board | 8 | 1 |
| Yard | 23 | 0 |
| Leaning Block (with the stair plate) | 24 | 1 |
| Market | 30 | 3 |
| Fence pylons | 20 | 0 |
| Floodlights (with crossarms) | 16 | 4 |
| North floodlights (2 × (mast, lamp bank, neon face)) | 6 | 2 |
| Cistern (4 legs, tank, cap, ladder) | 7 | 0 |
| Barrels | 4 | 2 |
| Wrecks | 56 | 0 |
| Jersey barriers | 10 | 0 |
| Rubble | 12 | 0 |
| Skyline (10 × 5 + 15 × 4) | 110 | 0 |
| Lamps | 16 | 4 |
| **Total** | **431** | **20** |

### 3.6 Dunewatch: a caravan ksar (noon)

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| Well Square | Sundial inlay (decor). **4 gnomon pillars** (new): 4 × 4 × 30 at **r 15 on bearings 45 + 90k**, which puts them at (±10.6, ±10.6). Sandstone RGB(206, 170, 120), each with a bronze cap (decor, 4.4 × 0.6 × 4.4, RGB(140, 110, 60) Metal) and a neon hour-notch strip (decor). | These are the R1 inward anchors. The inner corners are at r 12.2, outside R0. Clearances: (11, 20)'s and (−14, 20)'s boxes are 1.4 u away, (8, −22)'s 3.4 u, and the souk street (z −3..3, x ≥ 14) 5.6 u. |
| **Covered Souk** | Street z −3..3, **x 14..40**. 6 stalls at x 18, 26 and 34 on both sides (counters at z ±3.75..±5.25). Awnings at h 5 and 4 beams, all decor. | No pads |
| **Quarters** | 24 × 24 blocks centred at **(30, −24), (−30, −24) and (30, 26)**. Each holds 4 B6 houses of 9 × 9 at (cx ± 7.5, cz ± 7.5), with 6 u alleys. | |
| **Citadel** (hero) | Lower terrace x −12..12, z −52..−36, h 4. Upper terrace x −8..8, z −51..−41, h 8. **Signal tower** 5 × 5 at (0, −48), top 38, with `Fire` and 1 light. | See access below |
| Cistern Oasis | Pool r 8 at (−28, 26). Palms at (−38, 26), (−35.1, 33.1), (−35.1, 18.9), (−28, 36), (−28, 16), **(−20, 30)**. Pergola 8 × 8 at (−14, 38). **Oasis masts (22)** at (−48, 30) and (−18, 46), each with a crossarm pair. | |
| Edge | 8 wall fragments 8 × 1 × 2.4 at r 52 on bearings 30, 110, 140, 170, 200, 220, 320, 340. Rock terrain ring at 70–86, open to the south. | |
| Caravan masts | **(±10, 56) h 22** and **(±12, −58) h 20**, each with a crossarm pair (top 1 u below the mast top). Mast: timber RGB(110, 78, 50) Wood; crossarms: RGB(120, 124, 130) Metal. | The farthest crossarm end is at (14.1, −60.1), r 61.8, which sets the hill clearance below |
| Cover | 16 crates, sacks and pots (seeded, with rejection) | |
| **Ksar towers** (replace the r 82 backdrop towers) | 8 corner towers (burj), **7 × 7 × 30**, at **r 60 on bearings 22.5 + 45k** (r **62** on 67.5 and 112.5), yaw −b, `backdrop = true, keep = true`. Mudbrick RGB(196, 150, 100) Sandstone, with a stepped crenellation band (decor, 7.4 × 1 × 7.4, h 30–31) and 2 slit-window strips (decor). | Each sits in its own hill keep-out sector: its angular half-extent is 3.6°, and the halfWidth is 5. The two south towers move out to r 62 so they clear pad (20, 45)'s box by 1.7 u; at r 60 one corner would stand 0.14 u inside it. They are the outer ring of the §1.5 pattern. |
| **Dovecotes** (3, new) | Pigeon towers 4.5 × 4.5 × 26 at **(36, −43), (−4, 23.5) and (−35.5, −6.5)**. Mudbrick RGB(186, 140, 92) Sandstone, with a decor band of pigeon holes (dark RGB(60, 44, 30) dots on a SurfaceGui) at h 20–24 and a flat cap. | They fill the gaps the ring and gnomons leave: the NE lane behind the quarter, the south Well Square approach and the west lane. Clearances: (22, −44)'s box 5.75 u, (−14, 20)'s 1.55 u, (−38, 6) B's 2.05 u, and the NE B house 4.75 u. |

**Citadel access**
- **Ramp 1:** 8 wide, x −4..4, z −36..−29, south face.
- **Ramp 2:** a tangential ramp on the east strip, x 8..12, rising north from z −36 to −43 (h 4 → 8), with a **4 × 4 landing at x 8..12, z −47..−43, h 8** flush against the upper terrace.
- **Ramp 3** (back stair): x −2..2, z −59..−52, running down to the north.

**Rooftop network (h 5–7.4)**

Roof heights by quarter. "A" is the 5 u house nearest the citadel or centre.

| Quarter | 5 | 6.2 | 7.4 | 6.2 |
|---|---|---|---|---|
| NE | A (22.5, −31.5) | B (37.5, −31.5) | C (37.5, −16.5) | D (22.5, −16.5) |
| NW | A′ (−22.5, −31.5) | (−37.5, −31.5) | (−37.5, −16.5) | (−22.5, −16.5) |
| SE | (22.5, 33.5) | (37.5, 33.5) | (37.5, 18.5) | (22.5, 18.5) |

- **Within each quarter:** 4 plank bridges of 6 u rising 1.2 (11°).
- **Ramps:** each quarter has a ramp (3 wide, rise 5) onto its 5 u house, running out from the house's west face (the east face for NW):
  - NE: x 9.25..18, z −35..−32
  - NW: x −18..−9.25, z −35..−32
  - SE: x 9.25..18, z 33..36
- **Outer trusses:** on each 7.4 u house's outer face, at x 42 (NE, SE) and x −42 (NW).
- **Souk link:** 2 rope bridges of 26 u at **x 24.5** (6.2 ↔ 6.2) and **x 35.5** (7.4 ↔ 7.4). They moved 2 u toward the quarter centre lines to clear the new windcatchers by 0.5 u.
- **Souk-facing trusses:** at **(26.6, −11.6) and (26.6, 13.6)**, on the D houses' souk faces east of the bridge landings. The bridge midpoints are within 13 u of an access.
- **Outer trusses:** on the 7.4 u houses' outer faces at **z −19 (NE, NW) and z 21 (SE)**, clear of the corner windcatchers.
- **Windcatchers (all 12 houses, revised):** each is **4.5 × 4.5**, from the roof to **h 26**, Sandstone RGB(206, 170, 120), with 2 vents (decor).
  - On the 3 **A houses** (the 5 u houses with the ramps) it stands at the **roof centre**. That leaves a 2.25 u walkway round it, and the ramp arrives on the west face.
  - On the other 9 it stands **flush in the roof's outer corner**, the corner away from the quarter centre, so its centre is (hx ± 2.25, hz ± 2.25), for example (39.75, −33.75) on NE B. No plank bridge, ramp or truss lands in an outer corner. Each plank bridge lands at the centre of an inner edge, 4.5 u from the windcatcher, and the souk rope bridges pass 0.5 u beside it.
  - Swing gate reason: the alley points (x = ±30 and z = −24 / 26) see an outer-corner windcatcher 30–60° off-axis, which the fan samples. A centred one sits dead ahead or in the blind wedge.

**Hills** (`hills()` is called 30 times for dunes; §4.1):
- `hills = { minGround = 66, keepOut = { { bearing = 90, halfWidth = 30 }, { bearing = 22.5, halfWidth = 5 }, … one per ksar tower on 22.5 + 45k } }`.
- The largest non-backdrop footprint radius is 61.8 (caravan-mast crossarms at (±12, −58)), and 61.8 + 4 = 65.8 ≤ 66. The next largest are citadel Ramp 3 at 59.0 and the south masts at 57.8.
- The south sector keeps the caravan approach, the rock ring's gap, open.

**Anchors:** signal tower 38; ksar towers 30; gnomons 30; windcatchers 26; dovecotes 26; caravan and oasis masts 20–22 (crossarms). Palms are not counted.

**Swing gate (fan, §1.5):** 53 points (19 skipped: inside houses, on the citadel terraces and ramps, or on the quarter ramps), **0 fail**, 39 of them 4 of 4. Jitter-weak: 3, at (±20, −10) and (20, 40). **The revision 4 geometry failed 36 of 53.** It was the worst world: roofs at 5–7.4, 3.5 u windcatchers at house centres, and no ring. The ring, gnomons, corner windcatchers and dovecotes were chosen by a search over the fan, not by eye.

**Pads** (10, 3 boss; min gap 1.0 u)

| | | | | |
|---|---|---|---|---|
| (0, 40) B | (−38, 6) B | (48, −2) B | (8, −22) | (−8, −22) |
| (11, 20) | (−14, 20) | (20, 45) | (22, −44) | (−22, −44) |

**Height:** roofs 5–7.4, terraces 4 and 8; windcatcher tops by flight only.

**Budget: 378 parts / 9 lights** (budget 400 / 12)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav, sundial | 33 | 1 |
| Gnomons (4 × (pillar, cap, strip)) | 12 | 0 |
| Souk (6 stalls, 4 beams) | 34 | 3 |
| Quarters | 111 | 0 |
| Trusses | 5 | 0 |
| Windcatchers (12 × 3) | 36 | 0 |
| Dovecotes (3 × (tower, cap)) | 6 | 0 |
| Rope bridges | 10 | 0 |
| Citadel (3 blocks, tower, fire, 3 ramps, landing, 3 rails) | 12 | 1 |
| Oasis | 35 | 0 |
| Wall fragments | 8 | 0 |
| Cover | 16 | 0 |
| Masts (6 × (2 + 2 crossarms)) | 24 | 2 |
| Ksar towers (8 × (tower, crenellation, window strips)) | 24 | 0 |
| Oil lanterns | 12 | 2 |
| **Total** | **378** | **9** |

### 3.7 Quarry Hollow (afternoon)

**Setting:** a canyon bowl of Rock terrain, made by `hill()` beyond **r 60**: `hills = { minGround = 60, keepOut = { { bearing = 90, halfWidth = 12 } } }`, so the view south through the Stone Gate stays open. The largest non-backdrop footprint radius is 55.8 (the bench corner (54, 14)) and the Stone Gate is at 55.6, so 55.8 + 4 = 59.8 ≤ 60.

| Piece | Position and size | Notes |
|---|---|---|
| **Four Stacks** | 10 × 10 × 28 at (±22, ±22); cliff-dwelling windows (decor) | **Gallery** at h 10: 3 u strips, so each gallery spans 16 × 16. **Switchback** (w 4, rise 10, footprint 8 × 12.75) starting at the gallery's outer x edge and running outward: x ±(30..42.75), z = stack z ± 4. |
| Rock needles | (22, 0), (−22, 0), (0, 22), (−10, −22): core 4 × 4, cap 5 × 5 at h 10, spike to 14 | Reached only by bridges |
| **Rope Ring** (h 10) | 8 rope bridges. **Real spans from the gallery edge to the cap:** E, W and S pairs 11.5 u each; north 1.5 u (NW gallery to the needle at (−10, −22)) and 21.5 u (that needle to the NE gallery) | |
| Quarry benches | x ±(40..54), z −14..14, h 2. Glacis x ±(36.5..40). Shed (B3) on the bench at z −14..−4, roof at 11. **Hoist headframe (new):** one per bench, a timber tower **4 × 4, from the bench (h 2) to h 30**, at **(±51, −11)** (x ±(49..53), z −13..−9). It rises through the shed's outer end, with a sheave wheel on top (decor: Cylinder 3 across × 0.5, RGB(60, 64, 70) Metal). Timber RGB(110, 78, 50) Wood. | The shed roof keeps 10 × 10 of walkable area west of it, and the truss is unchanged. Pad (±47, 6) B's box ends at z −2, 7 u away. **Why:** from (±50, 0) on the bench, the shed filled the north facing (8.0) and the glacis and needle hits stayed below 16 on the west. The headframe's south face is 9 u north of the point, and the point's 59° and 66° rays hit it at h 18.5 and 23.7, which is 16.5 and 21.7 above the bench. |
| **Quarry Crane** (hero) | A-frame base x −4..4, z −49..−43, **top at 40**. Jib 1 × 1 × 24 at h 38 from z −52 to −28 (solid, an anchor). Counterweight 3³ at z −52, h 34–37. **Hook block 3 × 3 × 3 at (0, −34), h 20–23** (solid). Rope (decor). | The hero sightline (eye h 3.0) passes over the N rope bridge at h 13.0 and 1.5 u under the hook |
| Stone Gate | Piers 4 × 4 × 18 at x ±13 (x ±(11..15)), **z 49.5..53.5** (moved 4.5 u in from 54..58 to clear the hills); lintel x −15..15, h 18–20 | Flight-only perch. Pads (±14, 36) B end at z 44, 5.5 u away. The anchor moves nearer to every grid point (all have z ≤ 50), so coverage can only improve. |
| Backdrop needles (5 × 5, yaw −b) | r 50 at bearing 30 (h 34), 150 (44), 210 (38), 330 (36); **r 52** at bearing 60 (40), 120 (30), 240 (32), 300 (42) | **Revision 5:** the four needles on 60/120/240/300 moved out 2 u. At r 50, each one's inner corner touched the nearest (±14, ±36) B box (gap 0.0). The gap is now 0.58 u, and the corner radius is 54.6, inside the hill clearance. |
| Detail | 24 boulders and 12 cut blocks (seeded, with rejection); ore carts; 6 pole lanterns | |

**Anchors:** stacks 28; crane 40; hook 23; gate 20; needles 30–44; headframes 30.

**Swing gate (fan, §1.5):** 46 points (26 skipped: inside the stacks and needles, under the galleries and rope bridges, on the switchbacks and inside the sheds), **0 fail**, 32 of them 4 of 4. Jitter-weak: 0. The revision 4 geometry failed 2 points: (±50, 0) on the benches.

**Pads** (10, 6 boss; min gap 0.5 u)

| | | | | |
|---|---|---|---|---|
| (14, −36) B | (−14, −36) B | (14, 36) B | (−14, 36) B | (47, 6, h 2) B |
| (−47, 6, h 2) B | (30, 10) | (30, −10) | (−30, 10) | (−30, −10) |

**Height:** benches 2, galleries and ring 10, shed 11, gate lintel and jib by flight.

**Budget: 260 parts / 14 lights** (budget 280 / 16)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Stacks | 64 | 4 |
| Needles | 12 | 0 |
| Rope bridges | 40 | 0 |
| Benches | 30 | 2 |
| **Crane** | **9** | 1 |
| Gate | 3 | 0 |
| Backdrop needles | 8 | 0 |
| Boulders | 24 | 0 |
| Carts | 11 | 0 |
| Blocks | 12 | 0 |
| Lanterns | 12 | 6 |
| Headframes (2 × (tower, sheave)) | 4 | 0 |
| **Total** | **260** | **14** |

### 3.8 Mistreach: a stilt village (morning, fog 22–130)

| Piece | Position and size | Notes |
|---|---|---|
| **Lighthouse** (hero) | Tower r 3 at (0, −50), 32 tall. Gallery 9 × 9 at 26. **64-stud truss** at z −45.5..−44.67. Lamp room; cap. | **Beam**: a decor neon wedge 2 × 2 × 30, Transparency 0.6, **tagged `Spin`** with attribute `Spin = 20` (§4.1) |
| Plaza | Disc r 14 raised 0.5; inlay; 10 mooring posts (decor) at r 17 | |
| Canal | Water 6 wide on z = 0 from x 16 to the shore; arched bridges at x 26 and 42 (z −5.6..5.6) | |
| Tideline Walk | `chordRing{ b0 = -11.25, b1 = 348.75, n = 16, rIn = 55, rOut = 60, top = 0.3, t = 0.3, capW = 3.5 }`. That gives **16 decks 21.9 × 5** (2·55·tan 11.25° = 21.88) centred on bearings **22.5k**, yaw −b, so a deck spans the canal at bearing 0. **16 joint caps ("mooring plates") 3.5 × 6.17 × 0.5** on bearings 11.25 + 22.5k, spanning r 55 → 61.17, top 0.4. **Outer rails 16 × 23.9 u** (2·60·tan 11.25°) at r 59.85, timber style, with 3 u gaps at the 2 mooring piers. Planks: weathered wood RGB(128, 104, 80) WoodPlanks; plates: RGB(70, 74, 78) Metal. | Ground loop. **Top lowered from 0.4 to 0.3**, which is below the 0.3 u pad threshold: at 0.4 it clipped the outer corners of the (33, −36) B and (−33, −36) boxes. The plates clear those boxes by 0.76 u (303.75°) and 2.76 u (236.25°). |
| **Moorings** | 4 B7 houses at r 70, **22° apart**: E cluster on bearings −33, −11, 11, 33; W cluster on 147, 169, 191, 213. **12 u flat bridges** between decks (the gap is 12.7). A pier of 3 parts to the boardwalk. | 2 houses per cluster have net-loft balconies at h 6 (ladder, deck, 2 posts, rail) joined by a rope bridge |
| Fish Market | Stall rows along z ±4 at x −44..−28; drying racks at x −46 and −25 | |
| Shrine Grove | 6 pines at radius 6 around (28, 28), h 30, 32, 34, 36, 38, 32 (cores 28.5–36.1); altar 4 × 4 × 4; lantern | |
| Boatyard | Shed 8 × 8 × 7 at (20, −32), yaw 0. **Hulls: wedge pairs 4 × 6 × 2.5 at (12, −40) and (12, −26), yaw 0.** Each pair is 2 Wedges of Size (2, 2.5, 6) back to back, the left one at yaw 90 and the right at yaw −90, so the keel ridge runs along Z at x 12 and the overall box is x 10..14, z ±3 about the centre. Tarred hull RGB(46, 40, 36) Wood. | |
| Net-lofts | 6 × 6 at h 5 (14-stud truss) at (−22, 34), **(−28, 40)**, **(−38, 28)**; 2 flat bridges | |
| **Harbour masts** (22) | (46, −20), (48, 18), (20, 47), (−22, 48), (−48, 4), (−24, −44) (lit); **(−42, −8), (42, −30), (−4, 26), (−44, 18)** (unlit). Each has a crossarm pair (yardarms) at h 20.5–21. Mast RGB(96, 72, 52) Wood. | |
| Ferry pier | South to (0, 80), with a lamp | |
| Detail | 10 island trees, 12 rocks, 16 crates (seeded, with rejection); 6 boardwalk lamps (3 lit) | |

**Anchors:** lighthouse 32; pines 28.5–36.1 (crowns are now Foliage and queryable); 10 masts 22 (yardarms). The check covers 68 grid points with 0 uncovered.

**Pads** (10, 5 boss; all on land; min gap 0.6 u)

| | | | | |
|---|---|---|---|---|
| (32, −16) B | (33, −36) B | (0, 44) B | (12, 36) B | (0, −36) B |
| (30, 14) | (−32, 16) | (−32, −16) | (−12, 36) | (−33, −36) |

**Height:** net-lofts 5, balconies 6, lighthouse gallery 26 (by its truss); mast tops by flight only.

**Budget: 478 parts / 25 lights** (budget 510 / 28)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Lighthouse | 11 | 2 |
| Plaza | 13 | 0 |
| Canal bridges | 10 | 0 |
| Tideline (16 decks, 16 plates, 16 rails) | 48 | 0 |
| **Moorings** (per cluster: 36 houses + 9 bridges + 3 pier + 10 balconies + 5 rope = 63) | **126** | 8 |
| Market | 36 | 3 |
| Grove | 35 | 1 |
| Boatyard | 9 | 0 |
| Net-lofts | 24 | 0 |
| **Masts** (6 × 3 + 4 × 2, plus 10 × 2 yardarms) | **46** | 6 |
| Ferry pier | 9 | 1 |
| Trees | 40 | 0 |
| Rocks | 12 | 0 |
| Cover | 16 | 0 |
| Lamps | 12 | 3 |
| **Total** | **478** | **25** |

### 3.9 Thunderspire: a cliff monastery (storm, dusk)

| Piece | Position and size | Notes |
|---|---|---|
| Middle terrace | x −40..40, z −50..−20, h 3; glacis 8 wide at x −32, −16, 0, 16, 32 (z −20..−14.75) | |
| Upper terrace | x −20..20, z −56..−36, h 6; glacis at x −12, 0, 12 (z −36..−30.75) | |
| **Great Hall** (hero) | B4 26 × 14 at (0, −48), x −13..13, z −55..−41, top about 20. **Stupa spire** 4 × 4 at (0, −52) rising to **34**, with a bell and finial (decor). | |
| Rod towers | Base 4 × 4 × 14 (granite RGB(92, 94, 100) Slate), copper mast to 26 (RGB(184, 115, 51) Metal), **copper crossarm pair at h 24.5–25**, and a neon tip with a light, at (±30, −8), (±44, −30), (±18, 30), **(±32, 46)** | Prayer flags are Beams. The (±32, 46) crossarm ends reach r 59.0. |
| **Horn Pinnacles** | 14 × 14 × 40 at x ±(40..54), z −20..−6. **Ledge** 4 wide at h 8 on the inner face: x ±(36..40), z −20..−6. | See the ledge stair below |
| **Mid piers** | Deck 6 × 6 at h 7 at (±30, −26) (x 27..33, z −29..−23), on 4 posts standing on the terrace. **Ramp** from the terrace on the west face: x 20..27, z −27.5..−24.5, rise 4, run bearing 0 (east; mirrored 180). | **Bridge** (flat, 3 wide): from **(38, −19, h 8)** on the ledge to **(31, −26, h 7)** on the pier. Length 9.9 u, 5.8° slope, **run bearing 225** (mirrored: (−38, −19) → (−31, −26), bearing 315). The clear span, from ledge corner (36, −20) to pier corner (33, −23), is 4.2 u. It passes 4.6 u over the x 32 glacis top and stays 3.9 u from the (29, −39) B box. The pier rail has a 3 u gap at its NE corner. No bridge to the upper terrace. |
| Lower Court | **Pilgrim shelters (open B4 8 × 6) at (±16, 46)**; 12 cairns and 20 boulders (seeded, with rejection); 6 stone lanterns on the terraces | |
| Beyond | Snowfield beyond r 70. 10 rock spires, 6 × 6 × 20–34 (seeded height), at r 90 on bearings 18 + 36k, `backdrop = true` (hills may bank against them). 4 far outbuildings 6 × 6 × 8 at **r 84 on bearings 200, 235, 305, 340**, yaw −b, `backdrop = true, keep = true`. | |

**Ledge stair** (4 pieces), running west along the pinnacle's south face (z −6..−2):

| Piece | x (east side; mirrored for west) | Height |
|---|---|---|
| Ramp 1 | 58 → 51 | 0 → 4 |
| Landing | 51..47 | 4 |
| Ramp 2 | 47 → 40 | 4 → 8 |
| **Top landing** | 40..36 | 8, joining the ledge |

**Upper route (U):** ground → ledge stair → ledge (8) → bridge → pier (7) → pier ramp → middle terrace (3) → glacis → upper terrace (6). Ledge-stair run bearing: 180 on the east side (climbing west) and 0 on the west side.

**Hills** (36 slate hills, §4.1):
- `hills = { minGround = 66, keepOut = { { bearing = 200, halfWidth = 6 }, { bearing = 235, halfWidth = 6 }, { bearing = 305, halfWidth = 6 }, { bearing = 340, halfWidth = 6 } } }`.
- Largest non-backdrop footprint radii: rod-tower crossarms at (±32, 46) 59.0; tower base 58.8; ledge-stair Ramp 1 foot at (58, −6) 58.3; pinnacle corner (54, −20) 57.6. 59.0 + 4 = 63.0 ≤ 66, so no hill can reach the ramp foot or bulge through the pinnacle stair.

**Anchors:** pinnacles 40; spire 34; 8 rod towers 26 (crossarms). The check covers 68 grid points with 0 uncovered.

**Pads** (11, 5 boss; min gap 0.75 u)

| | | | | |
|---|---|---|---|---|
| (0, 40) B | (36, 14) B | (−36, 14) B | (29, −39, h 3) B | (−29, −39, h 3) B |
| (20, 6) | (−20, 6) | (0, −24, h 3) | (0, 26) | (38, 30) |
| (−38, 30) | | | | |

**Height:** terraces 3 and 6, piers 7, ledges 8; spire and pinnacle tops by flight.

**Budget: 214 parts / 18 lights** (budget 240 / 21)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Terraces and glacis | 10 | 0 |
| Hall | 14 | 1 |
| Spire | 3 | 0 |
| Rod towers (8 × (3 + 2 crossarms)) | 40 | 8 |
| Pinnacles (2 × (3 blocks + 4 stair pieces + ledge + rail)) | 18 | 0 |
| Piers (2 × (deck, 4 posts, ramp, rail)) | 14 | 0 |
| Bridges | 6 | 0 |
| Shelters | 12 | 2 |
| Cairns | 12 | 0 |
| Boulders | 20 | 0 |
| Lanterns | 12 | 6 |
| Spires and outbuildings | 22 | 0 |
| **Total** | **214** | **18** |

### 3.10 The Seam: "The Stitchyard" (midnight, finale)

**The Hem**
- Basalt terrain out to r 18, with a crimson inlay at r 18.
- **Nothing collidable at r < 26.** The nearest part is at r 34.5.
- `hero = { x = 0, z = -60, top = 70, ids = { "spindle" } }`: the Spindle (below).

**Nine Patches (terrain, 0 parts)**
- Patch θ covers bearings θ − 20 … θ + 20 from r 20 to 52. It is painted with **3 `FillBlock`s on sub-bearings b = θ − 13.33, θ and θ + 13.33**.
  - Each block is `workspace.Terrain:FillBlock(CFrame.new(C + around(b, 36, -0.8)) * CFrame.Angles(0, -math.rad(b), 0), Vector3.new(32, 1.6, 12.2) * STUDS, material)`: **yaw −b**, Size.X radial (r 20–52), Size.Z tangential (12.2 = 2·52·tan 6.67°, so the outer edge is covered), and one 4-stud voxel thick with its top at the floor.
  - Patches are filled in θ order 0 → 320, so each later patch overwrites the shared border. The crimson strips on θ ± 20 hide the voxel steps.
- Materials: Asphalt, Ground, Cobblestone, Slate, Concrete, Sand, Rock, Grass, Snow, each with its own `SetMaterialColor`. These colours are reset at every build (§4.1).
- Crimson seam strips (decor) run along the borders.

**Vignettes.** Each vignette sits inside **two 7 × 7 u squares centred on bearing θ − 9 at r 38 and r 46**, and its anchor stands at r 42 on that bearing.

| θ | Patch | Vignette (anchor) | Parts / Lights |
|---|---|---|---|
| 0 | City | crosswalk (decor), car, lamp, **pylon 20** with a crossarm pair | 15 / 2 |
| 40 | Academy | torii, lantern, **cedar core 28.5** | 11 / 1 |
| 80 | Colony | 2-high container stack, ramp to 5.2, **gantry 20** | 7 / 0 |
| 120 | Wind | house (roof 6) with ramp, **windcatcher 20** | 10 / 0 |
| 160 | Earth | **rock stack 20**, switchback to a ledge at 8 | 7 / 0 |
| 200 | Water | stilt deck at 5 with ramp, hut, **mast 22** with yardarms | 13 / 1 |
| 240 | Kyoto | 3-torii tunnel, **pagoda tiers 16** | 16 / 0 |
| 280 | Lightning (due north at (0.7, −42), in front of the Spindle) | **rod tower 26** with copper crossarms, rock horn 24 at bearing 266 | 6 / 1 |
| 320 | Star Vault | **2 star pillars 24** (r 42 at bearing 311, r 46 at bearing 316), crystals | 13 / 1 |

**Thread Walk (behind the spawn)**
- Runs along bearings **71 → 111 → 151 → 191** at r 42: container top (5.2) → roof (6) → ledge (8) → deck (5).
- 3 rope bridges with about **21.7 u** clear span, with crimson neon rope rails.
- Each end comes down by its vignette's ramp or switchback.

**Beyond**
- 18 sky threads (decor).
- 12 fragments at r 60–90. **Only the 4 at r 64 on bearings 20, 110, 200 and 290, h 26–34, are collidable** (anchors and perches). The other 8 are decor.
- **5 stitched pillars** 3 × 3 × 30 at r 56 on bearings 30, 90, 150, 210 and 330. The pillar on bearing 270 is replaced by the Spindle. The pillars on 30, 150 and 210 are lit.

**The Spindle (hero set piece, new).** A giant sewing needle standing through a thimble on a spool of crimson thread: the rift's stitch, drawn tight. It stands on the −Z axis behind the Lightning vignette, centred **(0, −60)**, entirely at r 53–67. It is built from generic sewing shapes, with no emblem and no lettering.

| Piece | Part and size (u) | Position (h is base–top) | Colour / material |
|---|---|---|---|
| Plinth | Cylinder, vertical axis, 14 across × 2 | h 0–2 | RGB(40, 36, 44) Basalt |
| Spool core | Cylinder 8 across × 10 | h 2–12 | RGB(120, 20, 44) Fabric (wound thread) |
| Spool flanges (2) | Cylinder 12 across × 1 | h 2–3 and 11–12 | RGB(120, 84, 52) Wood |
| Needle shaft | Block 2.4 × 48 × 2.4 | h 12–60 | RGB(196, 200, 210) Metal, Reflectance 0.2 |
| Eye sides (2) | Block 0.8 × 6 × 2.4 at x ±0.8 | h 60–66, leaving a 0.8 u slot | same as the shaft |
| Eye crown | Block 2.4 × 2 × 2.4 | h 66–68 | same |
| Tip (2) | Wedge 2.4 × 2 × 1.2 at z −60 ± 0.6, yaws 0 and 180, meeting in a ridge | h 68–70 | same |
| **Thimble** | Cylinder 6 across × 3, round the shaft | h 40–43 | RGB(181, 140, 60) Metal |
| Thread 1 | Beam (0 parts) from an Attachment under the eye crown, through the slot, to the spool top. Width 0.5 studs, RGB(220, 30, 70), LightEmission 1. | | |
| Thread 2 | Beam (0 parts) from the eye to an Attachment on the portal's top segment, CurveSize0 30 and CurveSize1 −10, so the thread swoops down into the rift | | same |
| Glow | 1 PointLight on the eye crown (Range 40, Brightness 2, crimson). 1 ParticleEmitter on the spool core (Rate 6, Lifetime 4, Speed 2, crimson motes, LightEmission 1). 1 `Highlight` on the needle group (OutlineColor RGB(220, 30, 70), FillTransparency 1, DepthMode Occluded). | | |

- **11 parts and 1 light.** All the parts are Solid.
- The **thimble** is the swing target, 6 u wide at top 43. The needle is a flight-only perch.
- **Hero sightline:** from the eye (0, 0, 3) to (0, −60, 42) = 0.6·70. It crosses the Lightning vignette at z −42 at h 30.3, which is 4.3 u over the rod tower (26), and crosses the far square at z −46 at h 32.9. The rod tower is no longer the hero.
- It clears the vignette's far square (z up to −49.5) by 3.5 u.

**Anchors:** 9 vignette anchors, 2 extra (the horn and the second star pillar), 5 pillars at 30, and the Spindle thimble at 43. A rule re-run with the pillar swapped for the Spindle leaves every grid point with at least 2 anchors. The check covers 65 grid points with 0 uncovered.

**Pads** (12, 3 boss; min gap 0.28 u)
- **Normal pads at r 28, bearing θ + 11:** (27.5, 5.3), (17.6, 21.8), (−0.5, 28.0), (−18.4, 21.1), (−27.7, 4.4), (−24.0, −14.4), (−9.1, −26.5), (10.0, −26.1), (24.5, −13.6).
- **Boss pads at r 44, bearing θ + 11, for θ = 0, 280, 320:** (43.2, 8.4) B, (15.8, −41.1) B, (38.5, −21.3) B.

**Budget: 254 parts / 15 lights** (budget 280 / 18)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Hem and strips | 11 | 0 |
| Vignettes (with crossarms) | 98 | 6 |
| Thread Walk | 15 | 0 |
| Threads | 18 | 0 |
| Fragments | 60 | 4 |
| Pillars (5 × 2) | 10 | 3 |
| **The Spindle** | 11 | 1 |
| **Total** | **254** | **15** |

### 3.11 Summary

| World | Parts | Lights | `Layouts[theme].budget` | Upper route (h) | Pads (boss) | Min pad gap | Grid points / uncovered | Hero |
|---|---|---|---|---|---|---|---|---|
| Times Square | 501 | 31 | 540 / 36 | 9 loop | 12 (4) | 0.5 | 70 / 0 | Beacon 36 |
| Sorcery Academy | 340 | 17 | 370 / 20 | 5 loop | 10 (4) | 0.5 | 41 / 0 | Main Hall |
| Star Vault | 312 | 13 | 340 / 16 | 8 loop, ribs 57 | 11 (4) | 0.5 | 64 / 0 | Keeper's Dais |
| Kyoto | 446 | 18 | 470 / 21 | 6.5 loop | 11 (4) | 1.0 | 64 / 0 | Pagoda 36 |
| Colony | 403 | 18 | 420 / 21 | 7 U, 12 catwalk | 10 (3) | 1.0 in plan (caps and deck pass overhead) | 60 / 0 | Headcount Board |
| Dunewatch | 342 | 9 | 360 / 12 | 5–7.4 network | 10 (3) | 1.0 | 54 / 0 | Signal tower 38 |
| Quarry Hollow | 256 | 14 | 280 / 16 | 10 loop | 10 (6) | 0.5 | 60 / 0 | Crane 40 |
| Mistreach | 478 | 25 | 510 / 28 | 5–6 lofts, 0.3 ring | 10 (5) | 0.6 | 68 / 0 | Lighthouse 32 |
| Thunderspire | 214 | 18 | 240 / 21 | 3 / 6 / 7 / 8 U | 11 (5) | 0.75 | 68 / 0 | Hall and spire 34 |
| Seam | 254 | 15 | 280 / 18 | 5–8 U | 12 (3) | 0.28 | 65 / 0 | **The Spindle 70** |

The largest world is 501 parts and 31 lights, against caps of 900 and 60. Grid-point counts are from the distance-rule pre-check. The fan check (§4.5 check 4) is the gate that must pass.

---

## 4. Implementation

### 4.1 `src/server/Arenas.luau`

**Collision groups**, registered once when the module loads:

```lua
local PhysicsService = game:GetService("PhysicsService")
for _, g in { "Rail", "ShotRay", "Foliage" } do
  if not PhysicsService:IsCollisionGroupRegistered(g) then PhysicsService:RegisterCollisionGroup(g) end
end
PhysicsService:CollisionGroupSetCollidable("Rail", "ShotRay", false)
PhysicsService:CollisionGroupSetCollidable("Foliage", "ShotRay", false)
```

- `railPart(k, props)` sets `CollisionGroup = "Rail"`, `CanTouch = false`, and leaves CanCollide and CanQuery true.
- `foliage(k, props)` sets `CollisionGroup = "Foliage"`, CanCollide false, CanQuery true and CanTouch false.
- Other files:
  - `Projectiles.luau`, after line 35 (`wallParams.FilterType = …`): add `wallParams.CollisionGroup = "ShotRay"`.
  - `Abilities.luau` `clearPath`, after line 193: add `params.CollisionGroup = "ShotRay"`.
  - `Movement.findAnchor` is unchanged. Its default-group params hit Default, Rail and Foliage parts.

**Kit plumbing**
- `Kit` gains `parts`, `lights` and `L = Layouts[theme]`.
- `part()` and `light()` count as they create.
- At the end of `build`, `warn` if `k.parts > k.L.budget.parts` or `k.lights > k.L.budget.lights`, or if either exceeds the 900 / 60 caps. There is no separate budget table.

**Helpers**
- New: `at`, `frame`, `decor`, `railPart`, `foliage`, `core`, `crossarms`, `ring`, `chordRing`.
- Access and walkways: `ramp` (with `landing`), `stairs`, `switchback` (exact geometry in §2.1), `ledgeStair`, `ladder`, `deck`, `rail`, `bridge`, `arch`.
- Furniture: `stall`, `crate`, `container`, `jersey`.
- Buildings and anchors: `walkup`, `arcade`, `pavilion`, `watchtower`, `house`, `stilthouse`, `dorm`, `teahouse`, `windcatcher`, `palm`, `floodlight`, `pylonFence`.

**Changed functions**
- `tree`: cedar and pine crowns use `foliage()`, with the sizes and colours in §2.3, and those trees get the core. Other crowns become decor.
- `spire` and `floodlight`: add `crossarms(k, top, colour)` when the mast is under 2 u wide.
- `car`: 5 parts, no light. `lamp(…, lit)`. `billboard`: the sign is decor. `building`: at most 3 bands.
- `portal`: segments get CanQuery false.
- `SIGNS`: replacements as in §0.2.

**Data-driven build**
- Footprints, walks, access, anchors, pads and water are built from `Layouts[theme]` by `BUILD[f.kind](k, f)`.
- Decor and scatter stay procedural, using `Random.new(map.seed * 16 + districtIndex)`, with the rejection rule from §1.4.

**`Nav` part**
- An invisible part at C with no collision, query or touch.
- `Pad` Attachments carry the attributes `Radius` (6 or 8) and `Boss`.
- `Link` Attachments carry a `Top` Vector3 attribute.

**Terrain**

```lua
local TOUCHED = { Enum.Material.Grass, Enum.Material.Asphalt, Enum.Material.Ground, Enum.Material.Cobblestone,
  Enum.Material.Slate, Enum.Material.Concrete, Enum.Material.Sand, Enum.Material.Rock, Enum.Material.Snow,
  Enum.Material.Basalt, Enum.Material.Mud, Enum.Material.Sandstone }
local DEFAULT_COLOUR = {}
for _, m in TOUCHED do DEFAULT_COLOUR[m] = workspace.Terrain:GetMaterialColor(m) end  -- captured before any build
-- first lines of Arenas.build:
for m, c in DEFAULT_COLOUR do workspace.Terrain:SetMaterialColor(m, c) end
workspace.Terrain.WaterWaveSize = if theme == "water" then 0.15 else 0
```

- Ponds are walkable reflecting pools (the baseplate top is at y = 0). Their bridges are walkable. Pads reject water.
- **`hill()`** reads `k.L.hills` (desert, earth and storm; the other themes never call it). It keeps the same number of `rng` draws per attempt and gives up after 6 rejected attempts:

```lua
--- A hill of terrain beyond the play space: its ground circle (radius 0.8·r, since it
--- is sunk 0.6·r) starts no nearer than minGround, and never enters a keep-out sector.
local function hill(k: Kit, rMin: number, rMax: number, material: Enum.Material)
	local H = k.L.hills :: { minGround: number, keepOut: { { bearing: number, halfWidth: number } } }
	for _ = 1, 6 do
		local r = k.rng:NextNumber(rMin, rMax)
		local d = H.minGround + k.rng:NextNumber(0, 74) + r * 0.8
		local b = k.rng:NextNumber(0, 360)
		local spread = math.deg(math.asin(0.8 * r / d)) -- angular half-width of the ground circle
		local ok = true
		for _, s in H.keepOut do
			local diff = math.abs((b - s.bearing + 180) % 360 - 180)
			if diff < s.halfWidth + spread then
				ok = false
				break
			end
		end
		if ok then
			workspace.Terrain:FillBall(around(k, math.rad(b), d, -0.6 * r), r * STUDS, material)
			return
		end
	end
end
```

- **`chordRing(k, s)`** implements the kit row in §2.1:

```lua
local function chordRing(k: Kit, s: ChordRing)
	local span = s.b1 - s.b0
	local closed = math.abs(span - 360) < 1e-6
	local step = span / s.n
	local half = math.rad(step / 2)
	local depth = s.rOut - s.rIn
	local len = 2 * s.rIn * math.tan(half) -- inner-edge chord: decks never overlap
	local capLen = s.rOut / math.cos(half) - s.rIn -- to the outer vertex
	assert(s.capW >= 2 * depth * math.tan(half) + 1, "chordRing: cap narrower than the joint V")
	local function radial(b: number, r: number, y: number): CFrame
		return CFrame.new(around(k, math.rad(b), r, y)) * CFrame.Angles(0, -math.rad(b), 0)
	end
	for i = 0, s.n - 1 do
		local b = s.b0 + (i + 0.5) * step
		part(k, { Size = Vector3.new(depth, s.t, len) * STUDS, CFrame = radial(b, s.rIn + depth / 2, s.top - s.t / 2),
			Color = s.colour, Material = s.material })
		-- rails: outer 2·rOut·tan(half) at rOut − 0.15, inner 2·(rIn + 0.3)·tan(half) at rIn + 0.15,
		-- each cut by s.rails.gaps ({ bearing, edge = "outer" | "inner", from, to } in u along the edge
		-- from that joint, positive toward increasing bearing), built with railPart.
		railRun(k, s, b, "outer", 2 * s.rOut * math.tan(half), s.rOut - 0.15)
		railRun(k, s, b, "inner", 2 * (s.rIn + 0.3) * math.tan(half), s.rIn + 0.15)
	end
	for j = 0, if closed then s.n - 1 else s.n do
		local b = s.b0 + j * step
		part(k, { Size = Vector3.new(capLen, 0.5, s.capW) * STUDS,
			CFrame = radial(b, s.rIn + capLen / 2, s.top + (s.capT or 0.1) - 0.25),
			Color = s.capColour, Material = s.capMaterial })
	end
end
```

- Each chord ring also writes its decks and caps to `Layouts[theme].footprints` (kind `"deck"` and `"cap"`), and one `walks` segment per deck from joint vertex to joint vertex on the centre line. Spec check 2b tests these.

**Spin:** `CollectionService:AddTag(beam, "Spin")`. `Fx` caches `CollectionService:GetTagged("Spin")` when the `Arena` child changes (from `ChildAdded` / `ChildRemoved` on `workspace`, next to the `Weather` code at about line 421). Each RenderStepped rotates the cached parts by their `Spin` attribute in degrees per second.

### 4.2 `Waves.spawnSpot(centre, boss)`

Replaces `Waves.spawnSpot` (Waves.luau lines 59–83). It needs `local Nav = require(script.Parent.Nav)`.

```lua
-- Pad -> stamp of its last pick. Keyed per build: cleared whenever the Nav part changes.
local used: { [Attachment]: number } = {}
local usedNav: Instance? = nil
local stamp = 0
local waveStart = 0 -- stamp when the current wave began (set by spawnCurrent)

--- In-place Fisher-Yates.
local function shuffle<T>(t: { T }): { T }
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

--- Flat distance from `at` to the nearest living player's root (math.huge if none).
local function playerGap(at: Vector3): number
	local gap = math.huge
	for player in Combat.states do
		local root = Combat.rootOf(player)
		if root then
			gap = math.min(gap, ((root.Position - at) * Vector3.new(1, 0, 1)).Magnitude)
		end
	end
	return gap
end

--- Where a pack (or a boss) arrives. With a Nav part the answer is always one of
--- its Pad attachments and `centre` is ignored; without one it samples the ring
--- round `centre`, as before.
function Waves.spawnSpot(centre: Vector3, boss: boolean?): Vector3
	local need = ((if boss then Config.ENEMY_NOTICE_BOSS else Config.ENEMY_NOTICE) + 6) * STUDS
	local arena = workspace:FindFirstChild("Arena")
	local nav = arena and arena:FindFirstChild("Nav")
	if nav then
		if nav ~= usedNav then
			table.clear(used)
			usedNav, stamp, waveStart = nav, 0, 0
		end
		local fresh, freshBoss, all = {}, {}, {}
		for _, a in nav:GetChildren() do
			if a:IsA("Attachment") and a.Name == "Pad" then
				local isBoss = a:GetAttribute("Boss") == true
				if boss and not isBoss then
					continue
				end
				table.insert(all, a)
				if (used[a] or 0) <= waveStart then -- not picked yet this wave
					table.insert(if isBoss and not boss then freshBoss else fresh, a)
				end
			end
		end
		if #all > 0 then
			-- Normal packs: this wave's unused non-boss pads, then unused boss pads, both
			-- shuffled; then every pad in least-recently-used order (not shuffled).
			-- Bosses: unused boss pads shuffled, then boss pads by LRU.
			local order: { Attachment }
			if #fresh > 0 then
				order = shuffle(fresh)
			elseif #freshBoss > 0 then
				order = shuffle(freshBoss)
			else
				table.sort(all, function(p, q)
					return (used[p] or 0) < (used[q] or 0)
				end)
				order = all
			end
			local pick, bestGap = order[1], -1
			for _, a in order do
				local gap = playerGap(a.WorldPosition)
				if gap >= need then
					pick = a
					break
				end
				if gap > bestGap then
					pick, bestGap = a, gap
				end
			end
			stamp += 1
			used[pick] = stamp
			return pick.WorldPosition
		end
	end
	-- No Nav, or a Nav with no pads (an authored map): the old ring sampler,
	-- now also rejecting spots Nav.isClear refuses (water, inside geometry).
	local best, bestGap = centre, -1
	for _ = 1, 12 do
		local a = math.random() * math.pi * 2
		local r = (20 + math.random() * 30) * STUDS
		local spot = centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if Nav.isClear(spot) then
			local gap = playerGap(spot)
			if gap >= need then
				return spot
			end
			if gap > bestGap then
				best, bestGap = spot, gap
			end
		end
	end
	return best
end
```

**`Waves.spawnCurrent` changes** (lines 86–100):
- First line: `waveStart = stamp`, so every pad counts as fresh again for the new wave while the LRU stamps carry across waves.
- The loop already computes `local boss = Worlds.enemy(id) and Worlds.enemy(id).boss` (line 94) before the call. Pass it: `packAt = Waves.spawnSpot(centre, boss == true)`.
- `centre` is still passed and is only used without a Nav.
- The old `table.clear(used)` per wave is gone. Clearing happens only when the Nav part changes, which means a new build.

**Rules:**
- `Config.ENEMY_NOTICE_BOSS + 6 = 32` u, which is why every boss pad is at r ≥ 34.
- **Pads never go:**
  - within 6 u of a footprint (8 u for boss pads), tested as oriented boxes;
  - under a deck or cap;
  - on thin decks;
  - in water;
  - at r < 20.

### 4.3 Enemy navigation: `src/server/Nav.luau` plus `Enemies.luau` (required)

**1. `Nav.moveTarget(e, target)`** replaces the direct `MoveTo` in the notice and chase branches.
- **Direct move** when `|ΔY| ≤ 3 u` and a Default-group `Spherecast` of radius 1·size u is clear. Rails block it, which is correct because rails stop bodies.
- **Every Nav cast** (this spherecast, and the `isClear` down-ray) sets `params.RespectCanCollide = true`. Foliage crowns, cores and crossarms (all CanCollide false) are therefore invisible to navigation.
- **Otherwise, a path:**
  - `PathfindingService:CreatePath{ AgentRadius = 0.6*size*STUDS, AgentHeight = 2.4*size*STUDS, AgentCanJump = false, AgentCanClimb = true, Costs = { Water = math.huge } }`.
  - At most 1 compute per second per enemy and 8 in flight at once, each in `task.spawn`.
  - Advance to the next waypoint within 1.5 u; recompute when the goal drifts more than 6 u.
- **On `NoPath`:** use the nearest `Link` whose `Top` is within 10 u of the target: walk to its foot, then its top.

**2. Unstick.** If the enemy moves less than 0.5 u in 0.8 s: `hum.Jump = true`, sidestep 6 u for 0.6 s, then clear the path.

**3. Reach fallback.**
- **Trigger:** a non-ranged enemy has been hunting for more than 4 s, and either its path is `NoPath` or the target is more than 3 u above it within 18 u horizontally. Then `e.tossing = true`. It is cleared once the enemy has a path again, or the target comes within 3 u vertically.
- **Profile:** `Nav.toss(e)` returns a **fresh table on every call**. Nothing is shared, so nothing can be mutated the way `Combat.luau:456` mutates `e.t.ranged.cd` on enrage. It reads `e.t.atk` at call time, so it follows enrage's attack boost, and applies the enrage cooldown itself:
  ```lua
  --- The rock a melee enemy lobs at someone it cannot reach. A new table every
  --- call, shaped like a `ranged` profile, so `shoot` treats it the same way.
  function Nav.toss(e: Combat.Enemy)
  	return {
  		cd = if e.enraged then 3.5 * 0.65 else 3.5,
  		power = Rules.round(e.t.atk * 0.5),
  		speed = 14,
  		arc = true,
  		size = 0.6,
  		color = 0xb8a88a,
  	}
  end
  ```
  There is no `TOSS` constant anywhere.
- **Code changes in `Enemies.luau`:**
  - Line 346: `shotReady = (e.t.ranged ~= nil or e.tossing == true) and now >= e.nextShot,`
  - Shoot branch (line 405):
    ```lua
    local prof = e.t.ranged or Nav.toss(e)
    e.nextShot = now + prof.cd * (0.8 + math.random() * 0.5)
    if target then shoot(e, target, prof) end
    ```
  - `shoot(e, target, prof)` begins `local r = prof or e.t.ranged`.
  - `Combat.Enemy` gains `tossing: boolean?`.
- `aiStep` shoots at 4.5 < dist < 42, which covers every perch in §3.

**4. `Nav.isClear(pos)`** returns true when all of these hold:
- a Default-group `GetPartBoundsInBox` of 3 × 5 × 3 u centred 2.8 u above `pos` (arena only, CanCollide parts) finds nothing;
- a ray down from +6 u hits within 1.5 u of `pos.Y`;
- the hit material is not Water.

**5. `Nav.clearSpot(pos)`** returns `pos` if `isClear`. Otherwise it tries 8 bearings at 3 u, then 8 at 6 u, and returns the first clear one. If none is clear, it returns the nearest `Pad`. It is used by:
- summoners, at `Enemies.luau:460`: `Enemies.spawn(sm.of, Nav.clearSpot(e.root.Position + offset))`;
- `FinaleFight.luau:139`: `Enemies.spawn(id, Nav.clearSpot(e.root.Position + side))`.

**6. Wander.** `wander()` picks `home + random 12 u` and accepts it only if `Nav.isClear`. It tries 4 times, then walks to a random `Pad` or `Link` foot within 20 u of home.

### 4.4 `Arenas.audit(model)` (Studio only)

- **Pads:**
  1. The ray down hits within 1 u of the pad and not Water.
  2. `GetPartBoundsInBox` with the box from §4.2 (boss: 16 × 7 × 16), arena only. Keep CanCollide parts whose top is more than 0.3 u above the pad. There must be none.
  3. The pad is 20–50 u from C; boss pads are at least 34 u.
- **Sightlines:** `RaycastParams` with `CollisionGroup = "ShotRay"` and characters excluded. Sample every walk every 6 u at +1.5 u and cast to every pad within 30 u. `warn` on each blocked pair.
- **Swing coverage:** at each grid point, run the real `findAnchor` fan facing N, E, S and W. A facing succeeds when its best hit is at least 16 u above the floor. At least 3 of the 4 must succeed.
- **Hero sightline (visual):** a default-group ray from (C.x, 3 u, C.z) to (hero.x, 0.6·hero.top, hero.z), excluding the hero's own parts. **Rails count as blockers**, because they are opaque, whatever their ShotRay group. Decor does not count.
- **R0:** no CanCollide part at r < 12 and h < 3 other than the floor.
- **Budget:** report `k.parts` and `k.lights` against `k.L.budget`.

### 4.5 `src/shared/Layouts.luau` (hand-written) and `tests/layouts.spec.luau`

- The file is required as `Shared.Layouts` in game, and as `require("../src/shared/Layouts")` in Lune, like `Finale`.
- It is not in `Data/`, so the export freshness test is unaffected.

**Schema:**

```lua
{
  budget = { parts = 540, lights = 36 },
  footprints = { { id = "beacon", kind = "tower", x = 0, z = -26, w = 8, d = 8, yaw = 0, h0 = 0, h1 = 36 }, ... },
                 -- every collidable piece near play: ramps (full wedge box), rotated parts (yaw), trusses, cars
  pads    = { { x = 0, z = -40, h = 0, boss = true }, ... },
  anchors = { { id = "beacon", x = 0, z = -26, top = 36 }, ... },         -- fixed data only
  walks   = { { id = "sky-n", a = { 10, -46, 9 }, b = { -10, -46, 9 }, w = 3 }, ... },
  decks   = { { id = "overpass-3", x = .., z = .., w = .., d = .., yaw = .., under = 6.2 }, ... },
  access  = { { id = "wu-ne-truss", kind = "truss", foot = { 16, -39.6, 0 }, top = { 16, -40, 9 }, w = 0.83 }, ... },
  water   = { { x = 32, z = 36, r = 8 }, ... },
  trees   = { { x = 34, z = -38, h = 40, kind = "cedar" }, ... },    -- trunk, core and Foliage crowns come from
                                                                      -- Layouts.treeParts(t), which Arenas also uses
  hills   = { minGround = 66, keepOut = { { bearing = 90, halfWidth = 30 }, ... } },  -- desert, earth, storm only
  hero    = { x = 0, z = -26, top = 36, ids = { "beacon" } },
}
```

- Every footprint has `id, kind, x, z, w (Size.X), d (Size.Z), yaw, h0, h1`. It may also carry `rail = true`, `query = "core" | "foliage"` (CanCollide false, CanQuery true), `backdrop = true` (beyond the play space; skipped by pad and hill-radius checks) and `keep = true` (a backdrop piece hills must avoid).
- Chord rings write their decks, caps and walks here through the same code path as `Arenas` (§4.1).

**Checks**, added to `tests/run.luau` with one `require`. They mirror the model I used to check this design.

1. **Pads.**
   - 20 ≤ r ≤ 50, and boss pads r ≥ 34. At least 10 pads, at least 3 of them boss pads.
   - **Oriented-box test:** each footprint is a rotated rectangle, tested on 4 axes against the axis-aligned box pad ± 6 (boss ± 8). It fails when the footprint's [h0, h1] overlaps [h + 0.3, h + 5.3] (boss [h + 0.3, h + 7.3]).
   - No pad inside `water`, and none under a `deck`.
2. **Walks:** every 3 u sample has an `access.top` within 25 u.

   2b. **Support under every walk sample (new).**
   - For each walk segment a → b (width w, height h), take samples every 0.5 u along the segment at lateral offsets 0 and ±(w/2 − 0.1).
   - At every vertex shared by two consecutive segments (turn angle θ), also take samples every 0.25 u along the bisector, out to ±((w/2)/cos(θ/2) − 0.15). This is where the outer-edge V opens.
   - Each sample (x, z) must lie inside, by oriented-box containment, a footprint of kind deck, cap, bastion, landing, roof, wall, bridge or access whose h1 is in [h − 0.05, h + 0.15].
   - In my model this check passes with the revision 4 geometry: Colony 1088 samples, Vault 2328, Tideline 2548 and Kyoto 2268, all with 0 failures. Without the caps the Colony fails 292 samples, and without the bastions Kyoto fails 70, so the check catches exactly the reviewer's holes.
3. **Access:** ramps and stairs are at least 3 u wide, and each world has one of at least 4 u.
4. **Swing: the real fan (replaces the distance rule).**
   - At every 10 u grid point with 20 ≤ r ≤ 50 that is outside footprints taller than 3 u, the root is at floor + 1.25 u.
   - Facing each of N, E, S and W, the spec reproduces `Movement.findAnchor` exactly:
     - elevations 25 + 55·i/8 for i = 0..8, and yaws −0.9, −0.45, 0, 0.45 and 0.9 rad;
     - `flat = rotY(yaw) · look`, `right = look × Y = (−look.z, 0, look.x)`, and `dir = rodrigues(flat, right, elevation)`, which is the full Rodrigues rotation, because `flat` is not perpendicular to `right` when yaw ≠ 0;
     - reach 60 u; accept a hit only if hit.y > root.y + 4; score = 2·hit.y + (hit − root)·look.
   - Geometry is every non-decor footprint as an oriented box (the slab test in the box's local frame, where local X = (cos yaw, 0, −sin yaw) and local Z = (sin yaw, 0, cos yaw)), plus every Foliage crown from `treeParts` as a sphere. Rails, cores and crossarms are included, as they are in-game.
   - A facing passes when its best hit is at least 16 u above the floor. A grid point passes when at least 3 of its 4 facings pass. **Every grid point must pass.**
   - The §1.5 distance rule stays in the spec only as an informational pre-check that prints its count.
   ```lua
   local function rodrigues(v, k, a) -- rotate v about unit axis k by angle a
   	local c, s = math.cos(a), math.sin(a)
   	local kv = k[1] * v[1] + k[2] * v[2] + k[3] * v[3]
   	local x = { k[2] * v[3] - k[3] * v[2], k[3] * v[1] - k[1] * v[3], k[1] * v[2] - k[2] * v[1] }
   	return { v[1] * c + x[1] * s + k[1] * kv * (1 - c), v[2] * c + x[2] * s + k[2] * kv * (1 - c),
   		v[3] * c + x[3] * s + k[3] * kv * (1 - c) }
   end
   local function fan(G, root, look) -- G = { boxes = {...}, balls = {...} }; returns best hit {x, y, z} or nil
   	local right = { -look[3], 0, look[1] }
   	local best, bestScore = nil, -math.huge
   	for i = 0, 8 do
   		local el = math.rad(25 + 55 * i / 8)
   		for _, yaw in { -0.9, -0.45, 0, 0.45, 0.9 } do
   			local c, s = math.cos(yaw), math.sin(yaw)
   			local flat = { look[1] * c + look[3] * s, 0, -look[1] * s + look[3] * c } -- CFrame.fromAxisAngle(Y, yaw) * look
   			local d = rodrigues(flat, right, el)
   			local t = nearestHit(G, root, d, 60) -- min over hitBox / hitBall, nil if none within 60
   			if t then
   				local h = { root[1] + d[1] * t, root[2] + d[2] * t, root[3] + d[3] * t }
   				if h[2] > root[2] + 4 then
   					local score = h[2] * 2 + (h[1] - root[1]) * look[1] + (h[3] - root[3]) * look[3]
   					if score > bestScore then best, bestScore = h, score end
   				end
   			end
   		end
   	end
   	return best
   end
   ```
5. **R0:** no footprint at r < 12 with h0 < 3. Seam: no footprint at r < 26.
6. **Budgets:** parts ≤ 900 and lights ≤ 60, and each world's counted parts and lights are ≤ `budget`.
7. **Hero sightline (visual, rails explicit):**
   - The segment runs from the eye (0, 0, **3.0**) to (hero.x, hero.z, 0.6·hero.top).
   - It must clear, by 0.3 u, **every** non-decor footprint other than those in `hero.ids`. That **includes rails** (`rail = true`), because the ShotRay exemption applies to shots, not to what the player sees. Foliage crowns count too.
   - This is why the Academy N cloister has its Hall Window (§3.2), and why the Seam hero is the 70 u Spindle, not the 26 u rod tower in front of it.
8. **Chord rings:** for every `chordRing`, capW ≥ 2·(rOut − rIn)·tan(step/2) + 1. Decks never overlap: length = 2·rIn·tan(step/2).
9. **Hills (new):** for desert, earth and storm:
   - `hills.minGround ≥ max over non-backdrop footprints of the farthest corner radius + 4`. Current values: desert 61.8 + 4 ≤ 66; earth 55.8 + 4 ≤ 60; storm 59.0 + 4 ≤ 66.
   - Every `keep` footprint's angular half-extent, seen from C, fits inside one keep-out sector's halfWidth.
   - Because `hill()` puts the ground circle's inner edge at d − 0.8·r ≥ minGround and rejects sectors by bearing ± (halfWidth + asin(0.8·r/d)), these two static checks cover every seed.

**Files touched**
- New:
  - `src/shared/Layouts.luau`
  - `src/server/Nav.luau`
  - `tests/layouts.spec.luau`
- Rewritten: `src/server/Arenas.luau`
- Changed:
  - `src/server/Enemies.luau`: movement hook, Unstick, toss, `clearSpot` for summons, wander.
  - `src/server/Combat.luau`: `tossing` field.
  - `src/server/Waves.luau`: `spawnSpot` rewrite (§4.2), `waveStart` and the `boss` argument in `spawnCurrent`.
  - `src/server/Projectiles.luau`: one line (the ShotRay group).
  - `src/server/Abilities.luau`: one line (the ShotRay group).
  - `src/server/FinaleFight.luau`: one line.
  - `src/client/Fx.luau`: `Spin` tag.
  - `tests/run.luau`: one `require`.
  - `web3d/rift3d.html`: 4 names, then `npm run export:roblox`, which regenerates `src/shared/Data/Maps.luau`.
  - `roblox/README.md`: line 95.
- Unchanged: `World.luau`, `Movement.luau`.

**Optional, out of track:** `Movement` could use `rope.Length = math.min(0.92*dist, hitHeight - 1.5u)`, so low anchors lift the player instead of dragging. Playtest before adopting. No world above depends on it.