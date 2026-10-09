--!strict
-- Sorcerer's Academy (24 styles): STYLE entries for Costumes.STYLE.
-- Source: docs/design/characters.md §3.0 (palette), §3 "Sorcerer's Academy (24)" kit rows,
-- §3.1 (bespoke pieces), with the lead-approval conditions and the revision-5 recolours applied.
-- Pure data: no Roblox APIs. Colours are 0xRRGGBB.
--
-- Kit entry fields (beyond the §6.1 `{code, n?, tint?}`):
--   [1]       kit code exactly as the design writes it (§2.3 / §3.1)
--   n         number of parts in the entry when the row gives a count (×N or (N)); overrides PARTS[code]
--   tint      explicit tint (otherwise §2.9 DEFAULT_TINT); tints = {L=, R=} for sided pairs
--   material  explicit Enum.Material name
--   side      "L" | "R" for a single-sided piece (character's left/right)
--   h, x, w   HR·p panel height, |x| offset of a mirrored pair, and panel width
--   variant   shape note from the row (e.g. "long", "short", "crop", "fin", "branches")
--   tail      SB with its tail (+1 part); pouch = SB pouch count (+1 part each)
--   max       Prop slot: largest arsenal prop in parts (counted in +N)
--   mount/pos attachment and nominal offset when the row overrides the §2.3 default (x mirrored for pairs)
--   scale     per-axis override of the piece's nominal size, e.g. {x = 1.1}
--   emblem    §2.5 emblem id on the piece; at = "front" | "back" | "tail"; emblemColor = stroke override
--   gui       0-part SurfaceGui decoration on the piece: {kind = ..., ...}
--   flash     colour the piece flashes on its trigger
--   fx        §6.5 emitter key; fxAt = where it sits when not on the piece itself
-- face.marks: Frames on the FP canvas (90×55 px, may overflow), {x, y (centre px), w, h, rot (deg, clockwise),
--   color, layer = "base" | "glow"}. Canvas x grows to the viewer's right, i.e. toward the character's LEFT.
-- guis (style level): 0-part SurfaceGuis on R15 parts that are neither FP nor a kit piece.

return {
	gojo = {
		name = "Aoi Hakumei",
		preset = "standard",
		height = 1.08,
		colors = {
			skin = 0xf3d6c0,
			hair = 0x2a3448,
			brow = 0x2a3448,
			eye = 0x6a5a8a,
			top = 0x2a3550,
			sleeves = 0x2a3550,
			bottom = 0x1f2740,
			trim = 0xe8ecf4,
			sig = 0x5ad4ff,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·w", n = 2, tint = 0xbfe8ff, variant = "side-swept" },
			{ "OR", n = 3 },
			{ "VS", variant = "coat" },
			{ "LP", tint = 0xe8ecf4 },
			{ "CT" },
			{ "GL", n = 1, side = "L" },
		},
		sigPiece = "OR",
		-- FaceGlow cyan only while the `Infinity` attribute is true; resting iris is colors.eye.
		face = { marks = {}, glow = 0x5ad4ff },
	},

	sukuna = {
		-- Lead condition 1: no red eyes; amber sig, indigo-charcoal cloth, amber hair wedges and crack.
		name = "Akuro",
		preset = "standard",
		height = 1.04,
		colors = {
			skin = 0xf2d6c6,
			hair = 0x2a1a1c,
			brow = 0x2a1a1c,
			eye = 0xc8782a,
			top = 0x1c1a2a,
			sleeves = 0x1c1a2a,
			bottom = 0x14121c,
			trim = 0x3a3450,
			sig = 0xe0a030,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·w", n = 2, tint = 0xc8782a, variant = "swept-back" },
			{ "XA", n = 4 },
			{ "VS", variant = "crossover robe" },
			{ "SB", tail = true, tint = 0x3a3450 },
		},
		sigPiece = "XA",
		face = {
			-- one jagged crack from the left temple to the jaw, 3 Frames; nothing under the eyes
			marks = {
				{ x = 82, y = 15, w = 3, h = 15, rot = 16, color = 0xc8782a, layer = "base" },
				{ x = 83, y = 28, w = 3, h = 13, rot = -27, color = 0xc8782a, layer = "base" },
				{ x = 82, y = 42, w = 3, h = 18, rot = 27, color = 0xc8782a, layer = "base" },
			},
		},
	},

	yuji = {
		name = "Haru Takane",
		preset = "standard",
		height = 1,
		colors = {
			skin = 0xf3c9a0,
			hair = 0xc8a070,
			brow = 0x8a6a4a,
			eye = 0x8a4a2a,
			top = 0x22283a,
			sleeves = 0x22283a,
			bottom = 0x22283a,
			trim = 0xc8a03a,
			sig = 0xd8683a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{
				"HD·d",
				tint = 0xc8a03a,
				gui = { kind = "patch", side = "L", w = 60, h = 40, fill = 0x9b1a2a, border = "E11", color = 0xe8e0d0 },
			},
			{ "HC" },
			{ "GL", n = 2, tint = 0xe8e0d0, variant = "knuckle tape" },
			{ "Prop", max = 2 },
		},
		sigPiece = "HD·d",
		face = { marks = {} },
		props = { max = 2, default = "fists" },
	},

	megumi = {
		name = "Kage Inukai",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0xf7dcc0,
			hair = 0x1e2230,
			brow = 0x1e2230,
			eye = 0x5a8a7a,
			top = 0x2a3238,
			sleeves = 0x2a3238,
			bottom = 0x2a3238,
			trim = 0x2a2e3a,
			sig = 0x4a9a88,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·s", n = 3 },
			{ "MT", tint = 0x2a2e3a, variant = "wolf pelt", fx = "shadow", fxAt = "feet" },
			{ "EP", n = 2, tint = 0x2a2e3a, variant = "ears", mount = "NeckAttachment", pos = { 0.55, 0.3, 0.2 } },
			{ "HC" },
		},
		sigPiece = "MT",
		face = { marks = {} },
	},

	toji = {
		name = "Zero",
		preset = "standard",
		height = 1.04,
		colors = {
			skin = 0xe8c8a0,
			hair = 0x141418,
			brow = 0x141418,
			eye = 0x4a5a4a,
			top = 0x16161c,
			sleeves = 0x16161c,
			bottom = 0x2a2a30,
			trim = 0x3a3a42,
			sig = 0x9fe870,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "Prop", max = 3 },
			{ "SB", pouch = 2 },
			{ "GL", n = 2, variant = "fingerless" },
		},
		sigPiece = "Prop",
		face = {
			-- scar on the left brow: 1 Frame 3×14 at 15°
			marks = {
				{ x = 72, y = 11, w = 3, h = 14, rot = 15, color = 0xc89a80, layer = "base" },
			},
		},
		props = { max = 3, default = "spear_chain" },
	},

	kashimo = {
		name = "Ikazuchi",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x1e2230,
			brow = 0x1e2230,
			eye = 0xd8b84a,
			top = 0x2e3a4a,
			sleeves = 0x2e3a4a,
			bottom = 0x22262e,
			trim = 0x8a94a0,
			sig = 0xf0d27a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", h = 1.5, variant = "long" },
			{ "TIP", tint = 0xf0d27a },
			{ "SB", tail = true },
			{ "STF", tint = 0x4a3a2a, material = "Wood", fx = "spark", fxAt = "tips" },
		},
		sigPiece = "STF",
		face = { marks = {} },
	},

	geto = {
		name = "Hoshiro Genma",
		preset = "standard",
		height = 1.04,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x2a1e2e,
			brow = 0x2a1e2e,
			eye = 0x6a4a7a,
			top = 0x2a2030,
			sleeves = 0x2a2030,
			bottom = 0x1a1622,
			trim = 0x8a7ab0,
			sig = 0xb06cff,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", h = 0.8, variant = "low tail" },
			{ "VS", variant = "long open coat" },
			{ "LP", tint = 0x8a7ab0, gui = { kind = "beads", color = 0x8a7ab0 } },
			{ "ORB", tint = 0xb06cff, material = "Neon" },
		},
		sigPiece = "ORB",
		face = { marks = {} },
	},

	kenjaku = {
		-- Lead condition 3: no bun, no face or neck stitches; crop with a low HR·p tail.
		name = "Nuime",
		preset = "standard",
		height = 1,
		colors = {
			skin = 0xe8d8c0,
			hair = 0x1a1a22,
			brow = 0x1a1a22,
			eye = 0xc89a6a,
			top = 0x4a3a4a,
			sleeves = 0x4a3a4a,
			bottom = 0x1a1622,
			trim = 0x2a2430,
			sig = 0xc89a6a,
		},
		kit = {
			{ "FP" },
			{ "HR", variant = "crop" },
			{ "HR·p", h = 0.8, variant = "low tail" },
			{ "HC", tint = 0x2a2430 },
			{ "CT", variant = "robe skirt" },
		},
		sigPiece = nil,
		face = { marks = {} },
		-- signature: cross-stitched right sleeve (0 parts)
		guis = {
			{ host = "RightUpperArm", kind = "crossStitch", color = 0x2a2430 },
		},
	},

	choso = {
		name = "Akagane",
		preset = "standard",
		height = 1.02,
		colors = {
			skin = 0xf0d2b8,
			hair = 0x3a1a1a,
			brow = 0x3a1a1a,
			eye = 0x6a3a3a,
			top = 0x2a1a20,
			sleeves = 0x2a1a20,
			bottom = 0x1a1218,
			trim = 0x5a4a4a,
			sig = 0x9b1a2a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·w", n = 1, side = "R", variant = "swept-back" },
			{ "VS", variant = "coat" },
			{ "GL", n = 2, tint = 0x5a4a4a, variant = "bracers" },
			{ "VL", n = 2, tint = 0x9b1a2a, material = "Neon" },
		},
		sigPiece = "VL",
		face = {
			-- a crimson chevron on each cheek (2 bars at ±35° each); no nose stripe
			marks = {
				{ x = 17, y = 31, w = 10, h = 3, rot = 35, color = 0x9b1a2a, layer = "base" },
				{ x = 25, y = 31, w = 10, h = 3, rot = -35, color = 0x9b1a2a, layer = "base" },
				{ x = 65, y = 31, w = 10, h = 3, rot = 35, color = 0x9b1a2a, layer = "base" },
				{ x = 73, y = 31, w = 10, h = 3, rot = -35, color = 0x9b1a2a, layer = "base" },
			},
		},
	},

	mahito = {
		-- Revision 5 (1c): plum hair, no pale or blue-grey skin, jade seam.
		-- Lead condition 3: no seam mark on the neck, so the row's neck seam E11 is not drawn.
		name = "Patchwork",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0xd8c0a8,
			hair = 0x3a1e34,
			brow = 0x3a1e34,
			eye = 0xa8883a,
			top = 0x5a4636,
			sleeves = 0x8a6244, -- per-limb values in `limbs`
			bottom = 0x4a5a3a, -- per-limb values in `limbs`
			trim = 0xc8a878,
			sig = 0x5ae0a0,
		},
		limbs = {
			LeftArm = 0x8a6244,
			RightArm = 0xd8c0a8,
			LeftLeg = 0x4a5a3a,
			RightLeg = 0x6a3a4a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", h = 0.9, variant = "strand" },
			{ "FS", n = 2, tint = 0xd8c0a8 },
			{
				"PLT",
				n = 2,
				tints = { L = 0xd8c0a8, R = 0x8a6244 },
				gui = { kind = "edge", emblem = "E11", color = 0x3a1e34 },
			},
			{ "SEAM", tint = 0x5ae0a0, material = "Neon" },
		},
		sigPiece = "FS",
		face = { marks = {} },
	},

	jogo = {
		name = "Kazan",
		preset = "standard",
		height = 0.95,
		colors = {
			skin = 0x2a1a18,
			hair = 0x2a1a18,
			brow = 0x2a1a18,
			eye = 0xff9a3a,
			top = 0x4a3a34,
			sleeves = 0x4a3a34,
			bottom = 0x2e2624,
			trim = 0x3a2a24,
			sig = 0xff9a3a,
		},
		kit = {
			{ "FP" },
			{ "CR", tint = 0x3a2a24, material = "Basalt", variant = "rock crown", fx = "smoke" },
			{ "VS", variant = "robe" },
		},
		sigPiece = "CR",
		face = { marks = {}, glow = 0xff9a3a }, -- ember FaceGlow
		guis = {
			{ host = "Head", kind = "lavaCrack", color = 0xff9a3a },
		},
	},

	hanami = {
		name = "Thornbloom",
		preset = "standard",
		height = 1.1,
		colors = {
			skin = 0x6a5a44,
			hair = 0x3a2a1a,
			brow = 0x3a2a1a,
			eye = 0xe8c05a,
			top = 0x4f6b3a,
			sleeves = 0x6a5a44,
			bottom = 0x3f4a2a,
			trim = 0x5b4a3a,
			sig = 0xff8ae0,
		},
		kit = {
			{ "FP" },
			{ "HN", tint = 0x5b4a3a, variant = "branches" },
			{ "LF", tint = 0x4f6b3a },
			{ "VS", tint = 0x5b4a3a, material = "Wood", variant = "bark" },
			{ "SG", n = 2, tint = 0x5b4a3a, material = "Wood", variant = "bark" },
			{ "BLM", tint = 0xff8ae0, material = "SmoothPlastic" },
		},
		sigPiece = "BLM",
		face = { marks = {} },
	},

	dagon = {
		name = "Tidehollow",
		preset = "heavy",
		height = 1.05,
		colors = {
			skin = 0x9ac8c0,
			hair = 0x9ac8c0,
			brow = 0x5a8a88,
			eye = 0xe8c85a,
			top = 0x3a6a5a,
			sleeves = 0x9ac8c0,
			bottom = 0x2a4a44,
			trim = 0xe8a07a,
			sig = 0x7ae0c8,
		},
		kit = {
			{ "FP" },
			{ "EP", n = 1, tint = 0x5a8a88, variant = "fin", fx = "drip" },
			{ "MT", tint = 0xe8a07a, variant = "coral shell" },
			{ "TSL", n = 2, tint = 0xe8a07a },
		},
		sigPiece = "EP",
		face = { marks = {} },
	},

	nanami = {
		name = "Overtime",
		preset = "standard",
		height = 1.08,
		colors = {
			skin = 0xf0d2ae,
			hair = 0x4a3a2a,
			brow = 0x4a3a2a,
			eye = 0x6a5a3a,
			top = 0x3a3a42,
			sleeves = 0x3a3a42,
			bottom = 0x3a3a42,
			trim = 0xe8e4dc,
			sig = 0xd8b46a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HC", tint = 0xe8e4dc, variant = "shirt collar" },
			{ "TIE", tint = 0x6a4a2a, gui = { kind = "stripes", bars = 3, rot = 30, color = 0x8a6a4a } },
			{ "BLD", tint = 0x9aa4b0, material = "Metal", gui = { kind = "gripWrap", bands = 3, color = 0x3a3a42 } },
			{ "WCH", tint = 0xd8b46a, material = "Metal" },
		},
		sigPiece = "WCH",
		face = { marks = {} },
	},

	nobara = {
		name = "Hammer Maiden",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x4a2a3a,
			brow = 0x4a2a3a,
			eye = 0x6a4a3a,
			top = 0x252c40,
			sleeves = 0x252c40,
			bottom = 0x3a3438,
			trim = 0x6a5a4a,
			sig = 0xe8a04a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", n = 2, h = 0.7, x = 0.3, w = 0.5, variant = "bob panels" },
			{ "SB", pouch = 1, gui = { kind = "nails", count = 3, color = 0x9aa4b0, glow = 0xe8a04a } },
			{ "HMR", n = 2, tints = { s = 0x5a4a3a, h = 0x9aa4b0 } }, -- HMR·s Wood handle, HMR·h Metal head
		},
		sigPiece = "HMR",
		face = { marks = {} },
	},

	toge = {
		name = "Kotodama",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x2a2a34,
			brow = 0x2a2a34,
			eye = 0x6a7a8a,
			top = 0x252c40,
			sleeves = 0x252c40,
			bottom = 0x161a26,
			trim = 0x3a4258,
			sig = 0x2fb7a8,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·w", n = 1, side = "R", tint = 0x2fb7a8, variant = "streak" },
			{ "CK", gui = { kind = "grille" }, flash = 0x2fb7a8 },
			{ "VS" },
		},
		sigPiece = "CK",
		face = { marks = {} }, -- mouth uncovered
	},

	maki = {
		name = "Rin Hoshigane",
		preset = "lean",
		height = 1.04,
		colors = {
			skin = 0xf0d2b0,
			hair = 0x5a2a24,
			brow = 0x5a2a24,
			eye = 0x6a4a3a,
			top = 0x252c40,
			sleeves = 0x252c40,
			bottom = 0x161a26,
			trim = 0x3a3f4a,
			sig = 0xd89a3a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", h = 1.1, variant = "ponytail" },
			{ "VB", tint = 0xd89a3a },
			{ "SG", n = 1, side = "L" },
			{ "Prop", max = 3 },
			{ "GL", n = 2 },
		},
		sigPiece = "Prop",
		face = { marks = {} },
		props = { max = 3, default = "naginata" },
	},

	naoya = {
		name = "Framerate",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x14161c,
			brow = 0x14161c,
			eye = 0x6a7488,
			top = 0x1a1a24,
			sleeves = 0x1a1a24,
			bottom = 0x14141c,
			trim = 0x3a4a5a,
			sig = 0x8ad0e0,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{
				"HR·p",
				n = 2,
				h = 0.9,
				x = 0.3,
				w = 0.5,
				tint = 0x14161c,
				gui = { kind = "tipBands", frac = 0.2, color = 0x6a8a9a },
			},
			{ "SC", emblem = "E8", at = "tail", emblemColor = 0x8ad0e0 },
			{ "SB" },
		},
		sigPiece = "SC",
		face = { marks = {} },
	},

	yuta = {
		name = "Rei Tsukiyo",
		preset = "lean",
		height = 1.02,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x14141a,
			brow = 0x14141a,
			eye = 0x4a4a5a,
			top = 0x3a3e4a,
			sleeves = 0x3a3e4a,
			bottom = 0x22283a,
			trim = 0x6a7a9a,
			sig = 0x9fd6ff,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·s", n = 2 },
			{ "BW", n = 2, variant = "katana" },
			{ "HC", gui = { kind = "edge", color = 0x6a7a9a } },
			{ "WSP", tint = 0x9fd6ff, material = "Neon", fx = "wind" },
		},
		sigPiece = "WSP",
		face = { marks = {} },
	},

	ishigori = {
		name = "Gankyu",
		preset = "heavy",
		height = 1.15,
		colors = {
			skin = 0xe0b088,
			hair = 0x3a2a1a,
			brow = 0x3a2a1a,
			eye = 0x6a4a2a,
			top = 0x2a2a30,
			sleeves = 0xe0b088,
			bottom = 0x2a2a30,
			trim = 0x5a5a64,
			sig = 0xffd54a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "FLT" },
			{ "VS", variant = "sleeveless" },
			{ "CN", tint = 0x4a4f58, material = "Metal" },
			{ "MZ", tint = 0xffd54a, material = "Neon" },
			{ "GL", n = 2 },
		},
		sigPiece = "CN",
		face = { marks = {} },
	},

	uro = {
		name = "Skyfold",
		preset = "standard",
		height = 1,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x1a1a24,
			brow = 0x1a1a24,
			eye = 0x5a7a9a,
			top = 0x4a5a7a,
			sleeves = 0x4a5a7a,
			bottom = 0x2a2a36,
			trim = 0xe8c0a0,
			sig = 0xffd8a0,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", h = 1.2 },
			{ "MT", tint = 0xe8c0a0, variant = "shawl" },
			{ "EDG", tint = 0xffd8a0, material = "Neon" },
			{ "SB" },
		},
		sigPiece = "MT",
		face = { marks = {} },
	},

	todo = {
		name = "Tetsuo Hakushu",
		preset = "heavy",
		height = 1.15,
		colors = {
			skin = 0x8a6244,
			hair = 0x14141c,
			brow = 0x14141c,
			eye = 0x2a2018,
			top = 0x1b1b24,
			sleeves = 0x8a6244,
			bottom = 0x1b1b24,
			trim = 0xc8a44a,
			sig = 0xd4142a,
		},
		kit = {
			{ "FP" },
			{ "HR", variant = "shaved sides", scale = { x = 1.1 } },
			{ "HR·w", n = 1, x = 0, variant = "crest" }, -- single, centred, rx(+15) only
			{ "EC", side = "R", tint = 0xc8a44a },
			{ "VS", variant = "open jacket" },
			{ "GL", n = 2, tint = 0xe8e0d0, variant = "palm tape", flash = 0xd4142a },
		},
		sigPiece = "EC",
		face = { marks = {} },
	},

	hakari = {
		name = "Jackpot",
		preset = "standard",
		height = 1.06,
		colors = {
			skin = 0xf0d2b8,
			hair = 0x3a2e24,
			brow = 0x3a2e24,
			eye = 0xc8a86a,
			top = 0x1a1a24,
			sleeves = 0x1a1a24,
			bottom = 0x1a1a24,
			trim = 0x2f8a5a,
			sig = 0xffd54a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·w", n = 2, variant = "undercut" },
			{ "HC", tint = 0x2f8a5a },
			{ "CP", tint = 0x14141c, variant = "short" },
			{ "EM", at = "front", gui = { kind = "reels", digits = 3 } },
		},
		sigPiece = "EM",
		face = { marks = {} },
	},

	yuki = {
		name = "Supernova",
		preset = "standard",
		height = 1.02,
		colors = {
			skin = 0xf7dcc0,
			hair = 0x6a2a2a,
			brow = 0x6a2a2a,
			eye = 0x8a6a4a,
			top = 0x2a2436,
			sleeves = 0x2a2436,
			bottom = 0x2a2436,
			trim = 0xa88aff,
			sig = 0xa88aff,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", h = 1.5, variant = "long" },
			{ "VS", variant = "biker jacket" },
			{ "SC", tint = 0xa88aff },
			{ "EM", emblem = "E10", at = "back" },
			{ "GL", n = 2 },
		},
		sigPiece = "EM",
		face = { marks = {} },
	},
}
