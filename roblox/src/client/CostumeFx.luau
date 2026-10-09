--!strict
-- Client-side costume motion and reads (docs/design/characters.md §2.1, §4.2, §4.5, §5.2, §6.2).
-- The server builds every costume once and never rewrites these welds; this module drives
-- them locally, at no server cost:
--   Gait_* / Orbit_* / Sway_* / Glide welds   (§2.1 client-driven welds)
--   float bob and toad hop on LowerTorso.Root  (§4.2)
--   Pulse parts (Volatile weak points and fuses at 3 Hz, 8 Hz over the 1 s fuse after death,
--   cursed cores) and the model Pulse (§4.5)
--   the Tempest Fox tell: Tell -> Beam widths × TellScale, emitters to TellRate, scorch trail
--   the death read on Dying: Neon in NatureColor for 0.1 s, then a 0.4 s fade (§6.2)
--   distance LOD every 0.5 s: CostumeDetail > 90 studs, emitters > 120, Sway > 60

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CostumeFx = {}

local LOD_DETAIL = 90
local LOD_EMIT = 120
local LOD_SWAY = 60
local LOD_DRIVE = 160 -- nothing is driven beyond this
local CYL_UP = CFrame.Angles(0, 0, math.pi / 2)
local TAU = math.pi * 2

-- p: pivot or centre, axis: orbit axis, a: amp / rate, ph: phase (read once per scan)
type Driven = { weld: Weld, rest: CFrame, p: Vector3, axis: Vector3, a: number, ph: number }

