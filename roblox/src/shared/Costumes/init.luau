--!strict
-- Costumes: the character and enemy looks as pure data plus pure functions
-- (docs/design/characters.md §6.1). Nothing in here touches Roblox beyond
-- loading its own child modules, so Lune runs it as well as the game.
--
-- STYLE is assembled from the child modules Styles/<universe>.luau (shinobi,
-- academy, skyline, elsewhere). Each returns `{ [styleId] = STYLE entry }`.
-- A missing or broken file does not stop the rest loading: its name and the
-- error land in `Costumes.STYLE_ERRORS`, and the tests name what is missing.
--
-- Colours are 0xRRGGBB integers (see Palette.luau). Sizes and offsets are
-- nominal studs at scale 1 (§2.1). Vectors are plain `{ x, y, z }` records so
-- the module needs no Roblox datatypes; the Kit turns them into Vector3s.
--
-- Kit entries (written by the Styles files; see their headers):
--   [1] code (§2.3 / §3.1, with the "·" character); n (the entry's part
--   count, overriding PARTS[code]); tint; tints = { role = colour } (sided
--   pairs L/R, HAT b/c/n, HMR s/h, and FM slit/lens, GG lens, MA seam,
--   BA claw, SHD beam, which glow); accent; material; reflectance; variant;
--   tail / pouch / pouches (SB extras); max (Prop); emblem / emblemColor;
--   gui = { kind, color?, fill?, glow? (true or a colour) }; flash.
--   effectiveLook reads every colour-bearing field.

local Costumes = {}

----------------------------------------------------------------------------
-- Loading (children and siblings), in Roblox and in Lune
----------------------------------------------------------------------------

local scriptRef: any = script

-- Lune resolves "@self/..." to this module's own folder and "./..." to its
-- siblings (the init.luau rule). In Roblox the same modules hang off `script`.
local function loadChild(name: string): any
	if scriptRef then
		local folder = scriptRef:FindFirstChild("Styles")
		local mod = folder and folder:FindFirstChild(name)
		if not mod then
			error("Styles/" .. name .. " is missing", 0)
		end
		return (require :: any)(mod)
	end
	return (require :: any)("@self/Styles/" .. name)
end

local function loadSibling(path: { string }): any
	if scriptRef then
		local node = scriptRef.Parent
		for _, p in path do
			node = node:WaitForChild(p)
		end
		return (require :: any)(node)
	end
	return (require :: any)("./" .. table.concat(path, "/"))
end

local Finale: any = loadSibling({ "Finale" })
local RulesData: any = loadSibling({ "Data", "Rules" })

----------------------------------------------------------------------------
-- Types
----------------------------------------------------------------------------

