# Dimensional Rift world layout, buildings and walkways: design revision 3

## R. What changed from revision 2

**How this revision was checked.** Every pad, footprint and anchor below was entered into an offline model of the planned `Layouts` data. The model treats each part as an oriented box and tests it against the pad's box on all four axes, which is how `GetPartBoundsInBox` works: a wedge or rotated part counts as its full box. It then ran the swing-coverage rule. **All 10 worlds pass**, with 0 pad collisions and 0 uncovered grid points. The smallest gap between a pad's clear box and any part is 1.0 u in Kyoto, Colony and Dunewatch, 0.75 u in Thunderspire, 0.6 u in Mistreach, 0.5 u in Academy, Star Vault and Quarry, 0.28 u in the Seam, and 0.5 u in Times Square after the last move.

### Blocking items

| # | Reviewer item | Resolution | Where |
|---|---|---|---|
| B1 | A rail with CanCollide true and CanQuery false is impossible | Rails now use **collision groups**. `Arenas` registers `Rail` and `ShotRay` and sets `CollisionGroupSetCollidable("Rail","ShotRay",false)`. Rails keep CanCollide true, CanQuery true and `CollisionGroup="Rail"`. `Projectiles` sets `wallParams.CollisionGroup="ShotRay"` (line 34). `Abilities.clearPath` does the same for its params (line 192), so dashes, teleports and knockback also pass rails. The sightline audit casts with `ShotRay`. | §0, §2, §4.1, §4.4 |
| B2 | Hand edits to generated files | Layouts move to **`src/shared/Layouts.luau`**, hand-written like `Finale.luau` and required as `Shared.Layouts`. The four worlds are renamed in **`web3d/rift3d.html`** (lines 2361, 2368, 2375, 2382, `name:` only), then `npm run export:roblox` regenerates `Data/Maps.luau`. `roblox/README.md` line 95 changes too. | §0.2, §4.1, §4.5 |
| B3 | Pads inside geometry | Every pad was re-placed and checked with the box test described above. Each of the reviewer's cases (a)–(h) is fixed (see the list below the table). | §3 |
| B4 | Dunewatch citadel bridges impossible | **Dropped** (the reviewer's second option). The citadel gets a third ramp. Each quarter now has its own ramp plus trusses. The NE and SE quarters are joined over the souk. | §3.6 |
| B5 | Swing coverage fails the rule in 6 worlds | The reviewer's anchor additions are adopted, and Dunewatch also gets 2 oasis masts (my recheck found the SW corner uncovered because 14 u palms don't count). All anchors are fixed data in `Layouts`, and none are random. Result: 0 uncovered grid points in all 10 worlds. | §3.x "Anchors" |
| B6 | Nav, toss and summon code | The toss uses `local prof = e.t.ranged or TOSS` in the shoot branch. `shotReady` in `Enemies.think` (line 346) becomes `(e.t.ranged ~= nil or e.tossing == true)`. `shoot(e, target, prof)` is added, and `Combat.Enemy` gains `tossing: boolean?`. Summoner children (`Enemies.luau` line 460) and `FinaleFight` line 139 both go through **`Nav.clearSpot`**, which searches a ring before falling back. | §4.3 |

How each of the reviewer's B3 cases was fixed:
- **(a) Colony.** The pad list was rebuilt. No pad is under the deck, and each pad is at least 1 u from a pier (piers are 2 × 2 u). I did not use (−6,−38): it hits the 270° pier. I did not use (24,−30): it hits the Fallen Span.
- **(b) Star Vault.** Pads (±26,−10) are removed.
- **(c) Academy.** The path lanterns move outside the gate.
- **(d) Academy.** The training ring has 6 posts at r 12.
- **(e) Dunewatch.** The pads move to (±8,−22).
- **(f) Dunewatch.** The palm moves to (−20,30).
- **(g) Mistreach.** The boss pad moves to (32,−16). It needs r ≥ 34, so (30,−14) was not usable.
- **(h) Thunderspire.** The shelters move to (±16,46).

### Improvements

| Improvement | Status |
|---|---|
| Boss pads at least 32 u from spawn, using `ENEMY_NOTICE_BOSS + 6` | **Adopted.** Every boss pad is at r ≥ 34, and `spawnSpot` uses 32 for bosses. |
| Normal packs use non-boss pads first | **Adopted** (§4.2). |
| No pads under the overpass | **Adopted.** No pad in any world is under a deck, and the spec asserts this. |
| Exact switchback geometry | **Adopted** (§2.1). The Quarry switchbacks now run outward from the gallery edge. The Thunderspire horn uses an in-line ledge stair with a 4 × 4 top landing at x 36..40. |
| Kyoto tower truss on the inner face, from the wall-walk | **Adopted**: h 6.5 → 13, 16 studs. |
| Mistreach moorings 22° apart with 12 u bridges | **Adopted.** Parts recounted. |
| Hero dominance | **Adopted.** The Crane goes to 40 u with a 3 u hook block. The Great Hall gets a stupa spire to 34. |
| Terrain colour reset | **Adopted.** Defaults are captured once at server start and restored at the top of `build`. |
| `Spin` via CollectionService | **Adopted.** |
| Wander validation | **Adopted** (`Nav.isClear`). |
| Vagueness | **Closed.** Piers, crane, hulls, ramp directions, tea pavilion, dorms and Seam fragments are all specified. |
| Cleanup | **Done.** One pad table per world. Torii posts at ±3. Quarry spans measured from the gallery edge. |
| IP: amber quarantine fence and "BLOCK 01 · HEADCOUNT" | **Adopted.** |
| Vault star chains | **Adopted.** |

### Declined or changed

- **Vault boss pads at r 40: adopted, but the gallery changes too.** At r 40 the 16 u box reaches r 51.3 on the diagonal. That hits the gallery deck (underside 6.6) and the gallery posts on 15 + 30k. So the gallery rises to **h 8** (underside 7.6, above the 7.3 boss headroom). The posts move to the pillar bearings (30k). The six r 40 braziers become three at r 38 on 15°, 105° and 195°.
- **Thunderspire bell spire at (0,−60): folded into the hall.** A stupa spire at (0,−52) rising to 34 passes the coverage check and also serves as the hero. The ground behind the terrace stays empty.
- **Thunderspire pier-to-upper-terrace bridge: dropped.** It crossed the only boss-pad space on the middle terrace. The upper route is now a U: ground → ledge stair → ledge → bridge → pier → pier ramp → middle terrace.
- **Dunewatch souk shortened to x 14..40 (6 stalls).** This frees the third boss pad at (48,−2).

---

## 0. What the code allows

