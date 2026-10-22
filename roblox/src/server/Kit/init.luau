--!strict
-- Kit: the costume builder (docs/design/characters.md §2, §6.1, §6.5).
--
-- Every costume piece is a Part, WedgePart, CornerWedgePart or a Block with a Sphere
-- SpecialMesh (an ellipsoid), held by a Weld whose C0 is written once from the rest pose:
--   C0 = attachment.CFrame * CFrame.new(offset * k) * rotation         (§2.1 Weld rules)
-- where k is the host's size over its NOMINAL size (§2.1 Scaling), unless the piece is
-- mounted `absolute`. Pieces never collide, query or touch, are massless, and live in the
-- character's Folder "Costume" (sub-folders "SuitTN" and "Prop").
--
-- Builders:  Kit.PIECES[code] = function(b, rig, entry, look): { BasePart }
--   b      a builder from Kit.new (counts parts, enforces the budget)
--   rig    Kit.rig(model): { model, parts = {[R15 name] = BasePart}, worn = {[code] = true}, ground, footprint }
--   entry  a STYLE kit entry: { code, n?, tint?, tints?, accent?, material?, reflectance?, side?, h?, x?, w?,
--          variant?, tail?, pouch?/pouches?, segs?, max?, mount?/pos?, scale?, emblem?/at?/emblemColor?,
--          gui?, flash?, fx?/fxAt?/fxColor?, tier?, folder? }  (schema in src/shared/Costumes/Styles/academy.luau)
--   look   the effectiveLook result: colours are read from look.colors (or look itself)
-- Kit.COUNT[code](entry) gives the parts an entry adds. Bespoke.luau, Creatures.luau and
-- Finale.luau add their own codes to Kit.PIECES and Kit.COUNT.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Palette)

-- Costumes is optional here so the builder never blocks on it; every constant has a local fallback.
local Costumes: { [string]: any } = {}
do
	local mod = Shared:FindFirstChild("Costumes")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, mod)
		if ok and type(result) == "table" then
			Costumes = result
		end
	end
end

local Kit = {}

export type Entry = { [any]: any }
export type Look = { [string]: any }
export type Props = {
	color: number?,
	material: string?,
	transparency: number?,
	reflectance: number?,
	name: string?,
}
export type MountOpts = {
	absolute: boolean?, -- §2.1: size and offset are studs, not nominal
	keep: boolean?, -- eyes, weak points and markers: never tagged CostumeDetail
	folder: string?, -- sub-folder of Costume ("SuitTN", "Prop")
	hinge: Vector3?, -- set by Builder.hinge
}
export type Rig = {
	model: Model,
	parts: { [string]: BasePart },
	worn: { [string]: boolean },
	ground: number, -- y_g in HumanoidRootPart space (§2.1)
	footprint: number, -- §2.1 footprint for humans
	look: Look?,
	role: string?,
}
export type LogEntry = {
	tier: string,
	code: string,
	count: number,
	mounted: boolean,
	parts: number,
	missing: boolean?,
}
type Mounted = { part: BasePart, weld: Weld, k: Vector3, attach: CFrame }

--------------------------------------------------------------------------------
-- Maths and constants
--------------------------------------------------------------------------------

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

local CYL_UP = CFrame.Angles(0, 0, math.pi / 2) -- local X -> +Y
local CYL_FWD = CFrame.Angles(0, math.pi / 2, 0) -- local X -> -Z
Kit.CYL_UP = CYL_UP
Kit.CYL_FWD = CYL_FWD
Kit.rx, Kit.ry, Kit.rz = rx, ry, rz

--- Reads a Vector3 from a Vector3, {x, y, z} or {x = , y = , z = } (Costumes is pure data).
local function toV3(v: any): Vector3?
	if typeof(v) == "Vector3" then
		return v
	end
	if type(v) == "table" then
		local x = v.x or v.X or v[1]
		local y = v.y or v.Y or v[2]
		local z = v.z or v.Z or v[3]
		if type(x) == "number" and type(y) == "number" and type(z) == "number" then
			return Vector3.new(x, y, z)
		end
	end
	return nil
end
Kit.toV3 = toV3

local function const(name: string, fallback: any): any
	local v = Costumes[name]
	if v == nil then
		return fallback
	end
	return v
end

local STEEL: number = const("STEEL", 0x9aa4b0)
local GRIP: number = const("GRIP", 0x2a2a30)
local DETAIL = 0.6 -- CastShadow off and CostumeDetail below this largest side (§2.1, §6.1)

local NOMINAL_DEFAULT: { [string]: Vector3 } = {
	Head = V(1.2, 1.2, 1.2),
	UpperTorso = V(2, 1.6, 1),
	LowerTorso = V(2, 0.4, 1),
	UpperArm = V(1, 1.17, 1),
	LowerArm = V(1, 1.05, 1),
	Hand = V(1, 0.3, 1),
	UpperLeg = V(1, 1.22, 1),
	LowerLeg = V(1, 1.19, 1),
	Foot = V(1, 0.3, 1),
	HumanoidRootPart = V(2, 2, 1),
}

--- NOMINAL size for an R15 part name (§2.1). Left/Right prefixes resolve to the generic entry.
function Kit.nominal(name: string): Vector3?
	local src = Costumes.NOMINAL
	local generic = string.gsub(string.gsub(name, "^Left", ""), "^Right", "")
	for _, key in { name, generic } do
		local v = if type(src) == "table" then toV3(src[key]) else nil
		if v then
			return v
		end
		local d = NOMINAL_DEFAULT[key]
		if d then
			return d
		end
	end
	return nil
end

--- Standard R15 accessory attachments: which part carries each, and its nominal position
--- (used only when a rig lacks the attachment).
local ATTACH: { [string]: { host: string, pos: Vector3 } } = {
	FaceFrontAttachment = { host = "Head", pos = V(0, 0, -0.6) },
	FaceCenterAttachment = { host = "Head", pos = V(0, 0, 0) },
	HairAttachment = { host = "Head", pos = V(0, 0.6, 0) },
	HatAttachment = { host = "Head", pos = V(0, 0.6, 0) },
	NeckAttachment = { host = "UpperTorso", pos = V(0, 0.8, 0) },
	BodyFrontAttachment = { host = "UpperTorso", pos = V(0, -0.2, -0.5) },
	BodyBackAttachment = { host = "UpperTorso", pos = V(0, -0.2, 0.5) },
	LeftCollarAttachment = { host = "UpperTorso", pos = V(-1, 0.8, 0) },
	RightCollarAttachment = { host = "UpperTorso", pos = V(1, 0.8, 0) },
	WaistFrontAttachment = { host = "LowerTorso", pos = V(0, 0, -0.5) },
	WaistBackAttachment = { host = "LowerTorso", pos = V(0, 0, 0.5) },
	WaistCenterAttachment = { host = "LowerTorso", pos = V(0, 0, 0) },
	LeftShoulderAttachment = { host = "LeftUpperArm", pos = V(0, 0.585, 0) },
	RightShoulderAttachment = { host = "RightUpperArm", pos = V(0, 0.585, 0) },
	LeftGripAttachment = { host = "LeftHand", pos = V(0, -0.15, 0) },
	RightGripAttachment = { host = "RightHand", pos = V(0, -0.15, 0) },
	LeftFootAttachment = { host = "LeftFoot", pos = V(0, -0.15, 0) },
	RightFootAttachment = { host = "RightFoot", pos = V(0, -0.15, 0) },
}
Kit.ATTACH = ATTACH

local function material(m: any): Enum.Material
	if typeof(m) == "EnumItem" then
		return m :: any
	end
	if type(m) == "string" then
		local ok, v = pcall(function()
			return (Enum.Material :: any)[m]
		end)
		if ok and v then
			return v
		end
	end
	return Enum.Material.SmoothPlastic
end

local function normal(face: string): Enum.NormalId
	local ok, v = pcall(function()
		return (Enum.NormalId :: any)[face]
	end)
	return if ok and v then v else Enum.NormalId.Front
end

--------------------------------------------------------------------------------
-- Rig
--------------------------------------------------------------------------------

--- The R15 parts of a character or NPC, plus ground and footprint (§2.1).
--- Read after the model is built and before it is parented.
function Kit.rig(model: Model): Rig
	local parts: { [string]: BasePart } = {}
	for _, c in model:GetChildren() do
		if c:IsA("BasePart") then
			parts[c.Name] = c
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = parts.HumanoidRootPart
	local hip = if hum then hum.HipHeight else 2
	local ut = parts.UpperTorso
	return {
		model = model,
		parts = parts,
		worn = {},
		ground = -(hip + (if hrp then hrp.Size.Y / 2 else 1)),
		footprint = 2.2 * (if ut then ut.Size.X / 2 else 1), -- 2.2 · WidthScale · size
	}
end

local function part(rig: Rig, name: string): BasePart
	local p = rig.parts[name]
	if not p then
		error("Kit: the rig has no " .. name, 0)
	end
	return p
end

--------------------------------------------------------------------------------
-- Builder
--------------------------------------------------------------------------------

local REFUSED = { "Kit: budget spent" } -- raised inside an entry so the whole entry rolls back

local Builder = {}
Builder.__index = Builder

type BuilderData = {
	model: Model,
	folder: Folder,
	budget: number,
	used: number,
	parts: { BasePart },
	mounts: { [BasePart]: Mounted },
	last: Mounted?,
	log: { LogEntry },
	code: string?,
	_stack: { { Instance } },
	_sway: number,
	_orbit: number,
}
export type Builder = typeof(setmetatable({} :: BuilderData, Builder))

--- A builder that counts parts against `budget` (default 14, §6.3). Reuses the model's
--- Costume folder when there is one (Kit.suitTN, Kit.prop mount into it later).
function Kit.new(model: Model, budget: number?): Builder
	local existing = model:FindFirstChild("Costume")
	local folder: Folder
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "Costume"
		folder.Parent = model
	end
	local data: BuilderData = {
		model = model,
		folder = folder,
		budget = budget or 14,
		used = 0,
		parts = {},
		mounts = {},
		last = nil,
		log = {},
		code = nil,
		_stack = {},
		_sway = 0,
		_orbit = 0,
	}
	return setmetatable(data, Builder)
end

function Builder.sub(self: Builder, name: string?): Instance
	if not name then
		return self.folder
	end
	local f = self.folder:FindFirstChild(name)
	if not f then
		local n = Instance.new("Folder")
		n.Name = name
		n.Parent = self.folder
		f = n
	end
	return f :: Instance
end

