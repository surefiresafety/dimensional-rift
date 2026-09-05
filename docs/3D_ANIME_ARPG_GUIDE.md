# Dimensional Rift 3D — Anime Action RPG Technical Guide

Lead Game Programmer / Technical Art Director notes for building the 3D version in **Unreal Engine 5.4+**
(Unity HDRP notes at the end). The 2D prototype in `src/` stays the design reference: same nature wheel,
same Rule of Four, same Spirit Energy.

Source files referenced here live in `unreal/` and `unity/`.

---

## Part 1 — Project architecture and the cel-shaded look

### 1.1 Create the project

1. Unreal Engine 5.4 or newer. **Games > Third Person**, C++, Starter Content off, Raytracing off.
   Name it `DimensionalRift`, then copy `unreal/Source`, `unreal/Config/DefaultEngine.ini` and
   `unreal/DimensionalRift.uproject` over the generated ones. Right-click the `.uproject` > *Generate
   Visual Studio project files*, build, open.
2. Enable plugins (the `.uproject` already lists them): **Enhanced Input, Niagara, Niagara Fluids,
   Cable Component, Gameplay Abilities, Pose Search (Motion Matching), Control Rig, Modeling Tools.**
3. Project Settings > Input > Default Classes: *Enhanced Player Input* and *Enhanced Input Component*.
4. Content folders (keep this flat; it scales to a team):

```
Content/
  Core/            BP_DRGameMode, BP_DRPlayerController, BP_DRCharacter (child of ADRCharacter)
  Input/           IMC_Default, IA_Move, IA_Look, IA_Jump, IA_Swing, IA_Zip, IA_Reel, IA_Dodge, IA_Ability1..4
  Abilities/       DA_* Data Assets (one per technique) + BP_Payload_* actors
  Characters/      Player/, Mentors/, Enemies/ (mesh, ABP, Control Rig, materials)
  Enemies/         BP_Enemy_* with IDRExtractable
  VFX/             Niagara systems, flipbooks, materials (M_VFX_*)
  Rendering/       PP_CelShade, PP_Outline, M_Toon_Master, MPC_Lighting, LUTs
  Maps/            L_NYC_TimesSquare, L_Konoha_TrainingGrounds, L_JujutsuHigh
  UI/              WBP_HUD (HP, Spirit Energy, 4 slots), WBP_Loadout
```

### 1.2 Systems layout (what talks to what)

```
ADRCharacter ─── UDRCharacterMovementComponent   (walk/fall + CMOVE_Swing + CMOVE_Zip)
     │       ├── UDRAbilityManagerComponent       (Learned[], Slots[4], cooldowns, ExtractFrom)
     │       ├── UDRSpiritEnergyComponent         (one pool, regen, OnChanged → HUD)
     │       └── UCableComponent                  (visible web)
     │
     ├── implements IDRCombatant                  (GetNature, IsInvulnerable, OnTechniqueHit)
     └── Spider-Sense: enemies call WarnIncomingAttack(); dodge inside window = Perfect Dodge

UDRAbilityData (Data Asset) ──► PayloadClass actor (hitbox/projectile + Niagara)
                                     └── UDRCombatStatics::ApplyTechniqueDamage(Target, Power, Nature)
Enemy (BP_Enemy_*) implements IDRCombatant + IDRExtractable(GetExtractableAbility)
```

Why not the Gameplay Ability System from day one? GAS is the right end state for a shipped ARPG
(prediction, gameplay effects, attribute sets), but its learning curve is steep and the loadout logic
is what makes this game special. `UDRAbilityManagerComponent` is written so that `SpawnPayload()` is
the one function you replace with `ASC->TryActivateAbilityByClass()` when you migrate. Study Epic's
**Lyra** sample for the GAS wiring when you get there.

### 1.3 Lighting for anime

The goal is *Guilty Gear Strive / Hi-Fi Rush* flat-lit characters inside a soft, painterly world. The
trick used here: keep Lumen on for the world, then **quantize the lighting result in post** so it reads
as bands. No engine source changes, no custom shading model.