| Fact | Source | What it means for layout |
|---|---|---|
| The spawn is at `C` + (0, +2) u, via `CFrame.new(pos)`, so **the player faces −Z**. | `World.spawnPoint` | The hero stands on the −Z axis, framed by the portal. |
| `spawnSpot` has no Y. Enemies spawn with +4 studs of lift, in packs of 3 with ±4 u jitter. Bosses spawn alone. | `Waves` | Pads need a clear box: 12 × 5 × 12 u for normal pads, 16 × 7 × 16 u for boss pads. |
| Enemies use `MoveTo` only and never jump. Notice and reach are 3D. Shooting happens at 4.5 < dist < 42. About 91 of 217 enemies are `ranged`. Nothing flies. | `Enemies.think`, `Rules.aiStep` line 476 | The navigation in §4.3 is required. |
| **CanQuery is ignored when CanCollide is true.** Collision groups do filter raycasts through `RaycastParams.CollisionGroup`. No collision groups are in use today. | engine, grep | Rails go in the `Rail` group; shot rays use the `ShotRay` group. |
| Swing: elevations 25–80° in 9 steps, 5 yaws, reach 60 u, hit more than 4 u above the root, score = 2·Y + forward, rope = 0.92 × distance, default group. | `Movement.findAnchor` | A hit at distance D needs a top of at least 0.47·D + 4. The arc clears the start height only for rays at 66° or steeper. |
| The Humanoid steps about 2 studs and walks 30° wedges. Truss sizes snap to 2 studs. | engine | Ramp run = 1.75 × rise. |
| `SIGNS` contains "DAILY BUGLE" and "RAMEN ICHIBAN". The portal segments are CanQuery true. | `Arenas.luau` | Both are fixed in §4.1. |
| `src/shared/Data/*` is generated, and `test/roblox-export.test.js:19` compares it against a fresh export. | README, test | New data goes outside `Data`. Names are changed in `rift3d.html`. |
| `Terrain:Clear()` does not reset `SetMaterialColor` (`Arenas.luau:442`, `:854`). | engine | Colours are reset per build. |

### 0.1 Coordinates

- Positions are `(x, z)` in units from C, and `h` is height in units. 1 u = 2.4 studs.
- **N = −Z, S = +Z, E = +X.** Bearing 0 = E, 90 = S, 180 = W, 270 = N (as in `around()`).

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
| R4 Backdrop | 60–150 | Skyline and terrain | Terrain hills only beyond 56. |

### 1.2 Routes

- **Ground loop:** continuous at r ≈ 30–42, at least 6 u wide.
- **Upper route:** at h 5–10, either a loop or a U that comes down by ramps at both ends.
  - Every walk sample point has an **access top within 25 u**.
  - Accesses are ramps or stairs at least 3 u wide, or a truss. The main accesses are at least 4 u wide.
- **Sightlines:** from each upper-route sample (every 6 u, at +1.5 u), every pad within 30 u is visible to a `ShotRay`-group ray.
- **No pad sits under a deck.**
- **Gates** are at least 5 u wide and at least 6 u tall.

### 1.3 Buildings versus the AI

- R2 buildings are convex rectangles: short side 14 u or less, long side 24 u or less, at least 6 u apart.
- Ground floors are open colonnades.
- **Upper-route edges are rails** in the `Rail` group: they stop bodies but not shots or dashes. Rails leave 3 u gaps at access tops and bridge ends.
- **Swing-only perches** (the Beacon, pagoda tiers, lintels, the Crane jib) are covered by the reach fallback (§4.3).

### 1.4 Cover and landmarks

- **Cover:** 2–4 pieces at least 2.2 u tall in each 20 × 20 u cell of R2, taking up no more than about 20% of the floor.
- **Scatter** (canes, blossoms, boulders, crates, cairns) is seeded and **rejected inside any pad's clear box plus 0.5 u**, inside footprints, and within 3 u of walks or access pieces.
- **Landmarks:** a hero on −Z, one silhouette per district, and a beacon in fog worlds.

### 1.5 Swing anchors

- Every 10 u grid point with 20 ≤ r ≤ 50 that is not inside a footprint taller than 3 u needs **at least 2 anchors** in `Layouts.anchors` with top ≥ 16, horizontal distance D ≤ 40, and top ≥ 0.47·D + 4.
- `top` is the real hit height: the part top, or 0.95·h for tree cores.
- Random pieces never count toward this.

---

## 2. Building and walkway kit

### Part flag sets

| Set | CanCollide | CanQuery | CanTouch | CastShadow | CollisionGroup |
|---|---|---|---|---|---|
| **Solid** (`part()`) | true | true | true | true | Default |
| **Decor** | false | false | false | false | Default |
| **Rail** | true | true | false | true | **`Rail`** (not collidable with `ShotRay`) |
| **Core** (anchor) | false | true | false | false | Default. Shots stop on it; it reads as foliage. |

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
| Floodlight / mast | 1.2–1.6 square, 20–22 tall, head (decor) | 2–3 | 0–1 |
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
| Cedar / pine (anchor) | h 30–44 | solid trunk 1.6 (pine 1.2) to 0.55·h; 3 crown balls (decor); **`Anchor` core**: Cylinder 1.2 across from 0.55·h to 0.95·h (hit height **0.95·h**) | 5 | 0 |
| Broadleaf / blossom / palm | h 10–16 | trunk plus crown (decor). Palm: trunk to 14, 4 fronds (decor), not an anchor. | 4 / 5 | 0 |
| Backdrop cedar | h 30–40 | trunk plus 2 balls (decor) | 3 | 0 |
| Anchor mast | 1.6 square, 20–40 tall | `spire()` | 2 | 0–1 |

---

## 3. The ten worlds

**Conventions:**
- **B** marks a boss pad (16 × 7 × 16 u clear, r ≥ 34). Every other pad clears 12 × 5 × 12 u.
- `h` is only given when a pad is not on the ground.
- Counts include the portal (29 parts, 1 light), the weather part and the `Nav` part: 31 parts and 1 light.
- **Min gap** is the smallest distance between a pad's clear box and any part.

### 3.1 Times Square: "The Crossroads" (city, night)

**Grid**
- North–south avenue (|x| < 6) and east–west street (|z| < 5), out to 100.
- **Ring Street** is the band where |x| or |z| is 30–38. It is the ground loop.

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| **The Beacon** (hero) | (0, −26): x −4..4, z −30..−22, 36 tall. 4 corner columns 1.5 × 6, then the upper mass from h 6 to 36. | You see north through its open legs. Three SurfaceGui screens face south. Neon crown (decor). Swing-only roof. |
| Neon Theatre (B3) | x 13..27, z −23..−13; truss on the south face at x 20.5 | "NOW SHOWING". Roof at 9. |
| **Red Steps** | x −26..−10, z −25..−14. Deck 16 × 4 at h 4 (z −25..−21); ramp z −21..−14 running down to the south | 7 neon tread edges (decor). Rails on the back and sides. 6 u lane to the Beacon. |
| Market Alley | Stall rows at x −16 and −26 (footprints x −17..−15 and −27..−25), z 16..28, 3 stalls each | |
| Transit Plaza | Kiosk 6 × 4 × 2.4 at (18, 18). Shelters 4 × 2 × 3 at (24, 8) and (8, 24), rotated. Planters 2.4 × 1.2 at (12, 21), (21, 12), (27, 20), (20, 27). | Subway mouth (decor) |
| Billboard pylons | (±12, ±12), 1.6 × 26 | |

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

**Anchors:** Beacon 36; pylons 26; near towers 36–50. The check covers 70 grid points with 0 uncovered.

**Pads** (12, 4 boss; min gap 0.5 u)

| | | | |
|---|---|---|---|
| (0, −40) B | (40, 0) B | (−40, 0) B | (0, 40) B |
| (30, −30) | (−32, −32) | (30, 30) | (−32, 35) |
| (26, −33) | (−24, 0) | (32, 11) | (−32, 9) |

