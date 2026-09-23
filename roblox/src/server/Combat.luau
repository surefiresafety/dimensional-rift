--!strict
-- The server's view of the fight: every player's combat state, every live
-- enemy, and the two functions everything else calls to hurt them. The
-- arithmetic lives in Shared.Rules; this file applies it to Roblox objects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rules = require(Shared.Rules)
local RulesData = require(Shared.Data.Rules)
local Skills = require(Shared.Data.Skills)
local Styles = require(Shared.Data.Styles)

local rules = Rules.new(RulesData)
local STUDS = Config.STUDS_PER_UNIT
local Fx = Remotes.get("Fx")
local Notice = Remotes.get("Notice")

export type Buff = {
	untilT: number,
	dmgMul: number,
	speedMul: number,
	costMul: number,
	regen: number,
	leech: number,
	chain: { power: number, radius: number, every: number }?,
	chainNext: number,
}

export type Minion = { untilT: number, power: number, every: number, next: number, radius: number, color: number }

export type Domain = {
	untilT: number,
	centre: Vector3,
	radius: number,
	power: number,
	tick: number,
	next: number,
	stun: boolean,
	nature: string,
}

export type PState = {
	player: Player,
	style: string?,
	baseStyle: string?, -- what a transform reverts to
	transformUntil: number?,
	slots: { string },
	learned: { [string]: boolean },
	se: number,
	maxSe: number,
	regenBlockedUntil: number,
	cooldowns: { [string]: number },
	ultReadyAt: number,
	buff: Buff?,
	shield: number,
	shieldUntil: number,
	shieldReflect: number,
	evadeUntil: number,
	infinity: boolean,
	decoy: boolean,
	flashRamp: number,
	minions: { Minion },
	domain: Domain?,
	kills: number,
}

export type Enemy = {
	id: string,
	t: any, -- a per-instance copy of the ENEMIES template: enrage mutates it
	model: Model,
	hum: Humanoid,
	root: BasePart,
	status: Rules.Status,
	clock: Rules.DotClock,
	defMul: number,
	enraged: boolean,
	dead: boolean,
	nextAttack: number,
	nextShot: number,
	nextSummon: number,
}

local Combat = {}
Combat.rules = rules
Combat.states = {} :: { [Player]: PState }
Combat.enemies = {} :: { Enemy }

local killedHandlers: { (Enemy, PState?) -> () } = {}
function Combat.onKilled(fn: (Enemy, PState?) -> ())
	table.insert(killedHandlers, fn)
end

function Combat.now(): number
	return workspace:GetServerTimeNow()
end

function Combat.notice(player: Player?, text: string, tone: string?)
	if player then
		Notice:FireClient(player, text, tone)
	else
		Notice:FireAllClients(text, tone)
	end
end

function Combat.fx(kind: string, payload: { [string]: any })
	Fx:FireAllClients(kind, payload)
end

