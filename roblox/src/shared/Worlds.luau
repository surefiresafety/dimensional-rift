--!strict
-- Every world and every enemy the game can use: the nine exported from the
-- web build (Data/Maps, Data/Enemies) plus the Seam and its bosses (Finale).
-- Anything that looks a world or an enemy up goes through here.

local Shared = script.Parent
local Maps = require(Shared.Data.Maps)
local EnemyData = require(Shared.Data.Enemies)
local EnemyLooks = require(Shared.Data.EnemyLooks)
local RulesData = require(Shared.Data.Rules)
local Finale = require(Shared.Finale)
local Story = require(Shared.Story)

local Worlds = {}

--- The names the Roblox build shows (the design's lead condition 2). Ids,
--- build keys and saved progress are unchanged; the web build keeps its own.
Worlds.NAMES = {
	times_square = "The Crossroads",
	jujutsu_high = "The Hidden Campus",
	star_corridor = "The Ribbed Vault",
	kyoto_academy = "The Walled Compound",
	culling_colony = "The Sealed Block",
	land_of_wind = "Dunewatch",
	land_of_earth = "Quarry Hollow",
	land_of_water = "Mistreach",
	land_of_lightning = "Thunderspire",
} :: { [string]: string }
for id, name in Worlds.NAMES do
	local map = (Maps :: any)[id]
	if map then
		map.name = name
	end
end

--- The rift's order: the nine worlds, then the Seam.
Worlds.ORDER = table.clone(RulesData.MAP_IDS) :: { string }
table.insert(Worlds.ORDER, Story.FINAL)

function Worlds.get(id: string): any
	if id == Story.FINAL then
		return Finale.MAP
	end
	return (Maps :: any)[id]
end

function Worlds.enemy(id: string): any
	return (EnemyData :: any)[id] or (Finale.ENEMIES :: any)[id]
end

function Worlds.look(id: string): any
	return (EnemyLooks :: any)[id] or (Finale.LOOKS :: any)[id]
end

return Worlds