**Height:** Red Steps 4, Theatre 9, High Line 9, Beacon 36 by swing.

**Budget** (unchanged, **493 parts / 31 lights**)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Ring inlay, crosswalks, dashes | 38 | 0 |
| Beacon | 9 | 1 |
| Pylons | 8 | 4 |
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
| **Total** | **493** | **31** |

### 3.2 Tokyo Sorcery Academy: "The Hidden Campus" (afternoon)

| Piece | Position and size | Notes |
|---|---|---|
| Rift Court | Gravel terrain; 4 stone lanterns at (±9, ±9) | |
| **Cloister** (upper loop, h 5) | Roofs 5 wide × 0.5 on the rectangle x ±30, z −24..+22: N run z −26.5..−21.5, S run z 19.5..24.5, E/W runs x ±(27.5..32.5). 26 posts 0.8 × 5 on the outer edge, rails on both roof edges. | Open at ground level |
| Cloister accesses (8; max gap 19 u) | **N corner ramps**: 3 wide, x ±(28.5..31.5), foot at z −35.25, top at z −26.5. **S corner ramps**: z 20.5..23.5, from x ±41.25 up to ±32.5. **Inner tangential ramps with 3 × 3 landings**: N at z −21.5..−18.5, x 8→16.75 (landing to 19.75); S at z 16.5..19.5, x −8→−16.75 (landing to −19.75). **2 dorm bridges** (2.5 u, flat). | |
| **Main Hall** (hero) | Podium x −14..14, z −53..−35, h 3. Stair 14 wide at z −35..−29.75. Hall 24 × 14 × 8 on the podium, top of roof about 14. | |
| Bell Tower (B5, stretched) | x −27..−21, z −53..−47. Deck at 12 by a 30-stud truss; roof at 26. | |
| South Gate | Torii at z 27 and 58 (posts x ±3). Gatehouse at (0, 48): piers 4 × 6 × 10 at x ±(3..7), deck at 6, roof at 10, 16-stud truss. | Opening 6 × 6 |
| Dorms | x ±(37..51), z −21..1, 22 × 14 × 8, long axis on Z. Balcony x ±(35..37) at h 5. | Parts in §2.3 |
| Training ring | Mud disc r 12 at (−28, 38); **6 posts 0.8 × 3 at r 12** on bearings 30 + 60k | Boss stage |
| Pond garden | Water r 8 at (32, 36); arched bridge north–south at x 32, z 28..44; rocks at (41, 30), (23, 41), (40, 43) | Reflecting pool (§4.1) |
| Training pillars | (±18, ±14), 2 × 19 | |
| Training stones (8) | (±8, −14), (±24, −12), (±8, 15), (±24, 14); each 2 × 1.2 × 3 | |
| **Path lanterns** (6, 3 lit) | x ±5.5 at z 53, 62, 66 | Moved clear of the (0, 36) boss box |
| Old cedars (14) | NE (34,−38) h40, (40,−42) 44, (46,−37) 36; NW mirrored; SE (46,26) 38, (50,34) 42, (44,44) 36; SW (−46,26) 38, (−44,34) 42, (−52,20) 36; **gate (±12, 56) 34** | Core hit at 0.95·h |
| Backdrop | 24 cedars at 90–140; terrain mountains | |

**Anchors:** pillars 19; Bell Tower 26; cedar cores 32.3–41.8. The check covers 41 grid points with 0 uncovered.

**Pads** (10, 4 boss; min gap 0.5 u)

| | | | | |
|---|---|---|---|---|
| (−28, 38) B | (0, 36) B | (42, 10) B | (−42, 10) B | (20, 4) |
| (−20, 4) | (22, −40) | (−22, −40) | (39, −29) | (−39, −29) |

**Height:** cloister 5, balconies 5, gatehouse 6, podium 3, Bell Tower 12.

**Budget: 338 parts / 17 lights** (`THEME_BUDGET` 370 / 20)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Stone lanterns | 8 | 4 |
| Cloister (4 roofs, 26 posts, 8 rails, 8 ramps, 2 landings) | 48 | 0 |
| Hanging lanterns | 4 | 4 |
| Main Hall | 17 | 1 |
| Bell Tower | 11 | 1 |
| Gatehouse | 7 | 1 |
| Torii | 8 | 0 |
| Dorms | 20 | 2 |
| Ring posts | 6 | 0 |
| Pond | 8 | 0 |
| Pillars | 8 | 0 |
| Stones | 8 | 0 |
| Cedars (14 × 5) | 70 | 0 |
| Backdrop | 72 | 0 |
| Path lanterns | 12 | 3 |
| **Total** | **338** | **17** |

### 3.3 Tombs of the Star Vault: "The Ribbed Vault" (night)

**Vault**
- 12 pillars 3 × 3 at r 34 on bearings 30k, from the floor to h 57.
- 12 radial ribs 3 × 1.5 with the **underside at h 57**, from r 12 to r 34.
- A crown ring and an outer ring beam. The oculus over r < 12 is open, with stars visible through it and between the ribs.
- Nothing extends past r 57.

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
| **Processional Gallery** (upper loop, **h 8**) | 12 chord decks 6 wide at r 49–55, underside 7.6. **12 posts at r 49 on bearings 30k** (in line with the pillars). Inner rail. | Gates under it are 6.5 tall |
| Gallery accesses | **8 tangential ramps**, 4 wide, rise 8, run 14, at r 45–49 on bearings 22.5 + 45k, each with a 4 × 4 landing flush against the deck edge | Largest gap about 20 u |
| Outer wall | r 55–57, 16 tall. The 4 cardinal segments are Star Gates (opening 6 × 6.5), with lit braziers at the gates. | |
| Crystal groves | **r 20** on bearings 45 + 90k; 5 crystals each inside a 6 × 6 × 4 patch | 1 light each |
| Braziers | 3 at r 38 on bearings 15, 105 and 195 | 1 light each |
| Sarcophagi | 8 pairs at r 30 on bearings 22.5 + 45k; each pair about 7 × 7 × 2.4 | Cover |

**Anchors:** ribs 57, sampled at r 14, 23 and 34 on each bearing; pillars 57. The check covers 64 grid points with 0 uncovered.

**Pads** (11, 4 boss; min gap 0.5 u)

| | | | |
|---|---|---|---|
| (28.3, 28.3) B | (−28.3, 28.3) B | (−28.3, −28.3) B | (28.3, −28.3) B |
| (24, 0) | (0, 24) | (−24, 0) | (0, −26, h 3), dais top |
| (42, 0) | (0, 42) | (−42, 0) | |

**Height:** dais 3, gallery 8, star chains, ribs.

**Budget: 288 parts / 13 lights** (`THEME_BUDGET` 320 / 16)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Pillars | 48 | 0 |
| Ribs and rings | 36 | 0 |
| Dais | 15 | 1 |
| Inlays | 4 | 0 |
| Gallery (12 decks, 12 rails, 12 posts, 8 ramps, 8 landings) | 52 | 0 |
| Wall and niches | 32 | 0 |
| Gate braziers | 4 | 4 |
| Crystals | 20 | 4 |
| Braziers | 6 | 3 |
| Sarcophagi | 32 | 0 |
| Star chains (4 cores, 4 stars) | 8 | 0 |
| **Total** | **288** | **13** |

### 3.4 Kyoto Imperial Academy: "The Walled Compound" (dusk, blossom)

