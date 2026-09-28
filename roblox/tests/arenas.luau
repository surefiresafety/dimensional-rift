--!nocheck
-- Builds every world with the real Arenas code on real Roblox instances (Lune),
-- with terrain and physics stubbed:  rojo build default.project.json -o build/DimensionalRift.rbxl
-- then  lune run tests/arenas
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local place = roblox.deserializePlace(fs.readFile("build/DimensionalRift.rbxl"))
local Instance, Vector3, CFrame, Color3, Enum =
	roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

local ws = Instance.new("Model")
ws.Name = "Workspace"
local terrainCalls = 0
local Terrain = setmetatable({}, {
	__index = function(_, k)
		if k == "GetMaterialColor" then
			return function()
				return Color3.new(1, 1, 1)
			end
		end
		if k == "WaterWaveSize" then
			return 0
		end
		return function()
			terrainCalls += 1
		end
	end,
	__newindex = function() end,
})
local tags = 0
local services = {
	ReplicatedStorage = place:GetService("ReplicatedStorage"),
	PhysicsService = {
		IsCollisionGroupRegistered = function()
			return false
		end,
		RegisterCollisionGroup = function() end,
		CollisionGroupSetCollidable = function() end,
	},
	CollectionService = {
		AddTag = function()
			tags += 1
		end,
	},
	Players = {
		GetPlayers = function()
			return {}
		end,
	},
	RunService = {
		IsStudio = function()
			return false
		end,
	},
}
local fakeGame = {
	GetService = function(_, n)
		return services[n] or error("no service " .. n)
	end,
}
local workspaceProxy = setmetatable({ Terrain = Terrain }, {
	__index = function(_, k)
		if k == "FindFirstChild" then
			return function(_, n)
				return ws:FindFirstChild(n)
			end
		end
	end,
})
local cache = {}
local function load(mod)
	if cache[mod] then
		return cache[mod]
	end
	local env = setmetatable({
		script = mod,
		game = fakeGame,
		workspace = workspaceProxy,
		require = function(m)
			return load(m)
		end,
		Instance = Instance,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		ColorSequence = roblox.ColorSequence,
		NumberSequence = roblox.NumberSequence,
		NumberRange = roblox.NumberRange,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		Vector2 = roblox.Vector2,
		UDim2 = roblox.UDim2,
		Random = {
			new = function(seed)
				local r = { s = seed }
				function r:NextNumber(a, b)
					a = a or 0
					b = b or 1
					return a + (b - a) * math.random()
				end
				function r:NextInteger(a, b)
					return math.random(a, b)
				end
				return r
			end,
		},
		warn = function(...)
			print("WARN", ...)
		end,
	}, { __index = _G })
	local fn = luau.load(mod.Source, { debugName = mod:GetFullName(), environment = env })
	local r = fn()
	cache[mod] = r
	return r
end
-- WaitForChild shim on the real instances
local Shared = services.ReplicatedStorage:FindFirstChild("Shared")
services.ReplicatedStorage = setmetatable({}, {
	__index = function(_, k)
		if k == "WaitForChild" then
			return function(_, n)
				return Shared
			end
		end
	end,
})
local Arenas = load(place:GetService("ServerScriptService").Server.Arenas)
local Worlds = load(Shared.Worlds)
for _, id in Worlds.ORDER do
	local map = Worlds.get(id)
	local ok, model = pcall(Arenas.build, id, map)
	if ok then
		local parts, lights = 0, 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
			if d:IsA("Light") then
				lights += 1
			end
		end
		print(
			string.format(
				"%-18s %-22s %4d parts %3d lights  nav pads %d",
				id,
				map.name,
				parts,
				lights,
				#model.Nav:GetChildren()
			)
		)
	else
		print("ERROR", id, model)
	end
end
print("terrain calls", terrainCalls, "spin tags", tags)
