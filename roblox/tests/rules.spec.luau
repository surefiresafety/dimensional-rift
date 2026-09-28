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

H.test("weapons cycle in order and wrap", function()
	local order = { "a", "b", "c" }
	H.eq(Rules.nextWeapon(order, nil), "a", "nothing drawn")
	H.eq(Rules.nextWeapon(order, "a"), "b", "next")
	H.eq(Rules.nextWeapon(order, "c"), "a", "wraps")
	H.eq(Rules.nextWeapon(order, "zzz"), "a", "unknown starts over")
end)

H.test("reverse time picks the newest snapshot old enough", function()
	local h = {}
	for t = 0, 10 do
		table.insert(h, { t = t, hp = t * 10, se = 0, x = 0, y = 0, z = 0 })
	end
	H.eq((Rules.rewindSnapshot(h, 10, 6) :: any).t, 4, "six seconds back from ten")
	H.eq((Rules.rewindSnapshot(h, 3, 6) :: any).t, 0, "not that much history: the oldest")
	H.eq(Rules.rewindSnapshot({}, 3, 6), nil, "no history at all")
end)

H.test("the suit eats its share, and a torn suit eats nothing", function()
	local eaten, through = Rules.suitAbsorb(100, 0.45, 420, false)
	H.eq(eaten, 45, "venom's share")
	H.eq(through, 55, "the rest")
	eaten, through = Rules.suitAbsorb(100, 0.45, 20, false)
	H.eq(eaten, 20, "only what the suit has left")
	H.eq(through, 80, "the rest goes through")
	eaten = Rules.suitAbsorb(100, 0.45, 420, true)
	H.eq(eaten, 0, "torn")
end)

H.test("the bond: sound is worst, then fire, nothing else touches it", function()
	H.eq(Rules.bondLoss("sound", 10), 8, "sound")
	H.eq(Rules.bondLoss("fire", 10), 5.5, "fire")
	H.eq(Rules.bondLoss("water", 10), 0, "water")
end)

H.test("the basic attack: fist, weapon, Black Flash", function()
	local yuji = { m1 = 16, m1Range = 0.5, m1BlackFlash = 0.7 }
	local fist = Rules.strike({ m1 = 26, m1Range = 2 }, nil, 0.5)
	H.eq(fist.power, 26, "the style's own m1")
	H.near(fist.reach, 4.8, 1e-9, "the style's extra reach")
	H.eq(fist.knock, 5, "a plain knock")
	H.eq(Rules.strike(nil, nil, 0.5).power, 16, "nobody: 16")
	local spear = { name = "Spear", m1 = 34, knock = 4, ignoreDef = true }
	local w = Rules.strike({ m1 = 26, m1Range = 2 }, spear, 0.5)
	H.eq(w.power, 34, "the weapon replaces the fist")
	H.near(w.reach, 2.8, 1e-9, "and none of the style's reach")
	H.near(w.knock, 6.6, 1e-9, "40% of the weapon's knock on top")
	H.eq(w.ignoreDef, true, "armour piercing")
	local bf = Rules.strike(yuji, nil, 0.69)
	H.eq(bf.blackFlash, true, "under the chance")
	H.eq(bf.power, 40, "16 x 2.5")
	H.eq(Rules.strike(yuji, nil, 0.7).blackFlash, false, "at the chance, no")
end)

H.test("hunger drains and says so at 75, 50, 30 and 15", function()
	local h, mark = Rules.hungerStep(76, 0.5, 2)
	H.eq(h, 75, "one a second at 0.5 for two")
	H.eq(mark, 75, "crossed 75")
	h, mark = Rules.hungerStep(75, 0.5, 2)
	H.eq(mark, nil, "already at the mark does not repeat")
	h = Rules.hungerStep(0.2, 0.8, 1)
	H.eq(h, 0, "never under zero")
	-- Venom (0.8 a second) empties from full in 125 seconds.
	local v, t = 100, 0
	while v > 0 do
		v = Rules.hungerStep(v, 0.8, 1 / 60)
		t += 1 / 60
	end
	H.near(t, 125, 0.05, "full to empty")
end)

