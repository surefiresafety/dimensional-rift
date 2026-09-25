--!strict
-- How enemies get about the built worlds (design §4.3). On the flat they walk
-- straight at you; when you are up a stair, on a roof or across a rail they
-- take a PathfindingService path, and if there is none they head for the
-- nearest stair or ladder (the arena's Nav part lists them as Links). A
-- melee enemy that still cannot reach you lobs rocks instead. Stuck enemies
-- hop and sidestep. Nav.isClear and Nav.clearSpot keep spawns and summons
-- out of walls and water.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local Combat = require(script.Parent.Combat)

local STUDS = Config.STUDS_PER_UNIT

local Nav = {}

type St = {
	waypoints: { PathWaypoint }?,
	wp: number,
	goal: Vector3?,
	computedAt: number,
	computing: boolean,
	noPath: boolean,
	link: Attachment?,
	linkTop: boolean,
	checkAt: number,
	checkPos: Vector3,
	sidestepUntil: number,
	sidestepTo: Vector3?,
	huntSince: number?,
}

local states: { [Combat.Enemy]: St } = setmetatable({}, { __mode = "k" }) :: any
local inFlight = 0
local MAX_IN_FLIGHT = 8

local function stateOf(e: Combat.Enemy): St
	local st = states[e]
	if not st then
		st = {
			waypoints = nil,
			wp = 1,
			goal = nil,
			computedAt = -math.huge,
			computing = false,
			noPath = false,
			link = nil,
			linkTop = false,
			checkAt = 0,
			checkPos = e.root.Position,
			sidestepUntil = 0,
			sidestepTo = nil,
			huntSince = nil,
		}
		states[e] = st
	end
	return st
end

local function arena(): Instance?
	return workspace:FindFirstChild("Arena")
end

local function navPart(): Instance?
	local a = arena()
	return a and a:FindFirstChild("Nav")
end

--- Casts that see only what stops bodies: the arena (not crowns, cores or decor) and the terrain.
local function solidParams(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	local list: { Instance } = { workspace.Terrain }
	local a = arena()
	if a then
		table.insert(list, a)
	end
	local base = workspace:FindFirstChild("Baseplate")
	if base then
		table.insert(list, base)
	end
	p.FilterDescendantsInstances = list
	p.RespectCanCollide = true
	return p
end

local function flat(v: Vector3): Vector3
	return v * Vector3.new(1, 0, 1)
end

--- Standing room at `pos` (a point on the floor): nothing solid in a 3 x 5 x 3
--- box above it, a floor within 1.5 u under it, and that floor not water.
function Nav.isClear(pos: Vector3): boolean
	local a = arena()
	if a then
		local o = OverlapParams.new()
		o.FilterType = Enum.RaycastFilterType.Include
		o.FilterDescendantsInstances = { a }
		o.RespectCanCollide = true
		local box = CFrame.new(pos + Vector3.new(0, 2.8 * STUDS, 0))
		if #workspace:GetPartBoundsInBox(box, Vector3.new(3, 5, 3) * STUDS, o) > 0 then
			return false
		end
	end
	local hit = workspace:Raycast(pos + Vector3.new(0, 6 * STUDS, 0), Vector3.new(0, -8 * STUDS, 0), solidParams())
	if not hit then
		return false
	end
	if math.abs(hit.Position.Y - pos.Y) > 1.5 * STUDS then
		return false
	end
	return hit.Material ~= Enum.Material.Water
end

--- The nearest Pad to `pos`, if the arena has any.
local function nearestPad(pos: Vector3): Vector3?
	local n = navPart()
	if not n then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, a in n:GetChildren() do
		if a:IsA("Attachment") and a.Name == "Pad" then
			local d = (a.WorldPosition - pos).Magnitude
			if d < bestD then
				best, bestD = a.WorldPosition, d
			end
		end
	end
	return best
end

--- `pos` if there is room there; else the first clear spot 3 u, then 6 u, round
--- it; else the nearest pad. For summons and finale adds.
function Nav.clearSpot(pos: Vector3): Vector3
	-- Settle onto the floor under the point first.
	local down = workspace:Raycast(pos + Vector3.new(0, 3 * STUDS, 0), Vector3.new(0, -8 * STUDS, 0), solidParams())
	local base = if down then down.Position else pos
	if Nav.isClear(base) then
		return base
	end
	for _, r in { 3, 6 } do
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local p = base + Vector3.new(math.cos(a), 0, math.sin(a)) * r * STUDS
			local d = workspace:Raycast(p + Vector3.new(0, 3 * STUDS, 0), Vector3.new(0, -6 * STUDS, 0), solidParams())
			local q = if d then d.Position else p
			if Nav.isClear(q) then
				return q
			end
		end
	end
	return nearestPad(pos) or pos
end

--- Whether an enemy can walk straight at `to`: a sphere its size, swept.
local function directClear(e: Combat.Enemy, to: Vector3): boolean
	local from = e.root.Position
	local dir = flat(to - from)
	if dir.Magnitude < 0.5 then
		return true
	end
	local size = e.t.size or 1
	local hit = workspace:Spherecast(from, 1 * size * STUDS, dir, solidParams())
	return hit == nil
end

local function compute(e: Combat.Enemy, st: St, goal: Vector3, now: number)
	if st.computing or now - st.computedAt < 1 or inFlight >= MAX_IN_FLIGHT then
		return
	end
	st.computing = true
	st.computedAt = now
	inFlight += 1
	local size = e.t.size or 1
	local from = e.root.Position
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 0.6 * size * STUDS,
			AgentHeight = 2.4 * size * STUDS,
			AgentCanJump = false,
			AgentCanClimb = true,
			Costs = { Water = math.huge },
		})
		local ok = pcall(function()
			path:ComputeAsync(from, goal)
		end)
		inFlight -= 1
		st.computing = false
		if e.dead then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			st.waypoints = path:GetWaypoints()
			st.wp = 2
			st.goal = goal
			st.noPath = false
			st.link = nil
		else
			st.waypoints = nil
			st.goal = goal
			st.noPath = true
		end
	end)
