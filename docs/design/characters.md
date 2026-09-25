# Character and Enemy Looks: Design v3 (Designer revision 2)

This design builds everything from R15 HumanoidDescriptions, Parts, WedgeParts, CornerWedgeParts, SpecialMesh `Sphere`, Welds, Beams, SurfaceGuis, ParticleEmitters, Highlights and PointLights. It uses no asset ids. Sizes are nominal studs at scale 1. At build time, each size and offset is multiplied componentwise by `host.Size / NOMINAL[host.Name]`.

**Changes from v2**
- All 9 blocking items are fixed. §7 lists each one and where it is handled.
- New primitives:
  - `Kit.ellipsoid` for any ball whose axes differ.
  - `Kit.paintParts` for colours on parts of a limb.
  - Client-driven `Gait_*` and `Orbit_*` welds.
  - `Costumes.role` with a fixed order of precedence.
  - A face made of two SurfaceGuis: one lit, one glowing.
- Redesigned for IP and readability: Aoi Hakumei, Threadrunner, Cackler with Glider Drone, Clawback, Redmaw, Gravewell, Tetsuo Hakushu, Haru Takane, Patchwork, Doctor Eightfold, the Unbidden's adaptation tiles and the Kage Inukai ward.
- Every part sum was recounted, including §4.3.

---

## 0. What the code does today

| # | Finding | Where | Consequence |
|---|---|---|---|
| F1 | Long hair, ponytails and buns sit at `-s.Z*0.5` / `-s.Z*0.45`. -Z is the face side. | `Looks.dressHair` | Hair covers the face. Move it to +Z. |
| F2 | Spiky hair adds up to 10 parts. | `dressHair` | Cap hair at 4 parts. |
| F3 | Nothing clears the default `face` decal. | `Looks.description` | Every enemy and boss smiles. |
| F4 | About 40 costume flags in `Characters.luau` / `EnemyLooks.luau` are never read. | `Looks` | The kit reads them (§2.7). |
| F5 | Generated data copies franchise trade dress: `webs`, `spider`, `whiskers`, `reactor`, `venomEyes`, `tieSpots`, `blindfold`, `eyePatch`, `sharingan`/`rinnegan`, `volcano`, forehead `stitches`, red-collar cloaks. | `Data/Characters.luau`, `Data/EnemyLooks.luau` | Needs a hand-written override layer (§6.1). |
| F6 | `ufo` (`shape="ufo"`) is not in `SHAPES`. `akatsuki_nin`, `gate_monk` and their `_alpha` variants have no look. | `Enemies.spawn` | They fall back to the default human. |
| F7 | Elites get a Highlight, but clients render at most 31 Highlights. On the Seam every non-boss is an elite (`bonus=1`, Waves.luau:101), with `MAX_ENEMIES=24`. | `Enemies.spawn` | Needs a Highlight budget (§6.4). |
| F8 | Wall raycasts can hit costume parts. | `Projectiles`, `Abilities.clearPath` | Every costume part is set `CanQuery=false, CanTouch=false, CanCollide=false, Massless=true`. |
| F9 | Franchise terms outside this track that must be renamed before publishing: `akatsuki_nin` "Red Cloud Cell"; "Cursed Womb"; "Finger Bearer"; "Kyoto Student"; "Summon Mahoraga" and the `MAHORAGA` banner (Abilities.luau:728); "Fox Chakra Mode"; "Domain: Unlimited Void"; "Malevolent Shrine"; "Self-Embodiment of Perfection"; "Horizon of the Captivating Skandha"; "Coffin of the Molten Mountain"; "Womb Profusion"; "The Phoenix Force"; "House Party Protocol"; "Heavenly Restriction"; "Spider-Sense" (Styles.luau passives); display names for arsenal keys `mark42`, `hulkbuster`, `warmachine`, `playful_cloud`, `split_soul`; the display name of the `pumpkin_bomb` drop. | data and UI strings | Keys are internal. Props are keyed by the current keys, so they survive a display-name-only rename. |
| F10 | `Rules.applyAffix` sets `t.color = a.color` (Rules.luau:410) before any look code runs. | `Enemies.spawn` | Elites get painted entirely in the affix colour. Fix: `pal.base` is captured before the affix (§4.1). |
| F11 | `description()` never reads `look.headScale` and sets HeadScale to 1. `buildNpc` then sets `d.HeadScale = size`. | `Looks.description`, `Looks.buildNpc` | Read `look.headScale` for the first time, clamped to 0.8–1.1, and have `buildNpc` do `d.HeadScale *= size` after the preset. |
| F12 | `Rules.rollAffix` returns nil when `boss` is set (Rules.luau:389). | Rules | Bosses never carry affix markers. |
| F13 | A Part with `Shape=Ball` is always a sphere. The existing `SHAPES` toad (2.6×1.9×2.6), wraith and imp, and the `dressHair` cap, all ask for ellipsoids and silently get spheres. | `creatureBody`, `dressHair` | All non-uniform balls use `Kit.ellipsoid` (§2.1). |
| F14 | All 32 `_alpha` templates have `boss = true`. So alphas never roll an affix (F12), and a naive "boss" check would give them boss dressing. | Data/Enemies.luau | Role is decided with a fixed precedence (§1.5). |
| F15 | `creatureBody` hides every R15 part, golem and imp limbs included. It welds with WeldConstraint at a world CFrame. | Enemies.luau:106 | Replaced by the `CREATURES` builders (§4.2). |
| F16 | `Rules.aiStep` leaves the tell state through `cancel` as well as through `lunge`/`endLunge` (Rules.luau:488). | Enemies.luau:426 | The Tell attribute must also clear on `cancel` (§5.2). |

---

## 1. Visual language

### 1.1 Silhouette rules
1. **One read shape above the shoulders.** Examples: hair mass, hood, horns, crest, hat, mask, beak, or an orbiting ring.
2. **At most one large back element.** Examples: cape, coat tails, back weapon, back arms, wings, a halo of shards, or a glider. A mantle or shawl counts as shoulders, not back.
3. **Heroes are asymmetric, enemies are symmetric.** Every playable character has one asymmetric signature, such as one shoulder guard, one glove, one metal arm, one scarf tail, one ear cuff, or one forelock.
4. **Creatures break the human outline.** A creature's body is wider or longer than it is tall, or it floats on a tail. Visible R15 limbs are allowed only on golems and imps, where they read as that creature's own limbs.
5. **Glow carries information.** Neon parts and glowing SurfaceGuis are used only for:
   - foe eyes
   - a hero's signature accent
   - creature weak points
   - alpha, affix, stitched, ally and boss markers
   - nature colour

### 1.2 Proportion presets (applied in `description()`)

| Preset | WidthScale | DepthScale | HeadScale | BodyTypeScale | ProportionScale | Used by |
|---|---|---|---|---|---|---|
| `lean` | 0.88 | 0.9 | 1.0 | 0.3 | 0.6 | acrobats, ninjas, students |
| `standard` | 1.0 | 1.0 | 1.0 | 0.2 | 0.3 | default |
| `heavy` | 1.25 | 1.15 | 0.9 | 0.1 | 0.0 | brutes, golems, heavy suit |
| `small` | 0.95 | 0.95 | 1.35 | 0.0 | 0.0 | imps, the grey |
| `towering` | 1.1 | 1.0 | 0.8 | 0.5 | 1.0 | finale bosses |

- HeightScale is always `look.height`.
- `look.headScale` overrides the preset HeadScale and is clamped to 0.8–1.1.
- NPCs then multiply every scale by `size`, using `*=`.

### 1.3 Palette per universe (`WORLD_OF` → `WORLD_LABEL`)

| Universe | Base cloth | Metal / trim | Accent rule | Materials | Emblems |
|---|---|---|---|---|---|
| **Shinobi Lands** (`naruto`) | indigo `0x2b3350`, moss `0x4f6b3a`, sand `0xc9b48a`, wrap `0xe8e0d0` | steel `0x9aa4b0` | One warm accent, only on scarf, belt or wraps | Fabric, Metal | E1 Gust, only on buckles and shoulder guards. No forehead plates. |
| **Sorcerer's Academy** (`jjk`) | navy `0x1b1f2e` / `0x252c40`, black `0x14141c` | gold `0xc8a44a` | Violet `0xb06cff` or crimson `0x9b1a2a`, as glow only | Fabric, SmoothPlastic, Foil | E7 Seal Ring |
| **Skyline City** (`marvel`) | graphite `0x23262e`, gunmetal `0x4a4f58`, ivory `0xe8e4dc` | chrome `0xb8bec8` | One saturated hero colour plus 0.06-stud seams. No red on a masked figure, no red-and-blue pair, no spider or web marks, and no white lenses on a dark suit. | SmoothPlastic, Metal, Glass (small lenses only), Neon | E2 Knot, E3 Hex, E5 Droplet |
| **Elsewhere** (`other`) | teal `0x2f8f86`, off-white `0xf0e0d0`, black `0x181818` | none | A single accent | Fabric | a personal glyph |
| **The Seam** (finale) | bruise `0x3a0a14`, ash `0xc8b8b0` | thread crimson `0xff2d55` | crimson seams | Neon, Beams | E11 Seam |

### 1.4 Reading a figure at a glance

`base` is the template colour captured **before** `applyAffix`, or the `Costumes.ENEMY` variant override (§4.1).

| Role | Eyes | Body colour | Marker | Highlight | Light |
|---|---|---|---|---|---|
| **Player** | whites + iris, on FaceBase (lit) | full-saturation costume | signature trim, nameplate | none | none |
| **Normal foe** | iris only, on FaceGlow (unlit, Brightness 2.5) | every cloth colour lerped 20% toward `0x2a2a30` (§4.1) | none | none | none |
| **Alpha** | FaceGlow, gold `0xffd54a`, iris ×1.3 | 15% darker than normal | **Alpha crest**: 1 gold Neon CornerWedge 0.5×0.45×0.5 on top of the head or body, plus a `dust` emitter | **none** | **none** |
| **Elite** (affix) | FaceGlow tinted `affix.color` | `base` | **Affix ring** (§4.5) plus 1 motif piece | only within budget (§6.4) | none |
| **Stitched** (elite on a stitched map) | crimson | `base` | 2 crimson Neon strips replace the motif; ring turns `0xff2d55` | never | none |
| **Ally / Worn** | FaceBase (whites + iris) | `base` | ring or SD turns cyan `0x5ad4ff`; strips removed | released | none |
| **Character boss** | FaceGlow in the signature colour | the hero costume lerped 22% toward `0x14040a` | **Rift halo**: 3 Beams (0 parts), `aura` emitter | always | 1 PointLight (range 14, brightness 1.2) |
| **Finale boss** | §5 | §5 | §5 | always | §5 |

### 1.5 Role precedence (exclusive)

`Costumes.role(id, t, affix)` is a single if/elseif chain:

```lua
if Finale.ENEMIES[id] then return "finale"
elseif id:match("_alpha$") then return "alpha"
elseif t.boss then return "charBoss"
elseif affix then return "elite"
else return "normal" end
```

- If requiring `Finale.luau` would pull in Roblox services, the caller passes `isFinale` instead.
- Alphas never get a halo, a light, an `aura` emitter or a guaranteed Highlight.
- Alphas also never get an affix, because they are `boss=true` and `rollAffix` returns nil for bosses. So "alpha + elite" cannot happen.

---

## 2. The kit

### 2.1 Build conventions and primitives

**Primitives**

| Primitive | Construction | Notes |
|---|---|---|
| **Ellipsoid** | `Kit.ellipsoid(size)`: a `Block` Part at `size` with a child `SpecialMesh{MeshType=Enum.MeshType.Sphere, Scale=Vector3.one}` | 0 extra parts, no asset id. |
| **Ball** | `Shape=Ball` | Used only when all three axes are equal (written "Ball Ø d"). |
| **Cylinder** | `Size = Vector3.new(length, diameter, diameter)` | The cylinder axis is local X. |

