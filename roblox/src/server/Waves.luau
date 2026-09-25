--!strict
-- Runs a world's waves: the scripted list, ending in the boss ladder the
-- exporter appended (alpha, a character boss, then two). When the last one
-- falls the world is cleared and the rift moves everyone on to the next world
-- in MAP_IDS order. Shared by everyone on the server, like the web build's
-- co-op.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Worlds)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rules = require(Shared.Rules)
local Progression = require(Shared.Progression)
local Skills = require(Shared.Data.Skills)

local Combat = require(script.Parent.Combat)
local Enemies = require(script.Parent.Enemies)
local World = require(script.Parent.World)
local Pickups = require(script.Parent.Pickups)
local Nav = require(script.Parent.Nav)

local STUDS = Config.STUDS_PER_UNIT
local WaveRemote = Remotes.get("Wave")

local Waves = {}
Waves.index = 0
Waves.running = false
Waves.started = false -- the first player's pick starts the rift; nothing restarts it
Waves.gen = 0 -- bumped by every start, so a timer from an old run does nothing
Waves.clearing = false -- true while an old world's leftovers are removed
-- 1, or 2 for Loose Threads: the harder tier once someone has closed the rift.
Waves.tier = 1
--- Set by Progress: the tier a world starts at, from who is playing.
Waves.tierFor = function(_mapId: string): number
	return 1
end

local clearedHandlers: { (string, number) -> () } = {}
--- A wave fell: the world it was in and its number (1-based).
function Waves.onCleared(fn: (string, number) -> ())
	table.insert(clearedHandlers, fn)
end
local startedHandlers: { (string) -> () } = {}
--- A world's first wave is about to arrive.
function Waves.onStarted(fn: (string) -> ())
	table.insert(startedHandlers, fn)
end
local worldHandlers: { (string) -> () } = {}
--- A world's last scripted wave fell. The rift moves on to the next world.
function Waves.onWorldCleared(fn: (string) -> ())
	table.insert(worldHandlers, fn)
end