H.test("the suit mends only when left alone, and knits at a quarter", function()
	local sym = { suit = 260, regen = 9, regenAfter = 5 }
	local hp, broken = Rules.suitRegen(sym, 0, true, 4, 1)
	H.eq(hp, 0, "hurt four seconds ago: nothing")
	H.eq(broken, true, "still torn")
	hp, broken = Rules.suitRegen(sym, 50, true, 6, 1)
	H.eq(hp, 59, "nine a second")
	H.eq(broken, true, "59 is under a quarter of 260")
	hp, broken = Rules.suitRegen(sym, 60, true, 6, 1)
	H.eq(broken, false, "69 is over a quarter")
	hp = Rules.suitRegen(sym, 259, false, 6, 1)
	H.eq(hp, 260, "capped at the suit's health")
end)

H.test("the bond: starving strips it, time alone brings it back", function()
	H.eq(Rules.bondStep(50, 100, 0, 10, 1), 44, "starving, six a second")
	H.eq(Rules.bondStep(3, 100, 0, 10, 1), 0, "never under zero")
	H.eq(Rules.bondStep(50, 100, 60, 10, 1), 53.5, "fed and left alone")
	H.eq(Rules.bondStep(50, 100, 60, 3, 1), 50, "hurt three seconds ago")
	H.eq(Rules.bondStep(0, 100, 60, 10, 1), 0, "gone is gone")
	H.eq(Rules.bondStep(99, 100, 60, 10, 1), 100, "capped")
end)

local function aiInput(over: { [string]: any }): Rules.AiInput
	local i: any = {
		now = 0,
		dist = 100,
		canAct = true,
		alerted = false,
		boss = false,
		notice = 18,
		leash = 60,
		reach = 3.2,
		shotReady = false,
		charge = nil,
		chargeReady = false,
	}
	for k, v in over do
		i[k] = v
	end
	return i
end

H.test("enemies wander until someone comes close, or they are hit", function()
	local ai = { state = "idle", stateUntil = 0 }
	H.eq(Rules.aiStep(ai, aiInput({ dist = 30 })), "idle", "too far to notice")
	H.eq(Rules.aiStep(ai, aiInput({ dist = math.huge })), "idle", "nobody at all")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 17 })), "notice", "inside the notice range")
	H.eq(ai.state, "chase", "and now it hunts")
	local hit = { state = "idle", stateUntil = 0 }
	H.eq(Rules.aiStep(hit, aiInput({ dist = 50, alerted = true })), "notice", "a hit wakes it at any range")
	local boss = { state = "idle", stateUntil = 0 }
	H.eq(Rules.aiStep(boss, aiInput({ dist = 22, notice = 26 })), "notice", "a boss sees further")
end)

H.test("a chaser gives up past its leash", function()
	local ai = { state = "chase", stateUntil = 0 }
	H.eq(Rules.aiStep(ai, aiInput({ dist = 61 })), "giveup", "too far")
	H.eq(ai.state, "idle", "back to wandering")
end)

H.test("a swing is wound up before it lands, and then it recovers", function()
	local ai = { state = "chase", stateUntil = 0 }
	H.eq(Rules.aiStep(ai, aiInput({ dist = 10 })), "chase", "closing in")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 3 })), "windup", "in reach: winds up")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 3, now = 0.5 })), "winding", "not yet")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 3, now = 0.7 })), "strike", "0.7 s later it lands")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 3, now = 1.0 })), "recover", "then a gap to punish")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 3, now = 1.8 })), "chase", "and again")
	local boss = { state = "chase", stateUntil = 0 }
	Rules.aiStep(boss, aiInput({ dist = 3, boss = true }))
	H.eq(Rules.aiStep(boss, aiInput({ dist = 3, now = 0.8, boss = true })), "winding", "a boss winds up longer")