Size notation in the tables:
- **"Ell A×B×C"** means an ellipsoid.
- **"Ball Ø d"** means a true sphere.
- **"Cyl Ø d × L"** means a cylinder with `Size = (L, d, d)`, then:
  - `CYL_UP = CFrame.Angles(0, 0, math.pi/2)`: vertical rods, hat crowns and brims, floor rings.
  - `CYL_FWD = CFrame.Angles(0, math.pi/2, 0)`: discs facing forward (goggles, cores, wrist spools seen from the front).
  - No rotation: a left-right rod.

**Weld rules**
- Every piece uses `Instance.new("Weld")`:
  - `Part0 = host`, `Part1 = piece`.
  - `C0 = (attachment and attachment.CFrame or CFrame.identity) * scaledOffset`.
  - `C1 = CFrame.identity`.
  - The piece's world CFrame is never set.
- This depends only on the rest pose, so it works on client-animated players and on server NPCs. `dressHair` moves to the same method.
- **Hinged pieces** (capes, tails, lapels) are written as `C0 = attach * CFrame.new(hinge) * rot * CFrame.new(0, -L/2, 0)`, so they rotate about their top edge.

**Piece properties**
- Every piece: `CanCollide=false, CanQuery=false, CanTouch=false, Massless=true, Anchored=false`.
- `CastShadow=false` when the largest side is under 0.6 studs.
- Pieces go in `Folder "Costume"` under the model.

**Client-driven welds (0 server cost)**

| Weld name | Tag | Attributes | What the client does |
|---|---|---|---|
| **`Gait_*`** | model tag `Gait` | `GaitPivot` (Vector3, in Part0 space), `GaitPhase` (0 or 0.5), `GaitAmp` (degrees) | Once, stores `rest = weld.C0`. Every frame: `weld.C0 = CFrame.new(p) * CFrame.Angles(math.rad(a*sin(2π(f·t + phase))), 0, 0) * CFrame.new(-p) * rest`, with `f = rootSpeed / (1.6·S)` Hz. `a` scales with `clamp(rootSpeed/4, 0, 1)`, so idle means still. |
| **`Orbit_*`** | model tag `Orbit` | `OrbitAxis` (Vector3), `OrbitRate` (revolutions/s), `OrbitPhase` | Rotates C0 about the axis through the host centre. |

- Client writes to a server Weld's C0 don't replicate and don't fight the server, because the server never rewrites them after the build.

**Anchor attachments** (standard R15)
- Head: `HairAttachment`, `HatAttachment`, `FaceFrontAttachment`.
- UpperTorso: `NeckAttachment`, `BodyFrontAttachment`, `BodyBackAttachment`, `Left/RightCollarAttachment`.
- LowerTorso: `WaistFront/Back/CenterAttachment`.
- UpperArm: `Left/RightShoulderAttachment`.
- Hand: `Left/RightGripAttachment`.
- Foot: `Left/RightFootAttachment`.
- LowerArm and LowerLeg pieces use the part itself.

**Axes and rotations**
- Axes: X right, Y up, **Z back** (−Z is the face side).
- `rx(d)`: positive tips the bottom forward (−Z).
- `rz(d)`: positive swings the bottom toward +X.

**Priority budget.** The builder mounts pieces in this order, and stops at the figure's costume budget:
1. FP (the face plate)
2. markers
3. kit pieces in listed order

Pieces that don't fit are skipped, so the last entries drop first. Each spec keeps its read shape and signature within its first 10 entries, and test 3 checks this.

**Nominal R15 sizes at scale 1**

| Part | Size |
|---|---|
| Head | 1.2³ |
| UpperTorso | 2×1.6×1 |
| LowerTorso | 2×0.4×1 |
| UpperArm | 1×1.17×1 |
| LowerArm | 1×1.05×1 |
| Hand | 1×0.3×1 |
| UpperLeg | 1×1.22×1 |
| LowerLeg | 1×1.19×1 |
| Foot | 1×0.3×1 |

**Ground and footprint**
- **Ground** in HumanoidRootPart (HRP) space is `y_g = −(HipHeight + HRP.Size.Y/2)`, read after the model is built and before it is parented.
- **Footprint** is:
  - `max(body.X, body.Z)` for creatures
  - `2.2 · WidthScale · size` for humans

### 2.2 Face-zone rule

- **Face zone**: FP's canvas top is at head y 0.325.
  - Eye row: head y 0.085–0.165.
  - Brows: head y 0.20–0.23.
  - **Eye zone**: x ∈ [−0.45, 0.45], y ∈ [0.06, 0.24].