**Octagonal wall (upper loop, h 6.5)**
- Apothem 54, flats centred on bearings 45k, each flat 44.7 long.
- 3 thick (inner face at apothem 52.5) and 6.5 tall. Wall-walk 3 wide with an outer rail.

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| Main gate | S flat: an 8 u gap (x −4..4) bridged by the gatehouse deck (underside 6, top 6.5), roof on 4 posts to 10. Stair flights (3 wide, rise 6.5) on the inner face at x ±(4..15.4), z 49.5..52.5. | Opening 8 × 6 |
| **Watchtowers** (B5) | Outside the wall at the diagonal flats' midpoints, apothem 58.5: (±41.4, ±41.4). The door is at the wall-walk. **The truss is on the tower's inner face, standing on the wall-walk: h 6.5 → 13, 16 studs** (the outer rail has a 3 u gap there). Roof at 20. | |
| Wall accesses (9; max gap about 20 u) | Tangential ramps (3 × 11.4) with 3 × 3 landings, centred at (51, 0), (−51, 0) and (0, −51). **Tower ramps** centred at (±43.1, ±29.0), running along the diagonal flat: foot toward the tower, top plus landing toward the E or W vertex. Plus the 2 gate stairs. | |
| **Five-Tier Pagoda** (hero) | (0, −38): base 12 × 12 (x −6..6, z −44..−32), 6 u per tier, top at 36. Ledge 16 × 16 at h 6 with rails. Stair 6 wide at z −30..−19.5. | |
| Thousand-Gate Path | 8 torii (posts x ±3) at z 16 + 4.9k, up to 50.3 | |
| Lecture halls (B4) | **18 × 12**: x ±(20..38), z −20..−8 | Shortened 2 u to free (±45, −14) |
| **Bamboo grove** | 36 canes 0.5 across, 14–22 tall, plus 18 tufts (decor). Seeded in the SW quadrant (x −50..−20, z 4..34, apothem ≤ 49.5), rejected inside pad boxes plus 0.5, which leaves the (−36, 20) clearing | |
| Pond garden | Water r 9 at (36, 18); red arch at x 36, z 10..26; tea pavilion (§2.3) on a deck at x 32..40, z 0..8; 4 rocks | |
| Old cedars (h 34, core 32.3) | (±38, −28), (±20, 44), **(±46, 4)**, **(±14, 10)** | |
| Blossom trees | 14 seeded at r 22–30 | |
| Stone lanterns | 8 at r 24 on bearings 22.5 + 45k | |
| Backdrop | 12 cedars; mountains | |

**Anchors:** pagoda 36; towers 20; cedars 32.3. The check covers 64 grid points with 0 uncovered.

**Pads** (11, 4 boss; min gap 1.0 u)

| | | | | |
|---|---|---|---|---|
| (26, −30) B | (−26, −30) B | (24, 32) B | (−24, 32) B | (15, −28) |
| (−15, −28) | (24, 0) | (−24, 0) | (−36, 20), bamboo clearing | (45, −14) |
| (−45, −14) | | | | |

**Height:** wall-walk 6.5, towers 13, pagoda ledge 6, tea deck 1.5.

**Budget: 434 parts / 18 lights** (`THEME_BUDGET` 470 / 21)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Wall | 18 | 0 |
| Ramps and landings | 14 | 0 |
| Gate stairs | 18 | 0 |
| Gatehouse | 7 | 1 |
| Towers | 40 | 4 |
| Pagoda | 24 | 1 |
| Torii | 32 | 0 |
| Halls | 28 | 2 |
| Bamboo | 54 | 0 |
| Pond | 20 | 1 |
| Blossoms | 56 | 0 |
| Lanterns | 16 | 8 |
| Cedars (8 × 5) | 40 | 0 |
| Backdrop | 36 | 0 |
| **Total** | **434** | **18** |

### 3.5 Survival Colony: "The Sealed Block" (dusk, ash)

**The Broken Overpass (upper U, h 7)**
- 8 chord decks of 17.2 × 8 at r 40–48, top at 7, underside 6.2, running from bearing 180 through 270 to 360.
- **9 piers, each 2 × 2 × 7**, at r 44 on bearings 180 + 22.5k. Concrete rails on both edges.

**Accesses** (6; max gap about 21.6 u)
- **Radial on-ramps**, 8 wide, rise 7, running outward from r 48 to r 60.25 on bearings **354°** and **186°**.
- **Fallen Span:** an inward spur from the inner edge at (22.2, −33.3, h 7) down to (14.4, −21.6), 8 wide at 26.6°. The loop above it stays whole.
- **Switchback** (w 4, rise 7) running outward from r 48 on bearing 247.5, footprint 8 × 10.1.
- **Trusses** (18 studs) on the piers at 202.5° and 337.5°.

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| Sign gantries | Pier joints at 225° and 315°: 2 posts **to 22**, a beam, and a SurfaceGui sign ("EXIT 7", "ZONE CLOSED") | |
| **Headcount Board** (hero) | (0, −30): board 20 × 10 from h 12 to 22, text "BLOCK 01 · HEADCOUNT". Legs are 2-truss pairs at x ±9 (z −30.5..−29.5, 30 studs). Catwalk 20 × 2 at h 12 on the south face, reached by the legs. | |
| **Container Yard** (SE) | See the table below | Court at (28, 31) |
| The Leaning Block | Arcade x −45..−31, z 28..38, tilted 6°. Annex x −30..−22, z 28..38, h 6. Rubble ramp x −28..−24, z 38..48.5, rising north onto the annex. Stairs (rise 3) up to the arcade roof. | |
| Scrap Market | Rows at **x −40 and −32**, stalls at z −14, −8, −2 (footprint z −16..0) | |
| **Quarantine fence** | 10 pylons (1.6 × 14 with an amber neon head) at r 100. **Beams** between neighbouring pylons: amber, `LightEmission 1`, width 20 studs, Transparency 0.6, 0 parts. | Replaces the dome |
| Floodlight masts (22) | (±48, 24), (±24, 46) | |
| Burning barrels | (±13, ±13) | 2 lit |
| Cover | 14 wrecked cars, 10 jersey barriers, 12 rubble blocks (seeded, with rejection) | |
| Skyline | **7 fixed towers 14 × 14 × 34** at (±64, −4), (±52, −40), (0, −66), (±34, 62); 15 seeded tilted towers at 70–110 (not counted as anchors) | |

**Container Yard** (each container 6 × 2.5 × 2.6)

| Container | Footprint | Height | Access |
|---|---|---|---|
| A | x 17.75..20.25, z 24..30 | G stacked on it, top 5.2 | Ramp to G faces **west**: x 8.65..17.75, z 25.5..28.5, rise 5.2 |
| B | x 17.75..20.25, z 30.5..36.5 | 2.6 | |
| C | x 35.75..38.25, z 24..30 | 2.6 | |
| D | x 35.75..38.25, z 32..38 | H stacked on it, top 5.2 | Ramp to H faces **east**: x 38.25..47.35, z 33.5..36.5 |
| E | x 25..31, z 19.75..22.25 | 2.6 | Ramp faces **north**: x 26.5..29.5, z 15.2..19.75 |
| F | x 25..31, z 39.75..42.25 | 2.6 | |