**Directional light (the "key")**
- Intensity 6–8 lux, temperature 5500 K, angle 0.3°. One strong key is more anime than many fills.
- Cast Shadows on, **Shadow Resolution Scale 2**, Virtual Shadow Maps on (config sets this).
- Light Shafts off (they photoreal the image). Use volumetric fog sparingly for god rays instead.

**Sky light + Sky atmosphere**
- Sky Light: Real Time Capture, intensity 1.0, **Lower Hemisphere is Solid Color** with a slightly
  warm ground bounce. This is your "ambient fill" band.
- Sky Atmosphere with Rayleigh scattering scale 0.05 and a stylized gradient via a **Sky material**
  (unlit, 3-stop gradient: horizon / mid / zenith) for the Konoha and Jujutsu High maps.

**Lumen**
- Global Illumination + Reflections = Lumen, quality *High*, **Final Gather Quality 2**, Lumen Scene
  Lighting Quality 1. Turn *off* Lumen for the NYC night map if performance dips; the cel pass hides
  the difference.

**Exposure and color**
- Auto exposure **off** (config). Post Process Volume: *Exposure > Metering Mode Manual*, Exposure
  Compensation 0, then set the directional light so the lit band sits around 0.8 luminance.
- Tonemapper: Film Slope 0.75, Toe 0.4, Shoulder 0.2, Black Clip 0, White Clip 0.04. Flattening the
  curve keeps shading bands flat instead of rolling off.
- Bloom: *Standard*, intensity 0.35, threshold 1.2. Techniques emit at 20–60× emissive so bloom only
  fires on VFX, never on skin.
- Chromatic aberration 0, vignette 0.2, grain 0, **motion blur 0** (config), lens flare off.
- Color grading: Saturation 1.15, Contrast 1.05, Shadows tint slightly cool (0.95, 0.95, 1.05).
- Optional: a 32×32 LUT per world (NYC = cool neon, Konoha = warm green, Jujutsu High = desaturated
  night) exported from DaVinci/Photoshop. LUTs are the cheapest way to make three worlds feel distinct.

**Anti-aliasing**
- **TSR** (config). Ink lines shimmer under TAA; TSR at 200% history plus `r.Tonemapper.Sharpen 1.5`
  keeps them crisp. If you ever switch to Forward Shading for MSAA, the post-process cel pass loses
  the GBuffer (`BaseColor`, `WorldNormal`), so keep deferred.

### 1.4 The cel-shade post-process stack

Two Post Process Materials, both **Before Tonemapping**. HLSL in `unreal/Shaders/`.

**PP_CelShade** (priority 0)
1. Material Domain = Post Process, Blendable Location = Before Tonemapping.
2. Add a **Custom** node, paste `PP_CelShade_Custom.hlsl`, inputs `UV, Steps, Bands, ShadowTint, SpecCut`.
3. Feed `UV` from *TexCoord[0]*, `Steps` = 3, `Bands` = 0.35, `ShadowTint` = (0.55, 0.45, 0.75),
   `SpecCut` = 0.92. Output → Emissive Color.
4. It divides the lit scene by albedo, quantizes the light into 3 bands, tints the shadow band cool,
   multiplies back. Anything with Custom Stencil 0 (sky, VFX, water) is passed through.

**PP_Outline** (priority 1)
1. Same domain/location. Custom node with `PP_Outline_Custom.hlsl`, inputs
   `UV, LineWidth, DepthK, NormalK, LineColor`.
2. Sobel on depth + world normal + custom stencil. Depth = silhouettes, normal = interior creases,
   stencil = a guaranteed line between two overlapping characters.
3. Line width in pixels is resolution-independent (`View.ViewSizeAndInvSize`). Fades with distance.

**Per-mesh setup**
- Every character/prop: *Rendering > Render CustomDepth Pass = true, CustomDepth Stencil Value = 1.*
  Hair, eyes, metal: value 3 (bit 2 = hard specular ping).
- Characters also get an **inverted-hull outline**: duplicate the mesh material slot with
  `M_InvertedHull` (two-sided off, *Cull Front*, vertex offset along normal 0.6 cm, unlit black).
  The post-process line gives consistency; the hull gives the thick "brush" edge on heroes.

