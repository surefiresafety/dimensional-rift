--!strict
-- Lighting and an arena for each world: its sky, fog, light and time of day,
-- and the themed arena Arenas builds. Drop a Model named after the map id into
-- ServerStorage.Maps and it is used instead of the built one.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Maps = require(Shared.Data.Maps)

local Arenas = require(script.Parent.Arenas)

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
	local arena = if authored then (authored :: Model):Clone() else Arenas.build(mapId, map)
	Lighting.ClockTime = Arenas.clockFor(map)
	-- A built arena lays its own ground; the baseplate stays as a floor under it.
	local base = workspace:FindFirstChild("Baseplate")
	if base and base:IsA("BasePart") then
		base.Transparency = if authored then 0 else 1
	end
	arena.Name = "Arena"
	arena.Parent = workspace
	World.current = mapId
	return map
end

-- The storm world's sky flashes now and then.
task.spawn(function()
	while true do
		task.wait(3 + math.random() * 6)
		local arena = workspace:FindFirstChild("Arena")
		if arena and arena:FindFirstChild("Lightning") then
			local was = Lighting.Brightness
			Lighting.Brightness = was + 4
			task.wait(0.08)
			Lighting.Brightness = was
			task.wait(0.1)
			Lighting.Brightness = was + 2.5
			task.wait(0.06)
			Lighting.Brightness = was
		end
	end
end)

function World.spawnPoint(): Vector3
	local map = Maps[World.current or Config.START_MAP]
	local s = map.spawn or { x = 0, y = 0, z = 8 }
	return Vector3.new(s.x, 0, s.z) * STUDS + Vector3.new(0, 4, 0)
end

return World