end

--- The nearest stair or ladder whose top is within 10 u of `target`.
local function linkFor(target: Vector3, from: Vector3): Attachment?
	local n = navPart()
	if not n then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, a in n:GetChildren() do
		if a:IsA("Attachment") and a.Name == "Link" then
			local top = a:GetAttribute("Top")
			if typeof(top) == "Vector3" and (top - target).Magnitude <= 10 * STUDS then
				local d = (a.WorldPosition - from).Magnitude
				if d < bestD then
					best, bestD = a, d
				end
			end
		end
	end
	return best
end

--- Moves `e` toward `target` (a player's position): straight when it can, by a
--- path when it cannot, by the nearest stair when there is no path.
function Nav.moveTarget(e: Combat.Enemy, target: Vector3)
	local now = Combat.now()
	local st = stateOf(e)
	local hum = e.hum
	-- A sidestep out of a jam runs its course first.
	if now < st.sidestepUntil and st.sidestepTo then
		hum:MoveTo(st.sidestepTo)
		return
	end
	local here = e.root.Position
	-- Stuck: barely moved in 0.8 s while trying to go somewhere.
	if now >= st.checkAt then
		if flat(here - st.checkPos).Magnitude < 0.5 * STUDS and flat(target - here).Magnitude > 3 * STUDS then
			hum.Jump = true
			local side = flat(target - here)
			side = if side.Magnitude > 0.01 then side.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
			if math.random() < 0.5 then
				side = -side
			end
			st.sidestepTo = here + side * 6 * STUDS
			st.sidestepUntil = now + 0.6
			st.waypoints = nil
			st.checkAt = now + 1.4
			st.checkPos = here
			hum:MoveTo(st.sidestepTo :: Vector3)
			return
		end
		st.checkAt = now + 0.8
		st.checkPos = here
	end
	local dy = (target.Y - here.Y) / STUDS
	if math.abs(dy) <= 3 and directClear(e, target) then
		st.waypoints = nil
		st.noPath = false
		st.link = nil
		hum:MoveTo(target)
		return
	end
	-- A path, recomputed when the goal has drifted more than 6 u.
	if not st.goal or (st.goal - target).Magnitude > 6 * STUDS or (not st.waypoints and not st.noPath) then
		compute(e, st, target, now)
	end
	local wps = st.waypoints
	if wps then
		local wp = wps[st.wp]
		while
			wp
			and flat(wp.Position - here).Magnitude < 1.5 * STUDS
			and math.abs(wp.Position.Y - here.Y) < 4 * STUDS
		do
			st.wp += 1
			wp = wps[st.wp]
		end
		if wp then
			hum:MoveTo(wp.Position)
			return
		end
		st.waypoints = nil
	end
	if st.noPath then
		-- No path: make for the nearest stair or ladder that tops out near the target.
		local link = st.link or linkFor(target, here)
		st.link = link
		if link then
			local foot = link.WorldPosition
			local top = link:GetAttribute("Top") :: Vector3
			if not st.linkTop and flat(foot - here).Magnitude < 2 * STUDS then
				st.linkTop = true
			end
			hum:MoveTo(if st.linkTop then top else foot)
			return
		end
	end
	hum:MoveTo(target)
end

--- Called every think while an enemy hunts `target`: decides whether a melee
--- enemy that cannot reach its target should lob rocks (e.tossing).
function Nav.updateToss(e: Combat.Enemy, target: BasePart?, hunting: boolean)
	local st = stateOf(e)
	local now = Combat.now()
	if not hunting or not target or e.t.ranged then
		st.huntSince = nil
		e.tossing = false
		return
	end
	st.huntSince = st.huntSince or now
	local here = e.root.Position
	local dy = (target.Position.Y - here.Y) / STUDS
	local near = flat(target.Position - here).Magnitude <= 18 * STUDS
	if e.tossing then
		if math.abs(dy) < 3 or (st.waypoints ~= nil and not st.noPath) then
			e.tossing = false
		end
	elseif now - (st.huntSince :: number) > 4 and (st.noPath or (dy > 3 and near)) then
		e.tossing = true
	end
end

--- Forget a hunt (the enemy gave up or went idle).
function Nav.reset(e: Combat.Enemy)
	local st = stateOf(e)
	st.waypoints, st.goal, st.noPath, st.link, st.linkTop, st.huntSince = nil, nil, false, nil, false, nil
	e.tossing = false
end

--- The rock a melee enemy lobs at someone it cannot reach. A new table every
--- call, shaped like a `ranged` profile, so `shoot` treats it the same way.
function Nav.toss(e: Combat.Enemy): any
	return {
		cd = if e.enraged then 3.5 * 0.65 else 3.5,
		power = Rules.round(e.t.atk * 0.5),
		speed = 14,
		arc = true,
		size = 0.6,
		color = 0xb8a88a,
	}
end

--- Somewhere to amble near `home`: a clear spot within 12 u, or failing four
--- tries, a pad or stair foot within 20 u.
function Nav.wanderSpot(home: Vector3): Vector3
	for _ = 1, 4 do
		local a = math.random() * math.pi * 2
		local r = math.random() * 12 * STUDS
		local p = home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if Nav.isClear(p) then
			return p
		end
	end
	local n = navPart()
	if n then
		local near = {}
		for _, a in n:GetChildren() do
			if a:IsA("Attachment") and flat(a.WorldPosition - home).Magnitude <= 20 * STUDS then
				table.insert(near, a.WorldPosition)
			end
		end
		if #near > 0 then
			return near[math.random(#near)]
		end
	end
	return home
end

return Nav