- **Rule**: no piece except VB, VB·m, GG, FM or BK may have any surface in front of z = −0.60 (the head's front face) inside the eye zone.
  - Ellipsoids are tested analytically, and blocks and wedges as oriented boxes.
- **Worked check**: the HR cap at y 0.26 or 0.32 with z +0.06 reaches at most z −0.592 at y 0.24. It passes.

### 2.3 Kit pieces (count = parts)

| Code | Piece | Shape and size (studs at scale 1) | Host and C0 offset | Parts |
|---|---|---|---|---|
| **FP** | FacePlate (face canvas) | Block 0.9×0.55×0.02, Transparency 1 | Head `FaceFrontAttachment` (0, 0.05, −0.02) | 1 |
| **HR** | Hair cap | **Ell 1.30×1.02×1.32** | Head (0, 0.26, **+0.06**); (0, 0.32, +0.06) when HB is worn | 1 |
| HR·s | Spike | Wedge 0.28×0.7×0.42, `rx(-30)` | Head, crown ring r=0.34 at y 0.6, max 3 | 1 each |
| HR·w | Swept wedge | Wedge 0.3×0.45×0.8, `rz(±25)*rx(-15)` | Head (±0.35, 0.45, +0.1) | 1 each |
| HR·p | Panel / ponytail | Block 1.08×(0.6–1.5)×0.3 | Head (0, −0.25, +0.62) | 1 |
| HR·f | Forelock | Block 0.2×0.6×0.1 | Head (−0.42, 0.12, −0.6); x-span −0.52 to −0.32, clear of the eye (−0.31 to −0.17) | 1 |
| HR·k | Bun / topknot | Ball Ø0.54 | Head (0, 0.62, +0.45) bun; (0, 0.78, 0) topknot | 1 |
| HR·t | Tuft | Ball Ø0.45 | Head (±0.4, 0.5, 0) | 1 each |
| **HB** | Cloth headband | Block **1.40×0.2×1.40** | Head (0, **0.36**, **+0.06**); spans y 0.26–0.46 | 1 |
| HB·t | Knot tails | 2 Blocks 0.14×0.6×0.05, `rx(-20)*rz(±15)` | Head (±0.1, **0.30**, +0.8) | 2 |
| **VB** | Visor band | Block 1.28×0.2×0.14, Glass, Transparency 0.35 | FaceFront (0, 0.12, −0.02) | 1 |
| VB·m | Monocle | Cyl Ø0.34×0.05 `CYL_FWD`, Glass | FaceFront (+0.24, 0.12, −0.04) | 1 |
| **LM** | Lower mask | Block 1.26×0.5×1.26 | Head (0, −0.36, 0) | 1 |
| **CK** | Choker | Block 1.1×0.22×1.1 | UpperTorso `NeckAttachment` (0, 0.12, 0) | 1 |
| **FM** | Full mask | Ell 1.28×1.3×1.3 at the Head centre, plus either 2 lens Blocks 0.26×0.13×0.05 `rz(±14)` at FaceFront (±0.24, 0.1, −0.05) or 1 slit Block 0.9×0.1×0.05 at FaceFront (0, 0.12, −0.05) | as stated | 3 / 2 |
| **BK** | Beak | Wedge 0.35×0.35×0.8 | FaceFront (0, −0.05, −0.4) | 1 |
| **HD** | Hood (up) | shell Ell 1.45×1.4×1.2; 2 cheek-frame Wedges 0.12×1.1×0.7 | shell Head (0, 0.1, +0.35); frames Head (±0.66, 0, −0.1) | 3 |
| HD·d | Hood (down) | Ell 1.3×0.5×0.8 | `NeckAttachment` (0, −0.1, +0.55) | 1 |
| **HN** | Horns / branches | Wedge 0.18×0.55×0.24 pair `rz(∓20)`; branches: Cyl Ø0.12×0.7 `CYL_UP*rz(∓20)` | Head (±0.38, 0.55, 0) | 2 |
| **EP** | Ears / fin | Wedge 0.12×0.5×0.3 pair; fin Wedge 0.1×0.6×1.1 | Head (±0.4, 0.6, 0) / (0, 0.7, +0.1) | 1–2 |
| **EC** | Ear cuff | Cyl Ø0.15×0.08 `CYL_FWD*CFrame.Angles(0, π/2, 0)` | Head (+0.61, 0.0, 0) | 1 |
| **GG** | Goggles / headphones | 2 Cyl Ø0.36×0.06 `CYL_FWD` | FaceFront (±0.24, 0.12, −0.03); pushed-up: Head (±0.24, 0.5, −0.35) `rx(40)` | 2 |
| **CR** | Crest / crown | 4 CornerWedges 0.3×0.5×0.3 | Head ring r=0.4, y 0.55, 90° steps | 4 |
| **OR** | Orbit shard | Wedge 0.12×0.35×0.2, Neon | Head, on radius 0.95 at y 0.35, 120° apart; Weld `Orbit_n`, axis (0,1,0), 0.25 rev/s | 1 each |
| **SC** | Scarf | wrap Block 1.2×0.34×1.25; tail Block 0.36×1.3×0.08 | wrap `NeckAttachment` (0, −0.05, 0); tail hinged at `BodyBack` (±0.45, 0.35, +0.1) `rx(-12)` | 2 |
| **SG** | Shoulder guard | Block 1.1×0.3×1.15, `rz(±20)` | `L/RShoulderAttachment` (∓0.1, 0.12, 0) | 1 each |
| **HC** | High collar | Block 1.25×0.55×1.2 | `NeckAttachment` (0, 0.15, +0.05) | 1 |
| **LP** | Open lapels | 2 Wedges 0.5×1.1×0.08, `rz(±18)` | `BodyFront` (±0.35, 0.1, −0.04) | 2 |
| **VS** | Vest / coat body / chest plate | Block 2.08×1.5×1.12 | UpperTorso (0, −0.02, 0) | 1 |
| **EM** | Emblem plate | Block 0.55×0.55×0.05 + SurfaceGui | `BodyFront` (0, 0.2, −0.03) / `BodyBack` / `WaistFront` | 1 |
| **CT** | Coat tails | 2 Blocks 0.95×1.5×0.08 | hinged at `WaistBack` (±0.48, 0, +0.04), `rx(-14)*rz(∓6)`, hung −0.75 | 2 |
| **CP** | Cape / cloak | Block 1.9×**2.3**×0.08 | hinged at `BodyBack` (0, 0.55, +0.08), `rx(-12)`, hung −1.15 | 1 |
| **SB** | Sash / belt, + tail, + pouch | belt Block 2.1×0.22×1.1; tail Block 0.25×0.7×0.06; pouch Block 0.35×0.3×0.2 | `WaistCenter`; tail (0.6, −0.4, −0.56); pouch (−0.7, −0.05, −0.56) | 1 / +1 / +1 |
| **MT** | Mantle / pelt / shawl | Ell 2.5×0.65×1.4 | `NeckAttachment` (0, −0.15, +0.05) | 1 |
| **CO** | Core / pendant | Cyl Ø0.4×0.08 `CYL_FWD`, Neon; diamond: Block 0.35×0.35×0.08 `rz(45)` | `BodyFront` (0, 0.25, −0.05) | 1 |
| **BW** | Back / hip prop | §2.6; default sword = hilt Cyl Ø0.14×0.8 + blade Block 0.1×2.3×0.28 | `BodyBack` (0, 0, +0.12) `rz(35)` | 1–3 |
| **BA** | Back arm | segment 1 Cyl Ø0.22×1.4 `CYL_UP*rz(±40)`; segment 2 Cyl Ø0.22×1.4, a further `rz(±40)` | `BodyBack` (±0.5, ±0.35, +0.2) | 2 per arm |
| **TN** | Tendril | Wedge 0.2×1.4×0.3, `rx(-25)` | `BodyBack` (±0.35, −0.2, +0.2) | 1 each |
| **WG** | Glider / wings | Cyl Ø2.2×0.12 `CYL_UP*rx(-20)`; wings: Wedge pair 0.1×1.6×1.1 | `BodyBack` (0, 0.1, +0.3) / under the feet | 1–2 |
| **GL** | Glove / bracer | Block 1.08×0.5×1.08 | LowerArm (0, −0.28, 0) | 1 each |
| **FB** | Forearm blade | Wedge 0.08×1.0×0.3 (long curved: 0.08×1.6×0.35, `rx(15)`) | LowerArm (±0.52, −0.1, 0) | 1 each |
| **MA** | Metal arm | `Kit.paintParts` Metal, Reflectance 0.2 on that arm's 3 R15 parts, + 1 Neon seam Block 0.06×1.0×0.06 | LowerArm (±0.5, 0, 0) | 1 |
| **XA** | Extra arm pair | per arm: Block 0.8×1.1×0.8 + Block 0.75×1.2×0.75, `rx(30)*rz(side·35)` | UpperTorso (±1.05, −0.55, −0.3) | 4 |
| **WR** | Leg wrap / sneaker cuff | Block 1.08×0.5×1.08 | LowerLeg (0, −0.2, 0) | 1 each |
| **FS** | Fist + thumb | fist Block 1.4×1.0×1.2 + thumb Wedge 0.35×0.5×0.4 | fist RightHand (0, −0.1, 0); thumb RightHand (−0.55, 0.05, −0.35) `rz(20)` | 2 |
| **SD** | Ground shadow (floaters) | Cyl Ø(1.2·footprint)×0.05 `CYL_UP`, `0x101014`, Transparency 0.6 | HRP (0, y_g + 0.03, 0) | 1 |

**Band-over-hair rule.** `Kit.ringOver(capSize, capOffset, y)` returns a Vector2:

```
X = 2·(capSize.X/2)·√(1 − ((y − capOffset.Y)/(capSize.Y/2))²) + 0.06
Z = 2·(capSize.Z/2)·√(…) + 0.06
```

Any band must be at least that wide on **both** axes and must be centred on the cap's z.

HB check at y 0.36, with the cap at y 0.32 and z +0.06:
- Required: X ≥ 1.356 and Z ≥ 1.376.
- The HB Block is 1.40×1.40, so it passes.
- The HB bottom at y 0.26 sits above the brow top at 0.23.

### 2.4 Face system (on FP; 0 extra parts)

**Setup**
- `Head.face` (Decal) is destroyed.
- Two SurfaceGuis are adorned to FP `Face=Front`, both with:
  - `SizingMode=PixelsPerStud`, `PixelsPerStud=100` (canvas 90×55)
  - `ClipsDescendants=false`, `MaxDistance=120`
- **FaceBase**: `LightInfluence=1`, `Brightness=1`, `ZOffset=0`. Holds whites, pupils, brows, mouth and marks.
- **FaceGlow**: `LightInfluence=0`, `Brightness=2.5`, `ZOffset=1`. Holds glowing irises and glowing marks.
- LightInfluence and Brightness are per SurfaceGui, not per Frame. That is why there are two.

**Friend face** (players, allies)

| Element | Size | Position | Colour / notes |
|---|---|---|---|
| Whites | Frame 14×8, UICorner 3 | centred (21,20) and (69,20) | on FaceBase |
| Iris | 7×8 | in the whites | `look.eye` |
| Pupil | 3×5 | in the iris | `0x101014` |
| Brows | 16×3 | (21,11) and (69,11) | `look.brow or look.hair`, `Rotation=±browAngle·57` |
| Mouth | 10×2 | centred (45,46) | `0x3a2020` |

- The mouth is hidden under LM, FM, CK-mask and BK.
- **Technique glow** for players: FaceGlow holds matching iris overlays with `Enabled=false`. `Looks.setGlow(character, color, on)` turns them on.

**Foe face**
- Irises 12×6 live on FaceGlow.
- Whites and pupils are `Visible=false`.

**`Kit.ally`**
- Reparents the irises from FaceGlow to FaceBase and resizes them to 7×8.
- Shows the whites and pupils.
- Sets `FaceGlow.Enabled=false`.

**Marks**
- Up to 4 Frames per face. They may overflow the canvas.

**Chest maw** (symbiote family, 0 parts)
- A SurfaceGui on UpperTorso Front: a dark band 160×40.
- Teeth are Frames rotated 45°, sized 6–16 px, at irregular spacing. Half of each sits under the band via ZIndex, which gives jagged fangs rather than a grin.

### 2.5 Emblem library (SurfaceGui, at most 6 Frames each, original)

| E | Name | Construction |
|---|---|---|
| E1 | Gust | 3 bars 60×6, `Rotation=-20`, 12 px apart |
| E2 | Knot | 3 transparent Ø26 circles, UIStroke 4, centres 14 px out at 90°/210°/330° |
| E3 | Hex core | three 40×24 Frames at 0°/60°/120° plus a centre dot |
| E4 | Crescent | a filled circle overlapped by a base-colour circle offset 12 px |
| E5 | Droplet | Ø36 circle plus a 26 square at 45° on top |
| E6 | Chevron | two 40×8 bars at ±35° |
| E7 | Seal ring | UIStroke ring Ø50, 4 ticks, centre dot |
| E8 | Film strip | a bar with 4 sprocket squares above and 4 below |
| E9 | Pips | a rounded square with 3 diagonal dots |
| E10 | Star-flare | 4 thin 6×40 diamonds crossed |
| E11 | Seam | 5 dashes 8×3 with 5 cross-ticks |

### 2.6 Props and swaps: `Costumes.ARSENAL_PROP[styleId][weaponKey]`

**How swaps work**
- `Combat` sets the player attribute `Weapon` (Combat.luau:284).
- `Looks.dress` connects `player:GetAttributeChangedSignal("Weapon")` and `"Suit"` once per character.
- Both connections are disconnected on `character.Destroying`, so they don't leak across respawns or transforms.
- On a change, `Kit.prop(character, styleId, key)` destroys the Costume child `Prop` and mounts the new prop, at most 3 parts.
- Lookups are two-level because `knife` exists in both the yuji and tophat orders.

| Style | Key | Prop | Host | Parts |
|---|---|---|---|---|
| toji | `spear_chain` | shaft Cyl Ø0.12×4.5 + blade Wedge 0.1×0.6×0.25; chain = Beam to the belt | BodyBack `rz(35)` | 2 |
| toji | `split_soul` | hilt Cyl Ø0.14×0.8 + blade Block 0.1×2.4×0.26 | BodyBack `rz(-35)` | 2 |
| toji | `playful_cloud` | 3 Cyl Ø0.2×1.3 end to end | BodyBack `rz(35)` | 3 |
| toji | `slaughter_demon` | hilt + blade Block 0.1×1.2×0.3 | WaistBack (0.7, 0, 0) `rz(15)` | 2 |
| maki | `naginata` | shaft Cyl Ø0.14×4.2 + blade Wedge 0.1×1.0×0.3 | BodyBack `rz(30)` | 2 |
| maki | `playful_cloud_m` | as `playful_cloud` | BodyBack | 3 |
| maki | `split_soul_m` | as `split_soul` | BodyBack `rz(-30)` | 2 |
| maki | `kusarigama` | handle Cyl Ø0.12×0.8 + sickle Wedge 0.08×0.4×0.7; chain Beam | WaistBack (−0.7, 0, 0) | 2 |
| yuji | `fists` | none; GL tape recoloured `0xd8683a` | n/a | 0 |
| yuji | `knife` | sheath Block 0.18×0.8×0.3 + grip Cyl Ø0.1×0.35 | WaistBack (0.7, 0, 0) | 2 |
| yuji | `slaughter` | cleaver Block 0.1×1.3×0.5 + grip | BodyBack `rz(20)` | 2 |
| tophat | `pistol` | holster Block 0.3×0.6×0.25 + grip Block 0.15×0.3×0.2 | WaistBack (0.7, 0, 0) | 2 |
| tophat | `rifle` | barrel Cyl Ø0.12×2.6 + stock Block 0.2×0.35×0.9 | BodyBack `rz(40)` | 2 |
| tophat | `sniper` | barrel Cyl Ø0.1×3.2 + stock + scope Cyl Ø0.16×0.7 | BodyBack `rz(40)` | 3 |
| tophat | `rpg` | tube Cyl Ø0.35×2.4 + warhead Ball Ø0.4 | BodyBack `rz(60)` | 2 |
| tophat | `knife` | as yuji `knife` | right hip | 2 |
| ironman | `mark42` | graphite `0x3a4250` + ivory `0xe8e4dc`, `standard` | n/a | 0 |
| ironman | `hulkbuster` | `0x5a6270` + ivory, preset `heavy`, SG ×1.3 | n/a | 0 |
| ironman | `bleeding` | Metal Reflectance 0.3 `0x2a3040`, cyan seams `0x5ad4ff` | n/a | 0 |
| ironman | `warmachine` | gunmetal `0x3a3f46`, shoulder cannon Cyl Ø0.35×1.4 + Neon muzzle Cyl Ø0.3×0.1 | RightShoulderAttachment | 2 |

**Suit swap** (no respawn):
1. `hum:ApplyDescription(newDesc)`.
2. `Looks.redress(character)`: destroys Costume and FP, rebuilds them, then re-runs `Kit.paintParts`. ApplyDescription resets part colours, so the paint must be reapplied.

**Symbiote suit hook**
- Styles marked `suitTN = true` (Threadrunner) mount TN×2 while the player attribute `Suit` (Combat.publish, Combat.luau:280) is above 0.
- The tendrils are removed at 0 or nil.
- They are inserted just after the style's `sig` entry, and budget trimming drops the style's last entries.
- Blackmaw and Antidote *are* the suit, so their looks are permanent.

### 2.7 Data flags → kit, and IP remaps

**Kept flags**

| Flag | Kit piece |
|---|---|
| `headband` | HB (cloth only) |
| `maskLower` | LM |
| `mask` | FM |
| `hood` | HD |
| `horns` | HN |
| `goggles` / `specs` | GG |
| `collar` | HC |
| `vest` | VS |
| `cape` | CP |
| `sash` / `belt` | SB |
| `pouch` | SB pouch |
| `shoulders` | SG |
| `sword` | BW |
| `tentacles` | BA×4 |
| `metalArm` | MA |
| `claws` | FB |
| `fourArms` | XA |
| `tendrils` | TN |
| `sandals` | WR |
| `uniform` / `cuff` / `clasps` / `buckle` | HC + SurfaceGui buttons |
| `scar` / `markStripe` / `markings` | face marks |

**Banned flags** (`Costumes.BANNED`) and their replacements

| Banned flag | Replacement |
|---|---|
| `webs`, `spider`, `whiskers`, `eyePatch` | nothing |
| `reactor` | E3 or the CO diamond |
| `venomEyes` | FM slit |
| `tieSpots` | stripes |
| `blindfold` | nothing (no eye band on pale-haired sorcerers) |
| `sharingan`, `rinnegan` | FaceGlow during techniques |
| `volcano` | CR rock crown |
| forehead `stitches` | a vertical right-side seam |
| `headbandPlate` | cloth HB |
| `scratchedPlate` | nothing |

### 2.8 `Kit.paintParts(model, map)`

`map` has the form `{[R15PartName] = {color, material?, reflectance?}}`. HumanoidDescription colours only whole limbs (Head, Torso, LeftArm, RightArm, LeftLeg, RightLeg), so anything smaller goes through this pass.

- **When it runs**:
  - after `LoadCharacterWithHumanoidDescriptionAsync` inside `Looks.dress`
  - after `buildNpc`
  - inside `Looks.redress`
- **Sources**:
  - `STYLE.recolor` keys that name an R15 part (e.g. `LeftUpperArm`)
  - MA
  - finale builders

---

## 3. Per-character specs (all 46)

Format of each row: kit in priority order · colour overrides · *signature* · **+N**, where +N is the parts added to the 16-part R15, counting FP (1). Colours not listed keep their `Characters.luau` values. "Prop" means the §2.6 slot, counted at its largest prop.

### Shinobi Lands (6)

| Style | Kit (priority order) | Colours | Signature | +N |
|---|---|---|---|---|
| naruto, **Ren Tsumuji** | FP, HR, HR·s×2 (swept back), HB + HB·t (cloth, no plate), SC (tail on the left), SB, EM buckle E1, GL×2 | hair `0x3a2a24`, spike tips `0x2f8f86`, top `0x2f8f86`, bottom `0xc9b48a`, band `0x2b3350`, scarf `0xf0a040`; no whiskers | *long scarf tail streaming left; one wind-streak mark on the right cheek* | 1+1+2+3+2+1+1+2 = **13** |
| sasuke, **Kurobane** | FP, HR, HR·s×3 (back), MT raven collar `0x151313`, 2 feather Wedges 0.1×0.6×0.25, BW sword across the upper back (2), SB | sash and bottom `0x3a3f4a` | *FaceGlow irises `0x9b6cff` only while a technique is active* | 1+1+3+1+2+2+1 = **11** |
| kakashi, **Hatsuyuki** | FP, HR, HR·w×2, LM, VS winter coat, SB, GL×2 | hair `0x1a1f2e`, swept wedges frost `0xdfe4ea`; coat `0xdfe4ea` over `0x2a3550`; no eye cover | *cyan E7 ring lights on the LM SurfaceGui while a copied technique is loaded* | 1+1+2+1+1+1+2 = **9** |
| itachi, **Karasu** | FP, HR (crop), HR·f (left), CP `0x2a2233`, MT crow mantle, 2 feather Wedges, crimson clip Wedge 0.08×0.25×0.12 | no collar, no ponytail, no clouds | *crimson clip in the forelock; black `ember` from the hands* | 1+1+1+1+1+2+1 = **8** |
| might_guy, **Midori Tetsu** | FP, HR, HR·k topknot, SB `0x3ad86a` + tail, GL×2 `0x8a3a2a`, WR×2 `0xe8e0d0` | gi `0x4a4f58` | *8 belt dots light green one by one as gates open* | 1+1+1+2+2+2 = **9** |
| pain, **Gravewell** | FP, HR, HR·w×2 (swept back), CP `0x1c1c26`, HC `0x5a5a70`, 4 basalt shards (CornerWedge 0.35×0.6×0.35, Basalt, violet `0x8a6cff` Neon-edge SurfaceGui) | hair `0xb8b8cc`; no piercings, no ringed eyes, no rods | *shards orbit a ring r=0.9 behind the shoulders (`Orbit_*`, axis Z, 0.15 rev/s), joined into a square by 4 Beams* | 1+1+2+1+1+4 = **10** |

### Sorcerer's Academy (24)

| Style | Kit (priority order) | Colours | Signature | +N |
|---|---|---|---|---|
| gojo, **Aoi Hakumei** | FP, HR, HR·w×2 (side-swept, no spikes), OR×3 (Neon `0x5ad4ff`), VS coat, LP, CT, GL left only | hair silver-lavender `0xc8c0e0`; coat `0x2a3550`; lapels `0xe8ecf4`; no VB, no eye cover, no high collar | *3 cyan shards orbiting the head; FaceGlow irises cyan while Infinity is up* | 1+1+2+3+1+2+2+1 = **13** |
| sukuna, **Akuro** | FP, HR, HR·s×2, XA (4), VS crossover robe `0x2a0a10`, SB `0x6a0c14` + tail | hair `0xe8d8d0`; one jagged ember crack `0x6a0c14` from the left temple to the jaw (3 Frames); nothing under the eyes | *second arm pair held forward, palms open* | 1+1+2+4+1+2 = **11** |
| yuji, **Haru Takane** | FP, HR, HD·d mustard `0xc8a03a` with a crimson stitched-patch SurfaceGui (E11 border on a `0x9b1a2a` 60×40 patch, left side), HC, GL×2 knuckle tape, Prop (≤2) | hair `0xc8a070`; uniform stays navy | *crimson stitched patch on the hood* | 1+1+1+1+2+2 = **8** |
| megumi, **Kage Inukai** | FP, HR, HR·s×3, MT wolf pelt `0x2a2e3a`, EP ears on the mantle (2), HC | uniform `0x191d44` | *`shadow` puddle at the feet* | 1+1+3+1+2+1 = **9** |
| toji, **Zero** | FP, HR, Prop (≤3), SB + 2 pouches, GL×2 fingerless | shirt `0x16161c`, trousers `0x2a2a30`; scar on the left brow | *back prop swaps with the Arsenal* | 1+1+3+3+2 = **10** |
| kashimo, **Ikazuchi** | FP, HR, HR·p long, SB `0xffd54a` + tail, BW staff Cyl Ø0.16×5 `CYL_UP*rz(35)` | hair `0xdfe8ff` | *`spark` at the staff tips* | 1+1+1+2+1 = **6** |
| geto, **Hoshiro Genma** | FP, HR, HR·p low tail, VS long open coat `0x2a2030`, LP, violet orb Neon Ball Ø0.5 over the left shoulder | lapel beads as SurfaceGui dots; no monk's sash, no bun, no gauged earrings | *floating violet orb* | 1+1+1+1+2+1 = **7** |
| kenjaku, **Nuime** | FP, HR, HR·k bun, HC `0x2a3018`, CT robe skirt | robe `0x3a4426`; E11 seam down the right side of face and neck | *cross-stitched right sleeve (SurfaceGui on RightUpperArm)* | 1+1+1+1+2 = **6** |
| choso, **Akagane** | FP, HR, HR·t×2, VS coat `0x2a1a20`, GL×2 bracers, 2 Neon vials Cyl Ø0.14×0.4 `CYL_UP` `0x9b1a2a` | crimson chevron on each cheek; no nose stripe | *glowing blood vials at the wrists* | 1+1+2+1+2+2 = **9** |
| mahito, **Patchwork** | FP, HR, HR·p strand, FS fist + thumb (2), 2 shoulder patch plates Block 0.9×0.25×1.0 (L `0xd8c0a8`, R `0xbacccf`) with E11 edges, chest seam strip Neon Block 0.08×1.4×0.05 `0xdcd3c9` | per limb: L arm `0xbacccf`, R arm `0xd8c0a8`, L leg `0xa8b8a0`, R leg `0x25345a`, hair `0xdcd3c9`; neck seam E11 | *quilted body with one giant fist* | 1+1+1+2+2+1 = **8** |
| jogo, **Kazan** | FP, CR rock crown (Basalt) + `smoke`, VS robe `0x6a2a1a` | skin `0x2a1a18` with lava-crack SurfaceGui `0xff6b3d`; ember FaceGlow; no volcano cone | *smoking rock crown* | 1+4+1 = **6** |
| hanami, **Thornbloom** | FP, HN branches, leaf Wedge 0.1×0.4×0.3, VS bark (Wood `0x5b4a3a`), SG×2 bark, CO bloom Ball Ø0.45 `0xff8ae0` on the left shoulder | no growths from the eyes | *pink bloom on one shoulder* | 1+2+1+1+2+1 = **8** |
| dagon, **Tidehollow** | FP, EP fin, MT coral shell `0x2a6a8a`, 2 waist tassels Cyl Ø0.12×0.9 `CYL_UP` | as data | *fin crest; `drip`* | 1+1+1+2 = **5** |
| nanami, **Overtime** | FP, HR, HC shirt collar `0xe8e4dc`, tie Block 0.25×0.9×0.05 (diagonal-stripe SurfaceGui `0x6a4a2a`), BW cloth-wrapped blade Block 0.14×2.0×0.35, wristwatch Cyl Ø0.3×0.08 `CYL_FWD` | suit `0x3a3a42`; no goggles, no beige suit, no patterned tie | *gold watch on the left wrist* | 1+1+1+1+1+1 = **6** |
| nobara, **Hammer Maiden** | FP, HR, HR·p×2 bob panels, SB + nail pouch, BW hammer (head Block 0.5×0.3×0.3 + handle Cyl Ø0.1×1.1) | hair `0x4a2a3a` | *3 belt nails, tips glow `0xd88a3a` when charged* | 1+1+2+2+2 = **8** |
| toge, **Kotodama** | FP, HR, HR·w streak `0x2fb7a8`, CK with speaker-grille SurfaceGui, VS | hair `0x2a2a34`; mouth uncovered; no face seal | *grille flashes on every command* | 1+1+1+1+1 = **5** |
| maki, **Rin Hoshigane** | FP, HR, HR·p ponytail, VB amber `0xd89a3a`, SG left, Prop (≤3), GL×2 | hair `0x5a2a24`; no glasses | *back prop swaps with the Arsenal* | 1+1+1+1+1+3+2 = **10** |
| naoya, **Framerate** | FP, HR, HR·p×2 (tips `0xd8c07a`), SC (E8 on the tail), SB `0x6a1a2a` | jacket `0x1a1a24` | *film-strip scarf* | 1+1+2+2+1 = **7** |
| yuta, **Rei Tsukiyo** | FP, HR, HR·s×2, BW katana (2), HC, wisp Neon Ball Ø0.5 `0x9fd6ff` behind the right shoulder + `wind` | coat `0x3a3e4a`, trim `0x9fd6ff`; no white uniform | *wisp companion* | 1+1+2+2+1+1 = **8** |
| ishigori, **Gankyu** | FP, HR, flat-top Block 1.1×0.3×1.1, VS sleeveless `0x2a2a30`, shoulder cannon Cyl Ø0.7×1.6 + Neon muzzle, GL×2 | hair `0xf0e08a`; no pompadour | *right-shoulder cannon* | 1+1+1+1+2+2 = **8** |
| uro, **Skyfold** | FP, HR, HR·p, MT shawl `0x8fa8c8`, Neon edge strip Block 2.3×0.06×0.06 `0x9fd6ff`, SB | robe `0xdcd8ce` | *folded-cloud shawl* | 1+1+1+1+1+1 = **6** |
| todo, **Tetsuo Hakushu** | FP, HR (shaved-side: cap scaled to X 1.1), HR·w crest (single, centred, swept back), EC right ear, VS open jacket `0x1b1b24`, GL×2 palm tape | sleeves skin; no topknot, no scar | *palm tape flashes `0xd4142a` on a swap; gold ear cuff* | 1+1+1+1+1+2 = **7** |
| hakari, **Jackpot** | FP, HR, HR·w×2 undercut, HC `0xffd54a`, CP short (1.9×1.4) `0x14141c`, EM reel window (3 SurfaceGui digits) | coat `0x1a1a24` | *chest reels roll during the domain* | 1+1+2+1+1+1 = **7** |
| yuki, **Supernova** | FP, HR, HR·p long, VS biker jacket `0x2a2436`, SC `0xff8a2a`, EM E10 on the back, GL×2 | as data | *star-flare on the jacket back* | 1+1+1+1+2+1+2 = **9** |

### Skyline City (14)

Masked figures keep FP for marks and mouth hiding. Their eyes are hidden, and lenses or slits act as the eyes.

| Style | Kit (priority order) | Colours | Signature | +N |
|---|---|---|---|---|
| spiderman, **Threadrunner** | FP (eyes hidden), HD (up), LM, GG round goggles (Neon teal `0x2fb7a8`), EM E2, GL×2 wrist spools Cyl Ø0.3×0.5 `CYL_UP`; TN×2 while `Suit > 0` | suit `0x2a2f3a`, hood and LM `0x3a4250`, teal panels on the torso front and forearms (SurfaceGui); no white anywhere on the head; no red; no amber; no spider or web marks | *hooded parkour runner with teal goggles and wrist spools* | 1+3+1+2+1+2 = **12** (14 with the suit) |
| insomniac, **Nightshift** | FP, FM (one amber slit `0xffb347`), 4 amber Neon seams (Block 0.06×1.0×0.06 on each LowerArm and LowerLeg), EM E2 amber | suit `0x14161e` | *single amber slit plus amber seams, the 60-stud discriminator from Threadrunner* | 1+2+4+1 = **8** |
| miles, **Voltstep** | FP, FM (one yellow slit `0xffe45c`), HD (up), WR×2 sneakers `0xffe45c` | suit `0x2a1f3a`; zigzag SurfaceGui seams on the arms; no red, no white lenses | *hood plus electric sneakers* | 1+2+3+2 = **8** |
| ironspider, **Ironthread** | FP, FM (amber lenses `0xffb347`), BA×4 copper (8), SG×2 | armour `0x4a4f58`, copper `0xc87a3a` | *four copper back legs* | 1+3+8+2 = **14** |
| venom, **Blackmaw** | FP, FM (one pale-violet slit `0xe8e0ff`), SG×2 bulky, TN×2 | ink `0x0a0a10`, Reflectance 0.15; chest maw (§2.4); no teardrop eyes | *maw across the chest* | 1+2+2+2 = **7** |
| carnage, **Redmaw** | FP, FM (amber slit `0xffb347`), FB×2 bone spurs `0xe8e0e2`, TN×3 | magenta-maroon `0x8a1a5a` (hue ≈326°); vein SurfaceGui `0x3a0a2a`; chest maw with jagged bone-coloured fangs (§2.4) | *bone spurs plus three tendrils* | 1+2+2+3 = **8** |
| antivenom, **Antidote** | FP, FM (teal slit), EM E5 droplet, SG×2 | pearl `0xe8eef4`, teal veins `0x2fb7a8` | *droplet emblem* | 1+2+1+2 = **6** |
| docock, **Doctor Eightfold** | FP, HR, BA×4, each arm 3 parts: segment 1 Cyl Ø0.22×1.4 `0xa8b2be`, segment 2 Cyl Ø0.2×0.9 `0xa8b2be`, Neon claw tip Wedge 0.2×0.5×0.25 `0x5a8f3a` | sweater `0x5a4a6a`; no glasses, no monocle, no trench coat | *four arms with glowing green claw tips* | 1+1+12 = **14** |
| winter, **Frost Arm** | FP, HR crop, GG pushed up (2), MA right + frost seam `0x9fe0ff`, VS `0x22252c`, SB + pouch | no lower mask, no long hair, no star | *frosted right arm* | 1+1+2+1+1+2 = **8** |
| ironman, **Arc Knight** | FP, FM helmet (one cyan slit), CO diamond `0x5ad4ff`, SG×2 ivory, GL×2 palm-Neon gauntlets, Prop (≤2, warmachine) | per the §2.6 suit; no red and gold, no round reactor | *diamond chest core* | 1+2+1+2+2+2 = **10** |
| jean, **Mindflare** | FP, HR, HR·p, VS `0x3a2458` with trim `0xe0c8ff`, 3 Neon crystal Wedges `0xff8ae0` (`Orbit_*` about Head, axis Y, r 0.9, y 0.6, 0.2 rev/s) | no green and gold, no firebird | *psionic shard halo* | 1+1+1+1+3 = **7** |
| strange, **Warden of Mirrors** | FP, HD (up) `0x2a2458`, MT hooded mantle `0x2a2458`, SB, EM mirror-shard pendant (Glass diamond, Reflectance 0.5) | robe `0x1f3a3a`; no silver temples, no high collar, no cape | *mirror pendant* | 1+3+1+1+1 = **7** |
| goblin, **Cackler** | FP, FM bone `0xe8e0c8` + 2 round lenses Glass `0xffb347`, BK beak, WG glider disc `0x4a4f58` (2 Neon SurfaceGui dots), GL×2 | suit rust `0xc8642a` / charcoal `0x2a2a30`; no green or chartreuse, no grin, no long ears, no hood | *beaked plague-mask on a glider* | 1+3+1+1+2 = **8** |
| wolverine, **Clawback** | FP, HR short crop (no side flares), HD·d parka hood, VS olive field parka `0x4a5a3a`, GL×2 bracers, FB×2 long curved (one per arm) | shirt `0x3a4a3a`; no stubble, no leather jacket, no yellow suit, no cowl | *single long curved bracer blade per arm* | 1+1+1+1+2+2 = **8** |

### Elsewhere (2)

| Style | Kit (priority order) | Colours | Signature | +N |
|---|---|---|---|---|
| eleven, **Nosebleed** | FP, HR, HR·p shoulder length, headphones (GG 2 + band Block 1.3×0.1×0.15 over the top of the head), VS windbreaker `0x2f8f86` with a `0xf0e0d0` stripe | no buzzcut | *nosebleed mark only during the ultimate* | 1+1+1+3+1 = **7** |
| tophat, **Top Hat** | FP, hat (brim Cyl Ø1.55×0.08 `CYL_UP` + crown Cyl Ø0.95×1.0 `CYL_UP` + band Cyl Ø0.97×0.15 `0x9b1a2a`), HC white, CT tailcoat, Prop (≤3), GL×2 white | as data | *top hat with a crimson band* | 1+3+1+2+3+2 = **12** |

---

## 4. Enemies

### 4.1 Palette capture and darkening

`Costumes.palette(template, affix, enemyEntry)` returns `{base, nature, affix}`.

- `base = enemyEntry.variant.color or template.color or NATURE[template.nature].color`. It is computed **before** `applyAffix`.
- **Normal-foe darkening**: `lerp(c, 0x2a2a30, 0.2)` applies to:
  - `pal.base`
  - EnemyLooks `top`, `sleeves` and `bottom`
  - every faction and grade-ladder piece colour

  It does not apply to weak points, eyes or markers.
- `affix.color` is used only for the ring, the motif, the FaceGlow tint and the Highlight.
- The server sets the model attribute `NatureColor = pal.nature` for the client death effect (§6.2).

### 4.2 Creature families (`CREATURES[shape](kit, t, pal)`)

**Common rules**
- The hidden walker keeps pathing and the default animations. All R15 parts get `Transparency=1`, except for golems and imps.
- **B** = body width in studs = `SHAPES[shape].size.X × STUDS(2.4) × 0.55 × t.size`. Piece sizes below are multiples of B.
- Pieces weld to LowerTorso unless stated otherwise, so the float bob and hop move them.
- **Gait legs** are `Gait_*` welds (§2.1):
  - pivot at the leg's top
  - `GaitAmp` 22°, `S = B`
- Each shape table below lists pieces in priority order.

**Toad** (hidden: all; weak point: warts) **+14**

| Piece | Parts |
|---|---|
| Body Ell 1.0×0.75×1.0·B, bottom at ground + 0.3 | 1 |
| 2 eye domes, Ball Ø0.34B, on top | 2 |
| 2 Neon slit pupils, Block 0.04×0.2×0.02·B, on FaceGlow colour | 2 |
| Mouth Block 0.9B×0.08×0.1 | 1 |
| 2 haunches Ell 0.45×0.4×0.55·B at (±0.45B, −0.1B, +0.3B), static | 2 |
| 2 hind pads Block 0.35×0.08×0.5·B: welds `Gait_HL/HR`, pivot (±0.4B, 0, +0.3B), phase 0.5 | 2 |
| 2 front paws Block 0.3×0.3×0.35·B at z −0.4B, bottom at ground: welds `Gait_FL/FR`, pivot (±0.35B, −0.1B, −0.35B), phase 0 | 2 |
| Neon wart cluster Ball Ø0.4 | 1 |
| Extra wart Ball Ø0.3 | 1 |

- **Hop**: while moving, the client adds a 0.25-stud sine hop to `LowerTorso.Root.C0` at the stride frequency.

**Blob** (hidden: all; weak point: core seen through the jelly) **+11**

| Piece | Parts |
|---|---|
| Outer jelly Ell (SHAPES size × scale), SmoothPlastic, Transparency 0.35 | 1 |
| Neon core Ball Ø0.55B | 1 |
| Eye: white Ball Ø0.4B + iris Ball Ø0.22B + pupil Ball Ø0.1B | 3 |
| Mouth Block 0.5B×0.06×0.05 | 1 |
| 2 tendrils Cyl Ø0.12B×0.6B on UpperTorso: welds `Gait_TL/TR`, GaitAmp 15° | 2 |
| 3 drips Ball Ø0.15B | 3 |

**Wraith** (hidden: all; weak point: eyes) **+12**

| Piece | Parts |
|---|---|
| Hood Ell 1.0×1.2×1.0·B | 1 |
| Hood peak Wedge 0.3×0.5×0.4·B | 1 |
| Recessed black face-void Ell 0.6×0.7×0.3·B | 1 |
| 2 Neon slit eyes | 2 |
| 2 tail Ell 0.7×1.0×0.7·B and 0.45×0.8×0.45·B, trailing −Y+Z | 2 |
| 2 claw Wedges 0.1×0.5×0.3·B on UpperTorso (±0.6B, −0.3B, −0.3B), static | 2 |
| 3 hem Wedges 0.3×0.5×0.1·B | 3 |

- `wind` emitter on the tail tip.

**Golem** (shown: all R15, `heavy`, Slate via paintParts; weak point: chest crack) **+11**

| Piece | Parts |
|---|---|
| 2 chest Wedges 1.0×1.5×0.6 with a 0.15 gap | 2 |
| Neon core Block 0.12×1.0×0.1 in the gap | 1 |
| Eye band Neon Block 0.9×0.12×0.05 | 1 |
| Brow Wedge 1.2×0.3×0.4 | 1 |
| 2 shoulder boulders Ball Ø1.3 | 2 |
| 2 gauntlets Block 1.4× LowerArm | 2 |
| 2 back shards Wedge 0.3×1.0×0.4 | 2 |

**Imp** (shown: all R15, `small`; weak point: grin) **+11**

| Piece | Parts |
|---|---|
| FP with a glowing grin on FaceGlow | 1 |
| 2 horns HN | 2 |
| 2 Neon eye Balls Ø0.2 | 2 |
| Belly Ell 1.3×1.0×1.1 on UpperTorso | 1 |
| Tail: 2 Cyl Ø0.12×0.8 + spade Wedge 0.1×0.35×0.35 on `WaistBack` | 3 |
| 2 wing Wedges 0.1×1.2×0.9 | 2 |

**UFO** (hidden: all; weak point: ring) **+8**

All sizes are × `t.size` (1.6).

| Piece | Parts |
|---|---|
| Saucer Cyl Ø4.2×0.6 `CYL_UP`, 1.5 above the hidden root | 1 |
| Dome Ball Ø1.8 Glass | 1 |
| Underside Neon ring Cyl Ø2.4×0.2 `CYL_UP` | 1 |
| 4 rim Neon Balls Ø0.3 | 4 |
| SD | 1 |

- 1 SpotLight pointing down: range 16, brightness 1.

**Floaters** (`float=true`): grade4, larva, wind_spirit, storm_wraith, bat_curse, smoke_curse, sand_spirit, mist_leech, crow_swarm, mirror_fiend, goblin_drone.
- They get SD (+1 part). On an elite, SD becomes the affix ring (Neon, `affix.color`, Transparency 0.35), so floaters never pay for both.
- **Bob**: the client tweens `LowerTorso.Root.C0` by ±0.3 studs over a 1.6 s sine. SD sits on the HRP, so it stays on the ground.

### 4.3 Per-enemy variants

Colours come from `pal.base`. Part counts are recounted and covered by test 2.

| Enemy | Shape | Variant | Parts |
|---|---|---|---|
| cursed_toad | toad | mottled `0x3f7a6a`, warts `0x5aa9ff`; the extra wart becomes a pink tongue Wedge | 14 |
| grade4 | blob | muddy `0xc9a068`, no tendrils (−2), float + SD (+1) | 10 |
| larva | blob | grub: 3 Balls Ø0.6/0.5/0.4 B replace the jelly and core; 2 mandible Wedges; eye (3); SD | 3+2+3+1 = 9 |
| cursed_womb | blob | `0x8a2a4a`; curled core (2 Balls) replaces the core; client pulses core Transparency | 12 |
| mist_leech | blob | funnel mouth Cyl `CYL_FWD` replaces the mouth; `smoke`; SD | 12 |
| slot_curse | blob | gold jelly; 3-reel face SurfaceGui on an FP replaces the eye (−3 +1); `coin` | 9 |
| wind_spirit | wraith | `0x8fe3c9`, `wind`, SD | 13 |
| storm_wraith | wraith | 2 yellow Neon crackle Blocks replace 2 hem pieces; `spark`; SD | 13 |
| bat_curse | wraith | 2 membrane wings + 2 ear Wedges replace the 3 hem pieces; SD | 14 |
| smoke_curse | wraith | Transparency 0.3, `smoke`; eyes become 1 lantern Ball (−1); SD | 12 |
| sand_spirit | wraith | Sand; bone face plate Block with eye-hole SurfaceGui replaces the void; SD | 13 |
| crow_swarm | wraith | 3 crows (Ball + beak Wedge each, 6) replace the body; `feather`; SD | 7 |
| mirror_fiend | wraith | Reflectance 0.5; 3 shard Wedges replace the hem; SD | 13 |
| ember_imp | imp | CrackedLava skin; `ember` on the spade | 11 |
| needle_curse | imp | 4 back needles Cyl Ø0.08×1.2 replace the wings | 13 |
| rush_curse | imp | ram horns (CornerWedges, forward); lean `RootJoint.C0 * rx(12)` | 11 |
| spine_curse | imp | bone `0xd8ccb8`; 4-block vertebra row replaces the wings | 13 |
| goblin_drone | imp | `variant.color = 0xc8642a` rust with charcoal `0x2a2a30` and amber `0xffb347` eyes (not data green); BK beak (+1, grin hidden, FP kept); hover disc Cyl Ø1.4×0.1 under the feet (+1) replaces the wings (−2); SD (+1) | 11+1−2+1+1 = **12** |
| stone_brute | golem | Slate; 2 moss Wedges `0x4f6b3a` replace the shards | 11 |
| finger_bearer | golem | fleshy `0x8a5a6a` SmoothPlastic; 5 back finger Cylinders replace the shards | 14 |
| iron_curse | golem | DiamondPlate `0x6a7280`; rivet SurfaceGui | 11 |
| tomb_guardian | golem | Sandstone; gold face plate `0xc8a44a` with E7 replaces the brow | 11 |
| mass_curse | golem | `0xff8a2a`; anvil head Block replaces the brow; waist weight replaces 1 shard | 11 |
| ufo | ufo | §4.2 | 8 |

### 4.4 Human enemies

**Id resolution**
- `Costumes.baseId(id) = id:gsub("_alpha$", "")`. Look, faction and grade come from the base id.
- `akatsuki_nin(_alpha)` and `gate_monk(_alpha)` get their looks from `Costumes.ENEMY`.

**Grade ladder**
- Uses the base template's grade. Alphas are grade `special` in data, but they use their base's ladder plus the crest.
- Counts include FP.

| Grade | Adds (priority order) | Costume | Total |
|---|---|---|---|
| 4 | FP, HR cap + 1 spike or panel | 3 | 19 |
| 3 | + faction piece (HB, HC or VS) | 4 | 20 |
| 2 | + SG on one side, + LM or SC wrap | 6 | 22 |
| 1 | + CT (2), + GL×2 | 10 | 26 |
| semi1 | + BW short (1 Block), + Neon trim strip in the nature colour | 12 | 28 |
| special | + crest (CR, single CornerWedge) + `aura` at Rate 6 | 13 | 29 |

- Markers mount first (at most 3 for humans: ring + motif, or ring + 2 stitched strips).
- The budget of 14 trims from the end of the list.

**Factions**

- **Ninja** (rogue_ninja, clone_ninja, blade_ninja, thunder_ninja, akatsuki_nin)
  - Base look: plain cloth HB (no mark), GL wraps, LM at grade 2+, flak VS at grade 1+, BW short. They read by HB + LM + faction colour.
  - **clone_ninja**: all `0x24242c`, Transparency 0.15, `smoke`.
  - **akatsuki_nin "Ember Veil"**:
    - CP `0x15151d` with an ember-orange hem stripe (SurfaceGui).
    - HD (up) and LM.
    - No clouds, no red collar.
- **Sorcerer** (kyoto_student, flame_dancer, blood_curse, gate_monk)
  - Base look: HC with uniform-button SurfaceGui, CT at grade 1+, 2 talisman strips (Block 0.15×0.6×0.03 `0xe8e0c8`) at grade 2+.
  - **gate_monk**: saffron `0xd88a3a` VS robe, SB olive `0x4f6b3a`, no hair, GL wraps.
  - **flame_dancer**: bare torso, SB, `ember` on the hands.
  - **blood_curse**: crimson drip SurfaceGui.
- **Street / colony** (on the `times_square` or `culling_colony` maps, via `Enemies.mapId`)
  - Headgear becomes a beanie (HR cap + 0.1 cuff Block) or a bandana LM.
  - VS becomes VS + LP (open jacket).
  - BW becomes a pipe Cyl Ø0.12×1.6.
- **grey**
  - `small` preset, WidthScale 0.7.
  - Eyes: 2 black Ell 0.36×0.2×0.1 `rz(±18)`.
  - No hair, no FP.

**Variety**: `Random.new(spawnCounter)` picks:
- one of 3 hair variants per faction
- a skin tone from `0xf3d6b8, 0xe0b088, 0xc89a70, 0x8a6244, 0x5a3a28`
- whether the last piece in the list is worn

### 4.5 Markers by role

**Affix ring**
- Neon Cyl Ø(1.4 × footprint) × 0.12, `CYL_UP`, Transparency 0.35, colour `affix.color`.
- Welded to the HRP at `(0, −HipHeight − HRP.Size.Y/2 + 0.03, 0)`.
- Footprint as in §2.1.

**Alpha**
- Crest (1 part).
- FaceGlow gold, eyes ×1.3.
- Body 15% darker.
- `dust` emitter.
- Nothing else (§1.5).

**Elite motif** (1 piece each, except Giant)

| Affix | Colour | Motif |
|---|---|---|
| Frenzied | `0xff4d5e` | red spike Wedge 0.2×0.6×0.4 crest + red `spark` |
| Armored | `0xb8c2d0` | shell = 1.08× the host size (UpperTorso for humans, main body piece for creatures; same primitive, so ellipsoid for an ellipsoid), DiamondPlate, Transparency 0 |
| Giant | `0xffb340` | ring 1.6× instead of a motif |
| Vampiric | `0xc0294a` | dark red `drip` |
| Volatile | `0xff8a3d` | weak point Transparency 0↔0.5 at 3 Hz on the client (8 Hz during the 1 s fuse) |

**Stitched**
- Applies when role is `elite` **and** `Enemies.stitched`, or when the spawn is summoned by a stitched parent (`Enemies.think` passes `opts.stitchedParent`).
- Bosses, character bosses, alphas and finale ids are never stitched.
- Look:
  - 2 Neon Blocks 0.08 × (0.9 × bodyY) × 0.05, `0xff2d55`, at `rz(±30)`, on the front of the main body piece (UpperTorso for humans).
  - They replace the motif.
  - The ring turns `0xff2d55`.
- `Enemies.stitched` is set in `Waves.start` as `Worlds.get(mapId).stitched == true`, so it resets on every other world.

**Ally / Worn**: `Kit.ally(model)`, called in `Abilities` `handlers.possess` right after `Combat.take(e)`:
- switches the face to the friend face (§2.4, including the SurfaceGui property flip)
- turns the ring or SD cyan `0x5ad4ff`, adding a ring if there is none
- destroys the stitched strips
- destroys the Highlight and calls `Enemies.releaseHighlight(model)`

**Character bosses** (`boss_<style>`, `hanami`, `jogo`, `mahito_b`, `dagon_b`, `kenjaku_b`, `toji_b`)
- Costume: `Costumes.STYLE[Costumes.styleFromEnemyId(id)]`, where `styleFromEnemyId` strips `boss_` and `_b`.
- Colours lerped 22% toward `0x14040a`.
- FaceGlow in the signature colour.
- **Rift halo**: 3 Attachments on a 1.4-stud ring behind the Head, joined by 3 Beams (Width 0.18, LightEmission 1, `FaceCamera=true`).
- `aura` emitter, 1 PointLight, Highlight.
- Largest style +N is 14, so every character boss fits in 30.

### 4.6 Friendly ultimate: Kage Inukai's ward (`ult.kind == "mahoraga"`)

**Build**
- `Looks.buildAlly("the_unbidden", 1.3)` builds the Unbidden model (§5.3), with:
  - all 8 collar tiles lit cyan `0x5ad4ff`
  - the friend face (cyan slit, on FaceBase)
  - no Highlight
  - `CanQuery=false` on every part
  - **a cyan ally ring** (+1)
- **Total: 30 parts.**
- It spawns 4 studs behind the caster. The server calls `root:SetNetworkOwner(nil)`.

**Storage**: `minion.model` on the `ps.minions` entry.

**Movement and attack** (Combat minion loop, Combat.luau:669)
- `hum:MoveTo(owner)` every 0.5 s.
- On each strike, it faces the target.
- The strike Beam's `from` becomes `minion.model.PrimaryPart.Position` (it was the caster's root).

