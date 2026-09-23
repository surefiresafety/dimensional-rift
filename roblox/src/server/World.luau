--!strict
-- Lighting and a placeholder arena for each world. The web build generates
-- nine cities procedurally; this gives each map its sky, fog and light, plus a
-- ring of blocky towers so there is something to swing from, until real
-- environments are built in Studio. Drop a Model named after the map id into
-- ServerStorage.Maps and it is used instead.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Maps = require(Shared.Data.Maps)

local STUDS = Config.STUDS_PER_UNIT

local World = {}
World.current = nil :: string?

local function light(map: any)
	Lighting.Ambient = Palette.color(map.hemiGround or 0x2b1d44)
	Lighting.OutdoorAmbient = Palette.color(map.hemiSky or 0x8a6cff)
	Lighting.FogColor = Palette.color(map.fogColor or map.sky or 0x1b1030)
	Lighting.FogStart = (map.fogNear or 60) * STUDS
	Lighting.FogEnd = (map.fogFar or 260) * STUDS
	Lighting.Brightness = math.clamp((map.sunLevel or 2) * 0.9, 0.5, 3)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Color = Palette.color(map.sky or 0x1b1030)
	atmosphere.Decay = Palette.color(map.fogColor or 0x2a1848)
	atmosphere.Density = 0.32
	atmosphere.Parent = Lighting
end

local function placeholderArena(map: any, seed: number): Model
	local rng = Random.new(seed)
	local arena = Instance.new("Model")
	local centre = map.portalCenter or { x = 0, y = 0, z = 0 }
	local c = Vector3.new(centre.x, 0, centre.z) * STUDS
	local tint = Palette.color(map.hemiSky or 0x8a6cff)
	for i = 1, 28 do
		local a = (i / 28) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(70, 120) * STUDS
		local h = rng:NextNumber(30, 90) * STUDS
		local w = rng:NextNumber(14, 26) * STUDS
		local tower = Instance.new("Part")
		tower.Anchored = true
		tower.Size = Vector3.new(w, h, w * rng:NextNumber(0.8, 1.3))
		tower.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, h / 2, math.sin(a) * r)) * CFrame.Angles(0, -a, 0)
		tower.Color = Color3.fromRGB(34, 30, 48):Lerp(tint, 0.12)
		tower.Material = Enum.Material.Concrete
		tower.Parent = arena
		-- A lit band near the top so the skyline reads at night.
		local band = Instance.new("Part")
		band.Anchored = true
		band.CanCollide = false
		band.Size = Vector3.new(w + 0.4, 2, tower.Size.Z + 0.4)
		band.CFrame = tower.CFrame * CFrame.new(0, h / 2 - 6, 0)
		band.Color = tint
		band.Material = Enum.Material.Neon
		band.Parent = arena
	end
	return arena
end

--- Loads a world: its lighting, and its arena.
function World.load(mapId: string): any
	local map = Maps[mapId]
	assert(map, "No such map: " .. mapId)
	local old = workspace:FindFirstChild("Arena")
	if old then
		old:Destroy()
	end
	light(map)
	local authored = ServerStorage:FindFirstChild("Maps") and ServerStorage.Maps:FindFirstChild(mapId)
	local arena = if authored then (authored :: Model):Clone() else placeholderArena(map, map.seed or 1)
	arena.Name = "Arena"
	arena.Parent = workspace
	World.current = mapId
	return map
end

function World.spawnPoint(): Vector3
	local map = Maps[World.current or Config.START_MAP]
	local s = map.spawn or { x = 0, y = 0, z = 8 }
	return Vector3.new(s.x, 0, s.z) * STUDS + Vector3.new(0, 4, 0)
end

return World
