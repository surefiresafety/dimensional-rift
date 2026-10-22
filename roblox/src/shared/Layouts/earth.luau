--!strict
-- Quarry Hollow (Land of Earth), afternoon. Design: docs/design/worlds.md §3.7.
-- A canyon bowl of Rock hills beyond r 60. Four cliff-dwelling stacks carry
-- galleries at h 10, joined through four rock needles by the Rope Ring, the
-- upper loop. Cut benches with hoist sheds and headframes stand east and west,
-- the Quarry Crane (the hero) to the north and the Stone Gate to the south.

return function(K: any)
	local rgb = K.rgb
	K.budget(280, 16)
	K.ground("Ground", rgb(150, 120, 88))
	K.hills({
		minGround = 60,
		keepOut = { { bearing = 90, halfWidth = 12 } },
		count = 36,
		rMin = 16,
		rMax = 36,
		material = "Rock",
	})
	K.hero(0, -46, 40, { "crane" })

	local ROCK = rgb(142, 104, 76)
	local NEEDLE = rgb(122, 96, 76)
	local CAPSTONE = rgb(98, 84, 72)
	local PLANK = rgb(128, 96, 62)
	local STEP = rgb(146, 128, 108)
	local BENCH = rgb(176, 150, 118)
	local TIMBER = rgb(110, 78, 50)
	local IRON = rgb(60, 64, 70)
	local LAMP = rgb(255, 196, 120)
	local H = 10 -- the Rope Ring

	-- Pads (10, 6 boss) -------------------------------------------------------
	for _, p in { { 14, -36 }, { -14, -36 }, { 14, 36 }, { -14, 36 } } do
		K.pad(p[1], p[2], 0, true)
	end
	K.pad(47, 6, 2, true)
	K.pad(-47, 6, 2, true)
	for _, p in { { 30, 10 }, { 30, -10 }, { -30, 10 }, { -30, -10 } } do
		K.pad(p[1], p[2])
	end

	-- The Four Stacks: 10 x 10 x 28 cliff dwellings, galleries at h 10 --------
	for _, c in { { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } } do
		local sx, sz = c[1], c[2]
		local cx, cz = 22 * sx, 22 * sz
		local id = `stack{if sx > 0 then "E" else "W"}{if sz > 0 then "S" else "N"}`
		K.box({
			id = id,
			kind = "tower",
			x = cx,
			z = cz,
			w = 10,
			d = 10,
			h0 = 0,
			h1 = 28,
			color = ROCK,
			mat = "Rock",
		})
		-- cliff-dwelling windows (decor): a dark doorway row facing C, a lit loft window facing out
		K.box({
			id = id .. "/doors",
			kind = "window",
			set = "decor",
			x = cx - 5.05 * sx,
			z = cz,
			w = 0.1,
			d = 6,
			h0 = 13,
			h1 = 15.5,
			color = rgb(44, 32, 26),
			mat = "Slate",
		})
		K.box({
			id = id .. "/window",
			kind = "window",
			set = "decor",
			x = cx,
			z = cz + 5.05 * sz,
			w = 3,
			d = 0.1,
			h0 = 19,
			h1 = 21,
			color = LAMP,
			mat = "Neon",
			light = { color = LAMP, range = 24, bright = 1 },
		})
		-- gallery: four 3 u strips round the stack, 16 x 16 overall
		local x0, x1, z0, z1 = cx - 8, cx + 8, cz - 8, cz + 8
		local strips: { { any } } = {
			{ "n", cx, cz - 6.5, 16, 3 },
			{ "s", cx, cz + 6.5, 16, 3 },
			{ "w", cx - 6.5, cz, 3, 10 },
			{ "e", cx + 6.5, cz, 3, 10 },
		}
		for _, s in strips do
			K.deck({
				id = id .. "/gallery-" .. s[1],
				x = s[2],
				z = s[3],
				w = s[4],
				d = s[5],
				h = H,
				color = PLANK,
				mat = "WoodPlanks",
			})
		end
		-- switchback down the outer x face, upper flight toward z = 0
		local dir = if sx > 0 then 0 else 180
		local side = if sx * sz > 0 then -1 else 1
		K.switchback({
			id = id .. "/stair",
			x = cx + 8 * sx,
			z = cz,
			dir = dir,
			w = 4,
			rise = H,
			side = side,
			color = STEP,
			mat = "Slate",
		})
		-- inner truss (toward C) so the far middle of the ring is within 25 u of an access
		local tz = cz - 6.5 * sz
		K.ladder({ id = id .. "/truss", x = cx - 8.42 * sx, z = tz, top = H, yaw = 0 })
		-- rails: gaps for the two bridges, the switchback top and the truss
		local outer = if sx > 0 then "e" else "w"
		local inner = if sx > 0 then "w" else "e"
		local toAxis = if sz > 0 then "n" else "s"
		local gaps: { { any } } = {
			{ toAxis, cx, 3.6 },
			{ inner, cz, 3.6 },
			{ inner, tz, 3 },
			{ outer, 20 * sz, 4.2 },
		}
		K.railRect({
			id = id .. "/rail",
			x0 = x0,
			x1 = x1,
			z0 = z0,
			z1 = z1,
			h = H,
			style = "timber",
			gaps = gaps,
		})
	end

	-- Rock needles: core 4 x 4, cap 5 x 5 at h 10, a spike to 14 on the outer side
	local needles = { { 22, 0, 1, 0 }, { -22, 0, -1, 0 }, { 0, 22, 0, 1 }, { -10, -22, 0, -1 } }
	for i, n in needles do
		local id = "needle" .. i
		K.box({
			id = id,
			kind = "tower",
			x = n[1],
			z = n[2],
			w = 4,
			d = 4,
			h0 = 0,
			h1 = H - 0.5,
			color = NEEDLE,
			mat = "Rock",
		})
		K.box({
			id = id .. "/cap",
			kind = "cap",
			x = n[1],
			z = n[2],
			w = 5,
			d = 5,
			h0 = H - 0.5,
			h1 = H,
			color = CAPSTONE,
			mat = "Slate",
		})
		K.box({
			id = id .. "/spike",
			kind = "tower",
			x = n[1] + 1.95 * n[3],
			z = n[2] + 1.95 * n[4],
			w = if n[3] ~= 0 then 1.1 else 1.6,
			d = if n[3] ~= 0 then 1.6 else 1.1,
			h0 = H,
			h1 = 14,
			color = NEEDLE,
			mat = "Rock",
		})
	end

	-- The Rope Ring: 8 rope bridges, gallery edge to cap edge ------------------
	local function rope(id: string, a: { number }, b: { number })
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		local yaw = -K.bearing(a[1], a[2], b[1], b[2])
		K.box({
			id = id,
			kind = "bridge",
			x = (a[1] + b[1]) / 2,
			z = (a[2] + b[2]) / 2,
			w = len,
			d = 2.5,
			h0 = H - 0.3,
			h1 = H,
			yaw = yaw,
			color = PLANK,
			mat = "WoodPlanks",
		})
		for i, s in { -1, 1 } do
			local ox, oz = -uz * s * 1.1, ux * s * 1.1
			K.rail({
				id = id .. "/rope" .. i,
				a = { a[1] + ox, a[2] + oz },
				b = { b[1] + ox, b[2] + oz },
				h = H,
				style = "rope",
			})
		end
		-- two posts at the gallery end, one each side (decor)
		for i, s in { -1, 1 } do
			K.box({
				id = id .. "/post" .. i,
				kind = "post",
				set = "decor",
				x = a[1] + ux * 0.2 - uz * s * 1.5,
				z = a[2] + uz * 0.2 + ux * s * 1.5,
				w = 0.3,
				d = 0.3,
				h0 = H - 1,
				h1 = H + 1.6,
				color = TIMBER,
				mat = "Wood",
			})
		end
	end
	rope("bridge-e1", { 22, 14 }, { 22, 2.5 })
	rope("bridge-e2", { 22, -14 }, { 22, -2.5 })
	rope("bridge-w1", { -22, 14 }, { -22, 2.5 })
	rope("bridge-w2", { -22, -14 }, { -22, -2.5 })
	rope("bridge-s1", { 14, 22 }, { 2.5, 22 })
	rope("bridge-s2", { -14, 22 }, { -2.5, 22 })
	rope("bridge-n1", { -14, -22 }, { -12.5, -22 })
	rope("bridge-n2", { 14, -22 }, { -7.5, -22 })

	-- The loop, along gallery centrelines and across the needle caps.
	local G = 15.6
	local loop = {
		{ 22, G },
		{ 22, 0 },
		{ 22, -G },
		{ G, -G },
		{ G, -22 },
		{ -10, -22 },
		{ -G, -22 },
		{ -G, -G },
		{ -22, -G },
		{ -22, 0 },
		{ -22, G },
		{ -G, G },
		{ -G, 22 },
		{ 0, 22 },
		{ G, 22 },
		{ G, G },
	}
	for i, a in loop do
		local b = loop[i % #loop + 1]
		K.walk("ring" .. i, { a[1], a[2], H }, { b[1], b[2], H }, 2.5)
	end

	-- Quarry benches (h 2), glacis, hoist sheds and headframes ----------------
	for _, sx in { 1, -1 } do
		local id = if sx > 0 then "benchE" else "benchW"
		K.rect({
			id = id,
			kind = "terrace",
			x0 = 40 * sx,
			x1 = 54 * sx,
			z0 = -14,
			z1 = 14,
			h0 = 0,
			h1 = 2,
			color = BENCH,
			mat = "Sandstone",
			floor = true,
		})
		K.ramp({
			id = id .. "/glacis",
			x = 36.5 * sx,
			z = 0,
			run = if sx > 0 then 0 else 180,
			w = 28,
			rise = 2,
			color = BENCH,
			mat = "Sandstone",
		})
		-- the shed (B3 on the bench): open to the south, side wall at the outer end
		local shed = id .. "/shed"
		local WALL, SHEDROOF = rgb(120, 90, 62), rgb(112, 98, 86)
		local function put(sid: string, ax: number, bx: number, az: number, bz: number, h0: number, h1: number, o: any?)
			local r: { [string]: any } = {
				id = shed .. sid,
				kind = "wall",
				x0 = ax * sx,
				x1 = bx * sx,
				z0 = az,
				z1 = bz,
				h0 = h0,
				h1 = h1,
				color = WALL,
				mat = "WoodPlanks",
			}
			for k, v in pairs(o or {}) do
				r[k] = v
			end
			K.rect(r)
		end
		put("", 40, 54, -14, -4, 7, 11, { kind = "roof", color = SHEDROOF, mat = "CorrodedMetal" })
		put("/back", 40, 54, -14, -13.4, 2, 7)
		put("/side", 53.4, 54, -14, -4, 2, 7)
		for i, x in { 40.4, 46.7, 53 } do
			put("/col" .. i, x - 0.4, x + 0.4, -4.8, -4, 2, 7, { kind = "post", color = TIMBER, mat = "Wood" })
		end
		put("/counter", 42, 48, -12.6, -11.4, 2, 3.1, { kind = "counter", color = PLANK })
		K.box({
			id = shed .. "/sign",
			kind = "sign",
			set = "decor",
			x = 46 * sx,
			z = -3.85,
			w = 10,
			d = 0.2,
			h0 = 7.6,
			h1 = 10.4,
			color = rgb(40, 32, 26),
			mat = "WoodPlanks",
			text = { text = if sx > 0 then "HOIST 1" else "HOIST 2", face = "Back", color = rgb(255, 214, 140) },
			light = { color = rgb(255, 214, 140), range = 24, bright = 1.2 },
		})
		K.railRect({
			id = shed .. "/rail",
			x0 = 40 * sx,
			x1 = 54 * sx,
			z0 = -14,
			z1 = -4,
			h = 11,
			style = "timber",
			gaps = { { "s" :: any, 41.6 * sx, 3 } },
		})
		K.ladder({ id = shed .. "/truss", x = 41.6 * sx, z = -3.58, base = 2, top = 11 })
		-- hoist headframe: 4 x 4 timber tower, bench to h 30, through the shed's outer end
		local hf = if sx > 0 then "headframeE" else "headframeW"
		K.box({
			id = hf,
			kind = "tower",
			x = 51 * sx,
			z = -11,
			w = 4,
			d = 4,
			h0 = 2,
			h1 = 30,
			color = TIMBER,
			mat = "Wood",
		})
		K.cyl({
			id = hf .. "/sheave",
			kind = "wheel",
			set = "decor",
			x = 51 * sx,
			z = -11,
			w = 3,
			h0 = 31.25,
			h1 = 31.75,
			color = IRON,
			mat = "Metal",
			lean = { 0, 0, -90 },
		})
	end

	-- The Quarry Crane (hero): A-frame derrick, jib at 38, hook block at 20-23 --
	local CRANE = rgb(196, 146, 52)
	K.box({
		id = "crane/base",
		kind = "plinth",
		x = 0,
		z = -46,
		w = 8,
		d = 6,
		h0 = 0,
		h1 = 1,
		color = rgb(128, 118, 104),
		mat = "Concrete",
	})
	K.box({
		id = "crane",
		kind = "tower",
		x = 0,
		z = -46,
		w = 2,
		d = 2,
		h0 = 1,
		h1 = 40,
		color = CRANE,
		mat = "Metal",
	})
	for i, s in { -1, 1 } do
		K.box({
			id = "crane/leg" .. i,
			kind = "strut",
			set = "decor",
			x = 2 * s,
			z = -46,
			w = 0.9,
			d = 0.9,
			h0 = 0.4,
			h1 = 39.6,
			color = CRANE,
			mat = "Metal",
			lean = { 0, 0, s * 5.8 },
		})
	end
	K.box({
		id = "crane/jib",
		kind = "jib",
		x = 0,
		z = -40,
		w = 1,
		d = 24,
		h0 = 37.5,
		h1 = 38.5,
		color = CRANE,
		mat = "Metal",
	})
	K.box({
		id = "crane/counterweight",
		kind = "weight",
		x = 0,
		z = -52,
		w = 3,
		d = 3,
		h0 = 34,
		h1 = 37,
		color = rgb(90, 88, 84),
		mat = "Concrete",
	})
	K.box({
		id = "crane/hook",
		kind = "hook",
		x = 0,
		z = -34,
		w = 3,
		d = 3,
		h0 = 20,
		h1 = 23,
		color = IRON,
		mat = "DiamondPlate",
	})
	K.box({
		id = "crane/rope",
		kind = "rope",
		set = "decor",
		x = 0,
		z = -34,
		w = 0.2,
		d = 0.2,
		h0 = 23,
		h1 = 37.5,
		color = rgb(50, 46, 42),
		mat = "Fabric",
	})
	K.ball({
		id = "crane/lamp",
		kind = "tip",
		set = "decor",
		x = 0,
		z = -46,
		dia = 1.2,
		h = 40.6,
		color = rgb(255, 90, 60),
		mat = "Neon",
		light = { color = rgb(255, 90, 60), range = 40, bright = 1.5 },
	})

	-- The Stone Gate (south): piers 4 x 4 x 18, lintel to 20 (a flight-only perch)
	local GATE = rgb(132, 112, 92)
	for i, s in { -1, 1 } do
		K.rect({
			id = "gate/pier" .. i,
			kind = "wall",
			x0 = 11 * s,
			x1 = 15 * s,
			z0 = 49.5,
			z1 = 53.5,
			h0 = 0,
			h1 = 18,
			color = GATE,
			mat = "Rock",
		})
	end
	K.rect({
		id = "gate/lintel",
		kind = "wall",
		x0 = -15,
		x1 = 15,
		z0 = 49.5,
		z1 = 53.5,
		h0 = 18,
		h1 = 20,
		color = CAPSTONE,
		mat = "Slate",
	})

	-- Backdrop needles, 5 x 5, yaw -b -----------------------------------------
	for i, n in
		{
			{ 30, 53, 34 },
			{ 150, 53, 44 },
			{ 210, 53, 38 },
			{ 330, 53, 36 },
			{ 60, 52, 40 },
			{ 120, 52, 30 },
			{ 240, 52, 32 },
			{ 300, 52, 42 },
		}
	do
		local x, z = K.around(n[1], n[2])
		K.box({
			id = "spire" .. i,
			kind = "tower",
			x = x,
			z = z,
			w = 5,
			d = 5,
			h0 = 0,
			h1 = n[3],
			yaw = -n[1],
			color = NEEDLE,
			mat = "Rock",
		})
	end

	-- Ore carts (3) on two short tracks ----------------------------------------
	for i, c in { { 33, 36, 0 }, { -33, 36, 0 }, { 38, -34, 90 } } do
		local id = "cart" .. i
		K.box({
			id = id,
			kind = "cart",
			x = c[1],
			z = c[2],
			w = 3,
			d = 1.8,
			h0 = 0.5,
			h1 = 2.3,
			yaw = c[3],
			color = rgb(96, 84, 74),
			mat = "CorrodedMetal",
		})
		K.box({
			id = id .. "/ore",
			kind = "ore",
			set = "decor",
			x = c[1],
			z = c[2],
			w = 2.6,
			d = 1.4,
			h0 = 2.3,
			h1 = 2.7,
			yaw = c[3],
			color = rgb(84, 72, 64),
			mat = "Pebble",
		})
		K.box({
			id = id .. "/wheels",
			kind = "axle",
			set = "decor",
			x = c[1],
			z = c[2],
			w = 2.6,
			d = 1.9,
			h0 = 0,
			h1 = 0.5,
			yaw = c[3],
			color = rgb(30, 28, 26),
			mat = "Metal",
		})
	end
	for i, c in { { 33, 36, 0 }, { -33, 36, 0 } } do
		K.box({
			id = "track" .. i,
			kind = "track",
			set = "decor",
			x = c[1],
			z = c[2],
			w = 10,
			d = 1.6,
			h0 = 0,
			h1 = 0.1,
			yaw = c[3],
			color = rgb(70, 60, 52),
			mat = "Metal",
		})
	end

	-- Pole lanterns (6, lit) --------------------------------------------------
	for i, p in { { 35, 0 }, { -35, 0 }, { 27, -34 }, { -27, -34 }, { 9, 47 }, { -9, 47 } } do
		K.box({
			id = "lantern" .. i,
			kind = "lamp",
			x = p[1],
			z = p[2],
			w = 0.4,
			d = 0.4,
			h0 = 0,
			h1 = 5.5,
			color = TIMBER,
			mat = "Wood",
		})
		K.box({
			id = "lantern" .. i .. "/glow",
			kind = "glow",
			set = "decor",
			x = p[1],
			z = p[2],
			w = 0.9,
			d = 0.9,
			h0 = 5.5,
			h1 = 6.6,
			color = LAMP,
			mat = "Neon",
			light = { color = LAMP, range = 26, bright = 1.2 },
		})
	end

	-- Seeded cover: boulders and cut blocks ------------------------------------
	K.scatter({
		id = "boulder",
		n = 24,
		radius = 1.8,
		region = { r0 = 18, r1 = 52 },
		make = function(id: string, x: number, z: number, rng: any)
			local dia = rng.num(2.6, 3.6)
			K.ball({
				id = id,
				kind = "boulder",
				x = x,
				z = z,
				dia = dia,
				h = dia * 0.35,
				color = rgb(rng.int(112, 136), rng.int(92, 108), rng.int(76, 88)),
				mat = "Rock",
			})
		end,
	})
	K.scatter({
		id = "block",
		n = 12,
		radius = 1.8,
		tries = 3000,
		region = { r0 = 18, r1 = 52 },
		make = function(id: string, x: number, z: number, rng: any)
			K.box({
				id = id,
				kind = "block",
				x = x,
				z = z,
				w = rng.num(2.4, 3.2),
				d = rng.num(1.6, 2.4),
				h0 = 0,
				h1 = rng.num(2.2, 2.6),
				yaw = rng.num(0, 90),
				color = BENCH,
				mat = "Sandstone",
			})
		end,
	})
end