**Cleanup**: `minion.model:Destroy()` in each of these cases:
- the entry expires (`table.remove` branch)
- `Players.PlayerRemoving`
- the owner's `Humanoid.Died`
- `Looks.dressPlayer` / transform
- `Waves.start`

Limit: one ward per caster.

---

## 5. Finale bosses

**Dispatch**: when `Finale.ENEMIES[id]` exists, the role is `finale`, and `Enemies.spawn` calls `BUILDERS[Costumes.ENEMY[id].builder](kit, t, pal)`. It skips `CREATURES` and the human ladder.

### 5.1 Hyakunui, the Hundred-Seam (size 1.8, human, `towering`)

Stitched down the midline: the left half is Nuime, the right half is Patchwork.

| Piece | Parts |
|---|---|
| FP: face seam line on FaceBase; left iris `0x8aa84a`, right iris `0x6cd8c0` on FaceGlow | 1 |
| HR cap | 1 |
| HR·k bun, left only, (−0.3, 0.6, +0.4) | 1 |
| HR·p strand panel, right only | 1 |
| CT robe panel, left only | 1 |
| Seam strips, Neon `0xff2d55`, 0.12 × torso height × 0.05, on BodyFront and BodyBack, each with an E11 SurfaceGui | 2 |
| Needle Wedges 0.1×0.6×0.1 at 3 thread ends | 3 |
| Chest patches 0.8×0.8×0.06 `0x3a0a14` with stitched-edge SurfaceGui | 2 |
| FS fist + thumb on the right hand (the 4th thread ends in the fist) | 2 |
| **Costume total** | **14 → 30** |

