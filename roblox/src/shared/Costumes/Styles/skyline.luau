--!strict
-- Skyline City (14 styles, WORLD_OF = "marvel"): STYLE entries for Costumes.STYLE.
-- Source: docs/design/characters.md §3.0 (palette), §3 "Skyline City (14)" kit rows, §3.1 (SPL, SM, WG,
-- BA/claw), with the revision-5 recolours applied (Antidote, Doctor Eightfold, Redmaw, Clawback).
-- Masked figures: `skin` is the mask or suit colour; HR is skipped under FM or HD.
-- Pure data: no Roblox APIs. Colours are 0xRRGGBB.
--
-- Kit entry fields: the one schema documented in Styles/academy.luau, plus
--   tints        sub-piece colours keyed by role: FM {slit} or {lens}, GG {lens}, MA {seam}, BA {claw}
--   segs         BA segments per arm (2, or 3 with the §3.1 claw)
--   reflectance  explicit Reflectance
--   gui.glow     colour the SurfaceGui lights in (LightInfluence 0)
-- and on `face`:
--   hideEyes     masked figure: whites and irises hidden, the lenses or slit act as the eyes (§3 Skyline)
--   maw          chest maw (§2.4): band in colors.trim, teeth colour, jagged fangs

return {
	spiderman = {
		-- +10, 12 with the suit (2 TN via suitTN while Suit > 0). The spools are the gloves (no GL).
		-- The head shows only skin between hood and LM; no white, no red, no amber, no spider or web marks.
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
			{ "HD", tint = 0x3a4250, variant = "up" },
			{ "LM", tint = 0x3a4250 },
			{ "GG", n = 2, tint = 0x2fb7a8, material = "Neon", variant = "round, on the face" },
			{ "EM", emblem = "E2", at = "front" },
			{ "SPL", n = 2, tint = 0x3a4250, gui = { kind = "ring", color = 0x2fb7a8 } },
		},
		sigPiece = "GG",
		face = { marks = {}, hideEyes = true },
		suitTN = true,
		guis = {
			{ host = "UpperTorso", kind = "panel", color = 0x2fb7a8 },
			{ host = "LeftLowerArm", kind = "panel", color = 0x2fb7a8 },
			{ host = "RightLowerArm", kind = "panel", color = 0x2fb7a8 },
		},
	},

	insomniac = {
		-- +8. Single amber slit plus amber seams: the 60-stud discriminator from Threadrunner.
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
			{ "FM", n = 2, variant = "slit", tints = { slit = 0xffb347 } },
			{ "SM", n = 4, tint = 0xffb347, material = "Neon" },
			{ "EM", emblem = "E2", at = "front" },
		},
		sigPiece = "FM",
		face = { marks = {}, hideEyes = true },
	},

	miles = {
		-- +8. No red, no white lenses.
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
			{ "FM", n = 2, variant = "slit", tints = { slit = 0xffe45c } },
			{ "HD", variant = "up" },
			{ "WR", n = 2, tint = 0xffe45c, variant = "electric sneakers" },
		},
		sigPiece = "WR",
		face = { marks = {}, hideEyes = true },
		guis = {
			-- zigzag seams "on the arms"
			{ host = "LeftUpperArm", kind = "zigzag", color = 0xffe45c },
			{ host = "RightUpperArm", kind = "zigzag", color = 0xffe45c },
		},
	},

	ironspider = {
		-- +14. Four copper back legs, 2 segments each (1.4 + 1.4, Ø0.22).
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
			{ "FM", n = 3, variant = "2 lens Blocks", tints = { lens = 0x6ad8c8 } },
			{ "BA", n = 8, segs = 2, tint = 0xc87a3a, material = "Metal" },
			{ "SG", n = 2 },
		},
		sigPiece = "BA",
		face = { marks = {}, hideEyes = true },
	},

	venom = {
		-- +7. Reflectance 0.15 on the R15. No teardrop eyes, no white.
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
			{ "FM", n = 2, variant = "slit", tints = { slit = 0xb89aff } },
			{ "SG", n = 2, variant = "bulky" },
			{ "TN", n = 2 },
		},
		sigPiece = nil, -- signature: the chest maw (0-part SurfaceGui)
		face = { marks = {}, hideEyes = true, maw = { teeth = 0xd8d0e8 } },
	},

	carnage = {
		-- +8. Bone spurs plus three tendrils; chest maw with jagged fangs.
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
			{ "FM", n = 2, variant = "slit", tints = { slit = 0xffb347 } },
			{ "FB", n = 2, tint = 0xd8ccb8, material = "SmoothPlastic", variant = "bone spurs" },
			{ "TN", n = 3 },
		},
		sigPiece = "FB",
		face = { marks = {}, hideEyes = true, maw = { teeth = 0xd8ccb8, jagged = true } },
		guis = {
			{ host = "UpperTorso", kind = "veins", color = 0x3a0a2a },
		},
	},

	antivenom = {
		-- +6. Revision 5, 1d: a lean two-tone field medic (celadon head and torso, deep-teal arms and legs),
		-- bone pauldrons and plate, mint slit and droplet. No white or near-white, no black, no teardrop eyes,
		-- no chest maw.
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
			{ "FM", n = 2, variant = "slit", tints = { slit = 0x4ae0c0 } },
			{ "EM", emblem = "E5", at = "front", tint = 0xd8ccb0, emblemColor = 0x4ae0c0 },
			{ "SG", n = 2, tint = 0xd8ccb0, material = "SmoothPlastic", variant = "bone" },
		},
		sigPiece = "EM",
		face = { marks = {}, hideEyes = true },
		guis = {
			{ host = "UpperTorso", kind = "veins", color = 0x24585a },
		},
	},

	docock = {
		-- +14. Each arm 3 parts: seg 1 Cyl Ø0.22×1.4, seg 2 Cyl Ø0.2×0.9, claw Wedge (Neon) (§3.1 BA/claw).
		-- No green anywhere, no glasses, no monocle, no trench coat, no bowl cut.
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
			{ "BA", n = 12, segs = 3, tint = 0xb8a078, material = "Metal", tints = { claw = 0xe89a4a } },
		},
		sigPiece = "BA",
		face = { marks = {} },
	},

	winter = {
		-- +8. Gunmetal arm (not silver). No lower mask, no long hair, no star.
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
			{ "GG", n = 2, tint = 0x2a2d34, variant = "pushed up", tints = { lens = 0x9fe0ff } },
			{ "MA", side = "R", tint = 0x4a4f58, material = "Metal", tints = { seam = 0x9fe0ff } },
			{ "VS" },
			{ "SB", pouch = 1 },
		},
		sigPiece = "MA",
		face = { marks = {} },
	},

	ironman = {
		-- +10. Suit keys per §2.6 (ARSENAL_PROP, suit = true). No red and gold, no round reactor.
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
			{ "FM", n = 2, variant = "helmet, slit", tints = { slit = 0x5ad4ff } },
			{ "CO", tint = 0x5ad4ff, variant = "diamond" },
			{ "SG", n = 2, tint = 0xe8e4dc },
			-- palm-Neon gauntlets: Ø40 px circle on the Bottom face, FaceGlow-style (LightInfluence 0)
			{ "GL", n = 2, tint = 0x3a4250, gui = { kind = "palm", face = "Bottom", d = 40, glow = 0x5ad4ff } },
			{ "Prop", max = 2 }, -- warmachine
		},
		sigPiece = "CO",
		face = { marks = {}, hideEyes = true },
		props = { max = 2, default = "mark42" },
	},

	jean = {
		-- +7. No red hair, no green and gold, no firebird.
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
			{ "CRY", n = 3, tint = 0xff8ae0, material = "Neon" }, -- psionic shard halo
		},
		sigPiece = "CRY",
		face = { marks = {} },
	},

	strange = {
		-- +7. No silver temples, no high collar, no cape, no red, no gold.
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
			{ "HD", tint = 0x2e2050, variant = "up" },
			{ "MT", tint = 0x2e2050, variant = "hooded mantle" },
			{ "SB", tint = 0x3a3048 },
			{
				"EM",
				at = "front",
				tint = 0x9fe0e8,
				material = "Glass",
				reflectance = 0.5,
				variant = "mirror-shard pendant, diamond",
			},
		},
		sigPiece = "EM",
		face = { marks = {} },
	},

	goblin = {
		-- +8. Beaked plague-mask on a glider; torso rust, limbs charcoal. No green or chartreuse, no grin,
		-- no long ears, no hood, no purple.
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
			{ "FM", n = 3, tint = 0xe8e0c8, variant = "bone, 2 round lenses", tints = { lens = 0xffb347 } },
			{ "BK", tint = 0xe8e0c8 },
			{
				"WG",
				tint = 0x4a4f58,
				material = "Metal",
				variant = "glider disc",
				gui = { kind = "dots", count = 2, glow = 0xffb347 },
			},
			{ "GL", n = 2 },
		},
		sigPiece = "BK",
		face = { marks = {}, hideEyes = true },
	},

	wolverine = {
		-- +8. Height 1.0 (no short stature), preset head. No stubble, no leather jacket, no yellow, no cowl.
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
			{ "HR", variant = "short crop, no side flares" },
			{ "HD·d", tint = 0x4a5a3a, variant = "parka hood" },
			{ "VS", tint = 0x4a5a3a, variant = "olive field parka" },
			{ "GL", n = 2, variant = "bracers" },
			{ "FB", n = 2, tint = 0xc8d0d8, variant = "long curved" },
		},
		sigPiece = "FB",
		face = { marks = {} },
	},
}