local function announce()
	WaveRemote:FireAllClients(World.current, Waves.index + 1, #Combat.enemies)
end

-- Pad -> stamp of its last pick. Keyed per build: cleared whenever the Nav part changes.
local used: { [Attachment]: number } = {}
local usedNav: Instance? = nil
local stamp = 0
local waveStart = 0 -- stamp when the current wave began (set by spawnCurrent)

--- In-place Fisher-Yates.
local function shuffle<T>(t: { T }): { T }
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

--- Flat distance from `at` to the nearest living player's root (math.huge if none).
local function playerGap(at: Vector3): number
	local gap = math.huge
	for player in Combat.states do
		local root = Combat.rootOf(player)
		if root then
			gap = math.min(gap, ((root.Position - at) * Vector3.new(1, 0, 1)).Magnitude)
		end
	end
	return gap
end

--- Where a pack (or a boss) arrives. With a Nav part the answer is always one of
--- its Pad attachments and `centre` is ignored; without one it samples the ring
--- round `centre`. Either way, out of notice range of every player if it can be.
function Waves.spawnSpot(centre: Vector3, boss: boolean?): Vector3
	local need = ((if boss then Config.ENEMY_NOTICE_BOSS else Config.ENEMY_NOTICE) + 6) * STUDS
	local arena = workspace:FindFirstChild("Arena")
	local nav = arena and arena:FindFirstChild("Nav")
	if nav then
		if nav ~= usedNav then
			table.clear(used)
			usedNav, stamp, waveStart = nav, 0, 0
		end
		local fresh, freshBoss, all = {}, {}, {}
		for _, a in nav:GetChildren() do
			if a:IsA("Attachment") and a.Name == "Pad" then
				local isBoss = a:GetAttribute("Boss") == true
				if boss and not isBoss then
					continue
				end
				table.insert(all, a)
				if (used[a] or 0) <= waveStart then -- not picked yet this wave
					table.insert(if isBoss and not boss then freshBoss else fresh, a)
				end
			end
		end
		if #all > 0 then
			-- Normal packs: this wave's unused non-boss pads, then unused boss pads,
			-- both shuffled; then every pad, least recently used first. Bosses:
			-- unused boss pads shuffled, then boss pads by LRU.
			local order: { Attachment }
			if #fresh > 0 then
				order = shuffle(fresh)
			elseif #freshBoss > 0 then
				order = shuffle(freshBoss)
			else
				table.sort(all, function(p, q)
					return (used[p] or 0) < (used[q] or 0)
				end)
				order = all
			end
			local pick, bestGap = order[1], -1
			for _, a in order do
				local gap = playerGap(a.WorldPosition)
				if gap >= need then
					pick = a
					break
				end
				if gap > bestGap then
					pick, bestGap = a, gap
				end
			end
			stamp += 1
			used[pick] = stamp
			return pick.WorldPosition
		end
	end
	-- No Nav, or a Nav with no pads (an authored map): sample the ring, and
	-- keep out of anything solid and out of water.
	local best, bestGap = centre, -1
	for _ = 1, 12 do
		local a = math.random() * math.pi * 2
		local r = (20 + math.random() * 30) * STUDS
		local spot = centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if Nav.isClear(spot) then
			local gap = playerGap(spot)
			if gap >= need then
				return spot
			end
			if gap > bestGap then
				best, bestGap = spot, gap
			end
		end
	end
	return best
end

function Waves.spawnCurrent()
	local map = Worlds.get(World.current :: string)
	local list = Rules.waveList(map, Waves.index)
	local c = map.portalCenter or { x = 0, y = 0, z = 0 }
	-- Spread over the arena and out of sight range of everyone, in small
	-- packs, so a wave is something to go and find rather than a crowd that
	-- arrives on top of you. Bosses stand alone.
	local centre = Vector3.new(c.x, 0, c.z) * STUDS
	waveStart = stamp -- every pad is fresh again for a new wave
	local packAt: Vector3? = nil
	for i, id in list do
		local boss = Worlds.enemy(id) and Worlds.enemy(id).boss
		if boss or not packAt or (i % 3) == 1 then
			packAt = Waves.spawnSpot(centre, boss == true)
		end
		local jitter = if boss then Vector3.zero else Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)) * STUDS
		-- The Seam stitches everything into an elite; Loose Threads makes
		-- elites commoner and everything tougher.
		local bonus = (if map.stitched then 1 else 0) + (if Waves.tier > 1 then 0.15 else 0)
		local affix = Rules.rollAffix(Waves.index + 1, boss, math.random(), math.random(), bonus)
		Enemies.spawn(id, (packAt :: Vector3) + jitter, affix, if Waves.tier > 1 then 1.6 else 1)
	end
	local names = {}
	for _, id in list do
		table.insert(names, Worlds.enemy(id).name)
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
	-- Whatever was left of the old world goes without dropping anything.
	Waves.clearing = true
	for _, e in table.clone(Combat.enemies) do
		e.affix = nil -- a volatile elite cleared away does not go off in the next world
		Combat.kill(e, nil)
	end
	Waves.clearing = false
	Pickups.clear()
	Waves.index = 0
	Waves.tier = Waves.tierFor(mapId)
	Waves.running = true
	for _, fn in startedHandlers do
		task.spawn(fn, mapId)
	end
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
	local map = Worlds.get(mapId)
	if number >= #map.waves then
		-- The last scripted wave is the world's last boss: the rift moves on.
		Waves.running = false
		for _, fn in worldHandlers do
			task.spawn(fn, mapId)
		end
		local nextMap = Progression.nextWorld(Worlds.ORDER, mapId)
		Combat.fx("banner", { text = string.upper(map.name) .. " CLEARED", color = 0xffd54a })
		Combat.notice(
			nil,
			`{map.name} is clear. The rift opens onto {Worlds.get(nextMap).name} in {Config.WORLD_BREAK} seconds.`,
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
	WaveRemote:FireAllClients(mapId, Waves.index + 1, 0, Config.WAVE_BREAK)
	task.delay(Config.WAVE_BREAK, function()
		if Waves.gen == gen and Waves.running and #Combat.enemies == 0 then
			Waves.spawnCurrent()
		end
	end)
end)

return Waves
