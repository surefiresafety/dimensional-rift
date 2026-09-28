--!strict
-- The world layouts, as plain data. Each world's file (a child of this module,
-- named after its theme) is a function that takes a kit `K` and lays the world
-- out with it: `K.box`, `K.ramp`, `K.chordRing`, `K.walkup` and the rest. The
-- kit writes every part as a record in a plan, never an Instance. Arenas turns
-- the records into parts; tests/layouts.spec runs the design's checks (pads,
-- walks, access, the swing fan, the hero sightline, budgets, hills) against
-- the same records, so what is tested is exactly what is built.
--
-- Units are web-build units (1 u = 2.4 studs), from the world's centre C.
-- (x, z) is the plan position, h a height. N = -Z, E = +X. A bearing is in
-- degrees: 0 = E, 90 = S, 180 = W, 270 = N. A `yaw` in degrees is applied as
-- CFrame.Angles(0, rad(yaw), 0): at yaw 0 a part's Size.X runs along X. A
-- radial piece on bearing b has yaw -b (Size.X radial, Size.Z tangential).
--
-- This module requires nothing, so Lune can load it as well as the game.

local Layouts = {}

export type Set = "solid" | "decor" | "rail" | "core" | "foliage"

export type Light = {
	kind: string?, -- "point" (default) or "spot"
	color: number?,
	range: number?, -- studs
	bright: number?,
	angle: number?, -- spot only
	face: string?, -- spot only: NormalId name, default "Front"
}

export type Text = {
	text: string,
	face: string?, -- NormalId name, default "Front" (-Z)
	color: number?,
	bg: number?,
	font: string?,
}