**Anchors:** board 22; gantries 22; floodlights 22; the 7 fixed towers 34. The check covers 60 grid points with 0 uncovered.

**Pads** (10, 3 boss; min gap 1.0 u; none under the deck)

| | | | | |
|---|---|---|---|---|
| (0, 40) B | (40, 13) B | (−40, 13) B | (28, 31), yard court | (−22, −22) |
| (32, −12) | (0, −23) | (−14, 28) | (−20, −2) | (22, 6) |

**Height:** overpass 7, catwalk 12, containers 2.6 and 5.2, annex 6, arcade about 9.

**Budget: 387 parts / 18 lights** (`THEME_BUDGET` 420 / 21)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Overpass | 43 | 0 |
| Gantries | 8 | 2 |
| Board | 8 | 1 |
| Yard | 23 | 0 |
| Leaning Block | 23 | 1 |
| Market | 30 | 3 |
| Fence pylons | 20 | 0 |
| Floodlights | 8 | 4 |
| Barrels | 4 | 2 |
| Wrecks | 56 | 0 |
| Jersey barriers | 10 | 0 |
| Rubble | 12 | 0 |
| Skyline (7 × 5 + 15 × 4) | 95 | 0 |
| Lamps | 16 | 4 |
| **Total** | **387** | **18** |

### 3.6 Dunewatch: a caravan ksar (noon)

**Set pieces**

| Piece | Position and size | Notes |
|---|---|---|
| Well Square | Sundial inlay (decor) | |
| **Covered Souk** | Street z −3..3, **x 14..40**. 6 stalls at x 18, 26 and 34 on both sides (counters at z ±3.75..±5.25). Awnings at h 5 and 4 beams, all decor. | No pads |
| **Quarters** | 24 × 24 blocks centred at **(30, −24), (−30, −24) and (30, 26)**. Each holds 4 B6 houses of 9 × 9 at (cx ± 7.5, cz ± 7.5), with 6 u alleys. | |
| **Citadel** (hero) | Lower terrace x −12..12, z −52..−36, h 4. Upper terrace x −8..8, z −51..−41, h 8. **Signal tower** 5 × 5 at (0, −48), top 38, with `Fire` and 1 light. | See access below |
| Cistern Oasis | Pool r 8 at (−28, 26). Palms at (−38, 26), (−35.1, 33.1), (−35.1, 18.9), (−28, 36), (−28, 16), **(−20, 30)**. Pergola 8 × 8 at (−14, 38). **Oasis masts (22)** at (−48, 30) and (−18, 46). | |
| Edge | 8 wall fragments 8 × 1 × 2.4 at r 52 on bearings 30, 110, 140, 170, 200, 220, 320, 340. Rock terrain ring at 70–86, open to the south. | |
| Caravan masts | **(±10, 56) h 22** and **(±12, −58) h 20** | |
| Cover | 16 crates, sacks and pots (seeded, with rejection) | |
| Backdrop | 8 mudbrick towers | |

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
- **Souk link:** 2 rope bridges of 26 u at x 22.5 (6.2 ↔ 6.2) and x 37.5 (7.4 ↔ 7.4).
- **Souk-facing trusses:** at (25, −11.6) and (25, 13.6), so the bridge midpoints are within 14 u of an access.
- **Windcatchers:** NE (37.5, −31.5) 26, (22.5, −16.5) 22; NW (−37.5, −31.5) 24, (−22.5, −16.5) 20; SE (22.5, 18.5) 22, (37.5, 33.5) 26.

**Anchors:** tower 38; windcatchers 20–26; caravan and oasis masts 20–22. Palms are not counted. The check covers 54 grid points with 0 uncovered.

**Pads** (10, 3 boss; min gap 1.0 u)

| | | | | |
|---|---|---|---|---|
| (0, 40) B | (−38, 6) B | (48, −2) B | (8, −22) | (−8, −22) |
| (11, 20) | (−14, 20) | (20, 45) | (22, −44) | (−22, −44) |

**Height:** roofs 5–7.4, terraces 4 and 8, windcatchers by swing.

**Budget: 330 parts / 9 lights** (`THEME_BUDGET` 360 / 12)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav, sundial | 33 | 1 |
| Souk (6 stalls, 4 beams) | 34 | 3 |
| Quarters | 111 | 0 |
| Trusses | 5 | 0 |
| Windcatchers | 18 | 0 |
| Rope bridges | 10 | 0 |
| Citadel (3 blocks, tower, fire, 3 ramps, landing, 3 rails) | 12 | 1 |
| Oasis | 35 | 0 |
| Wall fragments | 8 | 0 |
| Cover | 16 | 0 |
| Masts (6 × 2) | 12 | 2 |
| Backdrop | 24 | 0 |
| Oil lanterns | 12 | 2 |
| **Total** | **330** | **9** |

### 3.7 Quarry Hollow (afternoon)

**Setting:** a canyon bowl of Rock terrain beyond 58.

| Piece | Position and size | Notes |
|---|---|---|
| **Four Stacks** | 10 × 10 × 28 at (±22, ±22); cliff-dwelling windows (decor) | **Gallery** at h 10: 3 u strips, so each gallery spans 16 × 16. **Switchback** (w 4, rise 10, footprint 8 × 12.75) starting at the gallery's outer x edge and running outward: x ±(30..42.75), z = stack z ± 4. |
| Rock needles | (22, 0), (−22, 0), (0, 22), (−10, −22): core 4 × 4, cap 5 × 5 at h 10, spike to 14 | Reached only by bridges |
| **Rope Ring** (h 10) | 8 rope bridges. **Real spans from the gallery edge to the cap:** E, W and S pairs 11.5 u each; north 1.5 u (NW gallery to the needle at (−10, −22)) and 21.5 u (that needle to the NE gallery) | |
| Quarry benches | x ±(40..54), z −14..14, h 2. Glacis x ±(36.5..40). Shed (B3) on the bench at z −14..−4, roof at 11. | |
| **Quarry Crane** (hero) | A-frame base x −4..4, z −49..−43, **top at 40**. Jib 1 × 1 × 24 at h 38 from z −52 to −28 (solid, an anchor). Counterweight 3³ at z −52, h 34–37. **Hook block 3 × 3 × 3 at (0, −34), h 20–23** (solid). Rope (decor). | The spawn sightline passes over the N rope bridge at h 12.5 and under the hook |
| Stone Gate | Piers 4 × 4 × 18 at x ±13, z 54..58; lintel top at 20 | Swing-only perch |
| Backdrop needles (5 × 5) | r 50 at bearing 30 (h 34), 60 (40), 120 (30), 150 (44), 210 (38), 240 (32), 300 (42), 330 (36) | |
| Detail | 24 boulders and 12 cut blocks (seeded, with rejection); ore carts; 6 pole lanterns | |

**Anchors:** stacks 28; crane 40; hook 23; gate 20; needles 30–44. The check covers 60 grid points with 0 uncovered.

**Pads** (10, 6 boss; min gap 0.5 u)

| | | | | |
|---|---|---|---|---|
| (14, −36) B | (−14, −36) B | (14, 36) B | (−14, 36) B | (47, 6, h 2) B |
| (−47, 6, h 2) B | (30, 10) | (30, −10) | (−30, 10) | (−30, −10) |

**Height:** benches 2, galleries and ring 10, shed 11, gate lintel and jib by swing.

