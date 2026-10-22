--!strict
-- Creatures: enemy looks (docs/design/characters.md §4).
--   §4.2/§4.3  creature families (toad, blob, wraith, golem, imp, ufo) and per-enemy variants
--   §4.4       the human-enemy grade ladder, factions, street variant and the grey
--   §4.5       markers by role: Kit.alpha, Kit.affix, Kit.stitch, Kit.riftBoss, Kit.ally
--   §4.6       the friendly ward (Creatures.buildWard)
--
-- Entry point for the integration stage:
--   Creatures.dress(model, opts) -> (partsUsed, builder)
--     opts = { enemyId, role, t (template, post-affix), pal (Costumes.palette, pre-affix),
--              affix?, stitched?, budget?, mapId? (street variant), seed? (variety),
--              look? (EnemyLooks row override), grade? (base grade override) }
--   `model` is the R15 walker, built and not yet parented (§2.1 ground is read from it).
--   Finale ids are not handled here (Finale.luau BUILDERS).
--
-- Creature pieces of toad, blob, wraith and UFO are sized in studs (B already holds t.size) and
-- mount `absolute` on LowerTorso (so the client float bob and hop move them); "on the body"
-- offsets are computed from the body's planned centre because markers (tier 1) and weak points
-- (W) mount before the body (R). Golem and imp pieces are nominal on their visible R15 parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent) :: any
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Costumes = require(Shared:WaitForChild("Costumes")) :: any
local Config = require(Shared:WaitForChild("Config")) :: any

local function optional(path: { string }): any
	local node: any = Shared
	for _, n in path do
		node = node and node:FindFirstChild(n)
	end
	if node and node:IsA("ModuleScript") then
		local ok, r = pcall(require :: any, node)
		if ok then
			return r
		end
	end
	return {}
end
local EnemyLooks: { [string]: any } = optional({ "Data", "EnemyLooks" })
local EnemyData: { [string]: any } = optional({ "Data", "Enemies" })

local Creatures = {}

local STUDS: number = Config.STUDS_PER_UNIT or 2.4
local CYL_UP: CFrame = Kit.CYL_UP
local CYL_FWD: CFrame = Kit.CYL_FWD
local CYAN = 0x5ad4ff
local CRIMSON = 0xff2d55
local GOLD = 0xffd54a
local BLACK = 0x101014

