--!strict
-- The tenth world and what lives in it: the Seam, and Hyakunui with the two
-- things it tears out of itself. Hand-written (the rest of the worlds and
-- enemies are exported from the web build), in the same shapes as
-- Data/Maps and Data/Enemies so the rest of the game treats them the same.
-- Distances in web-build units; colours 0xRRGGBB.

local Finale = {}

Finale.MAP = {
	name = "The Seam",
	sub = "between every world",
	seed = 999,
	build = "buildSeam",
	blurb = "The space between every world, stitched shut.",
	sky = 0x14040a,
	fogColor = 0x2a0610,
	fogNear = 50,
	fogFar = 240,
	sunLevel = 1.4,
	hemiSky = 0xff2d55,
	hemiGround = 0x1a0406,
	spawn = { x = 0, y = 0, z = 8 },
	portalCenter = { x = 0, y = 0, z = 6 },
	-- Every enemy here is stitched: an elite, whatever it was before.
	stitched = true,
	waves = {
		{ "clone_ninja", "needle_curse", "storm_wraith", "ember_imp" },
		{ "flame_dancer", "blade_ninja", "iron_curse", "finger_bearer" },
		{ "mahito_b", "kenjaku_b" },
		{ "hyakunui" },
	},
	filler = { "needle_curse", "blade_ninja", "storm_wraith" },
}

Finale.ENEMIES = {
	hyakunui = {
		name = "Hyakunui, the Hundred-Seam",
		hp = 9000,
		atk = 58,
		speed = 6.5,
		size = 1.8,
		nature = "cursed",
		shape = "human",
		grade = "special",
		armor = 0.15,
		boss = true,
		finale = true,
		color = 0xff2d55,
		ranged = { cd = 4.5, speed = 30, power = 38, size = 0.8, burst = 3, spread = 0.2, color = 0xff2d55 },
		charge = { power = 70, speed = 30, cd = 9, time = 0.6, tell = 0.65, range = 24 },
		enrage = { at = 0.2, speed = 1.3, dmg = 1.35 },
	},
	tempest_fox = {
		name = "The Tempest Fox",
		hp = 2400,
		atk = 50,
		speed = 9,
		size = 2.1,
		nature = "wind",
		shape = "wraith",
		grade = "special",
		boss = true,
		color = 0xff8a3d,
		charge = { power = 60, speed = 34, cd = 5, time = 0.7, tell = 0.7, range = 30 },
	},
	the_unbidden = {
		name = "The Unbidden",
		hp = 3000,
		atk = 48,
		speed = 6,
		size = 1.9,
		nature = "physical",
		shape = "golem",
		grade = "special",
		boss = true,
		adapts = true, -- after three hits of one nature, that nature barely hurts it
		color = 0xd9d4cc,
	},
}

Finale.LOOKS = {
	hyakunui = {
		skin = 0xc8b8b0,
		hair = 0x1a1a22,
		hairStyle = "long",
		top = 0x3a0a14,
		bottom = 0x1a1a22,
		eye = 0xff2d55,
	},
}

-- The fight's rhythm: health thresholds between phases, and the attacks.
Finale.PHASE_AT = { 0.66, 0.33 } -- health fractions where phases 2 and 3 begin
Finale.SEAM_CUT = { every = 7, radius = 3.5, warn = 1.2, power = 45 } -- phase 1 on
Finale.GRASP = { every = 9, radius = 4.5, warn = 1.8, share = 0.25 } -- phase 3

--- Which phase a boss at `frac` of its health is in: 1, 2 or 3.
function Finale.phaseOf(frac: number): number
	if frac <= Finale.PHASE_AT[2] then
		return 3
	elseif frac <= Finale.PHASE_AT[1] then
		return 2
	end
	return 1
end

return Finale