**Budget: 256 parts / 14 lights** (`THEME_BUDGET` 280 / 16)

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
| **Total** | **256** | **14** |

### 3.8 Mistreach: a stilt village (morning, fog 22–130)

| Piece | Position and size | Notes |
|---|---|---|
| **Lighthouse** (hero) | Tower r 3 at (0, −50), 32 tall. Gallery 9 × 9 at 26. **64-stud truss** at z −45.5..−44.67. Lamp room; cap. | **Beam**: a decor neon wedge 2 × 2 × 30, Transparency 0.6, **tagged `Spin`** with attribute `Spin = 20` (§4.1) |
| Plaza | Disc r 14 raised 0.5; inlay; 10 mooring posts (decor) at r 17 | |
| Canal | Water 6 wide on z = 0 from x 16 to the shore; arched bridges at x 26 and 42 (z −5.6..5.6) | |
| Tideline Walk | Boardwalk at r 55–60, h 0.4, 16 chords, outer rails | Ground loop |
| **Moorings** | 4 B7 houses at r 70, **22° apart**: E cluster on bearings −33, −11, 11, 33; W cluster on 147, 169, 191, 213. **12 u flat bridges** between decks (the gap is 12.7). A pier of 3 parts to the boardwalk. | 2 houses per cluster have net-loft balconies at h 6 (ladder, deck, 2 posts, rail) joined by a rope bridge |
| Fish Market | Stall rows along z ±4 at x −44..−28; drying racks at x −46 and −25 | |
| Shrine Grove | 6 pines at radius 6 around (28, 28), h 30, 32, 34, 36, 38, 32 (cores 28.5–36.1); altar 4 × 4 × 4; lantern | |
| Boatyard | Shed 8 × 8 × 7 at (20, −32). **Hulls: wedge pairs 4 × 6 × 2.5 at (12, −40) and (12, −26).** | |
| Net-lofts | 6 × 6 at h 5 (14-stud truss) at (−22, 34), **(−28, 40)**, **(−38, 28)**; 2 flat bridges | |
| **Harbour masts** (22) | (46, −20), (48, 18), (20, 47), (−22, 48), (−48, 4), (−24, −44) (lit); **(−42, −8), (42, −30), (−4, 26), (−44, 18)** (unlit, new) | |
| Ferry pier | South to (0, 80), with a lamp | |
| Detail | 10 island trees, 12 rocks, 16 crates (seeded, with rejection); 6 boardwalk lamps (3 lit) | |

**Anchors:** lighthouse 32; pines 28.5–36.1; 10 masts 22. The check covers 68 grid points with 0 uncovered.

**Pads** (10, 5 boss; all on land; min gap 0.6 u)

| | | | | |
|---|---|---|---|---|
| (32, −16) B | (33, −36) B | (0, 44) B | (12, 36) B | (0, −36) B |
| (30, 14) | (−32, 16) | (−32, −16) | (−12, 36) | (−33, −36) |

**Height:** net-lofts 5, balconies 6, lighthouse gallery 26, masts by swing.

**Budget: 442 parts / 25 lights** (`THEME_BUDGET` 480 / 28)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Lighthouse | 11 | 2 |
| Plaza | 13 | 0 |
| Canal bridges | 10 | 0 |
| Tideline | 32 | 0 |
| **Moorings** (per cluster: 36 houses + 9 bridges + 3 pier + 10 balconies + 5 rope = 63) | **126** | 8 |
| Market | 36 | 3 |
| Grove | 35 | 1 |
| Boatyard | 9 | 0 |
| Net-lofts | 24 | 0 |
| **Masts** (6 × 3 + 4 × 2) | **26** | 6 |
| Ferry pier | 9 | 1 |
| Trees | 40 | 0 |
| Rocks | 12 | 0 |
| Cover | 16 | 0 |
| Lamps | 12 | 3 |
| **Total** | **442** | **25** |

### 3.9 Thunderspire: a cliff monastery (storm, dusk)

| Piece | Position and size | Notes |
|---|---|---|
| Middle terrace | x −40..40, z −50..−20, h 3; glacis 8 wide at x −32, −16, 0, 16, 32 (z −20..−14.75) | |
| Upper terrace | x −20..20, z −56..−36, h 6; glacis at x −12, 0, 12 (z −36..−30.75) | |
| **Great Hall** (hero) | B4 26 × 14 at (0, −48), x −13..13, z −55..−41, top about 20. **Stupa spire** 4 × 4 at (0, −52) rising to **34**, with a bell and finial (decor). | |
| Rod towers | Base 4 × 4 × 14, copper mast to 26, neon tip with a light, at (±30, −8), (±44, −30), (±18, 30), **(±32, 46)** | Prayer flags are Beams |
| **Horn Pinnacles** | 14 × 14 × 40 at x ±(40..54), z −20..−6. **Ledge** 4 wide at h 8 on the inner face: x ±(36..40), z −20..−6. | See the ledge stair below |
| **Mid piers** | Deck 6 × 6 at h 7 at (±30, −26) (x 27..33, z −29..−23), on 4 posts standing on the terrace. **Ramp** from the terrace on the west face: x 20..27, z −27.5..−24.5, rise 4. | **Bridge** from the ledge's north end (38, −20) to the pier (about 6 u, 8 → 7). No bridge to the upper terrace. |
| Lower Court | **Pilgrim shelters (open B4 8 × 6) at (±16, 46)**; 12 cairns and 20 boulders (seeded, with rejection); 6 stone lanterns on the terraces | |
| Beyond | Snowfield beyond r 70; 10 rock spires; 4 far outbuildings | |

**Ledge stair** (4 pieces), running west along the pinnacle's south face (z −6..−2):

| Piece | x (east side; mirrored for west) | Height |
|---|---|---|
| Ramp 1 | 58 → 51 | 0 → 4 |
| Landing | 51..47 | 4 |
| Ramp 2 | 47 → 40 | 4 → 8 |
| **Top landing** | 40..36 | 8, joining the ledge |

**Upper route (U):** ground → ledge stair → ledge (8) → bridge → pier (7) → pier ramp → middle terrace (3) → glacis → upper terrace (6).

**Anchors:** pinnacles 40; spire 34; 8 rod towers 26. The check covers 68 grid points with 0 uncovered.

**Pads** (11, 5 boss; min gap 0.75 u)

| | | | | |
|---|---|---|---|---|
| (0, 40) B | (36, 14) B | (−36, 14) B | (29, −39, h 3) B | (−29, −39, h 3) B |
| (20, 6) | (−20, 6) | (0, −24, h 3) | (0, 26) | (38, 30) |
| (−38, 30) | | | | |

**Height:** terraces 3 and 6, piers 7, ledges 8, spire and pinnacles by swing.

**Budget: 198 parts / 18 lights** (`THEME_BUDGET` 220 / 21)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Terraces and glacis | 10 | 0 |
| Hall | 14 | 1 |
| Spire | 3 | 0 |
| Rod towers (8 × 3) | 24 | 8 |
| Pinnacles (2 × (3 blocks + 4 stair pieces + ledge + rail)) | 18 | 0 |
| Piers (2 × (deck, 4 posts, ramp, rail)) | 14 | 0 |
| Bridges | 6 | 0 |
| Shelters | 12 | 2 |
| Cairns | 12 | 0 |
| Boulders | 20 | 0 |
| Lanterns | 12 | 6 |
| Spires and outbuildings | 22 | 0 |
| **Total** | **198** | **18** |