--- Records an extra instance (Attachment, Beam) so a rolled-back entry removes it too.
function Builder.track(self: Builder, inst: Instance)
	local top = self._stack[#self._stack]
	if top then
		table.insert(top, inst)
	end
end

--- k = host.Size / NOMINAL[host.Name], or (1,1,1) when absolute (§2.1 Scaling).
function Kit.scaleOf(host: BasePart, absolute: boolean?): Vector3
	if absolute then
		return Vector3.one
	end
	local n = Kit.nominal(host.Name)
	if not n then
		error(`Kit: no NOMINAL size for {host.Name}; mount it with absolute = true`, 0)
	end
	return host.Size / n
end

local function attachFrame(host: BasePart, attach: (Attachment | string)?, k: Vector3): CFrame
	if attach == nil then
		return CFrame.identity
	end
	if type(attach) == "string" then
		local a = host:FindFirstChild(attach)
		if a and a:IsA("Attachment") then
			return a.CFrame
		end
		local d = ATTACH[attach]
		if d then
			return CFrame.new(d.pos * k)
		end
		error(`Kit: {host.Name} has no {attach}`, 0)
	end
	return (attach :: Attachment).CFrame
end

local function project(axis: Vector3, k: Vector3): number
	return math.abs(axis.X) * k.X + math.abs(axis.Y) * k.Y + math.abs(axis.Z) * k.Z
end

--- An ellipsoid: a Block Part with a Sphere SpecialMesh at Scale 1 (§2.1). 0 extra parts.
function Kit.ellipsoid(size: Vector3): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Block
	p.Size = size
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = Vector3.one
	m.Parent = p
	return p
end

--- Mounts one piece (§6.1). kind: block | wedge | corner | cyl | ball | ell.
--- `size` and `cf` are nominal studs at scale 1 relative to `attach` (an Attachment, its name,
--- or nil for the part centre). Returns nil once the budget is spent (inside b:entry the
--- whole entry is rolled back instead).
function Builder.mount(
	self: Builder,
	host: BasePart,
	attach: (Attachment | string)?,
	kind: string,
	size: Vector3,
	cf: CFrame?,
	props: Props?,
	opts: MountOpts?
): BasePart?
	local o: MountOpts = opts or {}
	local pr: Props = props or {}
	local c = cf or CFrame.identity
	if self.used >= self.budget then
		if #self._stack > 0 then
			error(REFUSED, 0)
		end
		return nil
	end
	local k = Kit.scaleOf(host, o.absolute)
	local frame = attachFrame(host, attach, k)
	local R = c.Rotation
	local kl = V(project(R.XVector, k), project(R.YVector, k), project(R.ZVector, k))
	local s = size * kl
	local piece: BasePart
	if kind == "block" then
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Block
		p.Size = s
		piece = p
	elseif kind == "wedge" then
		local p = Instance.new("WedgePart")
		p.Size = s
		piece = p
	elseif kind == "corner" then
		local p = Instance.new("CornerWedgePart")
		p.Size = s
		piece = p
	elseif kind == "cyl" then
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = s
		piece = p
	elseif kind == "ball" then
		if math.abs(size.X - size.Y) > 1e-6 or math.abs(size.X - size.Z) > 1e-6 then
			error("Kit: a ball needs three equal axes; use ell", 0)
		end
		local d = size.X * (kl.X + kl.Y + kl.Z) / 3
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = V(d, d, d)
		piece = p
	elseif kind == "ell" then
		piece = Kit.ellipsoid(s)
	else
		error("Kit: unknown piece kind " .. kind, 0)
	end
	piece.Name = pr.name or self.code or kind
	piece.Color = Palette.color(pr.color or 0x808080)
	piece.Material = material(pr.material or "SmoothPlastic")
	piece.Transparency = pr.transparency or 0
	piece.Reflectance = pr.reflectance or 0
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	if math.max(piece.Size.X, piece.Size.Y, piece.Size.Z) < DETAIL then
		piece.CastShadow = false
		if not o.keep then
			piece:AddTag("CostumeDetail")
		end
	end
	local weld = Instance.new("Weld")
	weld.Part0 = host
	weld.Part1 = piece
	if o.hinge then
		-- §2.1 hinged: C0 = attach * CFrame.new(hinge) * rot * CFrame.new(0, -L/2, 0)
		weld.C0 = frame * CFrame.new(o.hinge * k) * R * CFrame.new(0, -piece.Size.Y / 2, 0)
	else
		weld.C0 = frame * CFrame.new(c.Position * k) * R
	end
	weld.C1 = CFrame.identity
	weld.Parent = piece
	piece.Parent = self:sub(o.folder)
	self.used += 1
	table.insert(self.parts, piece)
	local m: Mounted = { part = piece, weld = weld, k = k, attach = frame }
	self.mounts[piece] = m
	self.last = m
	self:track(piece)
	return piece
end

--- A hinged piece (capes, tails, lapels): rotates `rot` about `hinge` and hangs L/2 below it.
function Builder.hinge(
	self: Builder,
	host: BasePart,
	attach: (Attachment | string)?,
	kind: string,
	size: Vector3,
	hinge: Vector3,
	rot: CFrame,
	props: Props?,
	opts: MountOpts?
): BasePart?
	local o: MountOpts = table.clone(opts or {})
	o.hinge = hinge
	return self:mount(host, attach, kind, size, rot, props, o)
end

--- Mounts a whole entry or none of it (§2.1). `fn` mounts the pieces; `count` is the parts it
--- adds. The entry is skipped when it does not fit; a mount refused part-way rolls back.
function Builder.entry(self: Builder, tier: any, fn: () -> (), count: number?): boolean
	local rec: LogEntry = {
		tier = tostring(tier),
		code = self.code or "?",
		count = count or 0,
		mounted = false,
		parts = 0,
	}
	table.insert(self.log, rec)
	if self.used + (count or 0) > self.budget then
		return false
	end
	local before = self.used
	local list: { Instance } = {}
	table.insert(self._stack, list)
	local ok, err = pcall(fn :: any)
	table.remove(self._stack)
	if not ok then
		for _, inst in list do
			if inst:IsA("BasePart") then
				self.mounts[inst] = nil
				local i = table.find(self.parts, inst)
				if i then
					table.remove(self.parts, i)
				end
			end
			inst:Destroy()
		end
		self.used = before
		if err ~= REFUSED then
			error(err, 0)
		end
		return false
	end
	local outer = self._stack[#self._stack]
	if outer then
		for _, inst in list do
			table.insert(outer, inst)
		end
	end
	rec.mounted = true
	rec.parts = self.used - before
	return true
end

local function target(self: Builder, p: BasePart?): Mounted
	local m = if p then self.mounts[p] else self.last
	if not m then
		error("Kit: no mounted piece to drive", 0)
	end
	return m
end

--- A nominal point relative to the piece's attachment, in Part0 (host) space.
local function toHost(m: Mounted, v: Vector3): Vector3
	return (m.attach * CFrame.new(v * m.k)).Position
end

function Builder.weldOf(self: Builder, p: BasePart?): Weld
	return target(self, p).weld
end

--- Gait_<name> (§2.1): the client swings the weld about `pivot` (nominal, attachment-relative).
function Builder.gait(self: Builder, name: string, pivot: Vector3, phase: number?, amp: number?, p: BasePart?): Weld
	local m = target(self, p)
	m.weld.Name = "Gait_" .. name
	m.weld:SetAttribute("GaitPivot", toHost(m, pivot))
	m.weld:SetAttribute("GaitPhase", phase or 0)
	m.weld:SetAttribute("GaitAmp", amp or 22)
	self.model:AddTag("Gait")
	return m.weld
end

--- Orbit_<name> (§2.1): the client turns the weld about `axis` through `center` (nominal,
--- attachment-relative, default the host centre) at `rate` rev/s.
function Builder.orbit(
	self: Builder,
	axis: Vector3,
	rate: number,
	phase: number?,
	center: Vector3?,
	name: string?,
	p: BasePart?
): Weld
	local m = target(self, p)
	self._orbit += 1
	m.weld.Name = "Orbit_" .. (name or tostring(self._orbit))
	local a = m.attach.Rotation * CFrame.new(axis)
	m.weld:SetAttribute("OrbitAxis", a.Position.Unit)
	m.weld:SetAttribute("OrbitRate", rate)
	m.weld:SetAttribute("OrbitPhase", phase or 0)
	m.weld:SetAttribute("OrbitCenter", if center then toHost(m, center) else Vector3.zero)
	self.model:AddTag("Orbit")
	return m.weld
end

--- Sway_<n> (§2.1): the client lifts the piece about its hinge `pivot` with speed.
function Builder.sway(self: Builder, pivot: Vector3, amp: number?, p: BasePart?): Weld
	local m = target(self, p)
	self._sway += 1
	m.weld.Name = "Sway_" .. tostring(self._sway)
	m.weld:SetAttribute("SwayPivot", toHost(m, pivot))
	m.weld:SetAttribute("SwayAmp", amp or 18)
	self.model:AddTag("Sway")
	return m.weld
end

--------------------------------------------------------------------------------
-- Tints (§2.9)
--------------------------------------------------------------------------------

-- code (or code·sub) -> { colour slot or 0xRRGGBB or "STEEL"/"GRIP", material, transparency? }
local TINT: { [string]: { any } } = {
	HR = { "hair", "SmoothPlastic" },
	["HR·s"] = { "hair", "SmoothPlastic" },
	["HR·w"] = { "hair", "SmoothPlastic" },
	["HR·p"] = { "hair", "SmoothPlastic" },
	["HR·f"] = { "hair", "SmoothPlastic" },
	["HR·k"] = { "hair", "SmoothPlastic" },
	["HR·t"] = { "hair", "SmoothPlastic" },
	FLT = { "hair", "SmoothPlastic" },
	FM = { "top", "SmoothPlastic" },
	LM = { "top", "Fabric" },
	HD = { "top", "Fabric" },
	["HD·d"] = { "top", "Fabric" },
	CK = { "top", "Fabric" },
	VS = { "top", "Fabric" },
	HC = { "top", "Fabric" },
	LP = { "top", "Fabric" },
	CT = { "top", "Fabric" },
	CP = { "top", "Fabric" },
	MT = { "top", "Fabric" },
	SG = { "top", "SmoothPlastic" },
	TN = { "top", "SmoothPlastic" },
	HB = { "trim", "Fabric" },
	["HB·t"] = { "trim", "Fabric" },
	SC = { "trim", "Fabric" },
	SB = { "trim", "Fabric" },
	GL = { "trim", "Fabric" },
	WR = { "trim", "Fabric" },
	EM = { "trim", "Fabric" },
	EC = { "trim", "Metal" },
	BA = { "trim", "Metal" },
	HP = { "trim", "Fabric" },
	SPL = { "trim", "Fabric" },
	CR = { "trim", "SmoothPlastic" },
	XA = { "sleeves", "SmoothPlastic" },
	FS = { "sleeves", "SmoothPlastic" },
	OR = { "sig", "Neon" },
	CO = { "sig", "Neon" },
	seam = { "sig", "Neon" },
	["MA·seam"] = { "sig", "Neon" },
	["BA·claw"] = { "sig", "Neon" },
	GG = { "sig", "Glass", 0.2 },
	["GG·lens"] = { "sig", "Glass", 0.2 },
	["FM·lens"] = { "sig", "Glass", 0.2 },
	["FM·slit"] = { "sig", "Neon" },
	BW = { "STEEL", "Metal" },
	["BW·hilt"] = { "GRIP", "SmoothPlastic" },
	FB = { "STEEL", "Metal" },
	MA = { "STEEL", "Metal" },
	VB = { "sig", "Glass", 0.35 },
	["VB·m"] = { "sig", "Glass", 0.35 },
	EP = { "skin", "SmoothPlastic" },
	HN = { "skin", "SmoothPlastic" },
	BK = { "skin", "SmoothPlastic" },
	WG = { 0x4a4f58, "Metal" }, -- §3.1 WG row
	SD = { 0x101014, "SmoothPlastic", 0.6 },
	FP = { 0xffffff, "SmoothPlastic", 1 },
}

local function colorsOf(look: Look?): { [string]: any }
	if type(look) ~= "table" then
		return {}
	end
	local c = look.colors
	return if type(c) == "table" then c else look
end

local function slotColor(slot: any, look: Look?): number
	if type(slot) == "number" then
		return slot
	end
	if slot == "STEEL" or slot == "steel" then
		return STEEL
	elseif slot == "GRIP" or slot == "grip" then
		return GRIP
	end
	if type(slot) == "string" then
		local key = string.match(slot, "^colors%.(%w+)$") or slot
		local c = colorsOf(look)[key]
		if type(c) == "number" then
			return c
		end
	end
	return 0x808080
end

-- Costumes.DEFAULT_TINT, when present, wins over the local table (any of: 0xRRGGBB, "slot",
-- {slot, material, transparency}, {slot = / color = , material = , transparency = }).
local function designTint(key: string): { any }?
	local src = Costumes.DEFAULT_TINT
	local v = if type(src) == "table" then src[key] else nil
	if v == nil then
		return nil
	end
	if type(v) == "number" or type(v) == "string" then
		return { v }
	end
	if type(v) == "table" then
		local slot = v.slot or v.from or v.color or v.colour or v[1]
		if slot ~= nil then
			return { slot, v.material or v[2], v.transparency or v[3] }
		end
	end
	return nil
end

--- The §2.9 default colour, material and transparency for a code (or "code·sub").
function Kit.tint(key: string, look: Look?): (number, string, number?)
	local mine = TINT[key]
	local theirs = designTint(key)
	local slot = (theirs and theirs[1]) or (mine and mine[1])
	local mat = (theirs and theirs[2]) or (mine and mine[2]) or "SmoothPlastic"
	local tr = (theirs and theirs[3]) or (mine and mine[3])
	if slot == nil then
		local base = string.match(key, "^(.-)·[^·]+$")
		if base and base ~= key and (TINT[base] or designTint(base)) then
			return Kit.tint(base, look)
		end
		return 0x808080, mat, tr
	end
	return slotColor(slot, look), mat, tr
end

local SUB_ALIAS: { [string]: { string } } = {
	lens = { "lens", "lenses", "slit" },
	slit = { "slit", "lens", "lenses" },
	seam = { "seam", "glow" },
	claw = { "claw", "tip" },
	hilt = { "hilt", "grip" },
}

local function sideKey(s: number?): string?
	return if s == -1 then "L" elseif s == 1 then "R" else nil
end

--- Props for a piece: §2.9 default, then the entry's explicit values. With `sub`, the
--- colour comes from entry.tints[sub] or entry.accent (lenses, slits, seams, claws).
function Kit.props(code: string, entry: Entry, look: Look?, sub: string?, side: number?): Props
	local key = if sub then code .. "·" .. sub else code
	local color, mat, tr = Kit.tint(key, look)
	local tints = if type(entry.tints) == "table" then entry.tints else nil
	local refl: number? = nil
	if sub then
		local t: any = nil
		if tints then
			local keys: { string } = SUB_ALIAS[sub] or { sub }
			for _, k in keys do
				if tints[k] ~= nil then
					t = tints[k]
					break
				end
			end
		end
		if t == nil then
			t = entry.accent
		end
		if type(t) == "number" then
			color = t
		end
	else
		if type(entry.tint) == "number" then
			color = entry.tint
		end
		local sk = sideKey(side)
		if sk and tints and type(tints[sk]) == "number" then
			color = tints[sk]
		end
		if type(entry.material) == "string" then
			mat = entry.material
		end
		if type(entry.transparency) == "number" then
			tr = entry.transparency
		end
		if type(entry.reflectance) == "number" then
			refl = entry.reflectance
		end
	end
	return { color = color, material = mat, transparency = tr, reflectance = refl, name = code }
end

--------------------------------------------------------------------------------
-- Entry helpers
--------------------------------------------------------------------------------

local function codeOf(entry: Entry): string
	return tostring(entry[1] or entry.code or "?")
end
Kit.codeOf = codeOf

local function has(entry: Entry, word: string): boolean
	local v = entry.variant
	return type(v) == "string" and string.find(string.lower(v), word, 1, true) ~= nil
end

--- "L"/"left" -> -1 (the character's left is -X), "R"/"right" -> +1.
local function sideOf(v: any): number?
	if type(v) ~= "string" then
		return nil
	end
	local c = string.upper(string.sub(v, 1, 1))
	return if c == "L" then -1 elseif c == "R" then 1 else nil
end
Kit.sideOf = sideOf

--- Sides for a "1 each" piece: n = 2 is the pair; n = 1 is entry.side or `default`.
local function sidesOf(entry: Entry, defaultN: number, defaultSide: number): { number }
	local n = if type(entry.n) == "number" then entry.n else defaultN
	local one = sideOf(entry.side)
	if n <= 1 then
		return { one or defaultSide }
	end
	return { -1, 1 }
end

local function LR(s: number): string
	return if s < 0 then "Left" else "Right"
end

--- Nominal size with entry.scale = {x?, y?, z?} per-axis overrides.
local function sized(entry: Entry, v: Vector3): Vector3
	local sc = entry.scale
	if type(sc) ~= "table" then
		return v
	end
	return V(sc.x or sc.X or v.X, sc.y or sc.Y or v.Y, sc.z or sc.Z or v.Z)
end

--- Host, attachment and offset, honouring entry.mount / entry.pos (x mirrored to side s).
local function spot(
	rig: Rig,
	entry: Entry,
	host: string,
	attach: string?,
	pos: Vector3,
	s: number?
): (BasePart, string?, Vector3)
	local a = attach
	local h = host
	local p = pos
	if type(entry.mount) == "string" then
		a = entry.mount
		if s and a then
			a = string.gsub(string.gsub(a :: string, "^Left", LR(s)), "^Right", LR(s))
		end
		local d = a and ATTACH[a]
		if d then
			h = d.host
		end
	end
	local given = toV3(entry.pos)
	if given then
		p = if s then V(s * math.abs(given.X), given.Y, given.Z) else given
	end
	return part(rig, h), a, p
end

local function add(out: { BasePart }, p: BasePart?): BasePart?
	if p then
		table.insert(out, p)
	end
	return p
end

--------------------------------------------------------------------------------
-- SurfaceGui drawing
--------------------------------------------------------------------------------

local function faceDims(size: Vector3, face: string): (number, number)
	if face == "Left" or face == "Right" then
		return size.Z, size.Y
	elseif face == "Top" or face == "Bottom" then
		return size.X, size.Z
	end
	return size.X, size.Y
end

local function newGui(p: BasePart, face: string, name: string, pps: number, lit: boolean?): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = name
	g.Face = normal(face)
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = if lit then 0 else 1
	g.Brightness = if lit then 2 else 1
	g.MaxDistance = 120
	g.ClipsDescendants = false
	g.Adornee = p
	g.Parent = p
	return g
end

local function box(
	parent: Instance,
	name: string,
	pos: UDim2,
	w: number,
	h: number,
	color: Color3?,
	rot: number?,
	z: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = UDim2.fromOffset(w, h)
	f.BorderSizePixel = 0
	if color then
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 0
	else
		f.BackgroundTransparency = 1
	end
	f.Rotation = rot or 0
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

local function round(f: Frame, px: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if px then UDim.new(0, px) else UDim.new(0.5, 0)
	c.Parent = f
end

local function stroke(f: Frame, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = f
end

local function at(x: number, y: number): UDim2
	return UDim2.fromOffset(x, y)
end
local function mid(dx: number, dy: number): UDim2
	return UDim2.new(0.5, dx, 0.5, dy)
end
local function sc(x: number, y: number): UDim2
	return UDim2.fromScale(x, y)
end

--- A stepped transparency (opaque inside `segs`, clear between) so one Frame draws a dashed
--- row; keeps emblems within 6 Frames (§2.5). segs are sorted [a, b] spans in 0..1.
local function steps(segs: { { number } }): NumberSequence
	local kp = {}
	local e = 0.002
	local function push(t: number, v: number)
		table.insert(kp, NumberSequenceKeypoint.new(t, v))
	end
	if segs[1][1] > 0 then
		push(0, 1)
	end
	for _, s in segs do
		local a, b = s[1], s[2]
		if a > 0 then
			push(a - e, 1)
		end
		push(a, 0)
		push(b, 0)
		if b < 1 then
			push(b + e, 1)
		end
	end
	if segs[#segs][2] < 1 then
		push(1, 1)
	end
	return NumberSequence.new(kp)
end

--- n equal opaque spans of `dash` px spaced `period` px, filling a frame exactly.
local function dashes(f: Frame, n: number, dash: number, period: number, rot: number?)
	local total = (n - 1) * period + dash
	local segs = {}
	for i = 0, n - 1 do
		table.insert(segs, { i * period / total, (i * period + dash) / total })
	end
	local g = Instance.new("UIGradient")
	g.Transparency = steps(segs)
	g.Rotation = rot or 0
	g.Parent = f
end

local function circle(parent: Instance, name: string, pos: UDim2, d: number, color: Color3?, z: number?): Frame
	local f = box(parent, name, pos, d, d, color, 0, z)
	round(f)
	return f
end

-- §2.5 emblems, drawn about the centre of a 100 px square; each uses at most 6 Frames.
local EMBLEMS: { [string]: (Instance, Color3, Color3) -> () } = {
	E1 = function(g, s, _p) -- Gust: 3 bars 60×6 at -20°, 12 px apart
		for i = -1, 1 do
			box(g, "Gust", mid(-6 * i, 12 * i), 60, 6, s, -20)
		end
	end,
	E2 = function(g, s, _p) -- Knot: 3 stroked Ø26 circles, centres 14 px out at 90/210/330°
		for _, a in { 90, 210, 330 } do
			local r = math.rad(a)
			local f = circle(g, "Knot", mid(14 * math.cos(r), -14 * math.sin(r)), 26, nil)
			stroke(f, s, 4)
		end
	end,
	E3 = function(g, s, p) -- Hex core: three 40×24 at 0/60/120° plus a centre dot
		for _, a in { 0, 60, 120 } do
			box(g, "Hex", mid(0, 0), 40, 24, s, a)
		end
		circle(g, "Core", mid(0, 0), 10, p, 2)
	end,
	E4 = function(g, s, p) -- Crescent: a filled circle overlapped by a plate circle offset 12 px
		circle(g, "Moon", mid(-6, 0), 44, s, 1)
		circle(g, "Shade", mid(6, 0), 44, p, 2)
	end,
	E5 = function(g, s, _p) -- Droplet: Ø36 circle plus a 26 square at 45° on top
		circle(g, "Drop", mid(0, 8), 36, s)
		box(g, "Tip", mid(0, -4), 26, 26, s, 45)
	end,
	E6 = function(g, s, _p) -- Chevron: two 40×8 bars at ±35°
		box(g, "Chevron", mid(-15, 0), 40, 8, s, 35)
		box(g, "Chevron", mid(15, 0), 40, 8, s, -35)
	end,
	E7 = function(g, s, _p) -- Seal ring: stroked Ø50 ring, 4 ticks, centre dot
		local ring = circle(g, "Ring", mid(0, 0), 50, nil)
		stroke(ring, s, 4)
		for i = 0, 3 do
			local a = math.rad(90 * i)
			box(g, "Tick", mid(31 * math.sin(a), -31 * math.cos(a)), 4, 10, s, 90 * i)
		end
		circle(g, "Dot", mid(0, 0), 8, s)
	end,
	E8 = function(g, s, p) -- Film strip: a bar with 4 sprocket squares above and 4 below
		box(g, "Film", mid(0, 0), 84, 36, s)
		for _, dy in { -12, 12 } do
			local row = box(g, "Sprockets", mid(0, dy), 72, 6, p, 0, 2)
			dashes(row, 4, 6, 22)
		end
	end,
	E9 = function(g, s, p) -- Pips: a rounded square with 3 diagonal dots
		local sq = box(g, "Die", mid(0, 0), 44, 44, s)
		round(sq, 8)
		for i = -1, 1 do
			circle(g, "Pip", mid(12 * i, 12 * i), 9, p, 2)
		end
	end,
	E10 = function(g, s, _p) -- Star-flare: 4 thin 6×40 tapered diamonds crossed
		for i = 0, 3 do
			local f = box(g, "Flare", mid(0, 0), 6, 40, s, 45 * i)
			local grad = Instance.new("UIGradient")
			grad.Rotation = 90
			grad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			grad.Parent = f
		end
	end,
	E11 = function(g, s, _p) -- Seam: 5 dashes 8×3 with 5 cross-ticks
		dashes(box(g, "Seam", mid(0, 0), 64, 3, s), 5, 8, 14)
		dashes(box(g, "Ticks", mid(0, 0), 58, 11, s), 5, 2, 14)
	end,
}
Kit.EMBLEMS = EMBLEMS

export type EmblemOpts = {
	face: string?,
	stroke: number?,
	plate: number?,
	lit: boolean?,
	name: string?,
	rot: number?,
}

--- §2.5 emblem on one face of a part, fitted to the face's shorter side. Strokes default to
--- white; the plate colour (for cut-outs) defaults to the part's own colour.
function Kit.emblem(p: BasePart, id: string, opts: EmblemOpts?): SurfaceGui?
	local draw = EMBLEMS[id]
	if not draw then
		return nil
	end
	local o: EmblemOpts = opts or {}
	local face = o.face or "Front"
	local fw, fh = faceDims(p.Size, face)
	local g = newGui(p, face, o.name or ("Emblem_" .. id), 100 / math.max(math.min(fw, fh), 0.05), o.lit)
	local holder: Instance = g
	if o.rot then
		holder = box(g, "Holder", mid(0, 0), 100, 100, nil, o.rot)
	end
	draw(holder, Palette.color(o.stroke or 0xffffff), if o.plate then Palette.color(o.plate) else p.Color)
	return g
end

--------------------------------------------------------------------------------
-- 0-part SurfaceGui decorations (entry.gui, style guis): Kit.GUIS[kind](gui, spec, w, h, color)
-- w, h are the face in pixels (100 px per stud); `color` is the spec's colour (or glow).
--------------------------------------------------------------------------------

type GuiSpec = { [string]: any }
local GUIS: { [string]: (SurfaceGui, GuiSpec, number, number, Color3) -> () } = {}
Kit.GUIS = GUIS

GUIS.stripe = function(g, _spec, w, h, col)
	box(g, "Stripe", sc(0.5, 0.42), w, math.max(h * 0.1, 4), col)
end
GUIS.trim = function(g, spec, w, h, col)
	if spec.emblem == "E11" then
		local line = box(g, "Seam", sc(0.5, 0.06), w - 6, 3, col)
		dashes(line, 6, (w - 6) / 11, (w - 6 - (w - 6) / 11) / 5)
		return
	end
	local f = box(g, "Trim", sc(0.5, 0.5), w - 4, h - 4, nil)
	stroke(f, col, 3)
end
GUIS.edge = GUIS.trim
GUIS.panel = function(g, _spec, w, h, col)
	round(box(g, "Panel", sc(0.5, 0.5), w * 0.5, h * 0.45, col), 6)
end
GUIS.zigzag = function(g, _spec, _w, h, col)
	for i = 1, 4 do
		box(g, "Zig", sc(0.5, i / 5), 4, h * 0.26, col, if i % 2 == 0 then 40 else -40)
	end
end
GUIS.veins = function(g, _spec, _w, h, col)
	local marks = { { 0.3, 0.35, -30 }, { 0.62, 0.3, 20 }, { 0.42, 0.65, -15 }, { 0.7, 0.62, 35 } }
	for _, m in marks do
		box(g, "Vein", sc(m[1], m[2]), 3, h * 0.3, col, m[3])
	end
end
GUIS.crossStitch = function(g, _spec, _w, h, col)
	local holder = box(g, "Stitch", sc(0.5, 0.5), 100, 100, nil, 90)
	local n = 5
	local period = math.min(h * 0.8, 80) / n
	dashes(box(holder, "Seam", mid(0, 0), (n - 1) * period + 8, 3, col), n, 8, period)
	dashes(box(holder, "Ticks", mid(0, 0), (n - 1) * period + 2, 11, col), n, 2, period)
end
GUIS.lavaCrack = function(g, _spec, _w, h, col)
	-- character's left temple is the viewer's right on the Front face
	local marks = { { 0.84, 0.18, 16 }, { 0.86, 0.34, -27 }, { 0.8, 0.5, 27 } }
	for _, m in marks do
		box(g, "Crack", sc(m[1], m[2]), 3, h * 0.14, col, m[3])
	end
end
GUIS.patch = function(g, spec, w, h, col)
	local f = box(
		g,
		"Patch",
		sc(0.5, 0.5),
		math.min(spec.w or 60, w),
		math.min(spec.h or 40, h),
		Palette.color(spec.fill or 0x9b1a2a)
	)
	stroke(f, col, 2)
	if spec.border == "E11" then
		local seam = box(f, "Seam", sc(0.5, 0.12), math.min(spec.w or 60, w) - 8, 3, col, 0, 2)
		dashes(seam, 5, 6, ((math.min(spec.w or 60, w) - 8) - 6) / 4)
	end
end
GUIS.ring = function(g, _spec, _w, _h, col)
	EMBLEMS.E7(box(g, "Ring", sc(0.5, 0.5), 100, 100, nil), col, col)
end
GUIS.palm = function(g, _spec, _w, _h, col)
	circle(g, "Palm", sc(0.5, 0.5), 40, col)
end
GUIS.grille = function(g, spec, w, _h, col)
	local c = if spec.color then col else Color3.fromRGB(26, 26, 32)
	for i = 1, 4 do
		box(g, "Slot", sc(0.5, 0.2 + 0.15 * i), w * 0.5, 3, c)
	end
end
GUIS.beads = function(g, _spec, _w, _h, col)
	for i = 1, 4 do
		circle(g, "Bead", sc(0.5, i / 5), 6, col)
	end
end
GUIS.gripWrap = function(g, spec, w, h, col)
	local n = spec.bands or 3
	for i = 1, n do
		box(g, "Wrap", sc(0.5, 1 - 0.25 * i / (n + 1)), w, math.max(h * 0.03, 3), col)
	end
end
GUIS.stripes = function(g, spec, w, _h, col)
	local n = spec.bars or 3
	for i = 1, n do
		box(g, "Stripe", sc(0.5, i / (n + 1)), w * 1.3, 4, col, spec.rot or 30)
	end
end
GUIS.nails = function(g, spec, _w, _h, col)
	local n = spec.count or 3
	for i = 1, n do
		circle(g, "Nail", sc(i / (n + 1), 0.5), 8, col)
	end
end
GUIS.dots = function(g, spec, _w, _h, col)
	local n = spec.count or 4
	for i = 1, n do
		circle(g, "Dot", sc(i / (n + 1), 0.5), 6, col)
	end
end
GUIS.reels = function(g, spec, w, h, col)
	local n = spec.digits or 3
	for i = 1, n do
		local f = box(g, "Reel", sc(i / (n + 1), 0.5), w / (n + 1.5), h * 0.6, Color3.fromRGB(20, 20, 28))
		local t = Instance.new("TextLabel")
		t.Name = "Digit"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "7"
		t.TextScaled = true
		t.TextColor3 = col
		t.Parent = f
	end
end
GUIS.tipBands = function(g, spec, w, h, col)
	local frac = spec.frac or 0.2
	box(g, "Tip", sc(0.5, 1 - frac / 2), w, h * frac, col)
end

-- Which face a gui kind sits on when the spec gives none.
local GUI_FACE: { [string]: string } = { palm = "Bottom", tipBands = "Back" }
local GUI_FACE_BY_CODE: { [string]: string } =
	{ PLT = "Top", ["HR·p"] = "Back", SC = "Back", CP = "Back", CT = "Back" }
local GUI_ALL: { [string]: boolean } = { tipBands = true, palm = true, edge = true, ring = true, beads = true }

local function sideOfPart(p: BasePart, weld: Weld?): number
	local host = weld and weld.Part0
	if host then
		if string.sub(host.Name, 1, 4) == "Left" then
			return -1
		elseif string.sub(host.Name, 1, 5) == "Right" then
			return 1
		end
	end
	if weld then
		return if weld.C0.Position.X < 0 then -1 else 1
	end
	return 1
end

--- Draws a 0-part SurfaceGui decoration (entry.gui or a style-level gui) on the chosen parts.
function Kit.gui(parts: { BasePart }, spec: GuiSpec, look: Look?, code: string?): { SurfaceGui }
	local kind = tostring(spec.kind or "trim")
	local draw = GUIS[kind] or GUIS.trim
	local glow = spec.glow
	local lit = glow ~= nil and glow ~= false
	local colour = if type(spec.color) == "number"
		then spec.color
		elseif type(glow) == "number" then glow
		else slotColor("sig", look)
	local col = Palette.color(colour)
	local want = sideOf(spec.side)
	local chosen: { BasePart } = {}
	for i, p in parts do
		local weld = p:FindFirstChildOfClass("Weld")
		local s = sideOfPart(p, weld)
		if want then
			if s == want then
				table.insert(chosen, p)
			end
		elseif GUI_ALL[kind] then
			table.insert(chosen, p)
		elseif kind == "nails" then
			if i == #parts then
				table.insert(chosen, p)
			end
		elseif i == 1 then
			table.insert(chosen, p)
		end
	end
	if #chosen == 0 and #parts > 0 and not want then
		chosen = { parts[1] }
	end
	local out = {}
	for _, p in chosen do
		local weld = p:FindFirstChildOfClass("Weld")
		local face = spec.face
		if not face then
			if kind == "ring" then
				face = if sideOfPart(p, weld) < 0 then "Left" else "Right"
			elseif kind == "patch" then
				local s = sideOf(spec.side) or 1
				face = if s < 0 then "Left" else "Right"
			else
				face = GUI_FACE[kind] or (code and GUI_FACE_BY_CODE[code]) or "Front"
			end
		end
		local fw, fh = faceDims(p.Size, face)
		local g = newGui(p, face, "Gui_" .. kind, 100, lit)
		if type(glow) == "number" then
			g:SetAttribute("Glow", Palette.color(glow))
		end
		draw(g, spec, fw * 100, fh * 100, col)
		table.insert(out, g)
	end
	return out
end

--------------------------------------------------------------------------------
-- Face system (§2.4)
--------------------------------------------------------------------------------

export type FaceOpts = {
	friend: boolean?, -- friend face (players, allies): whites + iris on FaceBase
	eye: number?,
	brow: number?,
	browAngle: number?,
	glow: number?, -- technique glow (friend) colour
	iris: number?, -- foe FaceGlow iris colour (sig for a character boss, gold for alphas, affix colour)
	irisScale: number?, -- alphas 1.3
	marks: { any }?, -- up to 4 Frames {x, y, w, h, rot, color, layer = "base" | "glow"}
	hideEyes: boolean?, -- masked: lenses or slits act as the eyes
	mouth: boolean?, -- false under LM, FM, CK-mask and BK
}

local WHITE = 0xf4f0ea
local PUPIL = 0x101014
local MOUTH = 0x3a2020

local function faceGui(fp: BasePart, name: string, pps: number, light: number, bright: number, zoff: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = name
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = light
	g.Brightness = bright
	g.ZOffset = zoff
	g.ClipsDescendants = false
	g.MaxDistance = 120
	g.Adornee = fp
	g.Parent = fp
	return g
end

--- Builds FaceBase and FaceGlow on FP and destroys Head.face (§2.4). The canvas is always
--- 90×55 px (PixelsPerStud 100 at head scale 1). Canvas x grows toward the character's left.
function Kit.face(model: Model, fp: BasePart, opts: FaceOpts?): (SurfaceGui, SurfaceGui)
	local o: FaceOpts = opts or {}
	local head = model:FindFirstChild("Head")
	if head then
		local decal = head:FindFirstChild("face")
		if decal and decal:IsA("Decal") then
			decal:Destroy()
		end
	end
	for _, n in { "FaceBase", "FaceGlow" } do
		local old = fp:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local pps = 100 * 0.9 / math.max(fp.Size.X, 0.01)
	local base = faceGui(fp, "FaceBase", pps, 1, 1, 0)
	local glow = faceGui(fp, "FaceGlow", pps, 0, 2.5, 1)
	local friend = o.friend ~= false
	local hide = o.hideEyes == true
	local sc2 = o.irisScale or 1
	local eye = Palette.color(o.eye or 0x3a3440)
	local irisCol = Palette.color(o.iris or o.eye or 0x3a3440)
	local glowCol = Palette.color(o.glow or o.eye or 0xffffff)
	local browCol = Palette.color(o.brow or 0x2a2020)
	local angle = (o.browAngle or 0.25) * 57
	for _, cx in { 21, 69 } do
		local side = if cx < 45 then "R" else "L" -- canvas left is the character's right
		local white = box(base, "White" .. side, at(cx, 20), 14, 8, Palette.color(WHITE), 0, 1)
		round(white, 3)
		white.Visible = friend and not hide
		local pupil = box(base, "Pupil" .. side, at(cx, 20), 3, 5, Palette.color(PUPIL), 0, 3)
		pupil.Visible = friend and not hide
		if friend then
			box(base, "Iris" .. side, at(cx, 20), 7, 8, eye, 0, 2).Visible = not hide
			box(glow, "Glow" .. side, at(cx, 20), 7, 8, glowCol, 0, 2).Visible = not hide
		else
			box(glow, "Iris" .. side, at(cx, 20), 12 * sc2, 6 * sc2, irisCol, 0, 2).Visible = not hide
		end
		box(base, "Brow" .. side, at(cx, 11), 16, 3, browCol, if cx < 45 then angle else -angle, 2).Visible = not hide
	end
	box(base, "Mouth", at(45, 46), 10, 2, Palette.color(MOUTH), 0, 2).Visible = o.mouth ~= false
	local marks: { any } = o.marks or {}
	for i, m in marks do
		if i > 4 then
			break
		end
		if type(m) == "table" then
			local layer = if m.layer == "glow" then glow else base
			box(
				layer,
				"Mark" .. i,
				at(m.x or m[1] or 45, m.y or m[2] or 27),
				m.w or m[3] or 3,
				m.h or m[4] or 10,
				Palette.color(m.color or m[6] or 0x3a2020),
				m.rot or m[5] or 0,
				4
			)
		end
	end
	if friend then
		glow.Enabled = false -- Looks.setGlow turns the technique glow on
	end
	return base, glow
end

--- The chest maw (§2.4): a dark band in colors.trim with teeth half under it. 0 parts.
function Kit.maw(model: Model, look: Look?, maw: { [string]: any }): SurfaceGui?
	local ut = model:FindFirstChild("UpperTorso")
	if not (ut and ut:IsA("BasePart")) then
		return nil
	end
	local old = ut:FindFirstChild("Maw")
	if old then
		old:Destroy()
	end
	local g = newGui(ut, "Front", "Maw", 100 * 2 / math.max(ut.Size.X, 0.01), false)
	box(g, "Band", sc(0.5, 0.45), 160, 40, Palette.color(slotColor("trim", look)), 0, 2)
	local tooth = Palette.color(maw.teeth or maw.color or 0xd8d0e8)
	local jag = maw.jagged == true
	local xs = { -66, -47, -31, -12, 7, 22, 41, 60 }
	local sizes = if jag then { 14, 8, 16, 10, 15, 7, 13, 11 } else { 10, 8, 11, 9, 10, 8, 11, 9 }
	for i, x in xs do
		local top = i % 2 == 1
		local y = if top then -20 else 20
		box(g, "Tooth", UDim2.new(0.5, x, 0.45, y), sizes[i], sizes[i], tooth, 45, 1)
	end
	return g
end

--------------------------------------------------------------------------------
-- Emitters (§6.5)
--------------------------------------------------------------------------------

export type EmitterSpec = {
	rate: number,
	life: { number },
	light: number,
	size: { number },
	color: number?,
	speed: { number }?,
	spread: number?,
	accel: Vector3?,
	transparency: { number }?,
	shape: string?,
	flat: boolean?,
	spin: boolean?,
	emit: number?,
}

Kit.EMITTERS = {
	ember = { rate = 4, life = { 0.6, 1.0 }, light = 0.6, size = { 0.2, 0 }, speed = { 1, 2 }, color = 0xff8a3d },
	smoke = {
		rate = 5,
		life = { 1.2, 1.2 },
		light = 0,
		size = { 0.6, 1.2 },
		transparency = { 0.4, 1 },
		color = 0x3a3a40,
	},
	drip = { rate = 3, life = { 0.8, 0.8 }, light = 0.2, size = { 0.12, 0.12 }, accel = V(0, -20, 0) },
	spark = {
		rate = 6,
		life = { 0.3, 0.3 },
		light = 1,
		size = { 0.1, 0.1 },
		speed = { 6, 6 },
		spread = 180,
		color = 0xffe45c,
	},
	wind = { rate = 4, life = { 1.0, 1.0 }, light = 0.3, size = { 0.3, 0 }, spread = 30, color = 0xdff4ee },
	dust = { rate = 6, life = { 0.8, 0.8 }, light = 0, size = { 0.4, 0.8 }, color = 0xc8b8a0 },
	shadow = { rate = 5, life = { 1.0, 1.0 }, light = 0, size = { 1, 0 }, color = 0x101014, flat = true },
	feather = { rate = 3, life = { 1.2, 1.2 }, light = 0, size = { 0.25, 0.25 }, color = 0x14141c, spin = true },
	coin = { rate = 3, life = { 0.8, 0.8 }, light = 0.5, size = { 0.2, 0.2 }, color = 0xffd54a },
	aura = { rate = 10, life = { 1.0, 1.0 }, light = 0.8, size = { 0.8, 0 }, color = 0xff2d55, shape = "Cylinder" },
	thread = { rate = 4, life = { 1.2, 1.2 }, light = 1, size = { 0.1, 0.1 }, color = 0xff2d55 },
	burst = { rate = 0, emit = 12, life = { 0.6, 0.6 }, light = 1, size = { 0.3, 0 } },
} :: { [string]: EmitterSpec }

--- A §6.5 emitter under `parent` (a Part or Attachment). opts.color overrides the key's colour
--- (drip takes the owner's colour, Karasu's ember 0x5a5a78); opts.rate the rate (thread 12,
--- a grade-special aura 6). `burst` has Rate 0 and an "Emit" attribute (12) for the caller.
function Kit.emitter(
	parent: Instance,
	key: string,
	opts: { color: number?, rate: number?, name: string? }?
): ParticleEmitter?
	local spec = Kit.EMITTERS[key]
	if not spec then
		return nil
	end
	local o: { color: number?, rate: number?, name: string? } = opts or {}
	local e = Instance.new("ParticleEmitter")
	e.Name = o.name or key
	e.Rate = o.rate or spec.rate
	e.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
	e.LightEmission = spec.light
	e.Size = NumberSequence.new(spec.size[1], spec.size[2])
	local speed = spec.speed or { 0.5, 1 }
	e.Speed = NumberRange.new(speed[1], speed[2])
	if spec.spread then
		e.SpreadAngle = Vector2.new(spec.spread, spec.spread)
	end
	if spec.accel then
		e.Acceleration = spec.accel
	end
	local tr = spec.transparency or { 0.2, 0.6 }
	e.Transparency = NumberSequence.new(tr[1], tr[2])
	e.Color = ColorSequence.new(Palette.color(o.color or spec.color or 0xffffff))
	if spec.spin then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
	end
	if spec.shape == "Cylinder" then
		e.Shape = Enum.ParticleEmitterShape.Cylinder
	end
	if spec.flat then
		e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		e.EmissionDirection = Enum.NormalId.Top
		e.Speed = NumberRange.new(0.01, 0.01)
	end
	if spec.emit then
		e:SetAttribute("Emit", spec.emit)
	end
	e.Parent = parent
	return e
end

local function fxPoint(rig: Rig, name: string, cf: CFrame): Attachment?
	local host = rig.parts[name]
	if not host then
		return nil
	end
	local a = Instance.new("Attachment")
	a.Name = "CostumeFx"
	a.CFrame = cf
	a.Parent = host
	return a
end

--- Places a §6.5 emitter: on the piece, or at = "hands" | "feet" | "tips" | "head" | "back".
function Kit.fx(rig: Rig, key: string, where: string?, piece: BasePart?, color: number?): { ParticleEmitter }
	local hosts: { Instance } = {}
	local function push(i: Instance?)
		if i then
			table.insert(hosts, i)
		end
	end
	if where == "hands" then
		local hand = rig.parts.RightHand
		local grip = hand and hand:FindFirstChild("RightGripAttachment")
		local cf = if grip and grip:IsA("Attachment")
			then grip.CFrame
			else CFrame.new(ATTACH.RightGripAttachment.pos * (if hand then Kit.scaleOf(hand) else Vector3.one))
		push(fxPoint(rig, "RightHand", cf))
	elseif where == "feet" then
		push(fxPoint(rig, "HumanoidRootPart", C(0, rig.ground + 0.1, 0)))
	elseif where == "head" then
		push(fxPoint(rig, "Head", C(0, 0.6, 0)))
	elseif where == "back" then
		push(fxPoint(rig, "UpperTorso", C(0, 0, 0.6)))
	elseif where == "tips" and piece then
		for _, s in { -1, 1 } do
			local a = Instance.new("Attachment")
			a.Name = "FxTip"
			a.CFrame = C(s * piece.Size.X / 2, 0, 0)
			a.Parent = piece
			push(a)
		end
	elseif piece then
		push(piece)
	else
		push(rig.parts.UpperTorso)
	end
	local out = {}
	for _, h in hosts do
		local e = Kit.emitter(h, key, { color = color })
		if e then
			table.insert(out, e)
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

--- §2.1 band-over-hair rule: the minimum band size (X, Z) at height y over a cap.
function Kit.ringOver(capSize: Vector3, capOffset: Vector3, y: number): Vector2
	local t = (y - capOffset.Y) / (capSize.Y / 2)
	local f = math.sqrt(math.max(0, 1 - t * t))
	return Vector2.new(capSize.X * f + 0.06, capSize.Z * f + 0.06)
end

--- §2.8: map[R15 part name] = {color, material?, reflectance?} (or {color =, material =, reflectance =}).
function Kit.paintParts(model: Model, map: { [string]: any }?)
	if type(map) ~= "table" then
		return
	end
	for name, spec in map do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			local color = if type(spec) == "number" then spec else spec.color or spec[1]
			if type(color) == "number" then
				p.Color = Palette.color(color)
			end
			if type(spec) == "table" then
				local mat = spec.material or spec[2]
				if mat then
					p.Material = material(mat)
				end
				local refl = spec.reflectance or spec[3]
				if type(refl) == "number" then
					p.Reflectance = refl
				end
			end
		end
	end
end

--- §2.1 chain rule: bone frames (relative to the attachment) whose +Y runs along each segment.
function Kit.chain(base: Vector3, rots: { CFrame }, lens: { number }): { CFrame }
	local bones = {}
	local bone = CFrame.new(base) * (rots[1] or CFrame.identity) * CFrame.new(0, lens[1] / 2, 0)
	bones[1] = bone
	for k = 2, #lens do
		bone = bone * CFrame.new(0, lens[k - 1] / 2, 0) * (rots[k] or CFrame.identity) * CFrame.new(0, lens[k] / 2, 0)
		bones[k] = bone
	end
	return bones
end

--- The FP piece of a dressed model, if any.
function Kit.faceOf(model: Model): BasePart?
	local costume = model:FindFirstChild("Costume")
	local fp = costume and costume:FindFirstChild("FP")
	return if fp and fp:IsA("BasePart") then fp else nil
end

--------------------------------------------------------------------------------
-- Pieces (§2.3). Each returns the parts it mounted, in side order (left, right).
--------------------------------------------------------------------------------

export type PieceFn = (Builder, Rig, Entry, Look) -> { BasePart }
local P: { [string]: PieceFn } = {}
Kit.PIECES = P

local function capOffset(rig: Rig): Vector3
	return if rig.worn["HB"] then V(0, 0.32, 0.06) else V(0, 0.26, 0.06)
end
Kit.capOffset = capOffset
Kit.CAP = V(1.30, 1.02, 1.32)

local function isSlit(entry: Entry): boolean
	if has(entry, "slit") then
		return true
	end
	if has(entry, "round") or has(entry, "block") or has(entry, "lens") then
		return false
	end
	local t = entry.tints
	if type(t) == "table" and t.slit ~= nil then
		return true
	end
	return entry.n == 2 or entry.variant == nil
end

local function spikeAngles(n: number): { number }
	if n <= 1 then
		return { 180 }
	elseif n == 2 then
		return { 160, 200 }
	elseif n == 3 then
		return { 150, 180, 210 }
	end
	local t = {}
	for i = 1, n do
		t[i] = 140 + 80 * (i - 1) / (n - 1)
	end
	return t
end

local function tendrilXs(n: number): { number }
	if n <= 1 then
		return { 0 }
	elseif n == 2 then
		return { -0.35, 0.35 }
	elseif n == 3 then
		return { -0.35, 0.35, 0 } -- the third at the back centre
	end
	local t = {}
	for i = 1, n do
		t[i] = -0.45 + 0.9 * (i - 1) / (n - 1)
	end
	return t
end

P.FP = function(b, rig, _entry, _look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "Head"),
			"FaceFrontAttachment",
			"block",
			V(0.9, 0.55, 0.02),
			C(0, 0.05, -0.02),
			{ color = 0xffffff, material = "SmoothPlastic", transparency = 1, name = "FP" },
			{ keep = true }
		)
	)
	return out
end

P.HR = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "Head"),
			nil,
			"ell",
			sized(entry, Kit.CAP),
			CFrame.new(capOffset(rig)),
			Kit.props("HR", entry, look)
		)
	)
	return out
end

P["HR·s"] = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	for _, a in spikeAngles(entry.n or 3) do
		local r = math.rad(a)
		local cf = C(0.34 * math.sin(r), 0.6, -0.34 * math.cos(r)) * rx(30) * ry(a)
		add(out, b:mount(head, nil, "wedge", sized(entry, V(0.28, 0.7, 0.42)), cf, Kit.props("HR·s", entry, look)))
	end
	return out
end

P["HR·w"] = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	local size = sized(entry, V(0.3, 0.45, 0.8))
	if entry.x == 0 or has(entry, "crest") then
		-- single centred crest, rx(+15) only; raised to y 0.72 so it stands clear of the cap (top 0.77)
		add(out, b:mount(head, nil, "wedge", size, C(0, 0.72, 0.1) * rx(15), Kit.props("HR·w", entry, look)))
		return out
	end
	for _, s in sidesOf(entry, 2, 1) do
		local cf = C(s * 0.35, 0.45, 0.1) * rz(s * 25) * rx(15)
		add(out, b:mount(head, nil, "wedge", size, cf, Kit.props("HR·w", entry, look, nil, s)))
	end
	return out
end

P["HR·p"] = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	local h = entry.h or 1.0
	local n = entry.n or 1
	local w = entry.w or (if n > 1 then 0.5 else 1.08)
	local xs: { number } = if n > 1 then { -(entry.x or 0.3), entry.x or 0.3 } else { entry.x or 0 }
	for i, x in xs do
		local s = if n > 1 then (if i == 1 then -1 else 1) else nil
		add(
			out,
			b:mount(
				head,
				nil,
				"block",
				sized(entry, V(w, h, 0.3)),
				C(x, 0.5 - h / 2, 0.62),
				Kit.props("HR·p", entry, look, nil, s)
			)
		)
	end
	return out
end

P["HR·f"] = function(b, rig, entry, look)
	local out = {}
	local s = sideOf(entry.side) or -1
	add(
		out,
		b:mount(
			part(rig, "Head"),
			nil,
			"block",
			sized(entry, V(0.2, 0.6, 0.1)),
			C(s * 0.44, 0.12, -0.6),
			Kit.props("HR·f", entry, look)
		)
	)
	return out
end

P["HR·k"] = function(b, rig, entry, look)
	local out = {}
	local pos = if has(entry, "topknot") then C(0, 0.78, 0) else C(0, 0.62, 0.45)
	add(out, b:mount(part(rig, "Head"), nil, "ball", V(0.54, 0.54, 0.54), pos, Kit.props("HR·k", entry, look)))
	return out
end

P["HR·t"] = function(b, rig, entry, look)
	local out = {}
	for _, s in sidesOf(entry, 2, 1) do
		add(
			out,
			b:mount(
				part(rig, "Head"),
				nil,
				"ball",
				V(0.45, 0.45, 0.45),
				C(s * 0.4, 0.5, 0),
				Kit.props("HR·t", entry, look, nil, s)
			)
		)
	end
	return out
end

P.HB = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "Head"),
			nil,
			"block",
			sized(entry, V(1.40, 0.2, 1.40)),
			C(0, 0.36, 0.06),
			Kit.props("HB", entry, look)
		)
	)
	return out