-- The rest C0 of every driven weld, read once: a rescan mid-animation must not take an
-- animated C0 as the rest (orbit and sway would drift). Kit rebuilds make new Welds.
local restOf: { [Weld]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
type Rec = {
	model: Model,
	dirty: boolean,
	gait: { Driven },
	orbit: { Driven },
	sway: { Driven },
	glide: { Driven },
	pulse: { BasePart },
	neon: { BasePart },
	detail: { BasePart },
	emitters: { ParticleEmitter },
	emitOn: { [ParticleEmitter]: boolean },
	tellBeams: { Beam },
	tellEmitters: { ParticleEmitter },
	root: BasePart?,
	rootMotor: Motor6D?,
	rootRest: CFrame?,
	stride: number,
	near: boolean,
	swayOn: boolean,
	detailHidden: boolean,
	emitHidden: boolean,
	tell: boolean,
	nextScorch: number,
	dying: boolean,
	conns: { RBXScriptConnection },
}

local recs: { [Model]: Rec } = {}

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function vec(inst: Instance, name: string): Vector3
	local v = inst:GetAttribute(name)
	return if typeof(v) == "Vector3" then v else Vector3.zero
end

local function color(v: any, default: Color3): Color3
	if typeof(v) == "Color3" then
		return v
	elseif type(v) == "number" then
		return Color3.fromRGB(bit32.extract(v, 16, 8), bit32.extract(v, 8, 8), bit32.extract(v, 0, 8))
	end
	return default
end

local function scan(rec: Rec)
	local m = rec.model
	rec.gait, rec.orbit, rec.sway, rec.glide = {}, {}, {}, {}
	rec.pulse, rec.neon, rec.detail, rec.emitters = {}, {}, {}, {}
	rec.tellBeams, rec.tellEmitters = {}, {}
	local costume = m:FindFirstChild("Costume")
	local modelPulse = m:GetAttribute("Pulse") == true
	for _, d in m:GetDescendants() do
		if d:IsA("Weld") then
			local n = d.Name
			local rest = restOf[d]
			if not rest then
				rest = d.C0
				restOf[d] = rest
			end
			local entry: Driven =
				{ weld = d, rest = rest :: CFrame, p = Vector3.zero, axis = Vector3.yAxis, a = 0, ph = 0 }
			if string.sub(n, 1, 5) == "Gait_" then
				entry.p, entry.a, entry.ph = vec(d, "GaitPivot"), num(d, "GaitAmp", 22), num(d, "GaitPhase", 0)
			elseif string.sub(n, 1, 6) == "Orbit_" then
				local axis = vec(d, "OrbitAxis")
				entry.axis = if axis.Magnitude < 1e-3 then Vector3.yAxis else axis.Unit
				entry.p, entry.a, entry.ph = vec(d, "OrbitCenter"), num(d, "OrbitRate", 0.25), num(d, "OrbitPhase", 0)
			elseif string.sub(n, 1, 5) == "Sway_" then
				entry.p, entry.a = vec(d, "SwayPivot"), num(d, "SwayAmp", 18)
			end
			if string.sub(n, 1, 5) == "Gait_" then
				table.insert(rec.gait, entry)
			elseif string.sub(n, 1, 6) == "Orbit_" then
				table.insert(rec.orbit, entry)
			elseif string.sub(n, 1, 5) == "Sway_" then
				table.insert(rec.sway, entry)
			elseif n == "Glide" then
				table.insert(rec.glide, entry)
			end
		elseif d:IsA("BasePart") then
			if d:GetAttribute("Pulse") ~= nil then
				table.insert(rec.pulse, d)
			elseif modelPulse and costume and d:IsDescendantOf(costume) and d.Material == Enum.Material.Neon then
				table.insert(rec.neon, d)
			end
			if d:HasTag("CostumeDetail") then
				table.insert(rec.detail, d)
			end
		elseif d:IsA("ParticleEmitter") then
			table.insert(rec.emitters, d)
			if rec.emitOn[d] == nil then
				rec.emitOn[d] = d.Enabled
			end
			if d:GetAttribute("TellRate") ~= nil then
				if d:GetAttribute("BaseRate") == nil then
					d:SetAttribute("BaseRate", d.Rate)
				end
				table.insert(rec.tellEmitters, d)
			end
		elseif d:IsA("Beam") and d:GetAttribute("TellScale") ~= nil then
			if d:GetAttribute("BaseW0") == nil then
				d:SetAttribute("BaseW0", d.Width0)
				d:SetAttribute("BaseW1", d.Width1)
			end
			table.insert(rec.tellBeams, d)
		end
	end
	local root = m:FindFirstChild("HumanoidRootPart")
	rec.root = if root and root:IsA("BasePart") then root else nil
	local lt = m:FindFirstChild("LowerTorso")
	local motor = lt and lt:FindFirstChild("Root")
	if motor and motor:IsA("Motor6D") then
		if rec.rootMotor ~= motor then
			rec.rootMotor = motor
			rec.rootRest = motor.C0
		end
	else
		rec.rootMotor, rec.rootRest = nil, nil
	end
	rec.dirty = false
end

local function setTell(rec: Rec, on: boolean)
	rec.tell = on
	for _, b in rec.tellBeams do
		local k = if on then num(b, "TellScale", 2) else 1
		b.Width0 = num(b, "BaseW0", b.Width0) * k
		b.Width1 = num(b, "BaseW1", b.Width1) * k
	end
	for _, e in rec.tellEmitters do
		e.Rate = if on then num(e, "TellRate", e.Rate) else num(e, "BaseRate", e.Rate)
	end
end

--- §6.2 death read: every Costume part goes Neon in NatureColor for 0.1 s, then fades over 0.4 s.
local function deathRead(rec: Rec)
	if rec.dying then
		return
	end
	rec.dying = true
	local m = rec.model
	local costume = m:FindFirstChild("Costume")
	if not costume then
		return
	end
	local c = color(m:GetAttribute("NatureColor"), Color3.fromRGB(255, 255, 255))
	local parts: { BasePart } = {}
	local fusing: { BasePart } = {}
	local volatile = m:GetAttribute("Volatile") == true
	for _, d in costume:GetDescendants() do
		if volatile and d:IsA("BasePart") and d:GetAttribute("Pulse") ~= nil then
			table.insert(fusing, d) -- the 1 s fuse: 8 Hz, then gone with the model
		elseif d:IsA("BasePart") and d.Transparency < 1 then
			d.Material = Enum.Material.Neon
			d.Color = c
			table.insert(parts, d)
		elseif d:IsA("ParticleEmitter") then
			local n = d:GetAttribute("Emit")
			if type(n) == "number" then
				d.Color = ColorSequence.new(c)
				d:Emit(n)
			end
		end
	end
	if #fusing > 0 then
		task.spawn(function()
			local started = os.clock()
			while os.clock() - started < 1 and m.Parent do
				local k = 0.25 - 0.25 * math.cos(TAU * 8 * (os.clock() - started))
				for _, p in fusing do
					p.Transparency = k
				end
				task.wait()
			end
		end)
	end
	task.delay(0.1, function()
		for _, p in parts do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			end
		end
		for _, d in m:GetDescendants() do
			if d:IsA("SurfaceGui") then
				d.Enabled = false
			elseif d:IsA("Beam") then
				d.Enabled = false
			elseif d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
	end)
end

local function drop(model: Model)
	local rec = recs[model]
	if rec then
		for _, c in rec.conns do
			c:Disconnect()
		end
		recs[model] = nil
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or recs[model] then
		return
	end
	local rec: Rec = {
		model = model,
		dirty = true,
		gait = {},
		orbit = {},
		sway = {},
		glide = {},
		pulse = {},
		neon = {},
		detail = {},
		emitters = {},
		emitOn = setmetatable({}, { __mode = "k" }) :: any,
		tellBeams = {},
		tellEmitters = {},
		root = nil,
		rootMotor = nil,
		rootRest = nil,
		stride = 0,
		near = true,
		swayOn = true,
		detailHidden = false,
		emitHidden = false,
		tell = false,
		nextScorch = 0,
		dying = false,
		conns = {},
	}
	recs[model] = rec
	table.insert(
		rec.conns,
		model.DescendantAdded:Connect(function()
			rec.dirty = true
		end)
	)
	table.insert(
		rec.conns,
		model.DescendantRemoving:Connect(function()
			rec.dirty = true
		end)
	)
	table.insert(
		rec.conns,
		model.AttributeChanged:Connect(function(name: string)
			if name == "Dying" and model:GetAttribute("Dying") == true then
				deathRead(rec)
			elseif name == "Tell" then
				if rec.dirty then
					scan(rec)
				end
				setTell(rec, model:GetAttribute("Tell") == true)
			elseif name == "Pulse" then
				rec.dirty = true
			end
		end)
	)
	table.insert(
		rec.conns,
		model.Destroying:Connect(function()
			drop(model)
		end)
	)
	if model:GetAttribute("Dying") == true then
		scan(rec)
		deathRead(rec)
	end
end

--- Every model that can wear a costume: enemies, worn bodies, wards, player characters.
local function refresh()
	local folders = { workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Worn") }
	for _, f in folders do
		if f then
			for _, m in f:GetChildren() do
				track(m)
			end
		end
	end
	for _, tag in { "Ward", "Gait", "Orbit", "Sway", "Glide" } do
		for _, m in CollectionService:GetTagged(tag) do
			track(m)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			track(p.Character)
		end
	end
	for m in recs do
		if not m:IsDescendantOf(workspace) then
			drop(m)
		end
	end
end

--- Distance LOD (every 0.5 s).
local function lod()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local eye = cam.CFrame.Position
	for _, rec in recs do
		if rec.dirty then
			scan(rec)
		end
		local root = rec.root
		local d = if root then (root.Position - eye).Magnitude else 0
		rec.near = d <= LOD_DRIVE
		local swayOn = d <= LOD_SWAY
		if rec.swayOn and not swayOn then
			for _, s in rec.sway do
				s.weld.C0 = s.rest
			end
		end
		rec.swayOn = swayOn
		local hide = d > LOD_DETAIL
		if hide ~= rec.detailHidden then
			rec.detailHidden = hide
			for _, p in rec.detail do
				p.LocalTransparencyModifier = if hide then 1 else 0
			end
		end
		local mute = d > LOD_EMIT
		if mute ~= rec.emitHidden and not rec.dying then
			rec.emitHidden = mute
			for _, e in rec.emitters do
				e.Enabled = if mute then false else rec.emitOn[e] ~= false
			end
		end
	end
end

local function scorch(at: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(1.2, 0.05, 1.2)
	p.CFrame = CFrame.new(at)
	p.Color = Color3.fromRGB(40, 22, 14)
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 0.3
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(2), { Transparency = 1 }):Play()
	Debris:AddItem(p, 2.1)
end

local function step(dt: number)
	local t = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, rec in recs do
		if rec.dirty then
			scan(rec)
		end
		local root = rec.root
		if not rec.near or not root or rec.dying then
			continue
		end
		local m = rec.model
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local S = num(m, "Scale", 1)
		local f = speed / (1.6 * math.max(S, 0.1))
		rec.stride = (rec.stride + f * dt) % 1000

		for _, g in rec.gait do
			local p = g.p
			local a = g.a * math.clamp(speed / 4, 0, 1)
			local ang = a * math.sin(TAU * (rec.stride + g.ph))
			g.weld.C0 = CFrame.new(p) * CFrame.Angles(math.rad(ang), 0, 0) * CFrame.new(-p) * g.rest
		end
		for _, o in rec.orbit do
			local c = o.p
			local ang = TAU * (o.a * t + o.ph)
			o.weld.C0 = CFrame.new(c) * CFrame.fromAxisAngle(o.axis, ang) * CFrame.new(-c) * o.rest
		end
		if rec.swayOn then
			for _, s in rec.sway do
				local p = s.p
				local th = -s.a * math.clamp(speed / 16, 0, 1) + 3 * math.sin(TAU * 1.2 * t)
				s.weld.C0 = CFrame.new(p) * CFrame.Angles(math.rad(th), 0, 0) * CFrame.new(-p) * s.rest
			end
		end
		if #rec.glide > 0 then
			local untilT = num(m, "GlideUntil", 0)
			local ut = m:FindFirstChild("UpperTorso")
			local hum = m:FindFirstChildOfClass("Humanoid")
			for _, g in rec.glide do
				if serverNow < untilT and ut and ut:IsA("BasePart") and hum then
					local yg = -(hum.HipHeight + root.Size.Y / 2)
					g.weld.C0 = ut.CFrame:ToObjectSpace(root.CFrame * CFrame.new(0, yg - 0.06, 0) * CYL_UP)
				elseif g.weld.C0 ~= g.rest then
					g.weld.C0 = g.rest
				end
			end
		end
		-- float bob (±0.3 studs over 1.6 s) and toad hop (0.25 studs at the stride)
		local motor, rest = rec.rootMotor, rec.rootRest
		if motor and rest then
			if m:GetAttribute("Float") == true then
				motor.C0 = rest * CFrame.new(0, 0.3 * math.sin(TAU * t / 1.6), 0)
			elseif m:GetAttribute("Shape") == "toad" then
				local hop = if speed > 1 then 0.25 * math.abs(math.sin(math.pi * rec.stride)) else 0
				motor.C0 = rest * CFrame.new(0, hop, 0)
			end
		end
		-- pulses: Pulse = Hz on a part (Transparency 0..0.5); 8 Hz on a dying volatile's fuse
		for _, p in rec.pulse do
			local hz = num(p, "Pulse", 3)
			p.Transparency = 0.25 - 0.25 * math.cos(TAU * hz * t)
		end
		for _, p in rec.neon do
			p.Transparency = 0.15 - 0.15 * math.cos(TAU * 1.2 * t)
		end
		if rec.tell and serverNow >= rec.nextScorch then
			rec.nextScorch = serverNow + 0.15
			local hum = m:FindFirstChildOfClass("Humanoid")
			local yg = if hum then -(hum.HipHeight + root.Size.Y / 2) else -3
			scorch((root.CFrame * CFrame.new(0, yg + 0.03, 0)).Position)
		end
	end
end

local started = false
function CostumeFx.start()
	if started then
		return
	end
	started = true
	refresh()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			refresh()
			lod()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return CostumeFx
