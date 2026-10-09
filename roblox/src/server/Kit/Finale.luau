--!strict
-- Finale bosses (docs/design/characters.md §5): BUILDERS.hyakunui, BUILDERS.tempest_fox and
-- BUILDERS.the_unbidden, plus the Hyakunui phase looks (§6.2 Looks.finalePhase), the Tempest
-- Fox tell attribute (§5.2) and the Unbidden's Adapted_ look (§5.3).
--
--   Finale.dress(model, enemyId, opts?) -> (partsUsed, Builder)
--       opts = { t?, pal?, ally? (Unbidden ward: cyan collar + friend slit), budget? }
--       The model is the walker built from Finale.BODY[id] (preset, scales, six colours).
--   Finale.BUILDERS[builder](b, rig, t, pal, opts)
--   Finale.phase(model, phase)            Hyakunui phase 1..3 (monotonic, idempotent)
--   Finale.setTell(model, on)             sets the "Tell" attribute (client reads it)
--   Finale.tellAction(action) -> boolean? "tell" -> true; "endLunge"/"cancel"/"death" -> false
--   Finale.adapt(model, nature)           lights that nature's collar tile + plate trim
--   Finale.applyAdapted(model)            re-reads every Adapted_<nature> attribute
--   Finale.watch(model) -> RBXScriptConnection?  AttributeChanged -> applyAdapted

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent) :: any
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Costumes = require(Shared.Costumes) :: any
local FinaleData = require(Shared.Finale) :: any
local RulesData = require(Shared.Data.Rules) :: any

local Finale = {}

local V = Vector3.new
local C = CFrame.new
local rx, rz = Kit.rx, Kit.rz

local STITCH = 0xff2d55
local EMBER = 0xff8a3d
local SLATE = 0x3a4250
local BONE = 0xe8e4dc

-- Hyakunui phase-2 tear colours. The design's right colour 0xd9d4cc is within RGB 17 of
-- mahito's 0xd8e0d8 (test 5b), so the right patch tears to a warm bone instead.
Finale.TEAR = { left = 0xff8a3d, right = 0xe0c8a8 }

--- Walker descriptions for stage 3 (§5): preset, scale overrides, the six colours.
Finale.BODY = {
	hyakunui = {
		preset = "towering",
		colors = {
			Head = 0xe8d8c0,
			Torso = 0x3a2e2a,
			LeftArm = 0xe8d8c0,
			RightArm = 0x8a6244,
			LeftLeg = 0x1a1622,
			RightLeg = 0x6a3a4a,
		},
		budget = 14,
	},
	tempest_fox = { preset = "standard", heightScale = 0.7, hidden = true, colors = {}, budget = 14 },
	the_unbidden = {
		preset = "towering",
		widthScale = 1.2,
		depthScale = 0.9,
		headScale = 0.8,
		material = "SmoothPlastic",
		colors = {
			Head = 0xd9d4cc,
			Torso = 0xd9d4cc,
			LeftArm = 0xd9d4cc,
			RightArm = 0xd9d4cc,
			LeftLeg = 0xd9d4cc,
			RightLeg = 0xd9d4cc,
		},
		budget = 13,
	},
} :: { [string]: { [string]: any } }

--- Highlight colours (§5; claimed by Enemies.claimHighlight in stage 3).
Finale.HIGHLIGHT = {
	hyakunui = { outline = STITCH, fillTransparency = 0.9 },
	tempest_fox = { outline = EMBER, fillTransparency = 0.9 },
	the_unbidden = { outline = 0xd9d4cc, fillTransparency = 0.9 },
}

local LIMBS: { [string]: { string } } = {
	Head = { "Head" },
	Torso = { "UpperTorso", "LowerTorso" },
	LeftArm = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
	RightArm = { "RightUpperArm", "RightLowerArm", "RightHand" },
	LeftLeg = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
	RightLeg = { "RightUpperLeg", "RightLowerLeg", "RightFoot" },
}

local function paintBody(model: Model, body: { [string]: any })
	local map = {}
	for limb, color in body.colors do
		for _, n in LIMBS[limb] or {} do
			map[n] = { color = color, material = body.material }
		end
	end
	Kit.paintParts(model, map)
end

--------------------------------------------------------------------------------
-- small helpers
--------------------------------------------------------------------------------

local function mark(inst: Instance)
	inst:SetAttribute("FinaleFx", true)
