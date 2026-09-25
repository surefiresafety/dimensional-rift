--!strict
-- The server's view of the fight: every player's combat state, every live
-- enemy, and the two functions everything else calls to hurt them. The
-- arithmetic lives in Shared.Rules; this file applies it to Roblox objects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	-- Basic attack, dodge and output charge.
	strikeReadyAt: number,
	nextDodge: number,
	invulnUntil: number,
	dodgedAt: number, -- when the last dodge began: a hit soon after it is a perfect dodge
	perfectUsed: boolean, -- one perfect per dodge
	chargeStart: number?,
	output: { dmg: number, cost: number, name: string, tier: number }?,
	-- Weapon and suit sets, and the rewind history (oldest first).
	weapon: string?,
	history: { Rules.Snapshot },
	historyNext: number,
	-- R: tendrils, limbs and webbing on their own.
	autoAttack: boolean,
	limbCd: { number },
	webCd: number,
	-- The symbiote: its own health, its hunger, and how well it holds on.
	suitHp: number?,
	suitBroken: boolean,
	suitHurtAt: number,
	hunger: number,
	bond: number,
	bondWarned: boolean,
	feeding: boolean,
	feedTry: number,
	symChat: number,
	symbioteCd: number,
	looseSuit: { untilT: number, host: string, at: Vector3, part: BasePart }?,
	-- A character with a takeover (the Vessel) gets one save per life.
	takeoverUsed: boolean,
	-- Reloading the body (a transform): nothing else may start one meanwhile.
	reloading: boolean,
	-- Permanent upgrades (Progress.applyUpgrades): 1 until the save loads.
	powerMul: number,
	spiritMul: number,
	moveMul: number,
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
	nextShot: number,
	nextSummon: number,
	-- Its mind (Rules.aiStep): idle until it notices someone, then chase,
	-- and every attack telegraphed first.
	state: string,
	stateUntil: number,
	alerted: boolean, -- hit, or told by a packmate: notices on its next think
	home: Vector3, -- where it wanders around while idle
	wanderTo: Vector3?,
	nextWander: number,
	lungeDir: Vector3?,
	lungeHit: boolean,
	nextCharge: number,
	nextAura: number,
	-- Roblox's standard R15 animations, played from the server so everyone
	-- sees them: idle, walk, run and a slash for attacks.
	anims: { [string]: AnimationTrack },
	affix: Rules.Affix?, -- an elite's modifier
	summoned: boolean, -- called up by another enemy: drops nothing
	adapted: { [string]: number }?, -- the Unbidden: hits taken per nature
	moving: string?,
	-- Worn by Kenjaku's Body Swap: it fights for its wearer until this runs out.
	allyOf: PState?,
	allyUntil: number,
	-- A melee enemy that cannot reach its target lobs rocks instead (Nav).
	tossing: boolean?,
}

local Combat = {}
Combat.rules = rules
Combat.states = {} :: { [Player]: PState }
Combat.enemies = {} :: { Enemy }

local killedHandlers: { (Enemy, PState?) -> () } = {}
function Combat.onKilled(fn: (Enemy, PState?) -> ())
	table.insert(killedHandlers, fn)
end

-- Things a player did, for quests and stats: "cast", "output", "crit",
-- "strike" and "damage" (with the amount).
local eventHandlers: { (PState, string, number) -> () } = {}
function Combat.onEvent(fn: (PState, string, number) -> ())
	table.insert(eventHandlers, fn)
end
function Combat.emit(ps: PState?, kind: string, amount: number?)
	if not ps then
		return
	end
	for _, fn in eventHandlers do
		fn(ps, kind, amount or 1)
	end
end

