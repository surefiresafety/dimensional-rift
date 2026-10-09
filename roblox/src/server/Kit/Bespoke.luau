--!strict
-- Kit/Bespoke: the §3.1 bespoke pieces and the §2.6 props (docs/design/characters.md).
--
-- This module returns an installer, `install(Kit)`, which Kit/init.luau calls at its end
-- (`require(script.Bespoke)(Kit)`). A plain `require(script.Parent)` from here would be a
-- recursive require (Roblox errors on those), so Kit hands itself in instead. Installing
-- twice is a no-op. It adds:
--   Kit.PIECES / Kit.COUNT for HAT FTH CLP LF BLM ORB WSP SHD VL TIE WCH BLD HMR FLT CN MZ
--     STF TIP PLT SEAM TSL EDG CRY SPL SM and Prop
--   Kit.prop(character, styleId, weaponKey, role?) -> { BasePart }   (§2.6, at most 3 parts)
--   Kit.suitTN(character, on, look?) -> { BasePart }                (§2.6 symbiote suit, 2 TN)
--   Kit.propParts(styleId, key) -> number
-- The Prop kit entry mounts `entry.key`, else the model attribute "Weapon", else
-- STYLE[styleId].props.default.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Palette)

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

type Entry = { [any]: any }
type Look = { [string]: any }
type Rig = { [string]: any }

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
local CYL_UP = CFrame.Angles(0, 0, math.pi / 2)
local CYL_FWD = CFrame.Angles(0, math.pi / 2, 0)

local function part(rig: Rig, name: string): BasePart
	local p = rig.parts[name]
	if not p then
		error("Kit: the rig has no " .. name, 0)
	end
	return p
end

local function add(out: { BasePart }, p: BasePart?): BasePart?
	if p then
		table.insert(out, p)
	end
	return p
end

local function LR(s: number): string
	return if s < 0 then "Left" else "Right"
end

local function isBoss(look: Look?): boolean
	return type(look) == "table" and look.role == "charBoss"
end

local function shade(c: number): number
	if type(Costumes.bossShade) == "function" then
		return Costumes.bossShade(c)
	end
	return c
end

local function toInt(c: Color3): number
	return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
end

