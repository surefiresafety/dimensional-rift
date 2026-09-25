--!strict
-- Every technique type, resolved on the server. Each handler is the web
-- build's castSkill branch for that type, with distances scaled to studs.
--
-- Every technique type the web build has is here: projectile, melee, dash,
-- beam, trap, pull, yank, teleport, buff, heal, shield, evade, freeze, clones,
-- domain, toggle, self (decoy), rewind, switch (weapon and suit sets), possess
-- and devour, plus the transform and Mahoraga ultimates. The basic attack and
-- output charge (B) live here too, since both go through the same numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local RulesData = require(Shared.Data.Rules)
local Skills = require(Shared.Data.Skills)
local Styles = require(Shared.Data.Styles)
local Arsenals = require(Shared.Data.Arsenals)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Combat)
local Projectiles = require(script.Parent.Projectiles)

local STUDS = Config.STUDS_PER_UNIT
local CooldownRemote = Remotes.get("Cooldown")

local Abilities = {}

type Ctx = {
	ps: Combat.PState,
	s: any,
	id: string,
	root: BasePart,
	hum: Humanoid,
	origin: Vector3, -- chest height
	dir: Vector3, -- aim, unit
	flat: Vector3, -- aim on the ground plane, unit
	B: number, -- output multiplier: 1, or the stored charge being spent
	W: Rules.Weapon?, -- the drawn weapon, for a technique marked weaponScaled
	WM: number, -- the drawn weapon's damage multiplier, or 1
}

local function colorOf(s: any): number
	return s.color or RulesData.NATURE[s.nature].color
end

--- The weapon or suit a player has drawn, if their style carries a set.
local function currentWeapon(ps: Combat.PState): Rules.Weapon?
	local a = ps.style and (Arsenals :: any)[ps.style]
	return if a and ps.weapon then a.items[ps.weapon] else nil
end
Abilities.currentWeapon = currentWeapon

--- Split Soul and the knife: the same blow lands again on the soul a beat
--- later, cursed and through any defence.
function Abilities.soulCut(ps: Combat.PState, e: Combat.Enemy, power: number, delay: number, knock: number)
	task.delay(delay, function()
		local hum = Combat.humanoidOf(ps.player)
		if not e.dead and hum and hum.Health > 0 then
			Combat.hitEnemy(e, power, "cursed", e.root.Position, { knock = knock, ignoreDef = true }, ps)
			Combat.fx("number", { at = e.root.Position + Vector3.new(0, 4, 0), text = "SOUL", tone = "se" })
		end
	end)
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
					hit(c, o, s.power * c.B * c.WM * bonus(s, o), at)
				end
			else
				hit(c, e, s.power * c.B * c.WM * bonus(s, e), at)
			end
		end,
	})
	return true
end

handlers.melee = function(c)
	local s = c.s
	local W = c.W
	local reach = s.range * (if W then W.range or 1 else 1) * STUDS
	local tint = if W and W.color then W.color else colorOf(s)
	Combat.fx("slash", { at = c.origin + c.flat * STUDS * 1.4, dir = c.flat, reach = reach, color = tint })
	for _, e in table.clone(Combat.enemies) do
		if e.dead or not Combat.groundReachable(e, c.root.Position) then
			continue
		end
		local to = (e.root.Position - c.root.Position) * Vector3.new(1, 0, 1)
		local inReach = to.Magnitude <= reach + (e.t.size or 1) * STUDS
		local inArc = s.arc == nil or to.Magnitude < 1e-3 or to.Unit:Dot(c.flat) > s.arc
		if inReach and inArc then
			local power = (s.power * c.WM + (if s.percentMax then e.hum.MaxHealth * s.percentMax else 0))
				* c.B
				* bonus(s, e)
			if s.finisher then
				power *= 1 + s.finisher * (1 - e.hum.Health / e.hum.MaxHealth)
			end
			power = crit(c, e, power)
			if (s.breaksBarrier or (W and W.breaksBarrier)) and e.defMul < 1 then
				e.defMul = 1
				Combat.fx(
					"number",
					{ at = e.root.Position + Vector3.new(0, 4, 0), text = "BARRIER BROKEN", tone = "se" }
				)
			end
			hit(c, e, power, nil, {
				knock = (s.knock or 0) + (if W then W.knock or 0 else 0),
				ignoreDef = if s.ignoreDef or (W and W.ignoreDef) then true else nil,
			})
			-- The Chain of a Thousand Miles drags whatever it hits back in.
			if W and W.pull and not e.dead then
				local pull = (c.root.Position - e.root.Position) * Vector3.new(1, 0, 1)
				if pull.Magnitude > 2 * STUDS then
					local by = math.min(6 * STUDS, pull.Magnitude - 1.6 * STUDS)
					e.root.CFrame += pull.Unit * by
				end
			end
			if s.second then
				local target, second = e, s.second
				task.delay(second.delay, function()
					if not target.dead then
						Combat.hitEnemy(target, second.power * c.B, "cursed", c.root.Position, { knock = 4 }, c.ps)
					end
				end)
			end
			if W and W.soul then
				Abilities.soulCut(c.ps, e, power * W.soul.mul, W.soul.delay, 2)
			end
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
			local ignore = if c.W and c.W.ignoreDef then true else nil
			hit(c, e, crit(c, e, s.power * c.B * c.WM * bonus(s, e)), start, { ignoreDef = ignore })
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

