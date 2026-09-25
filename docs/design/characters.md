# Character and Enemy Looks: Design v5 (Designer revision 5), APPROVED WITH CONDITIONS

> **Lead approval.** Approved for building, with the round-5 reviewer's three blocking IP items fixed below by the lead (no further agent revision). See `docs/design/APPROVAL.md`.
> 1. **No red glowing eyes on Karasu or Akuro.** Karasu's `sig` is periwinkle `7a8ad8` (clip, FaceGlow, ember `5a5a78`). Akuro's `sig` is amber `e0a030`, his cloth moves off the crimson-black read to indigo-charcoal `1c1a2a` / trim `3a3450`, and his hair wedges and crack are amber. **Boss FaceGlow for these two is never red.**
> 2. **Hatsuyuki wears no mask.** LM is removed. The copy ring moves to a SurfaceGui on the right glove (`sigPiece = GL`). Hair wedges are steel teal `3a5a6a`; sleeves and coat `4a5a6a`, so nothing is pale. 8 parts.
> 3. **Nuime has no bun and no face stitches.** A crop with a low HR·p tail; the cross-stitched sleeve stays as his signature. **Test 5a also rejects any stitch or seam mark on the face or neck of a player or a character boss.** Hyakunui keeps its midline seam (it is the Seam's boss, not a player style).


This design builds everything from R15 HumanoidDescriptions, Parts, WedgeParts, CornerWedgeParts, SpecialMesh `Sphere`, Welds, Beams, SurfaceGuis, ParticleEmitters, Highlights and PointLights. It uses no asset ids. Sizes are nominal studs at scale 1. How a size and offset are scaled at build time depends on the piece's scaling mode (§2.1, **Scaling**).

**Changes in revision 5** (each round-4 blocking item and where it is fixed)

1. **IP: franchise marks and copied source data.**
   - **(a) Ren's cheek mark.** The 3-line wind-streak is removed. Ren has no face or cheek marks at all (§3 Ren row). `BANNED` now also forbids a substitute mark in the same place, and test 5a rejects 2 or more parallel Frames on one cheek (§2.7, §6.6).
   - **(b) Nosebleed's nose mark.** Removed in every phase. `nosebleed` (and `fangs`) join `BANNED` (§2.7). The other copied `eleven` values are also replaced: bottom `2a3a5a` → `4a4a3a`, eye `4a3a2a` → `5a6a5a`, and the off-white `f0e0d0` stripe → mustard `e8c86a` (§3.0, §3).
   - **(c) Patchwork.** Hair and brow are plum `3a1e34`. The pale blue-grey `bacccf` is gone: LeftArm and PLT R are now the deep human tone `8a6244`. Top `5a4636`, legs L `4a5a3a` / R `6a3a4a`, trim `c8a878`, eye `a8883a`, and sig and SEAM jade `5ae0a0` (replacing the source's `b06cff`) (§3.0, §3, §3.1). Hyakunui's right half follows: HR·p `3a1e34`, RightArm and FS `8a6244`, RightLeg `6a3a4a`, Torso `3a2e2a`, right iris `a8883a`. The needles are now steel `9aa4b0` (§5.1).
   - **(d) Antidote.** It is now a `lean`, height-1.04 two-tone field medic: celadon `a8c4b0` head and torso, deep teal `24585a` arms and legs, bone `d8ccb0` pauldrons and plate, and a mint `4ae0c0` slit and droplet. No colour is white or near-white (§3.0, §3).
   - **(e) Guard.** `SKIN_TONES` is now an explicit list of 19 human tones with no mask or suit colours. It is exempt only where the colour is used as skin (§3.0). `TRADE_DRESS` gains rows for mahito, antivenom, eleven, kenjaku, dagon, jogo and uro, and the docock and kashimo rows are extended (§3.0). A new mechanical **test 5g** reads the source data in the test only and fails any style that verbatim-copies more than 2 source colours, or any body-read colour (§3.0, §6.6). Test 5g found 18 more styles with copied colours, all now recoloured: Tidehollow, Kazan, Ikazuchi, Nuime, Framerate, Skyfold, Hammer Maiden, Kage Inukai, Jackpot, Supernova, Doctor Eightfold (brass arms, amber claws), Hatsuyuki, Akuro, Gravewell, Midori Tetsu, Rei, Top Hat and Redmaw. Overtime's white cloth-wrapped blade is now a bare steel blade. I ran a script over §3.0, §3, §3.1 and §5.1 in both roles: 5b, 5c, 5d, 5e and 5g all show 0 violations. It also caught Clawback's hair going red under the boss lerp, now `2a2420`.
2. **Tests that failed on the design's own data.**
   - **(a) Test 5e** now checks only non-skin colours with saturation ≥ 0.25. Threadrunner's skin `0xc89a70` is a human tone used as skin, so it is exempt (§6.6).
   - **(b) Test 10 and §2.2.** `FACE_EXEMPT = {FP, VB, VB·m, GG, FM, BK, GR·e}`: FP is the face canvas, and GR·e is the grey's eyes. Aoi's OR moves to rest `ry(120k) * CFrame.new(0, 0.65, −0.95)`, spanning y 0.475–0.825 at every phase, so it never crosses the brows. Orbiting pieces are tested at 36 phases. Test 10's scope is stated explicitly (§2.2, §2.3 OR, §6.1, §6.6).

The revision-4 changes (round 3) are listed in §7.

---

## 0. What the code does today

| # | Finding | Where | Consequence |
|---|---|---|---|
| F1 | Long hair, ponytails and buns sit at `-s.Z*0.5` / `-s.Z*0.45`. −Z is the face side. | `Looks.dressHair` | Hair covers the face. Move it to +Z. |
| F2 | Spiky hair adds up to 10 parts. | `dressHair` | Cap hair at 4 parts. |
| F3 | Nothing clears the default `face` decal. | `Looks.description` | Every enemy and boss smiles. |
| F4 | About 40 costume flags in `Characters.luau` / `EnemyLooks.luau` are never read. | `Looks` | For human enemies only, the kit reads them (§2.7). |
| F5 | Generated data copies franchise trade dress. This is not only the flags (`webs`, `spider`, `whiskers`, `reactor`, `venomEyes`, `tieSpots`, `blindfold`, `eyePatch`, `sharingan`/`rinnegan`, `volcano`, forehead `stitches`, red-collar cloaks). It is **also every colour**: orange sleeves on naruto, a red face on spiderman, gold sleeves on ironman, yellow sleeves on wolverine, a pink wig on sukuna, red `sig` on the Skyline figures. | `Data/Characters.luau`, `Data/EnemyLooks.luau` | Players and character bosses never read that data (§2.7). STYLE states every colour itself (§3.0). |
| F6 | `ufo` (`shape="ufo"`) is not in `SHAPES`. `akatsuki_nin`, `gate_monk` and their `_alpha` variants have no look. | `Enemies.spawn` | They fall back to the default human. |
| F7 | Elites get a Highlight, but clients render at most 31 Highlights. On the Seam every non-boss is an elite (`bonus=1`, Waves.luau:101), with `MAX_ENEMIES=24`. | `Enemies.spawn` | Needs a Highlight budget (§6.4). |
| F8 | Wall raycasts can hit costume parts. | `Projectiles`, `Abilities.clearPath` | Every costume part is set `CanQuery=false, CanTouch=false, CanCollide=false, Massless=true`. |
| F9 | Franchise terms outside this track must be renamed before publishing: `akatsuki_nin` "Red Cloud Cell"; "Cursed Womb"; "Finger Bearer"; "Kyoto Student"; "Summon Mahoraga" and the `MAHORAGA` banner (Abilities.luau:728); "Fox Chakra Mode"; "Domain: Unlimited Void"; "Malevolent Shrine"; "Self-Embodiment of Perfection"; "Horizon of the Captivating Skandha"; "Coffin of the Molten Mountain"; "Womb Profusion"; "The Phoenix Force"; "House Party Protocol"; "Heavenly Restriction"; "Spider-Sense" (Styles.luau passives); display names for the arsenal keys `mark42`, `hulkbuster`, `warmachine`, `playful_cloud`, `split_soul`; the display name of the `pumpkin_bomb` drop. | data and UI strings | Keys are internal. Props are keyed by the current keys, so they survive a rename of display names only. |
| F10 | `Rules.applyAffix` sets `t.color = a.color` (Rules.luau:410) before any look code runs. | `Enemies.spawn` | Elites get painted entirely in the affix colour. Fix: `pal.base` is captured before the affix (§4.1) and stored on the enemy as `e.pal` (§6.2). |
| F11 | `description()` never reads `look.headScale` and sets HeadScale to 1. `buildNpc` then sets `d.HeadScale = size`. | `Looks.description`, `Looks.buildNpc` | Human enemies: read `look.headScale`, clamped to 0.8–1.1. Players and bosses: the preset's HeadScale. `buildNpc` does `d.HeadScale *= size` after the preset. |
| F12 | `Rules.rollAffix` returns nil when `boss` is set (Rules.luau:389). | Rules | Bosses never carry affix markers. |
| F13 | A Part with `Shape=Ball` is always a sphere. The existing `SHAPES` toad (2.6×1.9×2.6), wraith and imp, and the `dressHair` cap, all ask for ellipsoids and silently get spheres. | `creatureBody`, `dressHair` | All non-uniform balls use `Kit.ellipsoid` (§2.1). |
| F14 | All 32 `_alpha` templates have `boss = true`. So alphas never roll an affix (F12), and a naive "boss" check would give them boss dressing. | Data/Enemies.luau | Role is decided with a fixed precedence (§1.5). |
| F15 | `creatureBody` hides every R15 part, golem and imp limbs included. It welds with WeldConstraint at a world CFrame. | Enemies.luau:106 | Replaced by the `CREATURES` builders (§4.2). |
| F16 | `Rules.aiStep` leaves the tell state through `cancel` as well as through `lunge`/`endLunge` (Rules.luau:488). | Enemies.luau:426 | The Tell attribute must also clear on `cancel` (§5.2). |
| F17 | `Combat.kill` tweens every visible BasePart's Transparency to 1 over 1.2 s on the server (Combat.luau:357–363). Its burst uses `e.t.color` (Combat.luau:346), which is the affix colour after F10. The spawn burst uses `look.top` (Enemies.luau:238). | `Combat.kill`, `Enemies.spawn` | The server fade replicates over any client fade. Fixed in §6.2. |
| F18 | `Combat.publish` rewrites `Suit = floor(suitHp)` (Combat.luau:280) on every publish, so it changes on every hit. | `Combat.publish` | Any `Suit` listener must be edge-triggered (§2.6). |

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
6. **No inherited looks.** Every colour and every piece on a player or character boss is written in this document (§3.0, §3, §3.1, §2.9). Generated data is never a fallback.

### 1.2 Proportion presets (applied in `description()`)

| Preset | WidthScale | DepthScale | HeadScale | BodyTypeScale | ProportionScale | Used by |
|---|---|---|---|---|---|---|
| `lean` | 0.88 | 0.9 | 1.0 | 0.3 | 0.6 | acrobats, ninjas, students |
| `standard` | 1.0 | 1.0 | 1.0 | 0.2 | 0.3 | default |
| `heavy` | 1.25 | 1.15 | 0.9 | 0.1 | 0.0 | brutes, golems, heavy suit |
| `small` | 0.95 | 0.95 | 1.35 | 0.0 | 0.0 | imps, the grey |
| `towering` | 1.1 | 1.0 | 0.8 | 0.5 | 1.0 | finale bosses |

- HeightScale is `STYLE.height` for players and character bosses (§3.0), and `look.height` for human enemies.
- `look.headScale` applies to **human enemies only**. It overrides the preset HeadScale and is clamped to 0.8–1.1. Players and character bosses always use the preset HeadScale.
- NPCs then multiply every scale by `size`, using `*=`.

### 1.3 Palette per universe (`WORLD_OF` → `WORLD_LABEL`)

| Universe | Base cloth | Metal / trim | Accent rule | Materials | Emblems |
|---|---|---|---|---|---|
| **Shinobi Lands** (`naruto`) | indigo `0x2b3350`, moss `0x4f6b3a`, sand `0xc9b48a`, wrap `0xe8e0d0` | steel `0x9aa4b0` | One warm accent, only on the scarf, belt or wraps | Fabric, Metal | E1 Gust, only on buckles and shoulder guards. No forehead plates. |
| **Sorcerer's Academy** (`jjk`) | navy `0x1b1f2e` / `0x252c40`, black `0x14141c` | gold `0xc8a44a` | Violet `0xb06cff` or crimson `0x9b1a2a`, as glow only | Fabric, SmoothPlastic, Foil | E7 Seal Ring |
| **Skyline City** (`marvel`) | graphite `0x23262e`, gunmetal `0x4a4f58`, ivory `0xe8e4dc` | chrome `0xb8bec8` | One saturated hero colour plus 0.06-stud seams. No red anywhere, no red-and-blue pair, no spider or web marks, no white lenses on a dark suit. | SmoothPlastic, Metal, Glass (small lenses only), Neon | E2 Knot, E3 Hex, E5 Droplet |
| **Elsewhere** (`other`) | teal `0x2f8f86`, off-white `0xf0e0d0`, black `0x181818` | none | A single accent | Fabric | a personal glyph |
| **The Seam** (finale) | bruise `0x3a0a14`, ash `0xc8b8b0` | thread crimson `0xff2d55` | crimson seams | Neon, Beams | E11 Seam |

### 1.4 Reading a figure at a glance

`base` is the template colour captured **before** `applyAffix`, or the `Costumes.ENEMY` variant override (§4.1).

| Role | Eyes | Body colour | Marker | Highlight | Light |
|---|---|---|---|---|---|
| **Player** | whites + iris, on FaceBase (lit) | STYLE colours (§3.0), full saturation | signature trim, nameplate | none | none |
| **Normal foe** | iris only, on FaceGlow (unlit, Brightness 2.5) | every cloth colour lerped 20% toward `0x2a2a30` (§4.1) | none | none | none |
| **Alpha** | FaceGlow, gold `0xffd54a`, iris ×1.3 | 15% darker than normal | **Alpha crest**: 1 gold Neon CornerWedge 0.5×0.45×0.5 (§4.5), plus a `dust` emitter | **none** | **none** |
| **Elite** (affix) | FaceGlow tinted `affix.color` | `base` | **Affix ring** (§4.5) plus the motif (0–2 parts) | only within budget (§6.4) | none |
| **Stitched** (elite on a stitched map) | crimson | `base` | 2 crimson Neon strips replace the motif; ring turns `0xff2d55` | never | none |
| **Ally / Worn** | FaceBase (whites + iris) | `base` | ring or SD turns cyan `0x5ad4ff`; strips removed | released | none |
| **Character boss** | FaceGlow in `STYLE.colors.sig` (§3.0) | STYLE colours lerped 22% toward `0x14040a` (not `eye`, `sig` or Neon tints) | **Rift halo**: 3 Beams (0 parts), `aura` emitter | always | 1 PointLight (range 14, brightness 1.2) |
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
  - `CYL_UP = CFrame.Angles(0, 0, math.pi/2)`: local X → +Y. Used for vertical rods, hat crowns and brims, and floor rings.
  - `CYL_FWD = CFrame.Angles(0, math.pi/2, 0)`: local X → −Z. Used for discs facing forward or back (goggles, cores, the glider).
  - No rotation: a left-right rod, or a disc facing ±X (headphone cups, the watch).
- C0 expressions compose left to right: `CFrame.new(p) * rx(a) * CYL_FWD` means "move to p, tilt, then turn the cylinder axis".

**Weld rules**
- Every piece uses `Instance.new("Weld")`:
  - `Part0 = host`, `Part1 = piece`.
  - `C0 = (attachment and attachment.CFrame or CFrame.identity) * scaledOffset`.
  - `C1 = CFrame.identity`.
  - The piece's world CFrame is never set.
- This depends only on the rest pose, so it works on client-animated players and on server NPCs. `dressHair` moves to the same method.
- **Hinged pieces** (capes, tails, lapels) are written as `C0 = attach * CFrame.new(hinge) * rot * CFrame.new(0, -L/2, 0)`, so they rotate about their top edge.
- **Chained pieces** (BA segments, Eightfold claws) use a bone frame whose +Y runs along the segment:
  ```
  bone_1 = attach * CFrame.new(base) * rot_1 * CFrame.new(0, L_1/2, 0)
  bone_k = bone_{k-1} * CFrame.new(0, L_{k-1}/2, 0) * rot_k * CFrame.new(0, L_k/2, 0)
  C0_k   = bone_k * CYL_UP      -- cylinders (axis X turned onto the bone's Y)
  C0_k   = bone_k               -- Blocks and Wedges, which are already Y-long
  ```

**Scaling** (`b:mount(host, attach, kind, size, cf, props, opts)`)
- `k = if opts.absolute then Vector3.one else host.Size / NOMINAL[host.Name]`. The builder errors if `NOMINAL[host.Name]` is nil and `absolute` is not set.
- **Offsets**: `scaledOffset = CFrame.new(cf.Position * k) * cf.Rotation`.
- **Sizes** are projected onto the piece's own axes, so rotated pieces scale along the right host axis. With `R = cf.Rotation`: `kl.X = |R.XVector.X|·k.X + |R.XVector.Y|·k.Y + |R.XVector.Z|·k.Z`, and likewise for `kl.Y` with `R.YVector` and `kl.Z` with `R.ZVector`. Then `size *= kl`. This is exact for axis-aligned pieces and 90° turns such as `CYL_UP`.
- **`absolute = true`** is used for:
  - every piece of toad, blob, wraith and UFO (sized in B or × `t.size`, §4.2)
  - every piece of the Tempest Fox (sized in S, §5.2)
  - every piece whose host is `HumanoidRootPart`: affix ring, SD, UFO SpotLight holder
  - creature Armored plates (sized in B)
- **`absolute = false`** (nominal, relative) is used for:
  - players and character bosses
  - human enemies
  - golem and imp pieces, which are nominal studs on visible R15 parts
  - Hyakunui, the Unbidden and the ward
  - alpha crests on humans
- `NOMINAL.HumanoidRootPart = Vector3.new(2, 2, 1)`, so a relative mount on the HRP by mistake still resolves. Test 12 asserts that no creature or Tempest Fox piece mounts with `absolute=false`.

**Piece properties**
- Every piece: `CanCollide=false, CanQuery=false, CanTouch=false, Massless=true, Anchored=false`.
- `CastShadow=false` when the largest side is under 0.6 studs.
- Pieces go in `Folder "Costume"` under the model. Suit tendrils go in `Costume/SuitTN`, and the arsenal prop goes in `Costume/Prop`.

**Client-driven welds (0 server cost)**

| Weld name | Tag | Attributes | What the client does |
|---|---|---|---|
| **`Gait_*`** | model tag `Gait` | `GaitPivot` (Vector3, in Part0 space), `GaitPhase` (0 or 0.5), `GaitAmp` (degrees) | Once, stores `rest = weld.C0`. Every frame: `weld.C0 = CFrame.new(p) * CFrame.Angles(math.rad(a*sin(2π(f·t + phase))), 0, 0) * CFrame.new(-p) * rest`, with `f = rootSpeed / (1.6·S)` Hz. `a` scales with `clamp(rootSpeed/4, 0, 1)`, so idle means still. |
| **`Orbit_*`** | model tag `Orbit` | `OrbitAxis` (Vector3), `OrbitRate` (rev/s), `OrbitPhase` (0–1), **`OrbitCenter`** (Vector3 in Part0 space, default (0,0,0)) | Stores `rest`. Every frame: `weld.C0 = CFrame.new(c) * CFrame.fromAxisAngle(axis, 2π(rate·t + phase)) * CFrame.new(-c) * rest`. The rest C0 places the piece on its ring around `c`. |
| **`Sway_*`** | model tag `Sway` | `SwayPivot` (Vector3, hinge point in Part0 space), `SwayAmp` (degrees, default 18) | Stores `rest`. Every frame: `θ = −SwayAmp·clamp(horizSpeed/16, 0, 1) + 3·sin(2π·1.2·t)` degrees, then `weld.C0 = CFrame.new(p) * CFrame.Angles(math.rad(θ), 0, 0) * CFrame.new(-p) * rest`. A negative angle lifts the bottom backward (+Z). Runs only within 60 studs of the camera. |
| **`Glide`** | the WG weld | model attribute `GlideUntil` (server time) | While `workspace:GetServerTimeNow() < GlideUntil`, sets `weld.C0 = UpperTorso.CFrame:ToObjectSpace(HRP.CFrame * CFrame.new(0, y_g − 0.06, 0) * CYL_UP)` each frame. Otherwise it restores `rest`. |

- Client writes to a server Weld's C0 don't replicate and don't fight the server, because the server never rewrites them after the build.
- `Sway_*` is set on CP, CP-short, CT, the SC tail, HB·t and the Tempest Fox tails (SwayAmp 10).

**Anchor attachments** (standard R15)
- Head: `HairAttachment`, `HatAttachment`, `FaceFrontAttachment`.
- UpperTorso: `NeckAttachment`, `BodyFrontAttachment`, `BodyBackAttachment`, `Left/RightCollarAttachment`.
- LowerTorso: `WaistFront/Back/CenterAttachment`.
- UpperArm: `Left/RightShoulderAttachment`.
- Hand: `Left/RightGripAttachment`.
- Foot: `Left/RightFootAttachment`.
- "Head (x, y, z)" or "UpperTorso (x, y, z)" with no attachment means the offset is from the **part centre**.
- LowerArm and LowerLeg pieces use the part itself.

**Axes and rotations**
- Axes: X right, Y up, **Z back** (−Z is the face side).
- `rx(d) = CFrame.Angles(math.rad(d), 0, 0)`. A positive d tips the bottom forward (−Z) and the top back (+Z).
- `rz(d) = CFrame.Angles(0, 0, math.rad(d))`. A positive d swings the bottom toward +X and the top toward −X.
- `ry(d) = CFrame.Angles(0, math.rad(d), 0)`.
- **Paired signs**: in "L/R … (∓a …) rz(±b)" the upper sign is for Left and the lower sign for Right.

**Mount order and trimming.** Every kit and family entry carries a tier:

| Tier | Contents |
|---|---|
| 0 | FP |
| 1 | markers (§4.5) |
| **W** | weak points |
| **R** | read and identity pieces, including a player's `sigPiece` and every entry before it |
| **L** | limbs and gait pieces |
| **D** | decoration |

- The builder mounts tiers in that order, and entries in listed order within a tier.
- An entry (a pair or group counts as one entry) is mounted whole or skipped whole, never split.
- When an entry does not fit the remaining budget, it is skipped and the next entry is tried.
- For players, every kit entry after `sigPiece` is tier D, and the rest are R. Only Threadrunner with the suit comes near the budget (12 ≤ 14), so no player piece is ever trimmed.
- **Test 3** checks that every W and R entry survives for every enemy in each of these roles:
  - normal
  - alpha
  - elite with the largest motif (Armored, 2 parts)
  - stitched

  It also checks that every player's `sigPiece` survives and sits within the first 10 kit entries.

**Nominal sizes at scale 1** (`NOMINAL`)

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
| HumanoidRootPart | 2×2×1 |

**Ground and footprint**
- **Ground** in HumanoidRootPart (HRP) space is `y_g = −(HipHeight + HRP.Size.Y/2)`, read after the model is built and before it is parented.
- **Footprint** is:
  - `max(body.X, body.Z)` for creatures
  - `2.2 · WidthScale · size` for humans

### 2.2 Face-zone rule

- **Face zone**: FP's canvas top is at head y 0.325.
  - Eye row: head y 0.085–0.165.
  - Brows: head y 0.20–0.23.
  - **Eye zone** (`Costumes.EYE_ZONE`): x ∈ [−0.33, 0.33], y ∈ [0.06, 0.24]. The whites span x ±(0.17–0.31) and the brows ±(0.16–0.32), so this covers every eye and brow element, including alpha irises at ×1.3 (±0.132 to ±0.288).
- **Rule**: no piece outside `Costumes.FACE_EXEMPT = {FP, VB, VB·m, GG, FM, BK, GR·e}` may have any surface in front of z = −0.60 (the head's front face) inside the eye zone.
  - FP is exempt because it *is* the face canvas (Block at FaceFront z −0.02, spanning z −0.61 to −0.63). GR·e is exempt because it *is* the grey's eyes (z −0.63 to −0.53). VB, VB·m, GG and FM lenses are eyewear or eyes by design, and BK is a beak that starts below the eye row.
  - Ellipsoids are tested analytically, and blocks and wedges as oriented boxes.
  - **Orbiting pieces** (`Orbit_*` welds: OR, CRY, ORB, WSP, SHD) are tested at 36 evenly spaced phases of their orbit, using the driver formula from §2.1, not only at rest.
- **Worked checks**
  - The HR cap at y 0.26 or 0.32 with z +0.06 reaches at most z −0.592 at y 0.24. It passes.
  - HR·f at x −0.44 spans x −0.54 to −0.34, which is outside [−0.33, 0.33]. It passes.
  - Karasu's clip spans x −0.48 to −0.40. It passes.
  - The headphone cups (§2.3 HP) are at |x| ≥ 0.57 and z ≥ −0.175. They pass.
  - **OR (Aoi)**: the rest C0 is now `ry(120k) * CFrame.new(0, 0.65, −0.95)`. The 0.35-tall Wedge spans y 0.475–0.825 at every phase, 0.235 above the eye-zone top (0.24) and 0.245 above the brow top (0.23). It never crosses in front of the brows or eyes from any orbit angle. It passes without an exemption. (At the old y 0.35 it spanned 0.175–0.525 at z −0.95 and failed.)
  - **CRY (Mindflare)**: rest y 0.6, 0.4 tall, so y 0.40–0.80 at every phase. It passes.
  - HB front face is at z −0.64 but spans y 0.26–0.46, above the zone. It passes.

### 2.3 Kit pieces (count = parts)

| Code | Piece | Shape and size (studs at scale 1) | Host and C0 offset | Parts |
|---|---|---|---|---|
| **FP** | FacePlate (face canvas) | Block 0.9×0.55×0.02, Transparency 1 | Head `FaceFrontAttachment` (0, 0.05, −0.02) | 1 |
| **HR** | Hair cap | **Ell 1.30×1.02×1.32** | Head (0, 0.26, **+0.06**); (0, 0.32, +0.06) when HB is worn | 1 |
| HR·s | Spike (back-swept) | Wedge 0.28×0.7×0.42, **`rx(+30)`** | Head, crown ring r=0.34 at y 0.6, slots at angles a = 150°/180°/210° from the front (2 spikes use 160°/200°); C0 = `CFrame.new(0.34·sin a, 0.6, −0.34·cos a) * rx(+30) * ry(a)`. The tilt is applied in head space, so every top leans to +Z; `ry(a)` then only turns the wedge's slope outward | 1 each |
| HR·w | Swept wedge (back-swept) | Wedge 0.3×0.45×0.8, **`rz(±25)*rx(+15)`** | Head (±0.35, 0.45, +0.1) | 1 each |
| HR·p | Panel / ponytail | Block 1.08×(0.6–1.5)×0.3 | Head (0, 0.5 − h/2, +0.62), so the top edge is always at y 0.5 (h = 1.5 gives centre −0.25) | 1 |
| HR·f | Forelock | Block 0.2×0.6×0.1 | Head **(−0.44, 0.12, −0.6)**; x-span −0.54 to −0.34, outside `EYE_ZONE` | 1 |
| HR·k | Bun / topknot | Ball Ø0.54 | Head (0, 0.62, +0.45) bun; (0, 0.78, 0) topknot | 1 |
| HR·t | Tuft | Ball Ø0.45 | Head (±0.4, 0.5, 0) | 1 each |
| **HB** | Cloth headband | Block **1.40×0.2×1.40** | Head (0, **0.36**, **+0.06**); spans y 0.26–0.46 | 1 |
| HB·t | Knot tails | 2 Blocks 0.14×0.6×0.05, hinged, `rx(-20)*rz(±15)`, `Sway_*` | Head (±0.1, **0.30**, +0.8) | 2 |
| **VB** | Visor band | Block 1.28×0.2×0.14, Glass, Transparency 0.35 | FaceFront (0, 0.12, −0.02) | 1 |
| VB·m | Monocle | Cyl Ø0.34×0.05 `CYL_FWD`, Glass | FaceFront (+0.24, 0.12, −0.04) | 1 |
| **LM** | Lower mask | Block 1.26×0.5×1.26 | Head (0, −0.36, 0) | 1 |
| **CK** | Choker | Block 1.1×0.22×1.1 | UpperTorso `NeckAttachment` (0, 0.12, 0) | 1 |
| **FM** | Full mask | Ell 1.28×1.3×1.3 at the Head centre, plus either 2 lens Blocks 0.26×0.13×0.05 `rz(±14)` at FaceFront (±0.24, 0.1, −0.05), or 2 round lenses Cyl Ø0.3×0.06 `CYL_FWD` at FaceFront (±0.24, 0.12, −0.03), or 1 slit Block 0.9×0.1×0.05 at FaceFront (0, 0.12, −0.05) | as stated | 3 / 3 / 2 |
| **BK** | Beak | Wedge 0.35×0.35×0.8 | FaceFront (0, −0.05, −0.4) | 1 |
| **HD** | Hood (up) | shell Ell 1.45×1.4×1.2; 2 cheek-frame Wedges 0.12×1.1×0.7 | shell Head (0, 0.1, +0.35); frames Head (±0.66, 0, −0.1) | 3 |
| HD·d | Hood (down) | Ell 1.3×0.5×0.8 | `NeckAttachment` (0, −0.1, +0.55) | 1 |
| **HN** | Horns / branches | Wedge 0.18×0.55×0.24 pair `rz(∓20)`; branches: Cyl Ø0.12×0.7 `CYL_UP*rz(∓20)` | Head (±0.38, 0.55, 0) | 2 |
| **EP** | Ears / fin | Wedge 0.12×0.5×0.3 pair; fin Wedge 0.1×0.6×1.1 | Head (±0.4, 0.6, 0) / (0, 0.7, +0.1) | 1–2 |
| **EC** | Ear cuff | Cyl Ø0.15×0.08 (no rotation: disc faces ±X) | Head (+0.61, 0.0, 0) | 1 |
| **GG** | Goggles | 2 Cyl Ø0.36×0.06 `CYL_FWD` | on the face: FaceFront (±0.24, 0.12, −0.03). Pushed up: Head **(±0.24, 0.5, −0.56)** `* rx(40) * CYL_FWD` (the cap front at y 0.5 is z −0.52) | 2 |
| **HP** | Headphones (new) | 2 cups Cyl Ø0.45×0.14, no rotation; band = 1 Beam (0 parts) | cups Head (±0.64, 0.02, +0.05); band: Attachments `HP0` at Head (−0.64, 0.245, +0.05), Axis (0,1,0), and `HP1` at Head (+0.64, 0.245, +0.05), Axis (0,−1,0), SecondaryAxis (1,0,0) on both; Beam `CurveSize0 = CurveSize1 = 0.9`, Width 0.12, Segments 12, `FaceCamera=true`, LightInfluence 1, tint `0x2a2a30`. The peak at x=0 is y 0.245 + 0.75·0.9 = 0.92, which clears the cap top (0.77) by 0.15. | 2 |
| **CR** | Crest / crown | 4 CornerWedges 0.3×0.5×0.3 | Head ring r=0.4, y 0.55, 90° steps: C0 = `ry(45 + 90i) * CFrame.new(0, 0.55, −0.4)` | 4 |
| **OR** | Orbit shard | Wedge 0.12×0.35×0.2, Neon | Head, rest C0 = `ry(120k) * CFrame.new(0, **0.65**, −0.95)` (spans y 0.475–0.825: a crown-height ring, clear of the eye zone at every phase, §2.2); Weld `Orbit_k`, axis (0,1,0), centre (0,0,0), 0.25 rev/s | 1 each |
| **SC** | Scarf | wrap Block 1.2×0.34×1.25; tail Block 0.36×1.3×0.08 | wrap `NeckAttachment` (0, −0.05, 0); tail hinged at `BodyBack` (±0.45, 0.35, +0.1) `rx(-12)`, `Sway_*` | 2 |
| **SG** | Shoulder guard | Block 1.1×0.3×1.15, `rz(±20)` | `L/RShoulderAttachment` (∓0.1, 0.12, 0) | 1 each |
| **HC** | High collar | Block 1.25×0.55×1.2 | `NeckAttachment` (0, 0.15, +0.05) | 1 |
| **LP** | Open lapels | 2 Wedges 0.5×1.1×0.08, `rz(±18)` | `BodyFront` (±0.35, 0.1, −0.04) | 2 |
| **VS** | Vest / coat body / chest plate | Block 2.08×1.5×1.12 | UpperTorso (0, −0.02, 0) | 1 |
| **EM** | Emblem plate | Block 0.55×0.55×0.05 + SurfaceGui | `BodyFront` (0, 0.2, −0.03) / `BodyBack` (0, 0.2, +0.03) / `WaistFront` (0, 0, −0.03) | 1 |
| **CT** | Coat tails | 2 Blocks 0.95×1.5×0.08, `Sway_*` | hinged at `WaistBack` (±0.48, 0, +0.04), `rx(-14)*rz(∓6)`, hung −0.75 | 2 |
| **CP** | Cape / cloak | Block 1.9×**2.3**×0.08 (short: 1.9×1.4), `Sway_*` | hinged at `BodyBack` (0, 0.55, +0.08), `rx(-12)`, hung −L/2 | 1 |
| **SB** | Sash / belt, + tail, + pouch | belt Block 2.1×0.22×1.1; tail Block 0.25×0.7×0.06; pouch Block 0.35×0.3×0.2 | `WaistCenter`; tail (0.6, −0.4, −0.56); pouch (−0.7, −0.05, −0.56); 2nd pouch (+0.7, −0.05, −0.56) | 1 / +1 / +1 |
| **MT** | Mantle / pelt / shawl | Ell 2.5×0.65×1.4 | `NeckAttachment` (0, −0.15, +0.05) | 1 |
| **CO** | Core / pendant | Cyl Ø0.4×0.08 `CYL_FWD`, Neon; diamond: Block 0.35×0.35×0.08 `rz(45)` | `BodyFront` (0, 0.25, −0.05) | 1 |
| **BW** | Back / hip prop | §2.6; default sword = hilt Cyl Ø0.14×0.8 + blade Block 0.1×2.3×0.28 | `BodyBack` (0, 0, +0.12) `rz(35)`; hilt at (0, 1.5, 0) along the blade's Y | 1–3 |
| **BA** | Back arm | segments by the chain rule (§2.1): arm (sx, sy) with sx, sy ∈ {+1, −1}; `base = (0.5·sx, 0.35·sy, +0.2)`; `rot_1 = CFrame.Angles(rad(30·sy), 0, rad(−sx·(sy>0 and 45 or 135)))`; `rot_2 = rz(40·sx)`; `rot_3 = identity` | `BodyBackAttachment` | 2 or 3 per arm |
| **TN** | Tendril | Wedge 0.2×1.4×0.3, hinged, `rx(-25)` | `BodyBack` (±0.35, −0.2, +0.2) | 1 each |
| **WG** | Glider / wings | disc Cyl Ø2.2×0.12 **`CYL_FWD`**; wings: Wedge pair 0.1×1.6×1.1 | disc `BodyBack` **(0, 0.1, +0.2)**, flat against the back; during Glider Ram the client `Glide` driver moves it under the feet (§2.1) | 1–2 |
| **GL** | Glove / bracer | Block 1.08×0.5×1.08 | LowerArm (0, −0.28, 0) | 1 each |
| **FB** | Forearm blade | Wedge 0.08×1.0×0.3 (long curved: 0.08×1.6×0.35, `rx(15)`) | LowerArm (±0.52, −0.1, 0) | 1 each |
| **MA** | Metal arm | `Kit.paintParts` Metal, Reflectance 0.2, on that arm's 3 R15 parts, + 1 Neon seam Block 0.06×1.0×0.06 | seam LowerArm (±0.52, 0, 0) | 1 |
| **XA** | Extra arm pair | per arm: Block 0.8×1.1×0.8 + Block 0.75×1.2×0.75, `rx(30)*rz(side·35)` | UpperTorso (±1.05, −0.55, −0.3) | 4 |
| **WR** | Leg wrap / sneaker cuff | Block 1.08×0.5×1.08 | LowerLeg (0, −0.2, 0) | 1 each |
| **FS** | Fist + thumb | fist Block 1.4×1.0×1.2 + thumb Wedge 0.35×0.5×0.4 | fist RightHand (0, −0.1, 0); thumb RightHand (−0.55, 0.05, −0.35) `rz(20)` | 2 |
| **SD** | Ground shadow (floaters) | Cyl Ø(1.2·footprint)×0.05 `CYL_UP`, `0x101014`, Transparency 0.6 | HRP (0, y_g + 0.03, 0), `absolute` | 1 |

**BA worked example** (Ironthread, upper right arm: sx=+1, sy=+1, both segments 1.4)
- `rot_1` turns +Y to (0.707, 0.707, 0), then `rx(30)` gives (0.612, 0.612, +0.354): up, out and back.
- `rot_2 = rz(40)` brings the second segment near vertical, so the upper pair rises like antlers.
- The lower pair (sy=−1) starts at `rz(∓135)` with `rx(−30)`, which gives (±0.612, −0.612, +0.354): down, out and back. After `rz(±40)` the tips point outward, about 4° below horizontal.
- Every tip ends behind the back plane (z > +0.5).

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
| Whites | Frame 14×8, UICorner 3 | centred (21,20) and (69,20) | `0xf4f0ea`, on FaceBase |
| Iris | 7×8 | in the whites | `STYLE.colors.eye` |
| Pupil | 3×5 | in the iris | `0x101014` |
| Brows | 16×3 | (21,11) and (69,11) | `STYLE.colors.brow`, `Rotation=±STYLE.browAngle·57` (default 0.25) |
| Mouth | 10×2 | centred (45,46) | `0x3a2020` |

- The mouth is hidden under LM, FM, CK-mask and BK.
- **Technique glow** for players: FaceGlow holds matching iris overlays in `STYLE.face.glow` (default `colors.sig`), with `Enabled=false`. `Looks.setGlow(character, on)` turns them on.

**Foe face**
- Irises 12×6 live on FaceGlow.
- Whites and pupils are `Visible=false`.

**`Kit.ally`**
- Reparents the irises from FaceGlow to FaceBase and resizes them to 7×8.
- Shows the whites and pupils.
- Sets `FaceGlow.Enabled=false`.

**Marks**
- Up to 4 Frames per face. They may overflow the canvas. Each mark states its own colour in §3.

**Chest maw** (symbiote family, 0 parts)
- A SurfaceGui on UpperTorso Front: a dark band 160×40 in `STYLE.colors.trim`.
- Teeth are Frames rotated 45°, sized 6–16 px, at irregular spacing. Half of each sits under the band via ZIndex, which gives jagged fangs rather than a grin. The tooth colour is stated per style.

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

Emblem strokes use `colors.sig` and the plate uses `colors.trim`, unless the row says otherwise.

### 2.6 Props and swaps: `Costumes.ARSENAL_PROP[styleId][weaponKey]`

**How swaps work**
- `Combat` sets the player attribute `Weapon` (Combat.luau:284).
- `Looks.dress` connects `player:GetAttributeChangedSignal("Weapon")` and, for `suitTN` styles only, `"Suit"`, once per character.
- Both connections are disconnected on `character.Destroying`, so they don't leak across respawns or transforms.
- **Weapon listener**: it caches `lastWeapon` and returns early if the value is unchanged. Otherwise:
  - If `ARSENAL_PROP[style][key].suit == true` (the ironman keys), it calls `Looks.redress(character)`.
  - Otherwise it calls `Kit.prop(character, styleId, key)`, which destroys `Costume/Prop` and mounts the new prop (at most 3 parts).
- Lookups are two-level because `knife` exists in both the yuji and tophat orders.
- Unless a row says otherwise, props use metal `0x9aa4b0`, grips and hilts `0x2a2a30`, and wood `0x5a4a3a`.

| Style | Key | Prop | Host and C0 | Parts |
|---|---|---|---|---|
| toji | `spear_chain` | shaft Cyl Ø0.12×4.5 + blade Wedge 0.1×0.6×0.25; chain = Beam to the belt | BodyBack (0, 0, +0.14) `rz(35)` | 2 |
| toji | `split_soul` | hilt Cyl Ø0.14×0.8 + blade Block 0.1×2.4×0.26 | BodyBack (0, 0, +0.14) `rz(-35)` | 2 |
| toji | `playful_cloud` | 3 Cyl Ø0.2×1.3 end to end, `0xc8a44a` bands | BodyBack (0, 0, +0.14) `rz(35)` | 3 |
| toji | `slaughter_demon` | hilt + blade Block 0.1×1.2×0.3 | WaistBack (0.7, 0, +0.08) `rz(15)` | 2 |
| maki | `naginata` | shaft Cyl Ø0.14×4.2 + blade Wedge 0.1×1.0×0.3 | BodyBack (0, 0, +0.14) `rz(30)` | 2 |
| maki | `playful_cloud_m` | as `playful_cloud` | BodyBack (0, 0, +0.14) `rz(30)` | 3 |
| maki | `split_soul_m` | as `split_soul` | BodyBack (0, 0, +0.14) `rz(-30)` | 2 |
| maki | `kusarigama` | handle Cyl Ø0.12×0.8 + sickle Wedge 0.08×0.4×0.7; chain Beam | WaistBack (−0.7, 0, +0.08) | 2 |
| yuji | `fists` | none; GL tape recoloured `0xd8683a` | n/a | 0 |
| yuji | `knife` | sheath Block 0.18×0.8×0.3 + grip Cyl Ø0.1×0.35 | WaistBack (0.7, 0, +0.08) | 2 |
| yuji | `slaughter` | cleaver Block 0.1×1.3×0.5 + grip | BodyBack (0, 0, +0.14) `rz(20)` | 2 |
| tophat | `pistol` | holster Block 0.3×0.6×0.25 + grip Block 0.15×0.3×0.2 | WaistBack (0.7, 0, +0.08) | 2 |
| tophat | `rifle` | barrel Cyl Ø0.12×2.6 + stock Block 0.2×0.35×0.9 | BodyBack (0, 0, +0.14) `rz(40)` | 2 |
| tophat | `sniper` | barrel Cyl Ø0.1×3.2 + stock + scope Cyl Ø0.16×0.7 | BodyBack (0, 0, +0.14) `rz(40)` | 3 |
| tophat | `rpg` | tube Cyl Ø0.35×2.4 + warhead Ball Ø0.4 | BodyBack (0, 0, +0.22) `rz(60)` | 2 |
| tophat | `knife` | as yuji `knife` | WaistBack (0.7, 0, +0.08) | 2 |
| ironman | `mark42` (`suit=true`) | top/sleeves/bottom/skin graphite `0x3a4250`, trim ivory `0xe8e4dc`, `standard` | n/a | 0 |
| ironman | `hulkbuster` (`suit=true`) | `0x5a6270` + ivory trim, preset `heavy`, SG ×1.3 | n/a | 0 |
| ironman | `bleeding` (`suit=true`) | Metal Reflectance 0.3 `0x2a3040`, cyan seams `0x5ad4ff` | n/a | 0 |
| ironman | `warmachine` (`suit=true`) | gunmetal `0x3a3f46`; shoulder cannon Cyl Ø0.35×1.4 + Neon muzzle Cyl Ø0.3×0.1 `0x5ad4ff` | cannon UpperTorso (1.0, 1.0, +0.1) `CYL_FWD`; muzzle UpperTorso (1.0, 1.0, −0.65) `CYL_FWD` | 2 |

**Suit swap** (no respawn):
1. `hum:ApplyDescription(newDesc)`.
2. `Looks.redress(character)`: destroys Costume and FP, rebuilds them, then re-runs `Kit.paintParts`. ApplyDescription resets part colours, so the paint must be reapplied.

**Symbiote suit hook** (edge-triggered)
- Styles marked `suitTN = true` (Threadrunner only) mount 2 TN pieces while the player attribute `Suit` is above 0.
- `Combat.publish` rewrites `Suit` on every publish (F18), so the listener acts only when the boolean flips:

```lua
local hasSuit = (player:GetAttribute("Suit") or 0) > 0
if hasSuit then Kit.suitTN(character, true) end
conns[#conns+1] = player:GetAttributeChangedSignal("Suit"):Connect(function()
    local now = (player:GetAttribute("Suit") or 0) > 0
    if now == hasSuit then return end          -- a hit changed the number, not the state
    hasSuit = now
    Kit.suitTN(character, now)                 -- mounts or destroys Costume/SuitTN (2 parts) only
end)
```

- The TN pieces sit outside the trim pass. The budget reserves 2 parts for them at dress time: Threadrunner 10 + 2 = 12 ≤ 14.
- Blackmaw, Redmaw and Antidote *are* the suit, so their looks are permanent and they connect no `Suit` listener.

### 2.7 Where looks come from, data flags, and IP remaps

**Authority**

| Figure | Look source | Reads `Characters.luau`? | Reads `EnemyLooks.luau`? | Flag → kit mapping |
|---|---|---|---|---|
| Player | `Costumes.STYLE[styleId]` only | **never** | never | **no** |
| Character boss (`boss_*`, `hanami`, `jogo`, `mahito_b`, `dagon_b`, `kenjaku_b`, `toji_b`) | `Costumes.STYLE[styleFromEnemyId(id)]` only | **never** | **never** (its `boss_*` rows are ignored) | **no** |
| Human enemy | `EnemyLooks[baseId]` colours + grade ladder + faction, or the `Costumes.ENEMY` override | never | yes | **yes** (table below) |
| Creature, finale | `Costumes.ENEMY`, `CREATURES`, `BUILDERS` | never | never | no |

After this change, nothing on the player or boss path calls `Looks.lookFor`. Test 5a proves it by building with `Characters = {}`.

**Kept flags** (human enemies only)

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

**Banned flags** (`Costumes.BANNED`, dropped for human enemies) and their replacements

| Banned flag | Replacement |
|---|---|
| `webs`, `spider`, `whiskers`, `eyePatch`, `nosebleed`, `fangs` | nothing (and no player or boss style may draw a substitute mark in the same place: no parallel cheek lines, no mark under the nose) |
| `reactor` | E3 or the CO diamond |
| `venomEyes` | FM slit |
| `tieSpots` | stripes |
| `blindfold` | nothing |
| `sharingan`, `rinnegan` | FaceGlow during techniques |
| `volcano` | CR rock crown |
| forehead `stitches` / body `stitches` | a vertical right-side seam (human enemies); never a stitched pale-skinned body |
| `headbandPlate` | cloth HB |
| `scratchedPlate` | nothing |

### 2.8 `Kit.paintParts(model, map)`

`map` has the form `{[R15PartName] = {color, material?, reflectance?}}`. HumanoidDescription colours only whole limbs (Head, Torso, LeftArm, RightArm, LeftLeg, RightLeg), so anything smaller goes through this pass.

- **When it runs**:
  - after `LoadCharacterWithHumanoidDescriptionAsync` inside `Looks.dress`
  - after `buildNpc`
  - inside `Looks.redress`
- **Sources**:
  - `STYLE.paint` (e.g. `LeftUpperArm`)
  - MA
  - finale builders

### 2.9 Default tints (`Costumes.DEFAULT_TINT`)

A kit entry without an explicit `tint` takes its colour from the style's **own** `colors` (§3.0), or from a design constant. Nothing falls through to data.

| Codes | Default tint | Material |
|---|---|---|
| HR, HR·s, HR·w, HR·p, HR·f, HR·k, HR·t, FLT | `colors.hair` | SmoothPlastic |
| FM, LM, HD, HD·d, CK, VS, HC, LP, CT, CP, MT, SG, TN | `colors.top` | Fabric (FM, SG, TN: SmoothPlastic) |
| HB, HB·t, SC, SB (+ tail, pouch), GL, WR, EM plate, EC, BA, HP, SPL | `colors.trim` | Fabric (BA, EC: Metal) |
| XA, FS | `colors.sleeves` | SmoothPlastic |
| OR, CO, Neon seams and strips, GG lenses, FM lenses and slits | `colors.sig` | Neon (GG and FM lenses: Glass, Transparency 0.2) |
| BW blade, FB, prop metal | `Costumes.STEEL = 0x9aa4b0` | Metal |
| BW hilt, prop grips | `Costumes.GRIP = 0x2a2a30` | SmoothPlastic |
| VB, VB·m | `colors.sig` | Glass, Transparency 0.35 |
| EP, HN, BK | `colors.skin` | SmoothPlastic |

---

## 3. Per-character specs (all 46)

### 3.0 Authoritative palette (`STYLE.colors`, `preset`, `height`)

Every player and character boss uses exactly these values. The six HumanoidDescription colours are:
- Head = `skin`
- Torso = `top`
- LeftArm and RightArm = `sleeves`
- LeftLeg and RightLeg = `bottom`

Patchwork is the one exception: it overrides single limbs through `STYLE.limbs`.

`trim` is the secondary cloth colour (§2.9). `sig` is a **colour**: it is used for the signature accent, the technique glow and the character-boss FaceGlow. The signature piece is the separate field `sigPiece` (§3, §6.1). `browAngle` is 0.25 unless a row gives another value.

**Shinobi Lands**

| Style | Preset | Height | skin | hair | brow | eye | top | sleeves | bottom | trim | sig |
|---|---|---|---|---|---|---|---|---|---|---|---|
| naruto, Ren Tsumuji | lean | 1 | `f3c9a0` | `3a2a24` | `3a2a24` | `5a7a4a` | `2f8f86` | `2f8f86` | `c9b48a` | `2b3350` | `e8b040` |
| sasuke, Kurobane | lean | 1.02 | `f7dcc0` | `151313` | `151313` | `3a3440` | `2a2a34` | `2a2a34` | `3a3f4a` | `3a3f4a` | `e0a83a` |
| kakashi, Hatsuyuki | standard | 1.04 | `f3d6b8` | `1a1f2e` | `1a1f2e` | `6a5a4a` | `223a44` | `4a5a6a` | `223a44` | `7a6a5a` | `5ad4ff` |
| itachi, Karasu | lean | 1.02 | `f0d8c0` | `14141c` | `14141c` | `3a3440` | `2a2233` | `2a2233` | `1e1a26` | `3a3440` | `7a8ad8` |
| might_guy, Midori Tetsu | standard | 1.04 | `e8b88a` | `14100c` | `14100c` | `2a2018` | `4a4f58` | `4a4f58` | `4a4f58` | `4f6b3a` | `3ad86a` |
| pain, Gravewell | standard | 1.02 | `e8d8c8` | `5a5a6a` | `5a5a6a` | `6a5a4a` | `2a2a36` | `2a2a36` | `1c1c26` | `5a5a70` | `8a6cff` |

**Sorcerer's Academy**

| Style | Preset | Height | skin | hair | brow | eye | top | sleeves | bottom | trim | sig |
|---|---|---|---|---|---|---|---|---|---|---|---|
| gojo, Aoi Hakumei | standard | 1.08 | `f3d6c0` | `2a3448` | `2a3448` | `6a5a8a` | `2a3550` | `2a3550` | `1f2740` | `e8ecf4` | `5ad4ff` |
| sukuna, Akuro | standard | 1.04 | `f2d6c6` | `2a1a1c` | `2a1a1c` | `c8782a` | `1c1a2a` | `1c1a2a` | `14121c` | `3a3450` | `e0a030` |
| yuji, Haru Takane | standard | 1 | `f3c9a0` | `c8a070` | `8a6a4a` | `8a4a2a` | `22283a` | `22283a` | `22283a` | `c8a03a` | `d8683a` |
| megumi, Kage Inukai | lean | 1 | `f7dcc0` | `1e2230` | `1e2230` | `5a8a7a` | `2a3238` | `2a3238` | `2a3238` | `2a2e3a` | `4a9a88` |
| toji, Zero | standard | 1.04 | `e8c8a0` | `141418` | `141418` | `4a5a4a` | `16161c` | `16161c` | `2a2a30` | `3a3a42` | `9fe870` |
| kashimo, Ikazuchi | lean | 1 | `f3d6b8` | `1e2230` | `1e2230` | `d8b84a` | `2e3a4a` | `2e3a4a` | `22262e` | `8a94a0` | `f0d27a` |
| geto, Hoshiro Genma | standard | 1.04 | `f3d6b8` | `2a1e2e` | `2a1e2e` | `6a4a7a` | `2a2030` | `2a2030` | `1a1622` | `8a7ab0` | `b06cff` |
| kenjaku, Nuime | standard | 1 | `e8d8c0` | `1a1a22` | `1a1a22` | `c89a6a` | `4a3a4a` | `4a3a4a` | `1a1622` | `2a2430` | `c89a6a` |
| choso, Akagane | standard | 1.02 | `f0d2b8` | `3a1a1a` | `3a1a1a` | `6a3a3a` | `2a1a20` | `2a1a20` | `1a1218` | `5a4a4a` | `9b1a2a` |
| mahito, Patchwork | lean | 1 | `d8c0a8` | `3a1e34` | `3a1e34` | `a8883a` | `5a4636` | L `8a6244` / R `d8c0a8` | L `4a5a3a` / R `6a3a4a` | `c8a878` | `5ae0a0` |
| jogo, Kazan | standard | 0.95 | `2a1a18` | `2a1a18` | `2a1a18` | `ff9a3a` | `4a3a34` | `4a3a34` | `2e2624` | `3a2a24` | `ff9a3a` |
| hanami, Thornbloom | standard | 1.1 | `6a5a44` | `3a2a1a` | `3a2a1a` | `e8c05a` | `4f6b3a` | `6a5a44` | `3f4a2a` | `5b4a3a` | `ff8ae0` |
| dagon, Tidehollow | heavy | 1.05 | `9ac8c0` | `9ac8c0` | `5a8a88` | `e8c85a` | `3a6a5a` | `9ac8c0` | `2a4a44` | `e8a07a` | `7ae0c8` |
| nanami, Overtime | standard | 1.08 | `f0d2ae` | `4a3a2a` | `4a3a2a` | `6a5a3a` | `3a3a42` | `3a3a42` | `3a3a42` | `e8e4dc` | `d8b46a` |
| nobara, Hammer Maiden | lean | 1 | `f3d6b8` | `4a2a3a` | `4a2a3a` | `6a4a3a` | `252c40` | `252c40` | `3a3438` | `6a5a4a` | `e8a04a` |
| toge, Kotodama | lean | 1 | `f3d6b8` | `2a2a34` | `2a2a34` | `6a7a8a` | `252c40` | `252c40` | `161a26` | `3a4258` | `2fb7a8` |
| maki, Rin Hoshigane | lean | 1.04 | `f0d2b0` | `5a2a24` | `5a2a24` | `6a4a3a` | `252c40` | `252c40` | `161a26` | `3a3f4a` | `d89a3a` |
| naoya, Framerate | lean | 1 | `f3d6b8` | `14161c` | `14161c` | `6a7488` | `1a1a24` | `1a1a24` | `14141c` | `3a4a5a` | `8ad0e0` |
| yuta, Rei Tsukiyo | lean | 1.02 | `f3d6b8` | `14141a` | `14141a` | `4a4a5a` | `3a3e4a` | `3a3e4a` | `22283a` | `6a7a9a` | `9fd6ff` |
| ishigori, Gankyu | heavy | 1.15 | `e0b088` | `3a2a1a` | `3a2a1a` | `6a4a2a` | `2a2a30` | `e0b088` | `2a2a30` | `5a5a64` | `ffd54a` |
| uro, Skyfold | standard | 1 | `f3d6b8` | `1a1a24` | `1a1a24` | `5a7a9a` | `4a5a7a` | `4a5a7a` | `2a2a36` | `e8c0a0` | `ffd8a0` |
| todo, Tetsuo Hakushu | heavy | 1.15 | `8a6244` | `14141c` | `14141c` | `2a2018` | `1b1b24` | `8a6244` | `1b1b24` | `c8a44a` | `d4142a` |
| hakari, Jackpot | standard | 1.06 | `f0d2b8` | `3a2e24` | `3a2e24` | `c8a86a` | `1a1a24` | `1a1a24` | `1a1a24` | `2f8a5a` | `ffd54a` |
| yuki, Supernova | standard | 1.02 | `f7dcc0` | `6a2a2a` | `6a2a2a` | `8a6a4a` | `2a2436` | `2a2436` | `2a2436` | `a88aff` | `a88aff` |

**Skyline City** (masked figures: `skin` is the mask/suit colour under FM; there is no red at any saturation above 0.5)

| Style | Preset | Height | skin | hair | brow | eye | top | sleeves | bottom | trim | sig |
|---|---|---|---|---|---|---|---|---|---|---|---|
| spiderman, Threadrunner | lean | 1 | `c89a70` | `2a2a30` | `2a2a30` | `2fb7a8` | `2a2f3a` | `2a2f3a` | `2a2f3a` | `3a4250` | `2fb7a8` |
| insomniac, Nightshift | lean | 1.02 | `14161e` | `14161e` | `14161e` | `ffb347` | `14161e` | `14161e` | `14161e` | `2a2e3a` | `ffb347` |
| miles, Voltstep | lean | 1 | `2a1f3a` | `2a1f3a` | `2a1f3a` | `ffe45c` | `2a1f3a` | `2a1f3a` | `2a1f3a` | `3a2f4a` | `ffe45c` |
| ironspider, Ironthread | standard | 1.04 | `4a4f58` | `4a4f58` | `4a4f58` | `6ad8c8` | `4a4f58` | `4a4f58` | `3a3f46` | `c87a3a` | `6ad8c8` |
| venom, Blackmaw | heavy | 1.15 | `0a0a10` | `0a0a10` | `0a0a10` | `b89aff` | `0a0a10` | `0a0a10` | `0a0a10` | `1a1a24` | `b89aff` |
| carnage, Redmaw | standard | 1.12 | `8a1a5a` | `8a1a5a` | `8a1a5a` | `ffb347` | `8a1a5a` | `8a1a5a` | `8a1a5a` | `3a0a2a` | `ffb347` |
| antivenom, Antidote | **lean** | **1.04** | `a8c4b0` | `a8c4b0` | `a8c4b0` | `4ae0c0` | `a8c4b0` | `24585a` | `24585a` | `d8ccb0` | `4ae0c0` |
| docock, Doctor Eightfold | standard | 1.05 | `e8c8a0` | `4a3a30` | `4a3a30` | `4a4a3a` | `5a4a6a` | `5a4a6a` | `2a2a34` | `b8a078` | `e89a4a` |
| winter, Frost Arm | standard | 1.06 | `e8c8a8` | `3a2e24` | `3a2e24` | `5a7a8a` | `22252c` | `22252c` | `16181d` | `2a2d34` | `9fe0ff` |
| ironman, Arc Knight | standard | 1 | `3a4250` | `3a4250` | `3a4250` | `5ad4ff` | `3a4250` | `3a4250` | `3a4250` | `e8e4dc` | `5ad4ff` |
| jean, Mindflare | lean | 1.02 | `f7dcc0` | `1e1a2a` | `1e1a2a` | `8a6ab0` | `3a2458` | `3a2458` | `2a1a40` | `e0c8ff` | `ff8ae0` |
| strange, Warden of Mirrors | standard | 1.04 | `f0d2b8` | `2a2a32` | `2a2a32` | `6a8a8a` | `1f3a3a` | `1f3a3a` | `14202a` | `2e2050` | `9fe0e8` |
| goblin, Cackler | standard | 1 | `e8e0c8` | `2a2a30` | `2a2a30` | `ffb347` | `c8642a` | `2a2a30` | `2a2a30` | `4a4f58` | `ffb347` |
| wolverine, Clawback | heavy | 1 | `e8b88a` | `2a2420` | `2a2420` | `3a5a3a` | `3a4a3a` | `4a5a3a` | `3a3a34` | `5a4a3a` | `c8d0d8` |

**Elsewhere**

| Style | Preset | Height | skin | hair | brow | eye | top | sleeves | bottom | trim | sig |
|---|---|---|---|---|---|---|---|---|---|---|---|
| eleven, Nosebleed | lean | 0.96 | `f3d6c0` | `2a2230` | `2a2230` | `5a6a5a` | `2f8f86` | `2f8f86` | `4a4a3a` | `e8c86a` | `b06cff` |
| tophat, Top Hat | lean | 1.02 | `e8d8c8` | `101010` | `101010` | `3a3a44` | `181818` | `181818` | `101010` | `e8e4dc` | `9b1a2a` |

**Human skin tones (`Costumes.SKIN_TONES`, explicit, human tones only).**

```lua
Costumes.SKIN_TONES = { 0xf3c9a0, 0xf7dcc0, 0xf3d6b8, 0xf3d6c0, 0xf0d8c0, 0xe8b88a, 0xe8d8c8, 0xf2d6c6, 0xe8c8a0, 0xe8d8c0,
                        0xf0d2b8, 0xd8c0a8, 0xf0d2ae, 0xf0d2b0, 0xe0b088, 0x8a6244, 0xc89a70, 0xe8c8a8, 0x5a3a28 }  -- 19
```

- These are the 18 human skin values in the tables above plus the darkest enemy variety tone (§4.4).
- **Not** in the list, and so always checked: every mask, suit and creature skin: `2a1a18` (Kazan), `6a5a44` (Thornbloom), `9ac8c0` (Tidehollow), `14161e`, `2a1f3a`, `4a4f58`, `0a0a10`, `8a1a5a`, `a8c4b0`, `3a4250`, `e8e0c8` (Skyline masks and suits).
- The exemption applies **only where the colour is used as skin**: the `skin` slot of an unmasked style, a bare-arm `sleeves` or `limbs` entry, and the bare-skin pieces FS, EP and BK. The same value used as cloth, trim or a tint is checked like any other colour.

**Trade-dress guard (`Costumes.TRADE_DRESS`, used by test 5b).** No effective colour may be within RGB distance 30 of a listed source colour. An entry marked *(hair)* applies only to hair, brow and HR·* / FLT / TIP tints. Exempt: skin uses of `SKIN_TONES` (above) and colours with HSV value below 0.3 (near-blacks). Rows marked **new** were added in revision 5. The guard also runs on the finale builders: Hyakunui against the mahito and kenjaku rows.

| Style | Source colours that must not reappear |
|---|---|
| naruto | `f66c2d`, `082c8c`, `e7e419` *(hair)* |
| sasuke | `e10000` |
| gojo | `f4f4ff` *(hair)*, `d8d8e8` *(hair)* |
| sukuna | `ff2d55`, `f7c6c6` *(hair)*, `e0a8a8` *(hair)* |
| yuji | `b52f36`, `ff8f9c` *(hair)* |
| kakashi | `c8ccd4`, `3f5a3a` |
| kashimo | `f5e6a0` *(hair)*, `dfe8ff` *(hair)*, `ffd54a` (the sash; extended in revision 5) |
| itachi | `b03a3a`, `d8232f` |
| might_guy | `2f8f3a`, `f66c2d` |
| pain | `f66c2d`, `b03a3a` |
| toge / nobara / maki / ishigori / hakari / yuki | `e8e8ee` / `c87a34` / `2b4a36` / `f0e08a` / `f2ecd8` / `f2d88a`, all *(hair)* |
| nanami | `d6cbb2`, `4a7a9a`, `d8c07a` *(hair)* |
| hanami | `8fbf6a` |
| spiderman | `d8323c`, `1f2f8f` |
| insomniac | `c8202c`, `1a2f7a`, `f0f4ff` |
| miles | `ff2d3a`, `d8202e` |
| ironspider | `b01824`, `8a1018`, `ffc83d` |
| venom | `f4f4f8`, `eceff4` |
| carnage | `8e0d1c`, `d4142a` |
| docock | `3f6a34`, `a8b2be`, `5a8f3a` |
| winter | `b8bec8` |
| ironman | `d4302a`, `ffc83d` |
| jean | `d94f1a`, `1f7a3a`, `ffd54a` |
| strange | `b02a2a`, `d4b04a`, `1e3a6a` |
| goblin | `4a9a3a`, `5aa83a`, `6a3ab0` |
| wolverine | `d8a83a`, `6a3a1a` |
| **mahito** (new) | `bacccf`, `25345a`, `d8e0d8`, `2a4a46`, `6cd8c0`, `6b6f6f`, `dcd3c9` *(hair)*, `b8bfc4` *(hair)*, `8fa8b8` *(hair)* |
| **antivenom** (new) | `e8eef4`, `dae2ea`, `eef2f6`, `dfe8f4`, `8fa0b0`, `f4f4f8` |
| **eleven** (new) | `f0e0d0`, `2a3a5a`, `c0392b`, `f0a8c0` (the pink dress), `6a4a2a` *(hair)* |
| **kenjaku** (new) | `3a4426`, `8aa84a` |
| **dagon** (new) | `bfe0f0`, `2a6a8a`, `6cd8ff`, `2f6fb5` *(hair)* |
| **jogo** (new) | `d88a4a`, `6a2a1a`, `ff6b3d` |
| **uro** (new) | `dcd8ce`, `8fa8c8` |

**Verbatim-copy check (test 5g, mechanical).** A hand list can miss rows, so test 5g also reads the source data *in the test only* (runtime never reads it, §2.7). For each style it gathers every colour field of `Characters[id]`, `Characters[id.."C"]`, `EnemyLooks["boss_"..id]`, `EnemyLooks[id.."_b"]` and `EnemyLooks[id]`. An effective colour *copies* a source colour when the RGB distance is under 8. Exempt: skin uses of `SKIN_TONES`, colours with HSV value below 0.25, and the §1.3 world constants (`Costumes.WORLD_CONST`: `2b3350 4f6b3a c9b48a e8e0d0 9aa4b0 1b1f2e 252c40 14141c c8a44a b06cff 9b1a2a 23262e 4a4f58 e8e4dc b8bec8 2f8f86 181818 3a0a14 c8b8b0 ff2d55`). **Pass**: at most 2 copies per style, and none of them in `top`, `sleeves`, `bottom`, `trim`, `hair` or `limbs`.

Revision 5 recoloured every style that failed 5g: Patchwork, Antidote and Nosebleed (the reviewer's items), plus Tidehollow, Kazan, Ikazuchi, Nuime, Framerate, Skyfold, Hammer Maiden, Kage Inukai, Jackpot, Supernova, Doctor Eightfold, Hatsuyuki, Akuro, Gravewell, Midori Tetsu, Rei, Top Hat and Redmaw (see the change list at the top). Single sig or eye matches that remain (for example Aoi's `5ad4ff` glow, Tetsuo's `d4142a` tape flash and Overtime's `d8b46a` watch) are within the 5g allowance and are not body colours. I ran the three checks (5b, 5g and the Skyline hue rules 5c–5e) with a script over the §3.0 tables, every explicit tint in §3 and §3.1, and Hyakunui, in both the `player` and `charBoss` roles. Result: 0 violations of 5b, 5c, 5d and 5e, and no style over the 5g limit.

### Kit rows (per style)

Format: kit in priority order (codes from §2.3 and §3.1) · explicit tints (everything else follows §2.9) · *signature* and `sigPiece` · **+N**, where +N is the parts added to the 16-part R15, counting FP (1). "Prop" means the §2.6 slot, counted at its largest prop.

#### Shinobi Lands (6)

| Style | Kit (priority order) | Explicit tints and marks | Signature (`sigPiece`) | +N |
|---|---|---|---|---|
| naruto, **Ren Tsumuji** | FP, HR, HR·s×2, HB + HB·t (cloth, no plate), SC (tail on the left), SB, EM buckle E1, GL×2 | HR·s `0x2f8f86`; HB `0x2b3350`; SC `0xe8b040`; **no face or cheek marks of any kind** (no lines, swirls or slashes) | *long amber scarf tail streaming left* (`SC`) | 1+1+2+3+2+1+1+2 = **13** |
| sasuke, **Kurobane** | FP, HR, HR·s×3, MT raven collar, FTH×2, BW sword across the upper back (2), SB | MT `0x151313`; FTH `0x3a3440` | *raven mantle with two upswept feathers; amber `0xe0a83a` irises only while a technique is active* (`MT`) | 1+1+3+1+2+2+1 = **11** |
| kakashi, **Hatsuyuki** | FP, HR, HR·w×2, VS winter coat, SB, GL×2 | HR·w `0x3a5a6a` (steel teal, not pale); VS `0x4a5a6a`; no mask of any kind; no eye cover | *cyan E7 ring lights on a SurfaceGui on the right GL while a copied technique is loaded* (`GL`) | 1+1+2+1+1+2 = **8** |
| itachi, **Karasu** | FP, HR (crop), HR·f (left), CP, MT crow mantle, FTH×2, CLP | CP `0x2a2233`; MT `0x14141c`; FTH `0x2a2233`; no collar, no ponytail, no clouds | *periwinkle `0x7a8ad8` clip in the forelock; grey-violet `ember` from the hands* (`CLP`) | 1+1+1+1+1+2+1 = **8** |
| might_guy, **Midori Tetsu** | FP, HR, HR·k topknot, SB + tail, GL×2, WR×2 | GL `0x8a3a2a`; WR `0xe8e0d0`; no bowl cut, no jumpsuit | *8 belt dots (SurfaceGui) light green one by one as gates open* (`SB`) | 1+1+1+2+2+2 = **9** |
| pain, **Gravewell** | FP, HR, HR·w×2, CP, HC, SHD×4 | CP `0x1c1c26`; no piercings, no ringed eyes, no rods | *4 basalt shards orbiting a ring behind the shoulders, joined into a square by 4 Beams `0x8a6cff`* (`SHD`) | 1+1+2+1+1+4 = **10** |

#### Sorcerer's Academy (24)

| Style | Kit (priority order) | Explicit tints and marks | Signature (`sigPiece`) | +N |
|---|---|---|---|---|
| gojo, **Aoi Hakumei** | FP, HR, HR·w×2 (side-swept, no spikes), OR×3, VS coat, LP, CT, GL left only | HR·w `0xbfe8ff` (pale shows only as two streaks); LP `0xe8ecf4`; resting iris `0x6a5a8a`; FaceGlow cyan `0x5ad4ff` only while `Infinity` is true; no VB, no eye cover, no high collar | *3 cyan shards orbiting the head* (`OR`) | 1+1+2+3+1+2+2+1 = **13** |
| sukuna, **Akuro** | FP, HR, HR·w×2 (swept back, no spikes), XA (4), VS crossover robe, SB + tail | HR·w amber `0xc8782a`; SB `0x3a3450`; one jagged amber crack `0xc8782a` from the left temple to the jaw (3 Frames); nothing under the eyes; iris amber `0xc8782a` | *second arm pair held forward, palms open* (`XA`) | 1+1+2+4+1+2 = **11** |
| yuji, **Haru Takane** | FP, HR, HD·d, HC, GL×2 knuckle tape, Prop (≤2) | HD·d mustard `0xc8a03a` with a crimson stitched-patch SurfaceGui (E11 border `0xe8e0d0` on a `0x9b1a2a` 60×40 patch, left side); GL `0xe8e0d0` | *crimson stitched patch on the hood* (`HD·d`) | 1+1+1+1+2+2 = **8** |
| megumi, **Kage Inukai** | FP, HR, HR·s×3, MT wolf pelt, EP ears on the mantle (2), HC | MT `0x2a2e3a`; EP `0x2a2e3a` at `NeckAttachment` (±0.55, 0.3, +0.2) | *`shadow` puddle at the feet; wolf-eared pelt* (`MT`) | 1+1+3+1+2+1 = **9** |
| toji, **Zero** | FP, HR, Prop (≤3), SB + 2 pouches, GL×2 fingerless | scar mark `0xc89a80` on the left brow (1 Frame 3×14 at 15°) | *back prop swaps with the Arsenal* (`Prop`) | 1+1+3+3+2 = **10** |
| kashimo, **Ikazuchi** | FP, HR, HR·p long (h 1.5), TIP, SB + tail, STF | TIP `0xf0d27a` | *`spark` at both staff tips; storm-gold hair tip* (`STF`) | 1+1+1+1+2+1 = **7** |
| geto, **Hoshiro Genma** | FP, HR, HR·p low tail (h 0.8), VS long open coat, LP, ORB | LP `0x8a7ab0`; lapel beads as SurfaceGui dots `0x8a7ab0`; no monk's sash, no bun, no gauged earrings | *floating violet orb* (`ORB`) | 1+1+1+1+2+1 = **7** |
| kenjaku, **Nuime** | FP, HR (crop), HR·p low tail, HC, CT robe skirt | HC `0x2a2430`; no marks on the face or neck; no bun | *cross-stitched right sleeve (SurfaceGui `0x2a2430` on RightUpperArm)* (`sigPiece = nil`, 0-part) | 1+1+1+1+2 = **6** |
| choso, **Akagane** | FP, HR, HR·w×1 (right, swept back), VS coat, GL×2 bracers, VL×2 | GL `0x5a4a4a`; crimson chevron `0x9b1a2a` on each cheek; no nose stripe, no tufts | *glowing blood vials at the wrists* (`VL`) | 1+1+1+1+2+2 = **8** |
| mahito, **Patchwork** | FP, HR, HR·p strand (h 0.9), FS fist + thumb (2), PLT×2, SEAM | `STYLE.limbs`: LeftArm `0x8a6244`, RightArm `0xd8c0a8`, LeftLeg `0x4a5a3a`, RightLeg `0x6a3a4a`; HR·p `0x3a1e34` (plum, via `colors.hair`); FS `0xd8c0a8`; neck seam E11 `0x3a1e34`; no pale or blue-grey skin, no pale hair, no face stitches | *quilted body with one giant fist* (`FS`) | 1+1+1+2+2+1 = **8** |
| jogo, **Kazan** | FP, CR rock crown (Basalt) + `smoke`, VS robe | CR `0x3a2a24`; lava-crack SurfaceGui `0xff9a3a` on the Head; ember FaceGlow; no volcano cone | *smoking rock crown* (`CR`) | 1+4+1 = **6** |
| hanami, **Thornbloom** | FP, HN branches, LF, VS bark, SG×2 bark, BLM | HN `0x5b4a3a`; VS and SG Wood `0x5b4a3a`; no growths from the eyes | *pink bloom on one shoulder* (`BLM`) | 1+2+1+1+2+1 = **8** |
| dagon, **Tidehollow** | FP, EP fin, MT coral shell, TSL×2 | EP `0x5a8a88`; MT `0xe8a07a` | *fin crest; `drip`* (`EP`) | 1+1+1+2 = **5** |
| nanami, **Overtime** | FP, HR, HC shirt collar, TIE, BLD, WCH | HC `0xe8e4dc`; no goggles, no beige suit, no patterned tie | *gold watch on the left wrist* (`WCH`) | 1+1+1+1+1+1 = **6** |
| nobara, **Hammer Maiden** | FP, HR, HR·p×2 bob panels (h 0.7, at x ±0.3 instead of a single centre panel, width 0.5), SB + nail pouch, HMR (2) | 3 nail heads on the pouch SurfaceGui `0x9aa4b0`, tips glow `0xe8a04a` when charged | *hammer on the back hip, glowing nails* (`HMR`) | 1+1+2+2+2 = **8** |
| toge, **Kotodama** | FP, HR, HR·w streak, CK with speaker-grille SurfaceGui, VS | HR·w `0x2fb7a8`; mouth uncovered; no face seal | *grille flashes `0x2fb7a8` on every command* (`CK`) | 1+1+1+1+1 = **5** |
| maki, **Rin Hoshigane** | FP, HR, HR·p ponytail (h 1.1), VB amber, SG left, Prop (≤3), GL×2 | VB `0xd89a3a`; no glasses | *back prop swaps with the Arsenal* (`Prop`) | 1+1+1+1+1+3+2 = **10** |
| naoya, **Framerate** | FP, HR, HR·p×2 (h 0.9, x ±0.3, width 0.5), SC, SB | HR·p `0x14161c` with slate tip bands (SurfaceGui, lower 20%) `0x6a8a9a`; SC tail E8 `0x8ad0e0` | *film-strip scarf* (`SC`) | 1+1+2+2+1 = **7** |
| yuta, **Rei Tsukiyo** | FP, HR, HR·s×2, BW katana (2), HC, WSP | HC `0x6a7a9a` trim edge; no white uniform | *wisp companion* (`WSP`) | 1+1+2+2+1+1 = **8** |
| ishigori, **Gankyu** | FP, HR, FLT, VS sleeveless, CN + MZ (2), GL×2 | no pompadour, no pale hair | *right-shoulder cannon* (`CN`) | 1+1+1+1+2+2 = **8** |
| uro, **Skyfold** | FP, HR, HR·p (h 1.2), MT shawl, EDG, SB | MT `0xe8c0a0` (apricot dusk cloud); no pale robe | *folded dusk-cloud shawl with a glowing dawn hem* (`MT`) | 1+1+1+1+1+1 = **6** |
| todo, **Tetsuo Hakushu** | FP, HR (shaved sides: cap scaled to X 1.1), HR·w crest (single, centred at x 0, `rx(+15)` only), EC right ear, VS open jacket, GL×2 palm tape | EC gold `0xc8a44a`; GL `0xe8e0d0`; no topknot, no scar | *palm tape flashes `0xd4142a` on a swap; gold ear cuff* (`EC`) | 1+1+1+1+1+2 = **7** |
| hakari, **Jackpot** | FP, HR, HR·w×2 undercut, HC, CP short (1.9×1.4), EM reel window (3 SurfaceGui digits) | HC felt green `0x2f8a5a`; CP `0x14141c`; no gold collar | *chest reels roll during the domain* (`EM`) | 1+1+2+1+1+1 = **7** |
| yuki, **Supernova** | FP, HR, HR·p long (h 1.5), VS biker jacket, SC, EM E10 on the back, GL×2 | SC periwinkle `0xa88aff`; no blonde hair, no orange | *star-flare on the jacket back* (`EM`) | 1+1+1+1+2+1+2 = **9** |

#### Skyline City (14)

Masked figures keep FP for marks and mouth hiding. Their eyes are hidden, and lenses or slits act as the eyes. HR is skipped under FM or HD.

| Style | Kit (priority order) | Explicit tints and marks | Signature (`sigPiece`) | +N |
|---|---|---|---|---|
| spiderman, **Threadrunner** | FP (eyes hidden), HD (up), LM, GG round goggles, [TN×2 while `Suit > 0`], EM E2, SPL×2 (the spools *are* the gloves; no GL) | HD and LM `0x3a4250`; GG Neon `0x2fb7a8`; teal panels `0x2fb7a8` on the torso front and forearms (SurfaceGui); the head shows only skin `0xc89a70` between hood and LM; no white, no red, no amber, no spider or web marks | *hooded parkour runner with teal goggles and wrist spools* (`GG`) | 1+3+1+2+1+2 = **10** (12 with the suit) |
| insomniac, **Nightshift** | FP, FM (one slit), 4 SM seams, EM E2 | FM slit and seams `0xffb347` | *single amber slit plus amber seams, the 60-stud discriminator from Threadrunner* (`FM`) | 1+2+4+1 = **8** |
| miles, **Voltstep** | FP, FM (one slit), HD (up), WR×2 sneakers | FM slit and WR `0xffe45c`; zigzag SurfaceGui seams `0xffe45c` on the arms; no red, no white lenses | *hood plus electric sneakers* (`WR`) | 1+2+3+2 = **8** |
| ironspider, **Ironthread** | FP, FM (2 lens Blocks), BA×4 (2 segments each, 1.4 + 1.4, Ø0.22), SG×2 | lenses `0x6ad8c8`; BA copper `0xc87a3a` Metal | *four copper back legs* (`BA`) | 1+3+8+2 = **14** |
| venom, **Blackmaw** | FP, FM (one slit), SG×2 bulky, TN×2 | slit `0xb89aff`; Reflectance 0.15 on the R15; chest maw (§2.4) with teeth `0xd8d0e8`; no teardrop eyes, no white | *maw across the chest* (`sigPiece = nil`, 0-part SurfaceGui) | 1+2+2+2 = **7** |
| carnage, **Redmaw** | FP, FM (one slit), FB×2 bone spurs, TN×3 | slit `0xffb347`; FB `0xd8ccb8` SmoothPlastic; vein SurfaceGui `0x3a0a2a`; chest maw with jagged fangs `0xd8ccb8` (§2.4) | *bone spurs plus three tendrils* (`FB`) | 1+2+2+3 = **8** |
| antivenom, **Antidote** | FP, FM (one slit), EM E5 droplet, SG×2 | celadon `0xa8c4b0` head and torso, deep-teal `0x24585a` arms and legs (a two-tone field-medic suit, `lean`, not a heavy build); slit and E5 stroke `0x4ae0c0`; vein SurfaceGui `0x24585a` on the celadon torso; SG bone `0xd8ccb0` SmoothPlastic; EM plate `0xd8ccb0`; no white or near-white anywhere (every colour has value ≤ 0.85 or saturation ≥ 0.15), no black, no teardrop eyes, no chest maw | *bone pauldrons over a two-tone medic suit, mint droplet emblem* (`EM`) | 1+2+1+2 = **6** |
| docock, **Doctor Eightfold** | FP, HR, BA×4, each arm 3 parts: seg 1 Cyl Ø0.22×1.4, seg 2 Cyl Ø0.2×0.9, claw Wedge 0.2×0.5×0.25 (Neon) | BA brass `0xb8a078` Metal; claw `0xe89a4a`; no green anywhere, no glasses, no monocle, no trench coat, no bowl cut | *four brass arms with glowing amber claw tips* (`BA`) | 1+1+12 = **14** |
| winter, **Frost Arm** | FP, HR crop, GG pushed up (2), MA right + frost seam, VS, SB + pouch | GG frames `0x2a2d34`, lenses `0x9fe0ff`; MA gunmetal `0x4a4f58` Metal (not silver), seam `0x9fe0ff`; no lower mask, no long hair, no star | *frosted right arm* (`MA`) | 1+1+2+1+1+2 = **8** |
| ironman, **Arc Knight** | FP, FM helmet (one slit), CO diamond, SG×2, GL×2 palm-Neon gauntlets, Prop (≤2, warmachine) | slit and CO `0x5ad4ff`; SG ivory `0xe8e4dc`; GL `0x3a4250` with a Ø40 px palm circle `0x5ad4ff` on a FaceGlow-style SurfaceGui (Bottom face, LightInfluence 0); suit keys per §2.6; no red and gold, no round reactor | *diamond chest core* (`CO`) | 1+2+1+2+2+2 = **10** |
| jean, **Mindflare** | FP, HR, HR·p (h 1.2), VS, CRY×3 | VS trim SurfaceGui `0xe0c8ff`; no red hair, no green and gold, no firebird | *psionic shard halo* (`CRY`) | 1+1+1+1+3 = **7** |
| strange, **Warden of Mirrors** | FP, HD (up), MT hooded mantle, SB, EM mirror-shard pendant (Glass diamond, Reflectance 0.5) | HD and MT `0x2e2050`; SB `0x3a3048`; EM `0x9fe0e8`; no silver temples, no high collar, no cape, no red, no gold | *mirror pendant* (`EM`) | 1+3+1+1+1 = **7** |
| goblin, **Cackler** | FP, FM bone + 2 round lenses, BK beak, WG glider disc (2 Neon SurfaceGui dots `0xffb347`), GL×2 | FM `0xe8e0c8`; lenses Glass `0xffb347`; BK `0xe8e0c8`; WG `0x4a4f58` Metal; torso rust `0xc8642a`, limbs charcoal `0x2a2a30`; no green or chartreuse, no grin, no long ears, no hood, no purple | *beaked plague-mask on a glider* (`BK`) | 1+3+1+1+2 = **8** |
| wolverine, **Clawback** | FP, HR short crop (no side flares), HD·d parka hood, VS olive field parka, GL×2 bracers, FB×2 long curved (one per arm) | HD·d and VS `0x4a5a3a`; FB `0xc8d0d8`; height 1.0 (no short stature), preset head; no stubble, no leather jacket, no yellow, no cowl | *single long curved bracer blade per arm* (`FB`) | 1+1+1+1+2+2 = **8** |

#### Elsewhere (2)

| Style | Kit (priority order) | Explicit tints and marks | Signature (`sigPiece`) | +N |
|---|---|---|---|---|
| eleven, **Nosebleed** | FP, HR, HR·p shoulder length (h 0.9), HP headphones (2 cups + Beam band), VS windbreaker | HP `0x2a2a30`; VS mustard stripe SurfaceGui `0xe8c86a`; bottom olive-grey `0x4a4a3a`; **no face marks at all** (no nosebleed or any mark under the nose, in any phase); no buzzcut, no pink, no off-white top | *headphones; violet `0xb06cff` glow during techniques* (`HP`) | 1+1+1+2+1 = **6** |
| tophat, **Top Hat** | FP, HAT (brim, crown, band), HC, CT tailcoat, Prop (≤3), GL×2 white | HAT brim and crown `0x101010`, band `0x9b1a2a`; HC and GL ivory `0xe8e4dc` | *top hat with a crimson band* (`HAT`) | 1+3+1+2+3+2 = **12** |

### 3.1 Bespoke pieces

Every piece in §3 that is not a standard §2.3 code is placed here. "Part centre" means no attachment, and the offset is from the host's centre. Every piece is nominal (relative scaling) unless it says `absolute`.

| Code | Style | Shape and size | Host | Attachment | C0 (after the attachment) | Tint / material | Parts |
|---|---|---|---|---|---|---|---|
| HAT·b | Top Hat | brim Cyl Ø1.55×0.08 | Head | part centre | `CFrame.new(0, 0.64, 0) * CYL_UP` (spans y 0.60–0.68, resting on the head top) | `0x101010` | 1 |
| HAT·c | Top Hat | crown Cyl Ø0.95×1.0 | Head | part centre | `CFrame.new(0, 1.14, 0) * CYL_UP` (y 0.64–1.64) | `0x101010` | 1 |
| HAT·n | Top Hat | band Cyl Ø0.97×0.15 | Head | part centre | `CFrame.new(0, 0.72, 0) * CYL_UP` (y 0.645–0.795) | `0x9b1a2a` | 1 |
| FTH | Kurobane, Karasu | 2 Wedges 0.1×0.6×0.25 | UpperTorso | `NeckAttachment` | `CFrame.new(±0.45, 0.25, +0.45) * rx(+20) * rz(∓15)`: tops lean back and out, bottoms 0.14 inside the mantle (mantle top at that x, z is y +0.09) | per row | 2 |
| CLP | Karasu | Wedge 0.08×0.25×0.12 | Head | part centre | `CFrame.new(−0.44, 0.22, −0.67)` (in front of HR·f, x −0.48 to −0.40) | `0x7a8ad8` | 1 |
| LF | Thornbloom | Wedge 0.1×0.4×0.3 | Head | part centre | `CFrame.new(0.56, 0.92, 0) * rz(−40)` (at the tip of the right HN branch, whose top end is (0.50, 0.88, 0)) | `0x4f6b3a` | 1 |
| BLM | Thornbloom | Ball Ø0.45 | LeftUpperArm | `LeftShoulderAttachment` | `CFrame.new(−0.05, 0.38, 0)` (bottom 0.12 inside the bark SG) | `0xff8ae0` SmoothPlastic | 1 |
| ORB | Genma | Ball Ø0.5 | UpperTorso | part centre | rest `CFrame.new(−1.3, 1.3, +0.4)`; Weld `Orbit_orb`, OrbitAxis (0,1,0), **OrbitCenter (−1.1, 1.3, +0.4)** (a 0.2 circle), OrbitRate 0.6 | `0xb06cff` Neon | 1 |
| WSP | Rei | Ball Ø0.5 + `wind` | UpperTorso | part centre | rest `CFrame.new(+1.2, 1.2, +0.7)`; Weld `Orbit_wisp`, OrbitAxis (0,1,0), **OrbitCenter (+1.0, 1.2, +0.7)**, OrbitRate 0.6, OrbitPhase 0.5 | `0x9fd6ff` Neon | 1 |
| SHD | Gravewell | 4 CornerWedges 0.35×0.6×0.35, Basalt, violet Neon-edge SurfaceGui `0x8a6cff` | UpperTorso | part centre | rest `CFrame.new(0, 0.4, 1.1) * rz(90i) * CFrame.new(0, 0.9, 0)`, i = 0..3; Welds `Orbit_i`, OrbitAxis (0,0,1), **OrbitCenter (0, 0.4, +1.1)**, OrbitRate 0.15. The ring spans z 0.925–1.275, clear of the torso back (0.5) and of the cape (z ≤ 0.8 at y −0.5). 4 Beams join adjacent shards. | `0x2a2a30` | 4 |
| VL | Akagane | 2 Cyl Ø0.14×0.4 | Left / RightLowerArm | part centre | `CFrame.new(∓0.61, −0.28, 0) * CYL_UP` (on the outer face of GL, whose outer face is at ±0.54) | `0x9b1a2a` Neon | 2 |
| TIE | Overtime | Block 0.25×0.9×0.05 + diagonal-stripe SurfaceGui (3 bars `0x8a6a4a` at 30°) | UpperTorso | part centre | `CFrame.new(0, 0.17, −0.53)` (y −0.28 to 0.62, just under the collar bottom at 0.675) | `0x6a4a2a` | 1 |
| WCH | Overtime | Cyl Ø0.3×0.08 (no rotation: the face points −X, outward) | LeftLowerArm | part centre | `CFrame.new(−0.54, −0.4, 0)` | `0xd8b46a` Metal | 1 |
| BLD | Overtime | Block 0.14×2.0×0.35, bare blade with a grip-wrap SurfaceGui on the lower quarter (3 bands `0x3a3a42`); no cloth wrapping, no pattern | UpperTorso | `BodyBackAttachment` | `CFrame.new(0, 0, +0.12) * rz(35)` | `0x9aa4b0` Metal | 1 |
| HMR·s | Hammer Maiden | handle Cyl Ø0.1×1.1 | LowerTorso | part centre | `CFrame.new(0.45, −0.1, 0.6) * rz(20) * CYL_UP` (z 0.55–0.65, clear of the back face at 0.5) | `0x5a4a3a` Wood | 1 |
| HMR·h | Hammer Maiden | head Block 0.5×0.3×0.3 | LowerTorso | part centre | `CFrame.new(0.45, −0.1, 0.6) * rz(20) * CFrame.new(0, 0.65, 0.05)` (the head's centre lands at (0.23, 0.51, 0.65)) | `0x9aa4b0` Metal | 1 |
| FLT | Gankyu | Block 1.1×0.3×1.1 | Head | part centre | `CFrame.new(0, 0.75, +0.06)` (y 0.60–0.90; wider than the cap's 0.97 cross-section at y 0.6, so it reads flat) | `colors.hair` | 1 |
| CN | Gankyu | Cyl Ø0.7×1.6 | UpperTorso | part centre | `CFrame.new(1.0, 1.15, +0.1) * CYL_FWD` (x 0.65–1.35 clears the head at 0.6; the bottom rests on the shoulder at y 0.8) | `0x4a4f58` Metal | 1 |
| MZ | Gankyu | Cyl Ø0.6×0.1 | UpperTorso | part centre | `CFrame.new(1.0, 1.15, −0.75) * CYL_FWD` | `0xffd54a` Neon | 1 |
| STF | Ikazuchi | Cyl Ø0.16×5.0; Attachments at the part's local (±2.5, 0, 0) carry `spark` | UpperTorso | `BodyBackAttachment` | `CFrame.new(0, −0.2, +0.2) * rz(35) * CYL_UP` | `0x4a3a2a` Wood | 1 |
| TIP | Ikazuchi | Block 1.08×0.3×0.32 | Head | part centre | `CFrame.new(0, −1.15, +0.62)` (below the long HR·p, whose bottom is at y −1.0) | `0xf0d27a` | 1 |
| PLT | Patchwork | 2 Blocks 0.9×0.25×1.0, E11 edge SurfaceGui `0x3a1e34` on Top | Left / RightUpperArm | `L/RShoulderAttachment` | `CFrame.new(∓0.05, 0.12, 0) * rz(±15)` | L `0xd8c0a8`, R `0x8a6244` | 2 |
| SEAM | Patchwork | Block 0.08×1.4×0.05 | UpperTorso | part centre | `CFrame.new(0.2, −0.05, −0.53)` | `0x5ae0a0` Neon | 1 |
| TSL | Tidehollow | 2 Cyl Ø0.12×0.9 | LowerTorso | `WaistFrontAttachment` | `CFrame.new(±0.35, −0.5, −0.05) * CYL_UP` | `0xe8a07a` | 2 |
| EDG | Skyfold | Block 1.3×0.06×0.06 | UpperTorso | `NeckAttachment` | `CFrame.new(0, −0.15, −0.67)` (along the shawl's front equator; the ends stand 0.07 proud) | `0xffd8a0` Neon | 1 |
| CRY | Mindflare | 3 Wedges 0.12×0.4×0.2 | Head | part centre | rest `ry(120k) * CFrame.new(0, 0.6, −0.9)`; Welds `Orbit_k`, OrbitAxis (0,1,0), centre (0,0,0), OrbitRate 0.2 | `0xff8ae0` Neon | 3 |
| SPL | Threadrunner | 2 Cyl Ø0.3×0.5 | Left / RightLowerArm | part centre | `CFrame.new(∓0.56, −0.25, 0) * CYL_UP` (outer forearm) | `0x3a4250` with a teal SurfaceGui ring `0x2fb7a8` | 2 |
| SM | Nightshift | 4 Blocks 0.06×1.0×0.06 | Left / RightLowerArm, Left / RightLowerLeg | part centre | `CFrame.new(∓0.52, 0, 0)` (outer side) | `0xffb347` Neon | 4 |
| WG | Cackler | disc Cyl Ø2.2×0.12 | UpperTorso | `BodyBackAttachment` | rest `CFrame.new(0, 0.1, +0.2) * CYL_FWD` (flat on the back, z 0.64–0.76 from the torso centre). During Glider Ram the `Glide` driver moves it under the feet (§2.1). | `0x4a4f58` Metal | 1 |
| HP | Nosebleed | §2.3 HP | Head | part centre | cups `CFrame.new(±0.64, 0.02, +0.05)`; Beam band per §2.3 | `0x2a2a30` | 2 |
| BA/claw | Eightfold | seg 1 Cyl Ø0.22×1.4, seg 2 Cyl Ø0.2×0.9, claw Wedge 0.2×0.5×0.25 | UpperTorso | `BodyBackAttachment` | chain rule (§2.1) with the §2.3 BA `base`, `rot_1`, `rot_2 = rz(40·sx)` and `rot_3 = identity`: `C0_1 = bone_1 * CYL_UP`, `C0_2 = bone_2 * CYL_UP`, `C0_3 = bone_3` | segs `0xb8a078` Metal, claw `0xe89a4a` Neon | 12 |
| GR·e | grey (enemy) | 2 Ell 0.36×0.2×0.1 | Head | part centre | `CFrame.new(±0.22, 0.08, −0.58) * rz(±18)` (outer corners up) | `0x101014` Glass, Reflectance 0.3 | 2 |
| UB·p | Unbidden | 2 Blocks 0.9×0.8×0.1 with a trim SurfaceGui (UIStroke 4 px) | UpperTorso | part centre | `CFrame.new(±0.5, 0.2, −0.55)` | `0xc8c2b8` | 2 |
| UB·d | Unbidden | 2 Ell 1.2×0.7×1.2 | Left / RightUpperArm | `L/RShoulderAttachment` | `CFrame.new(∓0.15, 0.1, 0)` (outward, clear of the collar ring) | `0xd9d4cc` | 2 |
| UB·t | Unbidden | 8 Blocks 0.42×0.3×0.14 | UpperTorso | `NeckAttachment` | `ry(45(i−1)) * CFrame.new(0, 0.12, −0.62) * rx(−20)`, i = 1..8 in `ADAPT_ORDER` (§5.3) | `0x8a8680` until adapted | 8 |
| HY·p, HY·s, HY·n | Hyakunui | §5.1 | UpperTorso | part centre | §5.1 | §5.1 | — |

---

## 4. Enemies

### 4.1 Palette capture and darkening

`Costumes.palette(template, affix, enemyEntry)` returns `{base, nature, affix}`.

- `base = enemyEntry.variant.color or template.color or NATURE[template.nature].color`. It is computed **before** `applyAffix` and stored as `e.pal` (§6.2).
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
- **B** = body width in studs = `SHAPES[shape].size.X × STUDS(2.4) × 0.55 × t.size`. B already includes `t.size`, so every toad, blob, wraith and UFO piece mounts with `absolute = true`. Golem and imp pieces are nominal studs on visible R15 parts and mount with `absolute = false` (§2.1).
- Pieces weld to LowerTorso unless stated otherwise, so the float bob and hop move them. Pieces described "on the body" are hosted on the main body piece.
- **Gait legs** are `Gait_*` welds (§2.1):
  - pivot at the leg's top
  - `GaitAmp` 22°, `S = B`
- **Tier** column: W weak point, R read, L limb, D decoration (§2.1). Variants' replacement pieces take the tier of what they replace, unless the variant says otherwise.

**Toad** (hidden: all; weak point: warts) **+14**

| Piece | Tier | Parts |
|---|---|---|
| Neon wart cluster Ball Ø0.18B on the body at (+0.2B, 0.3B, +0.15B) | W | 1 |
| Body Ell 1.0×0.75×1.0·B, bottom at ground + 0.3 | R | 1 |
| 2 eye domes Ball Ø0.34B on the body at (±0.25B, 0.3B, −0.3B) | R | 2 |
| 2 Neon slit pupils Block 0.04×0.2×0.02·B on the domes' fronts, FaceGlow colour | R | 2 |
| 2 hind pads Block 0.35×0.08×0.5·B: welds `Gait_HL/HR`, pivot (±0.4B, 0, +0.3B), phase 0.5 | L | 2 |
| 2 front paws Block 0.3×0.3×0.35·B at z −0.4B, bottom at ground: welds `Gait_FL/FR`, pivot (±0.35B, −0.1B, −0.35B), phase 0 | L | 2 |
| Mouth Block 0.9B×0.08×0.1 | D | 1 |
| 2 haunches Ell 0.45×0.4×0.55·B at (±0.45B, −0.1B, +0.3B), static | D | 2 |
| Extra wart Ball Ø0.14B on the body at (−0.25B, 0.25B, +0.25B) | D | 1 |

- **Hop**: while moving, the client adds a 0.25-stud sine hop to `LowerTorso.Root.C0` at the stride frequency.

**Blob** (hidden: all; weak point: core seen through the jelly) **+11**

| Piece | Tier | Parts |
|---|---|---|
| Neon core Ball Ø0.55B | W | 1 |
| Outer jelly Ell (SHAPES size × 2.4 × 0.55 × t.size), SmoothPlastic, Transparency 0.35 | R | 1 |
| Eye: white Ball Ø0.4B + iris Ball Ø0.22B + pupil Ball Ø0.1B | R | 3 |
| 2 tendrils Cyl Ø0.12B×0.6B on UpperTorso: welds `Gait_TL/TR`, GaitAmp 15° | L | 2 |
| Mouth Block 0.5B×0.06×0.05 | D | 1 |
| 3 drips Ball Ø0.15B | D | 3 |

**Wraith** (hidden: all; weak point: eyes) **+12**

| Piece | Tier | Parts |
|---|---|---|
| 2 Neon slit eyes | W | 2 |
| Hood Ell 1.0×1.2×1.0·B | R | 1 |
| Hood peak Wedge 0.3×0.5×0.4·B | R | 1 |
| Recessed black face-void Ell 0.6×0.7×0.3·B | R | 1 |
| 2 tail Ell 0.7×1.0×0.7·B and 0.45×0.8×0.45·B, trailing −Y+Z | R | 2 |
| 2 claw Wedges 0.1×0.5×0.3·B on UpperTorso (±0.6B, −0.3B, −0.3B), static | L | 2 |
| 3 hem Wedges 0.3×0.5×0.1·B | D | 3 |

- `wind` emitter on the tail tip.

**Golem** (shown: all R15, `heavy`, Slate via paintParts; weak point: chest crack; nominal) **+11**

| Piece | Tier | Parts |
|---|---|---|
| Neon core Block 0.12×1.0×0.1 in the chest gap, UpperTorso (0, 0.1, −0.62) | W | 1 |
| 2 chest Wedges 1.0×1.5×0.6 with a 0.15 gap, UpperTorso (±0.575, 0.05, −0.3) | R | 2 |
| Eye band Neon Block 0.9×0.12×0.05, FaceFront (0, 0.12, −0.03) | R | 1 |
| Brow Wedge 1.2×0.3×0.4, Head (0, 0.3, −0.5) | R | 1 |
| 2 back shards Wedge 0.3×1.0×0.4, UpperTorso (±0.4, 0.5, +0.65) | R | 2 |
| 2 gauntlets Block 1.4× LowerArm | L | 2 |
| 2 shoulder boulders Ball Ø1.3 at `L/RShoulderAttachment` (∓0.1, 0.2, 0) | D | 2 |

**Imp** (shown: all R15, `small`; weak point: grin; nominal) **+11**

| Piece | Tier | Parts |
|---|---|---|
| FP with a glowing grin on FaceGlow | 0 (W) | 1 |
| 2 horns HN | R | 2 |
| 2 Neon eye Balls Ø0.2 at FaceFront (±0.24, 0.12, −0.05) | R | 2 |
| Belly Ell 1.3×1.0×1.1 on UpperTorso (0, −0.2, −0.1) | R | 1 |
| Tail: 2 Cyl Ø0.12×0.8 + spade Wedge 0.1×0.35×0.35 on `WaistBack`, chained (§2.1) | L | 3 |
| 2 wing Wedges 0.1×1.2×0.9 at `BodyBack` (±0.4, 0.3, +0.1) `rz(∓30)` | D | 2 |

**UFO** (hidden: all; weak point: ring; all sizes × `t.size` (1.6); absolute) **+8**

| Piece | Tier | Parts |
|---|---|---|
| Underside Neon ring Cyl Ø2.4×0.2 `CYL_UP` | W | 1 |
| Saucer Cyl Ø4.2×0.6 `CYL_UP`, 1.5 above the hidden root | R | 1 |
| Dome Ball Ø1.8 Glass | R | 1 |
| 4 rim Neon Balls Ø0.3 | D | 4 |
| SD (a marker; §4.5) | 1 | 1 |

- 1 SpotLight pointing down: range 16, brightness 1.

**Floaters** (`float=true`): grade4, larva, wind_spirit, storm_wraith, bat_curse, smoke_curse, sand_spirit, mist_leech, crow_swarm, mirror_fiend, goblin_drone.
- They get SD (+1 part, tier 1). On an elite, SD becomes the affix ring (Neon, `affix.color`, Transparency 0.35), so floaters never pay for both.
- **Bob**: the client tweens `LowerTorso.Root.C0` by ±0.3 studs over a 1.6 s sine. SD sits on the HRP, so it stays on the ground.

**Worst case for test 3** (W + R + the 3 largest markers ≤ 14):

| Case | W + R | Markers | Total |
|---|---|---|---|
| toad | 6 | 3 | 9 |
| blob | 5 | 3 | 8 |
| wraith | 7 | 3 | 10 |
| bat_curse | 11 | 3 | 14 |
| golem | 7 | 3 | 10 |
| finger_bearer | 10 | 3 | 13 |
| imp | 6 | 3 | 9 |
| needle_curse | 10 | 3 | 13 |
| larva | 8 | 3 | 11 |
| ufo | 3 | 3 | 6 |

### 4.3 Per-enemy variants

Colours come from `pal.base`. Part counts are recounted and covered by test 2.

| Enemy | Shape | Variant | Parts |
|---|---|---|---|
| cursed_toad | toad | mottled `0x3f7a6a`, warts `0x5aa9ff`; the extra wart becomes a pink `0xe88aa0` tongue Wedge (D) | 14 |
| grade4 | blob | muddy `0xc9a068`, no tendrils (−2), float + SD (+1) | 10 |
| larva | blob | grub: 3 Balls Ø0.6/0.5/0.4 B (R) replace the jelly and core; 2 mandible Wedges (R); the eye (3) is the weak point (W); SD | 3+2+3+1 = 9 |
| cursed_womb | blob | `0x8a2a4a`; curled core (2 Balls, W) replaces the core; client pulses core Transparency | 12 |
| mist_leech | blob | funnel mouth Cyl `CYL_FWD` (R) replaces the mouth; `smoke`; SD | 12 |
| slot_curse | blob | gold `0xd8b84a` jelly; 3-reel face SurfaceGui on an FP (R) replaces the eye (−3 +1); `coin` | 9 |
| wind_spirit | wraith | `0x8fe3c9`, `wind`, SD | 13 |
| storm_wraith | wraith | 2 yellow `0xffe45c` Neon crackle Blocks (R) replace 2 hem pieces; `spark`; SD | 13 |
| bat_curse | wraith | 2 membrane wings + 2 ear Wedges (R) replace the 3 hem pieces; SD | 14 |
| smoke_curse | wraith | Transparency 0.3, `smoke`; eyes become 1 lantern Ball (W, −1); SD | 12 |
| sand_spirit | wraith | Sand; bone `0xd8ccb8` face plate Block with eye-hole SurfaceGui (R) replaces the void; SD | 13 |
| crow_swarm | wraith | 3 crows (Ball + beak Wedge each, 6) replace the body; the lead crow's Ball is W, the rest R; `feather`; SD | 7 |
| mirror_fiend | wraith | Reflectance 0.5; 3 shard Wedges (R) replace the hem; SD | 13 |
| ember_imp | imp | CrackedLava skin; `ember` on the spade | 11 |
| needle_curse | imp | 4 back needles Cyl Ø0.08×1.2 (R) replace the wings | 13 |
| rush_curse | imp | ram horns (CornerWedges, forward); lean `RootJoint.C0 * rx(12)` | 11 |
| spine_curse | imp | bone `0xd8ccb8`; 4-block vertebra row (R) replaces the wings | 13 |
| goblin_drone | imp | `variant.color = 0xc8642a` rust with charcoal `0x2a2a30` and amber `0xffb347` eyes (not data green); BK beak (R, +1, grin hidden, FP kept); hover disc Cyl Ø1.4×0.1 under the feet (R, +1) replaces the wings (−2); SD (+1) | 11+1−2+1+1 = **12** |
| stone_brute | golem | Slate; 2 moss Wedges `0x4f6b3a` replace the shards | 11 |
| finger_bearer | golem | fleshy `0x8a5a6a` SmoothPlastic; 5 back finger Cylinders (R) replace the shards | 14 |
| iron_curse | golem | DiamondPlate `0x6a7280`; rivet SurfaceGui | 11 |
| tomb_guardian | golem | Sandstone; gold face plate `0xc8a44a` with E7 (R) replaces the brow | 11 |
| mass_curse | golem | `0xff8a2a`; anvil head Block (R) replaces the brow; waist weight (R) replaces 1 shard | 11 |
| ufo | ufo | §4.2 | 8 |

### 4.4 Human enemies

**Id resolution**
- `Costumes.baseId(id) = id:gsub("_alpha$", "")`. Look, faction and grade come from the base id.
- `akatsuki_nin(_alpha)` and `gate_monk(_alpha)` get their looks from `Costumes.ENEMY`.
- Human enemies are the **only** figures that read `EnemyLooks` colours and flags (§2.7).

**Grade ladder**
- Uses the base template's grade. Alphas are grade `special` in data, but they use their base's ladder plus the crest.
- Counts include FP. Tier in brackets.

| Grade | Adds (priority order) | Costume | Total |
|---|---|---|---|
| 4 | FP [0], HR cap [R] + 1 spike or panel [R] | 3 | 19 |
| 3 | + faction piece (HB, HC or VS) [R] | 4 | 20 |
| 2 | + SG on one side [R], + LM or SC wrap [R] | 6 | 22 |
| 1 | + CT (2) [D], + GL×2 [D] | 10 | 26 |
| semi1 | + BW short (1 Block) [R], + Neon trim strip in the nature colour [R] | 12 | 28 |
| special | + crest (CR, single CornerWedge) [R] + `aura` at Rate 6 | 13 | 29 |

- Markers mount first (at most 3 for humans: ring + 2 Armored plates, ring + 2 stitched strips, or ring + fuse).
- The budget of 14 trims tier D first (§2.1). The worst case is special + 3 markers = 16, which drops GL×2. W + R is at most 9 + 3 = 12.

**Factions**

- **Ninja** (rogue_ninja, clone_ninja, blade_ninja, thunder_ninja, akatsuki_nin)
  - Base look: plain cloth HB (no mark), GL wraps, LM at grade 2+, flak VS at grade 1+, BW short. They read by HB + LM + faction colour.
  - **clone_ninja**: all `0x24242c`, Transparency 0.15, `smoke`.
  - **akatsuki_nin "Ember Veil"**:
    - CP `0x15151d` with an ember-orange `0xd8682a` hem stripe (SurfaceGui).
    - HD (up) `0x15151d` and LM `0x15151d`.
    - No clouds, no red collar.
- **Sorcerer** (kyoto_student, flame_dancer, blood_curse, gate_monk)
  - Base look: HC with uniform-button SurfaceGui, CT at grade 1+, 2 talisman strips (Block 0.15×0.6×0.03 `0xe8e0c8`, `BodyFront` (±0.4, −0.3, −0.03)) at grade 2+.
  - **gate_monk**: saffron `0xd88a3a` VS robe, SB olive `0x4f6b3a`, no hair, GL wraps `0xe8e0d0`.
  - **flame_dancer**: bare torso, SB, `ember` on the hands.
  - **blood_curse**: crimson `0x9b1a2a` drip SurfaceGui.
- **Street / colony** (on the `times_square` or `culling_colony` maps, via `Enemies.mapId`)
  - Headgear becomes a beanie (HR cap + 0.1 cuff Block) or a bandana LM.
  - VS becomes VS + LP (open jacket).
  - BW becomes a pipe Cyl Ø0.12×1.6.
- **grey**
  - `small` preset, WidthScale 0.7.
  - Eyes: GR·e (§3.1), 2 parts.
  - No hair, no FP.
  - Parts: 16 + 2 = **18**, plus at most 3 markers (21).

**Variety**: `Random.new(spawnCounter)` picks:
- one of 3 hair variants per faction
- a skin tone from `0xf3d6b8, 0xe0b088, 0xc89a70, 0x8a6244, 0x5a3a28`
- whether the last tier-D piece is worn

### 4.5 Markers by role

All markers are tier 1 and mount right after FP.

**Affix ring**
- Neon Cyl Ø(1.4 × footprint) × 0.12, `CYL_UP`, Transparency 0.35, colour `affix.color`.
- Welded to the HRP at `(0, −HipHeight − HRP.Size.Y/2 + 0.03, 0)`, `absolute`.
- Footprint as in §2.1.

**Alpha**
- Crest (1 part), gold `0xffd54a` Neon CornerWedge 0.5×0.45×0.5:
  - humans: Head (0, 0.8, +0.06), nominal, standing on the cap top (0.77)
  - creatures: main body piece `(0, 0.5·body.Y + 0.15, 0)`, absolute
- FaceGlow gold, eyes ×1.3.
- Body 15% darker.
- `dust` emitter.
- Nothing else (§1.5).

**Elite motif**

| Affix | Colour | Motif | Parts |
|---|---|---|---|
| Frenzied | `0xff4d5e` | red spike Wedge 0.2×0.6×0.4 crest (humans Head (0, 0.8, +0.06); creatures body top) + red `spark` | 1 |
| Armored | `0xb8c2d0` | **2 DiamondPlate plates, never a shell.** Humans, golems and imps: pauldrons Block 1.2×0.35×1.2 at `L/RShoulderAttachment` (∓0.1, 0.2, 0) `rz(±20)`, which enclose any SG. Toad, blob, wraith and UFO: 2 Wedges 0.5B×0.2B×0.6B on the main body at `(±0.3·body.X, 0.38·body.Y, 0) * rz(∓30)`, absolute. Jelly, core, crack, VS, emblem and lapels all stay visible. | 2 |
| Giant | `0xffb340` | ring 1.6× instead of a motif | 0 |
| Vampiric | `0xc0294a` | dark red `drip` | 0 |
| Volatile | `0xff8a3d` | Creatures: the weak point pulses Transparency 0↔0.5 at 3 Hz on the client (8 Hz during the 1 s fuse). **Humans**: a Neon fuse Ball Ø0.35 in `0xff8a3d` on UpperTorso `BodyBackAttachment` (0, 0.6, +0.2), which pulses the same way. | 0 / 1 |

**Stitched**
- Applies when role is `elite` **and** `Enemies.stitched`, or when the spawn is summoned by a stitched parent (`Enemies.think` passes `opts.stitchedParent`).
- Bosses, character bosses, alphas and finale ids are never stitched.
- Look:
  - 2 Neon Blocks 0.08 × (0.9 × bodyY) × 0.05, `0xff2d55`, at `rz(±30)`, on the front of the main body piece (UpperTorso for humans, at (±0.3, 0, −0.53)).
  - They replace the motif.
  - The ring turns `0xff2d55`.
- `Enemies.stitched` is set in `Waves.start` as `Worlds.get(mapId).stitched == true`, so it resets on every other world.

**Ally / Worn**: `Kit.ally(model)`, called in `Abilities` `handlers.possess` right after `Combat.take(e)`:
- switches the face to the friend face (§2.4, including the SurfaceGui property flip)
- turns the ring or SD cyan `0x5ad4ff`, adding a ring if there is none
- destroys the stitched strips
- destroys the Highlight and calls `Enemies.releaseHighlight(model)`

**Character bosses** (`boss_<style>`, `hanami`, `jogo`, `mahito_b`, `dagon_b`, `kenjaku_b`, `toji_b`)
- Costume: `Costumes.STYLE[Costumes.styleFromEnemyId(id)]`, where `styleFromEnemyId` strips `boss_` and `_b`. The `boss_*` rows in `EnemyLooks.luau` are ignored.
- STYLE cloth colours lerped 22% toward `0x14040a`.
- FaceGlow in `STYLE.colors.sig`. So boss_spiderman glows teal `0x2fb7a8` and boss_miles yellow `0xffe45c`; no Skyline boss glows red.
- **Rift halo**: 3 Attachments on a 1.4-stud ring behind the Head, joined by 3 Beams (Width 0.18, LightEmission 1, `FaceCamera=true`, colour `0xff2d55`).
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

**Dispatch**: when `Finale.ENEMIES[id]` exists, the role is `finale`, and `Enemies.spawn` calls `BUILDERS[Costumes.ENEMY[id].builder](kit, t, pal)`. It skips `CREATURES` and the human ladder. Hyakunui and the Unbidden mount nominal pieces on their R15 parts. The Tempest Fox mounts absolute pieces on the HRP (§2.1).

### 5.1 Hyakunui, the Hundred-Seam (size 1.8, human, `towering`)

Stitched down the midline: the left half is Nuime, the right half is Patchwork.

| Piece | Host and C0 | Parts |
|---|---|---|
| FP: face seam line on FaceBase `0xff2d55`; left iris `0xc89a6a` (Nuime), right iris `0xa8883a` (Patchwork) on FaceGlow | §2.3 | 1 |
| HR cap `0x1a1a22` | §2.3 | 1 |
| HR·k bun, left only `0x1a1a22` | Head (−0.3, 0.6, +0.4) | 1 |
| HR·p strand panel, right only plum `0x3a1e34`, 0.5×0.9×0.3 | Head (+0.3, 0.05, +0.62) | 1 |
| CT robe panel, left only `0x4a3a4a` | hinged at `WaistBack` (−0.48, 0, +0.04), `rx(-14)*rz(6)`, `Sway_*` | 1 |
| HY·s seam strips, Neon `0xff2d55`, 0.12×1.6×0.05, each with an E11 SurfaceGui | UpperTorso (0, 0, −0.525) and (0, 0, +0.525) | 2 |
| HY·n needle Wedges 0.1×0.6×0.1 `0x9aa4b0` Metal at 3 thread ends | UpperTorso (−2.2, 4.2, +1.6), (0, 4.8, +2.0), (+2.2, 4.2, +1.6), each `* rx(−30)` | 3 |
| HY·p chest patches 0.8×0.8×0.06 `0x3a0a14` with stitched-edge SurfaceGui `0xff2d55` | UpperTorso (−0.5, 0.2, −0.53) and (+0.5, −0.25, −0.53) | 2 |
| FS fist + thumb on the right hand `0x8a6244` (the 4th thread ends in the fist) | §2.3 | 2 |
| **Costume total** | | **14 → 30** |

**Halves**
- `Kit.paintParts`: LeftUpperArm and LeftLowerArm in robe `0x4a3a4a`; LeftHand `0xe8d8c0`.
- The description sets the whole-limb colours:
  - Head `0xe8d8c0`, Torso `0x3a2e2a`
  - LeftArm `0xe8d8c0` (repainted as above), RightArm `0x8a6244`
  - LeftLeg `0x1a1622`, RightLeg `0x6a3a4a`
- None of the source's pale blue-grey skin (`bacccf`), pale hair (`dcd3c9`, `b8bfc4`), navy leg (`25345a`) or `mahito_b` colours appear. Test 5b and 5g run on Hyakunui's colours against the mahito and kenjaku rows.

**Threads**
- 4 Beams (0 parts): Width 0.08, LightEmission 1, colour `0xff2d55`.
- They start at UpperTorso Attachments at `BodyBack` (±0.3, 0.6, +0.1) and (0, 0.2, +0.1), and fan out to the far Attachments at the needle positions above, like a loom.
- 3 far Attachments carry the needles, welded to UpperTorso at the same C0.
- The 4th Beam ends at an Attachment in the fist.

**Phases**: `FinaleFight.step` calls `Looks.finalePhase(e.model, phase)` next to `announce(1)` (FinaleFight.luau:129) and next to `announce(phase)` (FinaleFight.luau:134). It is not called inside `announce`.
1. `thread` emitter at Rate 4.
2. The patches "tear":
   - they turn Neon (left `0xff8a3d`, right `0xd9d4cc`) and each fires a 12-particle `burst`
   - the needle welds' C0 and the far Attachments are tweened out to 1.4× their offsets
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
- `S = 2.4 × 0.55 × t.size ≈ 2.77`. S already includes `t.size`.
- Every piece welds to the **HumanoidRootPart**, which is not animated, with `absolute = true`. Ground = y_g.

| Piece | Placement (HRP space) | Parts |
|---|---|---|
| Torso Ell 1.0×0.9×2.2·S, slate `0x3a4250`; belly glow SurfaceGui on its Bottom face, `0xff8a3d`, `LightInfluence 0` | centre at (0, y_g + 1.25S, 0) | 1 |
| Chest ruff Ell 0.9×0.9×0.7·S, `0xe8e4dc` | (0, y_g+1.35S, −0.9S) | 1 |
| Skull Ell 0.8×0.7×0.8·S, `0x3a4250` | (0, y_g+1.7S, −1.3S) | 1 |
| Snout Wedge 0.4×0.35×0.6·S, `0x3a4250` | (0, y_g+1.6S, −1.75S) | 1 |
| Ears: 2 Wedges 0.12×0.7×0.4·S, `0x3a4250`, inner-face SurfaceGui ember `0xff8a3d` | (±0.25S, y_g+2.2S, −1.25S) `rz(∓15)` | 2 |
| Face plate: bone `0xe8e4dc` Block 0.7×0.45×0.05·S with a forked-lightning SurfaceGui `0x3a4250` on FaceBase and 2 ember slit eyes `0xff8a3d` on FaceGlow | (0, y_g+1.72S, −1.71S) | 1 |
| Hind legs: 2 Wedges 0.45×1.3×0.6·S, `0x3a4250`, welds `Gait_HL/HR` | pivot (±0.35S, y_g+0.1+1.3S, +0.8S) | 2 |
| Front legs: 2 Wedges 0.4×1.3×0.5·S, `0x3a4250`, welds `Gait_FL/FR` | pivot (±0.35S, y_g+0.1+1.3S, −0.8S) | 2 |
| Tails: 3 Ell 0.35×0.35×2.4·S, `0x3a4250`, fanning up and back (`rx(-35)`, `rz(-20/0/20)`), `Sway_*` (SwayAmp 10); ember tip Beam `0xff8a3d` between Attachments at 70% and 100% of the length (Width 0.35→0.05, LightEmission 1) + `wind` | hinged at (0, y_g+1.4S, +1.1S) | 3 |
| **Costume total** | | **14 → 30** |

**Gait**
- Diagonal pairs in phase: FL with HR at phase 0, FR with HL at phase 0.5.
- Amplitude ±22°, `f = rootSpeed/(1.6·S)`.
- Each paw moves about ±0.49S fore and aft and lifts about 0.1S. It does not clip through the body.
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
- Visible walker, `towering` (HeadScale 0.8), WidthScale 1.2, DepthScale 0.9.
- Bone `0xd9d4cc` SmoothPlastic on all six description colours.
- `Kit.paintParts` makes the Hands and LowerArms Slate `0xa8a39a`.

| Piece | Host and C0 (§3.1) | Parts |
|---|---|---|
| FP: one vertical dark slit `0x2a2620` on FaceBase, no mouth | §2.3 | 1 |
| UB·p chest plates Block 0.9×0.8×0.1, trim SurfaceGui (UIStroke 4 px) | UpperTorso (±0.5, 0.2, −0.55) | 2 |
| UB·d shoulder domes Ell 1.2×0.7×1.2 | `L/RShoulderAttachment` (∓0.15, 0.1, 0) | 2 |
| **UB·t collar tiles**: 8 Blocks 0.42×0.3×0.14 in a **gorget ring of radius 0.62 at `NeckAttachment` y +0.12**, tile i at `ry(45(i−1)) * CFrame.new(0, 0.12, −0.62) * rx(−20)`, so each faces outward with its top tipped out; they start dull `0x8a8680` | `NeckAttachment` | 8 |
| **Costume total** | | **13 → 29** |

**Collar clearance**
- The ring sits on the torso top. Its bottom edge is at −0.03 relative to the neck, so it just seats into the shoulders.
- The domes sit 0.15 outward on the arms and clear the ring.
- After the relative scale (UpperTorso ×(1.2, 1, 0.9)), the ring is an ellipse with semi-axes 0.744 (x) and 0.558 (z). The tiles' inner faces are at z ±0.488. With HeadScale 0.8 the head's half-depth is 0.48, so the tiles clear it.
- Circumference ≈ 2π·0.65 ≈ 4.1 against 3.36 of tiles, which leaves gaps of about 0.09. At least 3 tiles are visible from any angle.

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
| `STYLE[styleId]` | `{ name, preset, height, browAngle?, colors = {skin, hair, brow, eye, top, sleeves, bottom, trim, sig}, limbs? = {LeftArm?, RightArm?, LeftLeg?, RightLeg?}, paint? = {[R15PartName]={color, material?, reflectance?}}, kit = { {"FP"}, {"HR"}, {"HR·s", n=2, tint=0x2f8f86}, … }, sigPiece = "SC" or nil, face = {marks = {...}, glow?}, props?, suitTN? }`. **`colors.sig` is a colour. `sigPiece` is the kit code.** The old field name `sig` no longer exists on STYLE. |
| `ENEMY[baseId]` | `{ shape?, faction?, variant = {color?, …}, builder? }` |
| `PARTS[code]` | part counts per piece code, including §3.1 codes |
| `TIER[code]` | tier per creature and ladder entry (§2.1) |
| `DEFAULT_TINT[code]` | §2.9 |
| `STEEL`, `GRIP` | `0x9aa4b0`, `0x2a2a30` |
| `SKIN_TONES` | the explicit list of 19 human tones in §3.0 (no mask, suit or creature colours); exempt only where used as skin |
| `WORLD_CONST` | the 20 §1.3 world cloth and metal constants, exempt from test 5g only |
| `FACE_EXEMPT` | `{FP, VB, VB·m, GG, FM, BK, GR·e}` (§2.2) |
| `TRADE_DRESS[styleId]` | §3.0 guard list, as `{ {color, hairOnly?}, … }`, including the revision-5 rows for mahito, antivenom, eleven, kenjaku, dagon, jogo and uro (docock and kashimo extended) |
| `ARSENAL_PROP[styleId][key]` | the §2.6 props, with `suit=true` on the ironman keys |
| `ADAPT_ORDER` | §5.3 |
| `BANNED` | §2.7 |
| `EYE_ZONE` | x −0.33 to 0.33, y 0.06–0.24 |
| `NOMINAL` | §2.1, including `HumanoidRootPart = (2,2,1)` |
| `baseId(id)` | strips `_alpha` |
| `styleFromEnemyId(id)` | strips `boss_` and `_b` |
| `role(id, t, affix)` | §1.5 |
| `palette(template, affix, entry)` | §4.1 |
| `darken(c)` | the 20% lerp toward `0x2a2a30` |
| `effectiveLook(styleId, role)` | returns every colour the build will use: the six description colours, `limbs`, `paint`, eye, brow, sig, glow, mark colours, and every kit entry's resolved tint (explicit or §2.9). For `role == "charBoss"` it applies the 22% lerp. It takes an optional `data` argument that defaults to `Characters`. The function never reads it; the argument exists only so test 5a can pass `{}`. |

**`src/server/Kit.luau`**
- `Kit.new(model, budget)` returns a builder that counts parts.
- `b:mount(host, attach, kind, size, cf, props, opts)`:
  - `kind` is one of `block | wedge | corner | cyl | ball | ell`.
  - Scales per §2.1 (**Scaling**), with `opts.absolute`.
  - Creates the part (for `ell`, a Block with a Sphere SpecialMesh).
  - Creates the Weld (`C0 = attach.CFrame * scaledOffset`).
  - Sets the no-collide and no-query properties.
  - Returns nil once the budget is spent.
  - Tags the piece `CostumeDetail` when its largest side is under 0.6 and it is not an eye, weak point or marker.
- `b:entry(tier, fn, count)` mounts a whole entry or skips it (§2.1).
- `b:gait(name, pivot, phase, amp)`, `b:orbit(axis, rate, phase, center)` and `b:sway(pivot, amp)` set the Weld name and attributes, and tag the model.
- Also: `Kit.ellipsoid`, `Kit.face`, `Kit.emblem`, `Kit.ringOver`, `Kit.paintParts`, `Kit.chain` (§2.1), one builder per code, `Kit.alpha`, `Kit.affix`, `Kit.stitch`, `Kit.ally`, `Kit.riftBoss`, `Kit.prop`, `Kit.suitTN(character, on)`.
- `CREATURES.toad|blob|wraith|golem|imp|ufo` and `BUILDERS.hyakunui|tempest_fox|the_unbidden`.

### 6.2 Changes to existing code

**`Looks.description(look, preset)`**
1. For players and character bosses, `look` is `Costumes.effectiveLook(styleId, role)`. It is never `Looks.lookFor(styleId)`.
2. Sets the six colours. For human enemies it keeps today's `bare` and `sleeves` rules. For STYLE looks it uses `colors` and `limbs` directly.
3. Applies the preset. HeightScale is `look.height`.
4. For human enemies only, reads `look.headScale`, clamped to 0.8–1.1.
5. For human enemies only, drops banned flags.

`ACCESSORIES` stays as an optional path, with the comment `-- optional Creator Store asset here: ACCESSORIES[styleId].hair = "<id>"`.

**`Looks.dressHair`**
- Hair goes at +Z.
- Cap at the base cap plus either 3 extras, 1 panel or 1 knot.
- Skipped when FM or HD is worn.
- Mounted through Kit with a Weld C0, as an ellipsoid.
- Cap raised when HB is worn.
- For players and bosses it runs from STYLE kit entries. `hairStyle` from data is never read on those paths.

**New `Looks.dress(model, look, opts)`**, where `opts = {styleId?, enemyId?, role, grade?, faction?, pal?, budget}`:
1. Destroys `Head.face`.
2. Mounts FP, FaceBase and FaceGlow.
3. Mounts markers, then entries by tier (§2.1).
4. Runs `Kit.paintParts`.

For players:
- `dressPlayer` calls `LoadCharacterWithHumanoidDescriptionAsync(Looks.description(Costumes.effectiveLook(styleId, "player"), preset))`, then `Looks.dress`.
- It connects the `Weapon` listener (§2.6), and the edge-triggered `Suit` listener for `suitTN` styles only. Both are disconnected on `character.Destroying`.
- It destroys any ward (§4.6).
- `Looks.redress(character)` handles only a transform and the Weapon keys marked `suit=true`. It never runs on a `Suit` change.

**`Looks.buildNpc(look, size, opts)`**
1. Preset first.
2. `d.HeadScale *= size`.
3. `Looks.dress`.

For a `charBoss`, `look = Costumes.effectiveLook(styleFromEnemyId(id), "charBoss")`. `Worlds.look(id)` is not consulted.

**New `Looks.buildAlly(id, size)` and `Looks.finalePhase(model, phase)`.**

**`Enemies.spawn`**
1. Before `Rules.applyAffix`: `local pal = Costumes.palette(template, affix, Costumes.ENEMY[Costumes.baseId(id)])`. The fallback look uses `pal.base`, never `t.color`.
2. `local role = Costumes.role(id, t, affix)`.
3. Dispatch:
   - `finale` → `BUILDERS`
   - `charBoss` → STYLE via `effectiveLook`
   - else if `t.shape ~= "human"` → `CREATURES[t.shape]` (ufo included; this replaces `creatureBody`)
   - else the human ladder, using the base id's grade and faction, plus the street variant from `Enemies.mapId`
4. Markers by role:
   - `alpha` → `Kit.alpha`
   - `charBoss` → `Kit.riftBoss`
   - `elite` → `Kit.affix`, and `Kit.stitch` when stitched (§4.5)
5. Highlights through `Enemies.claimHighlight(model, prio)`. Release on death and in `Combat.take`.
6. `model:SetAttribute("NatureColor", pal.nature)`.
7. Store `pal = pal` in the enemy record `e` (add `pal: Costumes.Palette?` to `Combat.Enemy`).
8. The spawn burst at Enemies.luau:238 uses `pal.base` instead of `look.top`.

**`Combat.kill`** (Combat.luau:340–368). The server keeps the body fade and hands the costume to the client:

```lua
local base = if e.pal then e.pal.base else (e.t.color or RulesData.NATURE[e.t.nature].color)
Combat.fx("burst", { at = e.root.Position, color = base, count = 18 })        -- was e.t.color (F10, F17)
e.model:SetAttribute("Dying", true)                                             -- client death read
...
local costume = e.model:FindFirstChild("Costume")
for _, d in e.model:GetDescendants() do
    if d:IsA("BasePart") and d.Transparency < 1
        and not (costume and d:IsDescendantOf(costume)) then                    -- the client owns these
        TweenService:Create(d, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1 }):Play()
    end
end
task.delay(1.5, function() e.model:Destroy() end)                               -- unchanged
```

If a client never sees `Dying` (for example because of streaming), the costume simply disappears with the model at 1.5 s.

**`Enemies.think`**
- Tell is set on `tell` and cleared on `endLunge`, `cancel` and death (§5.2).
- Summons pass `opts.stitchedParent`.

**`Waves.start`**: sets `Enemies.stitched` and `Enemies.mapId`, and destroys all ward models.

**`Combat.luau:416`**: the `Adapted_` attribute. **Combat.luau:669**: the ward strike origin, and destroying the model when its entry expires.

**`FinaleFight.step`**: `Looks.finalePhase` at lines ~129 and ~134.

**`Abilities`**
- `Kit.ally` after `Combat.take` in `handlers.possess`.
- The `mahoraga` branch spawns the ward.
- `handlers.dash` sets the glider swap: `if c.id == "glider_ram" then c.root.Parent:SetAttribute("GlideUntil", workspace:GetServerTimeNow() + 0.8) end`.

**Client `Fx`** (0 server cost)
- `Gait`, `Orbit` (with `OrbitCenter`), `Sway` and `Glide` drivers.
- Float bob and toad hop.
- Volatile and cursed_womb pulses, including the human fuse ball.
- Tempest Fox tell.
- **Death read**: on the model attribute `Dying` becoming true, every `Costume` BasePart is set to Material Neon and Color `NatureColor` for 0.1 s, then tweens Transparency to 1 over 0.4 s while `burst` fires. The server never touches these parts during the kill (see `Combat.kill` above), so there is no fight.
- **Distance LOD**, every 0.5 s:
  - `CostumeDetail` pieces get `LocalTransparencyModifier=1` beyond 90 studs
  - costume emitters are disabled beyond 120 studs
  - `Sway` stops beyond 60 studs

### 6.3 Budgets

| Figure | R15 | Costume budget (FP + markers + kit) | Cap | Lights | SurfaceGuis | Emitters |
|---|---|---|---|---|---|---|
| Player | 16 | ≤14 (largest: Ironthread and Eightfold 14; Threadrunner with suit 12) | **30** | 0 | ≤4 (2 face) | ≤1 |
| Human enemy | 16 | 3 → 13, plus markers, trimmed by tier to 14 | **30** | 0 | ≤3 | ≤1 |
| grey | 16 | 2 + markers ≤ 5 | **21** | 0 | 0 | 0 |
| Creature | 16 | ≤14 | **30** | 0 (UFO: 1 SpotLight) | ≤2 | ≤1 |
| Alpha / elite / stitched | 16 | markers first, then W, R, L, D | **30** | 0 | ≤3 | ≤2 |
| Character boss | 16 | ≤14 (halo is Beams) | **30** | 1 | ≤4 | ≤2 |
| Hyakunui / Tempest Fox / Unbidden / ward | 16 | 14 / 14 / 13 / 14 | **30 / 30 / 29 / 30** | 1 / 0 / 0 / 0 | ≤4 | ≤3 |

- **Worst-case parts**: 24 enemies × 30 + 8 players × 30 + wards (1 per caster, 30 each) is about 1,200 character parts. These are spread over the arena and LOD-culled on the client. The ~900-part arena budget covers level geometry; character parts are counted separately.
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
| ember | 4 | 0.6–1.0 | 0.6 | 0.2→0 | Speed 1–2, upward, `0xff8a3d` (Karasu: `0x5a5a78`) |
| smoke | 5 | 1.2 | 0 | 0.6→1.2 | Transparency 0.4→1, `0x3a3a40` |
| drip | 3 | 0.8 | 0.2 | 0.12 | Acceleration (0, −20, 0), colour from the owner (`colors.sig` or `affix.color`) |
| spark | 6 | 0.3 | 1 | 0.1 | Speed 6, Spread 180, `0xffe45c` (Frenzied: `0xff4d5e`) |
| wind | 4 | 1.0 | 0.3 | 0.3→0 | Spread 30, `0xdff4ee` |
| dust | 6 | 0.8 | 0 | 0.4→0.8 | at the feet, `0xc8b8a0` |
| shadow | 5 | 1.0 | 0 | 1→0 | `0x101014`, flat |
| feather | 3 | 1.2 | 0 | 0.25 | random rotation, `0x14141c` |
| coin | 3 | 0.8 | 0.5 | 0.2 | `0xffd54a` |
| aura (boss) | 10 | 1.0 | 0.8 | 0.8→0 | Shape Cylinder, at the feet, `0xff2d55` |
| thread | 4 / 12 | 1.2 | 1 | 0.1 | `0xff2d55` |
| burst | `Emit(12)` | 0.6 | 1 | 0.3→0 | one-shot, `NatureColor` |

### 6.6 Tests (Lune, `tests/`)

1. **Coverage**:
   - Every `Styles` id has a `STYLE` entry with all 9 `colors`, `preset` and `height`.
   - Every `boss_*` id resolves through `styleFromEnemyId`.
   - Every enemy id resolves through `baseId`.
   - `akatsuki_nin`, `gate_monk`, `ufo` and the finale ids have entries.
   - Every §3.1 code has a `PARTS` entry.
2. **Parts**:
   - For every style (with and without its suit), every enemy (normal, alpha, elite with each motif, stitched), every finale builder and the ward, `16 + Σ PARTS` after trimming is ≤ 30.
   - The untrimmed +N values in §3 **and** §4.3 equal their `PARTS` sums (Threadrunner = 10 and 12 with the suit; goblin_drone = 12).
3. **Placement and trimming**:
   - Each style's `sigPiece` (when not nil) is within the first 10 kit entries and survives the build.
   - For every enemy × {normal, alpha, elite-Armored, stitched}, every W and R entry is mounted.
   - Entries are never split.
4. **Banned content**:
   - No human-enemy look keeps a `BANNED` flag.
   - Only E1–E11 are used.
   - No Shinobi forehead plate.
   - No ninja uses a scratched mark.
5. **Colour**, on `effectiveLook` for every style in both the `player` and `charBoss` roles:
   - **a. Authority**: `effectiveLook(id, role, {})` (empty `Characters`) equals `effectiveLook(id, role)`. A build of each player and character boss with a stubbed `Characters = {}` and `EnemyLooks = {}` succeeds and produces the same colours. Nothing leaks from data: no data sleeves, skin, sig, flags (including `nosebleed`, `whiskers`, `stitches`) or hairStyle. No face mark in any STYLE is made of 2 or more parallel Frames on one cheek.
   - **b. Trade dress**: no effective colour is within RGB distance 30 of a `TRADE_DRESS[id]` entry (hair-only entries are checked against hair, brow and HR·* / FLT / TIP tints). Exempt: a `SKIN_TONES` value **used as skin** (§3.0; the list holds human tones only, so suit and mask colours are always checked) and colours with HSV value < 0.3. Also run on Hyakunui against the mahito and kenjaku rows.
   - **c. Skyline red**: no effective colour of any Skyline style (all six description colours, paint colours, sig, eye, and every tint) has hue < 20° or > 340° at saturation > 0.5. Redmaw `0x8a1a5a` (≈326°) and Cackler `0xc8642a` (≈22°) pass.
   - **d.** No Skyline effective look pairs a red with a blue (200°–250°, saturation > 0.4).
   - **e.** Threadrunner has no non-skin colour (every effective colour except a `SKIN_TONES` value used as skin) with saturation ≥ 0.25 within 20° of the hue of `0xffb347` (35.2°); this covers glow, lens, trim and cloth. Its skin `0xc89a70` (28.6°, and about 26.6° after the boss lerp) is a human tone and is exempt. No head colour has value > 0.85 and saturation < 0.15.
   - **g. Verbatim copy** (§3.0): the test gathers the style's source colours from `Characters` and `EnemyLooks` (the only place data is read for a player or boss look). At most 2 effective colours per style lie within RGB distance 8 of a source colour, and none of them is in `top`, `sleeves`, `bottom`, `trim`, `hair` or `limbs`. Exempt: skin uses of `SKIN_TONES`, HSV value < 0.25, and `WORLD_CONST`. Also run on Hyakunui against mahito ∪ kenjaku.
   - **f.** Character-boss FaceGlow equals `colors.sig`, which passes c for every Skyline style.
6. **Palette**: `palette(...).base` never equals `affix.color` unless the template colour does. `goblin_drone` base is `0xc8642a`.
7. **Adaptation order**: `ADAPT_ORDER` is a permutation of the `NATURE` keys.
8. **Props**: for each style in `Arsenals`, every key in `Arsenals[style].order` exists in `ARSENAL_PROP[style]`, and each prop is ≤ 3 parts. Only ironman keys carry `suit=true`.
9. **Roles**:
   - Every `ALPHA_IDS` entry resolves to `"alpha"`.
   - Every `Finale.ENEMIES` key resolves to `"finale"`.
   - Every `boss_*` id resolves to `"charBoss"`.
   - `Rules.rollAffix(w, true, 0, 0, 1)` returns nil.
10. **Face zone**: for every style (player and charBoss), every human-enemy grade and faction, the grey, Hyakunui and the Unbidden, no mounted piece outside `FACE_EXEMPT = {FP, VB, VB·m, GG, FM, BK, GR·e}` has a surface with z < −0.60 inside `EYE_ZONE` (x ±0.33, y 0.06–0.24, §2.2). `Orbit_*` pieces are checked at 36 phases. Creature families (their faces are not R15 heads) are out of scope. `ringOver` holds on both axes for every band worn over a cap.
11. **Ellipsoids**: every `PARTS`/spec entry of kind `ball` has three equal axes. Anything else must be `ell`.
12. **Scaling mode**: every toad, blob, wraith, UFO and Tempest Fox piece, and every HRP-hosted piece, mounts with `absolute=true`. Every other piece's host name is in `NOMINAL`. A golem piece on a size-1.6 mass_curse comes out ×1.6 exactly once (through its scaled host), and a toad body sized in B comes out at exactly B, never ×`t.size` twice.
13. **Suit listener** (a pure function `Costumes.suitEdge(prev, value)`): the Suit sequence 260, 251, 240, 12, 0, nil, 30 yields exactly 2 transitions after the initial mount (off at 0, on at 30).

---

## 7. Reviewer items

### Round 4 (revision 5): blocking, all fixed

| # | Item | Fix | Where |
|---|---|---|---|
| 1a | Ren's 3-line cheek mark reads as whiskers | Mark removed. No face marks. `BANNED` forbids substitutes. Test 5a rejects parallel cheek Frames. | §3 Ren, §2.7, §6.6 5a |
| 1b | Nosebleed's nose mark comes from `eleven.nosebleed` | Removed in every phase. `nosebleed` is banned. The copied bottom, eye and off-white are also replaced. | §3.0, §3 Nosebleed, §2.7 |
| 1c | Patchwork and Hyakunui copy mahito's data | Plum hair and brow `3a1e34`. `bacccf` → `8a6244`. New top, legs, trim, eye and sig. Hyakunui's right half follows. | §3.0, §3, §3.1 PLT/SEAM, §5.1 |
| 1d | Antidote is antivenom's palette on the same heavy build | `lean` 1.04. Celadon `a8c4b0` and deep teal `24585a`, bone `d8ccb0`, mint `4ae0c0`. No white. | §3.0, §3 Antidote |
| 1e | Guard blind to these; SKIN_TONES includes suit colours | Explicit 19 human `SKIN_TONES`, exempt only as skin. 7 new `TRADE_DRESS` rows, 2 extended. Mechanical test 5g for verbatim copies. 18 further styles recoloured. Script run: 0 violations. | §3.0, §6.1, §6.6 5b/5g |
| 2a | Test 5e fails on Threadrunner's own skin | 5e checks non-skin colours with saturation ≥ 0.25 only | §6.6 5e |
| 2b | Test 10 fails on FP, GR·e and Aoi's OR | `FACE_EXEMPT` adds FP and GR·e. OR raised to y 0.65 (spans 0.475–0.825). Orbits are tested at 36 phases. | §2.2, §2.3 OR, §6.1, §6.6 10 |

### Round 3 (revision 4): blocking, all fixed

| # | Item | Fix | Where |
|---|---|---|---|
| 1 | Palette and flag leakage | STYLE is authoritative for players and character bosses. `Characters.luau` and the `boss_*` EnemyLooks rows are never read. All 46 palettes are written out (9 colours + preset + height). `DEFAULT_TINT` covers every code. The flag→kit mapping runs for human enemies only. `sig` is renamed to `sigPiece`, and `colors.sig` is the colour. Test 5 runs on the effective look, runs with `Characters = {}`, checks TRADE_DRESS, and checks every colour for Skyline red. The named leaks are all gone: Ren's arms `0x2f8f86`, Threadrunner's face `0xc89a70` with no red sig, Arc Knight has no gold, Clawback's sleeves are `0x4a5a3a` with no cowl flags, Cackler has no HD, Eightfold has no GG or bowl, Hatsuyuki's HB is dropped, Karasu has no red HC, Akuro has no face marks from data, Warden's sash and buckle are `0x3a3048`/`0x9fe0e8` and his cape is dropped. Skyline boss FaceGlow uses `colors.sig`. | §1.1 rule 6, §2.7, §2.9, §3.0, §4.5, §6.1, §6.2, §6.6 (5) |
| 2 | IP on the three biggest names | Aoi hair `0x2a3448` with `0xbfe8ff` streaks, resting iris `0x6a5a8a`. Akuro hair `0x2a1a1c` with 2 HR·w `0x9b1a2a`, no spikes. Ikazuchi hair `0x1e2230` with a `0xf0d27a` TIP block. | §3.0, §3, §3.1 (TIP) |
| 3 | Bespoke pieces without a host | New §3.1 with 36 rows (size, host, attachment, C0, tint). The chain rule is in §2.1 and BA in §2.3. HP headphones: cups at Head (±0.64, 0.02, +0.05), band as a curved Beam that peaks at y 0.92. The GG pushed-up position is corrected too. | §2.1, §2.3, §3.1 |
| 4 | Geometry | (1) WG `CYL_FWD` at BodyBack (0, 0.1, +0.2), with a Glide swap. (2) Collar r 0.62, y +0.12, `rx(−20)`; domes at (±0.15, 0.1, 0). (3) `OrbitCenter`; Gravewell (0, 0.4, +1.1). (4) HR·s `rx(+30)`, HR·w `rx(+15)`. (5) `EYE_ZONE` x ±0.33 and HR·f at x −0.44. | §2.1, §2.2, §2.3, §3.1, §5.3 |
| 5 | Double scaling | `opts.absolute` rules, `NOMINAL.HumanoidRootPart`, size projection onto piece axes, test 12 | §2.1, §4.2, §5.2, §6.6 |
| 6 | Markers hide or drop weak points | Armored = 2 plates. Tiered mount order FP → markers → W → R → L → D, with atomic entries and a worst-case table. Volatile fuse ball for humans. Test 3. | §2.1, §4.2, §4.4, §4.5 |
| 7 | Death read fights the server | `e.pal`; the kill burst uses `pal.base`; the kill skips `Costume` descendants and sets `Dying`; the spawn burst uses `pal.base` | §0 F17, §6.2 |
| 8 | Suit listener rebuilds on every hit | Edge-triggered `hasSuit`. It only mounts or destroys `Costume/SuitTN`. Redress runs only on `suit=true` Weapon keys. Test 13. | §2.6, §6.2, §6.6 |
| 9 | Threadrunner arithmetic | Spools are the gloves (SPL×2): 10, or 12 with the suit | §3 |

### Round 3: improvements adopted

- Client-side `Sway_*` for CP, CT, SC tails, HB·t and the fox tails.
- The glider moves under the feet only during Glider Ram (`GlideUntil`).
- The pushed-up GG moves to z −0.56 so it sits in front of the hair cap rather than inside it.
- Tiered trimming, so variant identity pieces (fingers, bat wings, needles) never drop before decoration.
- Akagane loses the two hair tufts (a source tell) for a single swept wedge.
- Nanami's blond hair, Ishigori's pale flat-top, Hakari's pale hair, Yuki's blonde hair, Nobara's copper and Naoya's blond tips are replaced (§3.0).
- Jean's red hair, Doc Ock's bowl cut and Winter's silver arm are replaced.
- Blackmaw's near-white slit becomes violet `0xb89aff`.
- Ironthread's amber lenses (close to the source gold) become `0x6ad8c8`.
- Clawback is no longer short.

### Declined or adjusted

- **Headphone band.** The review suggested `CurveSize0 = CurveSize1 = 0.9`. That only bends both control points upward if the two Attachments' Axes point opposite ways (Beam control point 2 is `P1 − Axis1·CurveSize1`). HP1's Axis is therefore (0, −1, 0). The shape is as the reviewer intended.
- **Scaling for BUILDERS.** Not every builder is absolute. Hyakunui and the Unbidden hang nominal pieces on scaled R15 parts and need relative scaling. Only the Tempest Fox, which is sized in S on the HRP, is absolute. Golem and imp pieces are nominal too.
- **HR·f.** I both narrowed `EYE_ZONE` and moved HR·f to x −0.44. At −0.42 its inner edge (−0.32) would still sit 0.01 inside the narrowed zone. I did not add an exemption.
- **Unbidden gaps.** At r 0.62 the gaps are about 0.09, not 0.19. At least 3 tiles still read from any angle.

### Earlier rounds (revision 2), still in force

Kit.ellipsoid and the Cylinder convention; the headband-over-cap rule and test 10; client `Gait_*` legs; role precedence; the Tell cleared on cancel; the Redmaw redesign; the Threadrunner, Cackler and Clawback redesigns; the Unbidden collar concept; `Kit.paintParts` and the two-SurfaceGui face; stitched only on elites; Patchwork's fist; Hyakunui's 4th thread ending in the fist; Doctor Eightfold at 14; Clawback's parka hood; Aoi's coat tails; Tempest Fox HeightScale 0.7.