function Combat.rootOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Combat.humanoidOf(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function Combat.newState(player: Player): PState
	local ps: PState = {
		player = player,
		style = nil,
		slots = {},
		learned = {},
		se = Config.PLAYER_MAX_SE,
		maxSe = Config.PLAYER_MAX_SE,
		regenBlockedUntil = 0,
		cooldowns = {},
		ultReadyAt = 0,
		buff = nil,
		shield = 0,
		shieldUntil = 0,
		shieldReflect = 0,
		evadeUntil = 0,
		infinity = false,
		decoy = false,
		flashRamp = 0,
		minions = {},
		domain = nil,
		kills = 0,
	}
	Combat.states[player] = ps
	return ps
end

--- Publishes the numbers the HUD draws. Health rides on the Humanoid itself.
function Combat.publish(ps: PState)
	local p = ps.player
	p:SetAttribute("SE", if ps.se == math.huge then -1 else math.floor(ps.se))
	p:SetAttribute("MaxSE", if ps.maxSe == math.huge then -1 else ps.maxSe)
	p:SetAttribute("Style", ps.style)
	p:SetAttribute("Slots", table.concat(ps.slots, ","))
	p:SetAttribute("Infinity", ps.infinity)
end

function Combat.buffActive(ps: PState?): Buff?
	if ps and ps.buff and Combat.now() < ps.buff.untilT then
		return ps.buff
	end
	return nil
end

--- Every live enemy whose root is within `radius` studs of `pos`.
function Combat.enemiesNear(pos: Vector3, radius: number): { Enemy }
	local out = {}
	for _, e in Combat.enemies do
		if not e.dead and (e.root.Position - pos).Magnitude <= radius + (e.t.size or 1) * STUDS then
			table.insert(out, e)
		end
	end
	return out
end

function Combat.nearestEnemy(pos: Vector3, radius: number): Enemy?
	local best, bestD = nil, radius
	for _, e in Combat.enemies do
		if not e.dead then
			local d = (e.root.Position - pos).Magnitude
			if d < bestD then
				best, bestD = e, d
			end
		end
	end
	return best
end

local function kill(e: Enemy, by: PState?)
	if e.dead then
		return
	end
	e.dead = true
	e.hum.Health = 0
	-- Out of the live list first: anything listening (Waves) counts what is left.
	local i = table.find(Combat.enemies, e)
	if i then
		table.remove(Combat.enemies, i)
	end
	Combat.fx("burst", { at = e.root.Position, color = e.t.color or RulesData.NATURE[e.t.nature].color, count = 18 })
	for _, fn in killedHandlers do
		task.spawn(fn, e, by)
	end
	task.delay(1.5, function()
		e.model:Destroy()
	end)
end
Combat.kill = kill

--- enemyTakeHit. `from` is where the blow came from, for knockback.
function Combat.hitEnemy(e: Enemy, power: number, nature: string, from: Vector3?, onHit: Rules.OnHit?, by: PState?)
	if e.dead then
		return
	end
	local o: Rules.OnHit = onHit or {}
	local buff = Combat.buffActive(by)
	local style = by and by.style and Styles[by.style]
	local hungerMul = if style and style.symbiote and style.symbiote.hunger then Rules.hungerMul(nil) else 1
	local dmg, eff = rules:damageToEnemy({
		power = power,
		nature = nature,
		targetNature = e.t.nature,
		defMul = e.defMul,
		armor = e.t.armor,
		ignoreDef = o.ignoreDef,
		buffMul = if buff then buff.dmgMul else 1,
		hungerMul = hungerMul,
		roll = math.random(),
	})
	e.hum.Health = math.max(0, e.hum.Health - dmg)

	-- Lifesteal, from the technique or from a rage that feeds.
	local leech = (o.leech or 0) + (if buff then buff.leech else 0)
	if by and leech > 0 then
		local hum = Combat.humanoidOf(by.player)
		if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
			local back = math.max(1, Rules.round(dmg * leech))
			hum.Health = math.min(hum.MaxHealth, hum.Health + back)
			local r = Combat.rootOf(by.player)
			if r then
				Combat.fx("number", { at = r.Position, text = "+" .. back, tone = "heal" })
			end
		end
	end

	-- Some of them get worse when they are losing.
	local enrage = e.t.enrage
	if enrage and not e.enraged and e.hum.Health > 0 and e.hum.Health < e.hum.MaxHealth * (enrage.at or 0.35) then
		e.enraged = true
		e.t.speed *= enrage.speed or 1.4
		e.t.atk = Rules.round(e.t.atk * (enrage.dmg or 1.45))
		if e.t.ranged then
			e.t.ranged.cd *= 0.65
		end
		Combat.fx("burst", { at = e.root.Position, color = 0xff3b3b, count = 22 })
		Combat.notice(nil, e.t.name .. " is enraged.", "gold")
	end

	e.defMul = Rules.applyOnHit(e.status, e.defMul, o)
	Combat.fx("number", {
		at = e.root.Position + Vector3.new(0, 3 * (e.t.size or 1), 0),
		text = tostring(dmg),
		tone = if eff > 1 then "se" elseif eff < 1 then "nve" else "hit",
	})

	if from then
		local k = Rules.knockback(o.knock, e.t.boss, e.t.size) * STUDS
		local push = (e.root.Position - from) * Vector3.new(1, 0, 1)
		if push.Magnitude < 1e-3 then
			push = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		end
		local impulse = push.Unit * k * 0.9 + Vector3.new(0, math.min(11 * STUDS, k * 0.42), 0)
		e.root:ApplyImpulse(impulse * e.root.AssemblyMass)
	end

	if e.hum.Health <= 0 then
		kill(e, by)
	end
end

--- hurtPlayer: Infinity, evasion, shields and decoys first, then the hit.
function Combat.hurtPlayer(ps: PState, atk: number, nature: string, from: Enemy?)
	local hum = Combat.humanoidOf(ps.player)
	local root = Combat.rootOf(ps.player)
	if not hum or not root or hum.Health <= 0 then
		return
	end
	local now = Combat.now()
	local function say(text: string)
		Combat.fx("number", { at = root.Position + Vector3.new(0, 3, 0), text = text, tone = "heal" })
	end
	if ps.infinity then
		return say("INFINITY")
	end
	if now < ps.evadeUntil then
		return say("SPIDER-SENSE")
	end
	if ps.shield > 0 and now < ps.shieldUntil then
		ps.shield -= 1
		say("BLOCKED")
		if ps.shieldReflect > 0 and from and not from.dead then
			Combat.hitEnemy(from, ps.shieldReflect, "lightning", root.Position, { paralyze = 1.5, knock = 8 }, ps)
		end
		return
	end
	if ps.decoy then
		ps.decoy = false
		return say("CLONE!")
	end
	local dmg = rules:damageToPlayer(atk, nature, Config.PLAYER_NATURE, math.random())
	hum.Health = math.max(0, hum.Health - dmg)
	Combat.fx("number", { at = root.Position + Vector3.new(0, 3, 0), text = tostring(dmg), tone = "hurt" })
end

--- Status effects, regen, buffs and anything else that runs on the clock.
function Combat.step(dt: number)
	local now = Combat.now()
	for _, e in table.clone(Combat.enemies) do
		if not e.dead then
			local dot = Rules.tickStatuses(e.status, e.clock, dt, e.hum.MaxHealth)
			if dot > 0 then
				e.hum.Health = math.max(0, e.hum.Health - dot)
				Combat.fx("number", { at = e.root.Position + Vector3.new(0, 3, 0), text = tostring(dot), tone = "nve" })
				if e.hum.Health <= 0 then
					kill(e, nil)
				end
			end
		end
	end

	for _, ps in Combat.states do
		local hum = Combat.humanoidOf(ps.player)
		local root = Combat.rootOf(ps.player)
		if not hum or not root or hum.Health <= 0 then
			continue
		end
		if ps.se < ps.maxSe and now > ps.regenBlockedUntil then
			ps.se = math.min(ps.maxSe, ps.se + Config.SE_REGEN_PER_SECOND * dt)
		end
		local buff = Combat.buffActive(ps)
		hum.WalkSpeed = Config.WALK_SPEED * (if buff then buff.speedMul else 1)
		if buff then
			hum.Health = math.min(hum.MaxHealth, hum.Health + buff.regen * dt)
			if buff.chain and now >= buff.chainNext then
				buff.chainNext = now + buff.chain.every
				local e = Combat.nearestEnemy(root.Position, buff.chain.radius * STUDS)
				if e then
					Combat.fx(
						"beam",
						{ from = root.Position, to = e.root.Position, color = 0xffd54a, width = 0.6, life = 0.2 }
					)
					Combat.hitEnemy(e, buff.chain.power, "lightning", root.Position, { knock = 4 }, ps)
				end
			end
		end
		-- Summoned help: each strikes the nearest thing on its own clock.
		for i = #ps.minions, 1, -1 do
			local m = ps.minions[i]
			if now >= m.untilT then
				table.remove(ps.minions, i)
			elseif now >= m.next then
				m.next = now + m.every
				local e = Combat.nearestEnemy(root.Position, m.radius)
				if e then
					Combat.fx("beam", {
						from = root.Position + Vector3.new(0, 2, 0),
						to = e.root.Position,
						color = m.color,
						width = 0.8,
						life = 0.25,
					})
					Combat.hitEnemy(e, m.power, "physical", root.Position, { knock = 3 }, ps)
				end
			end
		end
		-- A domain: everything inside takes the sure hit on every tick.
		local d = ps.domain
		if d then
			if now >= d.untilT then
				ps.domain = nil
			elseif now >= d.next then
				d.next = now + d.tick
				for _, e in Combat.enemiesNear(d.centre, d.radius) do
					if d.stun then
						e.status.stun = math.max(e.status.stun or 0, d.tick + 0.1)
					end
					Combat.hitEnemy(e, d.power, d.nature, nil, { ignoreDef = true }, ps)
				end
			end
		end
		-- A transformation with a clock runs out.
		if ps.transformUntil and now >= ps.transformUntil then
			ps.transformUntil = nil
			Combat.revert(ps)
		end
		Combat.publish(ps)
	end
end

-- Set by init once Looks is loaded, so transforms can change the body.
Combat.revert = function(_ps: PState) end

--- The technique behind a slot or the ultimate, or nil.
function Combat.skillFor(ps: PState, which: number | string): (string?, any)
	if which == "ult" then
		local st = ps.style and Styles[ps.style]
		local u = st and st.ultimate
		return u and u.skill, u
	end
	local id = ps.slots[which :: number]
	return id, id and Skills[id]
end

return Combat
