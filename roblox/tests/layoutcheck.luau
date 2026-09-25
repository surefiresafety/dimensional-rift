--!strict
-- The design's layout checks (docs/design/worlds.md §4.5), run against a plan
-- from Layouts.plan. Each check returns a list of failures (strings); an empty
-- list passes. Used by layouts.spec (the suite) and world.luau (one world, in
-- detail, while a layout is being written).

local Layouts = require("../src/shared/Layouts")

type Rec = Layouts.Rec
type Plan = Layouts.Plan

local C = {}

local rad, cos, sin, sqrt = math.rad, math.cos, math.sin, math.sqrt
local inPlan = Layouts.inPlan

local function fmt(n: number): string
	return string.format("%.2f", n)
end

-- Geometry for rays ------------------------------------------------------------

local function slab(o: number, d: number, h: number, t0: number?, t1: number?): (number?, number?)
	if t0 == nil or t1 == nil then
		return nil, nil
	end
	if math.abs(d) < 1e-9 then
		if math.abs(o) > h then
			return nil, nil
		end
		return t0, t1
	end
	local a, b = (-h - o) / d, (h - o) / d
	if a > b then
		a, b = b, a
	end
	local n0, n1 = math.max(t0, a), math.min(t1, b)
	if n0 > n1 then
		return nil, nil
	end
	return n0, n1
end

--- The first hit of the ray o + t*d (t in [0, tmax]) on a box, wedge or vertical cylinder.
local function hitSolid(fp: Rec, o: { number }, d: { number }, tmax: number): number?
	local hy, oy = (fp.h1 - fp.h0) / 2, o[2] - (fp.h0 + fp.h1) / 2
	if fp.shape == "cyl" then
		local ox, oz, r = o[1] - fp.x, o[3] - fp.z, fp.w / 2
		if ox * ox + oz * oz <= r * r and math.abs(oy) <= hy then
			return nil
		end
		local t0, t1 = 0, tmax
		local a = d[1] ^ 2 + d[3] ^ 2
		if a > 1e-12 then
			local b, c = ox * d[1] + oz * d[3], ox * ox + oz * oz - r * r
			local disc = b * b - a * c
			if disc < 0 then
				return nil
			end
			t0, t1 = math.max(t0, (-b - sqrt(disc)) / a), math.min(t1, (-b + sqrt(disc)) / a)
			if t0 > t1 then
				return nil
			end
		elseif ox * ox + oz * oz > r * r then
			return nil
		end
		local n0 = slab(oy, d[2], hy, t0, t1)
		return n0
	end
	local c, s = cos(rad(fp.yaw)), sin(rad(fp.yaw))
	local rx, rz = o[1] - fp.x, o[3] - fp.z
	local O = { rx * c - rz * s, oy, rx * s + rz * c }
	local D = { d[1] * c - d[3] * s, d[2], d[1] * s + d[3] * c }
	local H = { fp.w / 2, hy, fp.d / 2 }
	local k = if fp.run then (fp.h1 - fp.h0) / fp.w else nil
	if
		math.abs(O[1]) <= H[1]
		and math.abs(O[2]) <= H[2]
		and math.abs(O[3]) <= H[3]
		and (k == nil or O[2] - k * O[1] <= 0)
	then
		return nil
	end
	local t0: number?, t1: number? = 0, tmax
	for i = 1, 3 do
		t0, t1 = slab(O[i], D[i], H[i], t0, t1)
		if t0 == nil then
			return nil
		end
	end
	local a0, a1 = t0 :: number, t1 :: number
	if k then
		local n0, n1 = O[2] - k * O[1], D[2] - k * D[1]
		if math.abs(n1) < 1e-12 then
			if n0 > 0 then
				return nil
			end
		elseif n1 > 0 then
			a1 = math.min(a1, -n0 / n1)
		else
			a0 = math.max(a0, -n0 / n1)
		end
		if a0 > a1 then
			return nil
		end
	end
	return a0
end
C.hitSolid = hitSolid

local function hitBall(b: { number }, o: { number }, d: { number }, tmax: number): number?
	local L = { o[1] - b[1], o[2] - b[2], o[3] - b[3] }
	local c = L[1] ^ 2 + L[2] ^ 2 + L[3] ^ 2 - b[4] ^ 2
	if c <= 0 then
		return nil
	end
	local p = L[1] * d[1] + L[2] * d[2] + L[3] * d[3]
	local disc = p * p - c
	if disc < 0 then
		return nil
	end
	local t = -p - sqrt(disc)
	return if t >= 0 and t <= tmax then t else nil