-- Anything leaving the fight: killed, or taken (Body Swap wears it).
local goneHandlers: { (Enemy) -> () } = {}
function Combat.onGone(fn: (Enemy) -> ())
	table.insert(goneHandlers, fn)
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
		strikeReadyAt = 0,
		nextDodge = 0,
		invulnUntil = 0,
		dodgedAt = -99,
		perfectUsed = false,
		chargeStart = nil,
		output = nil,
		weapon = nil,
		history = {},
		historyNext = 0,
		autoAttack = false,
		limbCd = {},
		webCd = 0,
		suitHp = nil,
		suitBroken = false,
		suitHurtAt = -99,
		hunger = 100,
		bond = RulesData.BOND_MAX,
		bondWarned = false,
		feeding = false,
		feedTry = 0,
		symChat = 14,
		symbioteCd = 0,
		looseSuit = nil,
		takeoverUsed = false,
		reloading = false,
		powerMul = 1,
		spiritMul = 1,
		moveMul = 1,
	}
	Combat.states[player] = ps
	return ps
end

--- Infinity only stays up for a kit that can take it down again: without a
--- toggle in the slots it would be permanent invulnerability.
function Combat.checkInfinity(ps: PState)
	for _, id in ps.slots do
		if Skills[id] and Skills[id].type == "toggle" then
			return
		end
	end
	ps.infinity = false
end

--- Publishes the numbers the HUD draws. Health rides on the Humanoid itself.
function Combat.publish(ps: PState)
	local p = ps.player
	p:SetAttribute("SE", if ps.se == math.huge then -1 else math.floor(ps.se))
	p:SetAttribute("MaxSE", if ps.maxSe == math.huge then -1 else ps.maxSe)
	p:SetAttribute("Style", ps.style)
	p:SetAttribute("BaseStyle", ps.baseStyle) -- set while transformed
	p:SetAttribute("Slots", table.concat(ps.slots, ","))
	p:SetAttribute("Infinity", ps.infinity)
	local st = ps.style and Styles[ps.style]
	local sym = st and st.symbiote
	p:SetAttribute("SuitMax", if sym then sym.suit else nil)
	p:SetAttribute("Suit", if sym then math.floor(ps.suitHp or sym.suit) else nil)
	p:SetAttribute("Hunger", if sym and sym.hunger then math.floor(ps.hunger) else nil)
	p:SetAttribute("Bond", if sym then math.floor(ps.bond) else nil)
	p:SetAttribute("Output", if ps.output then ps.output.name else nil)
	p:SetAttribute("Weapon", ps.weapon)
	p:SetAttribute("Auto", ps.autoAttack)
	p:SetAttribute("LooseSuit", ps.looseSuit ~= nil)
	local learned = {}
	for id in ps.learned do
		table.insert(learned, id)
	end
	table.sort(learned)
	p:SetAttribute("Learned", table.concat(learned, ","))
end

function Combat.buffActive(ps: PState?): Buff?
	if ps and ps.buff and Combat.now() < ps.buff.untilT then
		return ps.buff
	end
	return nil
end

--- A craft ten metres up is out of reach of fists, blades and tendrils.
function Combat.groundReachable(e: Enemy, from: Vector3): boolean
	return not (e.t.visitor and e.root.Position.Y - from.Y > 4 * STUDS)
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

-- Out of the live list first: anything listening (Waves) counts what is left.
local function remove(e: Enemy)
	e.dead = true
	local i = table.find(Combat.enemies, e)
	if i then
		table.remove(Combat.enemies, i)
	end
end

local function kill(e: Enemy, by: PState?)
	if e.dead then
		return
	end
	remove(e)
	e.hum.Health = 0
	Combat.fx("burst", { at = e.root.Position, color = e.t.color or RulesData.NATURE[e.t.nature].color, count = 18 })
	for _, fn in killedHandlers do
		task.spawn(fn, e, by)
	end
	for _, fn in goneHandlers do
		task.spawn(fn, e)
	end
	-- It topples and fades rather than standing there until it vanishes.
	for _, t in e.anims do
		t:Stop(0.1)
	end
	e.root:ApplyImpulse((Vector3.new(math.random() - 0.5, 0.6, math.random() - 0.5) * 30) * e.root.AssemblyMass)
	for _, d in e.model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			TweenService:Create(d, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			}):Play()
		end
	end
	task.delay(1.5, function()
		e.model:Destroy()
	end)