handlers.self = function(c)
	if not c.s.decoy then
		return false
	end
	c.ps.decoy = true
	Combat.fx("burst", { at = c.origin + c.flat * 1.2 * STUDS, color = 0xffffff, count = 10 })
	Combat.notice(c.ps.player, c.s.name .. "! A clone will take the next hit.")
	return true
end

handlers.rewind = function(c)
	local snap = Rules.rewindSnapshot(c.ps.history, Combat.now(), c.s.seconds or 6)
	if not snap then
		return false
	end
	local gained = math.max(0, Rules.round(snap.hp - c.hum.Health))
	local back = Vector3.new(snap.x, snap.y, snap.z)
	Combat.fx("burst", { at = c.root.Position, color = 0x9b6cff, count = 16 })
	c.root.AssemblyLinearVelocity = Vector3.zero
	c.root.CFrame = CFrame.new(back) * c.root.CFrame.Rotation
	c.hum.Health = math.min(c.hum.MaxHealth, math.max(c.hum.Health, snap.hp))
	c.ps.se = math.max(c.ps.se, snap.se)
	Combat.fx("banner", { text = "REVERSE TIME", color = 0x9b6cff })
	Combat.fx("burst", { at = back, color = 0x9b6cff, count = 24 })
	if gained > 0 then
		Combat.fx("number", { at = back + Vector3.new(0, 3, 0), text = "+" .. gained, tone = "heal" })
	end
	Combat.notice(
		c.ps.player,
		`Reverse Time: you are where you were {c.s.seconds or 6} seconds ago{if gained > 0
			then `, {gained} HP back`
			else ""}.`,
		"gold"
	)
	return true
end

handlers.switch = function(c)
	local a = (Arsenals :: any)[c.ps.style :: string]
	if not a then
		return false
	end
	Abilities.cycleWeapon(c.ps)
	return true
end

--- The nearest enemy inside `range` studs whose direction is within the
--- forward cone `dot` of the aim. The web build's Body Swap picks this way.
local function nearestAhead(c: Ctx, range: number, dot: number): Combat.Enemy?
	local best, bestD = nil, range
	for _, e in Combat.enemies do
		if e.dead or not Combat.groundReachable(e, c.root.Position) then
			continue
		end
		local to = e.root.Position - c.root.Position
		local d = to.Magnitude
		if d < bestD and (d < 1e-3 or to.Unit:Dot(c.dir) > dot) then
			best, bestD = e, d
		end
	end
	return best
end

