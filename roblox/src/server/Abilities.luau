--!strict
-- Every technique type, resolved on the server. Each handler is the web
-- build's castSkill branch for that type, with distances scaled to studs.
--
-- Ported: projectile, melee, dash, beam, trap, pull, yank, teleport, buff,
-- heal, shield, evade, freeze, clones, domain, toggle, and the transform and
-- Mahoraga ultimates. That is 272 of the 280 techniques.
-- Not yet: self (decoy), rewind, switch (weapon/suit sets), possess, devour.
-- Casting one of those refunds it and says so.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local RulesData = require(Shared.Data.Rules)
local Skills = require(Shared.Data.Skills)
local Styles = require(Shared.Data.Styles)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Combat)
local Projectiles = require(script.Parent.Projectiles)

local STUDS = Config.STUDS_PER_UNIT
local CooldownRemote = Remotes.get("Cooldown")

type Ctx = {
	ps: Combat.PState,
	s: any,
	id: string,
	root: BasePart,
	hum: Humanoid,
	origin: Vector3, -- chest height
	dir: Vector3, -- aim, unit
	flat: Vector3, -- aim on the ground plane, unit
	B: number, -- output multiplier (1 until output charge is ported)
}

local function colorOf(s: any): number
	return s.color or RulesData.NATURE[s.nature].color
end

local function onHitOf(s: any, extra: Rules.OnHit?): Rules.OnHit
	local o: any = table.clone(s.onHit or {})
	if s.knock and o.knock == nil then
		o.knock = s.knock
	end
	if s.ignoreDef then
		o.ignoreDef = true
	end
	if extra then
		for k, v in extra :: any do
			o[k] = v
		end
	end
	return o
end

--- The multiplier a technique earns against a target already carrying the
--- status it is built to exploit (Web Swing Kick on something webbed).
local function bonus(s: any, e: Combat.Enemy): number
	if s.bonusStatus and e.status[s.bonusStatus] then
		return s.bonusMul or 1
	end
	return 1
end

local function hit(c: Ctx, e: Combat.Enemy, power: number, from: Vector3?, extra: Rules.OnHit?)
	Combat.hitEnemy(e, power, c.s.nature, from or c.root.Position, onHitOf(c.s, extra), c.ps)
end

local function crit(c: Ctx, e: Combat.Enemy, power: number): number
	local mul, ramp, landed = Rules.rollCrit(c.s.crit, c.ps.flashRamp, math.random())
	c.ps.flashRamp = ramp
	if landed then
		Combat.fx("banner", { text = c.s.crit.tag or "BLACK FLASH", color = c.s.crit.color or 0xff2d55 })
		Combat.fx("burst", { at = e.root.Position, color = c.s.crit.color or 0xff2d55, count = 24 })
	end
	return power * mul
end

local handlers: { [string]: (Ctx) -> boolean? } = {}

handlers.projectile = function(c)
	local s = c.s
	Projectiles.fire({
		pos = c.origin + c.dir * STUDS,
		vel = c.dir * s.speed * STUDS,
		radius = s.radius * STUDS,
		gravity = 4 * STUDS,
		life = 3,
		hitsEnemies = true,
		pierce = if s.pierce == true then 99 elseif type(s.pierce) == "number" then s.pierce else 0,
		color = colorOf(s),
		onHitEnemy = function(e, at)
			if s.aoe then
				Combat.fx("ring", { at = at, radius = s.aoe * STUDS, color = colorOf(s) })
				for _, o in Combat.enemiesNear(at, s.aoe * STUDS) do
					hit(c, o, s.power * c.B * bonus(s, o), at)
				end
			else
				hit(c, e, s.power * c.B * bonus(s, e), at)
			end
		end,
	})
	return true
end

handlers.melee = function(c)
	local s = c.s
	local reach = s.range * STUDS
	Combat.fx("slash", { at = c.origin + c.flat * STUDS * 1.4, dir = c.flat, reach = reach, color = colorOf(s) })
	for _, e in table.clone(Combat.enemies) do
		if e.dead then
			continue
		end
		local to = (e.root.Position - c.root.Position) * Vector3.new(1, 0, 1)
		local inReach = to.Magnitude <= reach + (e.t.size or 1) * STUDS
		local inArc = s.arc == nil or to.Magnitude < 1e-3 or to.Unit:Dot(c.flat) > s.arc
		if inReach and inArc then
			local power = (s.power + (if s.percentMax then e.hum.MaxHealth * s.percentMax else 0)) * c.B * bonus(s, e)
			if s.finisher then
				power *= 1 + s.finisher * (1 - e.hum.Health / e.hum.MaxHealth)
			end
			hit(c, e, crit(c, e, power))
		end
	end
	return true
