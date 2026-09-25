--!strict
-- Spawning and driving enemies. Human-shaped ones and every character boss
-- are R15 rigs in their costume colours; the creature shapes (toad, blob,
-- wraith, golem, imp) are an R15 walker with its limbs hidden inside a body
-- shape, so they path and animate like everything else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Worlds)
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Rules = require(Shared.Rules)
local RulesData = require(Shared.Data.Rules)

local Combat = require(script.Parent.Combat)
local Looks = require(script.Parent.Looks)
local Projectiles = require(script.Parent.Projectiles)
local Nav = require(script.Parent.Nav)

local STUDS = Config.STUDS_PER_UNIT

-- Roblox's own default R15 animations (the ones the Animate script uses).
local ANIMS: { [string]: string } = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	slash = "rbxassetid://522635514",
	lunge = "rbxassetid://522638767",
}

local function loadAnims(hum: Humanoid): { [string]: AnimationTrack }
	local animator: Animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ANIMS do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and track then
			track.Priority = if name == "slash" or name == "lunge"
				then Enum.AnimationPriority.Action
				else Enum.AnimationPriority.Movement
			track.Looped = name ~= "slash" and name ~= "lunge"
			tracks[name] = track
		end
	end
	return tracks
end

--- Idle, walk or run, from how fast it is actually going.
local function animate(e: Combat.Enemy)
	local v = e.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local speed = v.Magnitude
	local want = if speed < 1.5 then "idle" elseif speed < 8 * STUDS * 0.5 then "walk" else "run"
	if e.moving ~= want then
		local old = e.moving and e.anims[e.moving]
		if old then
			old:Stop(0.2)
		end
		local new = e.anims[want]
		if new then
			new:Play(0.2)
		end
		e.moving = want
	end
	local track = e.anims[want]
	if track and want ~= "idle" then
		track:AdjustSpeed(math.clamp(speed / (if want == "walk" then 6 else 16), 0.5, 2.2))
	end
end

local function attackAnim(e: Combat.Enemy, name: string)
	local t = e.anims[name]
	if t then
		t:Play(0.05)
	end
end

local Enemies = {}

local folder = Instance.new("Folder")
folder.Name = "Enemies"
folder.Parent = workspace

local function deepCopy<T>(t: T): T
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t :: any do
		out[k] = deepCopy(v)
	end
	return out :: any
end

local SHAPES: { [string]: { part: Enum.PartType, size: Vector3 } } = {
	toad = { part = Enum.PartType.Ball, size = Vector3.new(2.6, 1.9, 2.6) },
	blob = { part = Enum.PartType.Ball, size = Vector3.new(2.2, 2.2, 2.2) },
	wraith = { part = Enum.PartType.Ball, size = Vector3.new(1.8, 2.8, 1.8) },
	golem = { part = Enum.PartType.Block, size = Vector3.new(2.6, 3.2, 2) },
	imp = { part = Enum.PartType.Ball, size = Vector3.new(1.5, 1.7, 1.5) },
}