handlers.possess = function(c)
	local s = c.s
	local e = nearestAhead(c, s.range * STUDS, 0.1)
	if not e then
		return false
	end
	-- Out of the fight's enemy list; it walks for its wearer now.
	Combat.take(e)
	e.model.Name = "Worn " .. e.t.name
	e.hum.DisplayName = "Worn  ·  " .. e.t.name
	table.insert(Combat.worn, {
		model = e.model,
		hum = e.hum,
		root = e.root,
		owner = c.ps,
		untilT = Combat.now() + (s.duration or 20),
		next = Combat.now() + 0.5,
		power = (s.power or 40) * c.B,
		nature = e.t.nature,
	})
	local heal = Rules.round((s.heal or 0) * c.B)
	c.hum.Health = math.min(c.hum.MaxHealth, c.hum.Health + heal)
	Combat.fx("burst", { at = e.root.Position, color = 0xb06cff, count = 22 })
	Combat.fx("number", { at = c.root.Position + Vector3.new(0, 3, 0), text = "+" .. heal, tone = "heal" })
	Combat.fx("banner", { text = "BODY TAKEN", color = 0xb06cff })
	Combat.notice(c.ps.player, "You step into the " .. e.t.name .. ". It fights for you now.", "gold")
	return true
end

-- Set by Symbiote: a line of the symbiote's, to its host.
Abilities.say = function(_ps: Combat.PState, _text: string, _loud: boolean?) end

