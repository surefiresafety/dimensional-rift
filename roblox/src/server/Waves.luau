--!strict
-- Runs a world's waves: the scripted list, then the boss ladder the exporter
-- appended (alpha, a character boss, then two), then filler forever. Shared by
-- everyone on the server, like the web build's co-op.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rules = require(Shared.Rules)
local Maps = require(Shared.Data.Maps)
local EnemyData = require(Shared.Data.Enemies)
local Skills = require(Shared.Data.Skills)

local Combat = require(script.Parent.Combat)
local Enemies = require(script.Parent.Enemies)
local World = require(script.Parent.World)

local STUDS = Config.STUDS_PER_UNIT
local WaveRemote = Remotes.get("Wave")

local Waves = {}
Waves.index = 0
Waves.running = false

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
	World.load(mapId)
	for _, e in table.clone(Combat.enemies) do
		Combat.kill(e, nil)
	end
	Waves.index = 0
	Waves.running = true
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
	announce()
	if Waves.running and #Combat.enemies == 0 then
		Waves.index += 1
		task.delay(Config.WAVE_BREAK, function()
			if #Combat.enemies == 0 then
				Waves.spawnCurrent()
			end
		end)
	end
end)

return Waves