end

P["HB·t"] = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	for _, s in { -1, 1 } do
		local hinge = V(s * 0.1, 0.30, 0.8)
		local p = b:hinge(
			head,
			nil,
			"block",
			V(0.14, 0.6, 0.05),
			hinge,
			rx(-20) * rz(s * 15),
			Kit.props("HB·t", entry, look, nil, s)
		)
		if p then
			b:sway(hinge, nil, p)
			table.insert(out, p)
		end
	end
	return out
end

P.VB = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "Head"),
			"FaceFrontAttachment",
			"block",
			V(1.28, 0.2, 0.14),
			C(0, 0.12, -0.02),
			Kit.props("VB", entry, look),
			{ keep = true }
		)
	)
	return out
end

P["VB·m"] = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "Head"),
			"FaceFrontAttachment",
			"cyl",
			V(0.05, 0.34, 0.34),
			C(0.24, 0.12, -0.04) * CYL_FWD,
			Kit.props("VB·m", entry, look),
			{ keep = true }
		)
	)
	return out
end

P.LM = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "Head"),
			nil,
			"block",
			sized(entry, V(1.26, 0.5, 1.26)),
			C(0, -0.36, 0),
			Kit.props("LM", entry, look)
		)
	)
	return out
end

P.CK = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "UpperTorso"),
			"NeckAttachment",
			"block",
			sized(entry, V(1.1, 0.22, 1.1)),
			C(0, 0.12, 0),
			Kit.props("CK", entry, look)
		)
	)
	return out