### 3.10 The Seam: "The Stitchyard" (midnight, finale)

**The Hem**
- Basalt terrain out to r 18, with a crimson inlay at r 18.
- **Nothing collidable at r < 26.** The nearest part is at r 34.5.

**Nine Patches (terrain, 0 parts)**
- Each 40° sector from r 20 to 52 is painted with 3 rotated `FillBlock`s, each 32 × 12 × 4 studs.
- Materials: Asphalt, Ground, Cobblestone, Slate, Concrete, Sand, Rock, Grass, Snow, each with its own `SetMaterialColor`. These colours are reset at every build (§4.1).
- Crimson seam strips (decor) run along the borders.

**Vignettes.** Each vignette sits inside **two 7 × 7 u squares centred on bearing θ − 9 at r 38 and r 46**, and its anchor stands at r 42 on that bearing.

| θ | Patch | Vignette (anchor) | Parts / Lights |
|---|---|---|---|
| 0 | City | crosswalk (decor), car, lamp, **pylon 20** | 13 / 2 |
| 40 | Academy | torii, lantern, **cedar core 28.5** | 11 / 1 |
| 80 | Colony | 2-high container stack, ramp to 5.2, **gantry 20** | 7 / 0 |
| 120 | Wind | house (roof 6) with ramp, **windcatcher 20** | 10 / 0 |
| 160 | Earth | **rock stack 20**, switchback to a ledge at 8 | 7 / 0 |
| 200 | Water | stilt deck at 5 with ramp, hut, **mast 22** | 11 / 1 |
| 240 | Kyoto | 3-torii tunnel, **pagoda tiers 16** | 16 / 0 |
| 280 | Lightning (hero, due north at (0.7, −42)) | **rod tower 26**, rock horn 24 at bearing 266 | 4 / 1 |
| 320 | Star Vault | **2 star pillars 24** (r 42 at bearing 311, r 46 at bearing 316), crystals | 13 / 1 |

**Thread Walk (behind the spawn)**
- Runs along bearings **71 → 111 → 151 → 191** at r 42: container top (5.2) → roof (6) → ledge (8) → deck (5).
- 3 rope bridges with about **21.7 u** clear span, with crimson neon rope rails.
- Each end comes down by its vignette's ramp or switchback.

**Beyond**
- 18 sky threads (decor).
- 12 fragments at r 60–90. **Only the 4 at r 64 on bearings 20, 110, 200 and 290, h 26–34, are collidable** (anchors and perches). The other 8 are decor.
- 6 stitched pillars 3 × 3 × 30 at r 56 on bearings 30 + 60k.

**Anchors:** 9 vignette anchors, 2 extra (the horn and the second star pillar), and 6 pillars at 30. The check covers 65 grid points with 0 uncovered.

**Pads** (12, 3 boss; min gap 0.28 u)
- **Normal pads at r 28, bearing θ + 11:** (27.5, 5.3), (17.6, 21.8), (−0.5, 28.0), (−18.4, 21.1), (−27.7, 4.4), (−24.0, −14.4), (−9.1, −26.5), (10.0, −26.1), (24.5, −13.6).
- **Boss pads at r 44, bearing θ + 11, for θ = 0, 280, 320:** (43.2, 8.4) B, (15.8, −41.1) B, (38.5, −21.3) B.

**Budget: 239 parts / 14 lights** (`THEME_BUDGET` 265 / 16)

| Item | Parts | Lights |
|---|---|---|
| Portal, weather, Nav | 31 | 1 |
| Hem and strips | 11 | 0 |
| Vignettes | 92 | 6 |
| Thread Walk | 15 | 0 |
| Threads | 18 | 0 |
| Fragments | 60 | 4 |
| Pillars | 12 | 3 |
| **Total** | **239** | **14** |

### 3.11 Summary

| World | Parts | Lights | `THEME_BUDGET` | Upper route (h) | Pads (boss) | Min pad gap | Grid points / uncovered | Hero |
|---|---|---|---|---|---|---|---|---|
| Times Square | 493 | 31 | 540 / 36 | 9 loop | 12 (4) | 0.5 | 70 / 0 | Beacon 36 |
| Sorcery Academy | 338 | 17 | 370 / 20 | 5 loop | 10 (4) | 0.5 | 41 / 0 | Main Hall |
| Star Vault | 288 | 13 | 320 / 16 | 8 loop, ribs 57 | 11 (4) | 0.5 | 64 / 0 | Keeper's Dais |
| Kyoto | 434 | 18 | 470 / 21 | 6.5 loop | 11 (4) | 1.0 | 64 / 0 | Pagoda 36 |
| Colony | 387 | 18 | 420 / 21 | 7 U, 12 catwalk | 10 (3) | 1.0 | 60 / 0 | Headcount Board |
| Dunewatch | 330 | 9 | 360 / 12 | 5–7.4 network | 10 (3) | 1.0 | 54 / 0 | Signal tower 38 |
| Quarry Hollow | 256 | 14 | 280 / 16 | 10 loop | 10 (6) | 0.5 | 60 / 0 | Crane 40 |
| Mistreach | 442 | 25 | 480 / 28 | 5–6 lofts, 0.4 ring | 10 (5) | 0.6 | 68 / 0 | Lighthouse 32 |
| Thunderspire | 198 | 18 | 220 / 21 | 3 / 6 / 7 / 8 U | 11 (5) | 0.75 | 68 / 0 | Hall and spire 34 |
| Seam | 239 | 14 | 265 / 16 | 5–8 U | 12 (3) | 0.28 | 65 / 0 | Rod tower 26 |

The largest world is 493 parts and 31 lights, against caps of 900 and 60.

---

## 4. Implementation

### 4.1 `src/server/Arenas.luau`

**Collision groups**, registered once when the module loads:

```lua
local PhysicsService = game:GetService("PhysicsService")
for _, g in { "Rail", "ShotRay" } do
  if not PhysicsService:IsCollisionGroupRegistered(g) then PhysicsService:RegisterCollisionGroup(g) end
end
PhysicsService:CollisionGroupSetCollidable("Rail", "ShotRay", false)
```

- `railPart(k, props)` sets `CollisionGroup = "Rail"`, `CanTouch = false`, and leaves CanCollide and CanQuery true.
- Other files:
  - `Projectiles.luau:34`: add `wallParams.CollisionGroup = "ShotRay"`.
  - `Abilities.luau` `clearPath` (about line 192): add `params.CollisionGroup = "ShotRay"`.
  - `Movement.findAnchor` is unchanged.

**Kit plumbing**
- `Kit` gains `parts`, `lights` and `L = Layouts[theme]`.
- `part()` and `light()` count as they create.
- At the end of `build`, `warn` if a count exceeds `THEME_BUDGET[theme]` or the 900 / 60 caps.

**Helpers**
- New: `at`, `frame`, `decor`, `railPart`, `core`, `ring`.
- Access and walkways: `ramp` (with `landing`), `stairs`, `switchback` (exact geometry in §2.1), `ledgeStair`, `ladder`, `deck`, `rail`, `bridge`, `arch`.
- Furniture: `stall`, `crate`, `container`, `jersey`.
- Buildings and anchors: `walkup`, `arcade`, `pavilion`, `watchtower`, `house`, `stilthouse`, `dorm`, `teahouse`, `windcatcher`, `palm`, `floodlight`, `pylonFence`.