export type Colors = {
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

-- Kit entries and STYLE entries are written by other files; typed loosely.
export type Entry = { [any]: any }

export type Style = {
	name: string,
	preset: string,
	height: number,
	browAngle: number?,
	colors: Colors,
	limbs: { [string]: number }?,
	paint: { [string]: { color: number, material: string?, reflectance: number? } }?,
	kit: { Entry },
	sigPiece: string?,
	face: { [string]: any }?,
	props: any,
	suitTN: boolean?,
	guis: { any }?,
	emitters: { any }?,
}

export type Vec = { x: number, y: number, z: number }

export type Tint = {
	slot: string?, -- a STYLE.colors key
	color: number?, -- or a design constant
	material: string,
	transparency: number?,
	reflectance: number?,
	eye: boolean?, -- lenses that act as eyes: never darkened
}

--- One colour the build will use, and where. `base` is the value before the
--- character-boss lerp; `color` is what is drawn.
export type Use = {
	color: number,
	base: number,
	where: string, -- "top", "limbs.LeftArm", "kit:HR·s", "kit:FM:accent", "mark", "prop:rpg", ...
	code: string?,
	slot: string?, -- set for the nine STYLE.colors slots and limbs
	hair: boolean, -- hair, brow, HR·* / FLT / TIP (trade-dress hair rows)
	skin: boolean, -- used as skin (the SKIN_TONES exemption applies)
	head: boolean,
	glow: boolean, -- Neon, glowing gui, eye, sig: not darkened for bosses
}

export type KitLook = {
	code: string,
	entry: Entry,
	parts: number,
	tint: number?,
	accent: number?,
	material: string?,
	transparency: number?,
	reflectance: number?,
}

export type Look = {
	styleId: string,
	role: string,
	name: string,
	preset: string,
	height: number,
	browAngle: number,
	colors: Colors, -- effective (darkened for a character boss, except eye and sig)
	body: { [string]: number }, -- the six HumanoidDescription colours
	limbs: { [string]: number },
	paint: { [string]: { color: number, material: string?, reflectance: number? } },
	glow: number, -- technique glow (face.glow or sig)
	faceGlow: number?, -- character boss FaceGlow (= colors.sig)
	marks: { { color: number, mark: any } },
	kit: { KitLook },
	sigPiece: string?,
	suitTN: boolean,
	masked: boolean,
	all: { Use },
}

export type Palette = { base: number, nature: number, affix: number? }

----------------------------------------------------------------------------
-- Constants (§1.3, §1.4, §2.9, §4.1, §4.5)
----------------------------------------------------------------------------

Costumes.STEEL = 0x9aa4b0
Costumes.GRIP = 0x2a2a30
Costumes.WOOD = 0x5a4a3a
Costumes.FOE_TINT = 0x2a2a30 -- normal-foe darkening target (§4.1)
Costumes.FOE_LERP = 0.2
Costumes.BOSS_TINT = 0x14040a -- character-boss darkening target (§1.4)
Costumes.BOSS_LERP = 0.22
Costumes.ALPHA_GOLD = 0xffd54a
Costumes.ALLY_CYAN = 0x5ad4ff
Costumes.STITCH = 0xff2d55
Costumes.SHADOW = 0x101014

-- 19 human skin tones, exempt from 5b/5g only where used as skin (§3.0).
Costumes.SKIN_TONES = {
	0xf3c9a0,
	0xf7dcc0,
	0xf3d6b8,
	0xf3d6c0,
	0xf0d8c0,
	0xe8b88a,
	0xe8d8c8,
	0xf2d6c6,
	0xe8c8a0,
	0xe8d8c0,
	0xf0d2b8,
	0xd8c0a8,
	0xf0d2ae,
	0xf0d2b0,
	0xe0b088,
	0x8a6244,
	0xc89a70,
	0xe8c8a8,
	0x5a3a28,
}

local SKIN_SET: { [number]: boolean } = {}
for _, c in Costumes.SKIN_TONES do
	SKIN_SET[c] = true
end

function Costumes.isSkinTone(c: number): boolean
	return SKIN_SET[c] == true
end

-- The 20 §1.3 world cloth and metal constants, exempt from test 5g only.
Costumes.WORLD_CONST = {
	0x2b3350,
	0x4f6b3a,
	0xc9b48a,
	0xe8e0d0,
	0x9aa4b0,
	0x1b1f2e,
	0x252c40,
	0x14141c,
	0xc8a44a,
	0xb06cff,
	0x9b1a2a,
	0x23262e,
	0x4a4f58,
	0xe8e4dc,
	0xb8bec8,
	0x2f8f86,
	0x181818,
	0x3a0a14,
	0xc8b8b0,
	0xff2d55,
}

-- The universes and the Styles file each one's styles live in.
Costumes.STYLE_FILES = { "shinobi", "academy", "skyline", "elsewhere" }
Costumes.UNIVERSE_FILE = { naruto = "shinobi", jjk = "academy", marvel = "skyline", other = "elsewhere" }

----------------------------------------------------------------------------
-- STYLE (assembled from Styles/*.luau)
----------------------------------------------------------------------------

Costumes.STYLE = {} :: { [string]: Style }
Costumes.STYLE_ERRORS = {} :: { [string]: string } -- file name -> why it did not load
Costumes.STYLE_SOURCE = {} :: { [string]: string } -- style id -> file name

for _, file in Costumes.STYLE_FILES do
	local ok, res = pcall(loadChild, file)
	if not ok then
		Costumes.STYLE_ERRORS[file] = tostring(res)
	elseif type(res) ~= "table" then
		Costumes.STYLE_ERRORS[file] = "did not return a table"
	else
		for id, entry in res do
			if Costumes.STYLE_SOURCE[id] then
				Costumes.STYLE_ERRORS[file] = `style '{id}' is also in {Costumes.STYLE_SOURCE[id]}`
			end
			Costumes.STYLE[id] = entry
			Costumes.STYLE_SOURCE[id] = file
		end
	end
end

----------------------------------------------------------------------------
-- Geometry constants (§2.1, §2.2)
----------------------------------------------------------------------------

local function v(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end
Costumes.vec = v

-- Nominal R15 sizes at scale 1 (§2.1), keyed by part name.
Costumes.NOMINAL = {
	Head = v(1.2, 1.2, 1.2),
	UpperTorso = v(2, 1.6, 1),
	LowerTorso = v(2, 0.4, 1),
	LeftUpperArm = v(1, 1.17, 1),
	RightUpperArm = v(1, 1.17, 1),
	LeftLowerArm = v(1, 1.05, 1),
	RightLowerArm = v(1, 1.05, 1),
	LeftHand = v(1, 0.3, 1),
	RightHand = v(1, 0.3, 1),
	LeftUpperLeg = v(1, 1.22, 1),
	RightUpperLeg = v(1, 1.22, 1),
	LeftLowerLeg = v(1, 1.19, 1),
	RightLowerLeg = v(1, 1.19, 1),
	LeftFoot = v(1, 0.3, 1),
	RightFoot = v(1, 0.3, 1),
	HumanoidRootPart = v(2, 2, 1),
} :: { [string]: Vec }

-- The eye zone in head space (§2.2): no non-exempt surface in front of zFront.
Costumes.EYE_ZONE = { xMin = -0.33, xMax = 0.33, yMin = 0.06, yMax = 0.24, zFront = -0.60 }

Costumes.FACE_EXEMPT = {
	["FP"] = true,
	["VB"] = true,
	["VB·m"] = true,
	["GG"] = true,
	["FM"] = true,
	["BK"] = true,
	["GR·e"] = true,
} :: { [string]: boolean }

----------------------------------------------------------------------------
-- PARTS (§2.3, §3.1, §4.4, §4.5, §5): parts in one entry of the code
----------------------------------------------------------------------------

-- The count for one entry as the design writes the code: "1 each" codes are
-- 1 (an entry's `n` then gives how many), groups carry their whole count.
Costumes.PARTS = {
	-- §2.3
	["FP"] = 1,
	["HR"] = 1,
	["HR·s"] = 1,
	["HR·w"] = 1,
	["HR·p"] = 1,
	["HR·f"] = 1,
	["HR·k"] = 1,
	["HR·t"] = 1,
	["HB"] = 1,
	["HB·t"] = 2,
	["VB"] = 1,
	["VB·m"] = 1,
	["LM"] = 1,
	["CK"] = 1,
	["FM"] = 3, -- 2 lens Blocks or 2 round lenses; the slit variant is 2
	["BK"] = 1,
	["HD"] = 3,
	["HD·d"] = 1,
	["HN"] = 2,
	["EP"] = 2, -- a pair; the fin variant is 1
	["EC"] = 1,
	["GG"] = 2,
	["HP"] = 2, -- 2 cups; the band is a Beam
	["CR"] = 4, -- the ladder's single-wedge crest is 1
	["OR"] = 1,
	["SC"] = 2,
	["SG"] = 1,
	["HC"] = 1,
	["LP"] = 2,
	["VS"] = 1,
	["EM"] = 1,
	["CT"] = 2,
	["CP"] = 1,
	["SB"] = 1, -- + tail (1) + each pouch (1)
	["MT"] = 1,
	["CO"] = 1,
	["BW"] = 2, -- default sword: hilt + blade (1 to 3; the ladder's short BW is 1)
	["BA"] = 2, -- per arm (2 or 3 segments)
	["TN"] = 1,
	["WG"] = 1, -- disc; the wings variant is 2
	["GL"] = 1,
	["FB"] = 1,
	["MA"] = 1, -- the Neon seam; the arm itself is painted
	["XA"] = 4,
	["WR"] = 1,
	["FS"] = 2,
	["SD"] = 1,
	["Prop"] = 3, -- the §2.6 slot, counted at its largest prop (entry.max overrides)
	-- §3.1
	["HAT"] = 3,
	["HAT·b"] = 1,
	["HAT·c"] = 1,
	["HAT·n"] = 1,
	["FTH"] = 2,
	["CLP"] = 1,
	["LF"] = 1,
	["BLM"] = 1,
	["ORB"] = 1,
	["WSP"] = 1,
	["SHD"] = 4,
	["VL"] = 2,
	["TIE"] = 1,
	["WCH"] = 1,
	["BLD"] = 1,
	["HMR"] = 2,
	["HMR·s"] = 1,
	["HMR·h"] = 1,
	["FLT"] = 1,
	["CN"] = 1,
	["MZ"] = 1,
	["STF"] = 1,
	["TIP"] = 1,
	["PLT"] = 2,
	["SEAM"] = 1,
	["TSL"] = 2,
	["EDG"] = 1,
	["CRY"] = 3,
	["SPL"] = 2,
	["SM"] = 4,
	["GR·e"] = 2,
	["UB·p"] = 2,
	["UB·d"] = 2,
	["UB·t"] = 8,
	["HY·p"] = 2,
	["HY·s"] = 2,
	["HY·n"] = 3,
	-- §4.4 ladder and faction pieces
	["TAL"] = 2, -- sorcerer talisman strips
	["CUFF"] = 1, -- street beanie cuff
	["PIPE"] = 1, -- street pipe (replaces BW)
	["TRIM"] = 1, -- semi1 Neon trim strip
	-- §4.5 markers
	["RING"] = 1, -- affix ring
	["CREST"] = 1, -- alpha crest
	["SPIKE"] = 1, -- Frenzied
	["ARMOR"] = 2, -- Armored pauldrons / plates
	["FUSE"] = 1, -- Volatile, humans only
	["STRIP"] = 2, -- stitched strips
} :: { [string]: number }

-- Variants that change a code's count (entry.variant).
local VARIANT_PARTS: { [string]: { [string]: number } } = {
	["FM"] = { slit = 2 },
	["EP"] = { fin = 1 },
	["CR"] = { single = 1 },
	["BW"] = { short = 1 },
	["WG"] = { wings = 2 },
}

--- Parts one kit entry mounts. `n`, when given, is the entry's part count and
--- overrides PARTS[code] (BA×4 of 2 segments is n = 8; HAT is n = 3);
--- otherwise PARTS[code] and its variant (a BA entry without n is 4 arms of
--- `segs`). SB adds its tail and pouches; Prop counts `max`.
function Costumes.entryParts(e: Entry): number
	local code = e[1]
	if type(e.parts) == "number" then
		return e.parts
	end
	if code == "BA" and type(e.n) ~= "number" then
		return 4 * (e.segs or Costumes.PARTS["BA"])
	end
	if code == "Prop" then
		return e.max or Costumes.PARTS["Prop"]
	end
	local base: number
	if type(e.n) == "number" then
		base = e.n
	else
		local vp = VARIANT_PARTS[code]
		base = (vp and e.variant and vp[e.variant]) or Costumes.PARTS[code] or 0
	end
	if code == "SB" then
		base += (if e.tail then 1 else 0) + (tonumber(e.pouch) or tonumber(e.pouches) or 0)
	end
	return base
end

--- The style's +N (FP included), with the suit's 2 TN when `withSuit` and
--- the style is `suitTN` (§2.6).
function Costumes.kitParts(style: Style, withSuit: boolean?): number
	local n = 0
	for _, e in style.kit do
		n += Costumes.entryParts(e)
	end
	if withSuit and style.suitTN then
		n += 2
	end
	return n
end

----------------------------------------------------------------------------
-- Round pieces (test 11): a ball has three equal axes, anything else is ell
----------------------------------------------------------------------------

local function ball(d: number): Vec
	return v(d, d, d)
end

Costumes.ROUND = {
	{ code = "HR", kind = "ell", size = v(1.30, 1.02, 1.32) },
	{ code = "HR·k", kind = "ball", size = ball(0.54) },
	{ code = "HR·t", kind = "ball", size = ball(0.45) },
	{ code = "FM", kind = "ell", size = v(1.28, 1.3, 1.3) },
	{ code = "HD", kind = "ell", size = v(1.45, 1.4, 1.2) },
	{ code = "HD·d", kind = "ell", size = v(1.3, 0.5, 0.8) },
	{ code = "MT", kind = "ell", size = v(2.5, 0.65, 1.4) },
	{ code = "BLM", kind = "ball", size = ball(0.45) },
	{ code = "ORB", kind = "ball", size = ball(0.5) },
	{ code = "WSP", kind = "ball", size = ball(0.5) },
	{ code = "GR·e", kind = "ell", size = v(0.36, 0.2, 0.1) },
	{ code = "UB·d", kind = "ell", size = v(1.2, 0.7, 1.2) },
	{ code = "FUSE", kind = "ball", size = ball(0.35) },
	{ code = "prop:rpg", kind = "ball", size = ball(0.4) },
	-- creature families, in B (or t.size for the UFO) units
	{ code = "toad.wart", kind = "ball", size = ball(0.18) },
	{ code = "toad.body", kind = "ell", size = v(1.0, 0.75, 1.0) },
	{ code = "toad.domes", kind = "ball", size = ball(0.34) },
	{ code = "toad.haunches", kind = "ell", size = v(0.45, 0.4, 0.55) },
	{ code = "toad.wart2", kind = "ball", size = ball(0.14) },
	{ code = "blob.core", kind = "ball", size = ball(0.55) },
	{ code = "blob.eye.white", kind = "ball", size = ball(0.4) },
	{ code = "blob.eye.iris", kind = "ball", size = ball(0.22) },
	{ code = "blob.eye.pupil", kind = "ball", size = ball(0.1) },
	{ code = "blob.drips", kind = "ball", size = ball(0.15) },
	{ code = "larva.seg1", kind = "ball", size = ball(0.6) },
	{ code = "larva.seg2", kind = "ball", size = ball(0.5) },
	{ code = "larva.seg3", kind = "ball", size = ball(0.4) },
	{ code = "wraith.hood", kind = "ell", size = v(1.0, 1.2, 1.0) },
	{ code = "wraith.void", kind = "ell", size = v(0.6, 0.7, 0.3) },
	{ code = "wraith.tail1", kind = "ell", size = v(0.7, 1.0, 0.7) },
	{ code = "wraith.tail2", kind = "ell", size = v(0.45, 0.8, 0.45) },
	{ code = "golem.boulders", kind = "ball", size = ball(1.3) },
	{ code = "imp.eyes", kind = "ball", size = ball(0.2) },
	{ code = "imp.belly", kind = "ell", size = v(1.3, 1.0, 1.1) },
	{ code = "ufo.dome", kind = "ball", size = ball(1.8) },
	{ code = "ufo.rim", kind = "ball", size = ball(0.3) },
	{ code = "fox.torso", kind = "ell", size = v(1.0, 0.9, 2.2) },
	{ code = "fox.ruff", kind = "ell", size = v(0.9, 0.9, 0.7) },
	{ code = "fox.skull", kind = "ell", size = v(0.8, 0.7, 0.8) },
	{ code = "fox.tails", kind = "ell", size = v(0.35, 0.35, 2.4) },
} :: { { code: string, kind: string, size: Vec } }

----------------------------------------------------------------------------
-- TIER (§2.1, §4.2, §4.4, §4.5)
----------------------------------------------------------------------------

export type Piece = { piece: string, tier: string, parts: number, color: number? }

local function p(piece: string, tier: string, parts: number, color: number?): Piece
	return { piece = piece, tier = tier, parts = parts, color = color }
end

Costumes.TIER_ORDER = { "0", "1", "W", "R", "L", "D" }

Costumes.TIER = {
	-- fixed tiers by code: FP first, then every marker
	code = {
		["FP"] = "0",
		["RING"] = "1",
		["CREST"] = "1",
		["SPIKE"] = "1",
		["ARMOR"] = "1",
		["FUSE"] = "1",
		["STRIP"] = "1",
		["SD"] = "1",
	} :: { [string]: string },
	-- creature families (§4.2), in mount order within a tier
	family = {
		toad = {
			p("wart", "W", 1),
			p("body", "R", 1),
			p("domes", "R", 2),
			p("pupils", "R", 2),
			p("hind", "L", 2),
			p("front", "L", 2),
			p("mouth", "D", 1),
			p("haunches", "D", 2),
			p("wart2", "D", 1),
		},
		blob = {
			p("core", "W", 1),
			p("jelly", "R", 1),
			p("eye", "R", 3),
			p("tendrils", "L", 2),
			p("mouth", "D", 1),
			p("drips", "D", 3),
		},
		wraith = {
			p("eyes", "W", 2),
			p("hood", "R", 1),
			p("peak", "R", 1),
			p("void", "R", 1),
			p("tail", "R", 2),
			p("claws", "L", 2),
			p("hem", "D", 3),
		},
		golem = {
			p("core", "W", 1),
			p("chest", "R", 2),
			p("band", "R", 1),
			p("brow", "R", 1),
			p("shards", "R", 2),
			p("gauntlets", "L", 2),
			p("boulders", "D", 2),
		},
		imp = {
			p("FP", "0", 1), -- the grin is the weak point
			p("horns", "R", 2),
			p("eyes", "R", 2),
			p("belly", "R", 1),
			p("tail", "L", 3),
			p("wings", "D", 2),
		},
		ufo = {
			p("ring", "W", 1),
			p("saucer", "R", 1),
			p("dome", "R", 1),
			p("rim", "D", 4),
			p("SD", "1", 1),
		},
	} :: { [string]: { Piece } },
	-- players: entries up to and including sigPiece are R, the rest D (§2.1)
	player = { upToSig = "R", afterSig = "D" },
}

-- Human-enemy grade ladder (§4.4), cumulative in this order. `slot` names
-- what a faction may substitute (see FACTION).
Costumes.LADDER = {
	{
		grade = "4",
		entries = {
			{ slot = "FP", code = "FP", tier = "0", parts = 1 },
			{ slot = "hair", code = "HR", tier = "R", parts = 1 },
			{ slot = "hairExtra", code = "HR·s", alt = "HR·p", tier = "R", parts = 1 },
		},
	},
	{ grade = "3", entries = { { slot = "faction", code = "HB", tier = "R", parts = 1 } } }, -- HB, HC or VS
	{
		grade = "2",
		entries = {
			{ slot = "shoulder", code = "SG", tier = "R", parts = 1 },
			{ slot = "lower", code = "LM", alt = "SC", tier = "R", parts = 1 }, -- LM or the SC wrap alone
		},
	},
	{
		grade = "1",
		entries = {
			{ slot = "tails", code = "CT", tier = "D", parts = 2 },
			{ slot = "gloves", code = "GL", n = 2, tier = "D", parts = 2 },
		},
	},
	{
		grade = "semi1",
		entries = {
			{ slot = "weapon", code = "BW", variant = "short", tier = "R", parts = 1 },
			{ slot = "trim", code = "TRIM", tier = "R", parts = 1 }, -- Neon, nature colour
		},
	},
	{
		grade = "special",
		entries = { { slot = "crest", code = "CR", variant = "single", tier = "R", parts = 1, fx = "aura", rate = 6 } },
	},
} :: { { grade: string, entries: { any } } }
Costumes.TIER.ladder = Costumes.LADDER

--- The cumulative ladder entries for a grade (a number or a string key).
function Costumes.ladderFor(grade: any): { any }
	local key = tostring(grade)
	local out = {}
	for _, step in Costumes.LADDER do
		for _, e in step.entries do
			table.insert(out, e)
		end
		if step.grade == key then
			return out
		end
	end
	return out
end

-- Human-enemy factions (§4.4): the faction piece and slot substitutions.
Costumes.FACTION = {
	ninja = {
		members = { "rogue_ninja", "clone_ninja", "blade_ninja", "thunder_ninja", "akatsuki_nin" },
		faction = { code = "HB", variant = "cloth" }, -- plain cloth, no mark, never a plate
		lower = { code = "LM" }, -- grade 2+
		gloves = { code = "GL", n = 2, variant = "wraps" },
		grade1 = { code = "VS", variant = "flak" }, -- flak vest at grade 1+
		weapon = { code = "BW", variant = "short" },
	},
	sorcerer = {
		members = { "kyoto_student", "flame_dancer", "blood_curse", "gate_monk" },
		faction = { code = "HC", gui = { kind = "buttons" } },
		tails = { code = "CT" }, -- grade 1+
		-- grade 2+: 2 talisman strips, Block 0.15×0.6×0.03 at BodyFront (±0.4, −0.3, −0.03)
		talismans = { code = "TAL", tint = 0xe8e0c8, size = v(0.15, 0.6, 0.03), pos = v(0.4, -0.3, -0.03) },
	},
	-- on these maps (via Enemies.mapId) headgear, VS and BW change (§4.4)
	street = {
		maps = { times_square = true, culling_colony = true },
		headgear = { { code = "HR", cuff = { code = "CUFF", size = 0.1 } }, { code = "LM", variant = "bandana" } } :: { any },
		vest = { { code = "VS" }, { code = "LP" } },
		weapon = { code = "PIPE", size = v(1.6, 0.12, 0.12) }, -- Cyl Ø0.12×1.6
	},
} :: { [string]: any }

-- Variety per spawn (§4.4): Random.new(spawnCounter) picks from these.
Costumes.VARIETY = {
	skin = { 0xf3d6b8, 0xe0b088, 0xc89a70, 0x8a6244, 0x5a3a28 },
	hairVariants = 3,
}

-- The grey (§4.4): small preset, WidthScale 0.7, GR·e eyes, no hair, no FP.
Costumes.GREY = { preset = "small", widthScale = 0.7, eyes = "GR·e", hair = false, fp = false, parts = 2 }

-- Markers by role (§4.5): parts and colours.
Costumes.MARKER = {
	ring = { code = "RING", parts = 1, transparency = 0.35 },
	alpha = { code = "CREST", parts = 1, color = 0xffd54a, fx = "dust", eyeScale = 1.3, darker = 0.15 },
	affix = {
		frenzied = { code = "SPIKE", parts = 1, color = 0xff4d5e, fx = "spark" },
		armored = { code = "ARMOR", parts = 2, color = 0xb8c2d0, material = "DiamondPlate" },
		giant = { parts = 0, color = 0xffb340, ringScale = 1.6 },
		vampiric = { parts = 0, color = 0xc0294a, fx = "drip" },
		volatile = { parts = 0, humanParts = 1, color = 0xff8a3d, code = "FUSE" },
	},
	stitch = { code = "STRIP", parts = 2, color = 0xff2d55 },
	ally = { color = 0x5ad4ff },
}

----------------------------------------------------------------------------
-- DEFAULT_TINT (§2.9, plus the §3.1 constants)
----------------------------------------------------------------------------

local function slot(s: string, material: string, extra: { [string]: any }?): Tint
	local t: Tint = { slot = s, material = material }
	if extra then
		t.transparency = extra.transparency
		t.reflectance = extra.reflectance
		t.eye = extra.eye
	end
	return t
end

local function const(c: number, material: string, extra: { [string]: any }?): Tint
	local t: Tint = { color = c, material = material }
	if extra then
		t.transparency = extra.transparency
		t.reflectance = extra.reflectance
		t.eye = extra.eye
	end
	return t
end

Costumes.DEFAULT_TINT = {
	-- colors.hair, SmoothPlastic
	["HR"] = slot("hair", "SmoothPlastic"),
	["HR·s"] = slot("hair", "SmoothPlastic"),
	["HR·w"] = slot("hair", "SmoothPlastic"),
	["HR·p"] = slot("hair", "SmoothPlastic"),
	["HR·f"] = slot("hair", "SmoothPlastic"),
	["HR·k"] = slot("hair", "SmoothPlastic"),
	["HR·t"] = slot("hair", "SmoothPlastic"),
	["FLT"] = slot("hair", "SmoothPlastic"),
	-- colors.top, Fabric (FM, SG, TN: SmoothPlastic)
	["FM"] = slot("top", "SmoothPlastic"),
	["LM"] = slot("top", "Fabric"),
	["HD"] = slot("top", "Fabric"),
	["HD·d"] = slot("top", "Fabric"),
	["CK"] = slot("top", "Fabric"),
	["VS"] = slot("top", "Fabric"),
	["HC"] = slot("top", "Fabric"),
	["LP"] = slot("top", "Fabric"),
	["CT"] = slot("top", "Fabric"),
	["CP"] = slot("top", "Fabric"),
	["MT"] = slot("top", "Fabric"),
	["SG"] = slot("top", "SmoothPlastic"),
	["TN"] = slot("top", "SmoothPlastic"),
	-- colors.trim, Fabric (BA, EC: Metal)
	["HB"] = slot("trim", "Fabric"),
	["HB·t"] = slot("trim", "Fabric"),
	["SC"] = slot("trim", "Fabric"),
	["SB"] = slot("trim", "Fabric"),
	["GL"] = slot("trim", "Fabric"),
	["WR"] = slot("trim", "Fabric"),
	["EM"] = slot("trim", "Fabric"),
	["EC"] = slot("trim", "Metal"),
	["BA"] = slot("trim", "Metal"),
	["HP"] = slot("trim", "Fabric"),
	["SPL"] = slot("trim", "Fabric"),
	-- colors.sleeves, SmoothPlastic
	["XA"] = slot("sleeves", "SmoothPlastic"),
	["FS"] = slot("sleeves", "SmoothPlastic"),
	-- colors.sig, Neon (GG and FM lenses: Glass, Transparency 0.2)
	["OR"] = slot("sig", "Neon"),
	["CO"] = slot("sig", "Neon"),
	["GG"] = slot("sig", "Glass", { transparency = 0.2, eye = true }),
	["MA"] = const(0x9aa4b0, "Metal", { reflectance = 0.2 }), -- the arm paint; the seam is the accent
	["TRIM"] = slot("sig", "Neon"), -- ladder trim strip (the Kit tints it with the nature colour)
	-- steel and grips
	["BW"] = const(0x9aa4b0, "Metal"), -- blade (hilt: accent)
	["FB"] = const(0x9aa4b0, "Metal"),
	["Prop"] = const(0x9aa4b0, "Metal"),
	-- VB, VB·m: sig, Glass 0.35
	["VB"] = slot("sig", "Glass", { transparency = 0.35 }),
	["VB·m"] = slot("sig", "Glass", { transparency = 0.35 }),
	-- colors.skin, SmoothPlastic
	["EP"] = slot("skin", "SmoothPlastic"),
	["HN"] = slot("skin", "SmoothPlastic"),
	["BK"] = slot("skin", "SmoothPlastic"),
	-- not in the §2.9 table; nearest rule
	["CR"] = slot("trim", "SmoothPlastic"),
	["FTH"] = slot("top", "SmoothPlastic"), -- "per row"
	["SD"] = const(0x101014, "SmoothPlastic", { transparency = 0.6 }),
	["WG"] = const(0x4a4f58, "Metal"),
	-- §3.1 constants
	["HAT"] = const(0x101010, "SmoothPlastic"),
	["HAT·b"] = const(0x101010, "SmoothPlastic"),
	["HAT·c"] = const(0x101010, "SmoothPlastic"),
	["HAT·n"] = const(0x9b1a2a, "SmoothPlastic"),
	["CLP"] = const(0x7a8ad8, "SmoothPlastic"),
	["LF"] = const(0x4f6b3a, "SmoothPlastic"),
	["BLM"] = const(0xff8ae0, "SmoothPlastic"),
	["ORB"] = const(0xb06cff, "Neon"),
	["WSP"] = const(0x9fd6ff, "Neon"),
	["SHD"] = const(0x2a2a30, "Basalt"),
	["VL"] = const(0x9b1a2a, "Neon"),
	["TIE"] = const(0x6a4a2a, "Fabric"),
	["WCH"] = const(0xd8b46a, "Metal"),
	["BLD"] = const(0x9aa4b0, "Metal"),
	["HMR"] = const(0x5a4a3a, "Wood"),
	["HMR·s"] = const(0x5a4a3a, "Wood"),
	["HMR·h"] = const(0x9aa4b0, "Metal"),
	["CN"] = const(0x4a4f58, "Metal"),
	["MZ"] = const(0xffd54a, "Neon"),
	["STF"] = const(0x4a3a2a, "Wood"),
	["TIP"] = const(0xf0d27a, "SmoothPlastic"),
	["PLT"] = const(0xd8c0a8, "SmoothPlastic"), -- left; right is the accent
	["SEAM"] = const(0x5ae0a0, "Neon"),
	["TSL"] = const(0xe8a07a, "SmoothPlastic"),
	["EDG"] = const(0xffd8a0, "Neon"),
	["CRY"] = const(0xff8ae0, "Neon"),
	["SM"] = const(0xffb347, "Neon"),
	["GR·e"] = const(0x101014, "Glass", { reflectance = 0.3, eye = true }),
	["UB·p"] = const(0xc8c2b8, "SmoothPlastic"),
	["UB·d"] = const(0xd9d4cc, "SmoothPlastic"),
	["UB·t"] = const(0x8a8680, "SmoothPlastic"),
	["HY·p"] = const(0x3a0a14, "SmoothPlastic"),
	["HY·s"] = const(0xff2d55, "Neon"),
	["HY·n"] = const(0x9aa4b0, "Metal"),
	["TAL"] = const(0xe8e0c8, "SmoothPlastic"),
	["CUFF"] = slot("hair", "Fabric"),
	["PIPE"] = const(0x9aa4b0, "Metal"),
} :: { [string]: Tint }

-- The second colour of a piece (entry.accent overrides): lenses and slits,
-- seams, hilts, bands, the right plate, the emblem stroke.
Costumes.DEFAULT_ACCENT = {
	["FM"] = slot("sig", "Neon", { eye = true }), -- slit Neon; lenses Glass 0.2
	["GG"] = slot("sig", "Glass", { transparency = 0.2, eye = true }),
	["MA"] = slot("sig", "Neon"), -- seam
	["BW"] = const(0x2a2a30, "SmoothPlastic"), -- hilt
	["HP"] = const(0x2a2a30, "SmoothPlastic"), -- Beam band
	["HAT"] = const(0x9b1a2a, "SmoothPlastic"), -- band
	["HMR"] = const(0x9aa4b0, "Metal"), -- head
	["PLT"] = const(0x8a6244, "SmoothPlastic"), -- right plate
	["SHD"] = const(0x8a6cff, "Neon"), -- Beams and Neon edge
	["EM"] = slot("sig", "SmoothPlastic"), -- emblem strokes (§2.5)
	["CN"] = const(0xffd54a, "Neon"), -- the muzzle, when written as one CN entry
} :: { [string]: Tint }

----------------------------------------------------------------------------
-- TRADE_DRESS (§3.0), BANNED (§2.7), ADAPT_ORDER (§5.3)
----------------------------------------------------------------------------

export type Guard = { color: number, hairOnly: boolean? }

local function td(list: { any }): { Guard }
	local out = {}
	for _, e in list do
		if type(e) == "number" then
			table.insert(out, { color = e })
		else
			table.insert(out, { color = e[1], hairOnly = true })
		end
	end
	return out
end
local function hair(c: number): { number }
	return { c }
end

Costumes.TRADE_DRESS = {
	naruto = td({ 0xf66c2d, 0x082c8c, hair(0xe7e419) }),
	sasuke = td({ 0xe10000 }),
	gojo = td({ hair(0xf4f4ff), hair(0xd8d8e8) }),
	sukuna = td({ 0xff2d55, hair(0xf7c6c6), hair(0xe0a8a8) }),
	yuji = td({ 0xb52f36, hair(0xff8f9c) }),
	kakashi = td({ 0xc8ccd4, 0x3f5a3a }),
	kashimo = td({ hair(0xf5e6a0), hair(0xdfe8ff), 0xffd54a }),
	itachi = td({ 0xb03a3a, 0xd8232f }),
	might_guy = td({ 0x2f8f3a, 0xf66c2d }),
	pain = td({ 0xf66c2d, 0xb03a3a }),
	toge = td({ hair(0xe8e8ee) }),
	nobara = td({ hair(0xc87a34) }),
	maki = td({ hair(0x2b4a36) }),
	ishigori = td({ hair(0xf0e08a) }),
	hakari = td({ hair(0xf2ecd8) }),
	yuki = td({ hair(0xf2d88a) }),
	nanami = td({ 0xd6cbb2, 0x4a7a9a, hair(0xd8c07a) }),
	hanami = td({ 0x8fbf6a }),
	spiderman = td({ 0xd8323c, 0x1f2f8f }),
	insomniac = td({ 0xc8202c, 0x1a2f7a, 0xf0f4ff }),
	miles = td({ 0xff2d3a, 0xd8202e }),
	ironspider = td({ 0xb01824, 0x8a1018, 0xffc83d }),
	venom = td({ 0xf4f4f8, 0xeceff4 }),
	carnage = td({ 0x8e0d1c, 0xd4142a }),
	docock = td({ 0x3f6a34, 0xa8b2be, 0x5a8f3a }),
	winter = td({ 0xb8bec8 }),
	ironman = td({ 0xd4302a, 0xffc83d }),
	jean = td({ 0xd94f1a, 0x1f7a3a, 0xffd54a }),
	strange = td({ 0xb02a2a, 0xd4b04a, 0x1e3a6a }),
	goblin = td({ 0x4a9a3a, 0x5aa83a, 0x6a3ab0 }),
	wolverine = td({ 0xd8a83a, 0x6a3a1a }),
	mahito = td({
		0xbacccf,
		0x25345a,
		0xd8e0d8,
		0x2a4a46,
		0x6cd8c0,
		0x6b6f6f,
		hair(0xdcd3c9),
		hair(0xb8bfc4),
		hair(0x8fa8b8),
	}),
	antivenom = td({ 0xe8eef4, 0xdae2ea, 0xeef2f6, 0xdfe8f4, 0x8fa0b0, 0xf4f4f8 }),
	eleven = td({ 0xf0e0d0, 0x2a3a5a, 0xc0392b, 0xf0a8c0, hair(0x6a4a2a) }),
	kenjaku = td({ 0x3a4426, 0x8aa84a }),
	dagon = td({ 0xbfe0f0, 0x2a6a8a, 0x6cd8ff, hair(0x2f6fb5) }),
	jogo = td({ 0xd88a4a, 0x6a2a1a, 0xff6b3d }),
	uro = td({ 0xdcd8ce, 0x8fa8c8 }),
} :: { [string]: { Guard } }

-- Flags dropped from human-enemy looks, with what replaces them (§2.7).
Costumes.BANNED = {
	webs = "nothing",
	spider = "nothing",
	whiskers = "nothing",
	eyePatch = "nothing",
	nosebleed = "nothing",
	fangs = "nothing",
	reactor = "E3 or the CO diamond",
	venomEyes = "FM slit",
	tieSpots = "stripes",
	blindfold = "nothing",
	sharingan = "FaceGlow during techniques",
	rinnegan = "FaceGlow during techniques",
	volcano = "CR rock crown",
	stitches = "a vertical right-side seam (human enemies)",
	headbandPlate = "cloth HB",
	scratchedPlate = "nothing",
} :: { [string]: string }

--- A human-enemy look with every BANNED flag dropped.
function Costumes.dropBanned(look: { [string]: any }): { [string]: any }
	local out = {}
	for k, val in look do
		if not Costumes.BANNED[k] then
			out[k] = val
		end
	end
	return out
end

Costumes.ADAPT_ORDER = { "physical", "cursed", "fire", "wind", "lightning", "earth", "water", "sound" }

----------------------------------------------------------------------------
-- ENEMY (§4.3 creature variants, §4.4 human enemies, §5 finale builders)
----------------------------------------------------------------------------

-- variant fields: color (pal.base), weak (weak-point colour), material,
-- transparency, reflectance, fx (§6.5 key), float (SD), remove (family piece
-- ids), add ({piece, tier, parts, color?}), retier ({piece = tier}), plus
-- free-form notes the Kit reads. `parts` is the §4.3 total (test 2).
export type Enemy = {
	shape: string?,
	faction: string?,
	builder: string?,
	variant: { [string]: any },
	parts: number?,
}

Costumes.ENEMY = {
	-- toad
	cursed_toad = {
		shape = "toad",
		variant = {
			color = 0x3f7a6a,
			weak = 0x5aa9ff,
			remove = { "wart2" },
			add = { p("tongue", "D", 1, 0xe88aa0) },
		},
		parts = 14,
	},
	-- blob
	grade4 = { shape = "blob", variant = { color = 0xc9a068, remove = { "tendrils" }, float = true }, parts = 10 },
	larva = {
		shape = "blob",
		variant = {
			remove = { "core", "jelly", "tendrils", "mouth", "drips" },
			retier = { eye = "W" },
			add = { p("segments", "R", 3), p("mandibles", "R", 2) },
			float = true,
		},
		parts = 9,
	},
	cursed_womb = {
		shape = "blob",
		variant = { color = 0x8a2a4a, remove = { "core" }, add = { p("curledCore", "W", 2) }, pulse = true },
		parts = 12,
	},
	mist_leech = {
		shape = "blob",
		variant = { remove = { "mouth" }, add = { p("funnel", "R", 1) }, fx = "smoke", float = true },
		parts = 12,
	},
	slot_curse = {
		shape = "blob",
		variant = { color = 0xd8b84a, remove = { "eye" }, add = { p("reelFace", "R", 1) }, fx = "coin" },
		parts = 9,
	},
	-- wraith
	wind_spirit = { shape = "wraith", variant = { color = 0x8fe3c9, fx = "wind", float = true }, parts = 13 },
	storm_wraith = {
		shape = "wraith",
		variant = {
			remove = { "hem" },
			add = { p("crackle", "R", 2, 0xffe45c), p("hem1", "D", 1) },
			fx = "spark",
			float = true,
		},
		parts = 13,
	},
	bat_curse = {
		shape = "wraith",
		variant = { remove = { "hem" }, add = { p("wings", "R", 2), p("ears", "R", 2) }, float = true },
		parts = 14,
	},
	smoke_curse = {
		shape = "wraith",
		variant = {
			transparency = 0.3,
			fx = "smoke",
			remove = { "eyes" },
			add = { p("lantern", "W", 1) },
			float = true,
		},
		parts = 12,
	},
	sand_spirit = {
		shape = "wraith",
		variant = { material = "Sand", remove = { "void" }, add = { p("facePlate", "R", 1, 0xd8ccb8) }, float = true },
		parts = 13,
	},
	crow_swarm = {
		shape = "wraith",
		variant = {
			remove = { "eyes", "hood", "peak", "void", "tail", "claws", "hem" },
			add = { p("leadCrow", "W", 1), p("crows", "R", 2), p("beaks", "R", 3) },
			fx = "feather",
			float = true,
		},
		parts = 7,
	},
	mirror_fiend = {
		shape = "wraith",
		variant = { reflectance = 0.5, remove = { "hem" }, add = { p("shards", "R", 3) }, float = true },
		parts = 13,
	},
	-- imp
	ember_imp = { shape = "imp", variant = { material = "CrackedLava", fx = "ember", fxAt = "spade" }, parts = 11 },
	needle_curse = {
		shape = "imp",
		variant = { remove = { "wings" }, add = { p("needles", "R", 4) } },
		parts = 13,
	},
	rush_curse = {
		shape = "imp",
		variant = { remove = { "horns" }, add = { p("ramHorns", "R", 2) }, lean = 12 },
		parts = 11,
	},
	spine_curse = {
		shape = "imp",
		variant = { color = 0xd8ccb8, remove = { "wings" }, add = { p("vertebrae", "R", 4) } },
		parts = 13,
	},
	goblin_drone = {
		shape = "imp",
		variant = {
			color = 0xc8642a, -- rust, not the data green
			dark = 0x2a2a30,
			eye = 0xffb347,
			remove = { "wings" },
			add = { p("beak", "R", 1), p("hoverDisc", "R", 1) },
			float = true,
		},
		parts = 12,
	},
	-- golem
	stone_brute = {
		shape = "golem",
		variant = { material = "Slate", remove = { "shards" }, add = { p("moss", "R", 2, 0x4f6b3a) } },
		parts = 11,
	},
	finger_bearer = {
		shape = "golem",
		variant = {
			color = 0x8a5a6a,
			material = "SmoothPlastic",
			remove = { "shards" },
			add = { p("fingers", "R", 5) },
		},
		parts = 14,
	},
	iron_curse = {
		shape = "golem",
		variant = { color = 0x6a7280, material = "DiamondPlate", gui = { kind = "rivets" } },
		parts = 11,
	},
	tomb_guardian = {
		shape = "golem",
		variant = {
			material = "Sandstone",
			remove = { "brow" },
			add = { p("facePlate", "R", 1, 0xc8a44a) },
			emblem = "E7",
		},
		parts = 11,
	},
	mass_curse = {
		shape = "golem",
		variant = {
			color = 0xff8a2a,
			remove = { "brow", "shards" },
			add = { p("anvilHead", "R", 1), p("shard", "R", 1), p("waistWeight", "R", 1) },
		},
		parts = 11,
	},
	-- ufo
	ufo = { shape = "ufo", variant = {}, parts = 8 },

	-- human enemies (§4.4): look from EnemyLooks[baseId] unless `variant.look` says
	rogue_ninja = { shape = "human", faction = "ninja", variant = {} },
	blade_ninja = { shape = "human", faction = "ninja", variant = {} },
	thunder_ninja = { shape = "human", faction = "ninja", variant = {} },
	clone_ninja = {
		shape = "human",
		faction = "ninja",
		variant = {
			color = 0x24242c,
			transparency = 0.15,
			fx = "smoke",
			look = { top = 0x24242c, sleeves = 0x24242c, bottom = 0x24242c, hair = 0x24242c },
			tintAll = 0x24242c,
		},
	},
	akatsuki_nin = {
		-- "Ember Veil": no clouds, no red collar
		shape = "human",
		faction = "ninja",
		variant = {
			color = 0x15151d,
			look = {
				hair = 0x14141c,
				top = 0x15151d,
				sleeves = 0x15151d,
				bottom = 0x1e1e28,
				eye = 0xd8682a,
			},
			pieces = {
				{ "CP", tint = 0x15151d, gui = { kind = "hemStripe", color = 0xd8682a } },
				{ "HD", tint = 0x15151d },
				{ "LM", tint = 0x15151d },
			} :: { any },
		},
	},
	kyoto_student = { shape = "human", faction = "sorcerer", variant = {} },
	flame_dancer = {
		shape = "human",
		faction = "sorcerer",
		variant = { bare = true, pieces = { { "SB" } } :: { any }, fx = "ember", fxAt = "hands" },
	},
	blood_curse = {
		shape = "human",
		faction = "sorcerer",
		variant = { gui = { kind = "drip", color = 0x9b1a2a } },
	},
	gate_monk = {
		shape = "human",
		faction = "sorcerer",
		variant = {
			color = 0xd88a3a, -- the saffron robe (data's 0x2f8f3a is a trade-dress green)
			hairless = true,
			look = { top = 0xd88a3a, sleeves = 0xd88a3a, bottom = 0x5a4a3a, eye = 0xff8a3d },
			pieces = {
				{ "VS", tint = 0xd88a3a, variant = "robe" },
				{ "SB", tint = 0x4f6b3a },
				{ "GL", n = 2, tint = 0xe8e0d0, variant = "wraps" },
			} :: { any },
		},
	},
	grey = { shape = "human", faction = "grey", variant = { preset = "small", widthScale = 0.7 } },

	-- finale (§5): BUILDERS[builder]
	hyakunui = { builder = "hyakunui", variant = {} },
	tempest_fox = { builder = "tempest_fox", variant = {} },
	the_unbidden = { builder = "the_unbidden", variant = {} },
} :: { [string]: Enemy }

--- The pieces a creature variant mounts: its family with the variant's
--- removals, additions and retiers applied, in family order then additions.
function Costumes.creaturePieces(id: string): { Piece }?
	local e = Costumes.ENEMY[Costumes.baseId(id)]
	local fam = e and e.shape and Costumes.TIER.family[e.shape]
	if not (e and fam) then
		return nil
	end
	local var = e.variant
	local gone: { [string]: boolean } = {}
	for _, r in var.remove or {} do
		gone[r] = true
	end
	local out: { Piece } = {}
	for _, piece in fam do
		if not gone[piece.piece] then
			local tier = (var.retier and var.retier[piece.piece]) or piece.tier
			table.insert(out, { piece = piece.piece, tier = tier, parts = piece.parts })
		end
	end
	for _, a in var.add or {} do
		table.insert(out, a)
	end
	if var.float and e.shape ~= "ufo" then
		table.insert(out, p("SD", "1", 1))
	end
	return out
end

--- A creature's untrimmed costume parts (§4.3 "Parts").
function Costumes.variantParts(id: string): number?
	local pieces = Costumes.creaturePieces(id)
	if not pieces then
		return nil
	end
	local n = 0
	for _, piece in pieces do
		n += piece.parts
	end
	return n
end

--- A human enemy's look: EnemyLooks[baseId] (passed in; the only reader of
--- that data) with banned flags dropped, then the ENEMY override on top.
--- `look.headScale` is clamped to 0.8–1.1 (§1.2).
function Costumes.humanLook(id: string, enemyLooks: { [string]: any }): { [string]: any }
	local base = Costumes.baseId(id)
	local look = Costumes.dropBanned(enemyLooks[base] or {})
	local e = Costumes.ENEMY[base]
	if e and e.variant.look then
		for k, val in e.variant.look do
			look[k] = val
		end
	end
	if type(look.headScale) == "number" then
		look.headScale = math.clamp(look.headScale, 0.8, 1.1)
	end
	return look
end

----------------------------------------------------------------------------
-- ARSENAL_PROP (§2.6): Costumes.ARSENAL_PROP[styleId][weaponKey]
----------------------------------------------------------------------------

-- host = { part, attach, pos, rz? }; pieces = { kind, size (Vec, Cyl as
-- (L, d, d)), tint, material, role, cf? (own host) }. `suit` keys redress
-- the whole figure with `colors` / `preset` instead of mounting a prop.
local CYL_FWD = "CYL_FWD"

local function hilt(): { [string]: any }
	return { kind = "cyl", size = v(0.8, 0.14, 0.14), tint = Costumes.GRIP, material = "SmoothPlastic", role = "hilt" }
end
local function knife(): { [string]: any }
	return {
		parts = 2,
		host = { part = "LowerTorso", attach = "WaistBackAttachment", pos = v(0.7, 0, 0.08) },
		pieces = {
			{ kind = "block", size = v(0.18, 0.8, 0.3), tint = Costumes.WOOD, material = "Wood", role = "sheath" },
			{ kind = "cyl", size = v(0.35, 0.1, 0.1), tint = Costumes.GRIP, material = "SmoothPlastic", role = "grip" },
		},
	}
end
local function splitSoul(rz: number): { [string]: any }
	return {
		parts = 2,
		host = { part = "UpperTorso", attach = "BodyBackAttachment", pos = v(0, 0, 0.14), rz = rz },
		pieces = {
			hilt(),
			{ kind = "block", size = v(0.1, 2.4, 0.26), tint = Costumes.STEEL, material = "Metal", role = "blade" },
		},
	}
end
local function playfulCloud(rz: number): { [string]: any }
	local sec = function(): { [string]: any }
		return {
			kind = "cyl",
			size = v(1.3, 0.2, 0.2),
			tint = Costumes.WOOD,
			material = "Wood",
			role = "section",
			band = 0xc8a44a,
		}
	end
	return {
		parts = 3,
		host = { part = "UpperTorso", attach = "BodyBackAttachment", pos = v(0, 0, 0.14), rz = rz },
		pieces = { sec(), sec(), sec() },
	}
end
local function suitColors(c: number, trim: number): { [string]: number }
	return { skin = c, hair = c, brow = c, top = c, sleeves = c, bottom = c, trim = trim }
end

Costumes.ARSENAL_PROP = {
	toji = {
		spear_chain = {
			parts = 2,
			host = { part = "UpperTorso", attach = "BodyBackAttachment", pos = v(0, 0, 0.14), rz = 35 },
			pieces = {
				{
					kind = "cyl",
					size = v(4.5, 0.12, 0.12),
					tint = Costumes.GRIP,
					material = "SmoothPlastic",
					role = "shaft",
				},
				{ kind = "wedge", size = v(0.1, 0.6, 0.25), tint = Costumes.STEEL, material = "Metal", role = "blade" },
			},
			beam = { to = "belt", color = Costumes.STEEL }, -- the chain, 0 parts
		},
		split_soul = splitSoul(-35),
		playful_cloud = playfulCloud(35),
		slaughter_demon = {
			parts = 2,
			host = { part = "LowerTorso", attach = "WaistBackAttachment", pos = v(0.7, 0, 0.08), rz = 15 },
			pieces = {
				hilt(),
				{ kind = "block", size = v(0.1, 1.2, 0.3), tint = Costumes.STEEL, material = "Metal", role = "blade" },
			},
		},
	},
	maki = {
		naginata = {
			parts = 2,
			host = { part = "UpperTorso", attach = "BodyBackAttachment", pos = v(0, 0, 0.14), rz = 30 },
			pieces = {
				{ kind = "cyl", size = v(4.2, 0.14, 0.14), tint = Costumes.WOOD, material = "Wood", role = "shaft" },
				{ kind = "wedge", size = v(0.1, 1.0, 0.3), tint = Costumes.STEEL, material = "Metal", role = "blade" },
			},
		},
		playful_cloud_m = playfulCloud(30),
		split_soul_m = splitSoul(-30),
		kusarigama = {
			parts = 2,
			host = { part = "LowerTorso", attach = "WaistBackAttachment", pos = v(-0.7, 0, 0.08) },
			pieces = {
				{ kind = "cyl", size = v(0.8, 0.12, 0.12), tint = Costumes.WOOD, material = "Wood", role = "handle" },
				{
					kind = "wedge",
					size = v(0.08, 0.4, 0.7),
					tint = Costumes.STEEL,
					material = "Metal",
					role = "sickle",
				},
			},
			beam = { to = "handle", color = Costumes.STEEL },
		},
	},
	yuji = {
		fists = { parts = 0, glTint = 0xd8683a }, -- no prop; the GL tape turns orange
		knife = knife(),
		slaughter = {
			parts = 2,
			host = { part = "UpperTorso", attach = "BodyBackAttachment", pos = v(0, 0, 0.14), rz = 20 },
			pieces = {
				{
					kind = "block",
					size = v(0.1, 1.3, 0.5),
					tint = Costumes.STEEL,
					material = "Metal",
					role = "cleaver",
				},
				{
					kind = "cyl",
					size = v(0.35, 0.1, 0.1),
					tint = Costumes.GRIP,
					material = "SmoothPlastic",
					role = "grip",
				},
			},
		},
	},
	tophat = {
		pistol = {
			parts = 2,
			host = { part = "LowerTorso", attach = "WaistBackAttachment", pos = v(0.7, 0, 0.08) },
			pieces = {
				{ kind = "block", size = v(0.3, 0.6, 0.25), tint = Costumes.WOOD, material = "Wood", role = "holster" },
				{
					kind = "block",
					size = v(0.15, 0.3, 0.2),
					tint = Costumes.GRIP,
					material = "SmoothPlastic",
					role = "grip",
				},
			},
		},
		rifle = {
			parts = 2,
			host = { part = "UpperTorso", attach = "BodyBackAttachment", pos = v(0, 0, 0.14), rz = 40 },
			pieces = {
				{ kind = "cyl", size = v(2.6, 0.12, 0.12), tint = Costumes.STEEL, material = "Metal", role = "barrel" },
				{ kind = "block", size = v(0.2, 0.35, 0.9), tint = Costumes.WOOD, material = "Wood", role = "stock" },
			},
		},
		sniper = {
			parts = 3,
			host = { part = "UpperTorso", attach = "BodyBackAttachment", pos = v(0, 0, 0.14), rz = 40 },
			pieces = {
				{ kind = "cyl", size = v(3.2, 0.1, 0.1), tint = Costumes.STEEL, material = "Metal", role = "barrel" },
				{ kind = "block", size = v(0.2, 0.35, 0.9), tint = Costumes.WOOD, material = "Wood", role = "stock" },
				{
					kind = "cyl",
					size = v(0.7, 0.16, 0.16),
					tint = Costumes.GRIP,
					material = "SmoothPlastic",
					role = "scope",
				},
			},
		},
		rpg = {
			parts = 2,
			host = { part = "UpperTorso", attach = "BodyBackAttachment", pos = v(0, 0, 0.22), rz = 60 },
			pieces = {
				{ kind = "cyl", size = v(2.4, 0.35, 0.35), tint = Costumes.STEEL, material = "Metal", role = "tube" },
				{ kind = "ball", size = ball(0.4), tint = Costumes.GRIP, material = "SmoothPlastic", role = "warhead" },
			},
		},
		knife = knife(),
	},
	ironman = {
		mark42 = { suit = true, parts = 0, preset = "standard", colors = suitColors(0x3a4250, 0xe8e4dc) },
		hulkbuster = {
			suit = true,
			parts = 0,
			preset = "heavy",
			sgScale = 1.3,
			colors = suitColors(0x5a6270, 0xe8e4dc),
		},
		bleeding = {
			suit = true,
			parts = 0,
			colors = suitColors(0x2a3040, 0x2a3040),
			material = "Metal",
			reflectance = 0.3,
			seam = 0x5ad4ff,
		},
		warmachine = {
			suit = true,
			parts = 2,
			colors = suitColors(0x3a3f46, 0x3a3f46),
			host = { part = "UpperTorso" },
			pieces = {
				{
					kind = "cyl",
					size = v(1.4, 0.35, 0.35),
					tint = 0x3a3f46,
					material = "Metal",
					role = "cannon",
					cf = { pos = v(1.0, 1.0, 0.1), rot = CYL_FWD },
				},
				{
					kind = "cyl",
					size = v(0.1, 0.3, 0.3),
					tint = 0x5ad4ff,
					material = "Neon",
					role = "muzzle",
					cf = { pos = v(1.0, 1.0, -0.65), rot = CYL_FWD },
				},
			},
		},
	},
} :: { [string]: { [string]: { [string]: any } } }

----------------------------------------------------------------------------
-- Ids and roles (§1.5, §4.4, §4.5)
----------------------------------------------------------------------------

function Costumes.baseId(id: string): string
	return (string.gsub(id, "_alpha$", ""))
end

function Costumes.styleFromEnemyId(id: string): string
	local s = string.gsub(id, "^boss_", "")
	s = string.gsub(s, "_b$", "")
	return s
end

--- "finale" | "alpha" | "charBoss" | "elite" | "normal", in that precedence.
--- `isFinale` overrides the Finale.ENEMIES lookup when the caller knows.
function Costumes.role(id: string, t: { [string]: any }?, affix: any?, isFinale: boolean?): string
	local fin = if isFinale ~= nil then isFinale else Finale.ENEMIES[id] ~= nil
	if fin then
		return "finale"
	elseif string.match(id, "_alpha$") then
		return "alpha"
	elseif t and t.boss then
		return "charBoss"
	elseif affix then
		return "elite"
	end
	return "normal"
end

----------------------------------------------------------------------------
-- Colour maths
----------------------------------------------------------------------------

function Costumes.rgb(c: number): (number, number, number)
	return bit32.extract(c, 16, 8), bit32.extract(c, 8, 8), bit32.extract(c, 0, 8)
end

--- Per-channel lerp from `a` toward `b` by `t`, rounded.
function Costumes.lerp(a: number, b: number, t: number): number
	local ar, ag, ab = Costumes.rgb(a)
	local br, bg, bb = Costumes.rgb(b)
	local function ch(x: number, y: number): number
		return math.clamp(math.floor(x + (y - x) * t + 0.5), 0, 255)
	end
	return ch(ar, br) * 65536 + ch(ag, bg) * 256 + ch(ab, bb)
end

--- Normal-foe darkening: 20% toward 0x2a2a30 (§4.1).
function Costumes.darken(c: number): number
	return Costumes.lerp(c, Costumes.FOE_TINT, Costumes.FOE_LERP)
end

--- Character-boss shading: 22% toward 0x14040a (§1.4).
function Costumes.bossShade(c: number): number
	return Costumes.lerp(c, Costumes.BOSS_TINT, Costumes.BOSS_LERP)
end

--- Hue in degrees (0–360), saturation and value (0–1).
function Costumes.hsv(c: number): (number, number, number)
	local r, g, b = Costumes.rgb(c)
	r, g, b = r / 255, g / 255, b / 255
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = 60 * (((g - b) / d) % 6)
		elseif mx == g then
			h = 60 * ((b - r) / d + 2)
		else
			h = 60 * ((r - g) / d + 4)
		end
	end
	return h, (if mx > 0 then d / mx else 0), mx
end

--- Euclidean RGB distance.
function Costumes.dist(a: number, b: number): number
	local ar, ag, ab = Costumes.rgb(a)
	local br, bg, bb = Costumes.rgb(b)
	return math.sqrt((ar - br) ^ 2 + (ag - bg) ^ 2 + (ab - bb) ^ 2)
end

----------------------------------------------------------------------------
-- palette (§4.1)
----------------------------------------------------------------------------

--- `{base, nature, affix}` for an enemy, from its template captured before
--- `Rules.applyAffix` (the affix never reaches `base`).
function Costumes.palette(template: { [string]: any }, affix: any?, entry: Enemy?): Palette
	local nat = RulesData.NATURE[template.nature]
	local natColor: number = if nat then nat.color else 0xe8e8e8
	local base: number = (entry and entry.variant and entry.variant.color) or template.color or natColor
	return { base = base, nature = natColor, affix = if affix then affix.color else nil }
end

----------------------------------------------------------------------------
-- effectiveLook (§6.1)
----------------------------------------------------------------------------

local HAIR_CODES: { [string]: boolean } = {
	["HR"] = true,
	["HR·s"] = true,
	["HR·w"] = true,
	["HR·p"] = true,
	["HR·f"] = true,
	["HR·k"] = true,
	["HR·t"] = true,
	["FLT"] = true,
	["TIP"] = true,
}

local HEAD_CODES: { [string]: boolean } = {
	["FP"] = true,
	["HB"] = true,
	["HB·t"] = true,
	["VB"] = true,
	["VB·m"] = true,
	["LM"] = true,
	["FM"] = true,
	["BK"] = true,
	["HD"] = true,
	["HN"] = true,
	["EP"] = true,
	["EC"] = true,
	["GG"] = true,
	["HP"] = true,
	["CR"] = true,
	["OR"] = true,
	["HAT"] = true,
	["HAT·b"] = true,
	["HAT·c"] = true,
	["HAT·n"] = true,
	["CLP"] = true,
	["LF"] = true,
	["CRY"] = true,
}
for code in HAIR_CODES do
	HEAD_CODES[code] = true
end

-- Bare-skin pieces (§3.0): their tint is a skin use when it is a skin tone.
local SKIN_CODES: { [string]: boolean } = { ["FS"] = true, ["EP"] = true, ["BK"] = true }

-- Keys inside a gui table that hold colours.
local GUI_COLOR_KEYS = { "color", "fill", "stroke", "bg", "ring", "teeth", "beam" }

-- `tints` sub-keys that glow or act as eyes (never darkened for bosses).
local GLOW_TINTS: { [string]: boolean } =
	{ slit = true, lens = true, lenses = true, claw = true, seam = true, beam = true }

local SLOTS = { "skin", "hair", "brow", "eye", "top", "sleeves", "bottom", "trim", "sig" }
local LIMB_SLOT: { [string]: string } =
	{ LeftArm = "sleeves", RightArm = "sleeves", LeftLeg = "bottom", RightLeg = "bottom" }

Costumes.HAIR_CODES = HAIR_CODES
Costumes.HEAD_CODES = HEAD_CODES

--- Every colour the build of a player or character boss uses: the six
--- description colours, limbs, paint, eye, brow, sig, glow, marks, and every
--- kit entry's resolved tint and accent (explicit, else §2.9), its guis,
--- style guis, emitters and the style's props. For "charBoss" the cloth is
--- lerped 22% toward 0x14040a; eye, sig, glow and Neon or glowing colours
--- are not. `data` is accepted and never read (test 5a passes `{}`).
--- `weaponKey` applies a `suit=true` ARSENAL_PROP (ironman) on top.
function Costumes.effectiveLook(styleId: string, role: string?, data: any?, weaponKey: string?): Look
	local _ = data -- never read: STYLE is the only source (§2.7)
	local r = role or "player"
	local s = Costumes.STYLE[styleId]
	if not s then
		local file = "?"
		local world = RulesData.WORLD_OF[styleId]
		if world then
			file = Costumes.UNIVERSE_FILE[world] or file
		end
		local why = Costumes.STYLE_ERRORS[file]
		error(`no STYLE entry for '{styleId}' (Styles/{file}.luau{if why then ": " .. why else ""})`, 2)
	end
	local boss = r == "charBoss"

	-- source colours, with a suit swap on top
	local src: { [string]: number } = {}
	for _, k in SLOTS do
		src[k] = (s.colors :: any)[k]
	end
	local preset = s.preset
	local suit = weaponKey and Costumes.ARSENAL_PROP[styleId] and Costumes.ARSENAL_PROP[styleId][weaponKey]
	if suit and suit.suit then
		for k, c in suit.colors or {} do
			src[k] = c
		end
		preset = suit.preset or preset
	end
	local sig, eye = src.sig, src.eye

	local masked = false
	for _, e in s.kit do
		if e[1] == "FM" then
			masked = true
		end
	end

	local all: { Use } = {}
	local function use(c: number?, where: string, o: { [string]: any }): number?
		if type(c) ~= "number" then
			return nil
		end
		local glow = o.glow == true or c == sig or c == eye
		local out = if boss and not glow then Costumes.bossShade(c) else c
		table.insert(all, {
			color = out,
			base = c,
			where = where,
			code = o.code,
			slot = o.slot,
			hair = o.hair == true,
			skin = o.skin == true,
			head = o.head == true,
			glow = glow,
		})
		return out
	end

	-- the nine colours
	local colors: { [string]: number } = {}
	colors.skin = use(src.skin, "skin", { slot = "skin", skin = not masked, head = true }) :: number
	colors.hair = use(src.hair, "hair", { slot = "hair", hair = true, head = true }) :: number
	colors.brow = use(src.brow, "brow", { slot = "brow", hair = true, head = true }) :: number
	colors.eye = use(src.eye, "eye", { slot = "eye", glow = true, head = true }) :: number
	colors.top = use(src.top, "top", { slot = "top" }) :: number
	colors.sleeves =
		use(src.sleeves, "sleeves", { slot = "sleeves", skin = Costumes.isSkinTone(src.sleeves) }) :: number
	colors.bottom = use(src.bottom, "bottom", { slot = "bottom" }) :: number
	colors.trim = use(src.trim, "trim", { slot = "trim" }) :: number
	colors.sig = use(src.sig, "sig", { slot = "sig", glow = true }) :: number

	local limbs: { [string]: number } = {}
	for limb, c in (s.limbs or {}) :: { [string]: number } do
		local arm = string.match(limb, "Arm$") ~= nil
		limbs[limb] =
			use(c, "limbs." .. limb, { slot = "limbs." .. limb, skin = arm and Costumes.isSkinTone(c) }) :: number
	end
	local body: { [string]: number } = { Head = colors.skin, Torso = colors.top }
	for limb, slotName in LIMB_SLOT do
		body[limb] = limbs[limb] or colors[slotName]
	end

	local paint: { [string]: { color: number, material: string?, reflectance: number? } } = {}
	for part, pe in (s.paint or {}) :: { [string]: any } do
		local c = use(pe.color, "paint." .. part, { glow = pe.material == "Neon", head = part == "Head" })
		paint[part] = { color = c :: number, material = pe.material, reflectance = pe.reflectance }
	end

	local face: { [string]: any } = s.face or {}
	local glowColor: number = if type(face.glow) == "number" then face.glow else sig
	use(glowColor, "glow", { glow = true, head = true })
	local faceGlow: number? = if boss then sig else nil
	if faceGlow then
		use(faceGlow, "faceGlow", { glow = true, head = true })
	end

	local marks: { { color: number, mark: any } } = {}
	for _, m in (face.marks or {}) :: { any } do
		if type(m) == "table" and type(m.color) == "number" then
			local c = use(m.color, "mark", { glow = m.layer == "glow" or m.glow == true, head = true })
			table.insert(marks, { color = c :: number, mark = m })
		end
	end
	if type(face.maw) == "table" and type(face.maw.teeth) == "number" then
		use(face.maw.teeth, "maw.teeth", {})
	end

	local function guiColors(g: any, where: string, o: { [string]: any })
		if type(g) ~= "table" then
			return
		end
		local glowAll = g.glow == true
		for _, key in GUI_COLOR_KEYS do
			if type(g[key]) == "number" then
				use(g[key], where .. "." .. key, { glow = glowAll, head = o.head, code = o.code })
			end
		end
		if type(g.glow) == "number" then
			use(g.glow, where .. ".glow", { glow = true, head = o.head, code = o.code })
		end
	end

	-- kit entries
	local kit: { KitLook } = {}
	for _, e in s.kit do
		local code: string = e[1]
		local isHair = HAIR_CODES[code] == true
		local isHead = HEAD_CODES[code] == true
		local skinPiece = SKIN_CODES[code] == true
		local where = "kit:" .. code
		local def = Costumes.DEFAULT_TINT[code]
		local tint: number?, material: string?, fromSlot: string?, eyeLike = nil, nil, nil, false
		if type(e.tint) == "number" then
			tint = e.tint
			material = e.material or (def and def.material)
		elseif def then
			fromSlot = def.slot
			tint = if def.slot then src[def.slot] else def.color
			material = e.material or def.material
			eyeLike = def.eye == true
		end
		local tintOut = use(tint, where, {
			code = code,
			hair = isHair,
			head = isHead,
			skin = skinPiece and tint ~= nil and Costumes.isSkinTone(tint :: number),
			glow = material == "Neon" or fromSlot == "sig" or fromSlot == "eye" or eyeLike,
		})
		-- several tints (sided pairs, HAT parts, HMR parts)
		if type(e.tints) == "table" then
			local keys = {}
			for k in e.tints do
				table.insert(keys, tostring(k))
			end
			table.sort(keys)
			for _, k in keys do
				local c = e.tints[k]
				local first = use(c, where .. "." .. k, {
					code = code,
					hair = isHair,
					head = isHead,
					skin = skinPiece and type(c) == "number" and Costumes.isSkinTone(c),
					glow = material == "Neon" or GLOW_TINTS[k] == true,
				})
				tintOut = tintOut or first
			end
		end
		-- accent: explicit (`accent`, or the sub-colours in `tints`), else the
		-- code's default second colour
		local adef = Costumes.DEFAULT_ACCENT[code]
		local accent: number?, accentGlow = nil, false
		if type(e.accent) == "number" then
			accent = e.accent
			accentGlow = (adef ~= nil and (adef.eye == true or adef.material == "Neon")) or code == "BA" -- the claw tips are Neon
		elseif adef and type(e.tints) ~= "table" and not (code == "EM" and not e.emblem) then
			accent = if adef.slot then src[adef.slot] else adef.color
			accentGlow = adef.eye == true or adef.material == "Neon" or adef.slot == "sig"
		end
		if code == "GG" and type(e.tint) == "number" and e.accent == nil then
			accent = nil -- one colour for the whole pair
		end
		local accentOut = use(accent, where .. ":accent", { code = code, head = isHead, glow = accentGlow })
		if type(e.emblemColor) == "number" then
			use(e.emblemColor, where .. ":emblem", { code = code, head = isHead })
		end
		if type(e.flash) == "number" then
			use(e.flash, where .. ":flash", { code = code, head = isHead, glow = true })
		end
		guiColors(e.gui, where .. ":gui", { code = code, head = isHead })
		table.insert(kit, {
			code = code,
			entry = e,
			parts = Costumes.entryParts(e),
			tint = tintOut,
			accent = accentOut,
			material = material,
			transparency = def and def.transparency,
			reflectance = e.reflectance or (def and def.reflectance),
		})
	end

	-- style-level guis and emitters
	for i, g in (s.guis or {}) :: { any } do
		local host = g.host or (type(g.parts) == "table" and g.parts[1]) or ""
		guiColors(g, "guis[" .. i .. "]", { head = host == "Head" })
	end
	for i, em in (s.emitters or {}) :: { any } do
		if type(em) == "table" and type(em.color) == "number" then
			use(em.color, "emitters[" .. i .. "]", { glow = true })
		end
	end

	-- the style's props (every key: the build may mount any of them)
	local props = Costumes.ARSENAL_PROP[styleId]
	if props then
		local keys = {}
		for k in props do
			table.insert(keys, k)
		end
		table.sort(keys)
		for _, k in keys do
			local pr = props[k]
			for _, piece in pr.pieces or {} do
				use(piece.tint, "prop:" .. k, { glow = piece.material == "Neon" })
				use(piece.band, "prop:" .. k .. ".band", {})
			end
			for slotName, c in pr.colors or {} do
				use(c, "prop:" .. k .. "." .. slotName, { skin = false })
			end
			use(pr.seam, "prop:" .. k .. ".seam", { glow = true })
			use(pr.glTint, "prop:" .. k .. ".gl", {})
		end
	end

	return {
		styleId = styleId,
		role = r,
		name = s.name,
		preset = preset,
		height = s.height,
		browAngle = s.browAngle or 0.25,
		colors = colors :: any,
		body = body,
		limbs = limbs,
		paint = paint,
		glow = glowColor,
		faceGlow = faceGlow,
		marks = marks,
		kit = kit,
		sigPiece = s.sigPiece,
		suitTN = s.suitTN == true,
		masked = masked,
		all = all,
	}
end

----------------------------------------------------------------------------
-- suitEdge (§2.6, test 13)
----------------------------------------------------------------------------

--- The edge-triggered Suit listener as a pure step: given the last state
--- (nil before the first read) and the attribute value, returns the new
--- state and whether the suit tendrils must be mounted or removed now. The
--- first read reports a change only when the suit is on (the initial mount).
function Costumes.suitEdge(prev: boolean?, value: number?): (boolean, boolean)
	local now = (value or 0) > 0
	if prev == nil then
		return now, now
	end
	return now, now ~= prev
end

return Costumes