end
Combat.kill = kill

--- Takes an enemy out of the fight without killing it: no drop, no kill, but
--- the wave counts it gone. The model is left for whoever took it.
function Combat.take(e: Enemy)
	if e.dead then
		return
	end
	remove(e)
	-- It is on your side now: off the radar, no boss bar, out of the enemies.
	e.model:SetAttribute("Hunting", false)
	e.model:SetAttribute("Boss", false)
	for _, t in e.anims do
		t:Stop(0.2)
	end
	local worn = workspace:FindFirstChild("Worn")
	if not worn then
		worn = Instance.new("Folder")
		worn.Name = "Worn"
		worn.Parent = workspace
	end
	e.model.Parent = worn
	for _, fn in goneHandlers do
		task.spawn(fn, e)
	end
end

--- enemyTakeHit. `from` is where the blow came from, for knockback.
function Combat.hitEnemy(e: Enemy, power: number, nature: string, from: Vector3?, onHit: Rules.OnHit?, by: PState?)
	if e.dead then
		return
	end
	local o: Rules.OnHit = onHit or {}
	local buff = Combat.buffActive(by)
	local style = by and by.style and Styles[by.style]
	local hungerMul = if by
			and style
			and style.symbiote
			and style.symbiote.hunger
		then Rules.hungerMul(by.hunger)
		else 1
	-- The Unbidden learns each nature after three hits of it.
	local adaptMul = 1
	if e.t.adapts then
		e.adapted = e.adapted or {}
		local adapted
		adaptMul, adapted = Rules.adapt(e.adapted :: { [string]: number }, nature)
		if adapted and (e.adapted :: any)[nature] == 4 then
			Combat.fx("number", { at = e.root.Position + Vector3.new(0, 5, 0), text = "ADAPTED", tone = "nve" })
		end
	end
	local dmg, eff = rules:damageToEnemy({
		power = power,
		nature = nature,
		targetNature = e.t.nature,
		defMul = e.defMul,
		armor = e.t.armor,
		ignoreDef = o.ignoreDef,
		buffMul = (if buff then buff.dmgMul else 1) * (if by then by.powerMul else 1) * adaptMul,
		hungerMul = hungerMul,
		roll = math.random(),
	})
	Combat.emit(by, "damage", math.min(dmg, e.hum.Health))
	e.hum.Health = math.max(0, e.hum.Health - dmg)
	e.alerted = true -- nobody gets hit and keeps wandering

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

--- Set by Symbiote: what a hit does to the bond, and whether the suit panics.
Combat.afterHurt = function(_ps: PState, _dmg: number, _nature: string) end
--- Set by init: a style with a takeover (the Vessel) is saved once per life.
Combat.onLethal = function(_ps: PState): boolean
	return false
end
Combat.lastHitBy = {} :: { [Player]: string }