handlers.devour = function(c)
	local s = c.s
	local ps = c.ps
	-- No clock on this one: what stops you feeding is being full.
	if s.hungerGate and ps.hunger > s.hungerGate then
		Combat.notice(ps.player, "The symbiote is not hungry yet.")
		return nil
	end
	local prey = Combat.nearestEnemy(c.root.Position, s.range * STUDS)
	if not prey then
		return false
	end
	local root = c.root
	-- Stun it, root it, stop it, and put it right in front of him at its own
	-- height: a floating thing otherwise drifts back out before the bite.
	local function hold(e: Combat.Enemy)
		e.status.stun = math.max(e.status.stun or 0, 1.4)
		e.status.root = math.max(e.status.root or 0, 1.4)
		e.root.AssemblyLinearVelocity = Vector3.zero
		local dir = (e.root.Position - root.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude < 1e-3 then
			dir = Vector3.zAxis
		end
		local at = root.Position + dir.Unit * 2.2 * STUDS
		e.root.CFrame = CFrame.new(at.X, e.root.Position.Y, at.Z) * e.root.CFrame.Rotation
	end
	for i = 0, 1 do
		Combat.fx("beam", {
			from = c.origin + Vector3.new(if i == 0 then -0.4 else 0.4, 0.2, 0) * STUDS,
			to = prey.root.Position + Vector3.new(0, 1.5, 0),
			color = 0x1a1a24,
			width = 0.3,
			life = 0.45,
		})
	end
	hold(prey)
	local bite = s.power * c.B
	task.delay(0.26, function()
		local hum = Combat.humanoidOf(ps.player)
		if not hum or hum.Health <= 0 then
			return
		end
		if not prey.dead then
			hold(prey)
		end
		local at = if prey.dead then root.Position + Vector3.new(0, 1.5, 0) * STUDS else prey.root.Position
		Combat.fx("burst", { at = at, color = 0xc0294a, count = 26 })
		Combat.fx("burst", { at = at, color = 0x1a1a24, count = 18 })
		-- No knockback: it is being eaten, not punched.
		if not prey.dead then
			Combat.hitEnemy(prey, bite, s.nature, nil, { knock = 0, ignoreDef = true }, ps)
		end
		ps.hunger = math.min(100, ps.hunger + 70)
		Abilities.say(ps, "Good.")
		local before = hum.Health
		hum.Health = hum.MaxHealth
		Combat.fx("number", {
			at = root.Position + Vector3.new(0, 3, 0),
			text = "+" .. Rules.round(hum.MaxHealth - before),
			tone = "heal",
		})
		Combat.fx("banner", { text = "FEED", color = 0xc0294a })
		Combat.publish(ps)
	end)
	return true
end

-- Set by init: swaps a player into another style's body and kit, or back.
local transformInto: (ps: Combat.PState, into: string?) -> () = function() end

Abilities.setTransform = function(fn: (Combat.PState, string?) -> ())
	transformInto = fn
end
function Abilities.transform(ps: Combat.PState, into: string?)
	transformInto(ps, into)
end

local function sendCooldown(ps: Combat.PState, key: string, readyAt: number, duration: number)
	CooldownRemote:FireClient(ps.player, key, readyAt, duration)
end

--- Draws the next weapon or suit in the player's set.
function Abilities.cycleWeapon(ps: Combat.PState): Rules.Weapon?
	local a = ps.style and (Arsenals :: any)[ps.style]
	if not a then
		return nil
	end
	ps.weapon = Rules.nextWeapon(a.order, ps.weapon)
	local w = a.items[ps.weapon :: string]
	local root = Combat.rootOf(ps.player)
	Combat.fx("banner", { text = string.upper(w.name), color = w.color })
	if root then
		Combat.fx("burst", { at = root.Position, color = w.color, count = 18 })
	end
	Combat.notice(ps.player, `Drew the {w.name} ({w.sub}). {w.note}`, "gold")
	Combat.publish(ps)
	return w
end

--- Spends a stored charge on the technique being cast. Returns the damage
--- multiplier and the charge, so a cast that finds nothing can put it back.
local function consumeOutput(ps: Combat.PState): (number, any)
	local o = ps.output
	if not o then
		return 1, nil
	end
	ps.output = nil
	Combat.fx("banner", { text = string.upper(o.name) .. " RELEASED", color = RulesData.OUTPUT_TIERS[o.tier].color })
	return o.dmg, o
end

export type CastOpts = { free: boolean? }

--- Resolves a cast. `which` is a slot number (1-5), "ult", or a skill id
--- (a signature on E, or a forced cast such as the symbiote feeding itself).
--- `opts.free` skips cost and cooldown. Returns whether it went off.
function Abilities.cast(ps: Combat.PState, which: number | string, aim: Vector3, opts: CastOpts?): boolean
	local free = opts ~= nil and opts.free == true
	local hum = Combat.humanoidOf(ps.player)
	local root = Combat.rootOf(ps.player)
	if not hum or not root or hum.Health <= 0 or not ps.style or ps.chargeStart then
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

	-- Cost and cooldown. An ultimate is priced and timed by its own entry. A
	-- drawn weapon scales both for the techniques built around it.
	local buff = Combat.buffActive(ps)
	local key = if ult then "ult" else id
	if not key then
		return false
	end
	local s = id and Skills[id]
	local W = if s and s.weaponScaled and not ult then currentWeapon(ps) else nil
	local readyAt = if ult then ps.ultReadyAt else (ps.cooldowns[key] or 0)
	if not free and not style.noCd and readyAt > now then
		return false
	end
	local costArgs: Rules.CostArgs = {
		weaponCostMul = if W then W.costMul else nil,
		outputCostMul = if ps.output then ps.output.cost else nil,
		buffCostMul = if buff then buff.costMul else nil,
	}
	local cost = if free then 0 elseif ult then Rules.castCost(ult, costArgs) else Rules.castCost(s, costArgs)
	if ps.se < cost then
		Combat.notice(ps.player, "Not enough Spirit Energy for " .. (if ult then ult.name else s.name) .. ".")
		return false
	end
	local cd = if free
		then nil
		elseif ult then (style.cdFlat or ult.cd)
		else Rules.cooldownFor(s, style, if W then W.cdMul else nil)

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

	local handler = handlers[s.type]
	if not handler then
		Combat.notice(ps.player, s.name .. " (" .. s.type .. ") is not in the Roblox build yet.")
		return false
	end

	local dir = if aim.Magnitude > 0.01 then aim.Unit else root.CFrame.LookVector
	local flat = dir * Vector3.new(1, 0, 1)
	flat = if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local B, stored = consumeOutput(ps)
	local ctx: Ctx = {
		ps = ps,
		s = s,
		id = id :: string,
		root = root,
		hum = hum,
		origin = root.Position + Vector3.new(0, 1.5, 0),
		dir = dir,
		flat = flat.Unit,
		B = B,
		W = W,
		WM = if W then W.mul or 1 else 1,
	}

	ps.se -= cost
	ps.regenBlockedUntil = now + Config.SE_REGEN_DELAY
	local went = handler(ctx)
	if went ~= true then
		-- Nothing to aim at: the energy and the charge come back and nothing
		-- locks. A handler that returns nil has already said why.
		ps.se += cost
		ps.output = stored
		if went == false then
			Combat.notice(ps.player, "Nothing in reach for " .. s.name .. ".")
		end
		Combat.publish(ps)
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

--- The basic attack: the style's fist, or whatever weapon is drawn.
function Abilities.strike(ps: Combat.PState, aim: Vector3)
	local hum = Combat.humanoidOf(ps.player)
	local root = Combat.rootOf(ps.player)
	local now = Combat.now()
	if not hum or not root or hum.Health <= 0 or not ps.style or ps.chargeStart or now < ps.strikeReadyAt then
		return
	end
	ps.strikeReadyAt = now + 0.38
	local W = currentWeapon(ps)
	local st = Rules.strike(Styles[ps.style], W, math.random())
	local flat = aim * Vector3.new(1, 0, 1)
	flat = if flat.Magnitude > 0.01 then flat.Unit else (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local reach = st.reach * STUDS
	local tint = if st.blackFlash then 0xff2d55 elseif W and W.color then W.color else 0xffffff
	Combat.fx("slash", { at = root.Position + flat * STUDS * 1.2, dir = flat, reach = reach, color = tint })
	local landed = false
	for _, e in table.clone(Combat.enemies) do
		if e.dead or not Combat.groundReachable(e, root.Position) then
			continue
		end
		local to = (e.root.Position - root.Position) * Vector3.new(1, 0, 1)
		if to.Magnitude <= reach + (e.t.size or 1) * STUDS and (to.Magnitude < 1e-3 or to.Unit:Dot(flat) > 0.3) then
			if st.blackFlash then
				if not landed then
					Combat.fx("banner", { text = "BLACK FLASH", color = 0xff2d55 })
				end
				Combat.fx("burst", { at = e.root.Position, color = 0xff2d55, count = 12 })
				Combat.hitEnemy(e, st.power, "cursed", root.Position, { knock = st.knock }, ps)
			else
				Combat.hitEnemy(
					e,
					st.power,
					"physical",
					root.Position,
					{ knock = st.knock, ignoreDef = if st.ignoreDef then true else nil },
					ps
				)
				if W and W.soul then
					Abilities.soulCut(ps, e, st.power * W.soul.mul, W.soul.delay, 1)
				end
			end
			landed = true
		end
	end
end

--- Hold B: powering up. Nothing else can be cast until it is let go.
function Abilities.startCharge(ps: Combat.PState)
	local hum = Combat.humanoidOf(ps.player)
	if ps.chargeStart or not ps.style or not hum or hum.Health <= 0 then
		return
	end
	ps.chargeStart = Combat.now()
	ps.player:SetAttribute("ChargeStart", ps.chargeStart)
	Combat.notice(ps.player, "Powering up. Hold B: 5 s for Medium Output, 10 s for Maximum.")
end

--- Let go of B: the tier reached is stored for the next technique. Maximum
--- Output also blows everything close away.
function Abilities.releaseCharge(ps: Combat.PState)
	local start = ps.chargeStart
	if not start then
		return
	end
	ps.chargeStart = nil
	ps.player:SetAttribute("ChargeStart", nil)
	local tiers = RulesData.OUTPUT_TIERS
	local i = Rules.outputTier(tiers, Combat.now() - start)
	local tier = tiers[i]
	ps.output = { dmg = tier.dmg, cost = tier.cost, name = tier.name, tier = i }
	Combat.fx("banner", { text = string.upper(tier.name), color = tier.color })
	local off = if tier.cost == 0
		then " and costs nothing"
		elseif tier.cost < 1 then ` at {Rules.round((1 - tier.cost) * 100)}% off`
		else ""
	Combat.notice(ps.player, `{tier.name} stored: your next technique hits for x{tier.dmg}{off}.`, "gold")
	local root = Combat.rootOf(ps.player)
	if root then
		Combat.fx("burst", { at = root.Position, color = tier.color, count = if i == #tiers then 44 else 18 })
		if i == #tiers then
			Combat.fx("ring", { at = root.Position, radius = 14 * STUDS, color = 0xff2d55 })
			for _, e in Combat.enemiesNear(root.Position, 14 * STUDS) do
				Combat.hitEnemy(e, 60, "physical", root.Position, { knock = 26, root = 0.8 }, ps)
			end
		end
	end
	Combat.publish(ps)
end

return Abilities
