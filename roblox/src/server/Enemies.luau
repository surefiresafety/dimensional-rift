--!strict
-- Spawning and driving enemies. Human-shaped ones and every character boss
-- are R15 rigs in their costume colours; the creature shapes (toad, blob,
-- wraith, golem, imp) are an R15 walker with its limbs hidden inside a body
-- shape, so they path and animate like everything else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Rules = require(Shared.Rules)
local RulesData = require(Shared.Data.Rules)
local EnemyData = require(Shared.Data.Enemies)
local EnemyLooks = require(Shared.Data.EnemyLooks)

local Combat = require(script.Parent.Combat)
local Looks = require(script.Parent.Looks)
local Projectiles = require(script.Parent.Projectiles)

local STUDS = Config.STUDS_PER_UNIT

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
function Enemies.spawn(id: string, at: Vector3): Combat.Enemy?
	local template = EnemyData[id]
	if not template or #Combat.enemies >= Config.MAX_ENEMIES then
		return nil
	end
	local t = deepCopy(template)
	local look = EnemyLooks[id]
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
	model.Parent = folder
	root:SetNetworkOwner(nil) -- the server drives them

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
		nextAttack = now + 1,
		nextShot = now + (if t.ranged then t.ranged.cd * math.random() else 0),
		nextSummon = now + (if t.summon then t.summon.every else 0),
	}
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

local function shoot(e: Combat.Enemy, target: BasePart)
	local r = e.t.ranged
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

--- One think for every enemy: chase, strike in reach, shoot at range, summon.
function Enemies.think()
	local now = Combat.now()
	for _, e in table.clone(Combat.enemies) do
		if e.dead then
			continue
		end
		local ps, target = nearestPlayer(e.root.Position)
		local mul = Rules.speedMul(e.status)
		e.hum.WalkSpeed = e.t.speed * STUDS * mul
		if not ps or not target then
			e.hum:MoveTo(e.root.Position)
			continue
		end
		local d = (target.Position - e.root.Position).Magnitude
		if mul > 0 then
			e.hum:MoveTo(target.Position)
		else
			e.hum:MoveTo(e.root.Position)
		end
		local reach = (Config.ENEMY_MELEE_REACH + (e.t.size or 1)) * STUDS
		if mul > 0 and d <= reach and now >= e.nextAttack then
			e.nextAttack = now + Config.ENEMY_MELEE_COOLDOWN
			Combat.hurtPlayer(ps, e.t.atk, e.t.nature, e)
		end
		local r = e.t.ranged
		if r and not e.status.stun and not e.status.paralyze and d >= (r.min or 8) * STUDS and now >= e.nextShot then
			e.nextShot = now + r.cd * (0.8 + math.random() * 0.5)
			shoot(e, target)
		end
		local sm = e.t.summon
		if sm and now >= e.nextSummon then
			e.nextSummon = now + sm.every
			local mine = 0
			for _, o in Combat.enemies do
				if o.id == sm.of and not o.dead then
					mine += 1
				end
			end
			for i = 1, math.min(sm.count or 2, (sm.max or 6) - mine) do
				local a = math.random() * math.pi * 2
				Enemies.spawn(sm.of, e.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (3 + i) * STUDS)
			end
		end
	end
end

return Enemies
