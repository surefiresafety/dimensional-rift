// Paste into a Custom node in PP_Outline (Post Process, Before Tonemapping, run AFTER PP_CelShade
// by giving it a higher Blendable Priority). Inputs: UV, LineWidth (scalar, 1.5), DepthK (scalar, 0.12),
// NormalK (scalar, 0.6), LineColor (float3, 0.05,0.03,0.08)
// Output: float3
//
// Sobel edges on depth + world normal + custom stencil. Depth edges give silhouettes, normal edges give
// interior creases (jaw, collar, folds), stencil edges guarantee a line between two characters that
// overlap at similar depth. Pair with an inverted-hull outline on characters for the thick "ink" line.

float2 Px = LineWidth * View.ViewSizeAndInvSize.zw;

float  D[9]; float3 N[9]; float S[9];
int i = 0;
[unroll] for (int y = -1; y <= 1; ++y)
[unroll] for (int x = -1; x <= 1; ++x)
{
    float2 P = UV + float2(x, y) * Px;
    D[i] = SceneTextureLookup(P, 4 /*SceneDepth*/, false).r;
    N[i] = SceneTextureLookup(P, 8 /*WorldNormal*/, false).rgb;
    S[i] = SceneTextureLookup(P, 25 /*CustomStencil*/, false).r;
    ++i;
}

// Sobel kernels
float Gx = (D[2] + 2*D[5] + D[8]) - (D[0] + 2*D[3] + D[6]);
float Gy = (D[6] + 2*D[7] + D[8]) - (D[0] + 2*D[1] + D[2]);
float DepthEdge = sqrt(Gx*Gx + Gy*Gy) / max(D[4], 1.0);     // relative to center depth so far lines don't vanish

float3 NGx = (N[2] + 2*N[5] + N[8]) - (N[0] + 2*N[3] + N[6]);
float3 NGy = (N[6] + 2*N[7] + N[8]) - (N[0] + 2*N[1] + N[2]);
float NormalEdge = length(NGx) + length(NGy);

float StencilEdge = 0;
[unroll] for (int k = 0; k < 9; ++k) StencilEdge += abs(S[k] - S[4]) > 0.5 ? 1 : 0;

float Edge = saturate(DepthEdge / DepthK) + saturate(NormalEdge / NormalK) * 0.6 + saturate(StencilEdge);
Edge = smoothstep(0.35, 0.9, Edge);

// Thinner lines with distance so the far city doesn't turn into a black scribble.
Edge *= saturate(1.0 - D[4] / 25000.0);

float3 Scene = SceneTextureLookup(UV, 0, false).rgb;
return lerp(Scene, LineColor, Edge);