end

P.FM = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	add(
		out,
		b:mount(
			head,
			nil,
			"ell",
			sized(entry, V(1.28, 1.3, 1.3)),
			CFrame.identity,
			Kit.props("FM", entry, look),
			{ keep = true }
		)
	)
	if isSlit(entry) then
		add(
			out,
			b:mount(
				head,
				"FaceFrontAttachment",
				"block",
				V(0.9, 0.1, 0.05),
				C(0, 0.12, -0.05),
				Kit.props("FM", entry, look, "slit"),
				{ keep = true }
			)
		)
	elseif has(entry, "round") then
		for _, s in { -1, 1 } do
			add(
				out,
				b:mount(
					head,
					"FaceFrontAttachment",
					"cyl",
					V(0.06, 0.3, 0.3),
					C(s * 0.24, 0.12, -0.03) * CYL_FWD,
					Kit.props("FM", entry, look, "lens"),
					{ keep = true }
				)
			)
		end
	else
		for _, s in { -1, 1 } do
			add(
				out,
				b:mount(
					head,
					"FaceFrontAttachment",
					"block",
					V(0.26, 0.13, 0.05),
					C(s * 0.24, 0.1, -0.05) * rz(s * 14),
					Kit.props("FM", entry, look, "lens"),
					{ keep = true }
				)
			)
		end
	end
	return out
