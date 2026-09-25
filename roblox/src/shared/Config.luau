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

-- The dodge (Q): a burst of speed, untouchable for a moment, then a cooldown.
Config.DODGE_COOLDOWN = 1.1
Config.DODGE_IFRAMES = 0.4 -- seconds nothing can hurt you
Config.DODGE_SPEED = 32 -- units a second, for DODGE_TIME
Config.DODGE_TIME = 0.22

-- Which world the server opens on, and how it runs waves.
Config.START_MAP = "times_square"
Config.WAVE_BREAK = 4 -- seconds between waves
Config.WORLD_BREAK = 15 -- seconds between clearing a world and the next one opening
Config.SPAWN_RING = 40 -- units from the world's portal centre that enemies arrive at
Config.MAX_ENEMIES = 24 -- a hard ceiling so summons cannot flood the server

-- Enemies.
Config.ENEMY_THINK_INTERVAL = 0.1
-- How close (web units, 2.4 studs each) a player has to come before an enemy
-- notices them. Until then it wanders near where it arrived. Bosses see a
-- little further. A hit, or a packmate within ENEMY_PACK spotting you, wakes
-- it too; past ENEMY_LEASH it gives up and goes back to wandering.
Config.ENEMY_NOTICE = 18
Config.ENEMY_NOTICE_BOSS = 26
Config.ENEMY_PACK = 9
Config.ENEMY_LEASH = 60
-- A swing starts inside this reach (plus the enemy's size) and lands if the
-- player is still inside the hit reach when the wind-up ends.
Config.ENEMY_SWING_START = 3.2
Config.ENEMY_SWING_HIT = 4.2

-- Sounds. These are files every Roblox client ships with, so they work with
-- no uploads; swap any of them for a library sound ("rbxassetid://123...").
Config.SOUNDS = {
	hit = { id = "rbxasset://sounds/swordslash.wav", volume = 0.35 },
	heavy = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.5 },
	slash = { id = "rbxasset://sounds/swordslash.wav", volume = 0.45 },
	dash = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.5 },
	beam = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4 },
	shot = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.2 },
	hurt = { id = "rbxasset://sounds/collide.wav", volume = 0.6 },
	alert = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35 },
	warn = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	domain = { id = "rbxasset://sounds/HalloweenGhost.wav", volume = 0.6 },
	banner = { id = "rbxasset://sounds/unsheath.wav", volume = 0.4 },
	level = { id = "rbxasset://sounds/victory.wav", volume = 0.5 },
	pickup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3 },
	click = { id = "rbxasset://sounds/button.wav", volume = 0.4 },
}

-- Music for each world, looped. Roblox ships no music, so these start empty:
-- paste a sound's id from the Creator Store ("rbxassetid://123...") for a
-- world, or for `default` to use it everywhere else.
Config.MUSIC = {
	default = "",
	times_square = "",
	jujutsu_high = "",
	star_corridor = "",
	kyoto_academy = "",
	culling_colony = "",
	land_of_wind = "",
	land_of_earth = "",
	land_of_water = "",
	land_of_lightning = "",
} :: { [string]: string }
Config.MUSIC_VOLUME = 0.3

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