**Changed functions**
- `tree`: crowns become decor, and cedars and pines get the core.
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
- `hill()` stays beyond 56.

**Spin:** `CollectionService:AddTag(beam, "Spin")`. `Fx` caches `CollectionService:GetTagged("Spin")` when the `Arena` child changes (from `ChildAdded` / `ChildRemoved` on `workspace`, next to the `Weather` code at about line 421). Each RenderStepped rotates the cached parts by their `Spin` attribute in degrees per second.

### 4.2 `Waves.spawnSpot(centre, boss)`

```lua
local used: { [Attachment]: number } = {}
local stamp = 0
function Waves.spawnSpot(centre: Vector3, boss: boolean?): Vector3
  local arena = workspace:FindFirstChild("Arena")
  local nav = arena and arena:FindFirstChild("Nav")
  if nav then
    local fresh, freshBoss, all = {}, {}, {}
    for _, a in nav:GetChildren() do
      if a:IsA("Attachment") and a.Name == "Pad" then
        local isBoss = a:GetAttribute("Boss") == true
        if boss and not isBoss then continue end
        table.insert(all, a)
        if not used[a] then table.insert(if isBoss and not boss then freshBoss else fresh, a) end
      end
    end
    -- normal packs: unused non-boss pads, then unused boss pads, then least-recently-used of all
    -- bosses: unused boss pads, then least-recently-used boss pads
    local pool = if #fresh > 0 then fresh elseif #freshBoss > 0 then freshBoss else all
    if pool == all then table.sort(all, function(p, q) return used[p] < used[q] end) end
    local need = ((if boss then Config.ENEMY_NOTICE_BOSS else Config.ENEMY_NOTICE) + 6) * STUDS
    local pick, bestGap = pool[1], -1
    for _, a in Rules.shuffled(pool) do            -- or a local Fisher-Yates
      local gap = math.huge
      for player in Combat.states do
        local root = Combat.rootOf(player)
        if root then gap = math.min(gap, ((root.Position - a.WorldPosition) * Vector3.new(1, 0, 1)).Magnitude) end
      end
      if gap >= need then pick = a break end
      if gap > bestGap then pick, bestGap = a, gap end
    end
    stamp += 1; used[pick] = stamp
    return pick.WorldPosition
  end
  -- no Nav (authored map): current ring, rejecting spots where a ray down hits Water or Nav.isClear fails
end
```

- `spawnCurrent` calls `table.clear(used)` at the start of each wave and passes `boss`.
- `Config.ENEMY_NOTICE_BOSS + 6 = 32` u, which is why every boss pad is at r ≥ 34.
- **Pads never go:**
  - within 6 u of a footprint (8 u for boss pads), tested as oriented boxes;
  - under a deck;
  - on thin decks;
  - in water;
  - at r < 20.

### 4.3 Enemy navigation: `src/server/Nav.luau` plus `Enemies.luau` (required)

**1. `Nav.moveTarget(e, target)`** replaces the direct `MoveTo` in the notice and chase branches.
- **Direct move** when `|ΔY| ≤ 3 u` and a Default-group `Spherecast` of radius 1·size u is clear. Rails block it, which is correct because rails stop bodies.
- **Otherwise, a path:**
  - `PathfindingService:CreatePath{ AgentRadius = 0.6*size*STUDS, AgentHeight = 2.4*size*STUDS, AgentCanJump = false, AgentCanClimb = true, Costs = { Water = math.huge } }`.
  - At most 1 compute per second per enemy and 8 in flight at once, each in `task.spawn`.
  - Advance to the next waypoint within 1.5 u; recompute when the goal drifts more than 6 u.
- **On `NoPath`:** use the nearest `Link` whose `Top` is within 10 u of the target: walk to its foot, then its top.

**2. Unstick.** If the enemy moves less than 0.5 u in 0.8 s: `hum.Jump = true`, sidestep 6 u for 0.6 s, then clear the path.

**3. Reach fallback.**
- **Trigger:** a non-ranged enemy has been hunting for more than 4 s, and either its path is `NoPath` or the target is more than 3 u above it within 18 u horizontally. Then `e.tossing = true`. It is cleared once the enemy has a path again, or the target comes within 3 u vertically.
- **Profile:** `TOSS = { cd = 3.5, power = 0 --[[set per enemy]], speed = 14, arc = true, size = 0.6, color = 0xb8a88a }`, with `power = Rules.round(e.t.atk * 0.5)` computed when used.
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
- **Swing coverage:** at each grid point, run the real `findAnchor` fan facing N, E, S and W. At least 3 of the 4 must succeed.
- **R0:** no CanCollide part at r < 12 and h < 3 other than the floor.
- **Budget:** report `k.parts` and `k.lights` against `THEME_BUDGET`.

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
  hero    = { x = 0, z = -26, top = 36 },
}
```

**Checks**, added to `tests/run.luau` with one `require`. They mirror the model I used to check this design.

1. **Pads.**
   - 20 ≤ r ≤ 50, and boss pads r ≥ 34. At least 10 pads, at least 3 of them boss pads.
   - **Oriented-box test:** each footprint is a rotated rectangle, tested on 4 axes against the axis-aligned box pad ± 6 (boss ± 8). It fails when the footprint's [h0, h1] overlaps [h + 0.3, h + 5.3] (boss [h + 0.3, h + 7.3]).
   - No pad inside `water`, and none under a `deck`.
2. **Walks:** every 3 u sample has an `access.top` within 25 u.
3. **Access:** ramps and stairs are at least 3 u wide, and each world has one of at least 4 u.
4. **Anchors:** the §1.5 rule at every grid point outside footprints taller than 3 u.
5. **R0:** no footprint at r < 12 with h0 < 3. Seam: no footprint at r < 26.
6. **Budgets:** parts ≤ 900 and lights ≤ 60.
7. **Hero sightline:** the segment from (0, 0, 2) to (hero.x, hero.z, 0.6·top) is not blocked by any footprint.

**Files touched**
- New:
  - `src/shared/Layouts.luau`
  - `src/server/Nav.luau`
  - `tests/layouts.spec.luau`
- Rewritten: `src/server/Arenas.luau`
- Changed:
  - `src/server/Enemies.luau`: movement hook, Unstick, toss, `clearSpot` for summons, wander.
  - `src/server/Combat.luau`: `tossing` field.
  - `src/server/Waves.luau`: pads.
  - `src/server/Projectiles.luau`: one line.
  - `src/server/Abilities.luau`: one line.
  - `src/server/FinaleFight.luau`: one line.
  - `src/client/Fx.luau`: `Spin` tag.
  - `tests/run.luau`: one `require`.
  - `web3d/rift3d.html`: 4 names, then `npm run export:roblox`, which regenerates `src/shared/Data/Maps.luau`.
  - `roblox/README.md`: line 95.
- Unchanged: `World.luau`, `Movement.luau`.

**Optional, out of track:** `Movement` could use `rope.Length = math.min(0.92*dist, hitHeight - 1.5u)`, so low anchors lift the player instead of dragging. Playtest before adopting. No world above depends on it.