end

P.BK = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "Head"),
			"FaceFrontAttachment",
			"wedge",
			sized(entry, V(0.35, 0.35, 0.8)),
			C(0, -0.05, -0.4),
			Kit.props("BK", entry, look)
		)
	)
	return out
end

P.HD = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	add(out, b:mount(head, nil, "ell", sized(entry, V(1.45, 1.4, 1.2)), C(0, 0.1, 0.35), Kit.props("HD", entry, look)))
	for _, s in { -1, 1 } do
		add(
			out,
			b:mount(head, nil, "wedge", V(0.12, 1.1, 0.7), C(s * 0.66, 0, -0.1), Kit.props("HD", entry, look, nil, s))
		)
	end
	return out
end

P["HD·d"] = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "UpperTorso"),
			"NeckAttachment",
			"ell",
			sized(entry, V(1.3, 0.5, 0.8)),
			C(0, -0.1, 0.55),
			Kit.props("HD·d", entry, look)
		)
	)
	return out
end

P.HN = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	local branches = has(entry, "branch")
	for _, s in { -1, 1 } do
		local pr = Kit.props("HN", entry, look, nil, s)
		if branches then
			add(out, b:mount(head, nil, "cyl", V(0.7, 0.12, 0.12), C(s * 0.38, 0.55, 0) * CYL_UP * rz(-s * 20), pr))
		else
			add(out, b:mount(head, nil, "wedge", V(0.18, 0.55, 0.24), C(s * 0.38, 0.55, 0) * rz(-s * 20), pr))
		end
	end
	return out
