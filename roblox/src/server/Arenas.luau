--!strict
-- Builds each world's arena from parts and terrain, so there is somewhere to
-- fight before anyone has built a map by hand. Each world has a theme (from
-- its `build` field in Data/Maps): a neon city, a burning ruin, two academies,
-- a star tomb, a desert, rock country, islands and a storm. Every theme lays
-- ground, cover inside the fighting ring, a skyline outside it, tall things
-- to swing from, weather, and the portal the rift came through.
--
-- Distances are worked in web-build units and scaled by STUDS at the end, like
-- the rest of the port. Everything is anchored and seeded, so a world looks
-- the same every time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local RulesData = require(Shared.Data.Rules)

local STUDS = Config.STUDS_PER_UNIT

local Arenas = {}

type Kit = {
	model: Model,
	rng: Random,
	centre: Vector3, -- studs, on the ground
	tint: Color3,
}

-- Parts --------------------------------------------------------------------

local function part(k: Kit, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for key, v in props do
		(p :: any)[key] = v
	end
	p.Parent = k.model
	return p
end

--- A point on the ground, `r` units out at angle `a` from the centre.
local function around(k: Kit, a: number, r: number, y: number?): Vector3
	return k.centre + Vector3.new(math.cos(a) * r, y or 0, math.sin(a) * r) * STUDS
end

local function light(p: BasePart, colour: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = p
end

local function weather(k: Kit, props: { [string]: any })
	local sky = part(k, {
		Name = "Weather",
		Size = Vector3.new(160, 1, 160) * STUDS,
		CFrame = CFrame.new(k.centre + Vector3.new(0, 60 * STUDS, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.LightInfluence = 0.6
	for key, v in props do
		(e :: any)[key] = v
	end
	e.Parent = sky
end

-- Props --------------------------------------------------------------------

--- A block of a building with rows of lit windows as neon bands.
local function building(k: Kit, at: Vector3, w: number, d: number, h: number, colour: Color3, windows: Color3?)
	local body = part(k, {
		Size = Vector3.new(w, h, d),
		CFrame = CFrame.lookAt(
			at + Vector3.new(0, h / 2, 0),
			k.centre * Vector3.new(1, 0, 1) + Vector3.new(0, h / 2, 0)
		),
		Color = colour,
		Material = Enum.Material.Concrete,
	})
	if windows then
		local rows = math.floor(h / (4 * STUDS))
		for i = 1, math.min(rows, 10) do
			if k.rng:NextNumber() < 0.75 then
				part(k, {
					Size = Vector3.new(w * 0.86, 0.9 * STUDS, 0.3),
					CFrame = body.CFrame * CFrame.new(0, -h / 2 + i * 4 * STUDS, -d / 2 - 0.1),
					Color = windows,
					Material = Enum.Material.Neon,
					CanCollide = false,
					CastShadow = false,
				})
			end
		end
	end
	-- Something on the roof, so the skyline is not all flat tops.
	if k.rng:NextNumber() < 0.6 then
		part(k, {
			Size = Vector3.new(w * 0.3, 2 * STUDS, d * 0.3),
			CFrame = body.CFrame * CFrame.new(k.rng:NextNumber(-0.2, 0.2) * w, h / 2 + STUDS, 0),
			Color = colour:Lerp(Color3.new(0, 0, 0), 0.3),
			Material = Enum.Material.Metal,
		})
	end
	return body
end

local SIGNS = {
	"RIFT NEWS 24/7",
	"SHARD COLA",
	"GRAND OPENING",
	"NOW SHOWING",
	"EVACUATE CALMLY",
	"DAILY BUGLE",
	"SALE 70% OFF",
	"THE SKY IS FINE",
	"MULTIVERSE TOURS",
	"RAMEN ICHIBAN",
}

--- A lit billboard on a building face.
local function billboard(k: Kit, on: BasePart, colour: Color3)
	local w = math.min(on.Size.X * 0.8, 18 * STUDS)
	local h = w * 0.45
	local sign = part(k, {
		Size = Vector3.new(w, h, 0.6),
		CFrame = on.CFrame
			* CFrame.new(0, on.Size.Y / 2 - h / 2 - k.rng:NextNumber(1, 4) * STUDS, -on.Size.Z / 2 - 0.5),
		Color = Color3.new(0.05, 0.05, 0.08),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 2.5
	gui.PixelsPerStud = 12
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = colour:Lerp(Color3.new(0, 0, 0), 0.55)
	t.TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.35)
	t.Text = SIGNS[k.rng:NextInteger(1, #SIGNS)]
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.Parent = gui
	gui.Parent = sign
	light(sign, colour, 30, 2)
end

local function lamp(k: Kit, at: Vector3, colour: Color3, height: number?)
	local h = (height or 7) * STUDS
	part(k, {
		Size = Vector3.new(0.4 * STUDS, h, 0.4 * STUDS),
		CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)),
		Color = Color3.fromRGB(40, 40, 48),
		Material = Enum.Material.Metal,
	})
	local bulb = part(k, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2 * STUDS,
		CFrame = CFrame.new(at + Vector3.new(0, h + 0.4 * STUDS, 0)),
		Color = colour,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	light(bulb, colour, 28, 1.6)
end

local CAR_COLOURS = { 0xd8323c, 0xffd54a, 0x2f6fff, 0xe8e8e8, 0x222228, 0x3ddc97 }

local function car(k: Kit, at: Vector3, yaw: number, wrecked: boolean?)
	local body = part(k, {
		Size = Vector3.new(2 * STUDS, 0.9 * STUDS, 4.2 * STUDS),
		CFrame = CFrame.new(at + Vector3.new(0, 0.9 * STUDS, 0))
			* CFrame.Angles(if wrecked then k.rng:NextNumber(-0.3, 0.3) else 0, yaw, if wrecked then 0.2 else 0),
		Color = if wrecked
			then Color3.fromRGB(60, 52, 48)
			else Palette.color(CAR_COLOURS[k.rng:NextInteger(1, #CAR_COLOURS)]),
		Material = if wrecked then Enum.Material.CorrodedMetal else Enum.Material.SmoothPlastic,
	})
	part(k, {
		Size = Vector3.new(1.8 * STUDS, 0.7 * STUDS, 2.2 * STUDS),
		CFrame = body.CFrame * CFrame.new(0, 0.8 * STUDS, 0.2 * STUDS),
		Color = Color3.fromRGB(30, 40, 55),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(k, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.5 * STUDS, 0.9 * STUDS, 0.9 * STUDS),
				CFrame = body.CFrame * CFrame.new(x * 1 * STUDS, -0.4 * STUDS, z * 1.4 * STUDS),
				Color = Color3.fromRGB(20, 20, 20),
				Material = Enum.Material.Rubber,
			})
		end
	end
	if not wrecked then
		local head = part(k, {
			Size = Vector3.new(1.6 * STUDS, 0.25 * STUDS, 0.1),
			CFrame = body.CFrame * CFrame.new(0, 0, -2.1 * STUDS),
			Color = Color3.fromRGB(255, 250, 220),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		light(head, Color3.fromRGB(255, 244, 214), 18, 1)
	else
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 9
		fire.Parent = body
	end
end

local function tree(k: Kit, at: Vector3, h: number, leaves: Color3, kind: string?)
	local trunkH = h * 0.55
	part(k, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkH, 0.8 * STUDS, 0.8 * STUDS),
		CFrame = CFrame.new(at + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(86, 60, 42),
		Material = Enum.Material.Wood,
	})
	if kind == "cedar" then
		for i = 0, 2 do
			part(k, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1, 0.8, 1) * (h * (0.5 - i * 0.12)),
				CFrame = CFrame.new(at + Vector3.new(0, trunkH + i * h * 0.16, 0)),
				Color = leaves,
				Material = Enum.Material.Grass,
			})
		end
	else
		for _ = 1, 3 do
			part(k, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * h * k.rng:NextNumber(0.35, 0.5),
				CFrame = CFrame.new(
					at
						+ Vector3.new(
							k.rng:NextNumber(-0.15, 0.15) * h,
							trunkH + k.rng:NextNumber(0, 0.15) * h,
							k.rng:NextNumber(-0.15, 0.15) * h
						)
				),
				Color = leaves,
				Material = if kind == "blossom" then Enum.Material.SmoothPlastic else Enum.Material.Grass,
				CanCollide = false,
			})
		end
	end
end

local function rock(k: Kit, at: Vector3, size: number, colour: Color3, material: Enum.Material?)
	part(k, {
		Size = Vector3.new(size * k.rng:NextNumber(0.8, 1.4), size * k.rng:NextNumber(0.6, 1.1), size),
		CFrame = CFrame.new(at + Vector3.new(0, size * 0.3, 0))
			* CFrame.Angles(k.rng:NextNumber(-0.4, 0.4), k.rng:NextNumber(0, 6.28), k.rng:NextNumber(-0.4, 0.4)),
		Color = colour,
		Material = material or Enum.Material.Slate,
	})
end

--- A tall, thin thing a web can hold: a spire, a trunk, an obelisk, a mast.
local function spire(k: Kit, at: Vector3, h: number, colour: Color3, material: Enum.Material, tip: Color3?)
	local w = 1.6 * STUDS
	part(k, {
		Name = "Mast",
		Size = Vector3.new(w, h, w),
		CFrame = CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, k.rng:NextNumber(0, 6.28), 0),
		Color = colour,
		Material = material,
	})
	if tip then
		local t = part(k, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4 * STUDS,
			CFrame = CFrame.new(at + Vector3.new(0, h + 0.6 * STUDS, 0)),
			Color = tip,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		light(t, tip, 40, 1.2)
	end
end

local function torii(k: Kit, at: Vector3, yaw: number, colour: Color3)
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	for _, x in { -1, 1 } do
		part(k, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7 * STUDS, 0.8 * STUDS, 0.8 * STUDS),
			CFrame = cf * CFrame.new(x * 3 * STUDS, 3.5 * STUDS, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = colour,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	part(k, {
		Size = Vector3.new(9 * STUDS, 0.6 * STUDS, 0.9 * STUDS),
		CFrame = cf * CFrame.new(0, 7.1 * STUDS, 0),
		Color = Color3.fromRGB(28, 22, 22),
		Material = Enum.Material.SmoothPlastic,
	})
	part(k, {
		Size = Vector3.new(7.5 * STUDS, 0.4 * STUDS, 0.6 * STUDS),
		CFrame = cf * CFrame.new(0, 6 * STUDS, 0),
		Color = colour,
		Material = Enum.Material.SmoothPlastic,
	})
end

--- A hall with a sweeping two-tier roof: temples, dojos, houses.
local function hall(k: Kit, at: Vector3, w: number, d: number, h: number, wall: Color3, roof: Color3)
	local cf = CFrame.lookAt(at + Vector3.new(0, h / 2, 0), k.centre * Vector3.new(1, 0, 1) + Vector3.new(0, h / 2, 0))
	local body =
		part(k, { Size = Vector3.new(w, h, d), CFrame = cf, Color = wall, Material = Enum.Material.WoodPlanks })
	for i, scale in { 1.3, 0.9 } do
		part(k, {
			Size = Vector3.new(w * scale, 0.8 * STUDS, d * scale),
			CFrame = body.CFrame * CFrame.new(0, h / 2 + (i - 0.5) * 2 * STUDS, 0),
			Color = roof,
			Material = Enum.Material.Slate,
		})
	end
	local door = part(k, {
		Size = Vector3.new(w * 0.25, h * 0.55, 0.3),
		CFrame = body.CFrame * CFrame.new(0, -h * 0.225, -d / 2 - 0.1),
		Color = Color3.fromRGB(255, 196, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	light(door, Color3.fromRGB(255, 190, 120), 20, 1)
end

local function lantern(k: Kit, at: Vector3, glow: Color3)
	part(k, {
		Size = Vector3.new(0.9, 3, 0.9) * STUDS,
		CFrame = CFrame.new(at + Vector3.new(0, 1.5 * STUDS, 0)),
		Color = Color3.fromRGB(120, 116, 110),
		Material = Enum.Material.Slate,
	})
	local g = part(k, {
		Size = Vector3.new(1.3, 1.1, 1.3) * STUDS,
		CFrame = CFrame.new(at + Vector3.new(0, 3.5 * STUDS, 0)),
		Color = glow,
		Material = Enum.Material.Neon,
	})
	light(g, glow, 22, 1.2)
end

local function crystal(k: Kit, at: Vector3, h: number, colour: Color3)
	local c = part(k, {
		Size = Vector3.new(h * 0.35, h, h * 0.35),
		CFrame = CFrame.new(at + Vector3.new(0, h * 0.4, 0))
			* CFrame.Angles(k.rng:NextNumber(-0.35, 0.35), k.rng:NextNumber(0, 6.28), k.rng:NextNumber(-0.35, 0.35)),
		Color = colour,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
	})
	light(c, colour, 24, 1.4)
end

--- The rift itself: a ring of light standing over the centre.
local function portal(k: Kit, colour: Color3)
	local r = 7 * STUDS
	local base = k.centre + Vector3.new(0, r + 3 * STUDS, 0)
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		part(k, {
			Size = Vector3.new(0.8, 1.7, 0.8) * STUDS,
			CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, math.sin(a) * r, 0)) * CFrame.Angles(0, 0, a),
			Color = colour,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
	end
	local core = part(k, {
		Name = "Rift",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, r * 1.9, r * 1.9),
		CFrame = CFrame.new(base) * CFrame.Angles(0, math.pi / 2, 0),
		Color = colour:Lerp(Color3.new(0, 0, 0), 0.5),
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	light(core, colour, 60, 3)
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
end

-- Ground -------------------------------------------------------------------

local SPAN = 150 -- units from the centre that the ground covers

local function ground(k: Kit, material: Enum.Material, colour: Color3?)
	local size = SPAN * 2 * STUDS
	workspace.Terrain:FillBlock(CFrame.new(k.centre + Vector3.new(0, -2, 0)), Vector3.new(size, 4, size), material)
	if colour then
		workspace.Terrain:SetMaterialColor(material, colour)
	end
end

local function slab(k: Kit, at: Vector3, size: Vector3, colour: Color3, material: Enum.Material, yaw: number?)
	return part(k, {
		Size = size,
		CFrame = CFrame.new(at + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw or 0, 0),
		Color = colour,
		Material = material,
	})
end

-- Themes -------------------------------------------------------------------

type Theme = { clock: number, build: (Kit) -> () }

local themes: { [string]: Theme } = {}

--- Neon city at night: roads, traffic, lamps, towers with billboards.
themes.city = {
	clock = 21,
	build = function(k)
		ground(k, Enum.Material.Asphalt, Color3.fromRGB(40, 38, 46))
		-- A crossroads of lane markings through the centre.
		for _, yaw in { 0, math.pi / 2 } do
			for i = -14, 14 do
				slab(
					k,
					k.centre + CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(i * 8, 0, 0) * STUDS),
					Vector3.new(4 * STUDS, 0.1, 0.4 * STUDS),
					Color3.fromRGB(255, 214, 90),
					Enum.Material.Neon,
					yaw
				).CanCollide =
					false
			end
		end
		-- Pavements round the plaza.
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2 + math.pi / 8
			slab(
				k,
				around(k, a, 46),
				Vector3.new(26, 0.5, 10) * STUDS,
				Color3.fromRGB(110, 106, 118),
				Enum.Material.Concrete,
				-a
			)
		end
		-- Traffic caught in the rift: cover inside the ring.
		for _ = 1, 16 do
			car(k, around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(14, 48)), k.rng:NextNumber(0, 6.28))
		end
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2
			lamp(k, around(k, a, 34), Color3.fromRGB(255, 226, 160))
		end
		-- Towers, every one lit, some with a billboard facing the plaza.
		local neon = { 0xff3d7f, 0x3ae0ff, 0xffd54a, 0x9b6cff, 0x3ddc97 }
		for i = 1, 30 do
			local a = i / 30 * math.pi * 2 + k.rng:NextNumber(-0.05, 0.05)
			local h = k.rng:NextNumber(40, 110) * STUDS
			local b = building(
				k,
				around(k, a, k.rng:NextNumber(66, 100)),
				k.rng:NextNumber(14, 24) * STUDS,
				k.rng:NextNumber(14, 22) * STUDS,
				h,
				Color3.fromRGB(38, 34, 52):Lerp(k.tint, 0.1),
				Color3.fromRGB(255, 232, 170)
			)
			if k.rng:NextNumber() < 0.55 then
				billboard(k, b, Palette.color(neon[k.rng:NextInteger(1, #neon)]))
			end
		end
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2 + 0.26
			spire(
				k,
				around(k, a, k.rng:NextNumber(38, 50)),
				k.rng:NextNumber(30, 40) * STUDS,
				Color3.fromRGB(44, 40, 60),
				Enum.Material.Metal,
				k.tint
			)
		end
		weather(k, {
			Color = ColorSequence.new(Color3.fromRGB(255, 140, 90)),
			LightEmission = 1,
			Rate = 12,
			Lifetime = NumberRange.new(6, 10),
			Speed = NumberRange.new(3, 6),
			Size = NumberSequence.new(0.3),
			SpreadAngle = Vector2.new(30, 30),
		})
	end,
}

--- The same city after the colony took it: broken towers, burning wrecks, ash.
themes.ruin = {
	clock = 18.3,
	build = function(k)
		ground(k, Enum.Material.Ground, Color3.fromRGB(70, 62, 56))
		for _ = 1, 18 do
			car(k, around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(12, 50)), k.rng:NextNumber(0, 6.28), true)
		end
		for _ = 1, 40 do
			rock(
				k,
				around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(10, 60)),
				k.rng:NextNumber(1.5, 4) * STUDS,
				Color3.fromRGB(96, 90, 86),
				Enum.Material.Concrete
			)
		end
		for i = 1, 26 do
			local a = i / 26 * math.pi * 2
			local b = building(
				k,
				around(k, a, k.rng:NextNumber(62, 96)),
				k.rng:NextNumber(14, 22) * STUDS,
				k.rng:NextNumber(14, 20) * STUDS,
				k.rng:NextNumber(24, 70) * STUDS,
				Color3.fromRGB(78, 72, 70),
				if k.rng:NextNumber() < 0.3 then Color3.fromRGB(255, 120, 60) else nil
			)
			b.CFrame *= CFrame.Angles(k.rng:NextNumber(-0.08, 0.08), 0, k.rng:NextNumber(-0.08, 0.08))
		end
		for i = 1, 12 do
			spire(
				k,
				around(k, i / 12 * math.pi * 2, k.rng:NextNumber(36, 48)),
				k.rng:NextNumber(28, 38) * STUDS,
				Color3.fromRGB(70, 64, 60),
				Enum.Material.CorrodedMetal
			)
		end
		weather(k, {
			Color = ColorSequence.new(Color3.fromRGB(120, 110, 104)),
			Rate = 60,
			Lifetime = NumberRange.new(8, 12),
			Speed = NumberRange.new(2, 4),
			Size = NumberSequence.new(0.35),
			SpreadAngle = Vector2.new(40, 40),
		})
	end,
}

local function academy(k: Kit, blossom: boolean)
	ground(k, Enum.Material.Grass, Color3.fromRGB(78, 110, 64))
	-- A stone path from the gate to the hall, across the courtyard.
	for i = -10, 10 do
		slab(
			k,
			k.centre + Vector3.new(0, 0, i * 5) * STUDS,
			Vector3.new(7, 0.3, 4.4) * STUDS,
			Color3.fromRGB(150, 146, 138),
			Enum.Material.Cobblestone
		)
	end
	torii(k, k.centre + Vector3.new(0, 0, 52) * STUDS, 0, Color3.fromRGB(200, 40, 34))
	torii(k, k.centre + Vector3.new(0, 0, 28) * STUDS, 0, Color3.fromRGB(200, 40, 34))
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2 + 0.3
		hall(
			k,
			around(k, a, k.rng:NextNumber(64, 80)),
			k.rng:NextNumber(18, 30) * STUDS,
			k.rng:NextNumber(12, 18) * STUDS,
			k.rng:NextNumber(8, 14) * STUDS,
			Color3.fromRGB(150, 104, 70),
			Color3.fromRGB(46, 50, 58)
		)
	end
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		lantern(k, around(k, a, 26), Color3.fromRGB(255, 200, 120))
	end
	local leaves = if blossom then Color3.fromRGB(255, 176, 204) else Color3.fromRGB(58, 104, 60)
	for _ = 1, 26 do
		tree(
			k,
			around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(30, 58)),
			k.rng:NextNumber(10, 16) * STUDS,
			leaves,
			if blossom then "blossom" else nil
		)
	end
	-- Old cedars tall enough to swing from.
	for i = 1, 12 do
		tree(
			k,
			around(k, i / 12 * math.pi * 2 + 0.2, k.rng:NextNumber(38, 50)),
			k.rng:NextNumber(34, 44) * STUDS,
			Color3.fromRGB(40, 78, 48),
			"cedar"
		)
	end
	-- The forest beyond the walls.
	for _ = 1, 50 do
		tree(
			k,
			around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(90, 140)),
			k.rng:NextNumber(24, 40) * STUDS,
			Color3.fromRGB(36, 70, 44),
			"cedar"
		)
	end
	weather(k, {
		Color = ColorSequence.new(if blossom then Color3.fromRGB(255, 190, 214) else Color3.fromRGB(150, 190, 110)),
		Rate = if blossom then 30 else 10,
		Lifetime = NumberRange.new(10, 16),
		Speed = NumberRange.new(2, 4),
		RotSpeed = NumberRange.new(-90, 90),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new(0.5),
		SpreadAngle = Vector2.new(60, 60),
	})
end

themes.academy = {
	clock = 15,
	build = function(k)
		academy(k, false)
	end,
}
themes.kyoto = {
	clock = 17.2,
	build = function(k)
		academy(k, true)
	end,
}

--- A tomb under the stars: black stone, obelisks, crystals, a colonnade.
themes.tomb = {
	clock = 0,
	build = function(k)
		ground(k, Enum.Material.Basalt, Color3.fromRGB(34, 30, 44))
		for i = 1, 24 do
			local a = i / 24 * math.pi * 2
			slab(
				k,
				around(k, a, 56),
				Vector3.new(2.4, 18, 2.4) * STUDS,
				Color3.fromRGB(60, 56, 76),
				Enum.Material.Marble
			)
		end
		for _ = 1, 30 do
			crystal(
				k,
				around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(12, 52)),
				k.rng:NextNumber(3, 8) * STUDS,
				k.tint
			)
		end
		for i = 1, 12 do
			spire(
				k,
				around(k, i / 12 * math.pi * 2 + 0.13, k.rng:NextNumber(36, 48)),
				k.rng:NextNumber(30, 42) * STUDS,
				Color3.fromRGB(28, 26, 36),
				Enum.Material.Basalt,
				k.tint
			)
		end
		for _ = 1, 24 do
			slab(
				k,
				around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(70, 110)),
				Vector3.new(k.rng:NextNumber(8, 16), k.rng:NextNumber(20, 60), k.rng:NextNumber(8, 16)) * STUDS,
				Color3.fromRGB(40, 36, 52),
				Enum.Material.Slate,
				k.rng:NextNumber(0, 6.28)
			)
		end
		weather(k, {
			Color = ColorSequence.new(k.tint, Color3.new(1, 1, 1)),
			LightEmission = 1,
			Rate = 25,
			Lifetime = NumberRange.new(6, 10),
			Speed = NumberRange.new(0.5, 2),
			Size = NumberSequence.new(0.25),
			SpreadAngle = Vector2.new(180, 180),
		})
	end,
}

--- Desert: dunes, sandstone domes and towers, blowing sand.
themes.desert = {
	clock = 13,
	build = function(k)
		ground(k, Enum.Material.Sand, Color3.fromRGB(214, 180, 120))
		for _ = 1, 30 do
			local at = around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(60, 140))
			workspace.Terrain:FillBall(at, k.rng:NextNumber(12, 30) * STUDS, Enum.Material.Sand)
		end
		for i = 1, 12 do
			local at = around(k, i / 12 * math.pi * 2 + 0.2, k.rng:NextNumber(58, 72))
			local r = k.rng:NextNumber(7, 11) * STUDS
			slab(k, at, Vector3.new(r * 2, r, r * 2), Color3.fromRGB(206, 160, 104), Enum.Material.Sandstone)
			part(k, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * r * 1.9,
				CFrame = CFrame.new(at + Vector3.new(0, r, 0)),
				Color = Color3.fromRGB(214, 174, 118),
				Material = Enum.Material.Sandstone,
			})
		end
		for _ = 1, 26 do
			rock(
				k,
				around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(12, 54)),
				k.rng:NextNumber(2, 5) * STUDS,
				Color3.fromRGB(188, 146, 96),
				Enum.Material.Sandstone
			)
		end
		for i = 1, 12 do
			spire(
				k,
				around(k, i / 12 * math.pi * 2, k.rng:NextNumber(36, 48)),
				k.rng:NextNumber(28, 38) * STUDS,
				Color3.fromRGB(196, 150, 96),
				Enum.Material.Sandstone
			)
		end
		weather(k, {
			Color = ColorSequence.new(Color3.fromRGB(230, 196, 140)),
			Rate = 80,
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(10, 18),
			Acceleration = Vector3.new(20, 0, 5),
			Size = NumberSequence.new(0.3),
			Transparency = NumberSequence.new(0.4),
			SpreadAngle = Vector2.new(60, 60),
		})
	end,
}

--- Rock country: boulders, standing spires, cliffs all round.
themes.earth = {
	clock = 16,
	build = function(k)
		ground(k, Enum.Material.Rock, Color3.fromRGB(128, 112, 94))
		for _ = 1, 40 do
			rock(
				k,
				around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(10, 56)),
				k.rng:NextNumber(2, 6) * STUDS,
				Color3.fromRGB(140, 118, 94),
				Enum.Material.Rock
			)
		end
		for i = 1, 14 do
			spire(
				k,
				around(k, i / 14 * math.pi * 2, k.rng:NextNumber(34, 50)),
				k.rng:NextNumber(30, 44) * STUDS,
				Color3.fromRGB(118, 100, 82),
				Enum.Material.Rock
			)
		end
		for _ = 1, 40 do
			local at = around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(80, 140))
			workspace.Terrain:FillBall(at, k.rng:NextNumber(16, 36) * STUDS, Enum.Material.Rock)
		end
		weather(k, {
			Color = ColorSequence.new(Color3.fromRGB(180, 160, 130)),
			Rate = 10,
			Lifetime = NumberRange.new(8, 12),
			Speed = NumberRange.new(1, 3),
			Size = NumberSequence.new(0.4),
			SpreadAngle = Vector2.new(60, 60),
		})
	end,
}

--- Islands: a grass island in open water, stilt houses, bridges, mist.
themes.water = {
	clock = 9.5,
	build = function(k)
		local size = SPAN * 2 * STUDS
		workspace.Terrain:FillBlock(
			CFrame.new(k.centre + Vector3.new(0, -1, 0)),
			Vector3.new(size, 3, size),
			Enum.Material.Water
		)
		workspace.Terrain:FillCylinder(
			CFrame.new(k.centre + Vector3.new(0, -1, 0)),
			4 * STUDS,
			58 * STUDS,
			Enum.Material.Grass
		)
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local at = around(k, a, 74)
			for _, dx in { -1, 1 } do
				for _, dz in { -1, 1 } do
					slab(
						k,
						at + Vector3.new(dx * 4, -4, dz * 3) * STUDS,
						Vector3.new(0.8, 9, 0.8) * STUDS,
						Color3.fromRGB(90, 66, 46),
						Enum.Material.Wood
					)
				end
			end
			hall(
				k,
				at + Vector3.new(0, 5 * STUDS, 0),
				11 * STUDS,
				9 * STUDS,
				6 * STUDS,
				Color3.fromRGB(170, 140, 100),
				Color3.fromRGB(60, 80, 100)
			)
			-- A walkway back to the island.
			slab(
				k,
				around(k, a, 63, 0.3),
				Vector3.new(16, 0.5, 3) * STUDS,
				Color3.fromRGB(120, 92, 64),
				Enum.Material.WoodPlanks,
				-a
			)
		end
		for _ = 1, 18 do
			tree(
				k,
				around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(20, 52)),
				k.rng:NextNumber(10, 16) * STUDS,
				Color3.fromRGB(70, 120, 80)
			)
		end
		for i = 1, 12 do
			spire(
				k,
				around(k, i / 12 * math.pi * 2 + 0.1, k.rng:NextNumber(36, 48)),
				k.rng:NextNumber(28, 38) * STUDS,
				Color3.fromRGB(200, 200, 210),
				Enum.Material.Concrete,
				Color3.fromRGB(150, 220, 255)
			)
		end
		weather(k, {
			Color = ColorSequence.new(Color3.fromRGB(220, 235, 245)),
			Rate = 20,
			Lifetime = NumberRange.new(10, 14),
			Speed = NumberRange.new(0.5, 1.5),
			Size = NumberSequence.new(6),
			Transparency = NumberSequence.new(0.85),
			SpreadAngle = Vector2.new(180, 180),
		})
	end,
}

--- A storm on a mountainside: slate crags, rain, lightning every few seconds.
themes.storm = {
	clock = 19.2,
	build = function(k)
		ground(k, Enum.Material.Slate, Color3.fromRGB(70, 74, 84))
		for _ = 1, 34 do
			rock(
				k,
				around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(12, 56)),
				k.rng:NextNumber(2, 5) * STUDS,
				Color3.fromRGB(78, 82, 94)
			)
		end
		for i = 1, 14 do
			spire(
				k,
				around(k, i / 14 * math.pi * 2, k.rng:NextNumber(34, 50)),
				k.rng:NextNumber(30, 44) * STUDS,
				Color3.fromRGB(58, 62, 72),
				Enum.Material.Slate,
				Color3.fromRGB(255, 240, 120)
			)
		end
		for _ = 1, 36 do
			local at = around(k, k.rng:NextNumber(0, 6.28), k.rng:NextNumber(80, 140))
			workspace.Terrain:FillBall(at, k.rng:NextNumber(18, 40) * STUDS, Enum.Material.Slate)
		end
		weather(k, {
			Color = ColorSequence.new(Color3.fromRGB(180, 200, 230)),
			Rate = 300,
			Lifetime = NumberRange.new(1.5, 2),
			Speed = NumberRange.new(60, 80),
			Size = NumberSequence.new(0.12),
			Squash = NumberSequence.new(3),
			Transparency = NumberSequence.new(0.3),
			SpreadAngle = Vector2.new(5, 5),
		})
		local flash = Instance.new("BoolValue")
		flash.Name = "Lightning" -- World reads this and flashes the sky
		flash.Parent = k.model
	end,
}

local THEME_OF: { [string]: string } = {
	buildTimesSquare = "city",
	buildCullingColony = "ruin",
	buildJujutsuHigh = "academy",
	buildKyoto = "kyoto",
	buildStarCorridor = "tomb",
	buildLandOfWind = "desert",
	buildLandOfEarth = "earth",
	buildLandOfWater = "water",
	buildLandOfLightning = "storm",
}

--- The time of day a world's theme is set at.
function Arenas.clockFor(map: any): number
	local t = themes[THEME_OF[map.build or ""] or "city"]
	return t.clock
end

--- Builds a world's arena. Clears the terrain first; returns the model.
function Arenas.build(mapId: string, map: any): Model
	workspace.Terrain:Clear()
	local c = map.portalCenter or { x = 0, y = 0, z = 0 }
	local k: Kit = {
		model = Instance.new("Model"),
		rng = Random.new(map.seed or 1),
		centre = Vector3.new(c.x, 0, c.z) * STUDS,
		tint = Palette.color((RulesData.PORTAL_COLOR :: any)[mapId] or map.hemiSky or 0x8a6cff),
	}
	local theme = themes[THEME_OF[map.build or ""] or "city"]
	theme.build(k)
	portal(k, k.tint)
	return k.model
end

return Arenas