end)

H.test("stunning an enemy mid wind-up cancels the attack", function()
	local ai = { state = "chase", stateUntil = 0 }
	Rules.aiStep(ai, aiInput({ dist = 3 }))
	H.eq(Rules.aiStep(ai, aiInput({ dist = 3, now = 0.3, canAct = false })), "cancel", "stunned")
	H.eq(ai.state, "chase", "it has to start over")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 3, now = 0.4, canAct = false })), "hold", "and cannot while stunned")
end)

H.test("shooters aim before they shoot; chargers tell before they lunge", function()
	local ai = { state = "chase", stateUntil = 0 }
	H.eq(Rules.aiStep(ai, aiInput({ dist = 20, shotReady = true })), "aim", "aims first")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 20, now = 0.8 })), "shoot", "then fires")
	H.eq(Rules.aiStep(ai, aiInput({ dist = 50, shotReady = true })), "chase", "out of shooting range")
	local c = { state = "chase", stateUntil = 0 }
	local charge = { tell = 0.5, time = 0.7, range = 24 }
	H.eq(Rules.aiStep(c, aiInput({ dist = 12, charge = charge, chargeReady = true })), "tell", "the tell")
	H.eq(Rules.aiStep(c, aiInput({ dist = 12, now = 0.5, charge = charge })), "lunge", "then the lunge")
	H.eq(Rules.aiStep(c, aiInput({ dist = 12, now = 0.9, charge = charge })), "lunging", "for its time")
	H.eq(Rules.aiStep(c, aiInput({ dist = 12, now = 1.2, charge = charge })), "endLunge", "then it stops")
	local close = { state = "chase", stateUntil = 0 }
	H.eq(
		Rules.aiStep(close, aiInput({ dist = 4, charge = charge, chargeReady = true })),
		"chase",
		"too close to charge: it walks in"
	)
end)

H.test("elites: none early, more later, never bosses", function()
	H.eq(Rules.rollAffix(1, false, 0, 0), nil, "wave 1")
	H.eq(Rules.rollAffix(2, false, 0, 0), nil, "wave 2")
	H.eq(Rules.rollAffix(9, true, 0, 0), nil, "a boss")
	H.eq(Rules.rollAffix(3, false, 0.079, 0) ~= nil, true, "8% at wave 3")
	H.eq(Rules.rollAffix(3, false, 0.081, 0), nil, "and not more")
	H.eq(Rules.rollAffix(40, false, 0.29, 0) ~= nil, true, "capped at 30%")
	H.eq(Rules.rollAffix(40, false, 0.31, 0), nil, "never above")
	H.eq((Rules.rollAffix(9, false, 0, 0.999) :: any).key, Rules.AFFIXES[#Rules.AFFIXES].key, "the last one")
	local t: any = { name = "Grade 4", hp = 100, atk = 10, speed = 5, size = 1 }
	Rules.applyAffix(t, Rules.AFFIXES[3]) -- giant
	H.eq(t.name, "Giant Grade 4", "named")
	H.eq(t.hp, 180, "tougher")
	H.eq(t.atk, 13, "harder")
	H.near(t.size, 1.3, 1e-9, "bigger")
	H.eq(t.affix, "giant", "marked")
	local a: any = { name = "X", hp = 10, atk = 1, speed = 1, armor = 0.5 }
	Rules.applyAffix(a, Rules.AFFIXES[2]) -- armored
	H.eq(a.armor, 0.6, "armour capped")
end)

H.test("a frenzied enemy winds up faster", function()
	local ai = { state = "chase", stateUntil = 0 }
	Rules.aiStep(ai, aiInput({ dist = 3, tempo = 0.7 }))
	H.near(ai.stateUntil, 0.49, 1e-9, "0.7 x 0.7")
end)

return H
