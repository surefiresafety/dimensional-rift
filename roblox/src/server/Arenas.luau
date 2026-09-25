--!strict
-- Builds each world's arena from its layout (Shared.Layouts): every part the
-- layout lists, its terrain, water and hills, beams, and the Nav part that
-- tells Waves where enemies may arrive and tells Nav where the stairs are.
-- The theme adds what a layout does not: the weather, the time of day, the
-- storm's lightning and the portal the rift came through.
--
-- Layouts are worked in web-build units from the world's centre C and scaled
-- by STUDS here. Everything is anchored and seeded, so a world looks the same
-- every time. The layout checks in tests/layoutcheck.luau run against the
-- same plan, so what is built is what was tested.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Layouts = require(Shared.Layouts)
local RulesData = require(Shared.Data.Rules)

local STUDS = Config.STUDS_PER_UNIT

local Arenas = {}

-- Rails stop bodies but not shots; crowns stop swing rays but nothing else.
for _, g in { "Rail", "ShotRay", "Foliage" } do
	if not PhysicsService:IsCollisionGroupRegistered(g) then
		PhysicsService:RegisterCollisionGroup(g)
	end
end
PhysicsService:CollisionGroupSetCollidable("Rail", "ShotRay", false)
PhysicsService:CollisionGroupSetCollidable("Foliage", "ShotRay", false)

type Kit = {
	model: Model,
	centre: Vector3, -- studs, on the ground
	tint: Color3,
	rng: Random,
	plan: Layouts.Plan,
	groups: { [string]: Model },
	byId: { [string]: BasePart },
	parts: number,
	lights: number,
}

local function at(k: Kit, x: number, h: number, z: number): Vector3
	return k.centre + Vector3.new(x, h, z) * STUDS
end

local function material(name: string): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and m then m else Enum.Material.SmoothPlastic
end

-- Terrain colours are global, so every build starts from the defaults.
local TOUCHED = {
	Enum.Material.Grass,
	Enum.Material.Asphalt,
	Enum.Material.Ground,
	Enum.Material.Cobblestone,
	Enum.Material.Slate,
	Enum.Material.Concrete,
	Enum.Material.Sand,
	Enum.Material.Rock,
	Enum.Material.Snow,
	Enum.Material.Basalt,
	Enum.Material.Mud,
	Enum.Material.Sandstone,
	Enum.Material.Pavement,
	Enum.Material.Limestone,
	Enum.Material.Salt,
}
local DEFAULT_COLOUR: { [Enum.Material]: Color3 } = {}
for _, m in TOUCHED do
	DEFAULT_COLOUR[m] = workspace.Terrain:GetMaterialColor(m)
end

-- Parts ----------------------------------------------------------------------

local FACES: { [string]: Enum.NormalId } = {
	Front = Enum.NormalId.Front,
	Back = Enum.NormalId.Back,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
	Top = Enum.NormalId.Top,
	Bottom = Enum.NormalId.Bottom,
}

local function addLight(k: Kit, p: BasePart, l: Layouts.Light)
	local colour = Palette.color(l.color or 0xffe0a0)
	if l.kind == "spot" then
		local s = Instance.new("SpotLight")
		s.Color = colour
		s.Range = math.min(l.range or 40, 60)
		s.Brightness = l.bright or 2
		s.Angle = l.angle or 60
		s.Face = FACES[l.face or "Front"] or Enum.NormalId.Front
		s.Shadows = false
		s.Parent = p
	else
		local s = Instance.new("PointLight")
		s.Color = colour
		s.Range = math.min(l.range or 24, 60)
		s.Brightness = l.bright or 1.5
		s.Shadows = false
		s.Parent = p
	end
	k.lights += 1
end

