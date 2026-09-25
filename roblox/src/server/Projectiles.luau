--!strict
-- Server-simulated projectiles, for both sides. Hits are swept: each step tests
-- the whole segment it travelled, not just where it landed, so a fast shot
-- cannot pass through something between frames (the web build learned that
-- the hard way). Clients draw them from the same start and velocity.

local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Combat = require(script.Parent.Combat)

local STUDS = Config.STUDS_PER_UNIT

export type Shot = {
	id: string,
	pos: Vector3,
	vel: Vector3,
	radius: number,
	life: number,
	gravity: number,
	hitsEnemies: boolean,
	pierce: number, -- how many more things it can pass through
	hit: { [any]: boolean },
	onHitEnemy: ((Combat.Enemy, Vector3) -> ())?,
	onHitPlayer: ((Combat.PState, Vector3) -> ())?,
	onEnd: ((Vector3) -> ())?,
}

local Projectiles = {}
local live: { Shot } = {}

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.CollisionGroup = "ShotRay" -- rails and tree crowns let shots through

--- Distance from point p to the segment a..b.
local function segDistance(a: Vector3, b: Vector3, p: Vector3): number
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return (a + ab * t - p).Magnitude
end
Projectiles.segDistance = segDistance

function Projectiles.fire(shot: {
	pos: Vector3,
	vel: Vector3,
	radius: number,
	life: number?,
	gravity: number?,
	hitsEnemies: boolean,
	pierce: number?,
	color: number,
	onHitEnemy: ((Combat.Enemy, Vector3) -> ())?,
	onHitPlayer: ((Combat.PState, Vector3) -> ())?,
	onEnd: ((Vector3) -> ())?,
})
	local s: Shot = {
		id = HttpService:GenerateGUID(false),
		pos = shot.pos,
		vel = shot.vel,
		radius = shot.radius,
		life = shot.life or 3,
		gravity = shot.gravity or 0,
		hitsEnemies = shot.hitsEnemies,
		pierce = shot.pierce or 0,
		hit = {},
		onHitEnemy = shot.onHitEnemy,
		onHitPlayer = shot.onHitPlayer,
		onEnd = shot.onEnd,
	}
	table.insert(live, s)
	Combat.fx("shot", {
		id = s.id,
		pos = s.pos,
		vel = s.vel,
		radius = s.radius,
		gravity = s.gravity,
		life = s.life,
		color = shot.color,
	})
end

local function finish(i: number, s: Shot)
	table.remove(live, i)
	Combat.fx("shotEnd", { id = s.id, at = s.pos })
	if s.onEnd then
		s.onEnd(s.pos)
	end
end

function Projectiles.step(dt: number)
	-- Walls: anything that is not a character or an enemy.
	local ignore = { workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Worn") }
	for _, ps in Combat.states do
		if ps.player.Character then
			table.insert(ignore, ps.player.Character)
		end
	end
	wallParams.FilterDescendantsInstances = ignore :: { Instance }

	for i = #live, 1, -1 do
		local s = live[i]
		local from = s.pos
		s.vel -= Vector3.new(0, s.gravity * dt, 0)
		local to = from + s.vel * dt
		s.life -= dt

		local ended = false
		if s.hitsEnemies then
			for _, e in Combat.enemies do
				if not e.dead and not s.hit[e] then
					local reach = s.radius + 1.1 * (e.t.size or 1) * STUDS
					if segDistance(from, to, e.root.Position) < reach then
						s.hit[e] = true
						if s.onHitEnemy then
							s.onHitEnemy(e, to)
						end
						if s.pierce <= 0 then
							ended = true
							break
						end
						s.pierce -= 1
					end
				end
			end
		else
			for _, ps in Combat.states do
				local root = Combat.rootOf(ps.player)
				if root and not s.hit[ps] and segDistance(from, to, root.Position) < s.radius + 2 then
					s.hit[ps] = true
					if s.onHitPlayer then
						s.onHitPlayer(ps, to)
					end
					ended = true
					break
				end
			end
		end

		if not ended then
			local wall = workspace:Raycast(from, to - from, wallParams)
			if wall then
				to = wall.Position
				ended = true
			end
		end
		s.pos = to
		if ended or s.life <= 0 then
			finish(i, s)
		end
	end
end

return Projectiles