end

type Geo = { solids: { Rec }, balls: { { number } }, reach: { number } }

--- The fan's geometry: every checked footprint except seeded scatter; crowns as balls.
function C.geometry(P: Plan): Geo
	local G: Geo = { solids = {}, balls = {}, reach = {} }
	for _, fp in P.recs do
		if Layouts.checked(fp) and not fp.scatter then
			if fp.shape == "ball" then
				table.insert(G.balls, { fp.x, (fp.h0 + fp.h1) / 2, fp.z, fp.w / 2 })
			else
				table.insert(G.solids, fp)
			end
		end
	end
	return G
end

--- Only the parts that can be within `reach` of (x, z).
local function near(G: Geo, x: number, z: number, reach: number): Geo
	local out: Geo = { solids = {}, balls = {}, reach = {} }
	for _, fp in G.solids do
		local r = sqrt(fp.w ^ 2 + fp.d ^ 2) / 2
		if (fp.x - x) ^ 2 + (fp.z - z) ^ 2 <= (reach + r) ^ 2 then
			table.insert(out.solids, fp)
		end
	end
	for _, b in G.balls do
		if (b[1] - x) ^ 2 + (b[3] - z) ^ 2 <= (reach + b[4]) ^ 2 then
			table.insert(out.balls, b)
		end
	end
	return out
end

local function nearestHit(G: Geo, o: { number }, d: { number }, tmax: number): number?
	local best: number? = nil
	for _, fp in G.solids do
		local t = hitSolid(fp, o, d, tmax)
		if t and (best == nil or t < best) then
			best = t
		end
	end
	for _, b in G.balls do
		local t = hitBall(b, o, d, tmax)
		if t and (best == nil or t < best) then
			best = t
		end
	end
	return best
end

local function rodrigues(v: { number }, k: { number }, a: number): { number }
	local c, s = cos(a), sin(a)
	local kv = k[1] * v[1] + k[2] * v[2] + k[3] * v[3]
	local x = { k[2] * v[3] - k[3] * v[2], k[3] * v[1] - k[1] * v[3], k[1] * v[2] - k[2] * v[1] }
	return {
		v[1] * c + x[1] * s + k[1] * kv * (1 - c),
		v[2] * c + x[2] * s + k[2] * kv * (1 - c),
		v[3] * c + x[3] * s + k[3] * kv * (1 - c),
	}
end

--- Movement.findAnchor's fan: the chosen hit { x, y, z } facing `look`, or nil.
--- Points are { x, h, z } here, like the game's Vector3.
local function fan(G: Geo, root: { number }, look: { number }): { number }?
	local right = { -look[3], 0, look[1] }
	local best, bestScore = nil, -math.huge
	for i = 0, 8 do
		local el = rad(25 + 55 * i / 8)
		for _, yaw in { -0.9, -0.45, 0, 0.45, 0.9 } do
			local c, s = cos(yaw), sin(yaw)
			local flat = { look[1] * c + look[3] * s, 0, -look[1] * s + look[3] * c }
			local d = rodrigues(flat, right, el)
			local t = nearestHit(G, root, d, 60)
			if t then
				local h = { root[1] + d[1] * t, root[2] + d[2] * t, root[3] + d[3] * t }
				if h[2] > root[2] + 4 then
					local score = h[2] * 2 + (h[1] - root[1]) * look[1] + (h[3] - root[3]) * look[3]
					if score > bestScore then
						best, bestScore = h, score
					end
				end
			end
		end
	end
	return best
end

-- The checks -----------------------------------------------------------------