**Character master material `M_Toon_Master`**
- Base Color from a *hand-painted* albedo (flat colors, painted AO on folds). No roughness/metal maps
  for cloth. Roughness 0.85 constant, Specular 0.2.
- Emissive channel masked to eyes/markings, driven by a `GlowIntensity` parameter the technique VFX
  pulses (Cursed Energy aura, Sage Mode eyes).
- Normal map only for hard-surface (armor, web-shooters). Soft cloth normals fight the band edges.
- **Face shading**: use a *SDF face shadow map* (Genshin-style). Sample it with the dot of light
  direction against the head's forward vector, passed from a Material Parameter Collection updated by
  the character each tick. This is the one place hand-authored shadow shape beats the post pass.

### 1.5 Animation

- **Motion Matching** (Pose Search plugin, UE 5.4 *Game Animation Sample*) for locomotion. Free from
  Epic; drop in your anime skeleton via IK Retargeter.
- Techniques are **montages** with **AnimNotifies**: `Notify_HitboxOn/Off`, `Notify_SpawnPayload`,
  `Notify_EndCast` (calls `AbilityManager->EndCast()`), `Notify_HitStop`.
- Anime snap: run attack montages at 24 fps sampling with **held poses** (2–3 frame holds at the peak),
  then 0.05 s hit-stop via `SetGlobalTimeDilation(0.02)` for 3 frames on contact.
- **Control Rig** for the hand-to-web IK during swings (aim the arm at `GetSwingAnchor()`).

---

## Part 2 — Foundational code

All classes are in `unreal/Source/DimensionalRift/`. Summary of the design; read the headers for
the full API.

### 2.1 Web-swing physics (`UDRCharacterMovementComponent`)

A custom movement mode, `CMOVE_Swing`, solved on the character's own velocity (no PhysX constraint,
so it stays network-predictable and never fights the capsule):

1. **Anchor search** (`FindAnchor`) fires 27 line traces in a fan above the camera forward vector
   (elevation 25–80°, yaw ±35°), biased toward the current travel direction. Tagged `WebAnchor`
   geometry beats raw buildings. Candidates must be at least `MinAnchorHeight` above the player and
   within `MaxRopeLength`. Score = height × 0.6 + forwardness × 0.9 − distance × 0.25.
2. **Per tick** (`PhysSwing`):
   - integrate gravity × `SwingGravityScale` (1.6: heavier gravity = punchier arcs) and stick pumping;
   - reel-in shortens the rope (angular momentum turns it into speed);
   - **rope tension**: at full extension remove the outward radial velocity component, keep the tangent;
   - move with `SafeMoveUpdatedComponent` (collisions and slide work like stock modes);
   - **project the capsule back onto the sphere** of radius `RopeLength`;
   - set velocity from the displacement that actually happened (position-based dynamics).
3. **Release** multiplies momentum by 1.15 and adds an upward boost, so releasing at the bottom of an
   arc launches the player forward and up. Jump also releases. Landing on a walkable normal hands
   control back to `MOVE_Walking`.
4. `CMOVE_Zip` is the traversal twin of Web-Pull: straight line to the anchor at 32 m/s.

Tuning knobs are all `UPROPERTY` and safe to edit at runtime in PIE. Start with the defaults and change
one at a time: `SwingGravityScale` for arc feel, `SwingPumpAcceleration` for player agency,
`ReleaseUpBoost` for how generous release is.

The visible web is a `UCableComponent` attached to `hand_r`; `ADRCharacter::Tick` moves its end to
the anchor each frame.

**Level design contract for the HM-style gaps:** place `BP_WebAnchor` actors (a static mesh with
collision responding to the `WebAnchor` channel) above every gap you want crossable. The Konoha river
crossing from the 2D prototype becomes two anchors 25 m apart.

### 2.2 The 4-slot ability manager (`UDRAbilityManagerComponent`)

