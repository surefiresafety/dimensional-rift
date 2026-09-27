--!strict
-- Costumes.STYLE entries for Elsewhere (WORLD_OF = "other"), 2 styles.
-- Source: docs/design/characters.md §3.0 (palette), §3 "Kit rows: Elsewhere", §3.1 (HAT·b/c/n, HP),
-- revision-5 recolours applied (Nosebleed). Pure data: loaded by Costumes/init.luau.
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
	-- Nosebleed: +6. Rev 5 item 1b: no face marks at all (nothing under the nose, in any phase);
	-- no buzzcut, no pink, no off-white top. Violet glow during techniques.
	eleven = {
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
			{ "HR·p", h = 0.9 }, -- shoulder length
			{ "HP", tint = 0x2a2a30 }, -- 2 cups + Beam band
			{ "VS", gui = { kind = "stripe", color = 0xe8c86a } }, -- windbreaker, mustard stripe
		},
		sigPiece = "HP",
		face = { marks = {}, glow = 0xb06cff },
	},

	-- Top Hat: +12. HAT = §3.1 HAT·b (brim) + HAT·c (crown) in 0x101010 and HAT·n (band) in crimson.
	tophat = {
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
			{ "HAT", tint = 0x101010, accent = 0x9b1a2a },
			{ "HC", tint = 0xe8e4dc },
			{ "CT" }, -- tailcoat
			{ "Prop", max = 3 },
			{ "GL", n = 2, tint = 0xe8e4dc }, -- white gloves (ivory)
		},
		sigPiece = "HAT",
		face = { marks = {} },
		props = true,
	},
}

return styles