--- Check 1: pads.
function C.pads(P: Plan): { string }
	local fails = {}
	local boss = 0
	for _, p in P.pads do
		local where =
			`pad ({fmt(p.x)}, {fmt(p.z)}{if p.h ~= 0 then ", h " .. p.h else ""}){if p.boss then " B" else ""}`
		local r = sqrt(p.x * p.x + p.z * p.z)
		if r < 20 or r > 50 then
			table.insert(fails, `{where}: r {fmt(r)} outside 20..50`)
		end
		if p.boss then
			boss += 1
			if r < 34 then
				table.insert(fails, `{where}: boss pad at r {fmt(r)} < 34`)
			end
		end
		local e = if p.boss then 8 else 6
		local top = if p.boss then 7.3 else 5.3
		for _, fp in P.recs do
			if Layouts.checked(fp) and Layouts.collides(fp) and not fp.backdrop then
				if fp.h1 > p.h + 0.3 and fp.h0 < p.h + top then
					local hit
					if fp.shape == "cyl" or fp.shape == "ball" then
						local dx = math.max(math.abs(fp.x - p.x) - e, 0)
						local dz = math.max(math.abs(fp.z - p.z) - e, 0)
						hit = dx * dx + dz * dz < (fp.w / 2) ^ 2
					else
						-- separating axes: world X, world Z, and the footprint's own axes
						local cs = Layouts.corners(fp)
						hit = true
						local minx, maxx, minz, maxz = math.huge, -math.huge, math.huge, -math.huge
						for _, q in cs do
							minx, maxx = math.min(minx, q[1]), math.max(maxx, q[1])
							minz, maxz = math.min(minz, q[2]), math.max(maxz, q[2])
						end
						if maxx <= p.x - e or minx >= p.x + e or maxz <= p.z - e or minz >= p.z + e then
							hit = false
						else
							local c, s = cos(rad(fp.yaw)), sin(rad(fp.yaw))
							for _, ax in { { c, -s }, { s, c } } do
								local lo, hi = math.huge, -math.huge
								for _, sx in { -1, 1 } do
									for _, sz in { -1, 1 } do
										local v = (p.x + sx * e) * ax[1] + (p.z + sz * e) * ax[2]
										lo, hi = math.min(lo, v), math.max(hi, v)
									end
								end
								local cv = fp.x * ax[1] + fp.z * ax[2]
								local half = if ax[1] == c then fp.w / 2 else fp.d / 2
								if hi <= cv - half or lo >= cv + half then
									hit = false
								end
							end
						end
					end
					if hit then
						table.insert(fails, `{where}: box meets {fp.id} (h {fmt(fp.h0)}..{fmt(fp.h1)})`)
					end
				end
				if fp.h0 >= p.h + 0.3 and fp.h0 < p.h + 12 and inPlan(fp, p.x, p.z) then
					table.insert(fails, `{where}: under {fp.id}`)
				end
			end
		end
		for _, w in P.water do
			if
				(w.r and (p.x - w.x) ^ 2 + (p.z - w.z) ^ 2 < w.r ^ 2)
				or (
					w.w
					and inPlan({ shape = "box", x = w.x, z = w.z, w = w.w, d = w.d, yaw = w.yaw or 0 } :: any, p.x, p.z)
				)
			then
				table.insert(fails, `{where}: in water`)
			end
		end
		-- the floor under the pad must be at its height (so it does not float or sink)
		local f = 0
		for _, fp in P.recs do
			if Layouts.checked(fp) and fp.set == "solid" and inPlan(fp, p.x, p.z) then
				local t = Layouts.topAt(fp, p.x, p.z)
				if t <= p.h + 0.3 then
					f = math.max(f, t)
				end
			end
		end
		if math.abs(f - p.h) > 0.35 then
			table.insert(fails, `{where}: floor under it is at {fmt(f)}`)
		end
	end
	if #P.pads < 10 then
		table.insert(fails, `only {#P.pads} pads (need 10)`)
	end
	if boss < 3 then
		table.insert(fails, `only {boss} boss pads (need 3)`)
	end
	return fails
end

local function samples(w: Layouts.Walk, step: number): { { number } }
	local out = {}
	local dx, dz, dh = w.b[1] - w.a[1], w.b[2] - w.a[2], w.b[3] - w.a[3]
	local len = sqrt(dx * dx + dz * dz)
	local n = math.max(1, math.ceil(len / step))
	for i = 0, n do
		local t = i / n
		table.insert(out, { w.a[1] + dx * t, w.a[2] + dz * t, w.a[3] + dh * t })
	end
	return out
end

--- Check 2: every walk sample has an access top within 25 u.
function C.walks(P: Plan): { string }
	local fails = {}
	for _, w in P.walks do
		for _, s in samples(w, 3) do
			local best = math.huge
			for _, a in P.access do
				best = math.min(best, sqrt((a.top[1] - s[1]) ^ 2 + (a.top[2] - s[2]) ^ 2))
			end
			if best > 25 then
				table.insert(fails, `walk {w.id} at ({fmt(s[1])}, {fmt(s[2])}): nearest access top {fmt(best)} u`)
				break
			end
		end
	end
	return fails
end

local function supported(P: Plan, x: number, z: number, h: number): boolean
	for _, fp in P.recs do
		if Layouts.checked(fp) and fp.set == "solid" and inPlan(fp, x, z) then
			local t = Layouts.topAt(fp, x, z)
			if t >= h - 0.05 and t <= h + 0.15 then
				return true
			end
		end
	end
	return false
end

