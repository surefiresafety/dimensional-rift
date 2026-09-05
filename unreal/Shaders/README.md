# Post-process shaders

Two Custom-node HLSL snippets for the cel-shaded look. Both live in Post Process Materials
(Material Domain = Post Process, Blendable Location = **Before Tonemapping**) that you add to the
level's Post Process Volume under *Rendering Features > Post Process Materials*.

| File | Material | Blendable priority |
| --- | --- | --- |
| `PP_CelShade_Custom.hlsl` | `PP_CelShade` | 0 |
| `PP_Outline_Custom.hlsl` | `PP_Outline` | 1 (runs after cel shade) |

Setup once per project:

1. Project Settings > Rendering > **Custom Depth-Stencil Pass = Enabled with Stencil** (already in `Config/DefaultEngine.ini`).
2. Every character and prop mesh that should be toon-shaded: *Render CustomDepth Pass = true*, *CustomDepth Stencil Value* = 1. Add bit 2 (value 3) for hair/eyes/metal that want the hard specular ping.
3. Sky, VFX, water and UI meshes leave stencil at 0 and are passed through untouched.
4. The SceneTexture ids used by `SceneTextureLookup` are: 0 PostProcessInput0, 1 BaseColor, 4 SceneDepth, 8 WorldNormal, 25 CustomStencil. If a future engine version renumbers them, use the SceneTexture node's dropdown instead of the Custom node.