end

-- Walls stop a dash, a teleport, or a knocked-back body.
local function clearPath(c: Ctx, from: Vector3, to: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, inst in { c.ps.player.Character :: Instance?, workspace:FindFirstChild("Enemies") } do
		if inst then
			table.insert(ignore, inst)
		end
	end
	params.FilterDescendantsInstances = ignore
	local r = workspace:Raycast(from, to - from, params)
	if r then
		return r.Position - (to - from).Unit * 2
	end
	return to
end

handlers.dash = function(c)
	local s = c.s
	local start = c.root.Position
	local finish = clearPath(c, start, start + c.flat * s.range * STUDS)
	c.root.CFrame = CFrame.lookAt(finish, finish + c.flat)
	Combat.fx("dash", { from = start, to = finish, color = colorOf(s) })
	for _, e in table.clone(Combat.enemies) do
		if not e.dead and Projectiles.segDistance(start, finish, e.root.Position) < (2 + (e.t.size or 1)) * STUDS then
			hit(c, e, crit(c, e, s.power * c.B * bonus(s, e)), start)
		end
	end
	return true
end

handlers.beam = function(c)
	local s = c.s
	local from = c.origin
	local to = from + c.dir * s.range * STUDS
	Combat.fx("beam", { from = from, to = to, color = colorOf(s), width = s.radius * STUDS, life = 0.45 })
	for _, e in table.clone(Combat.enemies) do
		if not e.dead and Projectiles.segDistance(from, to, e.root.Position) < (s.radius + (e.t.size or 1)) * STUDS then
			hit(c, e, s.power * c.B * bonus(s, e), from)
		end
	end
	return true
end

handlers.trap = function(c)
	local s = c.s
	local centre = c.root.Position + c.flat * (s.range or 0) * STUDS
	Combat.fx("ring", { at = centre, radius = s.radius * STUDS, color = colorOf(s) })
	for _, e in Combat.enemiesNear(centre, s.radius * STUDS) do
		hit(c, e, s.power * c.B * bonus(s, e), centre)
	end
	return true
end

handlers.pull = function(c)
	local s = c.s
	local centre = c.origin + c.dir * s.range * STUDS
	Combat.fx("ring", { at = centre, radius = s.radius * STUDS, color = colorOf(s), implode = true })
	local caught = Combat.enemiesNear(centre, s.radius * STUDS)
	for _, e in caught do
		e.status.root = math.max(e.status.root or 0, s.duration or 0.9)
	end
	task.delay(s.duration or 0.9, function()
		for _, e in caught do
			if not e.dead then
				e.root.CFrame = CFrame.new(centre:Lerp(e.root.Position, 0.35))
				hit(c, e, s.power * c.B, nil)
			end
		end
	end)
	return true
end

--- The enemy nearest the aim line, inside `range` studs and a forward cone.
local function aimed(c: Ctx, range: number): Combat.Enemy?
	local best, bestScore = nil, math.huge
	for _, e in Combat.enemies do
		if not e.dead then
			local to = e.root.Position - c.origin
			local d = to.Magnitude
			if d <= range and d > 0.1 and to.Unit:Dot(c.dir) > 0.6 then
				local score = Projectiles.segDistance(c.origin, c.origin + c.dir * range, e.root.Position) + d * 0.1
				if score < bestScore then
					best, bestScore = e, score
				end
			end
		end
	end
	return best
end

handlers.yank = function(c)
	local s = c.s
	local e = aimed(c, s.range * STUDS)
	if not e then
		return false
	end
	Combat.fx("beam", { from = c.origin, to = e.root.Position, color = colorOf(s), width = 0.4, life = 0.3 })
	e.root.CFrame = CFrame.new(c.root.Position + c.flat * 2.2 * STUDS)
	e.status.root = math.max(e.status.root or 0, 0.6)
	hit(c, e, s.power * c.B, c.root.Position)
	return true
end

handlers.teleport = function(c)
	local s = c.s
	local e = aimed(c, s.range * STUDS)
	if not e then
		return false
	end
	local start = c.root.Position
	local behind = e.root.Position - c.flat * 2 * STUDS
	c.root.CFrame = CFrame.lookAt(behind, e.root.Position * Vector3.new(1, 0, 1) + Vector3.new(0, behind.Y, 0))
	Combat.fx("dash", { from = start, to = behind, color = colorOf(s) })
	hit(c, e, s.power * c.B, behind)
	return true
end

handlers.buff = function(c)
	local s = c.s
	local now = Combat.now()
	c.ps.buff = {
		untilT = now + s.duration * c.B,
		dmgMul = s.dmgMul or 1,
		speedMul = s.speedMul or 1,
		costMul = s.costMul or 1,
		regen = s.regen or 6,
		leech = if s.onHit then s.onHit.leech or 0 else 0,
		chain = s.chain,
		chainNext = 0,
	}
	if s.shield then
		c.ps.shield = Rules.round(s.shield * c.B)
		c.ps.shieldUntil = now + s.duration * c.B
	end
	Combat.fx("aura", { player = c.ps.player, color = colorOf(s), duration = s.duration * c.B })
	return true
end

handlers.heal = function(c)
	local amount = Rules.round(c.hum.MaxHealth * (c.s.percent or 0.3) * c.B)
	c.hum.Health = math.min(c.hum.MaxHealth, c.hum.Health + amount)
	Combat.fx("number", { at = c.root.Position + Vector3.new(0, 3, 0), text = "+" .. amount, tone = "heal" })
	Combat.fx("ring", { at = c.root.Position, radius = 3 * STUDS, color = 0x56e39f })
	return true
end

handlers.shield = function(c)
	local s = c.s
	c.ps.shield = Rules.round(s.charges * c.B)
	c.ps.shieldUntil = Combat.now() + s.duration
	c.ps.shieldReflect = (s.reflect or 0) * c.B
	if s.heal and c.hum.Health < c.hum.MaxHealth then
		local back = math.min(c.hum.MaxHealth - c.hum.Health, Rules.round(s.heal * c.B))
		c.hum.Health += back
		Combat.fx("number", { at = c.root.Position + Vector3.new(0, 3, 0), text = "+" .. back, tone = "heal" })
	end
	Combat.fx("shield", { player = c.ps.player, color = colorOf(s), duration = s.duration })
	return true
end

handlers.evade = function(c)
	c.ps.evadeUntil = Combat.now() + (c.s.duration or 3)
	Combat.fx("aura", { player = c.ps.player, color = 0xb06cff, duration = c.s.duration or 3 })
	return true
end

handlers.freeze = function(c)
	local s = c.s
	Combat.fx("flash", { color = 0x9fd6ff, duration = s.duration })
	for _, e in table.clone(Combat.enemies) do
		if not e.dead then
			e.status.stun = math.max(e.status.stun or 0, s.duration + (s.hold or 0))
			if s.power then
				hit(c, e, s.power * c.B, nil)
			end
		end
	end
	return true
end

handlers.clones = function(c)
	local s = c.s
	local count = if s.army then 3 + math.random(0, 2) else (s.count or 2)
	local now = Combat.now()
	for i = 1, count do
		table.insert(c.ps.minions, {
			untilT = now + (s.duration or 12),
			power = (s.power or 20) * c.B,
			every = 1 + i * 0.13,
			next = now + i * 0.2,
			radius = 26 * STUDS,
			color = colorOf(s),
		})
	end
	Combat.fx("burst", { at = c.root.Position, color = colorOf(s), count = 10 * count })
	return true
end

handlers.domain = function(c)
	local s = c.s
	local now = Combat.now()
	local radius = (s.radius or 34) * STUDS
	c.ps.domain = {
		untilT = now + (s.duration or 5),
		centre = c.root.Position,
		radius = radius,
		power = (s.power or 30) * c.B,
		tick = s.tick or 1,
		next = now + 0.8,
		stun = s.stun == true or s.mode == "slash",
		nature = s.nature,
	}
	Combat.fx("domain", {
		at = c.root.Position,
		radius = radius,
		title = s.title or string.upper(s.name),
		color = s.color or 0x120a2a,
		edge = s.edge or 0xffffff,
		floor = s.floor or s.color or 0x120a2a,
		open = s.open == true,
		duration = s.duration or 5,
	})
	return true
end

handlers.toggle = function(c)
	c.ps.infinity = not c.ps.infinity
	Combat.notice(c.ps.player, if c.ps.infinity then c.s.name .. " is up." else c.s.name .. " is down.")
	return true
end

-- Set by init: swaps a player into another style's body and kit, or back.
local transformInto: (ps: Combat.PState, into: string?) -> () = function() end

local Abilities = {}
Abilities.setTransform = function(fn: (Combat.PState, string?) -> ())
	transformInto = fn
end

local function sendCooldown(ps: Combat.PState, key: string, readyAt: number, duration: number)
	CooldownRemote:FireClient(ps.player, key, readyAt, duration)
end

--- Resolves a cast. `which` is a slot number (1-5), "ult", or a skill id
--- sent for a signature (E) action. Returns whether it went off.
function Abilities.cast(ps: Combat.PState, which: number | string, aim: Vector3): boolean
	local hum = Combat.humanoidOf(ps.player)
	local root = Combat.rootOf(ps.player)
	if not hum or not root or hum.Health <= 0 or not ps.style then
		return false
	end
	local now = Combat.now()
	local style = Styles[ps.style]
	local id: string?, ult: any = nil, nil
	if which == "ult" then
		ult = style.ultimate
		id = ult.skill
	elseif type(which) == "number" then
		id = ps.slots[which]
	elseif type(which) == "string" and Skills[which] then
		id = which
	end

	-- Cost and cooldown. An ultimate is priced and timed by its own entry.
	local buff = Combat.buffActive(ps)
	local key = if ult then "ult" else id
	if not key then
		return false
	end
	local readyAt = if ult then ps.ultReadyAt else (ps.cooldowns[key] or 0)
	if not style.noCd and readyAt > now then
		return false
	end
	local cost = if ult
		then ult.cost
		else Rules.castCost(Skills[id :: string], { buffCostMul = if buff then buff.costMul else 1 })
	if ps.se < cost then
		Combat.notice(
			ps.player,
			"Not enough Spirit Energy for " .. (if ult then ult.name else Skills[id :: string].name) .. "."
		)
		return false
	end
	local cd = if ult then (style.cdFlat or ult.cd) else Rules.cooldownFor(Skills[id :: string], style)

	-- The transform and Mahoraga ultimates have no technique behind them.
	if ult and not id then
		ps.se -= cost
		ps.regenBlockedUntil = now + Config.SE_REGEN_DELAY
		if cd then
			ps.ultReadyAt = now + cd
			sendCooldown(ps, "ult", ps.ultReadyAt, cd)
		end
		if ult.kind == "transform" then
			if ps.baseStyle and ult.toggle then
				transformInto(ps, nil)
			else
				transformInto(ps, ult.into)
				if ult.duration and not ult.toggle then
					ps.transformUntil = now + ult.duration
				end
			end
		elseif ult.kind == "mahoraga" then
			table.insert(ps.minions, {
				untilT = now + (ult.duration or 30),
				power = 90,
				every = 1.4,
				next = now + 1,
				radius = 40 * STUDS,
				color = 0xd9d4cc,
			})
			Combat.fx("banner", { text = "MAHORAGA", color = 0xd9d4cc })
		end
		return true
	end

	local s = Skills[id :: string]
	local handler = handlers[s.type]
	if not handler then
		Combat.notice(ps.player, s.name .. " (" .. s.type .. ") is not in the Roblox build yet.")
		return false
	end

	local dir = if aim.Magnitude > 0.01 then aim.Unit else root.CFrame.LookVector
	local flat = dir * Vector3.new(1, 0, 1)
	flat = if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local ctx: Ctx = {
		ps = ps,
		s = s,
		id = id :: string,
		root = root,
		hum = hum,
		origin = root.Position + Vector3.new(0, 1.5, 0),
		dir = dir,
		flat = flat.Unit,
		B = 1,
	}

	ps.se -= cost
	ps.regenBlockedUntil = now + Config.SE_REGEN_DELAY
	if handler(ctx) == false then
		-- Nothing to aim at: the energy comes back and nothing locks.
		ps.se += cost
		Combat.notice(ps.player, "Nothing in reach for " .. s.name .. ".")
		return false
	end
	if cd then
		if ult then
			ps.ultReadyAt = now + cd
		else
			ps.cooldowns[key] = now + cd
		end
		sendCooldown(ps, key, now + cd, cd)
	end
	if s.type == "domain" then
		Combat.fx("banner", { text = "DOMAIN EXPANSION", color = s.edge or 0xffffff })
	end
	Combat.publish(ps)
	return true
end

return Abilities