--- Check 2b: every walk is supported across its full width, and at its joints.
function C.support(P: Plan): { string }
	local fails = {}
	for _, w in P.walks do
		local dx, dz = w.b[1] - w.a[1], w.b[2] - w.a[2]
		local len = sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		local bad = 0
		local first
		for _, s in samples(w, 0.5) do
			for _, off in { 0, w.w / 2 - 0.1, -(w.w / 2 - 0.1) } do
				local x, z = s[1] - uz * off, s[2] + ux * off
				if not supported(P, x, z, s[3]) then
					bad += 1
					first = first or `({fmt(x)}, {fmt(z)}, h {fmt(s[3])})`
				end
			end
		end
		-- joints with the next walk that starts where this one ends
		for _, v in P.walks do
			if v ~= w and math.abs(v.a[1] - w.b[1]) < 0.05 and math.abs(v.a[2] - w.b[2]) < 0.05 then
				local ex, ez = v.b[1] - v.a[1], v.b[2] - v.a[2]
				local el = sqrt(ex * ex + ez * ez)
				local vx, vz = ex / el, ez / el
				local turn = math.acos(math.clamp(ux * vx + uz * vz, -1, 1))
				local bx, bz = -(uz + vz), ux + vx -- bisector of the two normals
				local bl = sqrt(bx * bx + bz * bz)
				if bl > 1e-6 then
					bx, bz = bx / bl, bz / bl
					local reach = (w.w / 2) / cos(turn / 2) - 0.15
					local t = -reach
					while t <= reach + 1e-9 do
						local x, z = w.b[1] + bx * t, w.b[2] + bz * t
						if not supported(P, x, z, w.b[3]) then
							bad += 1
							first = first or `joint ({fmt(x)}, {fmt(z)})`
						end
						t += 0.25
					end
				end
			end
		end
		if bad > 0 then
			table.insert(fails, `walk {w.id}: {bad} unsupported samples, first at {first}`)
		end
	end
	return fails
end

--- Check 3: ramps and stairs are at least 3 u wide, and one is at least 4.
function C.access(P: Plan): { string }
	local fails = {}
	local wide = false
	for _, a in P.access do
		if a.kind ~= "truss" then
			if a.w < 3 - 1e-6 then
				table.insert(fails, `access {a.id}: {fmt(a.w)} u wide (< 3)`)
			end
			if a.w >= 4 - 1e-6 then
				wide = true
			end
		end
	end
	if #P.walks > 0 and not wide then
		table.insert(fails, "no access at least 4 u wide")
	end
	return fails
end

local FACES = { { 0, 0, -1 }, { 1, 0, 0 }, { 0, 0, 1 }, { -1, 0, 0 } }

export type FanResult = {
	points: number,
	full: number,
	fails: { string },
	skipped: number,
	heights: { [string]: { number } },
}

--- Check 4: the swing fan gate (design §1.5).
function C.fan(P: Plan): FanResult
	local G = C.geometry(P)
	local out: FanResult = { points = 0, full = 0, fails = {}, skipped = 0, heights = {} }
	for i = -5, 5 do
		for j = -5, 5 do
			local x, z = i * 10, j * 10
			local r = sqrt(x * x + z * z)
			if r >= 20 and r <= 50 then
				local f = Layouts.floorAt(P, x, z)
				if Layouts.skipped(P, x, z, f) then
					out.skipped += 1
				else
					out.points += 1
					local g = near(G, x, z, 62)
					local ok, hs = 0, {}
					for n, look in FACES do
						local hit = fan(g, { x, f + 1.25, z }, look)
						hs[n] = if hit then hit[2] - f else -1
						if hit and hit[2] >= f + 16 then
							ok += 1
						end
					end
					out.heights[x .. "," .. z] = hs
					if ok == 4 then
						out.full += 1
					end
					if ok < 3 then
						table.insert(
							out.fails,
							string.format("(%d, %d) N%.1f E%.1f S%.1f W%.1f", x, z, hs[1], hs[2], hs[3], hs[4])
						)
					end
				end
			end
		end
	end
	return out
end

--- Check 5: nothing collidable and low inside the Rift Plaza.
function C.plaza(P: Plan): { string }
	local fails = {}
	for _, fp in P.recs do
		if Layouts.checked(fp) and Layouts.collides(fp) and fp.h0 < 3 then
			local close = false
			if fp.shape == "cyl" or fp.shape == "ball" then
				close = sqrt(fp.x * fp.x + fp.z * fp.z) - fp.w / 2 < P.r0
			else
				close = inPlan(fp, 0, 0)
				for _, q in Layouts.corners(fp) do
					if sqrt(q[1] * q[1] + q[2] * q[2]) < P.r0 then
						close = true
					end
				end
			end
			if close then
				table.insert(fails, `{fp.id} stands inside r {P.r0} below h 3`)
			end
		end
	end
	return fails