local function creatureBody(model: Model, t: any)
	local shape = SHAPES[t.shape]
	if not shape then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d.Transparency = 1
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = shape.part
	body.Size = shape.size * STUDS * 0.55 * (t.size or 1)
	body.Color = Palette.color(t.color or RulesData.NATURE[t.nature].color)
	body.Material = if t.float then Enum.Material.Neon else Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Massless = true
	body.CFrame = root.CFrame * CFrame.new(0, body.Size.Y * 0.1, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = body
	w.Parent = body
	body.Parent = model
	-- One big eye, which is most of what makes a curse read as a curse.
	local eye = Instance.new("Part")
	eye.Shape = Enum.PartType.Ball
	eye.Size = Vector3.one * body.Size.X * 0.32
	eye.Color = Color3.fromRGB(255, 228, 92)
	eye.Material = Enum.Material.Neon
	eye.CanCollide = false
	eye.Massless = true
	eye.CFrame = body.CFrame * CFrame.new(0, body.Size.Y * 0.12, -body.Size.Z * 0.42)
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = body
	w2.Part1 = eye
	w2.Parent = eye
	eye.Parent = model
end

--- Spawns one enemy of type `id` at `at`. Returns nil at the server's cap.
--- `scale` toughens it: health times scale, attack by half as much again
--- (Loose Threads uses 1.6).
function Enemies.spawn(id: string, at: Vector3, affix: Rules.Affix?, scale: number?): Combat.Enemy?
	local template = Worlds.enemy(id)
	if not template or #Combat.enemies >= Config.MAX_ENEMIES then
		return nil
	end
	local t = deepCopy(template)
	if affix then
		Rules.applyAffix(t, affix)
	end
	local sc = scale or 1
	if sc ~= 1 then
		t.hp = math.floor(t.hp * sc + 0.5)
		t.atk = math.floor(t.atk * (1 + (sc - 1) * 0.5) + 0.5)
	end
	local look = Worlds.look(id)
		or {
			skin = 0xd8c0b0,
			hair = 0x1a1a22,
			hairStyle = "short",
			top = t.color or RulesData.NATURE[t.nature].color,
			bottom = 0x24242c,
			eye = 0xffe45c,
		}
	local model = Looks.buildNpc(look, t.size or 1)
	model.Name = t.name
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if t.shape ~= "human" then
		creatureBody(model, t)
	end
	hum.MaxHealth = t.hp
	hum.Health = t.hp
	hum.WalkSpeed = t.speed * STUDS
	hum.DisplayName = t.name .. "  ·  " .. (RulesData.GRADES[tostring(t.grade)] or { label = "" }).label
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	hum.NameDisplayDistance = 90
	hum.HealthDisplayDistance = 90
	hum.BreakJointsOnDeath = false
	model:PivotTo(CFrame.new(at + Vector3.new(0, 4, 0)))

	local now = Combat.now()
	local e: Combat.Enemy = {
		id = id,
		t = t,
		model = model,
		hum = hum,
		root = root,
		status = {},
		clock = Rules.newDotClock(),
		defMul = 1,
		enraged = false,
		dead = false,
		nextShot = now + (if t.ranged then t.ranged.cd * math.random() else 0),
		nextSummon = now + (if t.summon then t.summon.every else 0),
		state = "idle",
		stateUntil = 0,
		anims = {},
		affix = affix,
		summoned = false,
		alerted = false,
		home = at,
		wanderTo = nil,
		nextWander = 0,
		lungeHit = false,
		nextCharge = now + (if t.charge then t.charge.cd * (0.5 + math.random()) else 0),
		nextAura = now + (if t.aura then t.aura.every or 0.6 else 0),
		allyUntil = 0,
	}
	-- Into the world only once its record is whole, so a bad template can
	-- never leave a body standing that nothing drives.
	model:SetAttribute("Boss", t.boss == true)
	model:SetAttribute("Hunting", false)
	model.Parent = folder
	root:SetNetworkOwner(nil) -- the server drives them
	e.anims = loadAnims(hum)
	if affix then
		-- An elite glows its colour so it reads from across the arena.
		local h = Instance.new("Highlight")
		h.OutlineColor = Palette.color(affix.color)
		h.FillColor = Palette.color(affix.color)
		h.FillTransparency = 0.8
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
		model:SetAttribute("Affix", affix.name)
	end
	table.insert(Combat.enemies, e)
	Combat.fx("burst", { at = at, color = look.top or 0xb06cff, count = 12 })
	return e
end

local function nearestPlayer(pos: Vector3): (Combat.PState?, BasePart?)
	local best, bestRoot, bestD = nil, nil, math.huge
	for _, ps in Combat.states do
		local root = Combat.rootOf(ps.player)
		local hum = Combat.humanoidOf(ps.player)
		if root and hum and hum.Health > 0 then
			local d = (root.Position - pos).Magnitude
			if d < bestD then
				best, bestRoot, bestD = ps, root, d
			end
		end
	end
	return best, bestRoot
end

local function shoot(e: Combat.Enemy, target: BasePart, prof: any?)
	local r = prof or e.t.ranged
	for i = 1, (r.burst or 1) do
		task.delay((i - 1) * 0.12, function()
			if e.dead then
				return
			end
			local from = e.root.Position + Vector3.new(0, 1.5 * (e.t.size or 1), 0)
			local aim = target.Position - from
			local flight = aim.Magnitude / (r.speed * STUDS)
			local spread = (r.spread or 0) * (math.random() - 0.5) * 2
			local dir = (CFrame.fromAxisAngle(Vector3.yAxis, spread) * aim).Unit
			local vel = dir * r.speed * STUDS
			if r.arc then
				vel += Vector3.new(0, 9 * STUDS * flight * 0.5, 0) -- lobbed shots hang in the air
			end
			Projectiles.fire({
				pos = from,
				vel = vel,
				radius = (r.size or 0.5) * STUDS,
				gravity = if r.arc then 9 * STUDS else 0,
				life = 4,
				hitsEnemies = false,
				color = r.color or 0xffffff,
				onHitPlayer = function(ps)
					Combat.hurtPlayer(ps, r.power, e.t.nature, e)
				end,
			})
		end)
	end
end

local function faceTowards(e: Combat.Enemy, at: Vector3)
	local flat = Vector3.new(at.X, e.root.Position.Y, at.Z)
	if (flat - e.root.Position).Magnitude > 0.1 then
		e.root.CFrame = CFrame.lookAt(e.root.Position, flat)
	end
end

--- Wakes everything close to `e` that has not seen anyone yet: a pack hunts
--- together.
local function alertPack(e: Combat.Enemy)
	for _, o in Combat.enemies do
		if o ~= e and not o.dead and o.state == "idle" then
			if (o.root.Position - e.root.Position).Magnitude < Config.ENEMY_PACK * STUDS then
				o.alerted = true
			end
		end
	end
end

--- Somewhere near where it arrived to amble towards while it has seen nobody.
local function wander(e: Combat.Enemy, now: number, mul: number)
	if mul <= 0 then
		e.hum:MoveTo(e.root.Position)
		return
	end
	if not e.wanderTo or now >= e.nextWander or (e.root.Position - e.wanderTo).Magnitude < 2 * STUDS then
		e.wanderTo = Nav.wanderSpot(e.home)
		e.nextWander = now + 3 + math.random() * 4
	end
	e.hum.WalkSpeed = e.t.speed * STUDS * 0.4 * mul
	e.hum:MoveTo(e.wanderTo :: Vector3)
end

--- One think for every enemy (every Config.ENEMY_THINK_INTERVAL): the state
--- machine in Rules.aiStep decides; this moves, telegraphs and hits.
function Enemies.think()
	local now = Combat.now()
	for _, e in table.clone(Combat.enemies) do
		if e.dead then
			continue
		end
		local ps, target = nearestPlayer(e.root.Position)
		local mul = Rules.speedMul(e.status)
		local size = e.t.size or 1
		local dist = if target then (target.Position - e.root.Position).Magnitude / STUDS else math.huge
		local canAct = mul > 0 and not e.status.stun and not e.status.paralyze
		local action = Rules.aiStep(e, {
			now = now,
			dist = dist,
			canAct = canAct,
			alerted = e.alerted,
			boss = e.t.boss,
			notice = if e.t.boss then Config.ENEMY_NOTICE_BOSS else Config.ENEMY_NOTICE,
			leash = Config.ENEMY_LEASH,
			reach = Config.ENEMY_SWING_START + (size - 1),
			shotReady = (e.t.ranged ~= nil or e.tossing == true) and now >= e.nextShot,
			charge = e.t.charge,
			chargeReady = e.t.charge ~= nil and now >= e.nextCharge,
			tempo = e.affix and e.affix.tempo,
		})
		e.alerted = false
		Nav.updateToss(e, target, e.state ~= "idle")
		if action ~= "lunging" then
			e.hum.WalkSpeed = e.t.speed * STUDS * mul
		end

		if action == "idle" then
			wander(e, now, mul)
		elseif action == "notice" then
			e.model:SetAttribute("Hunting", true)
			Combat.fx("alert", { model = e.model, color = 0xffd54a })
			alertPack(e)
			if target then
				Nav.moveTarget(e, target.Position)
			end
		elseif action == "giveup" then
			e.model:SetAttribute("Hunting", false)
			e.home = Nav.floorUnder(e.root.Position)
			Nav.reset(e)
			wander(e, now, mul)
		elseif action == "chase" then
			if target and mul > 0 then
				Nav.moveTarget(e, target.Position)
			end
		elseif action == "windup" or action == "aim" or action == "tell" then
			-- Plant, turn, and show what is coming.
			e.hum:MoveTo(e.root.Position)
			if target then
				faceTowards(e, target.Position)
			end
			Combat.fx("telegraph", {
				model = e.model,
				radius = (1.6 + size) * STUDS,
				color = if action == "windup" then 0xff3b3b elseif action == "aim" then 0xffd54a else 0xff8a3d,
				duration = e.stateUntil - now,
			})
			if action == "tell" and target then
				local flat = (target.Position - e.root.Position) * Vector3.new(1, 0, 1)
				e.lungeDir = if flat.Magnitude > 0.01 then flat.Unit else e.root.CFrame.LookVector
			end
		elseif action == "winding" or action == "aiming" or action == "telling" or action == "recover" then
			e.hum:MoveTo(e.root.Position)
			if target and action ~= "recover" then
				faceTowards(e, target.Position)
			end
		elseif action == "strike" then
			attackAnim(e, "slash")
			Combat.fx("slash", {
				at = e.root.Position + e.root.CFrame.LookVector * STUDS * size,
				dir = e.root.CFrame.LookVector,
				reach = (Config.ENEMY_SWING_HIT + size - 1) * STUDS,
				color = 0xff3b3b,
			})
			if ps and dist <= Config.ENEMY_SWING_HIT + (size - 1) then
				Combat.hurtPlayer(ps, e.t.atk, e.t.nature, e)
			end
		elseif action == "shoot" then
			-- A thrower's own shot, or a rock from a melee enemy that cannot reach.
			local prof = e.t.ranged or Nav.toss(e)
			e.nextShot = now + prof.cd * (0.8 + math.random() * 0.5)
			if target then
				shoot(e, target, prof)
			end
		elseif action == "lunge" then
			attackAnim(e, "lunge")
			e.lungeHit = false
			local dir = e.lungeDir or e.root.CFrame.LookVector
			e.hum.WalkSpeed = (e.t.charge.speed or 22) * STUDS
			e.hum:MoveTo(e.root.Position + dir * 60 * STUDS)
			Combat.fx("burst", { at = e.root.Position, color = 0xff8a3d, count = 12 })
		elseif action == "lunging" then
			if ps and not e.lungeHit and dist < 2.9 + (size - 1) then
				e.lungeHit = true
				Combat.hurtPlayer(ps, Rules.round(e.t.charge.power or e.t.atk * 1.7), e.t.nature, e)
				Combat.fx("burst", { at = e.root.Position, color = 0xff8a3d, count = 16 })
			end
		elseif action == "endLunge" then
			e.hum:MoveTo(e.root.Position)
			e.nextCharge = now + (e.t.charge.cd or 7) * (0.8 + math.random() * 0.4)
		elseif action == "hold" or action == "cancel" then
			e.hum:MoveTo(e.root.Position)
		end

		animate(e)

		-- Regeneration, and a damaging aura every 0.6 s (updateEnemies).
		if e.t.regen and e.hum.Health < e.hum.MaxHealth then
			e.hum.Health = math.min(e.hum.MaxHealth, e.hum.Health + e.t.regen * Config.ENEMY_THINK_INTERVAL)
		end
		local aura = e.t.aura
		if aura and now >= e.nextAura then
			e.nextAura = now + (aura.every or 0.6)
			Combat.fx("burst", { at = e.root.Position, color = RulesData.NATURE[e.t.nature].color, count = 5 })
			for _, other in Combat.states do
				local root = Combat.rootOf(other.player)
				if root and (root.Position - e.root.Position).Magnitude < (aura.radius or 6) * STUDS then
					Combat.hurtPlayer(other, aura.power or 6, e.t.nature, e, true)
				end
			end
		end
		-- Summoners call up help once they are in a fight.
		local sm = e.t.summon
		if sm and e.state ~= "idle" and now >= e.nextSummon then
			e.nextSummon = now + sm.every
			local mine = 0
			for _, o in Combat.enemies do
				if o.id == sm.of and not o.dead then
					mine += 1
				end
			end
			for n = 1, math.min(sm.count or 2, (sm.max or 6) - mine) do
				local a = math.random() * math.pi * 2
				local near = e.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (3 + n) * STUDS
				local child = Enemies.spawn(sm.of, Nav.clearSpot(near))
				if child then
					child.alerted = true
					child.summoned = true
				end
			end
		end
	end
end

-- A volatile elite goes off a second after it dies: a ring to get out of,
-- then the blast.
Combat.onKilled(function(e)
	local v = e.affix and e.affix.volatile
	if not v then
		return
	end
	local at = e.root.Position
	local radius = v.radius * STUDS
	Combat.fx("telegraph", { at = at, radius = radius, color = 0xff8a3d, duration = v.delay })
	task.delay(v.delay, function()
		Combat.fx("burst", { at = at, color = 0xff8a3d, count = 26 })
		Combat.fx("ring", { at = at, radius = radius, color = 0xff8a3d })
		for _, ps in Combat.states do
			local root = Combat.rootOf(ps.player)
			if root and (root.Position - at).Magnitude <= radius then
				Combat.hurtPlayer(ps, v.power, "fire", nil)
			end
		end
	end)
end)

return Enemies