return function(Kit: any)
	if Kit.__bespoke then
		return Kit
	end
	Kit.__bespoke = true

	local P: { [string]: any } = Kit.PIECES
	local COUNT: { [string]: any } = Kit.COUNT

	local function fixed(n: number): (Entry) -> number
		return function(_e: Entry): number
			return n
		end
	end
	local function nOr(d: number): (Entry) -> number
		return function(e: Entry): number
			return if type(e.n) == "number" then e.n else d
		end
	end

	--- Kit.props, with a character boss's shade applied to raw sub and side colours
	--- (effectiveLook already shades entry.tint and entry.accent).
	local function props(code: string, entry: Entry, look: Look, sub: string?, side: number?): { [string]: any }
		local p = Kit.props(code, entry, look, sub, side)
		if isBoss(look) and p.material ~= "Neon" and type(p.color) == "number" then
			local tints = if type(entry.tints) == "table" then entry.tints else {}
			local raw = false
			if sub then
				raw = not (tints[sub] == nil and type(entry.accent) == "number")
			elseif side then
				raw = type(tints[if side < 0 then "L" else "R"]) == "number"
			end
			if raw then
				p.color = shade(p.color)
			end
		end
		return p
	end

	-- one piece at a fixed spot
	local function single(code: string, host: string, attach: string?, kind: string, size: Vector3, cf: CFrame)
		P[code] = function(b, rig, entry, look)
			local out = {}
			add(out, b:mount(part(rig, host), attach, kind, size, cf, props(code, entry, look)))
			return out
		end
		COUNT[code] = fixed(1)
	end

	-- a mirrored pair: cf(s) with s = -1 for the character's left
	local function pair(
		code: string,
		host: (number) -> string,
		attach: ((number) -> string?)?,
		kind: string,
		size: Vector3,
		cf: (number) -> CFrame
	)
		P[code] = function(b, rig, entry, look)
			local out = {}
			for _, s in { -1, 1 } do
				local a = if attach then attach(s) else nil
				add(out, b:mount(part(rig, host(s)), a, kind, size, cf(s), props(code, entry, look, nil, s)))
			end
			return out
		end
		COUNT[code] = fixed(2)
	end

	local function orbiting(
		b: any,
		p: BasePart?,
		axis: Vector3,
		rate: number,
		phase: number,
		center: Vector3,
		name: string
	)
		if p then
			b:orbit(axis, rate, phase, center, name, p)
		end
	end

	-- HAT: brim, crown, band (Top Hat)
	P.HAT = function(b, rig, entry, look)
		local out = {}
		local head = part(rig, "Head")
		add(out, b:mount(head, nil, "cyl", V(0.08, 1.55, 1.55), C(0, 0.64, 0) * CYL_UP, props("HAT", entry, look, "b")))
		add(out, b:mount(head, nil, "cyl", V(1.0, 0.95, 0.95), C(0, 1.14, 0) * CYL_UP, props("HAT", entry, look, "c")))
		add(out, b:mount(head, nil, "cyl", V(0.15, 0.97, 0.97), C(0, 0.72, 0) * CYL_UP, props("HAT", entry, look, "n")))
		return out
	end
	COUNT.HAT = fixed(3)

	-- FTH: feathers rising from the mantle, tops back and out
	pair(
		"FTH",
		function()
			return "UpperTorso"
		end,
		function()
			return "NeckAttachment"
		end,
		"wedge",
		V(0.1, 0.6, 0.25),
		function(s)
			return C(s * 0.45, 0.25, 0.45) * rx(20) * rz(-s * 15)
		end
	)

	single("CLP", "Head", nil, "wedge", V(0.08, 0.25, 0.12), C(-0.44, 0.22, -0.67))
	single("LF", "Head", nil, "wedge", V(0.1, 0.4, 0.3), C(0.56, 0.92, 0) * rz(-40))
	single("BLM", "LeftUpperArm", "LeftShoulderAttachment", "ball", V(0.45, 0.45, 0.45), C(-0.05, 0.38, 0))

	P.ORB = function(b, rig, entry, look)
		local out = {}
		local p = add(
			out,
			b:mount(
				part(rig, "UpperTorso"),
				nil,
				"ball",
				V(0.5, 0.5, 0.5),
				C(-1.3, 1.3, 0.4),
				props("ORB", entry, look)
			)
		)
		orbiting(b, p, V(0, 1, 0), 0.6, 0, V(-1.1, 1.3, 0.4), "orb")
		return out
	end
	COUNT.ORB = fixed(1)

	P.WSP = function(b, rig, entry, look)
		local out = {}
		local p = add(
			out,
			b:mount(part(rig, "UpperTorso"), nil, "ball", V(0.5, 0.5, 0.5), C(1.2, 1.2, 0.7), props("WSP", entry, look))
		)
		orbiting(b, p, V(0, 1, 0), 0.6, 0.5, V(1.0, 1.2, 0.7), "wisp")
		return out
	end
	COUNT.WSP = fixed(1)

	-- SHD: 4 basalt shards on a ring behind the shoulders, joined by 4 Beams
	P.SHD = function(b, rig, entry, look)
		local out = {}
		local ut = part(rig, "UpperTorso")
		local center = V(0, 0.4, 1.1)
		for i = 0, 3 do
			local cf = CFrame.new(center) * rz(90 * i) * C(0, 0.9, 0)
			local p = add(out, b:mount(ut, nil, "corner", V(0.35, 0.6, 0.35), cf, props("SHD", entry, look)))
			orbiting(b, p, V(0, 0, 1), 0.15, 0, center, "shd" .. i)
		end
		if #out == 4 then
			local tints = if type(entry.tints) == "table" then entry.tints else {}
			local accent = Costumes.DEFAULT_ACCENT and Costumes.DEFAULT_ACCENT.SHD
			local col = tints.beam or entry.accent or (accent and accent.color) or 0x8a6cff
			local atts = {}
			for i, p in out do
				local a = Instance.new("Attachment")
				a.Name = "SHD_A"
				a.Parent = p
				atts[i] = a
			end
			for i, p in out do
				local beam = Instance.new("Beam")
				beam.Name = "SHD_Beam"
				beam.Attachment0 = atts[i]
				beam.Attachment1 = atts[i % 4 + 1]
				beam.Width0 = 0.06
				beam.Width1 = 0.06
				beam.FaceCamera = true
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Color = ColorSequence.new(Palette.color(col))
				beam.Transparency = NumberSequence.new(0.2)
				beam.Parent = p
			end
		end
		return out
	end
	COUNT.SHD = fixed(4)

	pair(
		"VL",
		function(s)
			return LR(s) .. "LowerArm"
		end,
		nil,
		"cyl",
		V(0.4, 0.14, 0.14),
		function(s)
			return C(s * 0.61, -0.28, 0) * CYL_UP
		end
	)

	single("TIE", "UpperTorso", nil, "block", V(0.25, 0.9, 0.05), C(0, 0.17, -0.53))
	single("WCH", "LeftLowerArm", nil, "cyl", V(0.08, 0.3, 0.3), C(-0.54, -0.4, 0))
	single("BLD", "UpperTorso", "BodyBackAttachment", "block", V(0.14, 2.0, 0.35), C(0, 0, 0.12) * rz(35))

	P.HMR = function(b, rig, entry, look)
		local out = {}
		local lt = part(rig, "LowerTorso")
		local base = C(0.45, -0.1, 0.6) * rz(20)
		add(out, b:mount(lt, nil, "cyl", V(1.1, 0.1, 0.1), base * CYL_UP, props("HMR", entry, look, "s")))
		add(out, b:mount(lt, nil, "block", V(0.5, 0.3, 0.3), base * C(0, 0.65, 0.05), props("HMR", entry, look, "h")))
		return out
	end
	COUNT.HMR = fixed(2)

	single("FLT", "Head", nil, "block", V(1.1, 0.3, 1.1), C(0, 0.75, 0.06))
	single("CN", "UpperTorso", nil, "cyl", V(1.6, 0.7, 0.7), C(1.0, 1.15, 0.1) * CYL_FWD)
	single("MZ", "UpperTorso", nil, "cyl", V(0.1, 0.6, 0.6), C(1.0, 1.15, -0.75) * CYL_FWD)
	single("STF", "UpperTorso", "BodyBackAttachment", "cyl", V(5.0, 0.16, 0.16), C(0, -0.2, 0.2) * rz(35) * CYL_UP)
	single("TIP", "Head", nil, "block", V(1.08, 0.3, 0.32), C(0, -1.15, 0.62))

	pair(
		"PLT",
		function(s)
			return LR(s) .. "UpperArm"
		end,
		function(s)
			return LR(s) .. "ShoulderAttachment"
		end,
		"block",
		V(0.9, 0.25, 1.0),
		function(s)
			return C(s * 0.05, 0.12, 0) * rz(-s * 15)
		end
	)

	single("SEAM", "UpperTorso", nil, "block", V(0.08, 1.4, 0.05), C(0.2, -0.05, -0.53))

	pair(
		"TSL",
		function()
			return "LowerTorso"
		end,
		function()
			return "WaistFrontAttachment"
		end,
		"cyl",
		V(0.9, 0.12, 0.12),
		function(s)
			return C(s * 0.35, -0.5, -0.05) * CYL_UP
		end
	)

	single("EDG", "UpperTorso", "NeckAttachment", "block", V(1.3, 0.06, 0.06), C(0, -0.15, -0.67))

	P.CRY = function(b, rig, entry, look)
		local out = {}
		local head = part(rig, "Head")
		local n = if type(entry.n) == "number" then entry.n else 3
		for k = 0, n - 1 do
			local p = add(
				out,
				b:mount(
					head,
					nil,
					"wedge",
					V(0.12, 0.4, 0.2),
					ry(360 / n * k) * C(0, 0.6, -0.9),
					props("CRY", entry, look)
				)
			)
			orbiting(b, p, V(0, 1, 0), 0.2, 0, Vector3.zero, "cry" .. k)
		end
		return out
	end
	COUNT.CRY = nOr(3)

	pair(
		"SPL",
		function(s)
			return LR(s) .. "LowerArm"
		end,
		nil,
		"cyl",
		V(0.5, 0.3, 0.3),
		function(s)
			return C(s * 0.56, -0.25, 0) * CYL_UP
		end
	)

	P.SM = function(b, rig, entry, look)
		local out = {}
		for _, limb in { "LowerArm", "LowerLeg" } do
			for _, s in { -1, 1 } do
				add(
					out,
					b:mount(
						part(rig, LR(s) .. limb),
						nil,
						"block",
						V(0.06, 1.0, 0.06),
						C(s * 0.52, 0, 0),
						props("SM", entry, look)
					)
				)
			end
		end
		return out
	end
	COUNT.SM = fixed(4)

	-- BLD's grip wrap belongs on the face away from the body
	local GUI_FACE: { [string]: string } = { BLD = "Back" }
	local decorate = Kit.decorate
	Kit.decorate = function(b: any, rig: Rig, entry: Entry, look: Look?, parts: { BasePart })
		local face = GUI_FACE[Kit.codeOf(entry)]
		if face and type(entry.gui) == "table" and entry.gui.face == nil then
			local e = table.clone(entry)
			local g = table.clone(entry.gui)
			g.face = face
			e.gui = g
			entry = e
		end
		return decorate(b, rig, entry, look, parts)
	end

	----------------------------------------------------------------------------
	-- Props (§2.6)
	----------------------------------------------------------------------------

	local TOP_ROLES = { hilt = true, grip = true, warhead = true, sickle = true }
	local OVERLAP = 0.05

	local function specOf(styleId: string?, key: string?): { [string]: any }?
		local all = Costumes.ARSENAL_PROP
		local s = if type(all) == "table" and styleId then all[styleId] else nil
		return if s and key then s[key] else nil
	end

	--- Parts the prop mounts (0 for the suit keys without pieces and for `fists`).
	function Kit.propParts(styleId: string, key: string): number
		local spec = specOf(styleId, key)
		return if spec and type(spec.pieces) == "table" then #spec.pieces else 0
	end

	local function lengthOf(kind: string, size: Vector3, role: string): number
		if role == "stock" then
			return size.Z
		end
		return if kind == "cyl" or kind == "ball" then size.X else size.Y
	end
	local function turnOf(kind: string, role: string): CFrame
		if role == "stock" then
			return rx(90)
		end
		return if kind == "cyl" then CYL_UP else CFrame.identity
	end

	local function tintGloves(model: Model, color: number?, boss: boolean)
		local costume = model:FindFirstChild("Costume")
		if not costume then
			return
		end
		for _, p in costume:GetChildren() do
			if p:IsA("BasePart") and p.Name == "GL" then
				local base = p:GetAttribute("BaseColor")
				if typeof(base) ~= "Color3" then
					base = p.Color
					p:SetAttribute("BaseColor", base)
				end
				p.Color = if color then Palette.color(if boss then shade(color) else color) else base :: Color3
			end
		end
	end

	--- Lays the pieces end to end along the prop's +Y (§2.6): grips, hilts and heads on top,
	--- a stock below, a scope alongside. Returns local frames in data order.
	local function layout(pieces: { any }): { CFrame }
		local hasShaft = false
		for _, pc in pieces do
			if pc.role == "shaft" or pc.role == "handle" then
				hasShaft = true
			end
		end
		local mains, tops, bottoms, sides = {}, {}, {}, {}
		for i, pc in pieces do
			local role = tostring(pc.role)
			if role == "stock" then
				table.insert(bottoms, i)
			elseif role == "scope" then
				table.insert(sides, i)
			elseif TOP_ROLES[role] or (role == "blade" and hasShaft) then
				table.insert(tops, i)
			else
				table.insert(mains, i)
			end
		end
		if #mains == 0 and #tops > 0 then
			table.insert(mains, table.remove(tops, 1) :: number)
		end
		local frames: { CFrame } = {}
		local function info(i: number): (string, Vector3, string, number)
			local pc = pieces[i]
			local size = Kit.toV3(pc.size) or Vector3.one
			local role = tostring(pc.role)
			return pc.kind, size, role, lengthOf(pc.kind, size, role)
		end
		local total = 0
		for _, i in mains do
			total += select(4, info(i))
		end
		local y = -total / 2
		for _, i in mains do
			local kind, _, role, len = info(i)
			frames[i] = C(0, y + len / 2, 0) * turnOf(kind, role)
			y += len
		end
		local top = total / 2
		for _, i in tops do
			local kind, size, role, len = info(i)
			local c = top + len / 2 - OVERLAP
			local z = if role == "sickle" then size.Z / 2 - OVERLAP else 0
			frames[i] = C(0, c, z) * turnOf(kind, role)
			top = c + len / 2
		end
		local bottom = -total / 2
		for _, i in bottoms do
			local kind, _, role, len = info(i)
			local c = bottom - len / 2 + OVERLAP
			frames[i] = C(0, c, 0) * turnOf(kind, role)
			bottom = c - len / 2
		end
		local mainDia = 0.1
		if mains[1] then
			local kind, size = info(mains[1])
			mainDia = if kind == "cyl" then size.Y else size.Z
		end
		for _, i in sides do
			local kind, size, role = info(i)
			frames[i] = C(0, total * 0.1, mainDia / 2 + size.Y / 2) * turnOf(kind, role)
		end
		return frames
	end

	local function band(p: BasePart, color: number)
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local g = Instance.new("SurfaceGui")
			g.Name = "Band"
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 100
			g.MaxDistance = 120
			g.Adornee = p
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = Palette.color(color)
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
			f.Parent = g
			g.Parent = p
		end
	end

	--- Mounts ARSENAL_PROP[styleId][key] into Costume/Prop through builder `b`.
	local function mountProp(b: any, rig: Rig, styleId: string?, key: string?, look: Look?): { BasePart }
		local out: { BasePart } = {}
		local spec = specOf(styleId, key)
		local boss = isBoss(look) or rig.role == "charBoss"
		tintGloves(rig.model, if spec then spec.glTint else nil, boss)
		if not spec or type(spec.pieces) ~= "table" then
			return out
		end
		local h = spec.host or {}
		local host = part(rig, h.part or "UpperTorso")
		local attach: string? = h.attach
		local hostPos = Kit.toV3(h.pos) or Vector3.zero
		local base = CFrame.new(hostPos) * rz(h.rz or 0)
		local frames = layout(spec.pieces)
		for i, pc in spec.pieces do
			local cf = frames[i]
			if type(pc.cf) == "table" then
				local rot = if pc.cf.rot == "CYL_FWD"
					then CYL_FWD
					elseif pc.cf.rot == "CYL_UP" then CYL_UP
					else CFrame.identity
				cf = CFrame.new(Kit.toV3(pc.cf.pos) or Vector3.zero) * rot
			else
				cf = base * cf
			end
			local color = pc.tint or Costumes.STEEL or 0x9aa4b0
			if boss and pc.material ~= "Neon" then
				color = shade(color)
			end
			local p = b:mount(
				host,
				if type(pc.cf) == "table" then nil else attach,
				pc.kind,
				Kit.toV3(pc.size) or Vector3.one,
				cf,
				{ color = color, material = pc.material or "Metal", name = "Prop·" .. tostring(pc.role) },
				{ folder = "Prop" }
			)
			if p then
				table.insert(out, p)
				if type(pc.band) == "number" then
					band(p, pc.band)
				end
			end
		end
		-- the chain (0 parts): from the main piece's lower end to the belt
		if type(spec.beam) == "table" and out[1] then
			local main = out[1]
			local weld = main:FindFirstChildOfClass("Weld")
			if weld then
				local k = Kit.scaleOf(host)
				local belt = if host.Name == "UpperTorso" then V(0.4, -1.0, 0.55) else V(0.3, 0, 0.55)
				local endLocal = if main:IsA("Part") and main.Shape == Enum.PartType.Cylinder
					then V(-main.Size.X / 2, 0, 0)
					else V(0, -main.Size.Y / 2, 0)
				local a0 = Instance.new("Attachment")
				a0.Name = "Chain0"
				a0.Position = endLocal
				a0.Parent = main
				local a1 = Instance.new("Attachment")
				a1.Name = "Chain1"
				a1.CFrame = weld.C0:Inverse() * CFrame.new(belt * k)
				a1.Parent = main
				local beam = Instance.new("Beam")
				beam.Name = "Chain"
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.CurveSize0 = -0.4
				beam.CurveSize1 = 0.4
				beam.Width0 = 0.06
				beam.Width1 = 0.06
				beam.Segments = 10
				beam.FaceCamera = true
				beam.Color = ColorSequence.new(Palette.color(spec.beam.color or Costumes.STEEL or 0x9aa4b0))
				beam.Parent = main
			end
		end
		return out
	end

	local function styleIdOf(entry: Entry, look: Look?): string?
		if type(entry.style) == "string" then
			return entry.style
		end
		if type(look) == "table" and type(look.styleId) == "string" then
			return look.styleId
		end
		local styles = Costumes.STYLE
		if type(styles) == "table" and type(look) == "table" then
			for id, st in styles do
				if st == look then
					return id
				end
			end
		end
		return nil
	end

	P.Prop = function(b, rig, entry, look)
		local styleId = styleIdOf(entry, look)
		local key = entry.key
		if key == nil and type(look) == "table" then
			key = look.weapon
		end
		if key == nil then
			local w = rig.model:GetAttribute("Weapon")
			key = if type(w) == "string" then w else nil
		end
		if key == nil and styleId and type(Costumes.STYLE) == "table" then
			local st = Costumes.STYLE[styleId]
			key = st and st.props and st.props.default
		end
		return mountProp(b, rig, styleId, key, look)
	end
	COUNT.Prop = function(e: Entry): number
		return if type(e.max) == "number" then e.max else 3
	end

	--- §2.6 weapon swap: destroys Costume/Prop and mounts the new prop (at most 3 parts).
	--- `fists` recolours the GL tape instead; other keys restore it.
	function Kit.prop(character: Model, styleId: string, key: string?, role: string?): { BasePart }
		local costume = character:FindFirstChild("Costume")
		local old = costume and costume:FindFirstChild("Prop")
		if old then
			old:Destroy()
		end
		local b = Kit.new(character, 3)
		local rig = Kit.rig(character)
		rig.role = role
		b.code = "Prop"
		local parts: { BasePart } = {}
		b:entry("D", function()
			parts = mountProp(b, rig, styleId, key, { role = role })
		end, math.min(Kit.propParts(styleId, key or ""), 3))
		return parts
	end

	--- §2.6 symbiote suit: mounts (on) or destroys (off) Costume/SuitTN, 2 TN parts.
	--- `look` is an effectiveLook, a styleId, or nil (the TN then take the UpperTorso colour).
	function Kit.suitTN(character: Model, on: boolean, look: any?): { BasePart }
		local costume = character:FindFirstChild("Costume")
		local old = costume and costume:FindFirstChild("SuitTN")
		if not on then
			if old then
				old:Destroy()
			end
			return {}
		end
		if old then
			local kept = {}
			for _, d in old:GetChildren() do
				if d:IsA("BasePart") then
					table.insert(kept, d)
				end
			end
			if #kept == 2 then
				return kept
			end
			old:Destroy()
		end
		local lk: Look = {}
		if type(look) == "table" then
			lk = look
		elseif type(look) == "string" and type(Costumes.effectiveLook) == "function" then
			lk = Costumes.effectiveLook(look, "player")
		else
			local ut = character:FindFirstChild("UpperTorso")
			if ut and ut:IsA("BasePart") then
				lk = { colors = { top = toInt(ut.Color) } }
			end
		end
		local b = Kit.new(character, 2)
		local rig = Kit.rig(character)
		b.code = "TN"
		local parts: { BasePart } = {}
		b:entry("R", function()
			parts = Kit.PIECES.TN(b, rig, { "TN", n = 2, folder = "SuitTN" }, lk)
		end, 2)
		return parts
	end

	return Kit
end