**Halves**
- `Kit.paintParts`: LeftUpperArm and LeftLowerArm in robe `0x3a4426`; LeftHand stays skin.
- The description sets the whole-limb colours: RightArm `0xbacccf`, RightLeg `0x25345a`.

**Threads**
- 4 Beams (0 parts): Width 0.08, LightEmission 1, colour `0xff2d55`.
- They start at UpperTorso Attachments at `BodyBack` (±0.3, 0.6, +0.1) and fan out to far Attachments 5 studs up and out, like a loom.
- 3 far Attachments carry the needles, welded to UpperTorso at the same C0.
- The 4th Beam ends at an Attachment in the fist.

**Phases**: `FinaleFight.step` calls `Looks.finalePhase(e.model, phase)` next to `announce(1)` (FinaleFight.luau:129) and next to `announce(phase)` (FinaleFight.luau:134). It is not called inside `announce`.
1. `thread` emitter at Rate 4.
2. The patches "tear":
   - they turn Neon (left `0xff8a3d`, right `0xd9d4cc`) and each fires a 12-particle `burst`
   - the needle welds' C0 and far Attachments are tweened out to 7 studs
   - Beam Width goes 0.08 → 0.14
3. "Coming apart":
   - seam, Beams and needles lerp 30% toward white
   - Highlight FillTransparency goes 0.9 → 0.6
   - HR·p and HR·k are destroyed
   - `thread` goes to Rate 12

