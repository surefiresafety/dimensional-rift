// Paste into a Custom node inside the post-process material PP_CelShade.
// Inputs (add as node pins, in this order):  UV (TexCoord[0]), Steps (scalar, 3), Bands (scalar, 0.35),
//                                            ShadowTint (float3, 0.55,0.45,0.75), SpecCut (scalar, 0.92)
// Output: float3. Material Domain = Post Process, Blendable Location = Before Tonemapping.
//
// How it works: PostProcessInput0 is the fully lit scene (Lumen, shadows, everything), BaseColor is
// the unlit albedo from the GBuffer. lit / albedo isolates how much light each pixel received; we
// quantize *that* into flat bands and multiply it back. Lumen's soft bounce becomes clean anime
// shadow shapes, and we never had to touch the shading model or rebuild the engine.

float3 Lit    = SceneTextureLookup(UV, 0 /*PostProcessInput0*/, false).rgb;
float3 Albedo = SceneTextureLookup(UV, 1 /*BaseColor*/,         false).rgb;
float  Depth  = SceneTextureLookup(UV, 4 /*SceneDepth*/,        false).r;
uint   Stencil = (uint)SceneTextureLookup(UV, 25 /*CustomStencil*/, false).r;

// Sky and unlit materials (stencil 0, or very far) pass through untouched.
if (Stencil == 0 || Depth > 1.0e6) return Lit;

float3 Light = Lit / max(Albedo, 0.002);
float  Lum   = dot(Light, float3(0.2126, 0.7152, 0.0722));

// Quantize luminance: Steps bands, biased so mid-tones fall in the lit band (anime faces read flat-lit).
float Stepped = floor(saturate(Lum * 0.8) * Steps + Bands) / Steps;
Stepped = max(Stepped, 0.18);                         // never fully black in shadow

// Keep the light's hue but flatten its intensity.
float3 Toon = Albedo * (Light / max(Lum, 0.001)) * Stepped;

// Cool shadow tint on the darkest band (classic cel look; swap tint per level via MPC).
float ShadowMask = 1.0 - saturate((Stepped - 0.18) / 0.35);
Toon = lerp(Toon, Toon * ShadowTint * 1.6, ShadowMask * 0.6);

// Hard specular "ping" for hair, eyes and metal: stencil bit 2 marks materials that want it.
if ((Stencil & 2u) != 0u && Lum > SpecCut) Toon += 0.35;

return Toon;