--- hurtPlayer: Infinity, evasion, shields and decoys first, then the hit.
--- `passive`: damage over time (an aura) that a perfect dodge cannot answer.
function Combat.hurtPlayer(ps: PState, atk: number, nature: string, from: Enemy?, passive: boolean?)
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
	if now < ps.invulnUntil then
		-- Slipping a blow in the first moments of a dodge is a perfect dodge:
		-- energy back, and the moment called out.
		if from and not passive and not ps.perfectUsed and now - ps.dodgedAt < 0.3 then
			ps.perfectUsed = true
			if ps.se ~= math.huge then
				ps.se = math.min(ps.maxSe, ps.se + 60)
			end
			Combat.fx("number", { at = root.Position + Vector3.new(0, 4, 0), text = "PERFECT  +60 SE", tone = "se" })
			Combat.fx("burst", { at = root.Position, color = 0xb06cff, count = 16 })
			Combat.emit(ps, "perfect")
			return
		end
		return say("DODGED")
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
	-- The symbiote takes its share first, out of its own health.
	local st = ps.style and Styles[ps.style]
	local sym = st and st.symbiote
	if sym then
		ps.suitHurtAt = now
		ps.suitHp = ps.suitHp or sym.suit
		local eaten, through = Rules.suitAbsorb(dmg, sym.absorb, ps.suitHp :: number, ps.suitBroken)
		if eaten > 0 then
			ps.suitHp = (ps.suitHp :: number) - eaten
			dmg = through
			Combat.fx("number", { at = root.Position + Vector3.new(2, 3.5, 0), text = "-" .. eaten, tone = "nve" })
		end
		if (ps.suitHp :: number) <= 0 and not ps.suitBroken then
			ps.suitBroken = true
			Combat.fx("banner", { text = "SUIT TORN", color = 0xc0294a })
			Combat.notice(
				ps.player,
				"The symbiote is torn open. It stops covering you until it knits back together.",
				"gold"
			)
		end
	end
	if from then
		Combat.lastHitBy[ps.player] = from.t.name
	end
	if hum.Health - dmg <= 0 and Combat.onLethal(ps) then
		return
	end
	hum.Health = math.max(0, hum.Health - dmg)
	Combat.fx("number", { at = root.Position + Vector3.new(0, 3, 0), text = tostring(dmg), tone = "hurt" })
	-- A vampiric elite drinks what it deals.
	local vamp = from and from.affix and from.affix.vampiric
	if from and vamp and not from.dead then
		from.hum.Health = math.min(from.hum.MaxHealth, from.hum.Health + dmg * vamp)
		Combat.fx(
			"number",
			{ at = from.root.Position + Vector3.new(0, 4, 0), text = "+" .. Rules.round(dmg * vamp), tone = "heal" }
		)
	end
	Combat.afterHurt(ps, dmg, nature)
end

export type Worn = {
	model: Model,
	hum: Humanoid,
	root: BasePart,
	owner: PState,
	untilT: number,
	next: number,
	power: number,
	nature: string,
}
--- Bodies taken by Body Swap: out of the fight's enemy list, fighting for
--- their wearer until the time runs out.
Combat.worn = {} :: { Worn }

local function stepWorn(now: number)
	for i = #Combat.worn, 1, -1 do
		local w = Combat.worn[i]
		if now >= w.untilT or w.hum.Health <= 0 or not w.model.Parent then
			table.remove(Combat.worn, i)
			Combat.fx("burst", { at = w.root.Position, color = 0xb06cff, count = 16 })
			w.model:Destroy()
			continue
		end
		local e = Combat.nearestEnemy(w.root.Position, 60 * STUDS)
		if e then
			w.hum:MoveTo(e.root.Position)
			if now >= w.next and (e.root.Position - w.root.Position).Magnitude < 4 * STUDS then
				w.next = now + 0.9
				Combat.hitEnemy(e, w.power, w.nature, w.root.Position, { knock = 6 }, w.owner)
			end
		end
	end
end

-- The HUD's numbers go out ten times a second, not every frame.
local nextPublish: { [PState]: number } = setmetatable({}, { __mode = "k" }) :: any

--- Status effects, regen, buffs and anything else that runs on the clock.
function Combat.step(dt: number)
	local now = Combat.now()
	stepWorn(now)
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
		-- Reverse Time's memory: a snapshot every half second, twelve seconds deep.
		if now >= ps.historyNext then
			ps.historyNext = now + 0.5
			local p = root.Position
			table.insert(ps.history, { t = now, hp = hum.Health, se = ps.se, x = p.X, y = p.Y, z = p.Z })
			while #ps.history > 0 and now - ps.history[1].t > 12 do
				table.remove(ps.history, 1)
			end
		end
		if ps.se < ps.maxSe and now > ps.regenBlockedUntil then
			ps.se = math.min(ps.maxSe, ps.se + Config.SE_REGEN_PER_SECOND * ps.spiritMul * dt)
		end
		local buff = Combat.buffActive(ps)
		hum.WalkSpeed = Config.WALK_SPEED * (if buff then buff.speedMul else 1) * ps.moveMul
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
		if now >= (nextPublish[ps] or 0) then
			nextPublish[ps] = now + 0.1
			Combat.publish(ps)
		end
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