- `Learned` (unbounded) and `Slots` (exactly 4, `nullptr` = empty). `Equip()` with `-1` takes the first
  free slot and **fails when full**, so the UI has to ask the player what to drop. That refusal is the
  Rule of Four.
- `ExtractFrom(AActor*)` is called by enemy death logic; it reads `IDRExtractable` and learns the
  technique, auto-equipping while there is room.
- `TryActivate(Slot)` returns an enum (`EmptySlot / OnCooldown / NotEnoughSpiritEnergy / Blocked`) so
  the HUD can shake the slot and play the right barks. On success it spends Spirit Energy, starts the
  cooldown, plays the cast montage, spawns the Niagara cast effect and the payload actor.
- `UDRAbilityData` (Primary Data Asset) is the designer-facing definition: nature, cost, cooldown,
  power, montage, VFX, sound, payload class. Techniques from all three universes are the same asset
  type, which is what makes the loadout truly mixed.

Spirit Energy (`UDRSpiritEnergyComponent`): one pool, regen after a 2.5 s delay, `OnChanged` for the
HUD. Ninjutsu, cursed techniques and web gadgets all call `TrySpend`.

### 2.3 Real-time combat

- `UDRCombatStatics::ApplyTechniqueDamage(Target, Power, Nature, Instigator)` is the *only* way damage
  enters the game. It reads the target's nature via `IDRCombatant`, applies the wheel (×2 / ×0.5),
  respects `IsInvulnerable`, then calls `OnTechniqueHit` for hit reacts and "Super effective!" UI.
- **Spider-Sense**: an enemy's attack montage has a notify at commit time that calls
  `Player->WarnIncomingAttack(this, 0.4)`. The world drops to 0.35× time (the player is exempt via
  `CustomTimeDilation`), a UI ring closes, and a dodge inside the window is a **Perfect Dodge**:
  1.2 s invulnerability, +10 Spirit Energy, `OnPerfectDodge` for the counter animation and the
  Sharingan/Spider-Sense flash. Naruto's Sharingan reuses the same window with a different VFX.
- Normal dodge: 0.25 s i-frames, 4.5 m, 0.6 s cooldown, launched via `LaunchCharacter`.

### 2.4 Enemy contract

```
BP_Enemy_CursedToad : ACharacter, IDRCombatant, IDRExtractable
  GetNature            -> Water
  GetExtractableAbility -> DA_AcidSpit
  OnDeath              -> Player->AbilityManager->ExtractFrom(this); play absorb VFX
  Attack montage notify -> Player->WarnIncomingAttack(this, TimeToImpact)
```

---

## Part 3 — Making the technique VFX look incredible

Techniques, in priority order. Each is achievable in stock Niagara.

**Core techniques**
1. **Hand-drawn flipbooks for impacts and smoke.** Draw 8–16 frame loops in Krita/Clip Studio (or
   Blender Grease Pencil), atlas them, play as Niagara sprites with *SubUV Blend off* (hard frames read
   as anime). This single technique carries 60% of the look. Free flipbook sources: Epic's
   *Paragon* and *Infinity Blade* FX packs (Fab, free) have sprite sheets you can re-cut.
2. **Stepped alpha, not soft alpha.** In every VFX material, run opacity through `step()` or a 2–3 band
   `smoothstep` staircase. Soft gradients are the fastest way to look "Unreal default".
3. **Ribbons for Chidori, webs and Cleave.** Niagara Ribbon renderer with a *Jitter Position* module
   (Chidori: 2–3 cm jitter every frame, additive, 40× emissive), *Ribbon Width by Curve* (thick at the
   hand, hairline at the tip). Sukuna's Dismantle is a flat ribbon with a panning "slash" texture and
   a 3-frame lifetime.
4. **Mesh-based VFX for Rasengan/Rasenshuriken.** A UV-sphere with three panning noise layers
   (different speeds, `frac()` for hard bands), Fresnel rim clamped to 2 bands, and a mesh ring for the
   shuriken blades spun by *Mesh Rotation Rate*. Vertex-animate the "spin" in the material, not the
   particle.
