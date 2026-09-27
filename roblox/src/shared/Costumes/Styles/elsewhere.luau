--!strict
-- Elsewhere (2 styles, WORLD_OF = "other"): STYLE entries for Costumes.STYLE.
-- Source: docs/design/characters.md §3.0 (palette), §3 "Elsewhere (2)" kit rows, §3.1 (HAT·b/c/n, HP),
-- with the revision-5 recolours applied (Nosebleed). Pure data: no Roblox APIs. Colours are 0xRRGGBB.
--
-- Kit entry fields: the one schema documented in Styles/academy.luau, plus
--   tints     sub-piece colours keyed by sub-code, e.g. HAT {b = brim, c = crown, n = band} (§3.1 HAT·b/c/n)

return {
	eleven = {
		-- +6. Revision 5, 1b: no face marks at all (nothing under the nose, in any phase);
		-- no buzzcut, no pink, no off-white top. Violet glow during techniques.
		name = "Nosebleed",
		preset = "lean",
		height = 0.96,
		colors = {
			skin = 0xf3d6c0,
			hair = 0x2a2230,
			brow = 0x2a2230,
			eye = 0x5a6a5a,
			top = 0x2f8f86,
			sleeves = 0x2f8f86,
			bottom = 0x4a4a3a,
			trim = 0xe8c86a,
			sig = 0xb06cff,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", h = 0.9, variant = "shoulder length" },
			{ "HP", n = 2, tint = 0x2a2a30 }, -- 2 cups + Beam band (0 parts)
			{ "VS", variant = "windbreaker", gui = { kind = "stripe", color = 0xe8c86a } },
		},
		sigPiece = "HP",
		face = { marks = {}, glow = 0xb06cff },
	},

	tophat = {
		-- +12. HAT is §3.1 HAT·b (brim) + HAT·c (crown) + HAT·n (band).
		name = "Top Hat",
		preset = "lean",
		height = 1.02,
		colors = {
			skin = 0xe8d8c8,
			hair = 0x101010,
			brow = 0x101010,
			eye = 0x3a3a44,
			top = 0x181818,
			sleeves = 0x181818,
			bottom = 0x101010,
			trim = 0xe8e4dc,
			sig = 0x9b1a2a,
		},
		kit = {
			{ "FP" },
			{ "HAT", n = 3, tints = { b = 0x101010, c = 0x101010, n = 0x9b1a2a } },
			{ "HC", tint = 0xe8e4dc },
			{ "CT", variant = "tailcoat" },
			{ "Prop", max = 3 },
			{ "GL", n = 2, tint = 0xe8e4dc, variant = "white" }, -- ivory, per the row
		},
		sigPiece = "HAT",
		face = { marks = {} },
		props = { max = 3, default = "pistol" },
	},
}
