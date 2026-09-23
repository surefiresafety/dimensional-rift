--!strict
-- The combat rules, checked against the web build. Expected values come from
-- the formulas in web3d/rift3d.html (enemyTakeHit, hurtPlayer, rollCrit, the
-- status loop in updateEnemies), run with the same inputs.

local H = require("./harness")
local Rules = require("../src/shared/Rules")
local RulesData = require("../src/shared/Data/Rules")

local rules = Rules.new(RulesData)

print("Rules")

H.test("the nature wheel", function()
	H.eq(rules:effectiveness("fire", "wind"), 2, "fire on wind")
	H.eq(rules:effectiveness("wind", "fire"), 0.5, "wind on fire")
	H.eq(rules:effectiveness("water", "fire"), 2, "water on fire")
	H.eq(rules:effectiveness("lightning", "lightning"), 1, "mirror match")
	H.eq(rules:effectiveness("cursed", "fire"), 1, "off the wheel")
	H.eq(rules:effectiveness("sound", "earth"), 1, "sound is off the wheel")
end)

H.test("damage to an enemy: weakness, armour and defence", function()
	local base = { power = 100, nature = "fire", targetNature = "wind", roll = 0.5 }
	H.eq((rules:damageToEnemy(base)), 200, "super effective")
	H.eq(
		(rules:damageToEnemy({ power = 100, nature = "fire", targetNature = "wind", roll = 0.5, armor = 0.2 })),
		160,
		"armour cut"
	)
	H.eq((rules:damageToEnemy({
		power = 100,
		nature = "fire",
		targetNature = "wind",
		roll = 0.5,
		armor = 0.2,
		defMul = 1.5,
	})), 240, "defence down")
	H.eq((rules:damageToEnemy({
		power = 100,
		nature = "fire",
		targetNature = "wind",
		roll = 0.5,
		armor = 0.2,
		defMul = 1.5,
		ignoreDef = true,
	})), 200, "ignoring defence skips both")
	H.eq(
		(rules:damageToEnemy({ power = 100, nature = "physical", targetNature = "earth", roll = 0.5, buffMul = 2.2 })),
		220,
		"buff multiplier"
	)
end)

H.test("damage spread is ±10%", function()
	H.eq((rules:damageToEnemy({ power = 100, nature = "physical", targetNature = "earth", roll = 0 })), 90, "low roll")
	H.eq(
		(rules:damageToEnemy({ power = 100, nature = "physical", targetNature = "earth", roll = 1 })),
		110,
		"high roll"
	)
end)

H.test("rounding matches JavaScript's Math.round", function()
	H.eq(Rules.round(2.5), 3, "half up")
	H.eq(Rules.round(-2.5), -2, "negative half goes up too")
	H.eq(Rules.round(2.49), 2, "just under")
end)

H.test("damage to the player", function()
	H.eq(rules:damageToPlayer(40, "fire", "physical", 0.5), 40, "neutral")
	H.eq(rules:damageToPlayer(40, "fire", "wind", 0.5), 80, "a wind player takes double from fire")
end)

H.test("hunger makes a symbiote hit harder", function()
	H.eq(Rules.hungerMul(100), 1, "full")
	H.eq(Rules.hungerMul(0), 1.5, "empty")
	H.eq(Rules.hungerMul(50), 1.25, "half")
	H.eq(Rules.hungerMul(nil), 1, "no hunger at all")
end)

H.test("cost is rounded up after every discount", function()
	H.eq(Rules.castCost({ cost = 15 }), 15, "plain")
	H.eq(Rules.castCost({ cost = 15 }, { buffCostMul = 0.6 }), 9, "Gate of Life")
	H.eq(Rules.castCost({ cost = 10 }, { weaponCostMul = 0.55 }), 6, "5.5 rounds up")
end)

H.test("cooldowns: normal, flat, none, and weapon-scaled", function()
	H.eq(Rules.cooldownFor({ cd = 4 }, {}), 4, "plain")
	H.eq(Rules.cooldownFor({ cd = 4 }, { cdFlat = 0.5 }), 0.5, "Gojo's half second")
	H.eq(Rules.cooldownFor({ cd = 4 }, { noCd = true }), nil, "no cooldown at all")
	H.eq(Rules.cooldownFor({ cd = 4 }, {}, 0.5), 2, "Slaughter Demon halves it")
end)