end

P.EP = function(b, rig, entry, look)
	local out = {}
	if has(entry, "fin") or (entry.n == 1 and not has(entry, "ear")) then
		add(
			out,
			b:mount(
				part(rig, "Head"),
				nil,
				"wedge",
				sized(entry, V(0.1, 0.6, 1.1)),
				C(0, 0.7, 0.1),
				Kit.props("EP", entry, look)
			)
		)
		return out
	end
	for _, s in sidesOf(entry, 2, 1) do
		local host, attach, pos = spot(rig, entry, "Head", nil, V(s * 0.4, 0.6, 0), s)
		add(
			out,
			b:mount(
				host,
				attach,
				"wedge",
				sized(entry, V(0.12, 0.5, 0.3)),
				CFrame.new(pos),
				Kit.props("EP", entry, look, nil, s)
			)
		)
	end
	return out
end

P.EC = function(b, rig, entry, look)
	local out = {}
	local s = sideOf(entry.side) or 1
	local host, attach, pos = spot(rig, entry, "Head", nil, V(s * 0.61, 0, 0), s)
	add(out, b:mount(host, attach, "cyl", V(0.08, 0.15, 0.15), CFrame.new(pos), Kit.props("EC", entry, look)))
	return out
end

P.GG = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	local up = has(entry, "up") or has(entry, "push")
	local tints = entry.tints
	local framed = entry.accent ~= nil or (type(tints) == "table" and (tints.lens ~= nil or tints.lenses ~= nil))
	local pr = Kit.props("GG", entry, look)
	local lens = Kit.props("GG", entry, look, "lens")
	if framed then
		pr.material = if type(entry.material) == "string" then entry.material else "SmoothPlastic"
		pr.transparency = 0
	end
	for _, s in { -1, 1 } do
		local p = if up
			then b:mount(
				head,
				nil,
				"cyl",
				V(0.06, 0.36, 0.36),
				C(s * 0.24, 0.5, -0.56) * rx(40) * CYL_FWD,
				pr,
				{ keep = true }
			)
			else b:mount(
				head,
				"FaceFrontAttachment",
				"cyl",
				V(0.06, 0.36, 0.36),
				C(s * 0.24, 0.12, -0.03) * CYL_FWD,
				pr,
				{ keep = true }
			)
		if p then
			table.insert(out, p)
			if framed then
				-- CYL_FWD turns local +X to the front, so the Right face is the lens
				local g = newGui(p, "Right", "Lens", 100 / math.max(p.Size.Y, 0.05), false)
				circle(g, "Lens", sc(0.5, 0.5), 70, Palette.color(lens.color or 0xffffff))
			end
		end
	end
	return out
end

P.HP = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	local pr = Kit.props("HP", entry, look)
	for _, s in { -1, 1 } do
		add(out, b:mount(head, nil, "cyl", V(0.14, 0.45, 0.45), C(s * 0.64, 0.02, 0.05), pr))
	end
	if #out == 2 then
		-- the band: a Beam between Attachments at Head (∓0.64, 0.245, +0.05), 0 parts
		local k = Kit.scaleOf(head)
		local a0 = Instance.new("Attachment")
		a0.Name = "HP0"
		a0.CFrame = CFrame.fromMatrix(V(0, 0.225 * k.Y, 0), V(0, 1, 0), V(1, 0, 0))
		a0.Parent = out[1]
		local a1 = Instance.new("Attachment")
		a1.Name = "HP1"
		a1.CFrame = CFrame.fromMatrix(V(0, 0.225 * k.Y, 0), V(0, -1, 0), V(1, 0, 0))
		a1.Parent = out[2]
		local beam = Instance.new("Beam")
		beam.Name = "Band"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.CurveSize0 = 0.9 * k.Y
		beam.CurveSize1 = 0.9 * k.Y
		beam.Width0 = 0.12 * k.X
		beam.Width1 = 0.12 * k.X
		beam.Segments = 12
		beam.FaceCamera = true
		beam.LightInfluence = 1
		beam.Color = ColorSequence.new(Palette.color(0x2a2a30))
		beam.Transparency = NumberSequence.new(0)
		beam.Parent = out[1]
	end
	return out
end

P.CR = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	local n = entry.n or 4
	for i = 0, n - 1 do
		local cf = ry(45 + (360 / math.max(n, 4)) * i) * C(0, 0.55, -0.4)
		add(out, b:mount(head, nil, "corner", sized(entry, V(0.3, 0.5, 0.3)), cf, Kit.props("CR", entry, look)))
	end
	return out
end

P.OR = function(b, rig, entry, look)
	local out = {}
	local head = part(rig, "Head")
	local n = entry.n or 3
	for k = 0, n - 1 do
		local p = b:mount(
			head,
			nil,
			"wedge",
			V(0.12, 0.35, 0.2),
			ry(360 / n * k) * C(0, 0.65, -0.95),
			Kit.props("OR", entry, look)
		)
		if p then
			b:orbit(V(0, 1, 0), entry.rate or 0.25, 0, Vector3.zero, tostring(k), p)
			table.insert(out, p)
		end
	end
	return out
end

P.SC = function(b, rig, entry, look)
	local out = {}
	local ut = part(rig, "UpperTorso")
	local pr = Kit.props("SC", entry, look)
	add(out, b:mount(ut, "NeckAttachment", "block", V(1.2, 0.34, 1.25), C(0, -0.05, 0), pr))
	local s = sideOf(entry.side) or -1
	local hinge = V(s * 0.45, 0.35, 0.1)
	local tail = b:hinge(ut, "BodyBackAttachment", "block", V(0.36, 1.3, 0.08), hinge, rx(-12), pr)
	if tail then
		b:sway(hinge, nil, tail)
		table.insert(out, tail)
		if type(entry.emblem) == "string" then
			Kit.emblem(tail, entry.emblem, {
				face = "Back",
				stroke = entry.emblemColor or entry.accent or slotColor("sig", look),
				plate = pr.color,
			})
		end
	end
	return out
end

P.SG = function(b, rig, entry, look)
	local out = {}
	local size = sized(entry, if has(entry, "bulky") then V(1.3, 0.4, 1.35) else V(1.1, 0.3, 1.15))
	for _, s in sidesOf(entry, 2, -1) do
		local host = part(rig, LR(s) .. "UpperArm")
		local cf = C(s * 0.1, 0.12, 0) * rz(-s * 20)
		add(out, b:mount(host, LR(s) .. "ShoulderAttachment", "block", size, cf, Kit.props("SG", entry, look, nil, s)))
	end
	return out
end

P.HC = function(b, rig, entry, look)
	local out = {}
	local host, attach, pos = spot(rig, entry, "UpperTorso", "NeckAttachment", V(0, 0.15, 0.05))
	add(
		out,
		b:mount(host, attach, "block", sized(entry, V(1.25, 0.55, 1.2)), CFrame.new(pos), Kit.props("HC", entry, look))
	)
	return out
end

P.LP = function(b, rig, entry, look)
	local out = {}
	local ut = part(rig, "UpperTorso")
	for _, s in { -1, 1 } do
		local cf = C(s * 0.35, 0.1, -0.04) * rz(-s * 18) -- tops out, bottoms in: a V
		add(
			out,
			b:mount(ut, "BodyFrontAttachment", "wedge", V(0.5, 1.1, 0.08), cf, Kit.props("LP", entry, look, nil, s))
		)
	end
	return out