local function addText(p: BasePart, t: Layouts.Text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = FACES[t.face or "Front"] or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 2.5
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	local fg = Palette.color(t.color or 0xffffff)
	label.BackgroundColor3 = if t.bg and t.bg >= 0 then Palette.color(t.bg) else fg:Lerp(Color3.new(0, 0, 0), 0.8)
	label.BackgroundTransparency = if t.bg == -1 then 1 else 0
	label.TextColor3 = fg
	label.Text = t.text
	local ok, font = pcall(function()
		return (Enum.Font :: any)[t.font or "Bangers"]
	end)
	label.Font = if ok and font then font else Enum.Font.Bangers
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = p
end

--- One layout record as a part.
local function render(k: Kit, r: Layouts.Rec)
	if r.ghost then
		return
	end
	local p: BasePart
	if r.shape == "wedge" then
		p = Instance.new("WedgePart")
	elseif r.shape == "truss" then
		local t = Instance.new("TrussPart")
		t.Style = Enum.Style.NoSupports
		p = t
	else
		p = Instance.new("Part")
	end
	local h = r.h1 - r.h0
	local cy = (r.h0 + r.h1) / 2
	local cf = CFrame.new(at(k, r.x, cy, r.z)) * CFrame.Angles(0, math.rad(r.yaw), 0)
	if r.slope then
		-- A pitched slab: its top runs from slope[1] at local -X to slope[2] at +X.
		local dh = r.slope[2] - r.slope[1]
		local t = h - math.abs(dh)
		local mid = (r.slope[1] + r.slope[2]) / 2 - t / 2
		cf = CFrame.new(at(k, r.x, mid, r.z))
			* CFrame.Angles(0, math.rad(r.yaw), 0)
			* CFrame.Angles(0, 0, math.atan2(dh, r.w))
		p.Size = Vector3.new(math.sqrt(r.w * r.w + dh * dh), t, r.d) * STUDS
	elseif r.shape == "wedge" then
		-- A WedgePart rises toward its local +Z; the layout's run is local +X.
		cf *= CFrame.Angles(0, math.pi / 2, 0)
		p.Size = Vector3.new(r.d, h, r.w) * STUDS
	elseif r.shape == "cyl" then
		(p :: Part).Shape = Enum.PartType.Cylinder
		cf *= CFrame.Angles(0, 0, math.pi / 2)
		p.Size = Vector3.new(h, r.w, r.w) * STUDS
	elseif r.shape == "ball" then
		(p :: Part).Shape = Enum.PartType.Ball
		p.Size = Vector3.one * r.w * STUDS
	elseif r.shape == "truss" then
		p.Size = Vector3.new(2, math.floor(h * STUDS / 2 + 0.5) * 2, 2)
	else
		p.Size = Vector3.new(r.w, h, r.d) * STUDS
	end
	if r.lean then
		cf *= CFrame.Angles(math.rad(r.lean[1]), math.rad(r.lean[2]), math.rad(r.lean[3]))
	end
	if r.tilt then
		local t = r.tilt
		local pivot = CFrame.new(at(k, t[1], t[2], t[3]))
		cf = pivot * CFrame.Angles(math.rad(t[4]), math.rad(t[5]), math.rad(t[6])) * pivot:Inverse() * cf
	end
	p.CFrame = cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = Palette.color(r.color)
	p.Material = material(r.mat)
	p.Transparency = r.alpha or 0
	p.Reflectance = r.refl or 0
	p.Name = r.name or r.id
	local set = r.set
	if set == "decor" then
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	elseif set == "rail" then
		p.CollisionGroup = "Rail"
		p.CanTouch = false
	elseif set == "core" then
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, true, false, false
	elseif set == "foliage" then
		p.CollisionGroup = "Foliage"
		p.CanCollide, p.CanQuery, p.CanTouch = false, true, false
	end
	if r.mat == "Neon" then
		p.CastShadow = false
	end
	if r.light then
		addLight(k, p, r.light)
	end
	if r.text then
		addText(p, r.text)
	end
	if r.fire then
		local f = Instance.new("Fire")
		f.Size = 6
		f.Heat = 9
		f.Parent = p
	end
	if r.smoke then
		local s = Instance.new("Smoke")
		s.Opacity = 0.2
		s.RiseVelocity = 4
		s.Parent = p
	end
	if r.spin then
		p:SetAttribute("Spin", r.spin)
		CollectionService:AddTag(p, "Spin")
	end
	-- Parts a highlight covers share a model, so one Highlight can hold them.
	local parent: Instance = k.model
	for prefix, g in k.groups do
		if r.id == prefix or string.sub(r.id, 1, #prefix + 1) == prefix .. "/" then
			parent = g
		end
	end
	p.Parent = parent
	k.byId[r.id] = p
	k.parts += 1
end

-- Terrain ----------------------------------------------------------------------

local SPAN = 150 -- units from the centre that the ground covers

local function terrain(k: Kit)
	local P = k.plan
	local T = workspace.Terrain
	if P.ground then
		local size = SPAN * 2 * STUDS
		local m = material(P.ground.material)
		T:FillBlock(CFrame.new(k.centre + Vector3.new(0, -2, 0)), Vector3.new(size, 4, size), m)
		if P.ground.color then
			T:SetMaterialColor(m, Palette.color(P.ground.color))
		end
	end
	for _, t in P.terrain do
		local m = material(t.material)
		local centre = at(k, t.x, (t.h0 + t.h1) / 2, t.z)
		if t.op == "ball" then
			T:FillBall(centre, t.w / 2 * STUDS, m)
		elseif t.op == "cyl" then
			T:FillCylinder(CFrame.new(centre), (t.h1 - t.h0) * STUDS, t.w / 2 * STUDS, m)
		else
			T:FillBlock(
				CFrame.new(centre) * CFrame.Angles(0, math.rad(t.yaw), 0),
				Vector3.new(t.w, t.h1 - t.h0, t.d) * STUDS,
				m
			)
		end
	end
	for name, c in P.colours do
		T:SetMaterialColor(material(name), Palette.color(c))
	end
	-- Pools: water in the top 4 studs of the ground, level with the floor.
	for _, w in P.water do
		if w.r then
			T:FillCylinder(CFrame.new(at(k, w.x, 0, w.z) - Vector3.new(0, 2, 0)), 4, w.r * STUDS, Enum.Material.Water)
		else
			T:FillBlock(
				CFrame.new(at(k, w.x, 0, w.z) - Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(w.yaw or 0), 0),
				Vector3.new((w.w :: number) * STUDS, 4, (w.d :: number) * STUDS),
				Enum.Material.Water
			)
		end
	end
end

--- A hill of terrain beyond the play space: its ground circle (radius 0.8 r,
--- since it is sunk 0.6 r) starts no nearer than minGround, and never enters a
--- keep-out sector (design §4.1).
local function hill(k: Kit, rMin: number, rMax: number, m: Enum.Material)
	local H = k.plan.hills :: any
	for _ = 1, 6 do
		local r = k.rng:NextNumber(rMin, rMax)
		local d = H.minGround + k.rng:NextNumber(0, 74) + r * 0.8
		local b = k.rng:NextNumber(0, 360)
		local spread = math.deg(math.asin(math.min(1, 0.8 * r / d)))
		local ok = true
		for _, s in H.keepOut do
			local diff = math.abs((b - s.bearing + 180) % 360 - 180)
			if diff < s.halfWidth + spread then
				ok = false
				break
			end
		end
		if ok then
			local x, z = Layouts.around(b, d)
			workspace.Terrain:FillBall(at(k, x, -0.6 * r, z), r * STUDS, m)
			return
		end
	end
end

-- Beams and emitters -----------------------------------------------------------

local function beams(k: Kit)
	if #k.plan.beams == 0 then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "Threads"
	holder.Anchored = true
	holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = false, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(k.centre)
	holder.Parent = k.model
	for _, b in k.plan.beams do
		-- Parent first: an unparented attachment takes WorldPosition as an offset.
		local a0 = Instance.new("Attachment")
		a0.Parent = holder
		a0.WorldPosition = at(k, b.a[1], b.a[3], b.a[2])
		local a1 = Instance.new("Attachment")
		a1.Parent = holder
		a1.WorldPosition = at(k, b.b[1], b.b[3], b.b[2])
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Color = ColorSequence.new(Palette.color(b.color))
		beam.Width0, beam.Width1 = b.width, b.width
		beam.Transparency = NumberSequence.new(b.alpha or 0)
		beam.LightEmission = b.emission or 1
		beam.CurveSize0, beam.CurveSize1 = b.curve0 or 0, b.curve1 or 0
		beam.Segments = b.segments or 10
		beam.FaceCamera = true
		beam.Parent = holder
	end
end

--- A ParticleEmitter from plain values: numbers, 0xRRGGBB colours, { lo, hi } ranges.
local function emitter(p: BasePart, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	for key, v in props do
		if key == "Color" then
			e.Color = ColorSequence.new(Palette.color(v))
		elseif key == "Lifetime" or key == "Speed" or key == "Rotation" or key == "RotSpeed" then
			(e :: any)[key] = if type(v) == "table" then NumberRange.new(v[1], v[2]) else NumberRange.new(v)
		elseif key == "Size" or key == "Transparency" or key == "Squash" then
			(e :: any)[key] = NumberSequence.new(v)
		elseif key == "SpreadAngle" then
			e.SpreadAngle = Vector2.new(v, v)
		else
			(e :: any)[key] = v
		end
	end
	e.Parent = p
end

-- The Nav part -------------------------------------------------------------------

--- Pads (where enemies arrive) and Links (the foot and top of every stair,
--- ramp and ladder) as attachments on one invisible part at C.
local function nav(k: Kit)
	local n = Instance.new("Part")
	n.Name = "Nav"
	n.Anchored = true
	n.CanCollide, n.CanQuery, n.CanTouch, n.CastShadow = false, false, false, false
	n.Transparency = 1
	n.Size = Vector3.one
	n.CFrame = CFrame.new(k.centre)
	for _, p in k.plan.pads do
		local a = Instance.new("Attachment")
		a.Name = "Pad"
		a.Parent = n
		a.WorldPosition = at(k, p.x, p.h, p.z)
		a:SetAttribute("Radius", if p.boss then 8 else 6)
		a:SetAttribute("Boss", p.boss)
	end
	for _, l in k.plan.access do
		local a = Instance.new("Attachment")
		a.Name = "Link"
		a.Parent = n
		a.WorldPosition = at(k, l.foot[1], l.foot[3], l.foot[2])
		a:SetAttribute("Top", at(k, l.top[1], l.top[3], l.top[2]))
	end
	n.Parent = k.model
	k.parts += 1
end

-- Atmosphere ----------------------------------------------------------------------

local function weather(k: Kit, props: { [string]: any })
	-- Each client keeps this part 30 studs over its own camera (Fx.start), so
	-- the weather falls round the player rather than high up in the fog.
	local sky = Instance.new("Part")
	sky.Name = "Weather"
	sky.Anchored = true
	sky.Size = Vector3.new(120, 1, 120)
	sky.CFrame = CFrame.new(k.centre + Vector3.new(0, 30, 0))
	sky.Transparency = 1
	sky.CanCollide, sky.CanQuery, sky.CanTouch, sky.CastShadow = false, false, false, false
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.LightInfluence = 0.6
	for key, v in props do
		(e :: any)[key] = v
	end
	e.Parent = sky
	sky.Parent = k.model
	k.parts += 1
end

--- The rift itself: a ring of light standing over the centre.
local function portal(k: Kit, colour: Color3)
	local r = 7 * STUDS
	local base = k.centre + Vector3.new(0, r + 3 * STUDS, 0)
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		local seg = Instance.new("Part")
		seg.Name = "RiftSegment"
		seg.Anchored = true
		seg.Size = Vector3.new(0.8, 1.7, 0.8) * STUDS
		seg.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, math.sin(a) * r, 0)) * CFrame.Angles(0, 0, a)
		seg.Color = colour
		seg.Material = Enum.Material.Neon
		seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = false, false, false, false
		seg.Parent = k.model
	end
	local core = Instance.new("Part")
	core.Name = "Rift"
	core.Anchored = true
	core.Shape = Enum.PartType.Cylinder
	core.Size = Vector3.new(0.2, r * 1.9, r * 1.9)
	core.CFrame = CFrame.new(base) * CFrame.Angles(0, math.pi / 2, 0)
	core.Color = colour:Lerp(Color3.new(0, 0, 0), 0.5)
	core.Material = Enum.Material.ForceField
	core.Transparency = 0.2
	core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow = false, false, false, false
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Range = 60
	l.Brightness = 3
	l.Parent = core
	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(colour, Color3.new(1, 1, 1))
	swirl.LightEmission = 1
	swirl.Rate = 40
	swirl.Lifetime = NumberRange.new(1, 2)
	swirl.Speed = NumberRange.new(2, 6)
	swirl.RotSpeed = NumberRange.new(-180, 180)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
	swirl.Transparency = NumberSequence.new(0.2, 1)
	swirl.Parent = core
	core.Parent = k.model
	k.parts += 29
	k.lights += 1
end

type Theme = { clock: number, weather: (Kit) -> { [string]: any }, lightning: boolean? }

local function leaves(colour: Color3, rate: number): { [string]: any }
	return {
		Color = ColorSequence.new(colour),
		Rate = rate,
		Lifetime = NumberRange.new(10, 16),
		Speed = NumberRange.new(2, 4),
		RotSpeed = NumberRange.new(-90, 90),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new(0.5),
		SpreadAngle = Vector2.new(60, 60),
	}
end

local THEMES: { [string]: Theme } = {
	city = {
		clock = 21,
		weather = function()
			return {
				Color = ColorSequence.new(Color3.fromRGB(255, 140, 90)),
				LightEmission = 1,
				Rate = 12,
				Lifetime = NumberRange.new(6, 10),
				Speed = NumberRange.new(3, 6),
				Size = NumberSequence.new(0.3),
				SpreadAngle = Vector2.new(30, 30),
			}
		end,
	},
	ruin = {
		clock = 18.3,
		weather = function()
			return {
				Color = ColorSequence.new(Color3.fromRGB(120, 110, 104)),
				Rate = 60,
				Lifetime = NumberRange.new(8, 12),
				Speed = NumberRange.new(2, 4),
				Size = NumberSequence.new(0.35),
				SpreadAngle = Vector2.new(40, 40),
			}
		end,
	},
	academy = {
		clock = 15,
		weather = function()
			return leaves(Color3.fromRGB(150, 190, 110), 10)
		end,
	},
	kyoto = {
		clock = 17.2,
		weather = function()
			return leaves(Color3.fromRGB(255, 190, 214), 30)
		end,
	},
	tomb = {
		clock = 0,
		weather = function(k)
			return {
				Color = ColorSequence.new(k.tint, Color3.new(1, 1, 1)),
				LightEmission = 1,
				Rate = 25,
				Lifetime = NumberRange.new(6, 10),
				Speed = NumberRange.new(0.5, 2),
				Size = NumberSequence.new(0.25),
				SpreadAngle = Vector2.new(180, 180),
			}
		end,
	},
	desert = {
		clock = 13,
		weather = function()
			return {
				Color = ColorSequence.new(Color3.fromRGB(230, 196, 140)),
				Rate = 80,
				Lifetime = NumberRange.new(4, 7),
				Speed = NumberRange.new(10, 18),
				Acceleration = Vector3.new(20, 0, 5),
				Size = NumberSequence.new(0.3),
				Transparency = NumberSequence.new(0.4),
				SpreadAngle = Vector2.new(60, 60),
			}
		end,
	},
	earth = {
		clock = 16,
		weather = function()
			return {
				Color = ColorSequence.new(Color3.fromRGB(180, 160, 130)),
				Rate = 10,
				Lifetime = NumberRange.new(8, 12),
				Speed = NumberRange.new(1, 3),
				Size = NumberSequence.new(0.4),
				SpreadAngle = Vector2.new(60, 60),
			}
		end,
	},
	water = {
		clock = 9.5,
		weather = function()
			return {
				Color = ColorSequence.new(Color3.fromRGB(220, 235, 245)),
				Rate = 20,
				Lifetime = NumberRange.new(10, 14),
				Speed = NumberRange.new(0.5, 1.5),
				Size = NumberSequence.new(6),
				Transparency = NumberSequence.new(0.85),
				SpreadAngle = Vector2.new(180, 180),
			}
		end,
	},
	storm = {
		clock = 19.2,
		lightning = true,
		weather = function()
			return {
				Color = ColorSequence.new(Color3.fromRGB(180, 200, 230)),
				Rate = 300,
				Lifetime = NumberRange.new(1.5, 2),
				Speed = NumberRange.new(60, 80),
				Size = NumberSequence.new(0.12),
				Squash = NumberSequence.new(3),
				Transparency = NumberSequence.new(0.3),
				SpreadAngle = Vector2.new(5, 5),
			}
		end,
	},
	seam = {
		clock = 0,
		weather = function()
			return {
				Color = ColorSequence.new(Color3.fromRGB(255, 45, 85), Color3.fromRGB(255, 200, 210)),
				LightEmission = 1,
				Rate = 30,
				Lifetime = NumberRange.new(4, 7),
				Speed = NumberRange.new(2, 5),
				Acceleration = Vector3.new(0, 6, 0), -- embers that rise
				Size = NumberSequence.new(0.3),
				SpreadAngle = Vector2.new(180, 180),
			}
		end,
	},
}

local function themeOf(map: any): string
	return Layouts.THEME_OF[map.build or ""] or "city"
end

--- The time of day a world's theme is set at.
function Arenas.clockFor(map: any): number
	return THEMES[themeOf(map)].clock
end

--- A world's layout plan (the same one the tests check).
function Arenas.plan(map: any): Layouts.Plan
	local theme = themeOf(map)
	local def = require(Shared.Layouts:FindFirstChild(theme) :: ModuleScript) :: any
	return Layouts.plan(theme, def, map.seed or 1)
end

--- Builds a world's arena. Clears the terrain first; returns the model.
function Arenas.build(mapId: string, map: any): Model
	workspace.Terrain:Clear()
	for m, c in DEFAULT_COLOUR do
		workspace.Terrain:SetMaterialColor(m, c)
	end
	local theme = themeOf(map)
	workspace.Terrain.WaterWaveSize = if theme == "water" then 0.15 else 0
	local c = map.portalCenter or { x = 0, y = 0, z = 0 }
	local plan = Arenas.plan(map)
	local k: Kit = {
		model = Instance.new("Model"),
		centre = Vector3.new(c.x, 0, c.z) * STUDS,
		tint = Palette.color((RulesData.PORTAL_COLOR :: any)[mapId] or map.hemiSky or 0x8a6cff),
		rng = Random.new(map.seed or 1),
		plan = plan,
		groups = {},
		byId = {},
		parts = 0,
		lights = 0,
	}
	for _, h in plan.highlights do
		local g = Instance.new("Model")
		g.Name = h.prefix
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = Palette.color(h.color)
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = g
		g.Parent = k.model
		k.groups[h.prefix] = g
	end
	terrain(k)
	if plan.hills then
		local H = plan.hills :: any
		for _ = 1, H.count or 30 do
			hill(k, H.rMin or 12, H.rMax or 30, material(H.material or "Rock"))
		end
	end
	for _, r in plan.recs do
		render(k, r)
	end
	for _, e in plan.emitters do
		local p = k.byId[e.id]
		if p then
			emitter(p, e.props)
		end
	end
	beams(k)
	nav(k)
	local t = THEMES[theme]
	weather(k, t.weather(k))
	if t.lightning then
		local flash = Instance.new("BoolValue")
		flash.Name = "Lightning" -- World reads this and flashes the sky
		flash.Parent = k.model
	end
	if plan.openWater then
		k.model:SetAttribute("OpenWater", true)
	end
	portal(k, k.tint)
	k.model:SetAttribute("Theme", theme)
	if k.parts > plan.budget.parts or k.lights > plan.budget.lights or k.parts > 900 or k.lights > 60 then
		warn(
			`{mapId}: {k.parts} parts and {k.lights} lights, over the budget {plan.budget.parts} / {plan.budget.lights}`
		)
	end
	return k.model
end

-- The audit (Studio only) -----------------------------------------------------------

--- Movement.findAnchor's fan with the facing passed in (design §4.4).
local function fanAt(root: Vector3, look: Vector3, params: RaycastParams): Vector3?
	local reach = 60 * STUDS
	local right = look:Cross(Vector3.yAxis)
	local best, bestScore = nil, -math.huge
	for i = 0, 8 do
		local el = math.rad(25 + 55 * i / 8)
		for _, yaw in { -0.9, -0.45, 0, 0.45, 0.9 } do
			local flat = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(look)
			local dir = CFrame.fromAxisAngle(right, el):VectorToWorldSpace(flat)
			local hit = workspace:Raycast(root, dir * reach, params)
			if hit and hit.Position.Y > root.Y + 4 * STUDS then
				local score = hit.Position.Y * 2 + (hit.Position - root):Dot(look)
				if score > bestScore then
					best, bestScore = hit.Position, score
				end
			end
		end
	end
	return best
end

--- Checks the built arena the way tests/layoutcheck checks its plan, but
--- against the real parts, terrain and scatter (design §4.4). Studio only;
--- warns on what fails. Run from the command bar:
---   require(game.ServerScriptService.Server.Arenas).audit(nil, require(game.ReplicatedStorage.Shared.Worlds).get("times_square"))
function Arenas.audit(model: Model?, map: any)
	if not RunService:IsStudio() then
		return
	end
	local arena = model or workspace:FindFirstChild("Arena") :: Model?
	if not arena then
		return
	end
	local plan = Arenas.plan(map)
	local c = map.portalCenter or { x = 0, y = 0, z = 0 }
	local C = Vector3.new(c.x, 0, c.z) * STUDS
	local ignore: { Instance } = {}
	for _, name in { "Enemies", "Worn", "Fx", "Pickups" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local bad = 0
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { arena }
	overlap.RespectCanCollide = true
	for _, p in plan.pads do
		local pos = C + Vector3.new(p.x, p.h, p.z) * STUDS
		local down = workspace:Raycast(pos + Vector3.new(0, 6 * STUDS, 0), Vector3.new(0, -8 * STUDS, 0), params)
		if not down or math.abs(down.Position.Y - pos.Y) > STUDS or down.Material == Enum.Material.Water then
			warn(`audit: pad ({p.x}, {p.z}) has no floor at its height`)
			bad += 1
		end
		local e = if p.boss then 16 else 12
		local hh = if p.boss then 7 else 5
		-- An exact overlap (bounding boxes of ramps and turned decks are too big).
		local probe = Instance.new("Part")
		probe.Anchored = true
		probe.CanCollide, probe.CanQuery, probe.CanTouch = false, false, false
		probe.Transparency = 1
		probe.Size = Vector3.new(e, hh, e) * STUDS
		probe.CFrame = CFrame.new(pos + Vector3.new(0, hh / 2 * STUDS, 0))
		probe.Parent = workspace
		local inside = workspace:GetPartsInPart(probe, overlap)
		probe:Destroy()
		for _, part in inside do
			if part.Position.Y + part.ExtentsSize.Y / 2 > pos.Y + 0.3 * STUDS then
				warn(`audit: pad ({p.x}, {p.z}) box holds {part:GetFullName()}`)
				bad += 1
			end
		end
	end
	local points, fails, full = 0, 0, 0
	for i = -5, 5 do
		for j = -5, 5 do
			local x, z = i * 10, j * 10
			local r = math.sqrt(x * x + z * z)
			if r >= 20 and r <= 50 then
				local f = Layouts.floorAt(plan, x, z)
				if not Layouts.skipped(plan, x, z, f) then
					points += 1
					local root = C + Vector3.new(x, f + 1.25, z) * STUDS
					local ok, hs = 0, {}
					for _, look in { -Vector3.zAxis, Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis } do
						local hit = fanAt(root, look, params)
						local h = if hit then (hit.Y - C.Y) / STUDS - f else -1
						table.insert(hs, string.format("%.1f", h))
						if h >= 16 then
							ok += 1
						end
					end
					if ok == 4 then
						full += 1
					elseif ok < 3 then
						fails += 1
						warn(`audit: swing fails at ({x}, {z}): {table.concat(hs, " ")}`)
					end
				end
			end
		end
	end
	print(`audit {map.name}: {points} points, {fails} fail, {full} 4-of-4; {bad} pad problems`)
end

return Arenas