H.test("crit rolls and the ramp", function()
	local crit = { chance = 0.45, mul = 2.6, ramp = 0.08 }
	local mul, ramp, landed = Rules.rollCrit(crit, 0, 0.3)
	H.eq(mul, 2.6, "landed multiplier")
	H.eq(ramp, 0, "ramp resets on a hit")
	H.eq(landed, true, "landed")
	mul, ramp, landed = Rules.rollCrit(crit, 0, 0.9)
	H.eq(mul, 1, "a miss does nothing")
	H.eq(ramp, 0.08, "and builds the ramp")
	-- The ramp carries: 0.45 + 0.08 = 0.53 now beats a 0.5 roll.
	mul = Rules.rollCrit(crit, ramp, 0.5)
	H.eq(mul, 2.6, "the ramp turns a near miss into a hit")
	H.eq((Rules.rollCrit(nil, 0.2, 0)), 1, "no crit table")
end)

H.test("knockback: bosses and big things shrug more of it off", function()
	H.eq(Rules.knockback(10, false, 1), 10, "plain")
	H.eq(Rules.knockback(10, true, 1), 4.5, "a boss")
	H.eq(Rules.knockback(10, false, 2), 5, "twice the size")
	H.eq(Rules.knockback(nil, false, 0.3), 5, "default 3, and small things cap at 0.6")
end)

H.test("status riders", function()
	local st = {}
	local def = Rules.applyOnHit(st, 1, { root = 2.5, defDown = 0.3, burn = 3, bleed = 4 })
	H.eq(st.root, 2.5, "root")
	H.eq(st.burn, 3, "burn")
	H.eq(st.bleed, 4, "bleed")
	H.near(def, 1.3, 1e-9, "defence down")
	Rules.applyOnHit(st, def, { bleed = 2 })
	H.eq(st.bleed, 4, "a shorter bleed does not cut a longer one")
	H.eq(Rules.applyOnHit(st, 1.9, { defDown = 0.5 }), 2, "defence down caps at 2")
end)

-- Web reference: 60 fps for the given seconds, status applied once at t=0.
local function simulate(name: string, duration: number, maxHp: number, seconds: number): number
	local st: Rules.Status = { [name] = duration }
	local clock = Rules.newDotClock()
	local total = 0
	for _ = 1, math.floor(seconds * 60 + 0.5) do
		total += Rules.tickStatuses(st, clock, 1 / 60, maxHp)
	end
	return total
end

H.test("damage over time matches the web build to the point", function()
	H.eq(simulate("burn", 3, 1000, 5), 30, "burn for 3s")
	H.eq(simulate("poison", 6, 1000, 8), 55, "poison for 6s")
	H.eq(simulate("bleed", 4, 1000, 6), 133, "bleed for 4s on a 1000 HP target")
	H.eq(simulate("bleed", 4, 300, 6), 77, "bleed for 4s on a 300 HP target")
end)

H.test("crowd control stops or slows movement", function()
	H.eq(Rules.speedMul({}), 1, "free")
	H.eq(Rules.speedMul({ webbed = 1 }), 0.4, "webbed")
	H.eq(Rules.speedMul({ root = 1, webbed = 1 }), 0, "rooted wins")
	H.eq(Rules.speedMul({ stun = 1 }), 0, "stunned")
end)

H.test("waves: scripted, then the last one plus filler", function()
	local map = { waves = { { "a" }, { "b", "c" } }, filler = { "x", "y" } }
	H.eq(table.concat(Rules.waveList(map, 0), ","), "a", "wave 1")
	H.eq(table.concat(Rules.waveList(map, 1), ","), "b,c", "wave 2")
	H.eq(table.concat(Rules.waveList(map, 2), ","), "b,c,x", "one past the script")
	H.eq(table.concat(Rules.waveList(map, 4), ","), "b,c,x,y,x", "three past")
	H.eq(#map.waves[2], 2, "the map's own table is not modified")
end)

H.test("output tiers", function()
	local tiers = RulesData.OUTPUT_TIERS
	H.eq(Rules.outputTier(tiers, 0), 1, "tap")
	H.eq(Rules.outputTier(tiers, 5), 2, "five seconds")
	H.eq(Rules.outputTier(tiers, 12), 3, "ten and over")
end)

return H
