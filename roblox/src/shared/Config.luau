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
Config.WORLD_BREAK = 15 -- seconds between clearing a world and the next one opening
Config.SPAWN_RING = 40 -- units from the world's portal centre that enemies arrive at
Config.MAX_ENEMIES = 24 -- a hard ceiling so summons cannot flood the server

-- Enemies.
Config.ENEMY_MELEE_REACH = 2.4 -- units, multiplied by the enemy's size
Config.ENEMY_MELEE_COOLDOWN = 1.1
Config.ENEMY_THINK_INTERVAL = 0.2

-- Badges. Create them on the Creator Dashboard and paste each id here; 0 means
-- the badge is not set up and is skipped. Progress is tracked either way.
Config.BADGES = {
	welcome = 0, -- first time in the rift
	first_boss = 0, -- beat a character boss
	world_clear = 0, -- clear a world's last wave
	level_10 = 0,
	level_25 = 0,
	streak_7 = 0, -- a seven-day login streak
	roster_15 = 0, -- fifteen characters on the roster
}

return Config
