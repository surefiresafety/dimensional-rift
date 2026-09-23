--!strict
-- Tuning that belongs to the Roblox build rather than to the design data.

local Config = {}

-- The web build's world is in roughly metre-sized units (a character stands
-- about 2.2 tall). An R15 character is about 5.3 studs, so everything with a
-- length in the data (ranges, radii, speeds) is multiplied by this.
Config.STUDS_PER_UNIT = 2.4

-- The player, matching the web build's defaults.
Config.PLAYER_MAX_HP = 500
Config.PLAYER_MAX_SE = 1000 -- a style can override this with `energy`
Config.PLAYER_NATURE = "physical"
Config.SE_REGEN_PER_SECOND = 40
Config.SE_REGEN_DELAY = 2.5 -- seconds after spending before it starts to come back
Config.WALK_SPEED = 22

-- Which world the server opens on, and how it runs waves.
Config.START_MAP = "times_square"
Config.WAVE_BREAK = 4 -- seconds between waves
Config.SPAWN_RING = 40 -- units from the world's portal centre that enemies arrive at
Config.MAX_ENEMIES = 24 -- a hard ceiling so summons cannot flood the server

-- Enemies.
Config.ENEMY_MELEE_REACH = 2.4 -- units, multiplied by the enemy's size
Config.ENEMY_MELEE_COOLDOWN = 1.1
Config.ENEMY_THINK_INTERVAL = 0.2

return Config