end

--- Check 6: budgets.
function C.budget(P: Plan): { string }
	local fails = {}
	local parts, lights = P.parts + Layouts.FIXED_PARTS, P.lights + Layouts.FIXED_LIGHTS
	if parts > P.budget.parts or parts > 900 then
		table.insert(fails, `{parts} parts over the budget {P.budget.parts} (cap 900)`)
	end
	if lights > P.budget.lights or lights > 60 then
		table.insert(fails, `{lights} lights over the budget {P.budget.lights} (cap 60)`)
	end
	return fails
end

local function isHero(P: Plan, id: string): boolean
	for _, h in (P.hero :: any).ids do
		if id == h or string.sub(id, 1, #h + 1) == h .. "/" then
			return true
		end
	end
	return false
end

--- Check 7: the hero sightline clears everything but the hero by 0.3 u (rails and crowns count).
function C.hero(P: Plan): { string }
	local fails = {}
	local hero = P.hero
	if not hero then
		return { "no hero set" }
	end
	local o = { 0, 3, 0 }
	local tgt = { hero.x, 0.6 * hero.top, hero.z }
	local d = { tgt[1] - o[1], tgt[2] - o[2], tgt[3] - o[3] }
	for _, fp in P.recs do
		if Layouts.checked(fp) and not fp.scatter and not isHero(P, fp.id) then
			local t
			if fp.shape == "ball" then
				t = hitBall({ fp.x, (fp.h0 + fp.h1) / 2, fp.z, fp.w / 2 + 0.3 }, o, d, 1)
			else
				local g = table.clone(fp)
				g.w += 0.6
				g.d += 0.6
				g.h0 -= 0.3
				g.h1 += 0.3
				t = hitSolid(g, o, d, 1)
			end
			if t then
				table.insert(fails, `{fp.id} blocks the sightline at t {fmt(t)}`)
			end
		end
	end
	local found = false
	for _, fp in P.recs do
		if isHero(P, fp.id) then
			found = true
		end
	end
	if not found then
		table.insert(fails, "no part carries a hero id")
	end
	return fails
end

--- Check 9: hills stay clear of the play space and the keep pieces.
function C.hills(P: Plan): { string }
	local fails = {}
	local H = P.hills
	if not H then
		return fails
	end
	local far, who = 0, ""
	for _, fp in P.recs do
		if Layouts.checked(fp) and not fp.backdrop then
			local r
			if fp.shape == "cyl" or fp.shape == "ball" then
				r = sqrt(fp.x * fp.x + fp.z * fp.z) + fp.w / 2
			else
				r = 0
				for _, q in Layouts.corners(fp) do
					r = math.max(r, sqrt(q[1] * q[1] + q[2] * q[2]))
				end
			end
			if r > far then
				far, who = r, fp.id
			end
		end
	end
	if far + 4 > H.minGround + 1e-6 then
		table.insert(fails, `minGround {H.minGround} < {fmt(far)} + 4 ({who})`)
	end
	for _, fp in P.recs do
		if fp.keep then
			local ok = false
			for _, s in H.keepOut do
				local inside = true
				for _, q in Layouts.corners(fp) do
					local b = math.deg(math.atan2(q[2], q[1]))
					if math.abs((b - s.bearing + 180) % 360 - 180) > s.halfWidth then
						inside = false
					end
				end
				if inside then
					ok = true
				end
			end
			if not ok then
				table.insert(fails, `{fp.id} (keep) is in no keep-out sector`)
			end
		end
	end
	return fails
end

--- Anchors flagged `anchor` must be at least 5 x 5 (the lead's condition for the Seam).
function C.anchors(P: Plan): { string }
	local fails = {}
	for _, fp in P.recs do
		if fp.anchor and (fp.w < 5 - 1e-6 or fp.d < 5 - 1e-6) then
			table.insert(fails, `{fp.id}: anchor {fmt(fp.w)} x {fmt(fp.d)} under 5 x 5`)
		end
	end
	return fails
end

--- Ids repeat only by mistake.
function C.ids(P: Plan): { string }
	local seen, fails = {}, {}
	for _, fp in P.recs do
		if seen[fp.id] then
			table.insert(fails, `duplicate id {fp.id}`)
		end
		seen[fp.id] = true
	end
	return fails
end

C.EXPECT = Layouts.EXPECT

return C