**Lights**: PointLight `0xff2d55`, range 18. Highlight outline `0xff2d55`. **Total 30.**

### 5.2 The Tempest Fox (size 2.1, finale builder, wind)

An original storm fox with 3 tails.

**Walker and scale**
- The hidden walker uses **HeightScale 0.7**, so its hitbox top is about 7.7 studs, matching the ear tips.
- All R15 parts are hidden.
- `S = 2.4 × 0.55 × t.size ≈ 2.77`.
- Every piece welds to the **HumanoidRootPart**, which is not animated. Ground = y_g.

| Piece | Placement | Parts |
|---|---|---|
| Torso Ell 1.0×0.9×2.2·S, slate `0x3a4250`; belly glow SurfaceGui on its Bottom face, `0xff8a3d`, `LightInfluence 0` | centre at y_g + 1.25S | 1 |
| Chest ruff Ell 0.9×0.9×0.7·S, `0xe8e4dc` | (0, y_g+1.35S, −0.9S) | 1 |
| Skull Ell 0.8×0.7×0.8·S | (0, y_g+1.7S, −1.3S) | 1 |
| Snout Wedge 0.4×0.35×0.6·S | skull front | 1 |
| Ears: 2 Wedges 0.12×0.7×0.4·S, inner-face SurfaceGui ember | skull top | 2 |
| Face plate: bone Block 0.7×0.45×0.05·S with a forked-lightning SurfaceGui on FaceBase and 2 ember slit eyes on FaceGlow | skull front | 1 |
| Hind legs: 2 Wedges 0.45×1.3×0.6·S, welds `Gait_HL/HR` | pivot (±0.35S, y_g+0.1+1.3S, +0.8S) | 2 |
| Front legs: 2 Wedges 0.4×1.3×0.5·S, welds `Gait_FL/FR` | pivot (±0.35S, y_g+0.1+1.3S, −0.8S) | 2 |
| Tails: 3 Ell 0.35×0.35×2.4·S fanning up and back (`rx(-35)`, `rz(-20/0/20)`); ember tip Beam between Attachments at 70% and 100% of the length (Width 0.35→0.05, LightEmission 1) + `wind` | (0, y_g+1.4S, +1.1S) | 3 |
| **Costume total** | | **14 → 30** |

