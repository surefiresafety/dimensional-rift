--!strict
-- Costumes.STYLE entries for Skyline City (WORLD_OF = "marvel"), 14 styles.
-- Source: docs/design/characters.md §3.0 (palette), §3 "Kit rows: Skyline City", §3.1 (SPL, SM, WG, BA/claw),
-- revision-5 recolours applied (Antidote, Eightfold, Redmaw). Masked figures: skin is the mask or suit colour;
-- HR is skipped under FM or HD. Pure data: loaded by Costumes/init.luau.
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
	-- Threadrunner: +10 (+2 TN while Suit > 0, via suitTN: 12). Spools are the gloves (no GL).
	-- Head shows only skin between hood and LM; no white, no red, no amber, no spider or web marks.
	spiderman = {
		name = "Threadrunner",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0xc89a70,
			hair = 0x2a2a30,
			brow = 0x2a2a30,
			eye = 0x2fb7a8,
			top = 0x2a2f3a,
			sleeves = 0x2a2f3a,
			bottom = 0x2a2f3a,
			trim = 0x3a4250,
			sig = 0x2fb7a8,
		},
		kit = {
			{ "FP" },
			{ "HD", tint = 0x3a4250 }, -- up
			{ "LM", tint = 0x3a4250 },
			{ "GG", tint = 0x2fb7a8, material = "Neon" }, -- round goggles, on the face
			{ "EM", emblem = "E2", at = "BodyFront" },
			{ "SPL", tint = 0x3a4250, gui = { kind = "ring", color = 0x2fb7a8 } },
		},
		sigPiece = "GG",
		face = { marks = {}, hideEyes = true },
		suitTN = true,
		guis = {
			{ kind = "panel", color = 0x2fb7a8, parts = { "UpperTorso" }, face = "Front" },
			{ kind = "panel", color = 0x2fb7a8, parts = { "LeftLowerArm", "RightLowerArm" }, face = "Front" },
		},
	},

	-- Nightshift: +8. Single amber slit plus amber seams (the 60-stud discriminator from Threadrunner).
	insomniac = {
		name = "Nightshift",
		preset = "lean",
		height = 1.02,
		colors = {
			skin = 0x14161e,
			hair = 0x14161e,
			brow = 0x14161e,
			eye = 0xffb347,
			top = 0x14161e,
			sleeves = 0x14161e,
			bottom = 0x14161e,
			trim = 0x2a2e3a,
			sig = 0xffb347,
		},
		kit = {
			{ "FP" },
			{ "FM", variant = "slit", accent = 0xffb347 },
			{ "SM", tint = 0xffb347, material = "Neon" }, -- 4 seams
			{ "EM", emblem = "E2", at = "BodyFront" },
		},
		sigPiece = "FM",
		face = { marks = {}, hideEyes = true },
	},

	-- Voltstep: +8. No red, no white lenses.
	miles = {
		name = "Voltstep",
		preset = "lean",
		height = 1,
		colors = {
			skin = 0x2a1f3a,
			hair = 0x2a1f3a,
			brow = 0x2a1f3a,
			eye = 0xffe45c,
			top = 0x2a1f3a,
			sleeves = 0x2a1f3a,
			bottom = 0x2a1f3a,
			trim = 0x3a2f4a,
			sig = 0xffe45c,
		},
		kit = {
			{ "FP" },
			{ "FM", variant = "slit", accent = 0xffe45c },
			{ "HD" }, -- up
			{ "WR", n = 2, tint = 0xffe45c }, -- electric sneakers
		},
		sigPiece = "WR",
		face = { marks = {}, hideEyes = true },
		guis = {
			{ kind = "zigzag", color = 0xffe45c, parts = { "LeftUpperArm", "RightUpperArm" } },
		},
	},

	-- Ironthread: +14. Four copper back legs, 2 segments each (1.4 + 1.4, Ø0.22).
	ironspider = {
		name = "Ironthread",
		preset = "standard",
		height = 1.04,
		colors = {
			skin = 0x4a4f58,
			hair = 0x4a4f58,
			brow = 0x4a4f58,
			eye = 0x6ad8c8,
			top = 0x4a4f58,
			sleeves = 0x4a4f58,
			bottom = 0x3a3f46,
			trim = 0xc87a3a,
			sig = 0x6ad8c8,
		},
		kit = {
			{ "FP" },
			{ "FM", variant = "blocks", accent = 0x6ad8c8 }, -- 2 lens Blocks
			{ "BA", n = 4, segs = 2, tint = 0xc87a3a, material = "Metal" },
			{ "SG", n = 2 },
		},
		sigPiece = "BA",
		face = { marks = {}, hideEyes = true },
	},

	-- Blackmaw: +7. Reflectance 0.15 on the R15; chest maw with pale-violet teeth. No teardrop eyes, no white.
	venom = {
		name = "Blackmaw",
		preset = "heavy",
		height = 1.15,
		colors = {
			skin = 0x0a0a10,
			hair = 0x0a0a10,
			brow = 0x0a0a10,
			eye = 0xb89aff,
			top = 0x0a0a10,
			sleeves = 0x0a0a10,
			bottom = 0x0a0a10,
			trim = 0x1a1a24,
			sig = 0xb89aff,
		},
		paint = {
			Head = { color = 0x0a0a10, reflectance = 0.15 },
			UpperTorso = { color = 0x0a0a10, reflectance = 0.15 },
			LowerTorso = { color = 0x0a0a10, reflectance = 0.15 },
			LeftUpperArm = { color = 0x0a0a10, reflectance = 0.15 },
			LeftLowerArm = { color = 0x0a0a10, reflectance = 0.15 },
			LeftHand = { color = 0x0a0a10, reflectance = 0.15 },
			RightUpperArm = { color = 0x0a0a10, reflectance = 0.15 },
			RightLowerArm = { color = 0x0a0a10, reflectance = 0.15 },
			RightHand = { color = 0x0a0a10, reflectance = 0.15 },
			LeftUpperLeg = { color = 0x0a0a10, reflectance = 0.15 },
			LeftLowerLeg = { color = 0x0a0a10, reflectance = 0.15 },
			LeftFoot = { color = 0x0a0a10, reflectance = 0.15 },
			RightUpperLeg = { color = 0x0a0a10, reflectance = 0.15 },
			RightLowerLeg = { color = 0x0a0a10, reflectance = 0.15 },
			RightFoot = { color = 0x0a0a10, reflectance = 0.15 },
		},
		kit = {
			{ "FP" },
			{ "FM", variant = "slit", accent = 0xb89aff },
			{ "SG", n = 2, variant = "bulky" },
			{ "TN", n = 2 },
		},
		sigPiece = nil, -- the chest maw (0-part SurfaceGui)
		face = { marks = {}, hideEyes = true, maw = { teeth = 0xd8d0e8 } },
	},

	-- Redmaw: +8. Bone spurs plus three tendrils; chest maw with jagged fangs.
	carnage = {
		name = "Redmaw",
		preset = "standard",
		height = 1.12,
		colors = {
			skin = 0x8a1a5a,
			hair = 0x8a1a5a,
			brow = 0x8a1a5a,
			eye = 0xffb347,
			top = 0x8a1a5a,
			sleeves = 0x8a1a5a,
			bottom = 0x8a1a5a,
			trim = 0x3a0a2a,
			sig = 0xffb347,
		},
		kit = {
			{ "FP" },
			{ "FM", variant = "slit", accent = 0xffb347 },
			{ "FB", n = 2, tint = 0xd8ccb8, material = "SmoothPlastic" }, -- bone spurs
			{ "TN", n = 3 },
		},
		sigPiece = "FB",
		face = { marks = {}, hideEyes = true, maw = { teeth = 0xd8ccb8, jagged = true } },
		guis = {
			{ kind = "veins", color = 0x3a0a2a, parts = { "UpperTorso" }, face = "Front" },
		},
	},

	-- Antidote: +6. Rev 5 item 1d: a lean two-tone field medic (celadon head and torso, deep-teal limbs),
	-- bone pauldrons and plate, mint slit and droplet. No white or near-white, no black, no maw.
	antivenom = {
		name = "Antidote",
		preset = "lean",
		height = 1.04,
		colors = {
			skin = 0xa8c4b0,
			hair = 0xa8c4b0,
			brow = 0xa8c4b0,
			eye = 0x4ae0c0,
			top = 0xa8c4b0,
			sleeves = 0x24585a,
			bottom = 0x24585a,
			trim = 0xd8ccb0,
			sig = 0x4ae0c0,
		},
		kit = {
			{ "FP" },
			{ "FM", variant = "slit", accent = 0x4ae0c0 },
			{ "EM", emblem = "E5", at = "BodyFront", tint = 0xd8ccb0, accent = 0x4ae0c0 }, -- droplet
			{ "SG", n = 2, tint = 0xd8ccb0, material = "SmoothPlastic" }, -- bone
		},
		sigPiece = "EM",
		face = { marks = {}, hideEyes = true },
		guis = {
			{ kind = "veins", color = 0x24585a, parts = { "UpperTorso" }, face = "Front" },
		},
	},

	-- Doctor Eightfold: +14. Four brass arms, 3 parts each (seg 1, seg 2, Neon claw; §3.1 BA/claw).
	-- No green anywhere, no glasses, no monocle, no trench coat, no bowl cut.
	docock = {
		name = "Doctor Eightfold",
		preset = "standard",
		height = 1.05,
		colors = {
			skin = 0xe8c8a0,
			hair = 0x4a3a30,
			brow = 0x4a3a30,
			eye = 0x4a4a3a,
			top = 0x5a4a6a,
			sleeves = 0x5a4a6a,
			bottom = 0x2a2a34,
			trim = 0xb8a078,
			sig = 0xe89a4a,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "BA", n = 4, segs = 3, tint = 0xb8a078, material = "Metal", accent = 0xe89a4a }, -- claw Neon
		},
		sigPiece = "BA",
		face = { marks = {} },
	},

	-- Frost Arm: +8. No lower mask, no long hair, no star; gunmetal arm, not silver.
	winter = {
		name = "Frost Arm",
		preset = "standard",
		height = 1.06,
		colors = {
			skin = 0xe8c8a8,
			hair = 0x3a2e24,
			brow = 0x3a2e24,
			eye = 0x5a7a8a,
			top = 0x22252c,
			sleeves = 0x22252c,
			bottom = 0x16181d,
			trim = 0x2a2d34,
			sig = 0x9fe0ff,
		},
		kit = {
			{ "FP" },
			{ "HR", variant = "crop" },
			{ "GG", variant = "up", tint = 0x2a2d34, accent = 0x9fe0ff }, -- frames, lenses
			{ "MA", side = "right", tint = 0x4a4f58, material = "Metal", accent = 0x9fe0ff }, -- frost seam
			{ "VS" },
			{ "SB", pouches = 1 },
		},
		sigPiece = "MA",
		face = { marks = {} },
	},

	-- Arc Knight: +10. No red and gold, no round reactor; suit keys per §2.6 ARSENAL_PROP.
	ironman = {
		name = "Arc Knight",
		preset = "standard",
		height = 1,
		colors = {
			skin = 0x3a4250,
			hair = 0x3a4250,
			brow = 0x3a4250,
			eye = 0x5ad4ff,
			top = 0x3a4250,
			sleeves = 0x3a4250,
			bottom = 0x3a4250,
			trim = 0xe8e4dc,
			sig = 0x5ad4ff,
		},
		kit = {
			{ "FP" },
			{ "FM", variant = "slit", accent = 0x5ad4ff }, -- helmet
			{ "CO", variant = "diamond", tint = 0x5ad4ff },
			{ "SG", n = 2, tint = 0xe8e4dc },
			-- palm-Neon gauntlets: Ø40 px circle on the Bottom face, LightInfluence 0
			{ "GL", n = 2, tint = 0x3a4250, gui = { kind = "palm", color = 0x5ad4ff, face = "Bottom", glow = true } },
			{ "Prop", max = 2 }, -- warmachine
		},
		sigPiece = "CO",
		face = { marks = {}, hideEyes = true },
		props = true,
	},

	-- Mindflare: +7. No red hair, no green and gold, no firebird.
	jean = {
		name = "Mindflare",
		preset = "lean",
		height = 1.02,
		colors = {
			skin = 0xf7dcc0,
			hair = 0x1e1a2a,
			brow = 0x1e1a2a,
			eye = 0x8a6ab0,
			top = 0x3a2458,
			sleeves = 0x3a2458,
			bottom = 0x2a1a40,
			trim = 0xe0c8ff,
			sig = 0xff8ae0,
		},
		kit = {
			{ "FP" },
			{ "HR" },
			{ "HR·p", h = 1.2 },
			{ "VS", gui = { kind = "trim", color = 0xe0c8ff } },
			{ "CRY", tint = 0xff8ae0, material = "Neon" }, -- 3 orbiting shards
		},
		sigPiece = "CRY",
		face = { marks = {} },
	},

	-- Warden of Mirrors: +7. No silver temples, no high collar, no cape, no red, no gold.
	strange = {
		name = "Warden of Mirrors",
		preset = "standard",
		height = 1.04,
		colors = {
			skin = 0xf0d2b8,
			hair = 0x2a2a32,
			brow = 0x2a2a32,
			eye = 0x6a8a8a,
			top = 0x1f3a3a,
			sleeves = 0x1f3a3a,
			bottom = 0x14202a,
			trim = 0x2e2050,
			sig = 0x9fe0e8,
		},
		kit = {
			{ "FP" },
			{ "HD", tint = 0x2e2050 }, -- up
			{ "MT", tint = 0x2e2050 }, -- hooded mantle
			{ "SB", tint = 0x3a3048 },
			{ "EM", variant = "pendant", tint = 0x9fe0e8, material = "Glass", reflectance = 0.5 }, -- mirror shard
		},
		sigPiece = "EM",
		face = { marks = {} },
	},

	-- Cackler: +8. Beaked plague-mask on a glider. No green or chartreuse, no grin, no long ears, no hood,
	-- no purple. Torso rust, limbs charcoal (via colors).
	goblin = {
		name = "Cackler",
		preset = "standard",
		height = 1,
		colors = {
			skin = 0xe8e0c8,
			hair = 0x2a2a30,
			brow = 0x2a2a30,
			eye = 0xffb347,
			top = 0xc8642a,
			sleeves = 0x2a2a30,
			bottom = 0x2a2a30,
			trim = 0x4a4f58,
			sig = 0xffb347,
		},
		kit = {
			{ "FP" },
			{ "FM", variant = "round", tint = 0xe8e0c8, accent = 0xffb347 }, -- bone mask, Glass lenses
			{ "BK", tint = 0xe8e0c8 },
			{
				"WG",
				tint = 0x4a4f58,
				material = "Metal",
				gui = { kind = "dots", color = 0xffb347, count = 2, glow = true },
			}, -- glider disc
			{ "GL", n = 2 },
		},
		sigPiece = "BK",
		face = { marks = {}, hideEyes = true },
	},

	-- Clawback: +8. Height 1.0 (no short stature), preset head. No stubble, no leather jacket, no yellow,
	-- no cowl.
	wolverine = {
		name = "Clawback",
		preset = "heavy",
		height = 1,
		colors = {
			skin = 0xe8b88a,
			hair = 0x2a2420,
			brow = 0x2a2420,
			eye = 0x3a5a3a,
			top = 0x3a4a3a,
			sleeves = 0x4a5a3a,
			bottom = 0x3a3a34,
			trim = 0x5a4a3a,
			sig = 0xc8d0d8,
		},
		kit = {
			{ "FP" },
			{ "HR", variant = "crop" }, -- short crop, no side flares
			{ "HD·d", tint = 0x4a5a3a }, -- parka hood
			{ "VS", tint = 0x4a5a3a }, -- olive field parka
			{ "GL", n = 2 }, -- bracers
			{ "FB", n = 2, variant = "long", tint = 0xc8d0d8 }, -- long curved, one per arm
		},
		sigPiece = "FB",
		face = { marks = {} },
	},
}

return styles