--- One part. Every size is in units; heights are from the ground (h 0).
export type Rec = {
	id: string,
	kind: string, -- what it is: "deck", "cap", "ramp", "rail", "tower", ...
	shape: string, -- "box" | "wedge" | "cyl" | "ball" | "truss"
	x: number,
	z: number,
	w: number, -- Size.X (a wedge: run length; a cylinder or ball: diameter)
	d: number, -- Size.Z (a wedge: width)
	h0: number,
	h1: number,
	yaw: number, -- degrees
	set: Set,
	run: number?, -- wedges: the bearing the slope climbs toward (yaw = -run)
	slope: { number }?, -- a pitched slab: { top at local -X end, top at local +X end }
	floor: boolean?, -- a walkable slab that sets the swing gate's floor
	backdrop: boolean?, -- beyond the play space (skipped by pad and hill checks)
	keep: boolean?, -- a backdrop piece that hills must stay clear of
	anchor: boolean?, -- a named swing anchor (the Seam's must be at least 5 x 5)
	scatter: boolean?, -- seeded scatter: left out of the swing fan, like the design
	ghost: boolean?, -- checked, never built (e.g. the tilted Leaning Block's box)
	nocheck: boolean?, -- built, never checked (its ghost stands in for it)
	color: number,
	mat: string,
	alpha: number?,
	refl: number?,
	name: string?,
	light: Light?,
	text: Text?,
	fire: boolean?,
	smoke: boolean?,
	spin: number?, -- degrees per second about its Y axis, client-side (tag Spin)
	tilt: { number }?, -- render only: { px, h, pz, rx, ry, rz } pivot (u) and angles (deg)
	lean: { number }?, -- render only: extra local rotation { rx, ry, rz } in degrees
}

export type Point = { number } -- { x, z, h }

export type Pad = { x: number, z: number, h: number, boss: boolean }
export type Walk = { id: string, a: Point, b: Point, w: number }
export type Access = { id: string, kind: string, foot: Point, top: Point, w: number }
export type Water = { x: number, z: number, r: number?, w: number?, d: number?, yaw: number? }
export type Beam = {
	a: Point,
	b: Point,
	color: number,
	width: number, -- studs
	alpha: number?,
	curve0: number?,
	curve1: number?,
	emission: number?,
	segments: number?,
}
export type Terrain = {
	op: string, -- "block" | "cyl" | "ball"
	x: number,
	z: number,
	w: number,
	d: number,
	h0: number,
	h1: number,
	yaw: number,
	material: string,
}

export type Plan = {
	theme: string,
	seed: number,
	recs: { Rec },
	pads: { Pad },
	walks: { Walk },
	access: { Access },
	water: { Water },
	beams: { Beam },
	terrain: { Terrain },
	colours: { [string]: number }, -- terrain material -> colour
	ground: { material: string, color: number? }?,
	hills: {
		minGround: number,
		keepOut: { { bearing: number, halfWidth: number } },
		count: number?,
		rMin: number?,
		rMax: number?,
		material: string?,
	}?,
	hero: { x: number, z: number, top: number, ids: { string } }?,
	budget: { parts: number, lights: number },
	highlights: { { prefix: string, color: number } },
	emitters: { { id: string, props: { [string]: any } } },
	r0: number, -- nothing collidable and low inside this radius
	openWater: boolean?, -- the baseplate stops colliding, so the sea can be swum
	parts: number,
	lights: number,
}

-- Maths -----------------------------------------------------------------------

local rad, cos, sin, sqrt = math.rad, math.cos, math.sin, math.sqrt

--- The point r units out on bearing b.
function Layouts.around(b: number, r: number): (number, number)
	return cos(rad(b)) * r, sin(rad(b)) * r
end

--- Local (lx, lz) in a frame at (x, z) turned by yaw, as world (x, z).
local function toWorld(x: number, z: number, yaw: number, lx: number, lz: number): (number, number)
	local c, s = cos(rad(yaw)), sin(rad(yaw))
	return x + lx * c + lz * s, z - lx * s + lz * c
end
Layouts.toWorld = toWorld

--- The bearing from a to b in plan.
local function bearing(ax: number, az: number, bx: number, bz: number): number
	return math.deg(math.atan2(bz - az, bx - ax))
end
Layouts.bearing = bearing

--- Whether (x, z) lies in the record's plan (boxes turned by yaw; cylinders and balls round).
local function inPlan(fp: Rec, x: number, z: number, grow: number?): boolean
	local g = (grow or 0) + 0.01
	if fp.shape == "cyl" or fp.shape == "ball" then
		return (x - fp.x) ^ 2 + (z - fp.z) ^ 2 <= (fp.w / 2 + g) ^ 2
	end
	local c, s = cos(rad(fp.yaw)), sin(rad(fp.yaw))
	local dx, dz = x - fp.x, z - fp.z
	return math.abs(dx * c - dz * s) <= fp.w / 2 + g and math.abs(dx * s + dz * c) <= fp.d / 2 + g
end
Layouts.inPlan = inPlan

--- The top of a record at (x, z): wedges and pitched slabs slope, the rest are flat.
function Layouts.topAt(fp: Rec, x: number, z: number): number
	if fp.run or fp.slope then
		local c, s = cos(rad(fp.yaw)), sin(rad(fp.yaw))
		local lx = (x - fp.x) * c - (z - fp.z) * s
		local f = math.clamp(lx / fp.w + 0.5, 0, 1)
		if fp.slope then
			return fp.slope[1] + (fp.slope[2] - fp.slope[1]) * f
		end
		return fp.h0 + (fp.h1 - fp.h0) * f
	end
	return fp.h1
end

--- The four plan corners of a box record.
function Layouts.corners(fp: Rec): { { number } }
	local out = {}
	for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local x, z = toWorld(fp.x, fp.z, fp.yaw, s[1] * fp.w / 2, s[2] * fp.d / 2)
		table.insert(out, { x, z })
	end
	return out
end

--- Whether a record counts as geometry for the checks.
function Layouts.checked(fp: Rec): boolean
	return fp.set ~= "decor" and not fp.nocheck
end

--- Whether a record stops bodies.
function Layouts.collides(fp: Rec): boolean
	return fp.set == "solid" or fp.set == "rail"
end

--- The swing gate's floor at (x, z): the highest `floor` slab over it, else 0.
function Layouts.floorAt(L: Plan, x: number, z: number): number
	local f = 0
	for _, fp in L.recs do
		if fp.floor and inPlan(fp, x, z) then
			f = math.max(f, fp.h1)
		end
	end
	return f
end

--- A grid point is skipped when something solid over it spans floor + 3 .. floor + 16.
function Layouts.skipped(L: Plan, x: number, z: number, f: number): boolean
	for _, fp in L.recs do
		if
			Layouts.checked(fp)
			and Layouts.collides(fp)
			and not fp.floor
			and not fp.scatter
			and fp.h1 > f + 3
			and fp.h0 < f + 16
			and inPlan(fp, x, z)
		then
			return true
		end
	end
	return false
end

-- A small seeded generator (xorshift), so Lune and the game agree -------------

export type Rng = { int: (number, number) -> number, num: (number?, number?) -> number }

function Layouts.rng(seed: number): Rng
	local s = bit32.bor(math.floor(seed * 2654435761) % 4294967296, 1)
	local function nxt(): number
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		return s / 4294967296
	end
	return {
		num = function(a: number?, b: number?): number
			local lo, hi = a or 0, b or 1
			return lo + (hi - lo) * nxt()
		end,
		int = function(a: number, b: number): number
			return math.min(b, a + math.floor(nxt() * (b - a + 1)))
		end,
	}
end

-- Colours ---------------------------------------------------------------------

function Layouts.rgb(r: number, g: number, b: number): number
	return r * 65536 + g * 256 + b
end
local rgb = Layouts.rgb

local STEEL = rgb(120, 124, 130)
local TIMBER = rgb(92, 64, 44)
local CONCRETE = rgb(128, 124, 118)

-- The kit ---------------------------------------------------------------------

--- A new plan for `theme`, and the kit that fills it. `seed` feeds K.rng.
function Layouts.kit(theme: string, seed: number): (any, Plan)
	local P: Plan = {
		theme = theme,
		seed = seed,
		recs = {},
		pads = {},
		walks = {},
		access = {},
		water = {},
		beams = {},
		terrain = {},
		colours = {},
		ground = nil,
		hills = nil,
		hero = nil,
		budget = { parts = 900, lights = 60 },
		highlights = {},
		emitters = {},
		r0 = 12,
		parts = 0,
		lights = 0,
	}
	local K: any = {}
	local scatterNow = false
	local scatters: { any } = {}
	K.plan = P
	K.rng = Layouts.rng(seed)
	K.rgb = rgb
	K.around = Layouts.around
	K.toWorld = toWorld
	K.bearing = bearing

	-- Primitives ---------------------------------------------------------------

	local FLAGS = {
		"floor",
		"backdrop",
		"keep",
		"anchor",
		"ghost",
		"nocheck",
		"alpha",
		"refl",
		"name",
		"light",
		"text",
		"fire",
		"smoke",
		"spin",
		"tilt",
		"lean",
		"slope",
	}

	local function add(
		o: { [string]: any },
		shape: string,
		x: number,
		z: number,
		w: number,
		d: number,
		h0: number,
		h1: number,
		yaw: number
	): Rec
		assert(o.id, "every piece needs an id")
		assert(h1 >= h0, o.id .. ": h1 below h0")
		local r: Rec = {
			id = o.id,
			kind = o.kind or "block",
			shape = shape,
			x = x,
			z = z,
			w = w,
			d = d,
			h0 = h0,
			h1 = h1,
			yaw = yaw,
			set = o.set or "solid",
			color = o.color or CONCRETE,
			mat = o.mat or "SmoothPlastic",
		}
		for _, f in FLAGS do
			if o[f] ~= nil then
				(r :: any)[f] = o[f]
			end
		end
		if scatterNow then
			r.scatter = true
		end
		if not r.ghost then
			P.parts += 1
			if r.light then
				P.lights += 1
			end
		end
		table.insert(P.recs, r)
		return r
	end
	K.add = add

	--- A box: { id, x, z, w, d, h0, h1, yaw?, kind?, set?, color?, mat?, ... }.
	function K.box(o: { [string]: any }): Rec
		return add(o, "box", o.x, o.z, o.w, o.d, o.h0 or 0, o.h1, o.yaw or 0)
	end

	--- A box given by its plan extent: { id, x0, x1, z0, z1, h0, h1, ... }.
	function K.rect(o: { [string]: any }): Rec
		local x0, x1 = math.min(o.x0, o.x1), math.max(o.x0, o.x1)
		local z0, z1 = math.min(o.z0, o.z1), math.max(o.z0, o.z1)
		return add(o, "box", (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, o.h0 or 0, o.h1, 0)
	end

	--- A wedge centred at (x, z): run length w along bearing `run`, width d,
	--- rising from h0 at the foot to h1 at the top.
	function K.wedge(o: { [string]: any }): Rec
		local r = add(o, "wedge", o.x, o.z, o.w, o.d, o.h0 or 0, o.h1, -o.run)
		r.run = o.run
		return r
	end

	--- A vertical cylinder, diameter w.
	function K.cyl(o: { [string]: any }): Rec
		return add(o, "cyl", o.x, o.z, o.w, o.w, o.h0 or 0, o.h1, o.yaw or 0)
	end

	--- A ball of diameter `dia` centred at height `h`.
	function K.ball(o: { [string]: any }): Rec
		return add(o, "ball", o.x, o.z, o.dia, o.dia, o.h - o.dia / 2, o.h + o.dia / 2, 0)
	end

	--- A truss ladder whose top sits at deck height `top` (0.4 studs proud).
	function K.ladder(o: { [string]: any }): Rec
		local base = o.base or 0
		local studs = math.ceil((o.top - base) * 2.4 / 2 - 1e-6) * 2
		local h1 = o.top + 0.4 / 2.4
		local r = add(
			{ id = o.id, kind = "truss", color = o.color or rgb(90, 90, 96), mat = o.mat or "Metal" },
			"truss",
			o.x,
			o.z,
			2 / 2.4,
			2 / 2.4,
			h1 - studs / 2.4,
			h1,
			o.yaw or 0
		)
		table.insert(
			P.access,
			{ id = o.id, kind = "truss", foot = { o.x, o.z, base }, top = { o.x, o.z, o.top }, w = 2 / 2.4 }
		)
		return r
	end

	-- Plan data ------------------------------------------------------------------

	function K.pad(x: number, z: number, h: number?, boss: boolean?)
		table.insert(P.pads, { x = x, z = z, h = h or 0, boss = boss == true })
	end
	function K.walk(id: string, a: Point, b: Point, w: number)
		table.insert(P.walks, { id = id, a = a, b = b, w = w })
	end
	function K.access(id: string, kind: string, foot: Point, top: Point, w: number)
		table.insert(P.access, { id = id, kind = kind, foot = foot, top = top, w = w })
	end
	--- A pool of water: { x, z, r } or { x, z, w, d, yaw }. Terrain water, walkable, no pads.
	function K.water(o: Water)
		table.insert(P.water, o)
	end
	function K.beam(o: Beam)
		table.insert(P.beams, o)
	end
	--- A terrain fill: { op = "block" | "cyl" | "ball", x, z, w, d?, h0, h1, yaw?, material }.
	function K.terrain(o: { [string]: any })
		table.insert(P.terrain, {
			op = o.op or "block",
			x = o.x,
			z = o.z,
			w = o.w,
			d = o.d or o.w,
			h0 = o.h0,
			h1 = o.h1,
			yaw = o.yaw or 0,
			material = o.material,
		})
		if o.color then
			P.colours[o.material] = o.color
		end
	end
	function K.ground(material: string, color: number?)
		P.ground = { material = material, color = color }
	end
	function K.hills(o: { [string]: any })
		P.hills = o :: any
	end
	function K.hero(x: number, z: number, top: number, ids: { string })
		P.hero = { x = x, z = z, top = top, ids = ids }
	end
	function K.budget(parts: number, lights: number)
		P.budget = { parts = parts, lights = lights }
	end
	--- Open sea: the baseplate stops colliding (lay the sea and island with K.terrain).
	function K.openWater()
		P.openWater = true
	end
	--- Radius of the Rift Plaza, where nothing collidable stands low (12; the Seam 26).
	function K.r0(r: number)
		P.r0 = r
	end
	--- A Highlight round every part whose id starts with `prefix`.
	function K.highlight(prefix: string, color: number)
		table.insert(P.highlights, { prefix = prefix, color = color })
	end
	--- A ParticleEmitter in the part with this id.
	function K.emitter(id: string, props: { [string]: any })
		table.insert(P.emitters, { id = id, props = props })
	end

	-- Access and walkways ------------------------------------------------------

	--- A ramp (or stairs) from its foot: { id, x, z (centre of the foot edge),
	--- run (bearing it climbs toward), w (width), rise, h0?, len? (default
	--- 1.75 * rise), landing? (true = w x w, or a length), stairs?, color?, mat? }.
	--- Returns the top point { x, z, h } (the far end of the landing if any).
	function K.ramp(o: { [string]: any }): Point
		local h0 = o.h0 or 0
		local len = o.len or 1.75 * o.rise
		local dx, dz = cos(rad(o.run)), sin(rad(o.run))
		local stairs = o.stairs == true
		K.wedge({
			id = o.id,
			kind = if stairs then "stairs" else "ramp",
			x = o.x + dx * len / 2,
			z = o.z + dz * len / 2,
			w = len,
			d = o.w,
			h0 = h0,
			h1 = h0 + o.rise,
			run = o.run,
			color = o.color or CONCRETE,
			mat = o.mat or "Concrete",
			alpha = if stairs then 1 else o.alpha,
		})
		if stairs then
			local n = math.min(8, math.ceil(o.rise / 0.6))
			for i = 1, n do
				local f = (i - 0.5) / n
				local tx, tz = o.x + dx * len * f, o.z + dz * len * f
				K.box({
					id = o.id .. "/tread" .. i,
					kind = "tread",
					set = "decor",
					x = tx,
					z = tz,
					w = len / n,
					d = o.w,
					h0 = h0,
					h1 = h0 + o.rise * i / n,
					yaw = -o.run,
					color = o.color or CONCRETE,
					mat = o.mat or "Concrete",
				})
			end
		end
		local top = { o.x + dx * len, o.z + dz * len, h0 + o.rise }
		if o.landing then
			local l = if type(o.landing) == "number" then o.landing else o.w
			K.box({
				id = o.id .. "/landing",
				kind = "landing",
				x = top[1] + dx * l / 2,
				z = top[2] + dz * l / 2,
				w = l,
				d = o.w,
				h0 = o.landBase or 0,
				h1 = h0 + o.rise,
				yaw = -o.run,
				color = o.landColor or o.color or CONCRETE,
				mat = o.landMat or o.mat or "Concrete",
			})
			top = { top[1] + dx * l, top[2] + dz * l, top[3] }
		end
		table.insert(
			P.access,
			{ id = o.id, kind = if stairs then "stairs" else "ramp", foot = { o.x, o.z, h0 }, top = top, w = o.w }
		)
		return top
	end

	--- Two flights side by side with a landing at the far end: { id, x, z (the
	--- centre of the top edge, against the deck), dir (bearing away from the
	--- deck), w, rise, side? (+1: the upper flight is on the right of dir),
	--- h0?, color?, mat? }. Footprint 2w x (0.875 * rise + w).
	function K.switchback(o: { [string]: any })
		local h0, w, rise = o.h0 or 0, o.w, o.rise
		local L = 0.875 * rise
		local side = o.side or 1
		local yaw = -o.dir
		local colour, mat = o.color or CONCRETE, o.mat or "Concrete"
		local function at(lx: number, lz: number): (number, number)
			return toWorld(o.x, o.z, yaw, lx, lz)
		end
		-- local +Z is to the right of dir (dir + 90)
		local ux, uz = at(L / 2, side * w / 2)
		K.box({
			id = o.id .. "/base",
			kind = "access",
			x = ux,
			z = uz,
			w = L,
			d = w,
			h0 = h0,
			h1 = h0 + rise / 2,
			yaw = yaw,
			color = colour,
			mat = mat,
		})
		K.wedge({
			id = o.id .. "/upper",
			kind = "ramp",
			x = ux,
			z = uz,
			w = L,
			d = w,
			h0 = h0 + rise / 2,
			h1 = h0 + rise,
			run = o.dir + 180,
			color = colour,
			mat = mat,
		})
		local lx, lz = at(L / 2, -side * w / 2)
		K.wedge({
			id = o.id .. "/lower",
			kind = "ramp",
			x = lx,
			z = lz,
			w = L,
			d = w,
			h0 = h0,
			h1 = h0 + rise / 2,
			run = o.dir,
			color = colour,
			mat = mat,
		})
		local nx, nz = at(L + w / 2, 0)
		K.box({
			id = o.id .. "/landing",
			kind = "landing",
			x = nx,
			z = nz,
			w = w,
			d = 2 * w,
			h0 = h0,
			h1 = h0 + rise / 2,
			yaw = yaw,
			color = colour,
			mat = mat,
		})
		local fx, fz = at(0, -side * w / 2)
		local tx, tz = at(0, side * w / 2)
		table.insert(
			P.access,
			{ id = o.id, kind = "switchback", foot = { fx, fz, h0 }, top = { tx, tz, h0 + rise }, w = w }
		)
	end

	--- Ramp, landing, ramp and a top landing in one line: { id, x, z (foot
	--- centre), run, w, rise1, land (length), rise2, top (length), h0?, color?, mat? }.
	function K.ledgeStair(o: { [string]: any }): Point
		local h0 = o.h0 or 0
		local p = K.ramp({
			id = o.id .. "/ramp1",
			x = o.x,
			z = o.z,
			run = o.run,
			w = o.w,
			rise = o.rise1,
			h0 = h0,
			len = o.len1,
			landing = o.land,
			color = o.color,
			mat = o.mat,
		})
		return K.ramp({
			id = o.id .. "/ramp2",
			x = p[1],
			z = p[2],
			run = o.run,
			w = o.w,
			rise = o.rise2,
			h0 = p[3],
			len = o.len2,
			landing = o.top,
			landBase = o.topBase,
			color = o.color,
			mat = o.mat,
		})
	end

	--- A deck slab: { id, x, z, w, d, h (top), t? (0.5), yaw?, posts? (0, 2 or 4), kind?, color?, mat? }.
	function K.deck(o: { [string]: any }): Rec
		local t = o.t or 0.5
		local yaw = o.yaw or 0
		local r = K.box({
			id = o.id,
			kind = o.kind or "deck",
			x = o.x,
			z = o.z,
			w = o.w,
			d = o.d,
			h0 = o.h - t,
			h1 = o.h,
			yaw = yaw,
			color = o.color or rgb(120, 92, 64),
			mat = o.mat or "WoodPlanks",
			floor = o.floor,
		})
		local posts = o.posts or 0
		if posts > 0 then
			local pw = o.postW or 0.6
			local spots: { { number } } = if posts == 2
				then { { -1, 1 }, { 1, 1 } }
				else { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
			for i, s in ipairs(spots) do
				local px, pz = toWorld(o.x, o.z, yaw, s[1] * (o.w / 2 - pw / 2), s[2] * (o.d / 2 - pw / 2))
				K.box({
					id = o.id .. "/post" .. i,
					kind = "post",
					x = px,
					z = pz,
					w = pw,
					d = pw,
					h0 = o.base or 0,
					h1 = o.h - t,
					color = o.postColor or TIMBER,
					mat = o.postMat or "Wood",
				})
			end
		end
		return r
	end

	--- A rail from a to b ({ x, z }) standing on height h: { id, a, b, h, style?
	--- ("panel" | "timber" | "rope"), color?, gaps? { { from, to } in u from a } }.
	function K.rail(o: { [string]: any })
		local ax, az, bx, bz = o.a[1], o.a[2], o.b[1], o.b[2]
		local len = sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local ux, uz = (bx - ax) / len, (bz - az) / len
		local yaw = -bearing(ax, az, bx, bz)
		local pieces = { { 0, len } }
		for _, g in o.gaps or {} do
			local nxt = {}
			for _, p in pieces do
				if g[2] <= p[1] or g[1] >= p[2] then
					table.insert(nxt, p)
				else
					if g[1] > p[1] then
						table.insert(nxt, { p[1], g[1] })
					end
					if g[2] < p[2] then
						table.insert(nxt, { g[2], p[2] })
					end
				end
			end
			pieces = nxt
		end
		local style = o.style or "panel"
		local ha, hb = o.h, o.hb or o.h
		for i, p in pieces do
			local l = p[2] - p[1]
			if l > 0.2 then
				local mid = (p[1] + p[2]) / 2
				local cx, cz = ax + ux * mid, az + uz * mid
				local h = ha + (hb - ha) * mid / len
				local dh = (hb - ha) * l / len
				local id = o.id .. (if #pieces > 1 then "/" .. i else "")
				local function bar(suffix: string, lo: number, hi: number, t: number, colour: number, mat: string)
					K.box({
						id = id .. suffix,
						kind = "rail",
						set = "rail",
						x = cx,
						z = cz,
						w = l,
						d = t,
						h0 = h + lo - math.abs(dh) / 2,
						h1 = h + hi + math.abs(dh) / 2,
						yaw = yaw,
						color = colour,
						mat = mat,
						slope = if ha ~= hb then { h - dh / 2 + hi, h + dh / 2 + hi } else nil,
					})
				end
				if style == "timber" then
					bar("", 0, 1.1, 0.3, o.color or TIMBER, "Wood")
				elseif style == "rope" then
					bar("", 0, 1.1, 0.15, o.color or rgb(170, 140, 96), "Fabric")
				else
					bar("", 0, 1.1, 0.3, o.color or rgb(70, 72, 80), o.mat or "Metal")
				end
			end
		end
	end

	--- A bridge from a to b ({ x, z, h }, deck tops): { id, a, b, style? ("flat"
	--- | "arch" | "rope"), w? (3; rope 2.5), rails? (true), walk?, color?, mat? }.
	function K.bridge(o: { [string]: any })
		local style = o.style or "flat"
		local a, b = o.a, o.b
		local len = sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local yaw = -bearing(a[1], a[2], b[1], b[2])
		local w = o.w or (if style == "rope" then 2.5 else 3)
		local cx, cz = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
		local colour = o.color or (if style == "flat" then CONCRETE else rgb(120, 92, 64))
		local mat = o.mat or (if style == "flat" then "Concrete" else "WoodPlanks")
		local t = o.t or 0.5
		if style == "arch" then
			assert(math.abs(a[3] - b[3]) < 1e-6, o.id .. ": an arched bridge is level")
			local rise = o.rise or 1.5
			local ramp = 1.75 * rise
			local ux, uz = (b[1] - a[1]) / len, (b[2] - a[2]) / len
			local run = bearing(a[1], a[2], b[1], b[2])
			K.wedge({
				id = o.id .. "/up",
				kind = "bridge",
				x = a[1] + ux * ramp / 2,
				z = a[2] + uz * ramp / 2,
				w = ramp,
				d = w,
				h0 = a[3],
				h1 = a[3] + rise,
				run = run,
				color = colour,
				mat = mat,
			})
			K.wedge({
				id = o.id .. "/down",
				kind = "bridge",
				x = b[1] - ux * ramp / 2,
				z = b[2] - uz * ramp / 2,
				w = ramp,
				d = w,
				h0 = b[3],
				h1 = b[3] + rise,
				run = run + 180,
				color = colour,
				mat = mat,
			})
			K.box({
				id = o.id .. "/crown",
				kind = "bridge",
				x = cx,
				z = cz,
				w = len - 2 * ramp,
				d = w,
				h0 = a[3] + rise - t,
				h1 = a[3] + rise,
				yaw = yaw,
				color = o.crownColor or colour,
				mat = mat,
			})
			if o.rails ~= false then
				for i, s in { -1, 1 } do
					local px, pz = toWorld(cx, cz, yaw, 0, s * (w / 2 - 0.15))
					K.box({
						id = o.id .. "/rail" .. i,
						kind = "rail",
						set = "rail",
						x = px,
						z = pz,
						w = len - 2 * ramp,
						d = 0.3,
						h0 = a[3] + rise,
						h1 = a[3] + rise + 1.1,
						yaw = yaw,
						color = o.railColor or rgb(190, 40, 40),
						mat = "SmoothPlastic",
					})
				end
			end
		else
			K.box({
				id = o.id,
				kind = "bridge",
				x = cx,
				z = cz,
				w = len,
				d = w,
				h0 = math.min(a[3], b[3]) - t,
				h1 = math.max(a[3], b[3]),
				yaw = yaw,
				color = colour,
				mat = mat,
				slope = if a[3] ~= b[3] then { a[3], b[3] } else nil,
			})
			if o.rails ~= false then
				for i, s in { -1, 1 } do
					local pax, paz = toWorld(a[1], a[2], yaw, 0, s * (w / 2 - 0.15))
					local pbx, pbz = toWorld(b[1], b[2], yaw, 0, s * (w / 2 - 0.15))
					K.rail({
						id = o.id .. "/rail" .. i,
						a = { pax, paz },
						b = { pbx, pbz },
						h = a[3],
						hb = b[3],
						style = if style == "rope" then "rope" else (o.railStyle or "panel"),
						color = o.railColor,
					})
				end
			end
			if style == "rope" then
				for i, p in { a, b } do
					for j, s in { -1, 1 } do
						local px, pz = toWorld(p[1], p[2], yaw, (if i == 1 then 1 else -1) * 0.2, s * (w / 2 + 0.25))
						K.box({
							id = o.id .. "/post" .. i .. j,
							kind = "post",
							set = "decor",
							x = px,
							z = pz,
							w = 0.3,
							d = 0.3,
							h0 = p[3] - 1,
							h1 = p[3] + 1.6,
							color = TIMBER,
							mat = "Wood",
						})
					end
				end
			end
		end
		if o.walk then
			table.insert(P.walks, { id = o.id, a = { a[1], a[2], a[3] }, b = { b[1], b[2], b[3] }, w = w })
		end
	end

	--- A gate: two piers and a lintel. { id, x, z, yaw?, span (clear opening), h (lintel underside), pier? (1.5), t? (1), color?, mat? }.
	function K.arch(o: { [string]: any })
		local pier, t, yaw = o.pier or 1.5, o.t or 1, o.yaw or 0
		for i, s in { -1, 1 } do
			local px, pz = toWorld(o.x, o.z, yaw, s * (o.span / 2 + pier / 2), 0)
			K.box({
				id = o.id .. "/pier" .. i,
				kind = "wall",
				x = px,
				z = pz,
				w = pier,
				d = o.depth or pier,
				h0 = 0,
				h1 = o.h + t,
				yaw = yaw,
				color = o.color,
				mat = o.mat,
			})
		end
		K.box({
			id = o.id .. "/lintel",
			kind = "wall",
			x = o.x,
			z = o.z,
			w = o.span + 2 * pier,
			d = o.depth or pier,
			h0 = o.h,
			h1 = o.h + t,
			yaw = yaw,
			color = o.color,
			mat = o.mat,
		})
	end

	--- A neon ring inlaid in the floor at radius r round (x, z) (2 decor discs).
	function K.inlay(o: { [string]: any })
		local x, z, w = o.x or 0, o.z or 0, o.w or 0.6
		K.cyl({
			id = o.id,
			kind = "inlay",
			set = "decor",
			x = x,
			z = z,
			w = 2 * o.r,
			h0 = (o.h or 0),
			h1 = (o.h or 0) + 0.04,
			color = o.color,
			mat = "Neon",
		})
		K.cyl({
			id = o.id .. "/fill",
			kind = "inlay",
			set = "decor",
			x = x,
			z = z,
			w = 2 * (o.r - w),
			h0 = (o.h or 0),
			h1 = (o.h or 0) + 0.05,
			color = o.fill or rgb(30, 30, 36),
			mat = o.fillMat or "Slate",
		})
	end

	--- A chord ring (design §2.1): n chord decks between bearings b0 and b1,
	--- joint caps, and rails. { id, b0, b1, n, rIn, rOut, top, t, capW, capT?,
	--- color?, mat?, capColor?, capMat?, rails? { outer = bool, inner = bool,
	--- style?, gaps? { { bearing, edge, from, to } | { at, edge, width } } },
	--- walk? (default true) }.
	function K.chordRing(s: { [string]: any })
		local span = s.b1 - s.b0
		local closed = math.abs(span - 360) < 1e-6
		local step = span / s.n
		local half = rad(step / 2)
		local depth = s.rOut - s.rIn
		local len = 2 * s.rIn * math.tan(half)
		local capLen = s.rOut / cos(half) - s.rIn
		assert(s.capW >= 2 * depth * math.tan(half) + 1, s.id .. ": cap narrower than the joint V")
		local rails = s.rails or {}
		local gaps = rails.gaps or {}
		for i = 0, s.n - 1 do
			local b = s.b0 + (i + 0.5) * step
			local x, z = Layouts.around(b, s.rIn + depth / 2)
			K.box({
				id = s.id .. "/deck" .. (i + 1),
				kind = "deck",
				x = x,
				z = z,
				w = depth,
				d = len,
				h0 = s.top - s.t,
				h1 = s.top,
				yaw = -b,
				color = s.color,
				mat = s.mat,
			})
			-- Rails: along the edge at apothem r, from the joint at b - step/2 (s = 0).
			for _, edge in { "outer", "inner" } do
				if rails[edge] ~= false and (rails[edge] or rails.both) then
					local r = if edge == "outer" then s.rOut - 0.15 else s.rIn + 0.15
					local L = if edge == "outer"
						then 2 * s.rOut * math.tan(half)
						else 2 * (s.rIn + 0.3) * math.tan(half)
					local cuts = {}
					local j0, j1 = b - step / 2, b + step / 2
					for _, g in gaps do
						if g.edge == edge then
							if g.at then
								-- A gap centred where bearing `at` meets this edge.
								local d = ((g.at - b + 180) % 360) - 180
								if math.abs(d) <= step / 2 + 1e-6 then
									local along = r * math.tan(rad(d)) + L / 2
									table.insert(cuts, { along - g.width / 2, along + g.width / 2 })
								end
							else
								local d0 = ((g.bearing - j0 + 180) % 360) - 180
								local d1 = ((g.bearing - j1 + 180) % 360) - 180
								if math.abs(d0) < 1e-6 then
									table.insert(cuts, { g.from, g.to })
								elseif math.abs(d1) < 1e-6 then
									table.insert(cuts, { L + g.from, L + g.to })
								end
							end
						end
					end
					local ax, az = toWorld(0, 0, -b, r, -L / 2)
					local bx, bz = toWorld(0, 0, -b, r, L / 2)
					K.rail({
						id = s.id .. "/" .. edge .. (i + 1),
						a = { ax, az },
						b = { bx, bz },
						h = s.top,
						style = rails.style,
						color = rails.color,
						mat = rails.mat,
						gaps = cuts,
					})
				end
			end
			if s.walk ~= false then
				local ax, az = toWorld(0, 0, -b, s.rIn + depth / 2, -len / 2 - depth / 2 * math.tan(half))
				local bx, bz = toWorld(0, 0, -b, s.rIn + depth / 2, len / 2 + depth / 2 * math.tan(half))
				table.insert(
					P.walks,
					{ id = s.id .. "/walk" .. (i + 1), a = { ax, az, s.top }, b = { bx, bz, s.top }, w = depth }
				)
			end
		end
		for j = 0, if closed then s.n - 1 else s.n do
			local b = s.b0 + j * step
			local x, z = Layouts.around(b, s.rIn + capLen / 2)
			local capT = s.capT or 0.1
			K.box({
				id = s.id .. "/cap" .. (j + 1),
				kind = "cap",
				x = x,
				z = z,
				w = capLen,
				d = s.capW,
				h0 = s.top + capT - 0.5,
				h1 = s.top + capT,
				yaw = -b,
				color = s.capColor or s.color,
				mat = s.capMat or s.mat,
			})
		end
	end

	-- Street furniture and cover -----------------------------------------------

	--- A market stall: counter, 2 posts, awning and goods (decor). { id, x, z, yaw?, color?, lit? }.
	function K.stall(o: { [string]: any })
		local yaw = o.yaw or 0
		K.box({
			id = o.id,
			kind = "stall",
			x = o.x,
			z = o.z,
			w = 4,
			d = 1.5,
			h0 = 0,
			h1 = 1.1,
			yaw = yaw,
			color = rgb(120, 92, 64),
			mat = "WoodPlanks",
		})
		for i, s in { -1, 1 } do
			local px, pz = toWorld(o.x, o.z, yaw, s * 1.85, 0.6)
			K.box({
				id = o.id .. "/post" .. i,
				kind = "post",
				x = px,
				z = pz,
				w = 0.3,
				d = 0.3,
				h0 = 1.1,
				h1 = 3.2,
				color = TIMBER,
				mat = "Wood",
			})
		end
		local ax, az = toWorld(o.x, o.z, yaw, 0, 0)
		K.box({
			id = o.id .. "/awning",
			kind = "awning",
			set = "decor",
			x = ax,
			z = az,
			w = 4.4,
			d = 2,
			h0 = 3.2,
			h1 = 3.4,
			yaw = yaw,
			color = o.color or rgb(200, 60, 50),
			mat = "Fabric",
			light = if o.lit then { color = rgb(255, 210, 150), range = 22, bright = 1 } else nil,
		})
		K.box({
			id = o.id .. "/goods",
			kind = "goods",
			set = "decor",
			x = o.x,
			z = o.z,
			w = 3.4,
			d = 1,
			h0 = 1.1,
			h1 = 1.5,
			yaw = yaw,
			color = o.goods or rgb(230, 170, 60),
			mat = "SmoothPlastic",
		})
	end

	function K.crate(o: { [string]: any })
		local s = o.s or 2.4
		K.box({
			id = o.id,
			kind = "crate",
			x = o.x,
			z = o.z,
			w = s,
			d = s,
			h0 = o.h0 or 0,
			h1 = (o.h0 or 0) + s,
			yaw = o.yaw or 0,
			color = o.color or rgb(140, 104, 62),
			mat = "WoodPlanks",
		})
	end

	--- A shipping container 6 x 2.5 x 2.6 (long along local X) and a decor stripe.
	function K.container(o: { [string]: any })
		local h0 = o.h0 or 0
		K.box({
			id = o.id,
			kind = "container",
			x = o.x,
			z = o.z,
			w = 6,
			d = 2.5,
			h0 = h0,
			h1 = h0 + 2.6,
			yaw = o.yaw or 0,
			color = o.color or rgb(170, 70, 50),
			mat = "DiamondPlate",
		})
		K.box({
			id = o.id .. "/stripe",
			kind = "stripe",
			set = "decor",
			x = o.x,
			z = o.z,
			w = 6.05,
			d = 2.55,
			h0 = h0 + 2.1,
			h1 = h0 + 2.3,
			yaw = o.yaw or 0,
			color = rgb(230, 226, 214),
			mat = "SmoothPlastic",
		})
	end

	function K.jersey(o: { [string]: any })
		K.box({
			id = o.id,
			kind = "jersey",
			x = o.x,
			z = o.z,
			w = 4,
			d = 0.8,
			h0 = 0,
			h1 = 1.2,
			yaw = o.yaw or 0,
			color = o.color or rgb(200, 196, 188),
			mat = "Concrete",
		})
	end

	local CARS = {
		rgb(216, 50, 60),
		rgb(255, 213, 74),
		rgb(47, 111, 255),
		rgb(232, 232, 232),
		rgb(34, 34, 40),
		rgb(61, 220, 151),
	}

	--- A car 4.5 x 2 x 1.6, long along local X: body, glass, 2 axles, headlamp. { id, x, z, yaw?, wrecked?, color? }.
	function K.car(o: { [string]: any })
		local yaw = o.yaw or 0
		local wrecked = o.wrecked == true
		local lean = if wrecked then { K.rng.num(-8, 8), 0, K.rng.num(-10, 10) } else nil
		local colour = o.color or (if wrecked then rgb(60, 52, 48) else CARS[K.rng.int(1, #CARS)])
		K.box({
			id = o.id,
			kind = "car",
			x = o.x,
			z = o.z,
			w = 4.5,
			d = 2,
			h0 = 0.3,
			h1 = 1.1,
			yaw = yaw,
			color = colour,
			mat = if wrecked then "CorrodedMetal" else "SmoothPlastic",
			lean = lean,
			fire = if wrecked then o.fire ~= false else nil,
		})
		local gx, gz = toWorld(o.x, o.z, yaw, -0.3, 0)
		K.box({
			id = o.id .. "/glass",
			kind = "car",
			x = gx,
			z = gz,
			w = 2.4,
			d = 1.8,
			h0 = 1.1,
			h1 = 1.6,
			yaw = yaw,
			color = rgb(30, 40, 55),
			mat = "Glass",
			alpha = 0.2,
			lean = lean,
		})
		for i, s in { -1, 1 } do
			local ax, az = toWorld(o.x, o.z, yaw, s * 1.4, 0)
			K.box({
				id = o.id .. "/axle" .. i,
				kind = "car",
				x = ax,
				z = az,
				w = 0.8,
				d = 2.1,
				h0 = 0,
				h1 = 0.6,
				yaw = yaw,
				color = rgb(20, 20, 20),
				mat = "Rubber",
			})
		end
		if not wrecked then
			local hx, hz = toWorld(o.x, o.z, yaw, 2.27, 0)
			K.box({
				id = o.id .. "/lamp",
				kind = "lamp",
				set = "decor",
				x = hx,
				z = hz,
				w = 0.05,
				d = 1.6,
				h0 = 0.7,
				h1 = 0.95,
				yaw = yaw,
				color = rgb(255, 250, 220),
				mat = "Neon",
			})
		end
	end

	--- A street lamp: pole 0.5 x h (7) and a neon bulb (decor, lit on request).
	function K.lamp(o: { [string]: any })
		local h = o.h or 7
		K.box({
			id = o.id,
			kind = "lamp",
			x = o.x,
			z = o.z,
			w = 0.5,
			d = 0.5,
			h0 = 0,
			h1 = h,
			color = o.pole or rgb(40, 40, 48),
			mat = "Metal",
		})
		K.ball({
			id = o.id .. "/bulb",
			kind = "bulb",
			set = "decor",
			x = o.x,
			z = o.z,
			dia = 1.2,
			h = h + 0.4,
			color = o.color or rgb(255, 226, 160),
			mat = "Neon",
			light = if o.lit then { color = o.color or rgb(255, 226, 160), range = 28, bright = 1.6 } else nil,
		})
	end

	--- A stone lantern 1 x 1 x 2.4 with a glowing box (decor).
	function K.stoneLantern(o: { [string]: any })
		K.box({
			id = o.id,
			kind = "lantern",
			x = o.x,
			z = o.z,
			w = 1,
			d = 1,
			h0 = o.h0 or 0,
			h1 = (o.h0 or 0) + 2.4,
			yaw = o.yaw or 0,
			color = rgb(120, 116, 110),
			mat = "Slate",
		})
		K.box({
			id = o.id .. "/glow",
			kind = "glow",
			set = "decor",
			x = o.x,
			z = o.z,
			w = 1.2,
			d = 1.2,
			h0 = (o.h0 or 0) + 2.4,
			h1 = (o.h0 or 0) + 3.2,
			yaw = o.yaw or 0,
			color = o.color or rgb(255, 190, 120),
			mat = "Neon",
			light = if o.lit ~= false then { color = o.color or rgb(255, 190, 120), range = 22, bright = 1.2 } else nil,
		})
	end

	--- A crossarm pair (Core set): 2 bars at yaw 45 and 135 crossing on the mast
	--- axis, their top at `top`. { id, x, z, top, len? (6), color? }.
	function K.crossarms(o: { [string]: any })
		for i, yaw in { 45, 135 } do
			K.box({
				id = o.id .. "/arm" .. i,
				kind = "crossarm",
				set = "core",
				x = o.x,
				z = o.z,
				w = o.len or 6,
				d = 0.5,
				h0 = o.top - 0.5,
				h1 = o.top,
				yaw = yaw,
				color = o.color or STEEL,
				mat = o.mat or "Metal",
			})
		end
	end

	--- A mast: { id, x, z, h, w? (1.6), color?, mat?, arms? (default when w < 2), armColor?, armLen?, tip? (neon colour), lit? }.
	function K.mast(o: { [string]: any })
		local w = o.w or 1.6
		K.box({
			id = o.id,
			kind = "mast",
			x = o.x,
			z = o.z,
			w = w,
			d = w,
			h0 = o.h0 or 0,
			h1 = o.h,
			yaw = o.yaw or 0,
			color = o.color or STEEL,
			mat = o.mat or "Metal",
			backdrop = o.backdrop,
			anchor = o.anchor,
		})
		if o.arms or (o.arms == nil and w < 2) then
			K.crossarms({
				id = o.id,
				x = o.x,
				z = o.z,
				top = o.h - 1,
				len = o.armLen,
				color = o.armColor or o.color or STEEL,
				mat = o.armMat or o.mat,
			})
		end
		if o.tip then
			K.ball({
				id = o.id .. "/tip",
				kind = "tip",
				set = "decor",
				x = o.x,
				z = o.z,
				dia = 1.6,
				h = o.h + 0.5,
				color = o.tip,
				mat = "Neon",
				light = if o.lit then { color = o.tip, range = 40, bright = 1.2 } else nil,
			})
		end
	end

	--- A floodlight mast facing C: { id, x, z, h? (20), w? (1.2), head? ("arms" | "bank"), lit?, color? }.
	function K.floodlight(o: { [string]: any })
		local h, w = o.h or 20, o.w or 1.2
		local b = bearing(0, 0, o.x, o.z)
		local face = o.face or b
		K.box({
			id = o.id,
			kind = "mast",
			x = o.x,
			z = o.z,
			w = w,
			d = w,
			h0 = 0,
			h1 = h,
			yaw = -face,
			color = o.color or STEEL,
			mat = "Metal",
		})
		local glow = o.glow or rgb(255, 236, 190)
		if o.head == "bank" then
			local px, pz = toWorld(o.x, o.z, -face, -(w / 2 + 0.3), 0)
			K.box({
				id = o.id .. "/bank",
				kind = "lampbank",
				set = "core",
				x = px,
				z = pz,
				w = 0.6,
				d = 6,
				h0 = h - 3,
				h1 = h,
				yaw = -face,
				color = o.color or STEEL,
				mat = "Metal",
			})
			local fx, fz = toWorld(o.x, o.z, -face, -(w / 2 + 0.65), 0)
			K.box({
				id = o.id .. "/face",
				kind = "glow",
				set = "decor",
				x = fx,
				z = fz,
				w = 0.1,
				d = 5.6,
				h0 = h - 2.8,
				h1 = h - 0.2,
				yaw = -face,
				color = glow,
				mat = "Neon",
				light = { kind = "spot", color = glow, range = 60, angle = 50, bright = 3, face = "Left" },
			})
		else
			K.crossarms({ id = o.id, x = o.x, z = o.z, top = h - 1, color = o.color or STEEL })
			local hx, hz = toWorld(o.x, o.z, -face, -(w / 2 + 0.3), 0)
			K.box({
				id = o.id .. "/head",
				kind = "glow",
				set = "decor",
				x = hx,
				z = hz,
				w = 0.6,
				d = 2.4,
				h0 = h - 1.4,
				h1 = h,
				yaw = -face,
				color = glow,
				mat = "Neon",
				light = if o.lit
					then { kind = "spot", color = glow, range = 50, angle = 60, bright = 2.5, face = "Left" }
					else nil,
			})
		end
	end

	--- A torii: posts at local x +-3, beam 9 wide with its top at 7.4, tie beam at 6.
	function K.torii(o: { [string]: any })
		local yaw, colour = o.yaw or 0, o.color or rgb(200, 40, 34)
		for i, s in { -1, 1 } do
			local px, pz = toWorld(o.x, o.z, yaw, s * 3, 0)
			K.cyl({
				id = o.id .. "/post" .. i,
				kind = "post",
				x = px,
				z = pz,
				w = 0.8,
				h0 = 0,
				h1 = 6.8,
				color = colour,
				mat = "SmoothPlastic",
			})
		end
		K.box({
			id = o.id .. "/beam",
			kind = "beam",
			x = o.x,
			z = o.z,
			w = 9,
			d = 0.9,
			h0 = 6.8,
			h1 = 7.4,
			yaw = yaw,
			color = rgb(28, 22, 22),
			mat = "SmoothPlastic",
		})
		K.box({
			id = o.id .. "/tie",
			kind = "beam",
			x = o.x,
			z = o.z,
			w = 7.5,
			d = 0.6,
			h0 = 5.8,
			h1 = 6.2,
			yaw = yaw,
			color = colour,
			mat = "SmoothPlastic",
		})
	end

	-- Buildings and anchors ----------------------------------------------------

	local function faceOffset(face: string, w: number, d: number): (number, number, number)
		-- local offset to the middle of a face, and that face's outward bearing in local yaw terms
		if face == "n" then
			return 0, -d / 2, 270
		elseif face == "s" then
			return 0, d / 2, 90
		elseif face == "e" then
			return w / 2, 0, 0
		end
		return -w / 2, 0, 180
	end

	--- Rails round a roof w x d at height h, with a gap `gap` (3) in the middle
	--- of every face listed in `open`. Faces are local: n (-Z), s, e (+X), w.
	function K.roofRails(o: { [string]: any })
		local yaw = o.yaw or 0
		local hw, hd = o.w / 2 - 0.15, o.d / 2 - 0.15
		local corners = {
			n = { { -hw, -hd }, { hw, -hd } },
			e = { { hw, -hd }, { hw, hd } },
			s = { { hw, hd }, { -hw, hd } },
			w = { { -hw, hd }, { -hw, -hd } },
		}
		local open: { [string]: any } = {}
		for _, f in o.open or {} do
			if type(f) == "table" then
				open[f[1]] = f
			else
				open[f] = true
			end
		end
		for _, f in o.faces or { "n", "e", "s", "w" } do
			local c = corners[f]
			local ax, az = toWorld(o.x, o.z, yaw, c[1][1], c[1][2])
			local bx, bz = toWorld(o.x, o.z, yaw, c[2][1], c[2][2])
			local len = sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local gaps = nil
			local g = open[f]
			if g then
				local width = if type(g) == "table" then (g[3] or o.gap or 3) else (o.gap or 3)
				local at = if type(g) == "table" and g[2] then g[2] else len / 2
				gaps = { { at - width / 2, at + width / 2 } }
			end
			K.rail({
				id = o.id .. "/rail-" .. f,
				a = { ax, az },
				b = { bx, bz },
				h = o.h,
				style = o.style,
				color = o.color,
				gaps = gaps,
			})
		end
	end

	--- Rails round an axis-aligned rectangle x0..x1, z0..z1 standing on h, set
	--- 0.15 in from its edges. { id, x0, x1, z0, z1, h, faces? { "n", "s", "e",
	--- "w" }, gaps? { { face, at (world x for n/s, world z for e/w), width } },
	--- style?, color? }. n is the z0 edge, s z1, w x0, e x1.
	function K.railRect(o: { [string]: any })
		local x0, x1 = math.min(o.x0, o.x1) + 0.15, math.max(o.x0, o.x1) - 0.15
		local z0, z1 = math.min(o.z0, o.z1) + 0.15, math.max(o.z0, o.z1) - 0.15
		local edges: { [string]: { any } } = {
			n = { { x0, z0 }, { x1, z0 }, x0 },
			s = { { x0, z1 }, { x1, z1 }, x0 },
			w = { { x0, z0 }, { x0, z1 }, z0 },
			e = { { x1, z0 }, { x1, z1 }, z0 },
		}
		for _, f in o.faces or { "n", "e", "s", "w" } do
			local e = edges[f]
			local cuts = {}
			for _, g in o.gaps or {} do
				if g[1] == f then
					local at = g[2] - e[3]
					table.insert(cuts, { at - g[3] / 2, at + g[3] / 2 })
				end
			end
			K.rail({ id = o.id .. "/" .. f, a = e[1], b = e[2], h = o.h, style = o.style, color = o.color, gaps = cuts })
		end
	end

	--- B1 tower:{ id, x, z, w, d, h, yaw?, color?, mat?, bands? (<= 3), band?, roof? (clutter),
	--- sign? { text, color }, backdrop?, keep?, anchor? }.
	function K.tower(o: { [string]: any })
		local yaw = o.yaw or 0
		K.box({
			id = o.id,
			kind = "tower",
			x = o.x,
			z = o.z,
			w = o.w,
			d = o.d,
			h0 = o.h0 or 0,
			h1 = o.h,
			yaw = yaw,
			color = o.color or rgb(38, 34, 52),
			mat = o.mat or "Concrete",
			backdrop = o.backdrop,
			keep = o.keep,
			anchor = o.anchor,
		})
		local n = math.min(o.bands or 0, 3)
		for i = 1, n do
			local bh = o.h * (0.3 + 0.55 * (i - 0.5) / n)
			K.box({
				id = o.id .. "/band" .. i,
				kind = "band",
				set = "decor",
				x = o.x,
				z = o.z,
				w = o.w + 0.1,
				d = o.d + 0.1,
				h0 = bh,
				h1 = bh + 0.8,
				yaw = yaw,
				color = o.band or rgb(255, 232, 170),
				mat = "Neon",
				backdrop = o.backdrop,
			})
		end
		if o.roof then
			local rx, rz = toWorld(o.x, o.z, yaw, o.w * 0.15, 0)
			K.box({
				id = o.id .. "/roof",
				kind = "roof",
				x = rx,
				z = rz,
				w = o.w * 0.3,
				d = o.d * 0.3,
				h0 = o.h,
				h1 = o.h + 2,
				yaw = yaw,
				color = rgb(60, 58, 64),
				mat = "Metal",
				backdrop = o.backdrop,
			})
		end
		if o.sign then
			-- On the face nearest C.
			local b = bearing(o.x, o.z, 0, 0) + yaw -- bearing to C in local terms
			local face, lx, lz, sw
			local l = ((b % 360) + 360) % 360
			if l >= 45 and l < 135 then
				face, lx, lz, sw = "s", 0, o.d / 2 + 0.3, o.w
			elseif l >= 135 and l < 225 then
				face, lx, lz, sw = "w", -o.w / 2 - 0.3, 0, o.d
			elseif l >= 225 and l < 315 then
				face, lx, lz, sw = "n", 0, -o.d / 2 - 0.3, o.w
			else
				face, lx, lz, sw = "e", o.w / 2 + 0.3, 0, o.d
			end
			local sx, sz = toWorld(o.x, o.z, yaw, lx, lz)
			local ww = math.min(sw * 0.8, 18)
			local hh = ww * 0.45
			local top = o.h - 3
			local isNS = face == "n" or face == "s"
			K.box({
				id = o.id .. "/sign",
				kind = "sign",
				set = "decor",
				x = sx,
				z = sz,
				w = if isNS then ww else 0.4,
				d = if isNS then 0.4 else ww,
				h0 = top - hh,
				h1 = top,
				yaw = yaw,
				color = rgb(14, 14, 20),
				mat = "SmoothPlastic",
				backdrop = o.backdrop,
				text = {
					text = o.sign.text,
					face = ({ n = "Front", s = "Back", e = "Right", w = "Left" })[face],
					color = o.sign.color,
					bg = o.sign.bg,
				},
				light = if o.sign.lit ~= false
					then { color = o.sign.color or rgb(255, 61, 127), range = 30, bright = 2 }
					else nil,
			})
		end
	end

	--- B2 walk-up 12 x 12, roof at 9: body, 4 roof rails, truss, 2 bands, tank, door.
	--- { id, x, z, yaw?, truss = face, open? { faces with a 3 u rail gap }, color?, lit? }.
	function K.walkup(o: { [string]: any })
		local yaw = o.yaw or 0
		local h = o.h or 9
		local s = o.size or 12
		K.box({
			id = o.id,
			kind = "roof",
			x = o.x,
			z = o.z,
			w = s,
			d = s,
			h0 = 0,
			h1 = h,
			yaw = yaw,
			color = o.color or rgb(92, 70, 64),
			mat = o.mat or "Brick",
		})
		for i, bh in { 3.2, 6.4 } do
			K.box({
				id = o.id .. "/band" .. i,
				kind = "band",
				set = "decor",
				x = o.x,
				z = o.z,
				w = s + 0.1,
				d = s + 0.1,
				h0 = bh,
				h1 = bh + 0.6,
				yaw = yaw,
				color = o.band or rgb(255, 214, 140),
				mat = "Neon",
			})
		end
		local open = table.clone(o.open or {})
		if o.truss then
			table.insert(open, o.truss)
		end
		K.roofRails({ id = o.id, x = o.x, z = o.z, w = s, d = s, h = h, yaw = yaw, open = open })
		if o.truss then
			local fx, fz = faceOffset(o.truss, s, s)
			local nx, nz = 0, 0
			if fx ~= 0 then
				nx = if fx > 0 then 0.42 else -0.42
			else
				nz = if fz > 0 then 0.42 else -0.42
			end
			local tx, tz = toWorld(o.x, o.z, yaw, fx + nx, fz + nz)
			K.ladder({ id = o.id .. "/truss", x = tx, z = tz, top = h, yaw = yaw })
		end
		local kx, kz = toWorld(o.x, o.z, yaw, s / 2 - 2.5, s / 2 - 2.5)
		K.cyl({
			id = o.id .. "/tank",
			kind = "tank",
			x = kx,
			z = kz,
			w = 2.6,
			h0 = h,
			h1 = h + 2.4,
			color = rgb(110, 90, 70),
			mat = "WoodPlanks",
		})
		local dx, dz = toWorld(o.x, o.z, yaw, 0, -s / 2 - 0.05)
		K.box({
			id = o.id .. "/door",
			kind = "door",
			set = "decor",
			x = dx,
			z = dz,
			w = 2,
			d = 0.1,
			h0 = 0,
			h1 = 3,
			yaw = yaw,
			color = rgb(255, 200, 130),
			mat = "Neon",
			light = if o.lit then { color = rgb(255, 200, 130), range = 18, bright = 1 } else nil,
		})
	end

	--- B3 arcade 14 x 10 (front = local -Z), open ground storey 5 tall, roof at 9:
	--- back wall, side wall, 3 columns, upper mass, counter, sign, 4 rails, truss.
	--- { id, x, z, yaw?, truss = face, trussAt? (offset along that face), open?, sign?, color? }.
	function K.arcade(o: { [string]: any })
		local yaw = o.yaw or 0
		local w, d, h = o.w or 14, o.d or 10, o.h or 9
		local colour = o.color or rgb(70, 50, 80)
		local function put(
			id: string,
			lx: number,
			lz: number,
			sw: number,
			sd: number,
			h0: number,
			h1: number,
			extra: { [string]: any }?
		)
			local x, z = toWorld(o.x, o.z, yaw, lx, lz)
			local r = {
				id = o.id .. id,
				kind = "wall",
				x = x,
				z = z,
				w = sw,
				d = sd,
				h0 = h0,
				h1 = h1,
				yaw = yaw,
				color = colour,
				mat = o.mat or "Brick",
			}
			for k, v in pairs(extra or {}) do
				r[k] = v
			end
			return K.box(r)
		end
		put("/back", 0, d / 2 - 0.3, w, 0.6, 0, 5)
		put("/side", -w / 2 + 0.3, 0, 0.6, d, 0, 5)
		for i, lx in { -w / 2 + 0.4, 0, w / 2 - 0.4 } do
			put("/col" .. i, lx, -d / 2 + 0.4, 0.8, 0.8, 0, 5)
		end
		put("", 0, 0, w, d, 5, h, { kind = "roof" })
		put("/counter", 1, d / 2 - 2, 6, 1.2, 0, 1.1, { color = rgb(120, 92, 64), mat = "WoodPlanks" })
		local sx, sz = toWorld(o.x, o.z, yaw, 0, -d / 2 - 0.15)
		K.box({
			id = o.id .. "/sign",
			kind = "sign",
			set = "decor",
			x = sx,
			z = sz,
			w = w * 0.8,
			d = 0.2,
			h0 = 5.6,
			h1 = 8.4,
			yaw = yaw,
			color = rgb(14, 14, 20),
			text = if o.sign then { text = o.sign, color = o.signColor or rgb(255, 214, 90) } else nil,
			light = { color = o.signColor or rgb(255, 214, 90), range = 24, bright = 1.5 },
		})
		local open = table.clone(o.open or {})
		if o.truss then
			table.insert(open, { o.truss, o.trussAt })
		end
		local railOpen = {}
		for _, f in open do
			if type(f) == "table" then
				local fx, fz = faceOffset(f[1], w, d)
				local len = if f[1] == "n" or f[1] == "s" then w - 0.3 else d - 0.3
				local at = if f[2] then len / 2 + f[2] else nil
				if (f[1] == "s" or f[1] == "w") and f[2] then
					at = len / 2 - f[2]
				end
				local _ = fx + fz
				table.insert(railOpen, { f[1], at })
			else
				table.insert(railOpen, f)
			end
		end
		K.roofRails({ id = o.id, x = o.x, z = o.z, w = w, d = d, h = h, yaw = yaw, open = railOpen })
		if o.truss then
			local fx, fz = faceOffset(o.truss, w, d)
			local along = o.trussAt or 0
			local lx, lz = fx, fz
			if o.truss == "n" or o.truss == "s" then
				lx += along
				lz += if fz > 0 then 0.42 else -0.42
			else
				lz += along
				lx += if fx > 0 then 0.42 else -0.42
			end
			local tx, tz = toWorld(o.x, o.z, yaw, lx, lz)
			K.ladder({ id = o.id .. "/truss", x = tx, z = tz, top = h, yaw = yaw })
		end
	end

	--- B4 pavilion hall (front = local -Z): podium, step wedge, 2 treads, 6 posts,
	--- back wall, 2 roof tiers, ridge. { id, x, z, w, d, h, yaw?, h0? (podium top,
	--- 0.6), closed? (a solid core), wall?, roof?, lit? }.
	function K.pavilion(o: { [string]: any })
		local yaw = o.yaw or 0
		local w, d, h = o.w, o.d, o.h
		local base = o.h0 or 0.6
		local wall, roof = o.wall or rgb(150, 60, 44), o.roof or rgb(58, 62, 70)
		local function put(
			id: string,
			lx: number,
			lz: number,
			sw: number,
			sd: number,
			h0: number,
			h1: number,
			extra: { [string]: any }?
		)
			local x, z = toWorld(o.x, o.z, yaw, lx, lz)
			local r = {
				id = o.id .. id,
				kind = "wall",
				x = x,
				z = z,
				w = sw,
				d = sd,
				h0 = h0,
				h1 = h1,
				yaw = yaw,
				color = wall,
				mat = "WoodPlanks",
			}
			for k, v in pairs(extra or {}) do
				r[k] = v
			end
			return K.box(r)
		end
		if base > 0 then
			put(
				"/podium",
				0,
				0,
				w,
				d,
				0,
				base,
				{ kind = "podium", color = rgb(150, 146, 138), mat = "Slate", floor = true }
			)
			local sx, sz = toWorld(o.x, o.z, yaw, 0, -d / 2 - 0.875 * base)
			K.wedge({
				id = o.id .. "/step",
				kind = "stairs",
				x = sx,
				z = sz,
				w = 1.75 * base,
				d = math.min(6, w / 2),
				h0 = 0,
				h1 = base,
				run = yaw + 90,
				color = rgb(150, 146, 138),
				mat = "Slate",
			})
			for i = 1, 2 do
				local tx, tz = toWorld(o.x, o.z, yaw, 0, -d / 2 - 1.75 * base * (i - 0.5) / 2)
				K.box({
					id = o.id .. "/tread" .. i,
					kind = "tread",
					set = "decor",
					x = tx,
					z = tz,
					w = math.min(6, w / 2) + 0.1,
					d = 0.2,
					h0 = 0,
					h1 = base * (3 - i) / 2 - 0.05,
					yaw = yaw,
					color = rgb(170, 166, 158),
					mat = "Slate",
				})
			end
		end
		for i, s in { { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0.2 }, { 1, 0.2 }, { 0, 0.2 } } do
			if not (o.closed and s[2] > 0) then
				put(
					"/post" .. i,
					s[1] * (w / 2 - 0.6),
					s[2] * (d / 2 - 0.6),
					0.8,
					0.8,
					base,
					base + h,
					{ kind = "post", color = o.post or rgb(150, 40, 34) }
				)
			end
		end
		put("/back", 0, d / 2 - 0.3, w - 0.4, 0.6, base, base + h)
		if o.closed then
			put("/core", 0, 0.3, w - 1.2, d - 1.8, base, base + h, { kind = "hall" })
		end
		put("", 0, 0, w + 2, d + 2, base + h, base + h + 0.8, { kind = "roof", color = roof, mat = "Slate" })
		put(
			"/roof2",
			0,
			0,
			w * 0.75,
			d * 0.75,
			base + h + 0.8,
			base + h + 1.8,
			{ kind = "roof", color = roof, mat = "Slate" }
		)
		put("/ridge", 0, 0, w * 0.6, 0.6, base + h + 1.8, base + h + 2.3, {
			kind = "roof",
			color = rgb(181, 140, 60),
			mat = "Metal",
			light = if o.lit ~= false then { color = rgb(255, 190, 120), range = 24, bright = 1 } else nil,
		})
	end

	--- B5 watchtower: 5 x 5 core to the deck, 6 x 6 deck, 4 rails, 2 posts, roof, truss.
	--- { id, x, z, deck (height), top, yaw?, truss = face, trussBase?, open?, color? }.
	function K.watchtower(o: { [string]: any })
		local yaw = o.yaw or 0
		local colour = o.color or rgb(120, 92, 64)
		K.box({
			id = o.id .. "/core",
			kind = "tower",
			x = o.x,
			z = o.z,
			w = 5,
			d = 5,
			h0 = o.h0 or 0,
			h1 = o.deck - 0.5,
			yaw = yaw,
			color = o.coreColor or rgb(150, 146, 138),
			mat = "Slate",
		})
		K.deck({ id = o.id, kind = "deck", x = o.x, z = o.z, w = 6, d = 6, h = o.deck, yaw = yaw, color = colour })
		local open = table.clone(o.open or {})
		if o.truss then
			table.insert(open, o.truss)
		end
		K.roofRails({ id = o.id, x = o.x, z = o.z, w = 6, d = 6, h = o.deck, yaw = yaw, open = open, style = "timber" })
		for i, s in { { -1, -1 }, { 1, 1 } } do
			local px, pz = toWorld(o.x, o.z, yaw, s[1] * 2.7, s[2] * 2.7)
			K.box({
				id = o.id .. "/post" .. i,
				kind = "post",
				x = px,
				z = pz,
				w = 0.5,
				d = 0.5,
				h0 = o.deck,
				h1 = o.top - 1,
				color = TIMBER,
				mat = "Wood",
			})
		end
		K.box({
			id = o.id .. "/roof",
			kind = "roof",
			x = o.x,
			z = o.z,
			w = 7.5,
			d = 7.5,
			h0 = o.top - 1,
			h1 = o.top,
			yaw = yaw,
			color = o.roof or rgb(58, 62, 70),
			mat = "Slate",
			light = { color = rgb(255, 190, 120), range = 20, bright = 1 },
		})
		if o.truss then
			local fx, fz = faceOffset(o.truss, 5, 5)
			local lx, lz = fx, fz
			if fx ~= 0 then
				lx += if fx > 0 then 0.42 else -0.42
			else
				lz += if fz > 0 then 0.42 else -0.42
			end
			local tx, tz = toWorld(o.x, o.z, yaw, lx, lz)
			K.ladder({ id = o.id .. "/truss", x = tx, z = tz, top = o.deck, base = o.trussBase or 0, yaw = yaw })
		end
	end

	--- B6 mudbrick house 9 x 9, roof at h: body, edge rails, door, window, roof clutter.
	--- { id, x, z, h, yaw?, rails? { faces }, open?, color? }.
	function K.house(o: { [string]: any })
		local yaw = o.yaw or 0
		local s = o.size or 9
		K.box({
			id = o.id,
			kind = "roof",
			x = o.x,
			z = o.z,
			w = s,
			d = s,
			h0 = 0,
			h1 = o.h,
			yaw = yaw,
			color = o.color or rgb(196, 150, 100),
			mat = o.mat or "Sandstone",
		})
		if o.rails then
			K.roofRails({
				id = o.id,
				x = o.x,
				z = o.z,
				w = s,
				d = s,
				h = o.h,
				yaw = yaw,
				faces = o.rails,
				open = o.open,
				color = o.railColor or rgb(150, 110, 70),
			})
		end
		local dx, dz = toWorld(o.x, o.z, yaw, 0, -s / 2 - 0.05)
		K.box({
			id = o.id .. "/door",
			kind = "door",
			set = "decor",
			x = dx,
			z = dz,
			w = 1.8,
			d = 0.1,
			h0 = 0,
			h1 = 2.8,
			yaw = yaw,
			color = rgb(60, 44, 30),
			mat = "Wood",
		})
		local wx, wz = toWorld(o.x, o.z, yaw, s / 2 + 0.05, 0)
		K.box({
			id = o.id .. "/window",
			kind = "window",
			set = "decor",
			x = wx,
			z = wz,
			w = 0.1,
			d = 1.4,
			h0 = o.h - 2.4,
			h1 = o.h - 1.2,
			yaw = yaw,
			color = rgb(60, 44, 30),
			mat = "Wood",
		})
		if o.clutter ~= false then
			local cx, cz = toWorld(o.x, o.z, yaw, -s / 4, s / 4)
			K.box({
				id = o.id .. "/clutter",
				kind = "clutter",
				set = "decor",
				x = cx,
				z = cz,
				w = 1.2,
				d = 1.2,
				h0 = o.h,
				h1 = o.h + 0.6,
				yaw = yaw,
				color = rgb(160, 120, 80),
				mat = "Fabric",
			})
		end
	end

	--- B7 stilt house: deck 14 x 12 (top `deck`, 0.4), 4 stilts from `base`, body 11 x 9 x 6, 2 roofs, lit door.
	function K.stilthouse(o: { [string]: any })
		local yaw = o.yaw or 0
		local top = o.deck or 0.4
		K.deck({
			id = o.id,
			kind = "deck",
			x = o.x,
			z = o.z,
			w = 14,
			d = 12,
			h = top,
			t = 0.6,
			yaw = yaw,
			posts = 4,
			base = o.base or -3,
			postW = 0.8,
		})
		local bx, bz = toWorld(o.x, o.z, yaw, 0, 1)
		K.box({
			id = o.id .. "/body",
			kind = "wall",
			x = bx,
			z = bz,
			w = 11,
			d = 9,
			h0 = top,
			h1 = top + 6,
			yaw = yaw,
			color = o.color or rgb(170, 140, 100),
			mat = "WoodPlanks",
		})
		K.box({
			id = o.id .. "/roof",
			kind = "roof",
			x = bx,
			z = bz,
			w = 13,
			d = 11,
			h0 = top + 6,
			h1 = top + 6.8,
			yaw = yaw,
			color = o.roof or rgb(60, 80, 100),
			mat = "Slate",
		})
		K.box({
			id = o.id .. "/roof2",
			kind = "roof",
			x = bx,
			z = bz,
			w = 9,
			d = 7,
			h0 = top + 6.8,
			h1 = top + 7.6,
			yaw = yaw,
			color = o.roof or rgb(60, 80, 100),
			mat = "Slate",
		})
		local dx, dz = toWorld(o.x, o.z, yaw, 0, 1 - 4.55)
		K.box({
			id = o.id .. "/door",
			kind = "door",
			set = "decor",
			x = dx,
			z = dz,
			w = 2.4,
			d = 0.1,
			h0 = top,
			h1 = top + 3.4,
			yaw = yaw,
			color = rgb(255, 196, 120),
			mat = "Neon",
			light = if o.lit ~= false then { color = rgb(255, 190, 120), range = 20, bright = 1 } else nil,
		})
	end

	--- Academy dorm 22 x 14 x 8 (w along local X), balcony 2 deep at h 5 on the local -Z face.
	function K.dorm(o: { [string]: any })
		local yaw = o.yaw or 0
		local w, d, h = o.w or 22, o.d or 14, o.h or 8
		K.box({
			id = o.id,
			kind = "wall",
			x = o.x,
			z = o.z,
			w = w,
			d = d,
			h0 = 0,
			h1 = h,
			yaw = yaw,
			color = o.color or rgb(232, 226, 214),
			mat = "SmoothPlastic",
		})
		K.box({
			id = o.id .. "/roof",
			kind = "roof",
			x = o.x,
			z = o.z,
			w = w + 1,
			d = d + 1,
			h0 = h,
			h1 = h + 0.6,
			yaw = yaw,
			color = rgb(58, 62, 70),
			mat = "Slate",
		})
		local bx, bz = toWorld(o.x, o.z, yaw, 0, -d / 2 - 1)
		K.box({
			id = o.id .. "/balcony",
			kind = "deck",
			x = bx,
			z = bz,
			w = w,
			d = 2,
			h0 = 4.6,
			h1 = 5,
			yaw = yaw,
			color = rgb(120, 92, 64),
			mat = "WoodPlanks",
		})
		local ax, az = toWorld(o.x, o.z, yaw, -w / 2 + 0.15, -d / 2 - 1.85)
		local cx, cz = toWorld(o.x, o.z, yaw, w / 2 - 0.15, -d / 2 - 1.85)
		K.rail({ id = o.id .. "/rail", a = { ax, az }, b = { cx, cz }, h = 5, style = "timber", gaps = o.railGaps })
		for i, s in { -1, 1 } do
			local px, pz = toWorld(o.x, o.z, yaw, s * (w / 2 - 0.3), -d / 2 - 1.7)
			K.box({
				id = o.id .. "/post" .. i,
				kind = "post",
				x = px,
				z = pz,
				w = 0.5,
				d = 0.5,
				h0 = 0,
				h1 = 4.6,
				color = TIMBER,
				mat = "Wood",
			})
		end
		for i, bh in { 2, 6 } do
			local wx, wz = toWorld(o.x, o.z, yaw, 0, -d / 2 - 0.05)
			K.box({
				id = o.id .. "/band" .. i,
				kind = "band",
				set = "decor",
				x = wx,
				z = wz,
				w = w - 2,
				d = 0.1,
				h0 = bh,
				h1 = bh + 1,
				yaw = yaw,
				color = rgb(70, 76, 90),
				mat = "Glass",
			})
		end
		local dx, dz = toWorld(o.x, o.z, yaw, 0, d / 2 + 0.05)
		K.box({
			id = o.id .. "/door",
			kind = "door",
			set = "decor",
			x = dx,
			z = dz,
			w = 2,
			d = 0.1,
			h0 = 0,
			h1 = 3,
			yaw = yaw,
			color = rgb(255, 200, 130),
			mat = "Neon",
			light = { color = rgb(255, 200, 130), range = 18, bright = 1 },
		})
	end

	--- Tea pavilion: deck 8 x 8 at 1.5 on 4 stilts, a step ramp, 4 posts, a roof.
	--- { id, x, z, yaw?, h? (1.5), step? (face bearing of the ramp, default south of the deck) }.
	function K.teahouse(o: { [string]: any })
		local yaw = o.yaw or 0
		local h = o.h or 1.5
		K.deck({
			id = o.id,
			kind = "deck",
			x = o.x,
			z = o.z,
			w = 8,
			d = 8,
			h = h,
			t = 0.4,
			yaw = yaw,
			posts = 4,
			postW = 0.5,
		})
		local run = o.run or (-yaw + 270) -- climbing toward the deck from the local +Z side by default
		local fx, fz = toWorld(o.x, o.z, yaw, 0, 4 + 1.75 * h)
		if o.foot then
			fx, fz = o.foot[1], o.foot[2]
		end
		K.ramp({
			id = o.id .. "/step",
			x = fx,
			z = fz,
			run = run,
			w = 3,
			rise = h,
			color = rgb(120, 92, 64),
			mat = "WoodPlanks",
		})
		for i, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local px, pz = toWorld(o.x, o.z, yaw, s[1] * 3.6, s[2] * 3.6)
			K.box({
				id = o.id .. "/pillar" .. i,
				kind = "post",
				x = px,
				z = pz,
				w = 0.4,
				d = 0.4,
				h0 = h,
				h1 = h + 4,
				color = rgb(150, 40, 34),
				mat = "Wood",
			})
		end
		K.box({
			id = o.id .. "/roof",
			kind = "roof",
			x = o.x,
			z = o.z,
			w = 9.5,
			d = 9.5,
			h0 = h + 4,
			h1 = h + 4.8,
			yaw = yaw,
			color = rgb(58, 62, 70),
			mat = "Slate",
			light = { color = rgb(255, 190, 120), range = 20, bright = 1 },
		})
	end

	--- Windcatcher: a core w x w (4.5) from h0 to top, and 2 vents (decor).
	function K.windcatcher(o: { [string]: any })
		local w = o.w or 4.5
		K.box({
			id = o.id,
			kind = "tower",
			x = o.x,
			z = o.z,
			w = w,
			d = w,
			h0 = o.h0 or 0,
			h1 = o.top,
			yaw = o.yaw or 0,
			color = o.color or rgb(206, 170, 120),
			mat = "Sandstone",
		})
		for i, s in { -1, 1 } do
			local vx, vz = toWorld(o.x, o.z, o.yaw or 0, 0, s * (w / 2 + 0.05))
			K.box({
				id = o.id .. "/vent" .. i,
				kind = "vent",
				set = "decor",
				x = vx,
				z = vz,
				w = w * 0.6,
				d = 0.1,
				h0 = o.top - 3,
				h1 = o.top - 0.8,
				yaw = o.yaw or 0,
				color = rgb(60, 44, 30),
				mat = "Wood",
			})
		end
	end

	--- A tree: { id, x, z, h, kind = "cedar" | "pine" | "broadleaf" | "blossom" | "palm" | "backdrop", color? }.
	--- Cedars and pines are anchors: a Solid trunk to 0.55 h, 3 Foliage crowns and a Core cylinder to 0.95 h.
	function K.tree(o: { [string]: any })
		local h, kind = o.h, o.kind or "cedar"
		if kind == "cedar" or kind == "pine" then
			local leaves = o.color or (if kind == "cedar" then rgb(46, 74, 52) else rgb(38, 64, 48))
			K.cyl({
				id = o.id,
				kind = "trunk",
				x = o.x,
				z = o.z,
				w = if kind == "cedar" then 1.6 else 1.2,
				h0 = 0,
				h1 = 0.55 * h,
				color = rgb(92, 64, 44),
				mat = "Wood",
			})
			for i, f in { { 0.26, 0.62 }, { 0.21, 0.77 }, { 0.15, 0.9 } } do
				K.ball({
					id = o.id .. "/crown" .. i,
					kind = "crown",
					set = "foliage",
					x = o.x,
					z = o.z,
					dia = f[1] * h,
					h = f[2] * h,
					color = leaves,
					mat = "Grass",
				})
			end
			K.cyl({
				id = o.id .. "/core",
				kind = "core",
				set = "core",
				x = o.x,
				z = o.z,
				w = 1.2,
				h0 = 0.55 * h,
				h1 = 0.95 * h,
				color = rgb(92, 64, 44),
				mat = "Wood",
			})
		elseif kind == "palm" then
			K.cyl({
				id = o.id,
				kind = "trunk",
				x = o.x,
				z = o.z,
				w = 0.8,
				h0 = 0,
				h1 = h,
				color = rgb(130, 100, 70),
				mat = "Wood",
			})
			for i = 1, 4 do
				local fx, fz = toWorld(o.x, o.z, i * 90 + 20, 2, 0)
				K.box({
					id = o.id .. "/frond" .. i,
					kind = "frond",
					set = "decor",
					x = fx,
					z = fz,
					w = 4.5,
					d = 1.2,
					h0 = h - 0.3,
					h1 = h,
					yaw = i * 90 + 20,
					color = o.color or rgb(70, 130, 60),
					mat = "Grass",
					lean = { 0, 0, -18 },
				})
			end
		elseif kind == "backdrop" then
			K.cyl({
				id = o.id,
				kind = "trunk",
				set = "decor",
				x = o.x,
				z = o.z,
				w = 1.6,
				h0 = 0,
				h1 = 0.55 * h,
				color = rgb(92, 64, 44),
				mat = "Wood",
				backdrop = true,
			})
			for i, f in { { 0.3, 0.62 }, { 0.2, 0.82 } } do
				K.ball({
					id = o.id .. "/crown" .. i,
					kind = "crown",
					set = "decor",
					x = o.x,
					z = o.z,
					dia = f[1] * h,
					h = f[2] * h,
					color = o.color or rgb(46, 74, 52),
					mat = "Grass",
					backdrop = true,
				})
			end
		else
			K.cyl({
				id = o.id,
				kind = "trunk",
				x = o.x,
				z = o.z,
				w = 0.8,
				h0 = 0,
				h1 = 0.55 * h,
				color = rgb(86, 60, 42),
				mat = "Wood",
			})
			local leaves = o.color or (if kind == "blossom" then rgb(255, 183, 206) else rgb(70, 120, 80))
			for i, f in { { 0, 0, 0.45 }, { 0.12, 0.1, 0.36 }, { -0.1, 0.14, 0.34 } } do
				local bx, bz = o.x + f[1] * h, o.z + f[2] * h
				K.ball({
					id = o.id .. "/crown" .. i,
					kind = "crown",
					set = "decor",
					x = bx,
					z = bz,
					dia = f[3] * h,
					h = 0.6 * h + i * 0.05 * h,
					color = leaves,
					mat = if kind == "blossom" then "SmoothPlastic" else "Grass",
				})
			end
		end
	end

	--- An anchor mass: a block w x d x h (d defaults to w) and an optional decor trim band.
	--- { id, x, z, w, d?, h, h0?, yaw?, color, mat, trim? { h, t?, color, mat?, grow? } }.
	function K.mass(o: { [string]: any })
		local r = K.box({
			id = o.id,
			kind = o.kind or "mass",
			x = o.x,
			z = o.z,
			w = o.w,
			d = o.d or o.w,
			h0 = o.h0 or 0,
			h1 = o.h,
			yaw = o.yaw or 0,
			color = o.color,
			mat = o.mat,
			backdrop = o.backdrop,
			keep = o.keep,
			anchor = o.anchor,
			light = o.light,
		})
		if o.trim then
			local t = o.trim
			local g = t.grow or 0.4
			K.box({
				id = o.id .. "/trim",
				kind = "trim",
				set = "decor",
				x = o.x,
				z = o.z,
				w = o.w + g,
				d = (o.d or o.w) + g,
				h0 = t.h,
				h1 = t.h + (t.t or 1),
				yaw = o.yaw or 0,
				color = t.color,
				mat = t.mat or "SmoothPlastic",
				alpha = t.alpha,
				backdrop = o.backdrop,
			})
		end
		return r
	end

	--- The block cistern (water tower): 4 legs to 17, a tank 9 across at 17-23, a cap to 25, a ladder (decor).
	function K.cistern(o: { [string]: any })
		for i, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			K.box({
				id = o.id .. "/leg" .. i,
				kind = "post",
				x = o.x + s[1] * 2.8,
				z = o.z + s[2] * 2.8,
				w = 0.8,
				d = 0.8,
				h0 = 0,
				h1 = 17,
				color = STEEL,
				mat = "Metal",
			})
		end
		K.cyl({
			id = o.id,
			kind = "tank",
			x = o.x,
			z = o.z,
			w = 9,
			h0 = 17,
			h1 = 23,
			color = rgb(112, 84, 64),
			mat = "CorrodedMetal",
			text = if o.stencil then { text = o.stencil, face = "Top", color = rgb(230, 226, 214) } else nil,
		})
		K.cyl({
			id = o.id .. "/cap",
			kind = "tank",
			x = o.x,
			z = o.z,
			w = 5.4,
			h0 = 23,
			h1 = 25,
			color = rgb(90, 70, 56),
			mat = "CorrodedMetal",
		})
		K.box({
			id = o.id .. "/ladder",
			kind = "ladder",
			set = "decor",
			x = o.x,
			z = o.z - 2.8,
			w = 0.8,
			d = 0.2,
			h0 = 0,
			h1 = 17,
			color = STEEL,
			mat = "Metal",
		})
	end

	--- A fence of n pylons (1.6 x h, neon head) at radius r, with light-curtain Beams between neighbours.
	function K.pylonFence(o: { [string]: any })
		local h = o.h or 14
		for i = 1, o.n do
			local b = (o.b0 or 0) + (i - 1) * 360 / o.n
			local x, z = Layouts.around(b, o.r)
			K.box({
				id = o.id .. "/" .. i,
				kind = "mast",
				x = x,
				z = z,
				w = 1.6,
				d = 1.6,
				h0 = 0,
				h1 = h,
				yaw = -b,
				color = o.color or rgb(60, 64, 70),
				mat = "Metal",
				backdrop = true,
			})
			K.box({
				id = o.id .. "/" .. i .. "/head",
				kind = "glow",
				set = "decor",
				x = x,
				z = z,
				w = 2,
				d = 2,
				h0 = h,
				h1 = h + 1,
				yaw = -b,
				color = o.glow or rgb(255, 170, 40),
				mat = "Neon",
				backdrop = true,
			})
			local b2 = b + 360 / o.n
			local x2, z2 = Layouts.around(b2, o.r)
			table.insert(P.beams, {
				a = { x, z, h * 0.5 },
				b = { x2, z2, h * 0.5 },
				color = o.glow or rgb(255, 170, 40),
				width = 20,
				alpha = 0.6,
				emission = 1,
			})
		end
	end

	--- Seeded scatter, placed after everything else: `make(id, x, z, rng)` builds one piece
	--- at an accepted spot. { id, n, radius (plan clearance of one piece), make,
	--- region = { r0, r1, b0?, b1? } | { x0, x1, z0, z1 }, tries? }.
	--- Spots are rejected inside pad boxes (+0.5), inside footprints, within 3 u of
	--- walks and access, within 2 u of the hero sightline, inside the Rift Plaza and in water.
	function K.scatter(o: { [string]: any })
		table.insert(scatters, o)
	end

	-- Scatter runs at the end (Layouts.plan calls this).
	function K._finish()
		for _, o in scatters do
			local placed, tries = 0, 0
			while placed < o.n and tries < (o.tries or o.n * 40) do
				tries += 1
				local x, z
				local g = o.region
				if g.r0 then
					local b = K.rng.num(g.b0 or 0, g.b1 or 360)
					x, z = Layouts.around(b, K.rng.num(g.r0, g.r1))
				else
					x, z = K.rng.num(g.x0, g.x1), K.rng.num(g.z0, g.z1)
				end
				if Layouts.spotFree(P, x, z, o.radius or 1.5) then
					placed += 1
					scatterNow = true
					o.make(o.id .. placed, x, z, K.rng)
					scatterNow = false
				end
			end
		end
	end

	return K, P
end

--- Distance from (px, pz) to the plan segment a-b.
local function segDist(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local vx, vz = bx - ax, bz - az
	local l2 = vx * vx + vz * vz
	local t = if l2 > 0 then math.clamp(((px - ax) * vx + (pz - az) * vz) / l2, 0, 1) else 0
	return sqrt((px - ax - vx * t) ^ 2 + (pz - az - vz * t) ^ 2)
end
Layouts.segDist = segDist

--- Whether a scatter piece of plan radius `r` may stand at (x, z) (design §1.4).
function Layouts.spotFree(P: Plan, x: number, z: number, r: number): boolean
	if sqrt(x * x + z * z) < math.max(P.r0, 12) + r then
		return false
	end
	for _, p in P.pads do
		local e = (if p.boss then 8 else 6) + 0.5 + r
		if math.abs(x - p.x) <= e and math.abs(z - p.z) <= e then
			return false
		end
	end
	for _, fp in P.recs do
		if fp.set ~= "decor" and not fp.backdrop and inPlan(fp, x, z, r) then
			return false
		end
	end
	for _, w in P.walks do
		if segDist(x, z, w.a[1], w.a[2], w.b[1], w.b[2]) < w.w / 2 + 3 + r then
			return false
		end
	end
	for _, a in P.access do
		if segDist(x, z, a.foot[1], a.foot[2], a.top[1], a.top[2]) < a.w / 2 + 3 + r then
			return false
		end
	end
	if P.hero and segDist(x, z, 0, 0, P.hero.x, P.hero.z) < 2 + r then
		return false
	end
	for _, wt in P.water do
		if wt.r then
			if (x - wt.x) ^ 2 + (z - wt.z) ^ 2 < (wt.r + r) ^ 2 then
				return false
			end
		elseif inPlan({ shape = "box", x = wt.x, z = wt.z, w = wt.w, d = wt.d, yaw = wt.yaw or 0 } :: any, x, z, r) then
			return false
		end
	end
	return true
end

--- Lays a world out: `def` is the world's layout function (a child module of
--- this one). Returns the finished plan.
function Layouts.plan(theme: string, def: (any) -> (), seed: number?): Plan
	local K, P = Layouts.kit(theme, seed or 1)
	def(K)
	K._finish()
	return P
end

Layouts.THEMES = { "city", "academy", "tomb", "kyoto", "ruin", "desert", "earth", "water", "storm", "seam" }

--- Each map's `build` key and the theme (layout file) it uses.
Layouts.THEME_OF = {
	buildTimesSquare = "city",
	buildCullingColony = "ruin",
	buildJujutsuHigh = "academy",
	buildKyoto = "kyoto",
	buildStarCorridor = "tomb",
	buildLandOfWind = "desert",
	buildLandOfEarth = "earth",
	buildLandOfWater = "water",
	buildLandOfLightning = "storm",
	buildSeam = "seam",
} :: { [string]: string }

--- Grid points the swing gate expects per world (design §3.11); a drift of more than 3 warns.
Layouts.EXPECT = {
	city = 53,
	academy = 41,
	tomb = 60,
	kyoto = 52,
	ruin = 52,
	desert = 53,
	earth = 46,
	water = 67,
	storm = 63,
	seam = 70,
} :: { [string]: number }

--- What the portal, the weather part and the Nav part add to every world.
Layouts.FIXED_PARTS = 31
Layouts.FIXED_LIGHTS = 1

return Layouts
