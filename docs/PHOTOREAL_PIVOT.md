# Photoreal pivot — asset strategy, VFX direction, swing physics

Moving Dimensional Rift off the cel-shaded look and onto photoreal UE5. This replaces the art
direction in `3D_ANIME_ARPG_GUIDE.md`; the gameplay design in `DESIGN.md` is unaffected.

**Nothing in this document has been compiled or rendered.** There is no UE5 install in this
environment, so every number below is a starting value derived from physics or from published
engine defaults, not something measured in your project. Treat them as first-pass settings.

---

## 0. The problem you are actually taking on

Photoreal humans plus anime abilities is not a rendering problem, it is a consistency problem.
The moment a MetaHuman with real skin shading throws a Rasengan made of stylised sprite flares,
the flares read as fake — not because they are worse than the character, but because they obey
different rules. Everything the player sees must agree on one physical model: the same light
units, the same atmosphere, the same lens.

The rule that makes this tractable: **an ability may be impossible, but its consequences must
be ordinary.** Cursed energy can exist. When it hits a wall, the wall has to spall concrete,
throw dust that settles under gravity, and heat the air enough to shimmer. Players do not check
whether the glow is realistic; they check whether the world reacted correctly. That is where the
VFX budget goes.

Second, unavoidable point: photoreal raises your production cost by roughly an order of
magnitude and your hardware floor with it. A Lumen + Nanite city with MetaHumans is a 30-series
/ current-console target, not a laptop target. The browser build in `web3d/rift3d.html` cannot
follow you here — it stays as the stylised game and the design sandbox.

---

## 1. Asset strategy

### 1.1 MetaHumans for the playable cast

**Use MetaHuman Creator for the human roster, not for the non-human one.** Yuji, Megumi, Nobara,
Maki, Toge, Nanami, Naruto, Sasuke, Kakashi, Peter Parker and Bucky are all MetaHuman candidates.
Sukuna's four arms, Mahito's stitched patchwork, Jogo's volcano head and the symbiotes are not —
they need bespoke topology and should be sculpted in ZBrush/Blender against the MetaHuman
skeleton so they share the animation set.

Pipeline, in the order that actually works:

1. **Build the base in MetaHuman Creator** (free, browser). Get the head and body proportions
   only. Do not try to match hair or costume there.
2. **Export via Quixel Bridge** into a UE5.4+ project. You get the full LOD chain, the facial
   rig with ~800 blendshapes, groom-based hair and the skin material with its dual-lobe
   specular and backscatter already wired.
3. **Replace the hair groom.** MetaHuman's stock grooms are photoreal and generic. Anime
   silhouettes are the single biggest identity cue you have — Gojo's spikes, Nobara's bob,
   Maki's low tail. Author these as Groom assets in Blender/XGen with real strand counts
   (80k–150k for a lead), then dial the strand width down (0.02–0.04 mm) so the silhouette
   stays sharp rather than fluffy. This is where "recognisably the character" is won or lost.
