--!strict
-- Runs a world's waves: the scripted list, ending in the boss ladder the
-- exporter appended (alpha, a character boss, then two). When the last one
-- falls the world is cleared and the rift moves everyone on to the next world
-- in MAP_IDS order. Shared by everyone on the server, like the web build's
-- co-op.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rules = require(Shared.Rules)
local Progression = require(Shared.Progression)
local Maps = require(Shared.Data.Maps)
local EnemyData = require(Shared.Data.Enemies)
local Skills = require(Shared.Data.Skills)
local RulesData = require(Shared.Data.Rules)

local Combat = require(script.Parent.Combat)
local Enemies = require(script.Parent.Enemies)
local World = require(script.Parent.World)

local STUDS = Config.STUDS_PER_UNIT
local WaveRemote = Remotes.get("Wave")

local Waves = {}
Waves.index = 0
Waves.running = false
Waves.started = false -- the first player's pick starts the rift; nothing restarts it
Waves.gen = 0 -- bumped by every start, so a timer from an old run does nothing

local clearedHandlers: { (string, number) -> () } = {}
--- A wave fell: the world it was in and its number (1-based).
function Waves.onCleared(fn: (string, number) -> ())
	table.insert(clearedHandlers, fn)
end
local worldHandlers: { (string) -> () } = {}
--- A world's last scripted wave fell. The rift moves on to the next world.
function Waves.onWorldCleared(fn: (string) -> ())
	table.insert(worldHandlers, fn)
end

local function announce()
	WaveRemote:FireAllClients(World.current, Waves.index + 1, #Combat.enemies)
end

function Waves.spawnCurrent()
	local map = Maps[World.current :: string]
	local list = Rules.waveList(map, Waves.index)
	local c = map.portalCenter or { x = 0, y = 0, z = 0 }
	for i, id in list do
		local a = ((i - 1) / math.max(1, #list)) * math.pi * 2 + Waves.index * 0.4
		Enemies.spawn(id, Vector3.new(c.x + math.sin(a) * 17, 0, c.z + math.cos(a) * 17) * STUDS)
	end
	local names = {}
	for _, id in list do
		table.insert(names, EnemyData[id].name)
	end
	Combat.notice(nil, ("Wave %d: %s."):format(Waves.index + 1, table.concat(names, ", ")))
	Combat.fx("banner", { text = "WAVE " .. (Waves.index + 1), color = 0xffd54a })
	announce()
end

function Waves.start(mapId: string)
	-- Not running while the old wave is cleared away, or that counts as a win.
	Waves.running = false
	Waves.started = true
	Waves.gen += 1
	World.load(mapId)
	for _, e in table.clone(Combat.enemies) do
		Combat.kill(e, nil)
	end
	Waves.index = 0
	Waves.running = true
	-- Everyone walks through the rift with the world.
	for player in Combat.states do
		local root = Combat.rootOf(player)
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(World.spawnPoint())
		end
	end
	Waves.spawnCurrent()
end

Combat.onKilled(function(e, by)
	-- What it drops is yours to keep.
	if by and e.t.drops and not by.learned[e.t.drops] then
		by.learned[e.t.drops] = true
		local sk = Skills[e.t.drops]
		if sk then
			Combat.notice(by.player, "You absorbed " .. e.t.name .. "'s technique: " .. sk.name .. ".", "gold")
		end
	end
	if by then
		by.kills += 1
	end
end)

Combat.onGone(function()
	announce()
	if not Waves.running or #Combat.enemies > 0 then
		return
	end
	local mapId = World.current :: string
	local number = Waves.index + 1
	local gen = Waves.gen
	for _, fn in clearedHandlers do
		task.spawn(fn, mapId, number)
	end
	local map = Maps[mapId]
	if number >= #map.waves then
		-- The last scripted wave is the world's last boss: the rift moves on.
		Waves.running = false
		for _, fn in worldHandlers do
			task.spawn(fn, mapId)
		end
		local nextMap = Progression.nextWorld(RulesData.MAP_IDS, mapId)
		Combat.fx("banner", { text = string.upper(map.name) .. " CLEARED", color = 0xffd54a })
		Combat.notice(
			nil,
			`{map.name} is clear. The rift opens onto {Maps[nextMap].name} in {Config.WORLD_BREAK} seconds.`,
			"gold"
		)
		task.delay(Config.WORLD_BREAK, function()
			if Waves.gen == gen then
				Waves.start(nextMap)
			end
		end)
		return
	end
	Waves.index += 1
	task.delay(Config.WAVE_BREAK, function()
		if Waves.gen == gen and Waves.running and #Combat.enemies == 0 then
			Waves.spawnCurrent()
		end
	end)
end)

return Waves
