--!strict
-- The combat rules, ported line for line from web3d/rift3d.html.
--
-- Nothing in here touches Roblox: no Instances, no services, no clock. Every
-- random number comes in as an argument. That keeps it runnable under Lune
-- (see tests/rules.spec.luau), so the arithmetic can be checked against the web
-- build without opening Studio.

export type OnHit = {
	knock: number?,
	root: number?,
	webbed: number?,
	burn: number?,
	poison: number?,
	paralyze: number?,
	bleed: number?,
	defDown: number?,
	leech: number?,
	ignoreDef: boolean?,
}

export type Crit = { chance: number?, mul: number?, ramp: number?, tag: string?, color: number? }

export type Status = { [string]: number }

local Rules = {}
Rules.__index = Rules

export type Rules = typeof(setmetatable({} :: { beats: { [string]: string } }, Rules))

--- `data` is Shared.Data.Rules.
function Rules.new(data: { BEATS: { [string]: string } }): Rules
	return setmetatable({ beats = data.BEATS }, Rules)
end

-- JavaScript's Math.round: halves go up, towards +infinity.
local function round(x: number): number
	return math.floor(x + 0.5)
end
Rules.round = round

--- The nature wheel. 2 on a weakness, 0.5 on a resistance, 1 otherwise, and 1
--- for anything off the wheel (physical, cursed, sound).
function Rules.effectiveness(self: Rules, attack: string, defend: string): number
	local beats = self.beats
	if beats[attack] == nil or beats[defend] == nil then
		return 1
	end
	if beats[attack] == defend then
		return 2
	end
	if beats[defend] == attack then
		return 0.5
	end
	return 1
end

export type HitArgs = {
	power: number,
	nature: string,
	targetNature: string,
	defMul: number?, -- raised by defDown, capped at 2
	armor: number?, -- the enemy template's flat cut
	ignoreDef: boolean?,
	buffMul: number?,
	hungerMul: number?,
	roll: number, -- uniform 0..1, for the ±10% spread
}

--- enemyTakeHit's damage line.
function Rules.damageToEnemy(self: Rules, a: HitArgs): (number, number)
	local eff = self:effectiveness(a.nature, a.targetNature)
	local def = if a.ignoreDef then 1 else (a.defMul or 1)
	local armour = if a.ignoreDef then 1 else 1 - (a.armor or 0)
	local dmg = round(a.power * eff * def * armour * (a.buffMul or 1) * (a.hungerMul or 1) * (0.9 + a.roll * 0.2))
	return dmg, eff
end

--- hurtPlayer's damage line, before shields, decoys and the symbiote suit.
function Rules.damageToPlayer(self: Rules, atk: number, nature: string, playerNature: string, roll: number): number
	return round(atk * self:effectiveness(nature, playerNature) * (0.9 + roll * 0.2))
end

--- A symbiote that starves hits harder: full is 1, empty is 1.5, linear between.
function Rules.hungerMul(hunger: number?): number
	local h = math.clamp(hunger or 100, 0, 100)
	return 1 + 0.5 * (1 - h / 100)
end

export type CostArgs = { weaponCostMul: number?, outputCostMul: number?, buffCostMul: number? }

function Rules.castCost(skill: { cost: number }, a: CostArgs?): number
	local m = a or {}
	return math.ceil(skill.cost * (m.weaponCostMul or 1) * (m.outputCostMul or 1) * (m.buffCostMul or 1))
end

--- How long a technique locks for. nil means the style ignores cooldowns
--- entirely; a style's cdFlat replaces every cooldown it has.
function Rules.cooldownFor(
	skill: { cd: number? },
	style: { noCd: boolean?, cdFlat: number? }?,
	weaponCdMul: number?
): number?
	if style and style.noCd then
		return nil
	end
	if style and style.cdFlat then
		return style.cdFlat
	end
	return (skill.cd or 0) * (weaponCdMul or 1)
end

--- Black Flash and the Eight Gates. Returns the damage multiplier, the new
--- ramp, and whether it landed. The ramp makes the next attempt likelier every
--- time one misses, and resets on a hit.
function Rules.rollCrit(crit: Crit?, ramp: number, roll: number): (number, number, boolean)
	if not crit then
		return 1, ramp, false
	end
	if roll < (crit.chance or 0) + ramp then
		return crit.mul or 2, 0, true
	end
	return 1, ramp + (crit.ramp or 0), false
end

--- Knockback impulse: bosses shrug off more than half of it, big things more.
function Rules.knockback(knock: number?, isBoss: boolean?, size: number?): number
	return (knock or 3) * (if isBoss then 0.45 else 1) / math.max(0.6, size or 1)
end

--- Applies an attack's riders to an enemy's status table. Returns the new
--- defence multiplier.
function Rules.applyOnHit(status: Status, defMul: number, onHit: OnHit?): number
	if not onHit then
		return defMul
	end
	if onHit.root then
		status.root = onHit.root
	end
	if onHit.defDown then
		defMul = math.min(2, defMul + onHit.defDown)
	end
	if onHit.webbed then
		status.webbed = onHit.webbed
	end
	if onHit.burn then
		status.burn = onHit.burn
	end
	if onHit.poison then
		status.poison = onHit.poison
	end
	if onHit.paralyze then
		status.paralyze = onHit.paralyze
	end
	if onHit.bleed then
		status.bleed = math.max(status.bleed or 0, onHit.bleed)
	end
	return defMul
end

export type DotClock = { burn: number, poison: number, bleed: number }

function Rules.newDotClock(): DotClock
	return { burn = 0, poison = 0, bleed = 0 }
end

--- One frame of status time. Counts every status down, drops the expired
--- ones, then ticks the damage-over-time effects every half second: burn 6,
--- poison 5, bleed 7 plus 1.2% of the target's max health. Returns the damage
--- to deal this frame.
function Rules.tickStatuses(status: Status, clock: DotClock, dt: number, maxHp: number): number
	for k, v in status do
		local left = v - dt
		status[k] = if left <= 0 then nil else left
	end
	local dmg = 0
	if status.burn then
		clock.burn += dt
		if clock.burn > 0.5 then
			clock.burn = 0
			dmg += 6
		end
	end
	if status.poison then
		clock.poison += dt
		if clock.poison > 0.5 then
			clock.poison = 0
			dmg += 5
		end
	end
	if status.bleed then
		clock.bleed += dt
		if clock.bleed > 0.5 then
			clock.bleed = 0
			dmg += round(7 + maxHp * 0.012)
		end
	end
	return dmg
end

--- Movement multiplier for an enemy under crowd control.
function Rules.speedMul(status: Status): number
	if status.root or status.paralyze or status.stun then
		return 0
	end
	if status.webbed then
		return 0.4
	end
	return 1
end

--- The enemies in wave `index` (0-based) of a map. Past the scripted waves it
--- keeps the last one and adds filler, one more per wave.
function Rules.waveList(map: { waves: { { string } }, filler: { string }? }, index: number): { string }
	local waves = map.waves
	local list = table.clone(waves[math.min(index, #waves - 1) + 1])
	if index >= #waves then
		local filler = map.filler or { "grade4" }
		for i = 0, index - #waves do
			table.insert(list, filler[(i % #filler) + 1])
		end
	end
	return list
end

--- The output tier a charge held for `held` seconds reaches.
function Rules.outputTier(tiers: { { at: number } }, held: number): number
	local best = 1
	for i, t in tiers do
		if held >= t.at then
			best = i
		end
	end
	return best
end

return Rules