end

P.VS = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "UpperTorso"),
			nil,
			"block",
			sized(entry, V(2.08, 1.5, 1.12)),
			C(0, -0.02, 0),
			Kit.props("VS", entry, look)
		)
	)
	return out
end

local EM_AT: { [string]: { any } } = {
	front = { "BodyFrontAttachment", V(0, 0.2, -0.03), "Front" },
	back = { "BodyBackAttachment", V(0, 0.2, 0.03), "Back" },
	waist = { "WaistFrontAttachment", V(0, 0, -0.03), "Front" },
}
EM_AT.BodyFront = EM_AT.front
EM_AT.BodyBack = EM_AT.back
EM_AT.WaistFront = EM_AT.waist
EM_AT.buckle = EM_AT.waist

P.EM = function(b, rig, entry, look)
	local out = {}
	local where = EM_AT[tostring(entry.at)] or (if has(entry, "buckle") then EM_AT.waist else EM_AT.front)
	local attach: string = where[1]
	local pr = Kit.props("EM", entry, look)
	local pendant = has(entry, "pendant") or has(entry, "diamond")
	local cf = CFrame.new(where[2]) * (if pendant then rz(45) else CFrame.identity)
	local p = b:mount(part(rig, ATTACH[attach].host), attach, "block", sized(entry, V(0.55, 0.55, 0.05)), cf, pr)
	if p then
		table.insert(out, p)
		if type(entry.emblem) == "string" and not pendant then
			local tints = entry.tints
			Kit.emblem(p, entry.emblem, {
				face = where[3],
				stroke = entry.emblemColor
					or entry.accent
					or (if type(tints) == "table" then tints.stroke else nil)
					or slotColor("sig", look),
				plate = pr.color,
			})
		end
	end
	return out
end

P.CT = function(b, rig, entry, look)
	local out = {}
	local lt = part(rig, "LowerTorso")
	for _, s in { -1, 1 } do
		local hinge = V(s * 0.48, 0, 0.04)
		local p = b:hinge(
			lt,
			"WaistBackAttachment",
			"block",
			V(0.95, 1.5, 0.08),
			hinge,
			rx(-14) * rz(-s * 6),
			Kit.props("CT", entry, look, nil, s)
		)
		if p then
			b:sway(hinge, nil, p)
			table.insert(out, p)
		end
	end
	return out
end

P.CP = function(b, rig, entry, look)
	local out = {}
	local size = if has(entry, "short") then V(1.9, 1.4, 0.08) else V(1.9, 2.3, 0.08)
	local hinge = V(0, 0.55, 0.08)
	local p = b:hinge(
		part(rig, "UpperTorso"),
		"BodyBackAttachment",
		"block",
		sized(entry, size),
		hinge,
		rx(-12),
		Kit.props("CP", entry, look)
	)
	if p then
		b:sway(hinge, nil, p)
		table.insert(out, p)
	end
	return out
end

local function pouchesOf(entry: Entry): number
	local v = entry.pouches or entry.pouch
	if v == true then
		return 1
	end
	return if type(v) == "number" then math.clamp(v, 0, 2) else 0
end

P.SB = function(b, rig, entry, look)
	local out = {}
	local lt = part(rig, "LowerTorso")
	local pr = Kit.props("SB", entry, look)
	add(out, b:mount(lt, "WaistCenterAttachment", "block", V(2.1, 0.22, 1.1), CFrame.identity, pr))
	if entry.tail then
		add(out, b:mount(lt, "WaistCenterAttachment", "block", V(0.25, 0.7, 0.06), C(0.6, -0.4, -0.56), pr))
	end
	local spots = { V(-0.7, -0.05, -0.56), V(0.7, -0.05, -0.56) }
	for i = 1, pouchesOf(entry) do
		add(out, b:mount(lt, "WaistCenterAttachment", "block", V(0.35, 0.3, 0.2), CFrame.new(spots[i]), pr))
	end
	return out
end

P.MT = function(b, rig, entry, look)
	local out = {}
	add(
		out,
		b:mount(
			part(rig, "UpperTorso"),
			"NeckAttachment",
			"ell",
			sized(entry, V(2.5, 0.65, 1.4)),
			C(0, -0.15, 0.05),
			Kit.props("MT", entry, look)
		)
	)
	return out
end

P.CO = function(b, rig, entry, look)
	local out = {}
	local ut = part(rig, "UpperTorso")
	local pr = Kit.props("CO", entry, look)
	if has(entry, "diamond") then
		add(out, b:mount(ut, "BodyFrontAttachment", "block", V(0.35, 0.35, 0.08), C(0, 0.25, -0.05) * rz(45), pr))
	else
		add(out, b:mount(ut, "BodyFrontAttachment", "cyl", V(0.08, 0.4, 0.4), C(0, 0.25, -0.05) * CYL_FWD, pr))
	end
	return out
end

P.BW = function(b, rig, entry, look)
	local out = {}
	local ut = part(rig, "UpperTorso")
	local base = C(0, 0, 0.12) * rz(entry.angle or 35)
	local blade = Kit.props("BW", entry, look)
	local hilt = Kit.props("BW", entry, look, "hilt")
	if has(entry, "pipe") then
		add(out, b:mount(ut, "BodyBackAttachment", "cyl", V(1.6, 0.12, 0.12), base * CYL_UP, blade))
		return out
	end
	if has(entry, "short") then
		add(out, b:mount(ut, "BodyBackAttachment", "block", V(0.1, 1.2, 0.28), base, blade))
		return out
	end
	local len = if has(entry, "katana") then 2.4 else 2.3
	add(out, b:mount(ut, "BodyBackAttachment", "block", V(0.1, len, 0.28), base, blade))
	add(
		out,
		b:mount(ut, "BodyBackAttachment", "cyl", V(0.8, 0.14, 0.14), base * C(0, len / 2 + 0.35, 0) * CYL_UP, hilt)
	)
	if (entry.n or 2) >= 3 then
		add(out, b:mount(ut, "BodyBackAttachment", "block", V(0.5, 0.08, 0.2), base * C(0, len / 2 - 0.02, 0), hilt))
	end
	return out
end

local BA_ORDER = { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }

local function baShape(entry: Entry): (number, number)
	local segs = if type(entry.segs) == "number" then entry.segs else 2
	local arms = math.clamp(math.floor((entry.n or 4 * segs) / segs + 0.5), 1, 4)
	return arms, segs
end