end

local function attach(host: BasePart, name: string, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a.Parent = host
	mark(a)
	return a
end

local function surface(p: BasePart, face: Enum.NormalId, name: string, pps: number, lit: boolean): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = name
	g.Face = face
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

local function frame(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: number?, rot: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(0.5, x, 0.5, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BorderSizePixel = 0
	if color then
		f.BackgroundColor3 = Palette.color(color)
		f.BackgroundTransparency = 0
	else
		f.BackgroundTransparency = 1
	end
	f.Rotation = rot or 0
	f.Parent = parent
	return f
end

local function outline(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: number, px: number): UIStroke
	local f = frame(parent, name, x, y, w, h, nil)
	local s = Instance.new("UIStroke")
	s.Color = Palette.color(color)
	s.Thickness = px
	s.Parent = f
	return s
end

local function tween(inst: Instance, props: { [string]: any }, time: number)
	local ok, ts = pcall(function()
		return game:GetService("TweenService")
	end)
	if ok and ts then
		(ts :: any):Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	else
		for k, v in props do
			(inst :: any)[k] = v
		end
	end
end

local function piecesNamed(model: Model, name: string): { BasePart }
	local out = {}
	local costume = model:FindFirstChild("Costume")
	if costume then
		for _, d in costume:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function entry(b: any, code: string, tier: any, count: number, fn: () -> ()): boolean
	b.code = code
	return b:entry(tier, fn, count)
end

local function attachFrame(host: BasePart, name: string, k: Vector3): CFrame
	local a = host:FindFirstChild(name)
	if a and a:IsA("Attachment") then
		return a.CFrame
	end
	return C(Kit.ATTACH[name].pos * k)
end

--------------------------------------------------------------------------------
-- §5.1 Hyakunui
--------------------------------------------------------------------------------

local NEEDLES = { V(-2.2, 4.2, 1.6), V(0, 4.8, 2.0), V(2.2, 4.2, 1.6) }
local STARTS = { V(-0.3, 0.6, 0.1), V(0, 0.2, 0.1), V(0.3, 0.6, 0.1) } -- to needles 1, 2, 3; the 4th from 3

local HY_LOOK = {
	colors = {
		skin = 0xe8d8c0,
		hair = 0x1a1a22,
		brow = 0x1a1a22,
		eye = 0xc89a6a,
		top = 0x4a3a4a,
		sleeves = 0x8a6244,
		bottom = 0x1a1622,
		trim = 0x3a0a14,
		sig = STITCH,
	},
}

local function hyakunui(b: any, rig: any, t: { [string]: any }, pal: { [string]: any }?, _opts: { [string]: any })
	local model: Model = rig.model
	local head: BasePart = rig.parts.Head
	local ut: BasePart = rig.parts.UpperTorso
	local lt: BasePart = rig.parts.LowerTorso
	local k = Kit.scaleOf(ut)

	-- tier 0: FP and the face (§5.1 FP row; the midline seam stays, lead condition 3)
	local fp: BasePart? = nil
	entry(b, "FP", 0, 1, function()
		fp = Kit.PIECES.FP(b, rig, { "FP" }, HY_LOOK)[1]
	end)
	if fp then
		local base, glow = Kit.face(model, fp, {
			friend = false,
			iris = 0xc89a6a,
			brow = 0x1a1a22,
			marks = {
				{ x = 45, y = 27, w = 2, h = 62, color = STITCH },
				{ x = 45, y = 6, w = 8, h = 2, color = STITCH },
				{ x = 45, y = 30, w = 8, h = 2, color = STITCH },
				{ x = 45, y = 54, w = 8, h = 2, color = STITCH },
			},
		})
		local ir = glow:FindFirstChild("IrisR")
		if ir and ir:IsA("Frame") then
			ir.BackgroundColor3 = Palette.color(0xa8883a) -- the right half is Patchwork
		end
		local br = base:FindFirstChild("BrowR")
		if br and br:IsA("Frame") then
			br.BackgroundColor3 = Palette.color(0x3a1e34)
		end
	end

	-- identity: seams, needles, patches, fist, hair
	local strips: { BasePart } = {}
	entry(b, "HY·s", "R", 2, function()
		for _, z in { -0.525, 0.525 } do
			local p = b:mount(ut, nil, "block", V(0.12, 1.6, 0.05), C(0, 0, z), { color = STITCH, material = "Neon", name = "HY·s" })
			table.insert(strips, p)
		end
	end)
	local patches: { BasePart } = {}
	entry(b, "HY·p", "R", 2, function()
		for _, pos in { V(-0.5, 0.2, -0.53), V(0.5, -0.25, -0.53) } do
			local p = b:mount(ut, nil, "block", V(0.8, 0.8, 0.06), C(pos.X, pos.Y, pos.Z), {
				color = 0x3a0a14,
				name = "HY·p",
			})
			p:SetAttribute("Side", if pos.X < 0 then "L" else "R")
			table.insert(patches, p)
		end
	end)
	-- SurfaceGuis (budget 4 with the face): the front strip carries its E11 and, drawn past its
	-- edges (ClipsDescendants false), both patches' stitched edges; the back strip its E11.
	for i, s in strips do
		local face = if i == 1 then Enum.NormalId.Front else Enum.NormalId.Back
		local pps = 100 / s.Size.Y
		local g = surface(s, face, "Seam", pps, false)
		local holder = frame(g, "Holder", 0, 0, 100, 100, nil, 90)
		Kit.EMBLEMS.E11(holder, Palette.color(0x3a0a14), s.Color)
		if i == 1 then
			for _, p in patches do
				-- offset in UpperTorso space, from the rest welds (the strip is unrotated)
				local wp = p:FindFirstChildOfClass("Weld") :: Weld
				local ws = s:FindFirstChildOfClass("Weld") :: Weld
				local d = wp.C0.Position - ws.C0.Position
				-- canvas x grows toward the character's left (-X); y grows down
				outline(g, "Patch" .. tostring(p:GetAttribute("Side")), -d.X * pps, -d.Y * pps, (p.Size.X + 0.04) * pps, (p.Size.Y + 0.04) * pps, STITCH, 3)
			end
		end
	end
	local needles: { BasePart } = {}
	entry(b, "HY·n", "R", 3, function()
		for _, pos in NEEDLES do
			local p = b:mount(ut, nil, "wedge", V(0.1, 0.6, 0.1), C(pos.X, pos.Y, pos.Z) * rx(-30), {
				color = Costumes.STEEL,
				material = "Metal",
				name = "HY·n",
			})
			local w = p:FindFirstChildOfClass("Weld") :: Weld
			w:SetAttribute("BasePos", w.C0.Position)
			table.insert(needles, p)
		end
	end)
	local fist: BasePart? = nil
	b.code = "FS"
	b:entry("R", function()
		fist = Kit.PIECES.FS(b, rig, { "FS", side = "R", tint = 0x8a6244 }, HY_LOOK)[1]
	end, 2)
	entry(b, "HR", "R", 1, function()
		Kit.PIECES.HR(b, rig, { "HR", tint = 0x1a1a22 }, HY_LOOK)
	end)
	entry(b, "HR·k", "R", 1, function()
		b:mount(head, nil, "ball", V(0.54, 0.54, 0.54), C(-0.3, 0.6, 0.4), { color = 0x1a1a22, name = "HR·k" })
	end)
	entry(b, "HR·p", "R", 1, function()
		Kit.PIECES["HR·p"](b, rig, { "HR·p", h = 0.9, w = 0.5, x = 0.3, tint = 0x3a1e34 }, HY_LOOK)
	end)
	entry(b, "CT", "D", 1, function()
		local hinge = V(-0.48, 0, 0.04)
		local p = b:hinge(lt, "WaistBackAttachment", "block", V(0.95, 1.5, 0.08), hinge, rx(-14) * rz(6), {
			color = 0x4a3a4a,
			material = "Fabric",
			name = "CT",
		})
		b:sway(hinge, nil, p)
	end)

	-- threads: 4 Beams from the back to the 3 needles and the fist (0 parts)
	local back = attachFrame(ut, "BodyBackAttachment", k)
	local starts = {}
	for i, s in STARTS do
		starts[i] = attach(ut, "ThreadStart", back * C(s * k))
	end
	local ends: { Attachment } = {}
	for i, p in needles do
		local w = p:FindFirstChildOfClass("Weld") :: Weld
		local a = attach(ut, "ThreadFar", w.C0)
		a:SetAttribute("BasePos", w.C0.Position)
		ends[i] = a
	end
	if fist then
		table.insert(ends, attach(fist, "ThreadFist", CFrame.identity))
	end
	local from = { starts[1], starts[2], starts[3], starts[3] }
	for i, a1 in ends do
		local beam = Instance.new("Beam")
		beam.Name = "Thread"
		beam.Attachment0 = from[i]
		beam.Attachment1 = a1
		beam.Width0 = 0.08 * k.X
		beam.Width1 = 0.08 * k.X
		beam:SetAttribute("BaseWidth", 0.08 * k.X)
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Palette.color(STITCH))
		beam.Parent = ut
		mark(beam)
	end

	-- emitters (3): thread, and a one-shot burst on each patch for phase 2
	local th = Kit.emitter(starts[2], "thread", { name = "Thread" })
	if th then
		mark(th)
	end
	local nature = (pal and pal.nature) or (RulesData.NATURE[t.nature or "cursed"] or { color = STITCH }).color
	for _, p in patches do
		Kit.emitter(p, "burst", { color = nature, name = "Burst" })
	end

	-- light
	local light = Instance.new("PointLight")
	light.Name = "FinaleLight"
	light.Color = Palette.color(STITCH)
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = ut
	mark(light)

	-- halves (§5.1)
	paintBody(model, Finale.BODY.hyakunui)
	Kit.paintParts(model, {
		LeftUpperArm = { color = 0x4a3a4a, material = "Fabric" },
		LeftLowerArm = { color = 0x4a3a4a, material = "Fabric" },
		LeftHand = { color = 0xe8d8c0 },
	})
	model:SetAttribute("FinalePhase", 0)
	Finale.phase(model, 1)
end

local function white(c: number): number
	return Costumes.lerp(c, 0xffffff, 0.3)
end

--- Hyakunui's phase look (§5.1 Phases). Phases only go up; each includes the ones before.
function Finale.phase(model: Model, phase: number)
	local now = (model:GetAttribute("FinalePhase") :: number?) or 0
	if phase <= now then
		return
	end
	model:SetAttribute("FinalePhase", phase)
	local ut = model:FindFirstChild("UpperTorso")
	local emitter: ParticleEmitter? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Name == "Thread" then
			emitter = d
		end
	end
	if emitter then
		emitter.Rate = if phase >= 3 then 12 else 4
	end
	if phase >= 2 and now < 2 then
		for _, p in piecesNamed(model, "HY·p") do
			p.Material = Enum.Material.Neon
			p.Color = Palette.color(if p:GetAttribute("Side") == "L" then Finale.TEAR.left else Finale.TEAR.right)
			local burst = p:FindFirstChild("Burst")
			if burst and burst:IsA("ParticleEmitter") then
				pcall(function()
					burst:Emit(12)
				end)
			end
		end
		for _, p in piecesNamed(model, "HY·n") do
			local w = p:FindFirstChildOfClass("Weld")
			local base = w and w:GetAttribute("BasePos")
			if w and typeof(base) == "Vector3" then
				tween(w, { C0 = CFrame.new(base * 1.4) * w.C0.Rotation }, 0.6)
			end
		end
		if ut then
			for _, d in ut:GetChildren() do
				local base = d:GetAttribute("BasePos")
				if d:IsA("Attachment") and d.Name == "ThreadFar" and typeof(base) == "Vector3" then
					tween(d, { CFrame = CFrame.new(base * 1.4) * d.CFrame.Rotation }, 0.6)
				elseif d:IsA("Beam") and d.Name == "Thread" then
					local w = (d:GetAttribute("BaseWidth") :: number?) or 0.08
					d.Width0 = w * 0.14 / 0.08
					d.Width1 = w * 0.14 / 0.08
				end
			end
		end
	end
	if phase >= 3 and now < 3 then
		for _, p in piecesNamed(model, "HY·s") do
			p.Color = Palette.color(white(STITCH))
		end
		for _, p in piecesNamed(model, "HY·n") do
			p.Color = Palette.color(white(Costumes.STEEL))
		end
		if ut then
			for _, d in ut:GetChildren() do
				if d:IsA("Beam") and d.Name == "Thread" then
					d.Color = ColorSequence.new(Palette.color(white(STITCH)))
				end
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("Highlight") then
				d.FillTransparency = 0.6
			end
		end
		for _, n in { "HR·p", "HR·k" } do
			for _, p in piecesNamed(model, n) do
				p:Destroy()
			end
		end
	end
end

--------------------------------------------------------------------------------
-- §5.2 The Tempest Fox (every piece absolute on the HumanoidRootPart)
--------------------------------------------------------------------------------

local function tempestFox(b: any, rig: any, t: { [string]: any }, _pal: { [string]: any }?, _opts: { [string]: any })
	local model: Model = rig.model
	local hrp: BasePart = rig.parts.HumanoidRootPart
	local S = 2.4 * 0.55 * (t.size or 2.1)
	local g = rig.ground
	local ABS = { absolute = true }
	local function body(name: string, color: number?): any
		return { color = color or SLATE, material = "SmoothPlastic", name = name }
	end
	local function m(kind: string, size: Vector3, cf: CFrame, pr: any): BasePart
		return b:mount(hrp, nil, kind, size * S, cf, pr, ABS)
	end

	-- hide the walker
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	local head = rig.parts.Head
	local decal = head and head:FindFirstChild("face")
	if decal then
		decal:Destroy()
	end

	local plate: BasePart? = nil
	entry(b, "TF·face", "R", 1, function()
		plate = m("block", V(0.7, 0.45, 0.05), C(0, g + 1.72 * S, -1.71 * S), body("FP", BONE))
	end)
	entry(b, "TF·skull", "R", 1, function()
		m("ell", V(0.8, 0.7, 0.8), C(0, g + 1.7 * S, -1.3 * S), body("TF·skull"))
	end)
	entry(b, "TF·snout", "R", 1, function()
		m("wedge", V(0.4, 0.35, 0.6), C(0, g + 1.6 * S, -1.75 * S), body("TF·snout"))
	end)
	local ears: { BasePart } = {}
	entry(b, "TF·ear", "R", 2, function()
		for _, s in { -1, 1 } do
			table.insert(ears, m("wedge", V(0.12, 0.7, 0.4), C(s * 0.25 * S, g + 2.2 * S, -1.25 * S) * rz(-s * 15), body("TF·ear")))
		end
	end)
	entry(b, "TF·body", "R", 1, function()
		m("ell", V(1.0, 0.9, 2.2), C(0, g + 1.25 * S, 0), body("TF·body"))
	end)
	entry(b, "TF·ruff", "R", 1, function()
		m("ell", V(0.9, 0.9, 0.7), C(0, g + 1.35 * S, -0.9 * S), body("TF·ruff", BONE))
	end)
	local tails: { BasePart } = {}
	entry(b, "TF·tail", "R", 3, function()
		local hinge = V(0, g + 1.4 * S, 1.1 * S)
		for _, a in { -20, 0, 20 } do
			local p = m("ell", V(0.35, 0.35, 2.4), C(hinge.X, hinge.Y, hinge.Z) * rz(a) * rx(-35) * C(0, 0, 1.2 * S), body("TF·tail"))
			b:sway(hinge, 10, p)
			table.insert(tails, p)
		end
	end)
	local legs: { [string]: BasePart } = {}
	entry(b, "TF·leg", "L", 4, function()
		-- {name, side, z, size, gait phase}: FL+HR at 0, FR+HL at 0.5
		for _, l in {
			{ "HL", -1, 0.8, V(0.45, 1.3, 0.6), 0.5 },
			{ "HR", 1, 0.8, V(0.45, 1.3, 0.6), 0 },
			{ "FL", -1, -0.8, V(0.4, 1.3, 0.5), 0 },
			{ "FR", 1, -0.8, V(0.4, 1.3, 0.5), 0.5 },
		} do
			local pivot = V(l[2] * 0.35 * S, g + 0.1 + 1.3 * S, l[3] * S)
			local p = b:hinge(hrp, nil, "wedge", l[4] * S, pivot, CFrame.identity, body("TF·leg"), ABS)
			b:gait(l[1], pivot, l[5], 22, p)
			legs[l[1]] = p
		end
	end)

	-- SurfaceGuis (budget 4): FaceBase + FaceGlow on the face plate, ember on each ear's inner
	-- face. The belly glow is left out to stay within the §6.3 budget.
	if plate then
		local pps = 100 / plate.Size.X
		local base = surface(plate, Enum.NormalId.Front, "FaceBase", pps, false)
		local glow = surface(plate, Enum.NormalId.Front, "FaceGlow", pps, true)
		glow.Brightness = 2.5
		glow.ZOffset = 1
		frame(base, "Fork", 0, -20, 4, 22, SLATE, 20)
		frame(base, "Fork", -6, -4, 4, 16, SLATE, -25)
		frame(base, "Fork", 6, -2, 4, 14, SLATE, 30)
		for _, s in { -1, 1 } do
			frame(glow, "Iris", s * 22, -10, 18, 4, EMBER, s * 15)
		end
	end
	for _, e in ears do
		local gg = surface(e, Enum.NormalId.Front, "Ember", 100 / e.Size.Y, true)
		frame(gg, "Inner", 0, 6, 0.6 * 100 * e.Size.X / e.Size.Y + 4, 60, EMBER)
	end

	-- tail ember tips (Beams) and wind: one on the middle tail, one on each front paw (3 total)
	for i, p in tails do
		local L = p.Size.Z
		local a0 = attach(p, "TipFrom", C(0, 0, 0.2 * L))
		local a1 = attach(p, "TipTo", C(0, 0, 0.5 * L))
		local beam = Instance.new("Beam")
		beam.Name = "TailTip"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 0.35 * S
		beam.Width1 = 0.05 * S
		beam:SetAttribute("TellScale", 2)
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Palette.color(EMBER))
		beam.Parent = p
		if i == 2 then
			local e = Kit.emitter(a1, "wind")
			if e then
				e:SetAttribute("TellRate", 12)
			end
		end
	end
	for _, n in { "FL", "FR" } do
		local leg = legs[n]
		if leg then
			local a = attach(leg, "Paw", C(0, -leg.Size.Y / 2, 0))
			local e = Kit.emitter(a, "wind", { rate = 6 })
			if e then
				e.Lifetime = NumberRange.new(0.6, 0.6)
				e:SetAttribute("TellRate", 12)
			end
		end
	end
	model:SetAttribute("Tell", false)
end

--- Maps an Enemies.think action to the Tell state (§5.2): true, false, or nil (no change).
function Finale.tellAction(action: string?): boolean?
	if action == "tell" then
		return true
	elseif action == "endLunge" or action == "cancel" or action == "death" then
		return false
	end
	return nil
end

--- Sets the model's Tell attribute (edge only). The client widens the tail Beams by their
--- TellScale, raises emitters to their TellRate and lays the scorch trail.
function Finale.setTell(model: Model, on: boolean)
	if model:GetAttribute("Tell") ~= on then
		model:SetAttribute("Tell", on)
	end
end

--------------------------------------------------------------------------------
-- §5.3 The Unbidden
--------------------------------------------------------------------------------

local DULL = 0x8a8680
local UB_LOOK = { colors = { skin = 0xd9d4cc, top = 0xd9d4cc, trim = DULL, sig = DULL, eye = 0x2a2620 } }

local function unbidden(b: any, rig: any, _t: { [string]: any }, _pal: { [string]: any }?, opts: { [string]: any })
	local model: Model = rig.model
	local ut: BasePart = rig.parts.UpperTorso
	local ally = opts.ally == true
	local fp: BasePart? = nil
	entry(b, "FP", 0, 1, function()
		fp = Kit.PIECES.FP(b, rig, { "FP" }, UB_LOOK)[1]
	end)
	if fp then
		Kit.face(model, fp, {
			friend = ally,
			hideEyes = true,
			mouth = false,
			marks = { { x = 45, y = 22, w = 4, h = 28, color = if ally then Costumes.ALLY_CYAN else 0x2a2620 } },
		})
	end
	entry(b, "UB·t", "R", 8, function()
		for i, nature in Costumes.ADAPT_ORDER do
			local cf = Kit.ry(45 * (i - 1)) * C(0, 0.12, -0.62) * rx(-20)
			local p = b:mount(ut, "NeckAttachment", "block", V(0.42, 0.3, 0.14), cf, { color = DULL, name = "UB·t" })
			p:SetAttribute("Nature", nature)
		end
	end)
	entry(b, "UB·p", "R", 2, function()
		for _, s in { -1, 1 } do
			local p = b:mount(ut, nil, "block", V(0.9, 0.8, 0.1), C(s * 0.5, 0.2, -0.55), { color = 0xc8c2b8, name = "UB·p" })
			local g = surface(p, Enum.NormalId.Front, "Trim", 100, false)
			outline(g, "Trim", 0, 0, p.Size.X * 100 - 8, p.Size.Y * 100 - 8, DULL, 4)
		end
	end)
	entry(b, "UB·d", "R", 2, function()
		for _, s in { -1, 1 } do
			local side = if s < 0 then "Left" else "Right"
			b:mount(rig.parts[side .. "UpperArm"], side .. "ShoulderAttachment", "ell", V(1.2, 0.7, 1.2), C(s * 0.15, 0.1, 0), {
				color = 0xd9d4cc,
				name = "UB·d",
			})
		end
	end)
	paintBody(model, Finale.BODY.the_unbidden)
	local slate = { color = 0xa8a39a, material = "SmoothPlastic" }
	Kit.paintParts(model, { LeftHand = slate, RightHand = slate, LeftLowerArm = slate, RightLowerArm = slate })
	if ally then
		for _, p in piecesNamed(model, "UB·t") do
			p.Material = Enum.Material.Neon
			p.Color = Palette.color(Costumes.ALLY_CYAN)
		end
	else
		Finale.applyAdapted(model)
	end
end

local function trimColour(model: Model, color: number)
	for _, p in piecesNamed(model, "UB·p") do
		local g = p:FindFirstChild("Trim")
		local f = g and g:FindFirstChild("Trim")
		local s = f and f:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = Palette.color(color)
		end
	end
end

--- Lights `nature`'s collar tile in its NATURE colour; the chest-plate trim echoes it.
function Finale.adapt(model: Model, nature: string)
	local nat = RulesData.NATURE[nature]
	if not nat then
		return
	end
	for _, p in piecesNamed(model, "UB·t") do
		if p:GetAttribute("Nature") == nature then
			p.Material = Enum.Material.Neon
			p.Color = Palette.color(nat.color)
		end
	end
	trimColour(model, nat.color)
	model:SetAttribute("AdaptedLast", nature)
end

--- Applies every Adapted_<nature> attribute (ADAPT_ORDER order; the trim takes the last one
--- adapted, or the last in ADAPT_ORDER when that is unknown).
function Finale.applyAdapted(model: Model)
	local last = model:GetAttribute("AdaptedLast")
	local latest: string? = nil
	for _, nature in Costumes.ADAPT_ORDER do
		if model:GetAttribute("Adapted_" .. nature) == true then
			Finale.adapt(model, nature)
			latest = nature
		end
	end
	if type(last) == "string" and model:GetAttribute("Adapted_" .. last) == true then
		latest = last
	end
	if latest then
		Finale.adapt(model, latest)
	end
end

--- Connects AttributeChanged once (§5.3 "Enemies connects AttributeChanged once at spawn").
function Finale.watch(model: Model): RBXScriptConnection?
	local ok, conn = pcall(function()
		return model.AttributeChanged:Connect(function(name: string)
			local nature = string.match(name, "^Adapted_(.+)$")
			if nature and model:GetAttribute(name) == true then
				Finale.adapt(model, nature)
			end
		end)
	end)
	return if ok then conn else nil
end

--------------------------------------------------------------------------------
-- dispatch
--------------------------------------------------------------------------------

Finale.BUILDERS = {
	hyakunui = hyakunui,
	tempest_fox = tempestFox,
	the_unbidden = unbidden,
} :: { [string]: (any, any, { [string]: any }, { [string]: any }?, { [string]: any }) -> () }

--- Dresses a finale walker. Returns the costume parts used and the builder.
function Finale.dress(model: Model, enemyId: string, opts: { [string]: any }?): (number, any)
	local o = opts or {}
	local id = Costumes.baseId(enemyId)
	local spec = Costumes.ENEMY[id]
	local name = (spec and spec.builder) or id
	local build = Finale.BUILDERS[name]
	if not build then
		error("Finale: no builder for " .. enemyId, 0)
	end
	local t = o.t or FinaleData.ENEMIES[id] or {}
	local old = model:FindFirstChild("Costume")
	if old then
		old:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d:GetAttribute("FinaleFx") == true or (d:IsA("Attachment") and d.Name == "CostumeFx") then
			d:Destroy()
		end
	end
	local body = Finale.BODY[name] or {}
	local budget = o.budget or body.budget or 14
	if o.ally then
		budget = 14 -- the ward: +1 for the cyan ring (Kit.ally)
	end
	local b = Kit.new(model, budget)
	local rig = Kit.rig(model)
	rig.role = if o.ally then "ally" else "finale"
	build(b, rig, t, o.pal, o)
	return b.used, b
end

return Finale