local function V(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function C(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end
local function rx(d: number): CFrame
	return CFrame.Angles(math.rad(d), 0, 0)
end
local function ry(d: number): CFrame
	return CFrame.Angles(0, math.rad(d), 0)
end
local function rz(d: number): CFrame
	return CFrame.Angles(0, 0, math.rad(d))
end
local function LR(s: number): string
	return if s < 0 then "Left" else "Right"
end
local function lerp(a: number, b: number, t: number): number
	return Costumes.lerp(a, b, t)
end

-- web-build SHAPES (Enemies.luau) for B (§4.2)
Creatures.SHAPES = {
	toad = V(2.6, 1.9, 2.6),
	blob = V(2.2, 2.2, 2.2),
	wraith = V(1.8, 2.8, 1.8),
	golem = V(2.6, 3.2, 2),
	imp = V(1.5, 1.7, 1.5),
} :: { [string]: Vector3 }

Creatures.FLOATERS = {
	grade4 = true,
	larva = true,
	wind_spirit = true,
	storm_wraith = true,
	bat_curse = true,
	smoke_curse = true,
	sand_spirit = true,
	mist_leech = true,
	crow_swarm = true,
	mirror_fiend = true,
	goblin_drone = true,
} :: { [string]: boolean }

local ABSOLUTE_FAMILY = { toad = true, blob = true, wraith = true, ufo = true }
Creatures.ABSOLUTE_FAMILY = ABSOLUTE_FAMILY

type Spot = { host: BasePart, attach: string?, cf: CFrame, absolute: boolean? }
type Where = {
	top: Spot,
	plates: { Spot },
	plateKind: string,
	plateSize: Vector3,
	front: { Spot },
	stripSize: Vector3,
	fuse: Spot?,
	footprint: number,
	creature: boolean,
	fxHost: Instance?,
}

--------------------------------------------------------------------------------
-- 0-part SurfaceGui kinds used by enemy looks
--------------------------------------------------------------------------------

local function frame(parent: Instance, pos: UDim2, w: number, h: number, color: Color3, rot: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = UDim2.fromOffset(w, h)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Rotation = rot or 0
	f.Parent = parent
	return f
end
local function dot(parent: Instance, pos: UDim2, d: number, color: Color3)
	local f = frame(parent, pos, d, d, color)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
end

Kit.GUIS.buttons = function(g: SurfaceGui, _spec: any, _w: number, _h: number, col: Color3)
	for i = 1, 3 do
		dot(g, UDim2.fromScale(0.5, 0.2 + 0.25 * (i - 1)), 7, col)
	end
end
Kit.GUIS.hemStripe = function(g: SurfaceGui, _spec: any, w: number, h: number, col: Color3)
	frame(g, UDim2.fromScale(0.5, 0.94), w, math.max(h * 0.06, 4), col)
end
Kit.GUIS.drip = function(g: SurfaceGui, _spec: any, w: number, h: number, col: Color3)
	frame(g, UDim2.fromScale(0.5, 0.12), w * 0.8, 6, col)
	for i, len in { 0.25, 0.4, 0.18, 0.32 } do
		frame(g, UDim2.new(0.18 + 0.2 * (i - 1), 0, 0.12 + len / 2, 0), 5, h * len, col)
	end
end
Kit.GUIS.rivets = function(g: SurfaceGui, _spec: any, _w: number, _h: number, col: Color3)
	for r = 1, 2 do
		for c = 1, 3 do
			dot(g, UDim2.fromScale(c / 4, 0.3 + 0.4 * (r - 1)), 7, col)
		end
	end
end
Kit.GUIS.eyeHoles = function(g: SurfaceGui, _spec: any, _w: number, _h: number, col: Color3)
	for _, x in { 0.3, 0.7 } do
		dot(g, UDim2.fromScale(x, 0.4), 14, col)
	end
end

--------------------------------------------------------------------------------
-- §4.4 ladder and faction pieces registered with the Kit
--------------------------------------------------------------------------------

local function headOf(rig: any): BasePart
	return rig.parts.Head
end

Kit.PIECES.TAL = function(b: any, rig: any, entry: any, _look: any): { BasePart }
	local out = {}
	for _, s in { -1, 1 } do
		local p = b:mount(
			rig.parts.UpperTorso,
			"BodyFrontAttachment",
			"block",
			V(0.15, 0.6, 0.03),
			C(s * 0.4, -0.3, -0.03),
			{ color = entry.tint or 0xe8e0c8, material = "SmoothPlastic", name = "TAL" }
		)
		if p then
			table.insert(out, p)
		end
	end
	return out
end
Kit.PIECES.CUFF = function(b: any, rig: any, entry: any, _look: any): { BasePart }
	-- beanie cuff over the cap: ringOver at y 0.31 needs 1.354 × 1.373 (§2.1)
	local p = b:mount(
		headOf(rig),
		nil,
		"block",
		V(1.40, 0.1, 1.40),
		C(0, 0.31, 0.06),
		{ color = entry.tint or 0x3a3a46, material = "Fabric", name = "CUFF" }
	)
	return if p then { p } else {}
end
Kit.PIECES.PIPE = function(b: any, rig: any, entry: any, _look: any): { BasePart }
	local p = b:mount(
		rig.parts.UpperTorso,
		"BodyBackAttachment",
		"cyl",
		V(1.6, 0.12, 0.12),
		C(0, 0, 0.12) * rz(35) * CYL_UP,
		{ color = entry.tint or 0x6a6e76, material = "Metal", name = "PIPE" }
	)
	return if p then { p } else {}
end
Kit.PIECES.TRIM = function(b: any, rig: any, entry: any, _look: any): { BasePart }
	-- a glowing band round the torso, just above the waist, outside any VS (2.08 × 1.12)
	local p = b:mount(
		rig.parts.UpperTorso,
		nil,
		"block",
		V(2.14, 0.08, 1.16),
		C(0, -0.62, 0),
		{ color = entry.tint or 0xffffff, material = "Neon", name = "TRIM" },
		{ keep = true }
	)
	return if p then { p } else {}
end
Kit.PIECES["CR·1"] = function(b: any, rig: any, entry: any, _look: any): { BasePart }
	local p = b:mount(
		headOf(rig),
		nil,
		"corner",
		V(0.3, 0.5, 0.3),
		C(0, 0.85, 0.06),
		{ color = entry.tint or 0x2a2a30, material = "SmoothPlastic", name = "CR" }
	)
	return if p then { p } else {}
end
Kit.COUNT.TAL = function(_e: any): number
	return 2
end
for _, code in { "CUFF", "PIPE", "TRIM", "CR·1" } do
	Kit.COUNT[code] = function(_e: any): number
		return 1
	end
end

--------------------------------------------------------------------------------
-- §4.5 markers
--------------------------------------------------------------------------------

local function mountSpot(b: any, spot: Spot, kind: string, size: Vector3, extra: CFrame?, props: any): BasePart?
	return b:mount(
		spot.host,
		spot.attach,
		kind,
		size,
		spot.cf * (extra or CFrame.identity),
		props,
		{ absolute = spot.absolute, keep = true }
	)
end

local function humanWhere(rig: any): Where
	local p = rig.parts
	return {
		top = { host = p.Head, cf = C(0, 0.8, 0.06) },
		plates = {
			{ host = p.LeftUpperArm, attach = "LeftShoulderAttachment", cf = C(-0.1, 0.2, 0) * rz(20) },
			{ host = p.RightUpperArm, attach = "RightShoulderAttachment", cf = C(0.1, 0.2, 0) * rz(-20) },
		},
		plateKind = "block",
		plateSize = V(1.2, 0.35, 1.2),
		front = {
			{ host = p.UpperTorso, cf = C(-0.3, 0, -0.53) * rz(30) },
			{ host = p.UpperTorso, cf = C(0.3, 0, -0.53) * rz(-30) },
		},
		stripSize = V(0.08, 0.9 * 1.6, 0.05),
		fuse = { host = p.UpperTorso, attach = "BodyBackAttachment", cf = C(0, 0.6, 0.2) },
		footprint = rig.footprint,
		creature = false,
		fxHost = p.UpperTorso,
	}
end
Creatures.humanWhere = humanWhere

--- The affix (or ally) ring on the HRP at the ground, absolute (§4.5).
function Kit.ring(b: any, rig: any, color: number, footprint: number?, scale: number?): BasePart?
	local d = 1.4 * (footprint or rig.footprint) * (scale or 1)
	return b:mount(
		rig.parts.HumanoidRootPart,
		nil,
		"cyl",
		V(0.12, d, d),
		C(0, rig.ground + 0.03, 0) * CYL_UP,
		{ color = color, material = "Neon", transparency = 0.35, name = "RING" },
		{ absolute = true, keep = true }
	)
end

--- Alpha crest (1 part) and the dust emitter (§4.5). Call inside a tier-1 entry.
function Kit.alpha(b: any, rig: any, where: Where?): { BasePart }
	local w = where or humanWhere(rig)
	local p = mountSpot(b, w.top, "corner", V(0.5, 0.45, 0.5), nil, { color = GOLD, material = "Neon", name = "CREST" })
	local fx = Kit.fx(rig, "dust", "feet")
	for _, e in fx do
		b:track(e.Parent)
	end
	return if p then { p } else {}
end

--- Parts the affix marker adds (ring + motif).
function Creatures.affixParts(affix: any, creature: boolean): number
	local key = affix and affix.key
	if key == "frenzied" then
		return 2
	elseif key == "armored" then
		return 3
	elseif key == "volatile" and not creature then
		return 2
	end
	return 1
end

--- Elite ring plus motif (§4.5). Call inside a tier-1 entry.
function Kit.affix(b: any, rig: any, affix: any, where: Where?): { BasePart }
	local w = where or humanWhere(rig)
	local out = {}
	local key = affix.key
	local ring = Kit.ring(b, rig, affix.color, w.footprint, if key == "giant" then 1.6 else 1)
	if ring then
		table.insert(out, ring)
	end
	if key == "frenzied" then
		local p = mountSpot(b, w.top, "wedge", V(0.2, 0.6, 0.4), if w.creature then C(0, 0.15, 0) else nil, {
			color = affix.color,
			material = "Neon",
			name = "SPIKE",
		})
		if p then
			table.insert(out, p)
			Kit.emitter(p, "spark", { color = affix.color })
		end
	elseif key == "armored" then
		for _, s in w.plates do
			local p = mountSpot(
				b,
				s,
				w.plateKind,
				w.plateSize,
				nil,
				{ color = affix.color, material = "DiamondPlate", name = "ARMOR" }
			)
			if p then
				table.insert(out, p)
			end
		end
	elseif key == "vampiric" then
		if w.fxHost then
			Kit.emitter(w.fxHost, "drip", { color = affix.color })
		end
	elseif key == "volatile" then
		rig.model:SetAttribute("Volatile", true)
		if not w.creature and w.fuse then
			local p = mountSpot(
				b,
				w.fuse,
				"ball",
				V(0.35, 0.35, 0.35),
				nil,
				{ color = affix.color, material = "Neon", name = "FUSE" }
			)
			if p then
				p:SetAttribute("Pulse", 3)
				table.insert(out, p)
			end
		end
	end
	rig.model:SetAttribute("Affix", affix.name)
	return out
end

--- Stitched (§4.5): a crimson ring and 2 crimson strips that replace the motif. 3 parts.
function Kit.stitch(b: any, rig: any, affix: any?, where: Where?): { BasePart }
	local w = where or humanWhere(rig)
	local out = {}
	local ring = Kit.ring(b, rig, CRIMSON, w.footprint)
	if ring then
		table.insert(out, ring)
	end
	for _, s in w.front do
		local p = mountSpot(b, s, "block", w.stripSize, nil, { color = CRIMSON, material = "Neon", name = "STRIP" })
		if p then
			table.insert(out, p)
		end
	end
	rig.model:SetAttribute("Stitched", true)
	if affix then
		rig.model:SetAttribute("Affix", affix.name)
	end
	return out
end

--- Character-boss dressing (§4.5): the rift halo (3 Beams, 0 parts), aura and one PointLight.
function Kit.riftBoss(model: Model): ()
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		local k = head.Size.Y / 1.2
		local r = 0.7 * k
		local centre = V(0, 0.3 * k, 0.75 * k)
		local atts = {}
		for i = 0, 2 do
			local a = math.rad(120 * i)
			local pos = centre + V(r * math.sin(a), r * math.cos(a), 0)
			local tangent = V(math.cos(a), -math.sin(a), 0)
			local att = Instance.new("Attachment")
			att.Name = "Halo" .. i
			att.CFrame = CFrame.fromMatrix(pos, tangent, V(0, 0, 1):Cross(tangent))
			att.Parent = head
			atts[i + 1] = att
		end
		local handle = r * 4 / 3 * math.tan(math.rad(30))
		for i = 1, 3 do
			local beam = Instance.new("Beam")
			beam.Name = "Halo"
			beam.Attachment0 = atts[i]
			beam.Attachment1 = atts[i % 3 + 1]
			beam.CurveSize0 = handle
			beam.CurveSize1 = -handle
			beam.Width0 = 0.18
			beam.Width1 = 0.18
			beam.Segments = 10
			beam.LightEmission = 1
			beam.FaceCamera = true
			beam.Color = ColorSequence.new(Color3.fromRGB(255, 45, 85))
			beam.Transparency = NumberSequence.new(0)
			beam.Parent = head
		end
	end
	local rig = Kit.rig(model)
	if rig.parts.HumanoidRootPart then
		Kit.fx(rig, "aura", "feet")
	end
	local ut = model:FindFirstChild("UpperTorso")
	if ut then
		local light = Instance.new("PointLight")
		light.Name = "RiftLight"
		light.Range = 14
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 45, 85)
		light.Parent = ut
	end
end

--- Ally / Worn (§4.5): friend face, ring or SD cyan (a ring is added if there is none), stitched
--- strips removed, Highlight destroyed. Pass Enemies.releaseHighlight as `release`.
function Kit.ally(model: Model, release: ((Model) -> ())?): ()
	local fp = Kit.faceOf(model)
	if fp then
		local base = fp:FindFirstChild("FaceBase") :: SurfaceGui?
		local glow = fp:FindFirstChild("FaceGlow") :: SurfaceGui?
		if base and glow then
			for _, side in { "L", "R" } do
				local iris = glow:FindFirstChild("Iris" .. side) :: Frame?
				if iris then
					iris.Parent = base
					iris.Size = UDim2.fromOffset(7, 8)
					iris.ZIndex = 2
				end
				for _, n in { "White", "Pupil" } do
					local f = base:FindFirstChild(n .. side) :: Frame?
					if f then
						f.Visible = true
					end
				end
			end
			glow.Enabled = false
		end
	end
	local costume = model:FindFirstChild("Costume")
	local ringed = false
	if costume then
		for _, d in costume:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "STRIP" then
					d:Destroy()
				elseif d.Name == "RING" or d.Name == "SD" then
					d.Color = Color3.fromRGB(90, 212, 255)
					d.Material = Enum.Material.Neon
					ringed = true
				end
			end
		end
	end
	if not ringed and model:FindFirstChild("HumanoidRootPart") then
		local b = Kit.new(model, 1)
		local fpAttr = model:GetAttribute("Footprint")
		Kit.ring(b, Kit.rig(model), CYAN, if type(fpAttr) == "number" then fpAttr else nil)
	end
	for _, h in model:GetChildren() do
		if h:IsA("Highlight") then
			h:Destroy()
		end
	end
	model:SetAttribute("Worn", true)
	if release then
		release(model)
	end
end

--------------------------------------------------------------------------------
-- Role colours (§1.4, §4.1)
--------------------------------------------------------------------------------

--- Cloth/body colour for a role: normal darkened 20%, alpha a further 15% darker.
function Creatures.shade(c: number, role: string): number
	if role == "normal" then
		return Costumes.darken(c)
	elseif role == "alpha" then
		return lerp(Costumes.darken(c), 0x000000, 0.15)
	end
	return c
end

--- FaceGlow / eye colour for a role.
function Creatures.eyeColor(role: string, affix: any?, stitched: boolean?, default: number?): number
	if role == "alpha" then
		return GOLD
	elseif stitched then
		return CRIMSON
	elseif role == "elite" and affix then
		return affix.color
	elseif role == "ally" then
		return CYAN
	end
	return default or 0xffe45c
end

--------------------------------------------------------------------------------
-- Creature families (§4.2, §4.3)
--------------------------------------------------------------------------------

type Cx = {
	model: Model,
	rig: any,
	b: any,
	t: any,
	pal: any,
	id: string,
	shape: string,
	var: { [string]: any },
	role: string,
	affix: any?,
	stitched: boolean,
	B: number,
	s: number,
	g: number, -- ground in LowerTorso space
	lt: BasePart,
	c: Vector3, -- main body centre (LowerTorso space)
	size: Vector3, -- main body size
	col: { [string]: number },
	mat: string,
	tr: number,
	refl: number,
	parts: { [string]: { BasePart } },
	weak: { BasePart },
	footprint: number,
}

local function rel(a: BasePart, b: BasePart): CFrame
	return a.CFrame:ToObjectSpace(b.CFrame)
end

local function props(cx: Cx, color: number, mat: string?, extra: { [string]: any }?): any
	local p: { [string]: any } = {
		color = color,
		material = mat or cx.mat,
		transparency = if mat == nil then cx.tr else 0,
		reflectance = if mat == nil then cx.refl else 0,
	}
	for k, v in (extra or {}) :: { [string]: any } do
		p[k] = v
	end
	return p
end

-- absolute mount on LowerTorso at a LowerTorso-space frame
local function lt(cx: Cx, kind: string, size: Vector3, cf: CFrame, pr: any, keep: boolean?): BasePart?
	return cx.b:mount(cx.lt, nil, kind, size, cf, pr, { absolute = true, keep = keep })
end
-- ...on the body: offset from the body's centre
local function body(cx: Cx, kind: string, size: Vector3, off: CFrame, pr: any, keep: boolean?): BasePart?
	return lt(cx, kind, size, CFrame.new(cx.c) * off, pr, keep)
end
-- absolute mount on UpperTorso, offset from its centre
local function ut(cx: Cx, kind: string, size: Vector3, off: CFrame, pr: any): BasePart?
	return cx.b:mount(cx.rig.parts.UpperTorso, nil, kind, size, off, pr, { absolute = true })
end
-- nominal mount (golem, imp)
local function nom(
	cx: Cx,
	host: string,
	attach: string?,
	kind: string,
	size: Vector3,
	cf: CFrame,
	pr: any,
	keep: boolean?
)
	return cx.b:mount(cx.rig.parts[host], attach, kind, size, cf, pr, { keep = keep })
end

local function ball(d: number): Vector3
	return V(d, d, d)
end

type PieceFns = { [string]: (Cx) -> () }
local FAMILY: { [string]: PieceFns } = {}

-- toad ------------------------------------------------------------------------------------
FAMILY.toad = {
	wart = function(cx)
		local B = cx.B
		body(cx, "ball", ball(0.18 * B), C(0.2 * B, 0.3 * B, 0.15 * B), props(cx, cx.col.weak, "Neon"), true)
	end,
	body = function(cx)
		body(cx, "ell", cx.size, CFrame.identity, props(cx, cx.col.body))
	end,
	domes = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(cx, "ball", ball(0.34 * B), C(s * 0.25 * B, 0.3 * B, -0.3 * B), props(cx, cx.col.body))
		end
	end,
	pupils = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(
				cx,
				"block",
				V(0.04, 0.2, 0.02) * B,
				C(s * 0.25 * B, 0.3 * B, -0.48 * B),
				props(cx, cx.col.eye, "Neon"),
				true
			)
		end
	end,
	hind = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			local p = lt(
				cx,
				"block",
				V(0.35, 0.08, 0.5) * B,
				C(s * 0.4 * B, cx.g + 0.04 * B, 0.35 * B),
				props(cx, cx.col.dark)
			)
			if p then
				cx.b:gait(if s < 0 then "HL" else "HR", V(s * 0.4 * B, 0, 0.3 * B), 0.5, 22, p)
			end
		end
	end,
	front = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			local p = lt(
				cx,
				"block",
				V(0.3, 0.3, 0.35) * B,
				C(s * 0.35 * B, cx.g + 0.15 * B, -0.4 * B),
				props(cx, cx.col.dark)
			)
			if p then
				cx.b:gait(if s < 0 then "FL" else "FR", V(s * 0.35 * B, -0.1 * B, -0.35 * B), 0, 22, p)
			end
		end
	end,
	mouth = function(cx)
		body(
			cx,
			"block",
			V(0.9 * cx.B, 0.08, 0.1),
			C(0, -0.05 * cx.B, -0.47 * cx.B),
			props(cx, 0x1a1a20, "SmoothPlastic")
		)
	end,
	haunches = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(cx, "ell", V(0.45, 0.4, 0.55) * B, C(s * 0.45 * B, -0.1 * B, 0.3 * B), props(cx, cx.col.body))
		end
	end,
	wart2 = function(cx)
		local B = cx.B
		body(cx, "ball", ball(0.14 * B), C(-0.25 * B, 0.25 * B, 0.25 * B), props(cx, cx.col.weak, "SmoothPlastic"))
	end,
	tongue = function(cx)
		local B = cx.B
		body(cx, "wedge", V(0.25, 0.05, 0.4) * B, C(0, -0.14 * B, -0.6 * B), props(cx, 0xe88aa0, "SmoothPlastic"))
	end,
}

-- blob ------------------------------------------------------------------------------------
local function blobEye(cx: Cx, z: number)
	local B = cx.B
	body(cx, "ball", ball(0.4 * B), C(0, 0.15 * B, z * B), props(cx, 0xf4f0ea, "SmoothPlastic"), true)
	body(cx, "ball", ball(0.22 * B), C(0, 0.15 * B, (z - 0.16) * B), props(cx, cx.col.eye, "Neon"), true)
	body(cx, "ball", ball(0.1 * B), C(0, 0.15 * B, (z - 0.25) * B), props(cx, BLACK, "SmoothPlastic"), true)
end

FAMILY.blob = {
	core = function(cx)
		body(cx, "ball", ball(0.55 * cx.B), CFrame.identity, props(cx, cx.col.weak, "Neon"), true)
	end,
	jelly = function(cx)
		local pr = props(cx, cx.col.body, nil, { transparency = math.max(cx.tr, 0.35) })
		body(cx, "ell", cx.size, CFrame.identity, pr)
	end,
	eye = function(cx)
		blobEye(cx, if cx.id == "larva" then -0.62 else -0.42)
	end,
	tendrils = function(cx)
		local B = cx.B
		local toUT = rel(cx.rig.parts.UpperTorso, cx.lt)
		local bottom = cx.c.Y - 0.5 * B
		for _, s in { -1, 1 } do
			local top = toUT * V(s * 0.3 * B, bottom + 0.1 * B, 0)
			local p = ut(
				cx,
				"cyl",
				V(0.6, 0.12, 0.12) * B,
				CFrame.new(top - V(0, 0.3 * B, 0)) * CYL_UP,
				props(cx, cx.col.body)
			)
			if p then
				cx.b:gait(if s < 0 then "TL" else "TR", top, if s < 0 then 0 else 0.5, 15, p)
			end
		end
	end,
	mouth = function(cx)
		body(
			cx,
			"block",
			V(0.5 * cx.B, 0.06, 0.05),
			C(0, -0.1 * cx.B, -0.5 * cx.B),
			props(cx, 0x1a1a20, "SmoothPlastic")
		)
	end,
	drips = function(cx)
		local B = cx.B
		for _, o in { V(-0.3, -0.38, -0.2), V(0.32, -0.3, 0.1), V(0, -0.45, 0.25) } do
			body(cx, "ball", ball(0.15 * B), CFrame.new(o * B), props(cx, cx.col.body))
		end
	end,
	segments = function(cx)
		local B = cx.B
		for i, row: any in
			{ { 0.6 :: any, V(0, 0, -0.2) }, { 0.5 :: any, V(0, -0.05, 0.3) }, { 0.4 :: any, V(0, -0.1, 0.72) } } :: { any }
		do
			local _ = i
			body(cx, "ball", ball(row[1] * B), CFrame.new(row[2] * B), props(cx, cx.col.body))
		end
	end,
	mandibles = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(
				cx,
				"wedge",
				V(0.08, 0.12, 0.3) * B,
				C(s * 0.12 * B, -0.18 * B, -0.62 * B) * ry(180),
				props(cx, cx.col.dark, "SmoothPlastic")
			)
		end
	end,
	curledCore = function(cx)
		local B = cx.B
		for _, row: any in { { 0.4 :: any, V(-0.08, 0, 0) }, { 0.3 :: any, V(0.12, 0.1, 0.05) } } :: { any } do
			local p = body(cx, "ball", ball(row[1] * B), CFrame.new(row[2] * B), props(cx, cx.col.weak, "Neon"), true)
			if p then
				p:SetAttribute("Pulse", 1.5)
			end
		end
	end,
	funnel = function(cx)
		body(
			cx,
			"cyl",
			V(0.3, 0.3, 0.3) * cx.B,
			C(0, -0.1 * cx.B, -0.55 * cx.B) * CYL_FWD,
			props(cx, cx.col.dark, "SmoothPlastic")
		)
	end,
	reelFace = function(cx)
		local B = cx.B
		local p = body(
			cx,
			"block",
			V(0.6 * B, 0.3 * B, 0.02),
			C(0, 0.12 * B, -0.51 * B),
			props(cx, 0xffffff, "SmoothPlastic", { transparency = 1, name = "ReelFace" }),
			true
		)
		if p then
			Kit.gui({ p }, { kind = "reels", color = cx.col.eye, glow = true, face = "Front" }, nil, nil)
		end
	end,
}

-- wraith ----------------------------------------------------------------------------------
local function hemSpots(cx: Cx): { CFrame }
	local B = cx.B
	local out = {}
	for _, x in { -0.3, 0, 0.3 } do
		table.insert(out, C(x * B, -0.62 * B, (if x == 0 then -0.42 else -0.32) * B) * ry(x * 60))
	end
	return out
end

FAMILY.wraith = {
	eyes = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(
				cx,
				"block",
				V(0.14, 0.05, 0.03) * B,
				C(s * 0.12 * B, 0.1 * B, -0.54 * B) * rz(-s * 12),
				props(cx, cx.col.eye, "Neon"),
				true
			)
		end
	end,
	hood = function(cx)
		body(cx, "ell", cx.size, CFrame.identity, props(cx, cx.col.body))
	end,
	peak = function(cx)
		local B = cx.B
		body(cx, "wedge", V(0.3, 0.5, 0.4) * B, C(0, 0.62 * B, 0.12 * B) * ry(180), props(cx, cx.col.body))
	end,
	void = function(cx)
		local B = cx.B
		body(cx, "ell", V(0.6, 0.7, 0.3) * B, C(0, 0.02 * B, -0.38 * B), props(cx, 0x08080c, "SmoothPlastic"))
	end,
	tail = function(cx)
		local B = cx.B
		body(cx, "ell", V(0.7, 1.0, 0.7) * B, C(0, -0.8 * B, 0.18 * B) * rx(-20), props(cx, cx.col.body))
		local tip = body(cx, "ell", V(0.45, 0.8, 0.45) * B, C(0, -1.4 * B, 0.45 * B) * rx(-35), props(cx, cx.col.body))
		if tip then
			cx.parts.tailTip = { tip }
		end
	end,
	claws = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			ut(
				cx,
				"wedge",
				V(0.1, 0.5, 0.3) * B,
				C(s * 0.6 * B, -0.3 * B, -0.3 * B),
				props(cx, cx.col.dark, "SmoothPlastic")
			)
		end
	end,
	hem = function(cx)
		for _, cf in hemSpots(cx) do
			body(cx, "wedge", V(0.3, 0.5, 0.1) * cx.B, cf, props(cx, cx.col.dark))
		end
	end,
	hem1 = function(cx)
		body(cx, "wedge", V(0.3, 0.5, 0.1) * cx.B, hemSpots(cx)[2], props(cx, cx.col.dark))
	end,
	crackle = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(
				cx,
				"block",
				V(0.06, 0.5, 0.06) * B,
				C(s * 0.3 * B, -0.6 * B, -0.3 * B) * rz(s * 20),
				props(cx, 0xffe45c, "Neon"),
				true
			)
		end
	end,
	wings = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(
				cx,
				"wedge",
				V(0.06, 0.9, 0.9) * B,
				C(s * 0.75 * B, 0.1 * B, 0.2 * B) * rz(-s * 40),
				props(cx, cx.col.dark)
			)
		end
	end,
	ears = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(cx, "wedge", V(0.12, 0.4, 0.2) * B, C(s * 0.28 * B, 0.65 * B, 0) * rz(-s * 15), props(cx, cx.col.body))
		end
	end,
	lantern = function(cx)
		body(cx, "ball", ball(0.25 * cx.B), C(0, 0.05 * cx.B, -0.5 * cx.B), props(cx, cx.col.eye, "Neon"), true)
	end,
	facePlate = function(cx)
		local B = cx.B
		local p =
			body(cx, "block", V(0.55, 0.6, 0.06) * B, C(0, 0.02 * B, -0.47 * B), props(cx, 0xd8ccb8, "SmoothPlastic"))
		if p then
			Kit.gui({ p }, { kind = "eyeHoles", color = 0x14100c, face = "Front" }, nil, nil)
		end
	end,
	leadCrow = function(cx)
		body(cx, "ball", ball(0.45 * cx.B), CFrame.identity, props(cx, cx.col.body), true)
	end,
	crows = function(cx)
		local B = cx.B
		for _, s in { -1, 1 } do
			body(cx, "ball", ball(0.35 * B), C(s * 0.5 * B, -0.3 * B, 0.3 * B), props(cx, cx.col.body))
		end
	end,
	beaks = function(cx)
		local B = cx.B
		for _, o in { V(0, 0, -0.3), V(-0.5, -0.3, 0.08), V(0.5, -0.3, 0.08) } do
			body(cx, "wedge", V(0.1, 0.1, 0.25) * B, CFrame.new(o * B) * ry(180), props(cx, 0xc8a44a, "SmoothPlastic"))
		end
	end,
	shards = function(cx)
		for _, cf in hemSpots(cx) do
			body(cx, "wedge", V(0.15, 0.6, 0.3) * cx.B, cf, props(cx, cx.col.body))
		end
	end,
}

-- golem (nominal) -------------------------------------------------------------------------
local function golemShard(cx: Cx, xs: { number }, color: number?)
	for _, x in xs do
		nom(
			cx,
			"UpperTorso",
			nil,
			"wedge",
			V(0.3, 1.0, 0.4),
			C(x, 0.5, 0.65) * ry(180),
			props(cx, color or cx.col.body)
		)
	end
end

FAMILY.golem = {
	core = function(cx)
		nom(cx, "UpperTorso", nil, "block", V(0.12, 1.0, 0.1), C(0, 0.1, -0.62), props(cx, cx.col.weak, "Neon"), true)
	end,
	chest = function(cx)
		local list = {}
		for _, s in { -1, 1 } do
			local p =
				nom(cx, "UpperTorso", nil, "wedge", V(1.0, 1.5, 0.6), C(s * 0.575, 0.05, -0.3), props(cx, cx.col.body))
			if p then
				table.insert(list, p)
			end
		end
		if cx.var.gui and #list > 0 then
			Kit.gui(list, { kind = cx.var.gui.kind, color = cx.col.dark, face = "Back" }, nil, nil)
		end
	end,
	band = function(cx)
		nom(
			cx,
			"Head",
			"FaceFrontAttachment",
			"block",
			V(0.9, 0.12, 0.05),
			C(0, 0.12, -0.03),
			props(cx, cx.col.eye, "Neon"),
			true
		)
	end,
	brow = function(cx)
		nom(cx, "Head", nil, "wedge", V(1.2, 0.3, 0.4), C(0, 0.3, -0.5), props(cx, cx.col.body))
	end,
	shards = function(cx)
		golemShard(cx, { -0.4, 0.4 })
	end,
	gauntlets = function(cx)
		for _, s in { -1, 1 } do
			nom(cx, LR(s) .. "LowerArm", nil, "block", V(1.4, 1.47, 1.4), C(0, -0.1, 0), props(cx, cx.col.dark))
		end
	end,
	boulders = function(cx)
		for _, s in { -1, 1 } do
			nom(
				cx,
				LR(s) .. "UpperArm",
				LR(s) .. "ShoulderAttachment",
				"ball",
				ball(1.3),
				C(s * 0.1, 0.2, 0),
				props(cx, cx.col.body)
			)
		end
	end,
	moss = function(cx)
		golemShard(cx, { -0.4, 0.4 }, 0x4f6b3a)
	end,
	fingers = function(cx)
		for i = -2, 2 do
			local x = 0.22 * i
			nom(
				cx,
				"UpperTorso",
				nil,
				"cyl",
				V(1.0, 0.2, 0.2),
				C(x, 0.75, 0.62) * rz(-i * 12) * rx(20) * CYL_UP,
				props(cx, cx.col.body)
			)
		end
	end,
	facePlate = function(cx)
		local p = nom(cx, "Head", nil, "block", V(1.0, 0.5, 0.08), C(0, 0.25, -0.64), props(cx, 0xc8a44a, "Metal"))
		if p and cx.var.emblem then
			Kit.emblem(p, cx.var.emblem, { stroke = 0x5a4a2a })
		end
	end,
	anvilHead = function(cx)
		nom(cx, "Head", nil, "block", V(1.5, 0.5, 1.0), C(0, 0.55, 0), props(cx, cx.col.dark, "Metal"))
	end,
	shard = function(cx)
		golemShard(cx, { 0 })
	end,
	waistWeight = function(cx)
		nom(cx, "LowerTorso", nil, "block", V(1.2, 0.5, 0.6), C(0, -0.1, 0.65), props(cx, cx.col.dark, "Metal"))
	end,
}

-- imp (nominal) ---------------------------------------------------------------------------
FAMILY.imp = {
	FP = function(cx)
		local fp = Kit.PIECES.FP(cx.b, cx.rig, { "FP" }, {})[1]
		if fp then
			local grin = if cx.var.add and cx.id == "goblin_drone"
				then {}
				else {
					{ x = 45, y = 44, w = 34, h = 4, color = cx.col.weak, layer = "glow" },
					{ x = 30, y = 40, w = 4, h = 8, rot = 20, color = cx.col.weak, layer = "glow" },
					{ x = 60, y = 40, w = 4, h = 8, rot = -20, color = cx.col.weak, layer = "glow" },
				}
			Kit.face(cx.model, fp, { friend = false, hideEyes = true, mouth = false, marks = grin })
			cx.weak = cx.weak or {}
		end
	end,
	horns = function(cx)
		Kit.PIECES.HN(cx.b, cx.rig, { "HN", tint = cx.col.dark }, {})
	end,
	eyes = function(cx)
		for _, s in { -1, 1 } do
			nom(
				cx,
				"Head",
				"FaceFrontAttachment",
				"ball",
				ball(0.2),
				C(s * 0.24, 0.12, -0.05),
				props(cx, cx.col.eye, "Neon"),
				true
			)
		end
	end,
	belly = function(cx)
		nom(cx, "UpperTorso", nil, "ell", V(1.3, 1.0, 1.1), C(0, -0.2, -0.1), props(cx, cx.col.light))
	end,
	tail = function(cx)
		local lens = { 0.8, 0.8, 0.35 }
		local bones = Kit.chain(V(0, 0, 0.05), { rx(110), rx(-50), rx(-20) }, lens)
		local pr = props(cx, cx.col.body)
		nom(cx, "LowerTorso", "WaistBackAttachment", "cyl", V(0.8, 0.12, 0.12), bones[1] * CYL_UP, pr)
		nom(cx, "LowerTorso", "WaistBackAttachment", "cyl", V(0.8, 0.12, 0.12), bones[2] * CYL_UP, pr)
		local spade =
			nom(cx, "LowerTorso", "WaistBackAttachment", "wedge", V(0.1, 0.35, 0.35), bones[3], props(cx, cx.col.dark))
		if spade then
			cx.parts.spade = { spade }
		end
	end,
	wings = function(cx)
		for _, s in { -1, 1 } do
			nom(
				cx,
				"UpperTorso",
				"BodyBackAttachment",
				"wedge",
				V(0.1, 1.2, 0.9),
				C(s * 0.4, 0.3, 0.1) * rz(-s * 30),
				props(cx, cx.col.dark)
			)
		end
	end,
	needles = function(cx)
		for _, x in { -0.45, -0.15, 0.15, 0.45 } do
			nom(
				cx,
				"UpperTorso",
				"BodyBackAttachment",
				"cyl",
				V(1.2, 0.08, 0.08),
				C(x, 0.5, 0.2) * rz(-x * 50) * rx(25) * CYL_UP,
				props(cx, 0x9aa4b0, "Metal")
			)
		end
	end,
	ramHorns = function(cx)
		for _, s in { -1, 1 } do
			nom(cx, "Head", nil, "corner", V(0.25, 0.4, 0.5), C(s * 0.38, 0.5, -0.1) * ry(180), props(cx, cx.col.dark))
		end
	end,
	vertebrae = function(cx)
		for i = 0, 3 do
			nom(
				cx,
				"UpperTorso",
				"BodyBackAttachment",
				"block",
				V(0.3, 0.2, 0.2),
				C(0, 0.6 - 0.4 * i, 0.12),
				props(cx, cx.col.light)
			)
		end
	end,
	beak = function(cx)
		Kit.PIECES.BK(cx.b, cx.rig, { "BK", tint = cx.col.dark }, {})
	end,
	hoverDisc = function(cx)
		local k = cx.lt.Size.Y / 0.4
		nom(
			cx,
			"LowerTorso",
			nil,
			"cyl",
			V(0.1, 1.4, 1.4),
			C(0, (cx.g + 0.08) / k, 0) * CYL_UP,
			props(cx, cx.col.dark, "Metal")
		)
	end,
}

-- ufo (all × t.size, absolute) ------------------------------------------------------------
FAMILY.ufo = {
	ring = function(cx)
		local s = cx.s
		body(cx, "cyl", V(0.2, 2.4, 2.4) * s, C(0, -0.4 * s, 0) * CYL_UP, props(cx, cx.col.weak, "Neon"), true)
	end,
	saucer = function(cx)
		body(cx, "cyl", cx.size.Y * V(1, 0, 0) + V(0, cx.size.X, cx.size.Z), CYL_UP, props(cx, cx.col.body, "Metal"))
	end,
	dome = function(cx)
		local s = cx.s
		body(cx, "ball", ball(1.8 * s), C(0, 0.45 * s, 0), props(cx, 0x9fd8ff, "Glass", { transparency = 0.4 }))
	end,
	rim = function(cx)
		local s = cx.s
		for i = 0, 3 do
			local a = math.rad(45 + 90 * i)
			body(
				cx,
				"ball",
				ball(0.3 * s),
				C(2.1 * s * math.sin(a), 0, 2.1 * s * math.cos(a)),
				props(cx, cx.col.eye, "Neon"),
				true
			)
		end
	end,
}

--- Builds the context: B, ground and the main body for a creature.
local function creatureCx(model: Model, opts: any, b: any, rig: any, e: any): Cx
	local id: string = opts.enemyId
	local t = opts.t or {}
	local shape: string = e.shape
	local var = e.var or e.variant or {}
	local s: number = t.size or 1
	local ltPart = rig.parts.LowerTorso :: BasePart
	local hrp = rig.parts.HumanoidRootPart :: BasePart
	local hrpInLt = rel(ltPart, hrp)
	local g = (hrpInLt * V(0, rig.ground, 0)).Y
	local shapeSize = Creatures.SHAPES[shape] or V(2, 2, 2)
	local B = shapeSize.X * STUDS * 0.55 * s
	local role: string = opts.role
	local pal = opts.pal or { base = t.color or 0x8a8a90, nature = 0xe8e8e8 }
	local baseCol = Creatures.shade(pal.base, role)
	local float = Creatures.FLOATERS[Costumes.baseId(id)] == true
	local c, size = Vector3.zero, V(B, B, B)
	if shape == "toad" then
		size = V(1.0, 0.75, 1.0) * B
		c = V(0, g + 0.3 + size.Y / 2, 0)
	elseif shape == "blob" then
		c = V(0, g + 0.5 * B + (if float then 0.6 else 0.1), 0)
		if Costumes.baseId(id) == "larva" then
			c = V(0, g + 0.4 * B + 0.6, 0)
			size = ball(0.6 * B)
		end
	elseif shape == "wraith" then
		size = V(1.0, 1.2, 1.0) * B
		c = V(0, g + 1.95 * B, 0)
		if Costumes.baseId(id) == "crow_swarm" then
			c = V(0, g + 1.4 * B, 0)
			size = ball(0.45 * B)
		end
	elseif shape == "ufo" then
		c = V(0, hrpInLt.Y + 1.5 * s, 0)
		size = V(4.2, 0.6, 4.2) * s
		B = 2 * s
	end
	local col = {
		body = baseCol,
		dark = lerp(baseCol, BLACK, 0.45),
		light = lerp(baseCol, 0xe8dcc8, 0.3),
		eye = Creatures.eyeColor(role, opts.affix, opts.stitched, var.eye),
		weak = var.weak or pal.nature or 0xffe45c,
	}
	if var.dark then
		col.dark = var.dark
	end
	return {
		model = model,
		rig = rig,
		b = b,
		t = t,
		pal = pal,
		id = Costumes.baseId(id),
		shape = shape,
		var = var,
		role = role,
		affix = opts.affix,
		stitched = opts.stitched == true,
		B = B,
		s = s,
		g = g,
		lt = ltPart,
		c = c,
		size = size,
		col = col,
		mat = var.material or "SmoothPlastic",
		tr = var.transparency or 0,
		refl = var.reflectance or 0,
		parts = {},
		weak = {},
		footprint = if shape == "golem" or shape == "imp" then rig.footprint else math.max(size.X, size.Z),
	}
end

local function creatureWhere(cx: Cx): Where
	if cx.shape == "golem" or cx.shape == "imp" then
		local w = humanWhere(cx.rig)
		if cx.shape == "golem" then
			for i, s in { -1, 1 } do
				w.front[i] = { host = cx.rig.parts.UpperTorso, cf = C(s * 0.3, 0, -0.66) * rz(-s * 30) }
			end
		end
		w.creature = true
		return w
	end
	local X, Y, Z = cx.size.X, cx.size.Y, cx.size.Z
	local B = cx.B
	local function at(cf: CFrame): Spot
		return { host = cx.lt, cf = CFrame.new(cx.c) * cf, absolute = true }
	end
	return {
		top = at(C(0, 0.5 * Y + 0.15, 0)),
		plates = { at(C(-0.3 * X, 0.38 * Y, 0) * rz(30)), at(C(0.3 * X, 0.38 * Y, 0) * rz(-30)) },
		plateKind = "wedge",
		plateSize = V(0.5, 0.2, 0.6) * B,
		front = { at(C(-0.15 * X, 0, -Z / 2 - 0.03) * rz(30)), at(C(0.15 * X, 0, -Z / 2 - 0.03) * rz(-30)) },
		stripSize = V(0.08, 0.9 * Y, 0.05),
		fuse = nil,
		footprint = cx.footprint,
		creature = true,
		fxHost = cx.lt,
	}
end

local TIER_RANK = { ["0"] = 1, ["1"] = 2, W = 3, R = 4, L = 5, D = 6 }

--- Markers for a role (§4.5) as {code, count, fn(b, rig)} (tier 1, mounted right after FP).
function Creatures.markers(role: string, affix: any?, stitched: boolean?, where: Where, sd: boolean?): { any }
	local list = {}
	if stitched and (role == "normal" or role == "elite") then
		table.insert(list, {
			code = "STRIP",
			count = 3,
			fn = function(b: any, rig: any)
				Kit.stitch(b, rig, affix, where)
			end,
		})
		return list -- the stitched ring replaces SD, as on an elite
	elseif role == "elite" and affix then
		if stitched then
			table.insert(list, {
				code = "STRIP",
				count = 3,
				fn = function(b: any, rig: any)
					Kit.stitch(b, rig, affix, where)
				end,
			})
		else
			table.insert(list, {
				code = "RING",
				count = Creatures.affixParts(affix, where.creature),
				fn = function(b: any, rig: any)
					Kit.affix(b, rig, affix, where)
				end,
			})
		end
		return list -- SD becomes the ring on an elite (§4.2)
	end
	if role == "alpha" then
		table.insert(list, {
			code = "CREST",
			count = 1,
			fn = function(b: any, rig: any)
				Kit.alpha(b, rig, where)
			end,
		})
	end
	if sd then
		table.insert(list, {
			code = "SD",
			count = 1,
			fn = function(b: any, rig: any)
				Kit.PIECES.SD(b, rig, { "SD", footprint = where.footprint }, {})
			end,
		})
	end
	return list
end

local function hideWalker(model: Model)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
end

local function dropFace(model: Model)
	local head = model:FindFirstChild("Head")
	local decal = head and head:FindFirstChild("face")
	if decal then
		decal:Destroy()
	end
end

local function dressCreature(model: Model, opts: any, enemy: any): (number, any)
	local old = model:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end
	local b = Kit.new(model, opts.budget or 14)
	local rig = Kit.rig(model)
	local cx = creatureCx(model, opts, b, rig, enemy)
	dropFace(model)
	if ABSOLUTE_FAMILY[cx.shape] then
		hideWalker(model)
	else
		-- visible walker: golem Slate, imp skin; painted with the role colour
		local map = {}
		local mat = cx.var.material or (if cx.shape == "golem" then "Slate" else "SmoothPlastic")
		for name, p in rig.parts do
			if name ~= "HumanoidRootPart" then
				map[name] = { color = cx.col.body, material = mat }
				local _ = p
			end
		end
		Kit.paintParts(model, map)
		if cx.var.lean then
			local motor = cx.lt:FindFirstChild("Root")
			if motor and motor:IsA("Motor6D") then
				motor.C0 = motor.C0 * rx(-cx.var.lean) -- forward lean
			end
		end
	end
	model:SetAttribute("Footprint", cx.footprint)
	local pieces = Costumes.creaturePieces(opts.enemyId) or {}
	local fam = FAMILY[cx.shape] or {}
	local where = creatureWhere(cx)
	local hasSD = false
	local queue = {}
	for i, p in pieces do
		if p.piece == "SD" then
			hasSD = true
		else
			table.insert(queue, { i = i, p = p })
		end
	end
	if cx.shape == "ufo" then
		hasSD = true
	end
	table.sort(queue, function(a, c)
		local ra, rc = TIER_RANK[a.p.tier] or 4, TIER_RANK[c.p.tier] or 4
		if ra ~= rc then
			return ra < rc
		end
		return a.i < c.i
	end)
	-- tier 0 (imp FP) first, then markers, then W R L D
	local function mountPiece(q: any)
		local fn = fam[q.p.piece]
		b.code = q.p.piece
		if not fn then
			table.insert(
				b.log,
				{ tier = q.p.tier, code = q.p.piece, count = 0, mounted = false, parts = 0, missing = true }
			)
			return
		end
		local before = #b.parts
		local ok = b:entry(q.p.tier, function()
			fn(cx)
		end, q.p.parts)
		if ok and q.p.tier == "W" then
			for k = before + 1, #b.parts do
				local part = b.parts[k]
				part:AddTag("WeakPoint")
				if model:GetAttribute("Volatile") then
					part:SetAttribute("Pulse", 3)
				end
			end
		end
	end
	local rest = {}
	for _, q in queue do
		if q.p.tier == "0" then
			mountPiece(q)
		else
			table.insert(rest, q)
		end
	end
	for _, m in Creatures.markers(cx.role, cx.affix, cx.stitched, where, hasSD) do
		b.code = m.code
		b:entry(1, function()
			m.fn(b, rig)
		end, m.count)
	end
	for _, q in rest do
		mountPiece(q)
	end
	-- emitters: the variant's (or the wraith's wind on its tail tip)
	local fx = cx.var.fx or (if cx.shape == "wraith" then "wind" else nil)
	if fx then
		local host: Instance = cx.lt
		if cx.var.fxAt == "spade" and cx.parts.spade then
			host = cx.parts.spade[1]
		elseif fx == "wind" and cx.parts.tailTip then
			host = cx.parts.tailTip[1]
		end
		Kit.emitter(host, fx)
	end
	if cx.shape == "ufo" then
		local a = Instance.new("Attachment")
		a.Name = "UfoLight"
		a.CFrame = C(0, 1.5 * cx.s, 0)
		a.Parent = rig.parts.HumanoidRootPart
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 16
		light.Brightness = 1
		light.Angle = 60
		light.Color = Color3.fromRGB(191, 232, 255)
		light.Parent = a
	end
	if cx.var.pulse then
		model:SetAttribute("Pulse", true)
	end
	return b.used, b
end

--------------------------------------------------------------------------------
-- Human enemies (§4.4)
--------------------------------------------------------------------------------

-- deterministic variety without Random (works in Lune too)
local function rng(seed: number): () -> number
	local state = (math.floor(seed) * 1103515245 + 12345) % 2147483648
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local HAIR_VARIANTS: { any } = {
	{ "HR·s", n = 1 },
	{ "HR·p", h = 0.6 },
	{ "HR·p", h = 1.1 },
}

local function baseGrade(id: string, opts: any): string
	if opts.grade ~= nil then
		return tostring(opts.grade)
	end
	local base = EnemyData[Costumes.baseId(id)]
	local g = base and base.grade
	if g == nil and opts.t then
		g = opts.t.grade
	end
	return tostring(g or 3)
end

--- The colours a human enemy is built with (also for Looks.description): skin, hair, brow, eye,
--- top, sleeves, bottom, trim, sig, darkened by role (§4.1); skin from the variety pick.
function Creatures.humanColors(id: string, role: string, opts: any?): ({ [string]: number }, { [string]: any })
	local o = opts or {}
	local look = o.look or Costumes.humanLook(id, EnemyLooks)
	local r = rng(o.seed or 0)
	local skinList = Costumes.VARIETY.skin
	local skin = look.skin
	if not (look.bare and Costumes.baseId(id) == "grey") then
		skin = skinList[math.floor(r() * #skinList) + 1]
	end
	local function sh(c: number?, d: number): number
		return Creatures.shade(c or d, role)
	end
	local top = sh(look.top, 0x2a2f45)
	local cols = {
		skin = skin or 0xd8c0b0,
		hair = sh(look.hair, 0x1a1a22),
		brow = look.brow or look.hair or 0x1a1a22,
		eye = Creatures.eyeColor(role, o.affix, o.stitched, look.eye),
		top = top,
		sleeves = sh(look.sleeves or look.top, 0x2a2f45),
		bottom = sh(look.bottom, 0x1a1e2e),
		trim = sh(look.headband or look.collar or look.trim or look.bottom, 0x3a3a46),
		sig = (o.pal and o.pal.nature) or 0xb06cff,
	}
	return cols, look
end

local function humanKit(id: string, opts: any): ({ any }, { [string]: number }, { [string]: any }, { any })
	local role: string = opts.role
	local base = Costumes.baseId(id)
	local enemy = Costumes.ENEMY[base] or { variant = {} }
	local var = enemy.variant or {}
	local factionId: string = enemy.faction or "ninja"
	local fac = Costumes.FACTION[factionId] or Costumes.FACTION.ninja
	local cols, look = Creatures.humanColors(id, role, opts)
	local function sh(c: number?, d: number): number
		return Creatures.shade(c or d, role)
	end
	local r = rng((opts.seed or 0) + 7)
	local grade = baseGrade(id, opts)
	local ladder = Costumes.ladderFor(grade)
	local has: { [string]: any } = {}
	for _, e in ladder do
		has[e.slot] = e
	end
	local street = opts.mapId ~= nil and Costumes.FACTION.street.maps[opts.mapId] == true
	local ninja = factionId == "ninja"
	local kit: { any } = { { "FP" } }
	local hairless = var.hairless or look.hairStyle == "none"
	local streetHat = if street and ninja and has.faction then (if r() < 0.5 then "beanie" else "bandana") else nil
	if has.hair and not hairless then
		local tint = if streetHat == "beanie" then cols.trim else cols.hair
		table.insert(kit, { "HR", tint = tint, tier = "R" })
	end
	if has.hairExtra and not hairless then
		local hs = look.hairStyle
		local pick = if hs == "spiky"
			then HAIR_VARIANTS[1]
			elseif hs == "long" or hs == "ponytail" or hs == "bun" then HAIR_VARIANTS[3]
			else HAIR_VARIANTS[math.floor(r() * 3) + 1]
		local e = table.clone(pick)
		e.tint = cols.hair
		e.tier = "R"
		table.insert(kit, e)
	end
	if has.faction then
		if streetHat == "beanie" then
			table.insert(kit, { "CUFF", tint = lerp(cols.trim, 0xe8e0d0, 0.3), tier = "R" })
		elseif streetHat == "bandana" then
			table.insert(kit, { "LM", variant = "bandana", tint = sh(look.headband, 0x6a3a2a), tier = "R" })
		elseif ninja then
			table.insert(kit, { "HB", variant = "cloth", tint = sh(look.headband, 0x3a3a46), tier = "R" })
		elseif look.bare or var.bare then
			table.insert(kit, { "SB", tint = sh(look.sash, 0x6a2a1a), tier = "R" })
		else
			table.insert(kit, {
				"HC",
				tint = sh(look.uniform or look.collar or look.top, 0x1e2430),
				gui = { kind = "buttons", color = look.buckle or 0xc8a44a },
				tier = "R",
			})
		end
	end
	if has.shoulder then
		table.insert(kit, { "SG", n = 1, side = "L", tint = sh(look.top, 0x2a2f45), tier = "R" })
	end
	if has.lower then
		if ninja then
			if streetHat ~= "bandana" then
				table.insert(kit, { "LM", tint = sh(look.maskLower or look.top, 0x1e2430), tier = "R" })
			end
		else
			table.insert(kit, { "TAL", tint = fac.talismans and fac.talismans.tint or 0xe8e0c8, tier = "R" })
		end
	end
	if has.tails then
		if ninja then
			table.insert(kit, { "VS", variant = "flak", tint = sh(look.top, 0x2a2f45), tier = "D" })
		else
			table.insert(kit, { "CT", tint = sh(look.top, 0x1e2430), tier = "D" })
		end
	end
	if has.gloves then
		table.insert(
			kit,
			{ "GL", n = 2, variant = "wraps", tint = sh(if ninja then 0xe8e0d0 else look.bottom, 0x2a2a30), tier = "D" }
		)
	end
	if has.weapon then
		if street then
			table.insert(kit, { "PIPE", tier = "R" })
		else
			table.insert(kit, { "BW", variant = "short", tier = "R" })
		end
	end
	if has.trim then
		table.insert(kit, { "TRIM", tint = cols.sig, tier = "R" })
	end
	if has.crest then
		table.insert(kit, { "CR·1", tint = sh(look.hair, 0x2a2a30), tier = "R" })
	end
	-- the ENEMY variant's own pieces replace the same code, else add as identity (R)
	for _, p in (var.pieces or {}) :: { any } do
		local e = table.clone(p)
		if e.tint then
			e.tint = sh(e.tint, e.tint :: number)
		end
		local replaced = false
		for i, k in kit do
			if k[1] == e[1] then
				e.tier = k.tier
				kit[i] = e
				replaced = true
				break
			end
		end
		if not replaced then
			e.tier = "R"
			table.insert(kit, e)
		end
	end
	-- a hood replaces the cloth headband
	local hooded = false
	for _, k in kit do
		hooded = hooded or k[1] == "HD"
	end
	if hooded then
		for i = #kit, 1, -1 do
			if kit[i][1] == "HB" then
				table.remove(kit, i)
			end
		end
	end
	-- kept data flags (§2.7) that the ladder did not already place: tier D extras
	local have: { [string]: boolean } = {}
	for _, k in kit do
		have[k[1]] = true
	end
	local FLAG: { [string]: string } =
		{ collar = "HC", sash = "SB", maskLower = "LM", vest = "VS", cape = "CP", belt = "SB" }
	local flagNames = {}
	for f in FLAG do
		table.insert(flagNames, f)
	end
	table.sort(flagNames)
	for _, f in flagNames do
		local code = FLAG[f]
		local v = look[f]
		if v and v ~= false and not have[code] then
			have[code] = true
			table.insert(kit, { code, tint = sh(if type(v) == "number" then v else look.top, 0x2a2a30), tier = "D" })
		end
	end
	-- street: VS becomes VS + LP (open jacket)
	if street and have.VS and not have.LP then
		table.insert(kit, { "LP", tint = sh(look.top, 0x2a2f45), tier = "D" })
	end
	-- variety: whether the last tier-D piece is worn
	if r() < 0.3 then
		for i = #kit, 1, -1 do
			if kit[i].tier == "D" then
				table.remove(kit, i)
				break
			end
		end
	end
	-- face marks (one mark per cheek at most; never parallel lines, never under the nose)
	local marks: { any } = {}
	if look.markStripe then
		table.insert(marks, { x = 21, y = 36, w = 3, h = 14, color = look.brow or look.hair or 0x9b1a2a })
	end
	if look.markings then
		local mc = look.sash or look.hair or 0x9b1a2a
		table.insert(marks, { x = 21, y = 34, w = 3, h = 10, rot = 30, color = mc })
		table.insert(marks, { x = 69, y = 34, w = 3, h = 10, rot = -30, color = mc })
	end
	local extras = { marks = marks, look = look, var = var }
	return kit, cols, extras, ladder
end

local function bodyPaint(cols: { [string]: number }, bare: boolean): { [string]: any }
	local map: { [string]: any } = { Head = { color = cols.skin } }
	for _, n in { "UpperTorso", "LowerTorso" } do
		map[n] = { color = if bare and n == "UpperTorso" then cols.skin else cols.top }
	end
	for _, s in { "Left", "Right" } do
		map[s .. "UpperArm"] = { color = if bare then cols.skin else cols.sleeves }
		map[s .. "LowerArm"] = { color = if bare then cols.skin else cols.sleeves }
		map[s .. "Hand"] = { color = cols.skin }
		map[s .. "UpperLeg"] = { color = cols.bottom }
		map[s .. "LowerLeg"] = { color = cols.bottom }
		map[s .. "Foot"] = { color = lerp(cols.bottom, BLACK, 0.4) }
	end
	return map
end

local function dressGrey(model: Model, opts: any): (number, any)
	local old = model:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end
	local b = Kit.new(model, opts.budget or 5)
	local rig = Kit.rig(model)
	dropFace(model)
	local cols, look = Creatures.humanColors(opts.enemyId, opts.role, opts)
	cols.skin = look.skin or 0xb9c7c2
	Kit.paintParts(model, bodyPaint(cols, true))
	for _, m in Creatures.markers(opts.role, opts.affix, opts.stitched, humanWhere(rig), false) do
		b.code = m.code
		b:entry(1, function()
			m.fn(b, rig)
		end, m.count)
	end
	b.code = "GR·e"
	b:entry("R", function()
		for _, s in { -1, 1 } do
			b:mount(
				rig.parts.Head,
				nil,
				"ell",
				V(0.36, 0.2, 0.1),
				C(s * 0.22, 0.08, -0.58) * rz(s * 18),
				{ color = BLACK, material = "Glass", reflectance = 0.3, name = "GR·e" },
				{ keep = true }
			)
		end
	end, 2)
	return b.used, b
end

local function dressHuman(model: Model, opts: any): (number, any)
	local id: string = opts.enemyId
	local role: string = opts.role
	local kit, cols, extras = humanKit(id, opts)
	local look, var = extras.look, extras.var
	local rig0 = Kit.rig(model)
	local where = humanWhere(rig0)
	local style: { [string]: any } = {
		kit = kit,
		face = { marks = extras.marks },
		paint = bodyPaint(cols, look.bare == true or var.bare == true),
		emitters = {},
		guis = {},
	}
	if var.fx then
		table.insert(style.emitters, { key = var.fx, at = var.fxAt })
	end
	if var.gui then
		table.insert(style.guis, { kind = var.gui.kind, color = var.gui.color, host = "UpperTorso" })
	end
	local markers = Creatures.markers(role, opts.affix, opts.stitched, where, false)
	local used, b = Kit.build(model, { colors = cols, kit = kit, faceGlow = cols.eye }, {
		role = role,
		style = style,
		budget = opts.budget or 14,
		reserve = 0,
		markers = markers,
		face = if role == "alpha" then { irisScale = 1.3 } else nil,
	})
	for _, k in kit do
		if k[1] == "CR·1" then
			for _, e in Kit.fx(Kit.rig(model), "aura", "feet") do
				e.Rate = 6
			end
		end
	end
	if var.transparency then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Name ~= "FP" and p.Transparency < 1 then
				p.Transparency = math.max(p.Transparency, var.transparency)
			end
		end
	end
	return used, b
end

--------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------

--- Dresses an enemy walker by role (§6.2 Enemies.spawn steps 3–4). Returns parts used and the
--- builder (its `log` records every entry's tier and whether it mounted).
function Creatures.dress(model: Model, opts: any): (number, any)
	local id: string = opts.enemyId
	local t = opts.t or {}
	local role: string = opts.role or Costumes.role(id, t, opts.affix, false)
	local o = table.clone(opts)
	o.role = role
	-- an elite on a stitched map, or a normal foe summoned by a stitched parent (§4.5)
	o.stitched = opts.stitched == true and (role == "elite" or role == "normal")
	if role == "finale" then
		error("Creatures.dress: finale ids are built by Finale.luau BUILDERS", 0)
	end
	if role == "charBoss" then
		local styleId = Costumes.styleFromEnemyId(id)
		local look = Costumes.effectiveLook(styleId, "charBoss")
		local used, b =
			Kit.build(model, look, { role = "charBoss", style = Costumes.STYLE[styleId], budget = o.budget })
		Kit.riftBoss(model)
		return used, b
	end
	local base = Costumes.baseId(id)
	local enemy = Costumes.ENEMY[base]
	local shape = (enemy and enemy.shape) or t.shape or "human"
	if shape ~= "human" then
		return dressCreature(model, o, { shape = shape, var = enemy and enemy.variant or {} })
	end
	if base == "grey" then
		return dressGrey(model, o)
	end
	return dressHuman(model, o)
end

--------------------------------------------------------------------------------
-- §4.6 the ward: the Unbidden (§5.3) as an ally, 1.3 size, 30 parts
--------------------------------------------------------------------------------

local BONE = 0xd9d4cc

--- Dresses a built R15 model as the ward: FP with the friend face (a cyan slit on FaceBase),
--- UB·p, UB·d, 8 UB·t lit cyan, a cyan ally ring. 14 parts. CanQuery off on every part.
function Creatures.dressWard(model: Model): (number, any)
	local old = model:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end
	local b = Kit.new(model, 14)
	local rig = Kit.rig(model)
	local p = rig.parts
	local map: { [string]: any } = {}
	for name in p do
		if name ~= "HumanoidRootPart" then
			map[name] = { color = BONE, material = "SmoothPlastic" }
		end
	end
	for _, s in { "Left", "Right" } do
		map[s .. "Hand"] = { color = 0xa8a39a, material = "Slate" }
		map[s .. "LowerArm"] = { color = 0xa8a39a, material = "Slate" }
	end
	Kit.paintParts(model, map)
	b.code = "FP"
	b:entry(0, function()
		local fp = Kit.PIECES.FP(b, rig, { "FP" }, {})[1]
		Kit.face(model, fp, {
			friend = true,
			hideEyes = true,
			mouth = false,
			marks = { { x = 45, y = 22, w = 4, h = 20, color = CYAN } },
		})
	end, 1)
	b.code = "RING"
	b:entry(1, function()
		Kit.ring(b, rig, CYAN)
	end, 1)
	b.code = "UB·p"
	b:entry("R", function()
		for _, s in { -1, 1 } do
			local plate = b:mount(p.UpperTorso, nil, "block", V(0.9, 0.8, 0.1), C(s * 0.5, 0.2, -0.55), {
				color = 0xc8c2b8,
				name = "UB·p",
			})
			if plate then
				Kit.gui({ plate }, { kind = "trim", color = CYAN, glow = true, face = "Front" }, nil, nil)
			end
		end
	end, 2)
	b.code = "UB·d"
	b:entry("R", function()
		for _, s in { -1, 1 } do
			b:mount(
				p[LR(s) .. "UpperArm"],
				LR(s) .. "ShoulderAttachment",
				"ell",
				V(1.2, 0.7, 1.2),
				C(s * 0.15, 0.1, 0),
				{ color = BONE, name = "UB·d" }
			)
		end
	end, 2)
	b.code = "UB·t"
	b:entry("R", function()
		for i, nature in Costumes.ADAPT_ORDER do
			local tile = b:mount(
				p.UpperTorso,
				"NeckAttachment",
				"block",
				V(0.42, 0.3, 0.14),
				ry(45 * (i - 1)) * C(0, 0.12, -0.62) * rx(-20),
				{ color = CYAN, material = "Neon", name = "UB·t" },
				{ keep = true }
			)
			if tile then
				tile:SetAttribute("Nature", nature)
			end
		end
	end, 8)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	return b.used, b
end

--- Builds Kage Inukai's ward for `owner` (a Player or a character Model): the Unbidden at size
--- 1.3 as an ally, 4 studs behind the caster, server-owned. `model` may be passed in (tests);
--- otherwise it is built from a HumanoidDescription. Tagged "Ward"; the caller stores it as
--- minion.model and destroys it (§4.6 cleanup).
function Creatures.buildWard(owner: any, model: Model?): Model
	local m = model
	if not m then
		local Players = game:GetService("Players")
		local d = Instance.new("HumanoidDescription")
		local bone = Color3.fromRGB(217, 212, 204)
		d.HeadColor = bone
		d.TorsoColor = bone
		d.LeftArmColor = bone
		d.RightArmColor = bone
		d.LeftLegColor = bone
		d.RightLegColor = bone
		local size = 1.3
		d.HeightScale = 1.0 * size
		d.WidthScale = 1.1 * 1.2 * size
		d.DepthScale = 0.9 * size
		d.HeadScale = 0.8 * size
		d.BodyTypeScale = 0.5
		d.ProportionScale = 1.0
		m = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end
	local ward = m :: Model
	ward.Name = "Ward"
	Creatures.dressWard(ward)
	ward:AddTag("Ward")
	local hum = ward:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local character = if typeof(owner) == "Instance" and owner:IsA("Player") then owner.Character else owner
	local root = if typeof(character) == "Instance" then character:FindFirstChild("HumanoidRootPart") else nil
	if typeof(owner) == "Instance" and owner:IsA("Player") then
		ward:SetAttribute("Owner", owner.UserId)
	end
	if root and root:IsA("BasePart") then
		ward:PivotTo(root.CFrame * CFrame.new(0, 0, 4))
		ward.Parent = workspace
		local hrp = ward:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			pcall(function()
				hrp:SetNetworkOwner(nil)
			end)
		end
	end
	return ward
end

Creatures.FAMILY = FAMILY
return Creatures
