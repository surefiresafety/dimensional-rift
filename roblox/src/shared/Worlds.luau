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