5. **Radial blur + chromatic split for Domain Expansion.** A post-process material with a *Radial Blur*
   (12 samples toward screen center) and a scalar parameter the payload actor drives 0→1 over 0.3 s
   via a *Material Parameter Collection*. Pair with a `Sequencer` camera cut and a Sky material swap
   (Dagon's domain replaces the sky with a water-caustic gradient).
6. **Screen-space shockwave.** Post-process refraction ring (distance field from a world position
   projected to screen, `sin()` band, 0.25 s). Used on every heavy hit; layer two for Black Flash.
7. **Anime speed lines.** Full-screen post material: radial UV, panning 1-D noise, stepped, masked by a
   vignette. Trigger on dodge-perfect and web release above 30 m/s.
8. **Hit-stop + camera shake + flash.** Every hit gets 2–4 frames of `SetGlobalTimeDilation(0.02)`,
   a *Camera Shake* (Perlin, 0.15 s) and a 1-frame white `PP` flash. This is cheaper than any VFX and
   is most of what "impact" is.
9. **Niagara Fluids for Disaster Flames and Gamabunta's water.** 2D gas sim (flames) and 3D liquid
   (water gun) from the *Niagara Fluids* plugin. Render the sim result through a 3-band stepped
   material so it stays flat like the rest of the image.
10. **Light functions and emissive bleed.** A spot light with a *Light Function* material (panning
    noise) attached to fire techniques makes the environment react to the jutsu in bands.
11. **Web material**: a spline mesh or cable with a *tiling silk texture*, 2-band Fresnel, and a
    `WorldPositionOffset` sag driven by the swing velocity so the web bows on release.
12. **Dissolve for extraction.** Defeated enemies dissolve with a stepped noise mask and an emissive
    edge in the technique's nature colour; particles fly to the player's chest (Niagara *Vector Field*
    or *Curl Noise Force* toward a spawn parameter `PlayerLocation`). This is the "capture" moment.

**Free plugins and assets to install**
- **Niagara + Niagara Fluids** (built in, enable in plugins).
- **Cable Component** (built in) for the web.
- **Pose Search / Motion Matching** and Epic's free **Game Animation Sample** project.
- **Lyra Starter Game** (Epic, free): the reference for GAS, Enhanced Input and UI patterns.
- **Paragon** character/FX packs, **Infinity Blade: Effects**, **Realistic Starter VFX Pack Vol 2**,
  **M5 VFX Vol 2 Fire and Flames** on Fab (all free). Re-cut their flipbooks into stepped-alpha versions.
- **Stylized Rendering** and **Valley of the Ancient** (Epic samples) for post-process material patterns.
- **Advanced Locomotion System (ALS v4, free)** if Motion Matching feels heavy.
- Search Fab for "anime toon shading post process" if you want a ready-made cel pass to compare against
  the two shaders here; several free ones exist, but check they support UE 5.4 and Lumen.

**Performance budget** (target 60 fps at 1440p on an RTX 3070-class GPU): 2 post-process materials
≈ 0.9 ms; keep Niagara GPU particle count under 200k on screen; Lumen *High* ≈ 5 ms; VSM ≈ 2 ms.

---

## Appendix — Unity HDRP equivalent

- **Toon shading**: Unity's official **Unity Toon Shader** package (`com.unity.toonshader`, HDRP
  support, free). It does per-material banding + outlines; add a **Custom Pass** (Full Screen, After
  Post Process) with the same Sobel outline for consistency between characters and world.
- **VFX**: **VFX Graph** replaces Niagara one-to-one (flipbooks, strips ≈ ribbons, mesh output,
  shader-graph stepped alpha). HDRP's **Custom Pass** replaces post-process materials.
- **Lighting**: one Directional Light, Physically Based Sky off in favour of a gradient sky material,
  **Exposure Fixed** in the Volume, Tonemapping *Custom* with a flattened curve, Motion Blur off.
- **Code**: `unity/Assets/Scripts/WebSwingController.cs` (Rigidbody pendulum, same maths) and
  `AbilityLoadout.cs` (Rule of Four + Spirit Energy + nature wheel). Use the new Input System's
  `PlayerInput` component to route Move/Swing/Ability1–4.