4. **Costume as a separate skeletal mesh** bound to the MetaHuman skeleton, with Chaos Cloth on
   the loose parts (Gojo's coat tails, Geto's kesa, Nanami's jacket vents). Do not model
   clothing into the body mesh — you lose the LOD chain and the cloth sim.
5. **Retarget with IK Retargeter** from your existing animation set. MetaHuman skeletons are
   uniform, so one retargeter chain serves all of them.

**Cost control.** A MetaHuman at LOD0 is roughly 100k triangles plus the groom, and grooms are
expensive. Budget:

| Context | Setting |
|---|---|
| Player character | LOD0, full groom, strand rendering |
| Nearby NPCs (< 15 m) | LOD1–2, groom cards not strands |
| Crowd (> 15 m) | LOD3+, card hair, disable facial rig ticking |
| Crowd (> 40 m) | Switch to a baked static/vertex-animated impostor |

Set `Enable LOD Sync` off and drive facial LOD independently — a face rig ticking on 40 crowd
members will cost you more than the geometry ever does.

### 1.2 Megascans for New York

Megascans is free with an Epic account for UE use. The trap is that it gives you superb
*materials* and *props* and almost no *architecture* — there are no skyscrapers in the library.
So split the problem:

**Buildings: modular kit, Megascans surfaces.** Author 6–8 building shells as modular kits
(ground floor, mid floors, cornice, roof) in Blender at real scale — a Manhattan floor is
~3.6 m, a mid-block tower 20–40 floors. Keep them low-poly; Nanite makes the trim and detail
cheap, but the shells should stay simple so instancing works. Then dress every surface with
Megascans:

- `Concrete Wall`, `Weathered Brick`, `Painted Metal Panel` for facades
- Displacement on Nanite meshes for real brick relief rather than a normal map, which falls
  apart at the grazing angles a swinging camera constantly produces
- `Asphalt`, `Road Markings`, `Manhole`, `Kerb` for street level
- Decal layers for grime runs under sills, water staining, tar patching. Grime under a sill is
  the single cheapest thing that makes a fake building read as real.

**Street dressing: this is where Megascans earns its keep.** Scaffolding, dumpsters, fire
hydrants, traffic cones, rubbish bags, cardboard, newspaper boxes, AC units, fire escapes,
puddles. New York is legible from the street furniture, not the towers. Assemble with the
**PCG framework** (UE5.2+): one rule set that scatters bins and cones along kerb splines, one
that puts AC units on facades above floor 2, one for roof clutter. You will do a block in an
afternoon instead of a week.

**Vertical readability.** You are shipping a swinging game, so the player spends most of their
time at 40–120 m looking down. That means roofs matter as much as streets: water towers,
HVAC plant, gravel ballast, skylights, satellite dishes. Budget as much dressing time for roofs
as for pavements. Most city games skip this and it is why they look empty from the air.

**Lighting.** One `Directional Light` (sun) plus `SkyAtmosphere`, `VolumetricCloud` and
`ExponentialHeightFog` with volumetric fog on. Set the sun to real physical intensity (~120,000
lux at noon) and light everything else in lumens against it. Lumen for GI and reflections,
Virtual Shadow Maps on. Then set the camera to real exposure values — a photographic pipeline
where every light is in real units is what makes Megascans albedos read correctly, because
they were scanned under known light.

### 1.3 Megascans for the forest

This is the case Megascans was built for, and the Konoha/Land of Fire environments should look
close to free by comparison.

- **Megascans Trees** (the scanned conifer and broadleaf sets) as Nanite meshes. Nanite handles
  foliage from 5.1 — enable it on trunks and branches; leave leaf cards as regular LODs where
  they use masked materials, since masked Nanite is still comparatively costly.
- **Ground:** layered Landscape material with 4–6 Megascans surfaces (forest floor, leaf litter,
  moss, exposed rock, mud) blended by slope and height, plus a runtime virtual texture so decals
  and puddles composite correctly.
- **Scatter:** PCG again — ferns, fallen logs, rocks, saplings driven by a density map you paint.
  Two or three scatter layers at different scales is what kills the "asset store forest" look.
- **The real work is light, not assets.** Forest photorealism is god rays through canopy gaps,
  and that is volumetric fog plus light shafts plus a sun angle low enough to rake. Budget your
  time there.

### 1.4 What to build first

Do not build the city first. Build **one block, one roof, one alley, at final quality**, with
the player character and one ability in it. That vertical slice tells you your real frame budget
and your real art cost, and every later estimate is derived from it. A team that greybox-blocks
all of Manhattan before lighting one corner of it will discover its performance problem six
months too late.

---

## 2. VFX direction

### 2.1 The four rules

Everything below is an application of these:

1. **Real units.** Emissive values in nits, not arbitrary multipliers. A muzzle flash is ~10,000
   nits; a Rasengan should be authored as a light source with an actual intensity and radius, so
   Lumen bounces it onto the walls correctly. If the effect does not light the environment, the
   eye reads it as a decal over the top of the scene.
2. **Refraction over addition.** Cartoon energy is additive glow. Real energy at high density
   bends light: heat shimmer, index-of-refraction distortion, chromatic separation at the edges.
   A distortion pass on a translucent material sells "immense power" far better than making the
   glow brighter, and it survives being seen in daylight.
3. **Secondary reaction is mandatory.** No effect exists alone. Every technique produces: dust
   displacement, debris with real mass, a light contribution, air distortion, and a mark left
   behind. The mark is the part everyone forgets and the part players actually notice.
4. **Sub-frame motion.** Real fast things motion-blur and leave sub-frame trails. Use
   Niagara ribbon renderers with velocity-aligned stretch, and turn motion blur back on
   (`r.DefaultFeature.MotionBlur=True` — the current `DefaultEngine.ini` disables it for the
   cel look, and that must be reverted for this pivot).

### 2.2 Web fluid

The single highest-value effect you have, because it is on screen constantly.

**Material.** Not a glowing line. Web is a translucent, slightly subsurface polymer:
- Base colour near-white with a faint blue-grey tint, roughness 0.25–0.4 — it is wet when fired
  and dries over ~2 s, so drive roughness up over the strand's lifetime.
- Thin-film / subsurface so light passing through it scatters. A backlit web strand should
  glow *by transmission*, not by emissive.
- A tiling fibre normal map along the strand's UV so it reads as twisted filament rather than a
  tube.

**Geometry.** Use a spline mesh or `CableComponent` for the main line and drive it from the
solver above:
- `GetStretchAlpha()` → strand thickness (thins as it stretches, like real polymer under load)
  and a subtle desaturation.
- `GetTensionNewtons()` → a low-amplitude vibration along the strand, plus creak audio.
- On release, do not delete the strand. Let it fall under its own gravity with a short Chaos
  cloth or a simple verlet chain, and stick to whatever it lands on for ~20 s. Streets that
  accumulate your own webbing are the strongest possible signal that the world is persistent.

**Firing.** The shot is a fluid jet, not a projectile: a Niagara ribbon of droplets that
coalesces into the strand over ~80 ms, with a spray of satellite droplets that miss and stick
around the anchor point as decals. Real web fluid would be non-Newtonian — it should string and
sag, never snap taut instantly.

**Impact.** A radial splat decal on the surface with real wetness (roughness drop, slight
darkening) that dries over several seconds.

### 2.3 Fire jutsu

Physically-based fire has three components and stylised fire usually only has one.

- **Combustion**: the luminous zone. Author this as blackbody radiation — map temperature
  (1,200–1,800 K for a wood fire, higher for a directed jet) through a blackbody node to colour,
  so it goes white-yellow at the core and deep orange at the fringes *automatically*. Never
  hand-pick fire colours; the blackbody curve is why real fire looks real.
- **Soot and smoke**: dark, dense, lit by the fire rather than emissive. This is the part that
  sells scale. A Katon should produce far more smoke than flame, and the smoke should rise
  buoyantly and then stall and spread when it cools.
- **Heat distortion**: a refraction-only pass extending well past the visible flame. Air above a
  fire is disturbed long after it stops glowing.

Use **Niagara Fluids** (the free grid-based 2D/3D gas solver plugin) for hero fire — the
`Grid3D Gas` template gives real buoyancy, vorticity and combustion. It is expensive; reserve
it for the ultimate and use particle-based approximations for the standard techniques.

Consequences: scorch decals that persist, ignited props, blackened and warped metal, and
sustained heat shimmer over the affected ground for 10–20 s afterward.

### 2.4 Water jutsu

- **Niagara Fluids `Grid3D Gas` will not do this** — use the FLIP solver in the shipped water
  templates, or, for the big Suiton walls, a pre-simulated mesh cache from Houdini/Blender
  played back as an Alembic. A Water Dragon is exactly the case where a baked sim beats a
  runtime one: it is a hero moment on a fixed timeline.
- **Material**: water is not blue. It is nearly colourless with high specular, strong refraction
  (IOR 1.33) and volumetric absorption that turns it blue-green only at depth. Getting IOR and
  absorption right is 80% of the look.
- **Foam and spray** are separate systems: white, opaque, high-frequency, driven by the sim's
  curl/velocity. Real water reads as water mostly because of its foam.
- **Wetness afterward**: a runtime virtual texture wetness mask painted by the effect, darkening
  albedo and dropping roughness where the water passed, drying over ~30 s.

### 2.5 Spatial distortion — Limitless, Domain Expansion, Kamui

The hardest to keep grounded, and the one where "realistic" means *optically consistent*
rather than *plausible*. There is no real reference, so the discipline is: pick a physical
metaphor and obey it exactly.

**Infinity / Limitless** — metaphor: *gravitational lensing*. A post-process material that
samples the scene texture with a radial UV offset falling off as 1/r², plus chromatic
aberration that increases toward the centre. No colour, no glow, no particles. Things simply
bend around him, and objects thrown at him decelerate asymptotically and never arrive. Rendered
correctly this is more unsettling than any glow, and it is nearly free.

**Hollow Purple** — metaphor: *an object that removes what it touches*. The volume itself should
be near-black with an event-horizon rim (strong Fresnel), with the environment bending inward
around it. Erase geometry with a mesh-cutting decal or a runtime boolean; leave a clean-edged
absence rather than rubble.

**Domain Expansion** — metaphor: *stepping into a different atmosphere*. On entry: swap the
post-process volume, the sky, the fog and the ambient audio all in one frame with a hard cut,
not a fade. The barrier interior gets its own volumetric fog density and its own light rig. The
power reads from the discontinuity — outside is New York at noon, inside is somewhere else
entirely, and the boundary is a hard surface.

**Kamui** — metaphor: *a spiral in space itself*. Radial UV distortion in a spiral, geometry
scaled toward the vanishing point as it is drawn in, and — the detail that sells it — the
*audio* going with it, dopplering and cutting off.

### 2.6 Cursed energy

Give it one consistent physical identity and never break it. Recommendation: treat it as a
**dense, cold, refractive fluid** — dark violet-black, visible mainly by what it distorts,
turbulent like smoke in water, with a faint edge glow only where it is densest. That reads as
alien and dangerous in a photoreal frame, whereas a bright additive glow reads as a video game.

---

## 3. Core code — physics-based swinging

Two implementations now exist in `unreal/Source/DimensionalRift/`:

- **`DRCharacterMovementComponent`** — the stylised one, a custom `CMOVE_Swing` movement mode
  with a rigid rope constraint and 1.5× gravity. Keep it for the arcade build.
- **`DRRealisticSwingComponent`** — new, written for this pivot. A drop-on `UActorComponent`
  that adds rope forces on top of the stock `MOVE_Falling`, so collision, sliding and CMC
  networking keep working untouched.

### 3.1 What makes it physical

| | Approach | Why |
|---|---|---|
| Gravity | 9.80665 m/s², `GravityScale = 1.0` | The component is only honest if the engine under it is |
| Rope | Damped spring (Hooke + damper), pull-only, with a hard stretch ceiling | Real webbing stretches; the stretch-and-recoil at the bottom of the arc is most of what reads as physical |
| Drag | Quadratic, `F = ½ρv²C_dA` | Gives terminal velocity for free and stops arcs accelerating without bound |
| Mass | Real, 78 kg, forces in newtons | Reel and pump forces then have intuitive magnitudes |
| Release | Velocity untouched | The launch you feel is the tangential velocity you already had — no added impulse |
| Integration | Semi-implicit Euler, fixed 240 Hz substep | A stiff spring explodes at variable 30–60 Hz timesteps |

### 3.2 The honest problem with realism here

A 78 kg body on a 25 m line has a pendulum period of 2π√(L/g) ≈ 10 s, so a half-arc takes
about **5 seconds**. That is much slower than any shipped Spider-Man game, and it will feel
sluggish. This is not a bug in the maths, it is what the maths says.

Two levers preserve the look while fixing the feel, because both are *real mechanisms*:

- **`RopeReelForce`** — Spider-Man visibly hauls himself up the line. Shortening the rope
  raises the pendulum frequency (T ∝ √L), so reeling in genuinely speeds the arc up. This is
  the main knob.
- **`PumpAcceleration`** — a body pumping a swing really does add energy; a playground swing is
  the proof.

Raising `GravityScale` above 1.0 also fixes the feel, and it is the one thing that will make an
observer say "that is a game". Leave it at 1.0 and buy your speed from the other two.

### 3.3 Blueprint wiring

Add the component to your character Blueprint, then:

```
Enhanced Input: IA_Swing (Triggered)  → TryAttach(Camera Forward Vector)
Enhanced Input: IA_Swing (Completed)  → Detach
Enhanced Input: IA_Move  (Triggered)  → SetSwingInput(Y, X, ReelAxis)
Enhanced Input: IA_Reel  (Triggered)  → SetSwingInput(fwd, right, 1.0)

OnSwingAttached(Anchor, RestLength) → spawn web strand, set Cable end at Anchor
OnSwingDetached(ReleaseVelocity)   → detach strand, let it fall, play let-go anim
OnSwingFailed(Direction)           → fire a strand that reaches nothing and drops
```

Drive presentation from the two accessors every frame:

```
GetStretchAlpha()    → strand thickness / desaturation, camera FOV push
GetTensionNewtons()  → strand vibration amplitude, creak audio gain, camera shake scale
```

`GetTensionNewtons()` is also the correct input for anchor destruction: when tension exceeds
what a fire escape can take, break it and drop the player. That single behaviour does more for
believability than any amount of shader work.

### 3.4 Settings that must change from the cel-shaded config

`unreal/Config/DefaultEngine.ini` is currently tuned for the stylised look. For this pivot:

```ini
r.DefaultFeature.MotionBlur=True          ; was False — photoreal needs sub-frame motion
r.DefaultFeature.AutoExposure=True        ; was False — physical camera response
r.DefaultFeature.AmbientOcclusion=True    ; was False
r.Lumen.TraceMeshSDFs=1                   ; was 0 — restore accurate near-field GI
r.Shadow.Virtual.Enable=1                 ; keep
r.Nanite.ProjectEnabled=True              ; keep
```

And remove the cel post-process chain (`Shaders/PP_CelShade_Custom.hlsl`,
`PP_Outline_Custom.hlsl`) from the global post-process volume. Keep the files; the arcade build
still needs them.

---

## 4. Suggested order of work

1. Revert the engine config above and delete the cel post-process from the photoreal map only.
2. Build one Manhattan block at final quality — street, alley, one roof — lit physically.
3. Drop one MetaHuman in it with the retargeted locomotion set.
4. Add `DRRealisticSwingComponent` and tune `RopeReelForce` until the arc feels right with
   `GravityScale` pinned at 1.0.
5. Author the web fluid material and strand system against that block. It is on screen more
   than anything else you will build.
6. Only then start on abilities, and start with the one that has the most secondary reaction
   (a fire technique), because that is what proves the "consequences must be ordinary" rule.
