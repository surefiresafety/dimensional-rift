--!strict
-- Costumes.STYLE entries for the Shinobi Lands (WORLD_OF = "naruto"), 6 styles.
-- Source: docs/design/characters.md §3.0 (palette), §3 "Kit rows: Shinobi Lands", §3.1 (FTH, CLP, SHD),
-- with the lead-approval conditions at the top of that document applied (Hatsuyuki: no mask, ring on
-- the right GL; Karasu: periwinkle sig, never red). Pure data: loaded by Costumes/init.luau.
--
-- Kit entry conventions (shared by every Styles/<universe>.luau):
--   [1]         the kit code exactly as the design writes it (§2.3 / §3.1, with the "·" character)
--   n           repeat count for a "1 each" code (HR·s×2, GL×2, SG×2...). Codes whose own part count
--               already covers the group (FTH 2, SHD 4, SPL 2, SM 4, CRY 3, HP 2, GG 2, HD 3, HB·t 2,
--               SC 2, LP 2, CT 2, XA 4, CR 4, HAT 3) are written once, without n.
--   tint        explicit main colour (otherwise §2.9 DEFAULT_TINT)
--   accent      explicit second colour: FM/GG lenses or slit, MA seam, BA claw, SHD beams, HAT band
--   material, reflectance   explicit material overrides
--   variant     shape variant: "crop", "topknot", "slit" | "blocks" | "round" (FM lenses), "up" (GG pushed
--               up), "long" (FB long curved), "bulky", "diamond" (CO), "sword" (BW), "pendant" (EM)
--   h           HR·p panel height;  segs  BA segments per arm (2 or 3)
--   tail, pouches  SB extras (+1 part each);  side  "left"/"right" for one-sided pieces
--   emblem, at  EM emblem id (E1..E11) and anchor ("BodyFront" | "BodyBack" | "WaistFront")
--   max         Prop slot, counted at its largest prop
--   gui         a SurfaceGui on the piece: { kind, color, count?, side?, face?, glow? }
-- Style-level extensions beyond §6.1 (colour-bearing, so effectiveLook can see them):
--   guis        SurfaceGuis on R15 parts: { kind, color, parts, face? }
--   emitters    { key, at, color? } (§6.5 EMITTERS keys)
--   face.hideEyes  masked figure: lenses/slits act as the eyes;  face.maw  chest maw (§2.4)

type Gui = {
	kind: string,
	color: number,
	count: number?,
	side: string?,
	face: string?,
	glow: boolean?,
	parts: { string }?,
}

type Entry = {
	[number]: string,
	n: number?,
	tint: number?,
	accent: number?,
	material: string?,
	reflectance: number?,
	variant: string?,
	h: number?,
	segs: number?,
	tail: boolean?,
	pouches: number?,
	side: string?,
	emblem: string?,
	at: string?,
	max: number?,
	gui: Gui?,
}

type Colors = {
	skin: number,
	hair: number,
	brow: number,
	eye: number,
	top: number,
	sleeves: number,
	bottom: number,
	trim: number,
	sig: number,
}

type Face = {
	marks: { { [string]: any } },
	glow: number?,
	hideEyes: boolean?,
	maw: { teeth: number, jagged: boolean? }?,
}

type Style = {
	name: string,
	preset: string,
	height: number,
	browAngle: number?,
	colors: Colors,
	limbs: { [string]: number }?,
	paint: { [string]: { color: number, material: string?, reflectance: number? } }?,
	kit: { Entry },
	sigPiece: string?,
	face: Face,
	props: boolean?,
	suitTN: boolean?,
	guis: { Gui }?,
	emitters: { { key: string, at: string, color: number? } }?,
}

local styles: { [string]: Style } = {
	-- Ren Tsumuji: +13. No face or cheek marks of any kind (rev 5, item 1a).
	naruto = {
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
			{ "HB", tint = 0x2b3350 }, -- cloth, no plate
			{ "HB·t" },
			{ "SC", tint = 0xe8b040, side = "left" }, -- long amber tail streaming left
			{ "SB" },
			{ "EM", emblem = "E1", at = "WaistFront" }, -- buckle
			{ "GL", n = 2 },
		},
		sigPiece = "SC",
		face = { marks = {} },
	},

	-- Kurobane: +11. Amber irises only while a technique is active.
	sasuke = {
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
			{ "MT", tint = 0x151313 }, -- raven collar
			{ "FTH", tint = 0x3a3440 }, -- the pair of upswept feathers (2 parts)
			{ "BW", variant = "sword" }, -- across the upper back, hilt + blade (2)
			{ "SB" },
		},
		sigPiece = "MT",
		face = { marks = {}, glow = 0xe0a83a },
	},

	-- Hatsuyuki: +8. Lead condition 2: no mask (LM removed), no eye cover; the copy ring is a
	-- SurfaceGui on the right glove; hair wedges steel teal; sleeves and coat 4a5a6a.
	kakashi = {
		name = "Hatsuyuki",
		preset = "standard",
		height = 1.04,
		colors = {
			skin = 0xf3d6b8,
			hair = 0x1a1f2e,
			brow = 0x1a1f2e,
			eye = 0x6a5a4a,
			top = 0x223a44,
			sleeves = 0x4a5a6a,
			bottom = 0x223a44,
			trim = 0x7a6a5a,
			sig = 0x5ad4ff,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·w", n = 2, tint = 0x3a5a6a },
			{ "VS", tint = 0x4a5a6a }, -- winter coat
			{ "SB" },
			-- cyan E7 ring lights on the right glove while a copied technique is loaded
			{ "GL", n = 2, gui = { kind = "E7", color = 0x5ad4ff, side = "right", glow = true } },
		},
		sigPiece = "GL",
		face = { marks = {} },
	},

	-- Karasu: +8. Lead condition 1: sig periwinkle, clip, FaceGlow and ember never red.
	-- No collar, no ponytail, no clouds.
	itachi = {
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
			{ "HR·f", side = "left" },
			{ "CP", tint = 0x2a2233 },
			{ "MT", tint = 0x14141c }, -- crow mantle
			{ "FTH", tint = 0x2a2233 },
			{ "CLP", tint = 0x7a8ad8 }, -- clip in the forelock
		},
		sigPiece = "CLP",
		face = { marks = {}, glow = 0x7a8ad8 },
		emitters = { { key = "ember", at = "hands", color = 0x5a5a78 } }, -- grey-violet
	},

	-- Midori Tetsu: +9. No bowl cut, no jumpsuit.
	might_guy = {
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
			{ "SB", tail = true, gui = { kind = "dots", color = 0x3ad86a, count = 8, glow = true } },
			{ "GL", n = 2, tint = 0x8a3a2a },
			{ "WR", n = 2, tint = 0xe8e0d0 },
		},
		sigPiece = "SB",
		face = { marks = {} },
	},

	-- Gravewell: +10. No piercings, no ringed eyes, no rods.
	pain = {
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
			-- 4 basalt shards orbiting behind the shoulders, joined into a square by 4 Beams
			{
				"SHD",
				tint = 0x2a2a30,
				material = "Basalt",
				accent = 0x8a6cff,
				gui = { kind = "edge", color = 0x8a6cff, glow = true },
			},
		},
		sigPiece = "SHD",
		face = { marks = {} },
	},
}

return styles
