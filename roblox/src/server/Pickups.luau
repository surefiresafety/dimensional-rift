--!strict
-- What enemies leave behind: health, Spirit Energy and Rift Shards as glowing
-- orbs. An orb drifts to anyone who comes close and is picked up on touch;
-- left alone it blinks out after 25 seconds. Worth walking over for, and a
-- reason to fight up close.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)

local Combat = require(script.Parent.Combat)

local STUDS = Config.STUDS_PER_UNIT
local MAGNET = 10 * STUDS
local TOUCH = 2.6 * STUDS
local LIFE = 25
local MAX = 80

export type Kind = "health" | "energy" | "shards"

local COLOUR: { [string]: number } = { health = 0x3ddc97, energy = 0x4ea8ff, shards = 0xb06cff }

type Orb = { part: Part, kind: Kind, value: number, untilT: number, speed: number }

local Pickups = {}
local orbs: { Orb } = {}

local folder = Instance.new("Folder")
folder.Name = "Pickups"
folder.Parent = workspace

--- Set by Progress: shards picked up go into the player's save.
Pickups.onShards = function(_player: Player, _n: number) end

function Pickups.drop(at: Vector3, kind: Kind, value: number)
	if #orbs >= MAX then
		local oldest = table.remove(orbs, 1) :: Orb
		oldest.part:Destroy()
	end
	local p = Instance.new("Part")
	p.Name = kind
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * (if kind == "shards" then 1.4 else 1.1) * STUDS
	p.Color = Palette.color(COLOUR[kind])
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	-- Scattered a little around where it fell.
	local off = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 4 * STUDS
	p.CFrame = CFrame.new(at * Vector3.new(1, 0, 1) + off + Vector3.new(0, 1.4 * STUDS, 0))
	local l = Instance.new("PointLight")
	l.Color = p.Color
	l.Range = 10
	l.Brightness = 1.2
	l.Parent = p
	p.Parent = folder
	table.insert(orbs, { part = p, kind = kind, value = value, untilT = Combat.now() + LIFE, speed = 0 })
end

local function collect(o: Orb, ps: Combat.PState)
	local hum = Combat.humanoidOf(ps.player)
	local root = Combat.rootOf(ps.player)
	if not hum or not root then
		return
	end
	local text
	if o.kind == "health" then
		local back = math.min(o.value, hum.MaxHealth - hum.Health)
		hum.Health += back
		text = "+" .. math.floor(back) .. " HP"
	elseif o.kind == "energy" then
		if ps.se ~= math.huge then
			ps.se = math.min(ps.maxSe, ps.se + o.value)
		end
		text = "+" .. o.value .. " SE"
	else
		Pickups.onShards(ps.player, o.value)
		text = "+" .. o.value .. " SHARDS"
	end
	Combat.fx("pickup", { at = root.Position, color = COLOUR[o.kind], text = text, player = ps.player })
end

function Pickups.step(dt: number)
	local now = Combat.now()
	for i = #orbs, 1, -1 do
		local o = orbs[i]
		if now >= o.untilT or not o.part.Parent then
			table.remove(orbs, i)
			o.part:Destroy()
			continue
		end
		-- Blink for the last five seconds.
		o.part.Transparency = if o.untilT - now < 5 and math.floor(now * 6) % 2 == 0 then 0.7 else 0
		local best: Combat.PState?, bestRoot: BasePart?, bestD = nil, nil, MAGNET
		for _, ps in Combat.states do
			local hum = Combat.humanoidOf(ps.player)
			local root = Combat.rootOf(ps.player)
			if hum and root and hum.Health > 0 then
				local d = (root.Position - o.part.Position).Magnitude
				-- A full health bar does not pull health orbs.
				local wanted = o.kind ~= "health" or hum.Health < hum.MaxHealth
				if wanted and d < bestD then
					best, bestRoot, bestD = ps, root, d
				end
			end
		end
		if best and bestRoot then
			if bestD <= TOUCH then
				table.remove(orbs, i)
				o.part:Destroy()
				collect(o, best)
				continue
			end
			o.speed = math.min(60 * STUDS, o.speed + 90 * STUDS * dt)
			local to = bestRoot.Position - o.part.Position
			o.part.CFrame = CFrame.new(o.part.Position + to.Unit * math.min(to.Magnitude, o.speed * dt))
		else
			o.speed = 0
			local p = o.part.Position
			o.part.CFrame = CFrame.new(p.X, 1.4 * STUDS + math.sin(now * 3 + i) * 0.3 * STUDS, p.Z)
		end
	end
end

--- What an enemy leaves: often health or energy, and shards from anything
--- that was a real fight.
function Pickups.fromKill(e: Combat.Enemy)
	local at = e.root.Position
	local r = math.random()
	if r < 0.35 then
		Pickups.drop(at, "health", 45)
	elseif r < 0.7 then
		Pickups.drop(at, "energy", 160)
	end
	local count, each = 0, 0
	if string.match(e.id, "^boss_") then
		count, each = 6, 5
	elseif string.match(e.id, "_alpha$") or e.t.boss then
		count, each = 3, 3
	elseif math.random() < 0.25 then
		count, each = 1, 2
	end
	for _ = 1, count do
		Pickups.drop(at, "shards", each)
	end
end

--- A new world: nothing carries over.
function Pickups.clear()
	for _, o in orbs do
		o.part:Destroy()
	end
	table.clear(orbs)
end

return Pickups