**Gait**
- Diagonal pairs in phase: FL with HR at phase 0, FR with HL at phase 0.5.
- Amplitude ±22°, `f = rootSpeed/(1.6·S)`.
- Each paw moves about ±0.49S fore and aft and lifts about 0.1S. It no longer clips through the body.
- `wind` emitters at the paws: Rate 6, Lifetime 0.6.

**Charge tell**
- In `Enemies.think`, `action == "tell"` (Enemies.luau:385) sets `model:SetAttribute("Tell", true)`.
- These clear it back to false:
  - `action == "endLunge"` (Enemies.luau:423)
  - `action == "cancel"`, inside the `hold or cancel` branch at Enemies.luau:426, only when `action == "cancel"`
  - death
- `windup` is the melee swing and is not used for this.
- Client response to Tell: tail Beams at Width ×2, emitter Rate 12, and a scorch trail of client-side decal parts.

**Lights**: none. Highlight outline `0xff8a3d`. **Total 30.**

### 5.3 The Unbidden (size 1.9, finale builder, adapts)

A featureless bone giant that grows armour against whatever hurts it. It has no wheel or halo.

**Body**
- Visible walker, `towering`, WidthScale 1.2, DepthScale 0.9.
- Bone `0xd9d4cc` SmoothPlastic.
- `Kit.paintParts` makes the Hands and LowerArms Slate `0xa8a39a`.

| Piece | Parts |
|---|---|
| FP: one vertical dark slit on FaceBase, no mouth | 1 |
| Chest plates Block 0.9×0.8×0.1, with a trim SurfaceGui (UIStroke 4 px) | 2 |
| Shoulder domes Ell 1.2×0.7×1.2 | 2 |
| **Collar tiles**: 8 Blocks 0.42×0.3×0.14 on UpperTorso `NeckAttachment`, radius 0.78, y −0.05, at 45° steps in `ADAPT_ORDER` (tile i at angle `(i−1)·45°` from front, C0 = `CFrame.Angles(0, θ, 0) * CFrame.new(0, −0.05, −0.78)`, so each faces outward), starting dull `0x8a8680` | 8 |
| **Costume total** | **13 → 29** |

- Arc length is 4.9 studs against 3.36 of tiles, which leaves 0.19-stud gaps. At least 3 tiles are visible from any angle.

**Adaptation**
- `Costumes.ADAPT_ORDER = {"physical","cursed","fire","wind","lightning","earth","water","sound"}`. Test 7 checks it against `NATURE`.
- At Combat.luau:416, inside `if adapted and counts[nature] == 4`, add `e.model:SetAttribute("Adapted_" .. nature, true)`.
- `Enemies` connects `AttributeChanged` once at spawn. When it fires:
  - that nature's tile turns Neon in `NATURE[nature].color`
  - the chest-plate trim takes the same colour as a frontal echo

**Lights**: none. Highlight outline `0xd9d4cc`. **Total 29.**

---

## 6. Implementation

### 6.1 New files

**`src/shared/Costumes.luau`** (pure data plus pure functions; testable with Lune)

| Field / function | Contents |
|---|---|
| `STYLE[styleId]` | `{ preset, recolor = {top, sleeves, leftArm, …, [R15PartName]={…}}, kit = { {"FP"}, {"HR"}, {"HR·s", n=2, tint=…}, … }, face = {marks, glow}, sig, props, suitTN? }` |
| `ENEMY[baseId]` | `{ shape?, faction?, variant = {color?, …}, builder? }` |
| `PARTS[code]` | part counts per piece code |
| `ARSENAL_PROP[styleId][key]` | the §2.6 props |
| `ADAPT_ORDER` | §5.3 |
| `BANNED` | §2.7 |
| `EYE_ZONE` | x ±0.45, y 0.06–0.24 |
| `baseId(id)` | strips `_alpha` |
| `styleFromEnemyId(id)` | strips `boss_` and `_b` |
| `role(id, t, affix)` | §1.5 |
| `palette(template, affix, entry)` | §4.1 |
| `darken(c)` | the 20% lerp toward `0x2a2a30` |

**`src/server/Kit.luau`**
- `Kit.new(model, budget)` returns a builder that counts parts.
- `b:mount(host, attach, kind, size, offset, props)`:
  - `kind` is one of `block | wedge | corner | cyl | ball | ell`.
  - Scales size and offset by `host.Size / NOMINAL[host.Name]`.
  - Creates the part (for `ell`, a Block with a Sphere SpecialMesh).
  - Creates the Weld (`C0 = attach.CFrame * offset`).
  - Sets the no-collide and no-query properties.
  - Returns nil once the budget is spent.
  - Tags the piece `CostumeDetail` when its largest side is under 0.6 and its role is not eye, weak point or marker.
- `b:gait(name, pivot, phase, amp)` and `b:orbit(axis, rate, phase)` set the Weld name and attributes, and tag the model.
- Also: `Kit.ellipsoid`, `Kit.face`, `Kit.emblem`, `Kit.ringOver`, `Kit.paintParts`, one builder per code, `Kit.alpha`, `Kit.affix`, `Kit.stitch`, `Kit.ally`, `Kit.riftBoss`, `Kit.prop`.
- `CREATURES.toad|blob|wraith|golem|imp|ufo` and `BUILDERS.hyakunui|tempest_fox|the_unbidden`.

### 6.2 Changes to existing code

**`Looks.description(look, styleId)`**
1. Merge whole-limb `recolor` into `look`.
2. Apply the preset.
3. Read `look.headScale` for the first time, clamped to 0.8–1.1.
4. Drop banned flags.

`ACCESSORIES` stays as an optional path, with the comment `-- optional Creator Store asset here: ACCESSORIES[styleId].hair = "<id>"`.

**`Looks.dressHair`**
- Hair goes at +Z.
- Cap at the base cap plus either 3 extras, 1 panel or 1 knot.
- Skipped when FM or HD is worn.
- Mounted through Kit with a Weld C0, as an ellipsoid.
- Cap raised when HB is worn.

**New `Looks.dress(model, look, opts)`**, where `opts = {styleId?, enemyId?, role, grade?, faction?, pal?, budget}`:
1. Destroys `Head.face`.
2. Mounts FP, FaceBase and FaceGlow.
3. Mounts markers, then the kit.
4. Runs `Kit.paintParts`.

For players:
- `dressPlayer` calls it after `LoadCharacterWithHumanoidDescriptionAsync`.
- It connects the `Weapon` and `Suit` listeners and disconnects them on `character.Destroying`.
- It destroys any ward (§4.6).
- `Looks.redress(character)` handles suit swaps and Suit changes.

**`Looks.buildNpc(look, size, opts)`**
1. Preset first.
2. `d.HeadScale *= size`.
3. `Looks.dress`.

**New `Looks.buildAlly(id, size)` and `Looks.finalePhase(model, phase)`.**

**`Enemies.spawn`**
1. Before `Rules.applyAffix`: `local pal = Costumes.palette(template, affix, Costumes.ENEMY[Costumes.baseId(id)])`. The fallback look uses `pal.base`, never `t.color`.
2. `local role = Costumes.role(id, t, affix)`.
3. Dispatch:
   - `finale` → `BUILDERS`
   - else if `t.shape ~= "human"` → `CREATURES[t.shape]` (ufo included; this replaces `creatureBody`)
   - else the human ladder, using the base id's grade and faction, plus the street variant from `Enemies.mapId`