P.BA = function(b, rig, entry, look)
	local out = {}
	local ut = part(rig, "UpperTorso")
	local arms, segs = baShape(entry)
	local pr = Kit.props("BA", entry, look)
	local claw = Kit.props("BA", entry, look, "claw")
	local lens = if segs >= 3 then { 1.4, 0.9, 0.5 } else { 1.4, 1.4 }
	local dias = if segs >= 3 then { 0.22, 0.2 } else { 0.22, 0.22 }
	for a = 1, arms do
		local sx, sy = BA_ORDER[a][1], BA_ORDER[a][2]
		local rot1 = CFrame.Angles(math.rad(30 * sy), 0, math.rad(-sx * (if sy > 0 then 45 else 135)))
		local bones = Kit.chain(V(0.5 * sx, 0.35 * sy, 0.2), { rot1, rz(40 * sx), CFrame.identity }, lens)
		for k = 1, math.min(segs, #lens) do
			if k <= #dias then
				add(out, b:mount(ut, "BodyBackAttachment", "cyl", V(lens[k], dias[k], dias[k]), bones[k] * CYL_UP, pr))
			else
				add(out, b:mount(ut, "BodyBackAttachment", "wedge", V(0.2, 0.5, 0.25), bones[k], claw))
			end
		end
	end
	return out
end

P.TN = function(b, rig, entry, look)
	local out = {}
	local ut = part(rig, "UpperTorso")
	for _, x in tendrilXs(entry.n or 2) do
		add(
			out,
			b:hinge(
				ut,
				"BodyBackAttachment",
				"wedge",
				V(0.2, 1.4, 0.3),
				V(x, -0.2, 0.2),
				rx(-25),
				Kit.props("TN", entry, look),
				{ folder = entry.folder }
			)
		)
	end
	return out
end

P.WG = function(b, rig, entry, look)
	local out = {}
	local ut = part(rig, "UpperTorso")
	local pr = Kit.props("WG", entry, look)
	if has(entry, "wing") then
		for _, s in { -1, 1 } do
			add(
				out,
				b:mount(ut, "BodyBackAttachment", "wedge", V(0.1, 1.6, 1.1), C(s * 0.5, 0.2, 0.2) * rz(-s * 30), pr)
			)
		end
		return out
	end
	local disc = b:mount(ut, "BodyBackAttachment", "cyl", V(0.12, 2.2, 2.2), C(0, 0.1, 0.2) * CYL_FWD, pr)
	if disc then
		b:weldOf(disc).Name = "Glide" -- the client Glide driver (§2.1) finds it by name
		b.model:AddTag("Glide")
		table.insert(out, disc)
	end
	return out
end

P.GL = function(b, rig, entry, look)
	local out = {}
	for _, s in sidesOf(entry, 2, -1) do
		local host = part(rig, LR(s) .. "LowerArm")
		add(
			out,
			b:mount(
				host,
				nil,
				"block",
				sized(entry, V(1.08, 0.5, 1.08)),
				C(0, -0.28, 0),
				Kit.props("GL", entry, look, nil, s)
			)
		)
	end
	return out
end

P.FB = function(b, rig, entry, look)
	local out = {}
	local long = has(entry, "long") or has(entry, "curved")
	for _, s in sidesOf(entry, 2, 1) do
		local host = part(rig, LR(s) .. "LowerArm")
		local size = if long then V(0.08, 1.6, 0.35) else V(0.08, 1.0, 0.3)
		local cf = C(s * 0.52, -0.1, 0) * (if long then rx(15) else CFrame.identity)
		add(out, b:mount(host, nil, "wedge", size, cf, Kit.props("FB", entry, look, nil, s)))
	end
	return out
end

P.MA = function(b, rig, entry, look)
	local out = {}
	local s = sideOf(entry.side) or 1
	local seam = b:mount(
		part(rig, LR(s) .. "LowerArm"),
		nil,
		"block",
		V(0.06, 1.0, 0.06),
		C(s * 0.52, 0, 0),
		Kit.props("MA", entry, look, "seam")
	)
	if seam then
		table.insert(out, seam)
		local arm = Kit.props("MA", entry, look)
		local map = {}
		for _, n in { "UpperArm", "LowerArm", "Hand" } do
			map[LR(s) .. n] = { color = arm.color, material = arm.material, reflectance = arm.reflectance or 0.2 }
		end
		Kit.paintParts(rig.model, map)
	end
	return out
end

P.XA = function(b, rig, entry, look)
	local out = {}
	local ut = part(rig, "UpperTorso")
	for _, s in { -1, 1 } do
		local pr = Kit.props("XA", entry, look, nil, s)
		local upper = C(s * 1.05, -0.55, -0.3) * rx(30) * rz(s * 35)
		add(out, b:mount(ut, nil, "block", V(0.8, 1.1, 0.8), upper, pr))
		-- the forearm bends forward from the elbow ("held forward, palms open")
		add(out, b:mount(ut, nil, "block", V(0.75, 1.2, 0.75), upper * C(0, -0.55, 0) * rx(60) * C(0, -0.6, 0), pr))
	end
	return out
end

P.WR = function(b, rig, entry, look)
	local out = {}
	for _, s in sidesOf(entry, 2, 1) do
		local host = part(rig, LR(s) .. "LowerLeg")
		add(
			out,
			b:mount(
				host,
				nil,
				"block",
				sized(entry, V(1.08, 0.5, 1.08)),
				C(0, -0.2, 0),
				Kit.props("WR", entry, look, nil, s)
			)
		)
	end
	return out
end

P.FS = function(b, rig, entry, look)
	local out = {}
	local s = sideOf(entry.side) or 1
	local hand = part(rig, LR(s) .. "Hand")
	local pr = Kit.props("FS", entry, look)
	add(out, b:mount(hand, nil, "block", V(1.4, 1.0, 1.2), C(0, -0.1, 0), pr))
	add(out, b:mount(hand, nil, "wedge", V(0.35, 0.5, 0.4), C(-s * 0.55, 0.05, -0.35) * rz(s * 20), pr))
	return out
end

P.SD = function(b, rig, entry, _look)
	local out = {}
	local d = 1.2 * (entry.footprint or rig.footprint)
	add(
		out,
		b:mount(
			part(rig, "HumanoidRootPart"),
			nil,
			"cyl",
			V(0.05, d, d),
			C(0, rig.ground + 0.03, 0) * CYL_UP,
			{ color = entry.tint or 0x101014, material = "SmoothPlastic", transparency = 0.6, name = "SD" },
			{ absolute = true, keep = true }
		)
	)
	return out
end

--------------------------------------------------------------------------------
-- Part counts per entry (§2.3); Kit.count falls back to entry.n, Costumes.PARTS, then 1.
--------------------------------------------------------------------------------

local function nOr(d: number): (Entry) -> number
	return function(e: Entry): number
		return if type(e.n) == "number" then e.n else d
	end
end
local function fixed(n: number): (Entry) -> number
	return function(_e: Entry): number
		return n
	end
end

Kit.COUNT = {
	FP = fixed(1),
	HR = fixed(1),
	["HR·s"] = nOr(3),
	["HR·w"] = function(e: Entry): number
		if e.x == 0 or has(e, "crest") then
			return 1
		end
		return #sidesOf(e, 2, 1)
	end,
	["HR·p"] = function(e: Entry): number
		return if (e.n or 1) > 1 then 2 else 1
	end,
	["HR·f"] = fixed(1),
	["HR·k"] = fixed(1),
	["HR·t"] = function(e: Entry): number
		return #sidesOf(e, 2, 1)
	end,
	HB = fixed(1),
	["HB·t"] = fixed(2),
	VB = fixed(1),
	["VB·m"] = fixed(1),
	LM = fixed(1),
	CK = fixed(1),
	FM = function(e: Entry): number
		return if isSlit(e) then 2 else 3
	end,
	BK = fixed(1),
	HD = fixed(3),
	["HD·d"] = fixed(1),
	HN = fixed(2),
	EP = function(e: Entry): number
		if has(e, "fin") or (e.n == 1 and not has(e, "ear")) then
			return 1
		end
		return #sidesOf(e, 2, 1)
	end,
	EC = fixed(1),
	GG = fixed(2),
	HP = fixed(2),
	CR = nOr(4),
	OR = nOr(3),
	SC = fixed(2),
	SG = function(e: Entry): number
		return #sidesOf(e, 2, -1)
	end,
	HC = fixed(1),
	LP = fixed(2),
	VS = fixed(1),
	EM = fixed(1),
	CT = fixed(2),
	CP = fixed(1),
	SB = function(e: Entry): number
		return 1 + (if e.tail then 1 else 0) + pouchesOf(e)
	end,
	MT = fixed(1),
	CO = fixed(1),
	BW = function(e: Entry): number
		if has(e, "pipe") or has(e, "short") then
			return 1
		end
		return if (e.n or 2) >= 3 then 3 else 2
	end,
	BA = function(e: Entry): number
		local arms, segs = baShape(e)
		return arms * math.min(segs, 3)
	end,
	TN = nOr(2),
	WG = function(e: Entry): number
		return if has(e, "wing") then 2 else 1
	end,
	GL = function(e: Entry): number
		return #sidesOf(e, 2, -1)
	end,
	FB = function(e: Entry): number
		return #sidesOf(e, 2, 1)
	end,
	MA = fixed(1),
	XA = fixed(4),
	WR = function(e: Entry): number
		return #sidesOf(e, 2, 1)
	end,
	FS = fixed(2),
	SD = fixed(1),
} :: { [string]: (Entry) -> number }

--- Parts an entry adds when mounted whole.
function Kit.count(entry: Entry): number
	local code = codeOf(entry)
	local f = Kit.COUNT[code]
	if f then
		return f(entry)
	end
	if code == "Prop" then
		return if type(entry.max) == "number" then entry.max else 0
	end
	if type(entry.n) == "number" then
		return entry.n
	end
	if type(Costumes.entryParts) == "function" then
		local ok, v = pcall(Costumes.entryParts, entry)
		if ok and type(v) == "number" then
			return v
		end
	end
	local parts = Costumes.PARTS
	local v = if type(parts) == "table" then parts[code] else nil
	return if type(v) == "number" then v else 1
end

--------------------------------------------------------------------------------
-- Entries and whole builds
--------------------------------------------------------------------------------

--- entry.gui, entry.emblem (on pieces other than EM and SC), entry.flash and entry.fx.
function Kit.decorate(b: Builder, rig: Rig, entry: Entry, look: Look?, parts: { BasePart })
	local code = codeOf(entry)
	if #parts == 0 then
		return
	end
	if type(entry.gui) == "table" then
		Kit.gui(parts, entry.gui, look, code)
	end
	if type(entry.emblem) == "string" and code ~= "EM" and code ~= "SC" then
		Kit.emblem(parts[1], entry.emblem, { stroke = entry.emblemColor or entry.accent or slotColor("sig", look) })
	end
	if type(entry.flash) == "number" then
		for _, p in parts do
			p:SetAttribute("Flash", Palette.color(entry.flash))
		end
	end
	if type(entry.fx) == "string" then
		local color = entry.fxColor
		if color == nil and entry.fx == "drip" then
			color = slotColor("sig", look)
		end
		for _, e in Kit.fx(rig, entry.fx, entry.fxAt, parts[1], color) do
			if e.Parent and not e.Parent:IsDescendantOf(b.folder) then
				b:track(e.Parent)
			end
		end
	end
end

--- Mounts one kit entry whole or not at all, at `tier`. Unknown codes are logged as missing.
function Kit.mountEntry(b: Builder, rig: Rig, entry: Entry, look: Look?, tier: any): boolean
	local code = codeOf(entry)
	local fn = P[code]
	b.code = code
	if not fn then
		table.insert(
			b.log,
			{ tier = tostring(tier), code = code, count = 0, mounted = false, parts = 0, missing = true }
		)
		return false
	end
	return b:entry(tier, function()
		local parts = fn(b, rig, entry, look or {})
		Kit.decorate(b, rig, entry, look, parts)
	end, Kit.count(entry))
end

--- A kit item as a plain STYLE entry. effectiveLook's kit items ({code, entry, tint, accent, ...})
--- become the raw entry with the effective tint (darkened for a character boss) and any
--- explicit accent.
function Kit.entryOf(item: any): Entry
	if type(item) == "table" and type(item.entry) == "table" then
		local e = table.clone(item.entry)
		if type(item.tint) == "number" then
			e.tint = item.tint
		end
		if type(item.accent) == "number" and item.entry.accent ~= nil then
			e.accent = item.accent
		end
		return e
	end
	return item
end

local TIER_RANK: { [string]: number } = { ["0"] = 1, ["1"] = 2, W = 3, R = 4, L = 5, D = 6 }
Kit.TIER_RANK = TIER_RANK

export type BuildOpts = {
	budget: number?, -- FP + markers + kit (default 14, §6.3)
	reserve: number?, -- parts held back (default 2 for suitTN styles, §2.6)
	role: string?, -- "player" (default) | "ally" | "charBoss" | "normal" | "alpha" | "elite" ...
	style: Look?, -- the STYLE entry, when `look` does not carry kit/face/guis itself
	styleId: string?,
	markers: { { count: number, fn: (Builder, Rig) -> (), code: string? } }?, -- tier 1 (§4.5)
	face: FaceOpts?, -- overrides for Kit.face (irisScale, iris ...)
}

--- Builds FP and the face, markers, then the kit entries by tier with whole-entry trimming
--- (§2.1): for players every entry after sigPiece is tier D, the rest R. Then the 0-part
--- SurfaceGuis, the chest maw, style emitters and STYLE.paint. Returns the parts used.
function Kit.build(model: Model, look: Look, opts: BuildOpts?): (number, Builder)
	local o: BuildOpts = opts or {}
	local styles = if type(Costumes.STYLE) == "table" then Costumes.STYLE else {}
	local style: Look = o.style or styles[o.styleId or ""] or styles[look.styleId or ""] or look
	local kit: { Entry } = {}
	for _, item in (look.kit or style.kit or {}) :: { any } do
		table.insert(kit, Kit.entryOf(item))
	end
	local role = o.role or "player"
	local reserve = o.reserve or (if style.suitTN then 2 else 0)
	local old = model:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d.Name == "CostumeFx" and d:IsA("Attachment") then
			d:Destroy()
		end
	end
	local b = Kit.new(model, (o.budget or 14) - reserve)
	local rig = Kit.rig(model)
	rig.look = look
	rig.role = role
	local fpEntry: Entry = { "FP" }
	for _, e in kit do
		local code = codeOf(e)
		rig.worn[code] = true
		if code == "FP" then
			fpEntry = e
		end
	end
	local masked = rig.worn.FM or rig.worn.HD

	-- tier 0: FP and the face
	local fp: BasePart? = nil
	b.code = "FP"
	b:entry(0, function()
		fp = P.FP(b, rig, fpEntry, look)[1]
	end, 1)
	if fp then
		local cols = colorsOf(look)
		local face = if type(style.face) == "table" then style.face else {}
		local ckMask = false
		for _, e in kit do
			if codeOf(e) == "CK" and (e.mask or has(e, "mask")) then
				ckMask = true
			end
		end
		-- effectiveLook carries marks as {color, mark}: the mark with its effective colour
		local marks: { any } = {}
		for _, m in (if type(look.marks) == "table" then look.marks else face.marks or {}) :: { any } do
			if type(m) == "table" and type(m.mark) == "table" then
				local mk = table.clone(m.mark)
				mk.color = m.color
				table.insert(marks, mk)
			else
				table.insert(marks, m)
			end
		end
		local fo: FaceOpts = {
			friend = role == "player" or role == "ally",
			eye = cols.eye,
			brow = cols.brow,
			browAngle = style.browAngle,
			glow = look.glow or face.glow or cols.sig,
			iris = look.faceGlow or (if role == "charBoss" then cols.sig else nil),
			marks = marks,
			hideEyes = face.hideEyes == true or rig.worn.FM == true,
			mouth = not (rig.worn.LM or rig.worn.FM or rig.worn.BK or ckMask),
		}
		for key, v in (o.face or {}) :: { [string]: any } do
			(fo :: any)[key] = v
		end
		Kit.face(model, fp, fo)
	end

	-- tier 1: markers
	local markers: { { count: number, fn: (Builder, Rig) -> (), code: string? } } = o.markers or {}
	for _, m in markers do
		b.code = m.code or "marker"
		b:entry(1, function()
			m.fn(b, rig)
		end, m.count)
	end

	-- kit entries by tier, listed order within a tier
	local sigIndex: number? = nil
	if type(style.sigPiece) == "string" then
		for i, e in kit do
			if codeOf(e) == style.sigPiece then
				sigIndex = i
				break
			end
		end
	end
	local queue = {}
	for i, e in kit do
		local code = codeOf(e)
		local hair = string.sub(code, 1, 2) == "HR" or code == "FLT" or code == "TIP"
		if code ~= "FP" and not (masked and hair) then
			local tier = e.tier or (if sigIndex and i > sigIndex then "D" else "R")
			table.insert(queue, { i = i, e = e, tier = tostring(tier) })
		end
	end
	table.sort(queue, function(a, c)
		local ra, rc = TIER_RANK[a.tier] or 4, TIER_RANK[c.tier] or 4
		if ra ~= rc then
			return ra < rc
		end
		return a.i < c.i
	end)
	for _, q in queue do
		Kit.mountEntry(b, rig, q.e, look, q.tier)
	end

	-- 0-part extras
	for _, spec in (if type(style.guis) == "table" then style.guis else {}) :: { any } do
		local hosts: { BasePart } = {}
		local names = if type(spec.parts) == "table" then spec.parts else { spec.host or "UpperTorso" }
		for _, n in names do
			local p = rig.parts[n]
			if p then
				table.insert(hosts, p)
			end
		end
		for _, p in hosts do
			local s = table.clone(spec)
			s.side = nil
			Kit.gui({ p }, s, look, nil)
		end
	end
	local face = if type(style.face) == "table" then style.face else nil
	if face and type(face.maw) == "table" then
		Kit.maw(model, look, face.maw)
	end
	for _, em in (if type(style.emitters) == "table" then style.emitters else {}) :: { any } do
		local key = if type(em) == "string" then em else em.key or em[1]
		if type(key) == "string" then
			local color = if type(em) == "table" then em.color else nil
			if color == nil and key == "drip" then
				color = colorsOf(look).sig
			end
			Kit.fx(rig, key, if type(em) == "table" then em.at else nil, nil, color)
		end
	end
	Kit.paintParts(model, look.paint or style.paint)
	return b.used, b
end

-- stage-2 pieces register themselves (an installer, so there is no recursive require)
require(script.Bespoke)(Kit)

return Kit
