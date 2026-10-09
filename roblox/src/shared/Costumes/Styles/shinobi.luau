--!strict
-- Shinobi Lands (6 styles, WORLD_OF = "naruto"): STYLE entries for Costumes.STYLE.
-- Source: docs/design/characters.md §3.0 (palette), §3 "Shinobi Lands (6)" kit rows, §3.1 (FTH, CLP, SHD),
-- with the lead-approval conditions (Karasu: periwinkle sig, never red; Hatsuyuki: no mask, ring on the
-- right glove) and the revision-5 recolours applied. Pure data: no Roblox APIs. Colours are 0xRRGGBB.
--
-- Kit entry fields: the one schema documented in Styles/academy.luau (n = parts in the entry when the row
-- gives a count, tint/tints, material, side "L"|"R", h/x/w, variant, tail/pouch, max, mount/pos, scale,
-- emblem/at/emblemColor, gui, flash, fx/fxAt), plus:
--   tints     sub-piece colours keyed by role, e.g. {beam = ...} (SHD's 4 Beams)
--   gui.glow  colour the SurfaceGui lights in (LightInfluence 0) on its trigger

return {
	naruto = {
		-- +13. Revision 5, 1a: no face or cheek marks of any kind (no lines, swirls or slashes).
		name = "Ren Tsumuji",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0xf3c9a0,
			hair = 0x3a2a24,
			brow = 0x3a2a24,
			eye = 0x5a7a4a,
			top = 0x2f8f86,
			sleeves = 0x2f8f86,
			bottom = 0xc9b48a,
			trim = 0x2b3350,
			sig = 0xe8b040,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·s", n = 2, tint = 0x2f8f86 },
			{ "HB", tint = 0x2b3350, variant = "cloth, no plate" },
			{ "HB·t" },
			{ "SC", tint = 0xe8b040, side = "L", variant = "long tail streaming left" },
			{ "SB" },
			{ "EM", emblem = "E1", at = "waist", variant = "buckle" },
			{ "GL", n = 2 },
		},
		sigPiece = "SC",
		face = { marks = {} },
	},

	sasuke = {
		-- +11. Amber irises only while a technique is active.
		name = "Kurobane",
		preset = "lean",
		height = 1.02,
		colors = {
			skin = 0xf7dcc0,
			hair = 0x151313,
			brow = 0x151313,
			eye = 0x3a3440,
			top = 0x2a2a34,
			sleeves = 0x2a2a34,
			bottom = 0x3a3f4a,
			trim = 0x3a3f4a,
			sig = 0xe0a83a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·s", n = 3 },
			{ "MT", tint = 0x151313, variant = "raven collar" },
			{ "FTH", n = 2, tint = 0x3a3440 },
			{ "BW", n = 2, variant = "sword across the upper back" },
			{ "SB" },
		},
		sigPiece = "MT",
		face = { marks = {}, glow = 0xe0a83a },
	},

	kakashi = {
		-- +8. Lead condition 2: no mask (LM removed), no eye cover; the copy ring is a SurfaceGui on the
		-- right glove; hair wedges steel teal, sleeves and coat 566a7e, so nothing is pale.
		name = "Hatsuyuki",
		preset = "standard",
		height = 1.04,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x1a1f2e,
			brow = 0x1a1f2e,
			eye = 0x6a5a4a,
			top = 0x223a44,
			sleeves = 0x566a7e,
			bottom = 0x223a44,
			trim = 0x7a6a5a,
			sig = 0x5ad4ff,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·w", n = 2, tint = 0x3a5a6a },
			{ "VS", tint = 0x566a7e, variant = "winter coat" },
			{ "SB" },
			-- cyan E7 ring lights on the right glove while a copied technique is loaded
			{ "GL", n = 2, gui = { kind = "ring", emblem = "E7", side = "R", glow = 0x5ad4ff } },
		},
		sigPiece = "GL",
		face = { marks = {} },
	},

	itachi = {
		-- +8. Lead condition 1: periwinkle sig (clip, FaceGlow); boss FaceGlow is never red.
		-- No collar, no ponytail, no clouds.
		name = "Karasu",
		preset = "lean",
		height = 1.02,
		colors = {
			skin = 0xf0d8c0,
			hair = 0x14141c,
			brow = 0x14141c,
			eye = 0x3a3440,
			top = 0x2a2233,
			sleeves = 0x2a2233,
			bottom = 0x1e1a26,
			trim = 0x3a3440,
			sig = 0x7a8ad8,
		},
		kit = {
			{ "FP" },
			{ "HR", variant = "crop" },
			{ "HR·f", side = "L" },
			{ "CP", tint = 0x2a2233 },
			{ "MT", tint = 0x14141c, variant = "crow mantle" },
			{ "FTH", n = 2, tint = 0x2a2233 },
			-- clip in the forelock; grey-violet ember from the hands (EMITTERS ember, Karasu colour 0x5a5a78)
			{ "CLP", tint = 0x7a8ad8, fx = "ember", fxAt = "hands", fxColor = 0x5a5a78 },
		},
		sigPiece = "CLP",
		face = { marks = {}, glow = 0x7a8ad8 },
	},

	might_guy = {
		-- +9. No bowl cut, no jumpsuit.
		name = "Midori Tetsu",
		preset = "standard",
		height = 1.04,
		colors = {
			skin = 0xe8b88a,
			hair = 0x14100c,
			brow = 0x14100c,
			eye = 0x2a2018,
			top = 0x4a4f58,
			sleeves = 0x4a4f58,
			bottom = 0x4a4f58,
			trim = 0x4f6b3a,
			sig = 0x3ad86a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·k", variant = "topknot" },
			-- 8 belt dots light green one by one as the gates open
			{ "SB", tail = true, gui = { kind = "dots", count = 8, glow = 0x3ad86a } },
			{ "GL", n = 2, tint = 0x8a3a2a },
			{ "WR", n = 2, tint = 0xe8e0d0 },
		},
		sigPiece = "SB",
		face = { marks = {} },
	},

	pain = {
		-- +10. No piercings, no ringed eyes, no rods.
		name = "Gravewell",
		preset = "standard",
		height = 1.02,
		colors = {
			skin = 0xe8d8c8,
			hair = 0x5a5a6a,
			brow = 0x5a5a6a,
			eye = 0x6a5a4a,
			top = 0x2a2a36,
			sleeves = 0x2a2a36,
			bottom = 0x1c1c26,
			trim = 0x5a5a70,
			sig = 0x8a6cff,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·w", n = 2 },
			{ "CP", tint = 0x1c1c26 },
			{ "HC" },
			-- 4 basalt shards orbiting a ring behind the shoulders, joined into a square by 4 Beams
			{
				"SHD",
				n = 4,
				tint = 0x2a2a30,
				material = "Basalt",
				tints = { beam = 0x8a6cff },
				gui = { kind = "edge", glow = 0x8a6cff },
			},
		},
		sigPiece = "SHD",
		face = { marks = {} },
	},
}