4. Markers by role:
   - `alpha` → `Kit.alpha`
   - `charBoss` → `Kit.riftBoss`
   - `elite` → `Kit.affix`, and `Kit.stitch` when stitched (§4.5)
5. Highlights through `Enemies.claimHighlight(model, prio)`. Release on death and in `Combat.take`.
6. `model:SetAttribute("NatureColor", pal.nature)`.
7. The burst colour uses `pal.base`.

**`Enemies.think`**
- Tell set on `tell`; cleared on `endLunge`, `cancel` and death (§5.2).
- Summons pass `opts.stitchedParent`.

**`Waves.start`**: sets `Enemies.stitched`, `Enemies.mapId`, and destroys all ward models.

**`Combat.luau:416`**: `Adapted_` attribute. **Combat.luau:669**: the ward strike origin, and destroying the model when its entry expires.

**`FinaleFight.step`**: `Looks.finalePhase` at lines ~129 and ~134.

**`Abilities`**: `Kit.ally` after `Combat.take` in `handlers.possess`; the `mahoraga` branch spawns the ward.

**Client `Fx`** (0 server cost)
- `Gait` driver.
- `Orbit` driver.
- Float bob and toad hop.
- Volatile and cursed_womb pulses.
- Tempest Fox tell.
- **Death read**: on `Humanoid.Died`, every Costume piece becomes Neon in `NatureColor` for 0.1 s, then tweens Transparency to 1 over 0.4 s while `burst` fires.
- **Distance LOD**, every 0.5 s:
  - `CostumeDetail` pieces get `LocalTransparencyModifier=1` beyond 90 studs
  - costume emitters are disabled beyond 120 studs

### 6.3 Budgets

| Figure | R15 | Costume budget (FP + markers + kit) | Cap | Lights | SurfaceGuis | Emitters |
|---|---|---|---|---|---|---|
| Player | 16 | ≤14 (Threadrunner with suit: 14) | **30** | 0 | ≤4 (2 face) | ≤1 |
| Human enemy | 16 | 3 → 13, plus markers, trimmed to 14 | **30** | 0 | ≤3 | ≤1 |
| Creature | 16 | ≤14 | **30** | 0 (UFO: 1 SpotLight) | ≤2 | ≤1 |
| Alpha / elite / stitched | 16 | markers first | **30** | 0 | ≤3 | ≤2 |
| Character boss | 16 | ≤14 (halo is Beams) | **30** | 1 | ≤4 | ≤2 |
| Hyakunui / Tempest Fox / Unbidden / ward | 16 | 14 / 14 / 13 / 14 | **30 / 30 / 29 / 30** | 1 / 0 / 0 / 0 | ≤4 | ≤3 |

- **Worst-case parts**: 24 enemies × 30 + 8 players × 30 + wards (1 per caster, 30 each) is about 1,200 character parts. These are spread over the arena and LOD-culled on the client.
- **Character lights**: at most 5 (up to 4 bosses plus the UFO class), well within the 60-light arena cap.

### 6.4 Highlight budget

`Enemies.claimHighlight(model, prio)` / `releaseHighlight(model)` keep a module counter:
- Finale and character bosses always get a Highlight (at most 4).
- Elites get one only while the total is 12 or fewer.
- Alphas, stitched figures, Worn figures and wards never get one.

The total stays at 16 or fewer, well under 31.

### 6.5 Particle emitters (`Kit.EMITTERS`)

Caps: enemies Rate ≤ 6 and Lifetime ≤ 1.2; players ≤ 6; bosses ≤ 12.

| Key | Rate | Lifetime | LightEmission | Size | Other |
|---|---|---|---|---|---|
| ember | 4 | 0.6–1.0 | 0.6 | 0.2→0 | Speed 1–2, upward |
| smoke | 5 | 1.2 | 0 | 0.6→1.2 | Transparency 0.4→1 |
| drip | 3 | 0.8 | 0.2 | 0.12 | Acceleration (0, −20, 0) |
| spark | 6 | 0.3 | 1 | 0.1 | Speed 6, Spread 180 |
| wind | 4 | 1.0 | 0.3 | 0.3→0 | Spread 30 |
| dust | 6 | 0.8 | 0 | 0.4→0.8 | at the feet |
| shadow | 5 | 1.0 | 0 | 1→0 | `0x101014`, flat |
| feather | 3 | 1.2 | 0 | 0.25 | random rotation |
| coin | 3 | 0.8 | 0.5 | 0.2 | `0xffd54a` |
| aura (boss) | 10 | 1.0 | 0.8 | 0.8→0 | Shape Cylinder, at the feet |
| thread | 4 / 12 | 1.2 | 1 | 0.1 | `0xff2d55` |
| burst | `Emit(12)` | 0.6 | 1 | 0.3→0 | one-shot |

### 6.6 Tests (Lune, `tests/`)

1. **Coverage**:
   - Every `Styles` id has a `STYLE` entry.
   - Every `boss_*` id resolves through `styleFromEnemyId`.
   - Every enemy id resolves through `baseId`.
   - `akatsuki_nin`, `gate_monk`, `ufo` and the finale ids have entries.
2. **Parts**:
   - For every style (with and without its suit), every enemy (normal, alpha, elite, stitched), every finale builder and the ward, `16 + Σ PARTS` after budget trimming is ≤ 30.
   - The untrimmed +N values in §3 **and** §4.3 equal their `PARTS` sums (goblin_drone = 12).
3. **Signature placement**: each `sig` is within the first 10 kit entries.
4. **Banned content**:
   - No effective look keeps a `BANNED` flag.
   - Only E1–E11 are used.
   - No Shinobi forehead plate.
   - No ninja uses a scratched mark.
5. **Colour**:
   - For any Skyline style whose head is masked (FM, or HD + LM), the largest non-neutral colour has no hue < 20° or > 340° at saturation > 0.5. Redmaw `0x8a1a5a` (≈326°) and Cackler `0xc8642a` (≈22°) pass.
   - No Skyline costume pairs a red with a blue (200°–250°).
   - Threadrunner has no hue within 20° of `0xffb347`, and no head colour with value > 0.85 and saturation < 0.15.
6. **Palette**: `palette(...).base` never equals `affix.color` unless the template colour does. `goblin_drone` base is `0xc8642a`.
7. **Adaptation order**: `ADAPT_ORDER` is a permutation of the `NATURE` keys.
8. **Props**: for each style in `Arsenals`, every key in `Arsenals[style].order` exists in `ARSENAL_PROP[style]`, and each prop is ≤ 3 parts.
9. **Roles**:
   - Every `ALPHA_IDS` entry resolves to `"alpha"`.
   - Every `Finale.ENEMIES` key resolves to `"finale"`.
   - Every `boss_*` id resolves to `"charBoss"`.
   - `Rules.rollAffix(w, true, 0, 0, 1)` returns nil.
10. **Face zone**: for every style and grade, no mounted piece outside {VB, VB·m, GG, FM, BK} has a surface with z < −0.60 inside `EYE_ZONE` (§2.2). `ringOver` holds on both axes for every band worn over a cap.
11. **Ellipsoids**: every `PARTS`/spec entry of kind `ball` has three equal axes. Anything else must be `ell`.

---

## 7. Reviewer items (revision 2)

### Blocking, all fixed

| # | Item | Fix | Where |
|---|---|---|---|
| 1 | Non-uniform Balls | `Kit.ellipsoid` (Block + Sphere SpecialMesh), "Ell" notation, explicit Cylinder `Size=(L,d,d)` convention, test 11 | §2.1 |
| 2 | Headband over the eyes | HB 1.40×0.2×1.40 at y 0.36 (z +0.06), HB·t at y 0.30, cap at 0.32 (z +0.06), `ringOver` on both axes, face-zone test 10. HR·f moved clear of the eye. | §2.2, §2.3, §6.6 |
| 3 | Legs swinging with hidden arms | `Gait_*` welds on LowerTorso/HRP, driven by the client (±22°, `rootSpeed/(1.6·S)`, diagonal pairs). Toad hop 0.25. KeyframeSequence fallback removed. Wraith claws and blob tendrils moved off hidden hands too. | §2.1, §4.2, §5.2 |
| 4 | Alphas treated as bosses | `Costumes.role` precedence; alphas get no halo, light or Highlight; test 9 | §1.5 |
| 5 | Tell can stick | cleared on `cancel`, `endLunge` and death | §5.2 |
| 6 | Redmaw | `0x8a1a5a`, bone spurs, vein `0x3a0a2a`, jagged bone-fang maw | §3 |
| 7 | IP on four playables | **Aoi Hakumei**: VB removed; 3 orbiting cyan shards; hair `0xc8c0e0`; glowing eyes during Infinity. **Threadrunner**: HD + LM + teal goggles, no white on the head. **Cackler and goblin_drone**: rust `0xc8642a` / charcoal / amber. **Clawback**: olive parka, no stubble, one long curved blade per arm. | §3, §4.3 |
| 8 | Unbidden tiles on the back | collar ring (r 0.78, y −0.05, 45° steps, 0.42×0.3×0.14) plus chest-trim echo | §5.3 |
| 9 | Sub-limb colours; per-SurfaceGui lighting | `Kit.paintParts`, reapplied after LoadCharacter, redress and buildNpc. Two face SurfaceGuis (FaceBase lit, FaceGlow unlit); `Kit.ally` moves the irises and disables FaceGlow. | §2.4, §2.8 |

### Improvements adopted

- Stitched only on elites and stitched summons; bosses are never stitched.
- Haru's stitched hood patch, and the hood recoloured to mustard.
- `Suit` hook for TN, with listeners disconnected on `Destroying`.
- Patchwork's quilted plates, seam strip and fist-plus-thumb (also used on Hyakunui).
- Tetsuo's shaved-side crest and ear cuff; Midori keeps the topknot.
- Gravewell's basalt shards.
- Doctor Eightfold's Neon claw tips.
- Ward: strike origin, cleanup list, `SetNetworkOwner(nil)`, cyan ring.
- Missing numbers filled in: ring host and height, footprint, stitched strip placement, Armored shell 1.08×, UFO × `t.size`.
- `ARSENAL_PROP[style][key]` and the test 8 iteration.
- goblin_drone = 12, and the §4.3 sums are now covered by a test.
- Scratched-headband mark dropped.
- CP 2.3 long at `rx(-12)` and CT at `rx(-14)`, both hinged at the top.
- Death read.
- Darkening scope defined.
- F11 reworded.

### Declined or adjusted

- **Doctor Eightfold's arithmetic.** The suggested "drop CT and 2 GL" was not possible because he had no GL. I dropped CT (−2) and the monocle (−1) instead, which also removes a glasses echo. That makes him 14 rather than 13.
- **Patchwork totals 8, not 7.** The fist-plus-thumb the reviewer asked for is 2 parts.
- **Hyakunui's fist.** It would have pushed him to 31, so it replaces one needle: the 4th thread ends in the fist. He stays at 30.
- **Clawback gets a hood.** I added HD·d (+1) so the parka has a read shape above the shoulders once the claws are shortened.
- **Aoi Hakumei keeps coat tails.** I kept CT and made the coat slate `0x2a3550` with ivory lapels. Removing the eye band and the pale hair already breaks the archetype, and the coat keeps the Academy silhouette.
- **Tempest Fox scale.** I made S explicit (`2.4×0.55×t.size`) and gave the walker HeightScale 0.7, so the invisible hitbox matches the visible fox. This was not requested, but without it shots over its back would hit empty air.