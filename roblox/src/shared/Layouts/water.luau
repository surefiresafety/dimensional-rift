--!strict
-- Mistreach, a stilt village, morning fog. Design: docs/design/worlds.md §3.8.
-- An island in open sea: a grass island to r 58 ringed by the Tideline Walk
-- (a chord boardwalk at h 0.3 straddling the shore), two clusters of stilt
-- houses moored beyond it, a canal cut in from the east, net-lofts to the
-- north-west, fog-bell towers round the plaza, sea stacks off the shore and
-- the lighthouse to the north.

return function(K: any)
	local rgb = K.rgb
	K.budget(550, 30)
	K.openWater()
	K.hero(0, -50, 32, { "lighthouse" })

	local SEABED = -5
	local TIMBER = rgb(96, 72, 52)
	local TAR = rgb(70, 56, 44)
	local PLANK = rgb(128, 104, 80)
	local IRON = rgb(70, 74, 78)

	-- Terrain: sand sea bed, the sea, a sandy shelf, the grass island, the plaza --
	K.terrain({
		op = "cyl",
		x = 0,
		z = 0,
		w = 420,
		h0 = -14,
		h1 = SEABED,
		material = "Sand",
		color = rgb(176, 164, 132),
	})
	K.terrain({ op = "cyl", x = 0, z = 0, w = 420, h0 = SEABED, h1 = -0.25, material = "Water" })
	K.terrain({ op = "cyl", x = 0, z = 0, w = 128, h0 = -6, h1 = -0.8, material = "Sand" })
	K.terrain({
		op = "cyl",
		x = 0,
		z = 0,
		w = 116,
		h0 = -6,
		h1 = 0,
		material = "Grass",
		color = rgb(84, 106, 72),
	})
	K.terrain({
		op = "cyl",
		x = 0,
		z = 0,
		w = 28,
		h0 = -1,
		h1 = 0.5,
		material = "Slate",
		color = rgb(112, 114, 118),
	})

	-- Pads (10, 5 boss; all on land)
	for _, p in { { 32, -16 }, { 33, -36 }, { 0, 44 }, { 12, 36 }, { 0, -36 } } do
		K.pad(p[1], p[2], 0, true)
	end
	for _, p in { { 30, 14 }, { -32, 16 }, { -32, -16 }, { -12, 36 }, { -33, -36 } } do
		K.pad(p[1], p[2])
	end

	-- Plaza: the raised disc (terrain above), an inlay, 10 mooring bollards --
	K.inlay({ id = "ring", r = 13.4, h = 0.5, color = rgb(120, 200, 220), fill = rgb(96, 100, 106) })
	for i, b in { 14, 66, 94, 146, 174, 206, 234, 262, 278, 346 } do
		local x, z = K.around(b, 17)
		K.cyl({
			id = "bollard" .. i,
			kind = "post",
			set = "decor",
			x = x,
			z = z,
			w = 0.7,
			h0 = 0,
			h1 = 1.3,
			color = IRON,
			mat = "Metal",
		})
	end

	-- The lighthouse (hero): tower, gallery at 26 with its truss, lamp room, cap --
	K.cyl({
		id = "lighthouse",
		kind = "tower",
		x = 0,
		z = -50,
		w = 6,
		h0 = 0,
		h1 = 26,
		color = rgb(232, 228, 220),
		mat = "Concrete",
	})
	for i, h in { 8, 17 } do
		K.cyl({
			id = "lighthouse/band" .. i,
			kind = "band",
			set = "decor",
			x = 0,
			z = -50,
			w = 6.1,
			h0 = h,
			h1 = h + 3,
			color = rgb(176, 52, 44),
			mat = "SmoothPlastic",
		})
	end
	K.deck({
		id = "lighthouse/gallery",
		x = 0,
		z = -50,
		w = 9,
		d = 9,
		h = 26,
		color = rgb(60, 64, 70),
		mat = "Metal",
	})
	K.railRect({
		id = "lighthouse/rail",
		x0 = -4.5,
		x1 = 4.5,
		z0 = -54.5,
		z1 = -45.5,
		h = 26,
		gaps = { { "s" :: any, 0, 3 } },
		color = rgb(40, 42, 48),
	})
	K.ladder({ id = "lighthouse/truss", x = 0, z = -45.08, top = 26 })
	K.cyl({
		id = "lighthouse/lamp",
		kind = "lamp",
		x = 0,
		z = -50,
		w = 4.4,
		h0 = 26,
		h1 = 30.5,
		color = rgb(255, 238, 190),
		mat = "Glass",
		alpha = 0.3,
		light = { color = rgb(255, 236, 180), range = 60, bright = 2 },
	})
	K.cyl({
		id = "lighthouse/cap",
		kind = "roof",
		x = 0,
		z = -50,
		w = 5.4,
		h0 = 30.5,
		h1 = 32,
		color = rgb(160, 44, 40),
		mat = "Metal",
	})
	K.wedge({
		id = "lighthouse/beam",
		kind = "glow",
		set = "decor",
		x = 0,
		z = -50,
		w = 30,
		d = 2,
		h0 = 27.4,
		h1 = 29.4,
		run = 0,
		color = rgb(255, 244, 200),
		mat = "Neon",
		alpha = 0.6,
		spin = 20,
		light = { kind = "spot", color = rgb(255, 244, 200), range = 60, angle = 30, bright = 3 },
	})

	-- Canal: water 6 wide on z = 0 from x 16 to the sea, two arched bridges --
	K.water({ x = 38, z = 0, w = 44, d = 6, yaw = 0 })
	for i, x in { 26, 42 } do
		K.bridge({
			id = "canal-bridge" .. i,
			a = { x, -5.6, 0 },
			b = { x, 5.6, 0 },
			style = "arch",
			color = PLANK,
			railColor = TIMBER,
		})
	end

	-- The Tideline Walk: 16 chord decks at h 0.3, mooring plates, timber rails --
	K.chordRing({
		id = "tide",
		b0 = -11.25,
		b1 = 348.75,
		n = 16,
		rIn = 55,
		rOut = 60,
		top = 0.3,
		t = 0.3,
		capW = 3.5,
		color = PLANK,
		mat = "WoodPlanks",
		capColor = IRON,
		capMat = "Metal",
		rails = {
			outer = true,
			style = "timber",
			gaps = {
				{ bearing = 11.25, edge = "outer", from = -1.5, to = 1.5 } :: any, -- east mooring pier
				{ bearing = 191.25, edge = "outer", from = -1.5, to = 1.5 } :: any, -- west mooring pier
				{ at = 90, edge = "outer", width = 3 } :: any, -- ferry pier
				-- a boat landing where the (33, -36) boss pad's clear box reaches the rail
				{ at = 312.94, edge = "outer", width = 3 } :: any,
			},
		},
	})
	-- Landing steps up from the island onto the boardwalk (rise 0.3), one on every other deck.
	for i = 0, 7 do
		local b = 22.5 + 45 * i
		local x, z = K.around(b, 55 - 0.525)
		K.ramp({
			id = "tide/step" .. (i + 1),
			x = x,
			z = z,
			run = b,
			w = 4,
			rise = 0.3,
			color = PLANK,
			mat = "WoodPlanks",
		})
	end
	-- Boardwalk lamps on six mooring plates, outside the rail.
	for i, b in { 33.75, 101.25, 146.25, 213.75, 281.25, 326.25 } do
		local x, z = K.around(b, 60.7)
		K.lamp({ id = "tide/lamp" .. i, x = x, z = z, h = 7, lit = i % 2 == 1, color = rgb(255, 214, 150) })
	end

	-- Moorings: 2 clusters of 4 stilt houses at r 70, 22 degrees apart ------------
	local walls = { rgb(170, 140, 100), rgb(150, 120, 90), rgb(118, 128, 136), rgb(156, 96, 72) }
	local roofs = { rgb(60, 80, 100), rgb(70, 70, 76), rgb(60, 80, 100), rgb(84, 70, 60) }
	for ci, c in
		{
			{ name = "e", b = { -33, -11, 11, 33 }, pier = 11.25 },
			{ name = "w", b = { 147, 169, 191, 213 }, pier = 191.25 },
		}
	do
		local id = "moor-" .. c.name
		local H: { { number } } = {}
		for i, b in c.b do
			local x, z = K.around(b, 70)
			local yaw = 90 - b -- local -Z faces C, local +X toward decreasing bearing
			H[i] = { x, z, yaw }
			K.stilthouse({
				id = id .. "/house" .. i,
				x = x,
				z = z,
				yaw = yaw,
				deck = 0.4,
				base = SEABED,
				color = walls[(i + ci) % 4 + 1],
				roof = roofs[(i + ci) % 4 + 1],
			})
		end
		-- 12 u flat bridges between neighbouring decks.
		for i = 1, 3 do
			local A, B = H[i], H[i + 1]
			local ax, az = K.toWorld(A[1], A[2], A[3], -6.8, -1)
			local bx, bz = K.toWorld(B[1], B[2], B[3], 6.8, -1)
			K.bridge({
				id = id .. "/bridge" .. i,
				a = { ax, az, 0.4 },
				b = { bx, bz, 0.4 },
				color = PLANK,
				mat = "WoodPlanks",
				railStyle = "timber",
			})
		end
		-- Net-loft balconies at h 6 on the inner pair, joined by a rope bridge.
		local ends = {}
		for k, s in { { 2, -1 }, { 3, 1 } } do
			local A = H[s[1]]
			local side = s[2] -- local x sign of the balcony side
			local bid = id .. "/balcony" .. k
			local bx, bz = K.toWorld(A[1], A[2], A[3], side * 7, 4)
			K.box({
				id = bid,
				kind = "deck",
				x = bx,
				z = bz,
				w = 3,
				d = 4,
				h0 = 5.6,
				h1 = 6,
				yaw = A[3],
				color = PLANK,
				mat = "WoodPlanks",
			})
			for j, lz in { 2.3, 5.7 } do
				local px, pz = K.toWorld(A[1], A[2], A[3], side * 8.2, lz)
				K.box({
					id = bid .. "/post" .. j,
					kind = "post",
					x = px,
					z = pz,
					w = 0.5,
					d = 0.5,
					h0 = SEABED,
					h1 = 5.6,
					yaw = A[3],
					color = TIMBER,
					mat = "Wood",
				})
			end
			local r1x, r1z = K.toWorld(A[1], A[2], A[3], side * 5.5, 5.85)
			local r2x, r2z = K.toWorld(A[1], A[2], A[3], side * 8.5, 5.85)
			K.rail({ id = bid .. "/rail", a = { r1x, r1z }, b = { r2x, r2z }, h = 6, style = "timber" })
			local lx, lz = K.toWorld(A[1], A[2], A[3], side * 6.5, 1.58)
			K.ladder({ id = bid .. "/truss", x = lx, z = lz, base = 0.4, top = 6, yaw = A[3] })
			local ex, ez = K.toWorld(A[1], A[2], A[3], side * 8.3, 4)
			ends[k] = { ex, ez, 6 }
		end
		K.bridge({ id = id .. "/rope", a = ends[1], b = ends[2], style = "rope", walk = true })
		-- The pier from the mooring plate to house 3.
		local p0x, p0z = K.around(c.pier, 60.4)
		local p1x, p1z = K.around(c.pier, 64.3)
		K.bridge({
			id = id .. "/pier",
			a = { p0x, p0z, 0.4 },
			b = { p1x, p1z, 0.4 },
			rails = false,
			color = PLANK,
			mat = "WoodPlanks",
		})
		for j, r in { 61.5, 63.5 } do
			local px, pz = K.around(c.pier, r)
			K.cyl({
				id = id .. "/pier/post" .. j,
				kind = "post",
				x = px,
				z = pz,
				w = 0.6,
				h0 = SEABED,
				h1 = -0.1,
				color = TIMBER,
				mat = "Wood",
			})
		end
	end

	-- Fish Market: stall rows along z +-4, drying racks at x -46 and -25 ----------
	local awnings = { rgb(70, 110, 140), rgb(190, 150, 70), rgb(150, 70, 60) }
	for row, z in { -4, 4 } do
		for i, x in { -42, -36, -30 } do
			K.stall({
				id = "stall" .. row .. i,
				x = x,
				z = z,
				yaw = if z < 0 then 180 else 0,
				color = awnings[i],
				goods = rgb(200, 206, 210),
				lit = (row == 1 and i ~= 2) or (row == 2 and i == 2),
			})
		end
	end
	for i, x in { -46, -25 } do
		for j, z in { -3, 3 } do
			K.box({
				id = "rack" .. i .. "/post" .. j,
				kind = "post",
				x = x,
				z = z,
				w = 0.3,
				d = 0.3,
				h0 = 0,
				h1 = 3,
				color = TIMBER,
				mat = "Wood",
			})
		end
		K.box({
			id = "rack" .. i .. "/net",
			kind = "net",
			set = "decor",
			x = x,
			z = 0,
			w = 0.15,
			d = 6.4,
			h0 = 1.2,
			h1 = 2.9,
			color = rgb(120, 130, 110),
			mat = "Fabric",
			alpha = 0.3,
		})
	end

	-- Shrine Grove: 6 pines round (28, 28), an altar, a lantern -----------------
	for i, h in { 30, 32, 34, 36, 38, 32 } do
		local x, z = K.around((i - 1) * 60, 6)
		K.tree({ id = "pine" .. i, x = 28 + x, z = 28 + z, h = h, kind = "pine" })
	end
	K.box({
		id = "altar",
		kind = "altar",
		x = 28,
		z = 28,
		w = 4,
		d = 4,
		h0 = 0,
		h1 = 4,
		color = rgb(120, 118, 112),
		mat = "Slate",
	})
	K.box({
		id = "altar/cap",
		kind = "roof",
		set = "decor",
		x = 28,
		z = 28,
		w = 4.6,
		d = 4.6,
		h0 = 4,
		h1 = 4.5,
		color = rgb(70, 72, 76),
		mat = "Slate",
	})
	K.box({
		id = "altar/offering",
		kind = "glow",
		set = "decor",
		x = 28,
		z = 28,
		w = 1.2,
		d = 1.2,
		h0 = 4.5,
		h1 = 5.1,
		color = rgb(200, 170, 110),
		mat = "Wood",
	})
	K.stoneLantern({ id = "grove-lantern", x = 24.2, z = 24.2 })

	-- Boatyard: a shed and two upturned hulls ------------------------------------
	K.box({
		id = "shed",
		kind = "wall",
		x = 20,
		z = -32,
		w = 8,
		d = 8,
		h0 = 0,
		h1 = 7,
		color = rgb(110, 92, 74),
		mat = "WoodPlanks",
	})
	K.box({
		id = "shed/roof",
		kind = "roof",
		x = 20,
		z = -32,
		w = 9,
		d = 9,
		h0 = 7,
		h1 = 7.6,
		color = rgb(62, 66, 72),
		mat = "Slate",
	})
	K.box({
		id = "shed/door",
		kind = "door",
		set = "decor",
		x = 15.95,
		z = -32,
		w = 0.1,
		d = 4,
		h0 = 0,
		h1 = 5,
		color = rgb(60, 44, 30),
		mat = "Wood",
	})
	for i, z in { -40, -26 } do
		K.wedge({
			id = "hull" .. i .. "/port",
			kind = "hull",
			x = 11,
			z = z,
			w = 2,
			d = 6,
			h0 = 0,
			h1 = 2.5,
			run = 0,
			color = rgb(46, 40, 36),
			mat = "Wood",
		})
		K.wedge({
			id = "hull" .. i .. "/starboard",
			kind = "hull",
			x = 13,
			z = z,
			w = 2,
			d = 6,
			h0 = 0,
			h1 = 2.5,
			run = 180,
			color = rgb(46, 40, 36),
			mat = "Wood",
		})
	end
	for i, p in { { 16, -40, 30 }, { 16.5, -24, -20 } } do
		K.box({
			id = "oars" .. i,
			kind = "clutter",
			set = "decor",
			x = p[1],
			z = p[2],
			w = 3.6,
			d = 0.3,
			h0 = 0,
			h1 = 0.2,
			yaw = p[3],
			color = rgb(150, 120, 84),
			mat = "Wood",
		})
	end

	-- Net-lofts: 6 x 6 decks at h 5 on posts, trusses, two flat bridges ----------
	local lofts: { { any } } = { { -22, 34, "n" }, { -28, 40, "w" }, { -38, 28, "w" } }
	for i, l in lofts do
		K.deck({
			id = "loft" .. i,
			x = l[1],
			z = l[2],
			w = 6,
			d = 6,
			h = 5,
			posts = 4,
			color = PLANK,
		})
		local tx, tz = l[1], l[2]
		if l[3] == "n" then
			tz -= 3.42
		else
			tx -= 3.42
		end
		K.ladder({ id = "loft" .. i .. "/truss", x = tx, z = tz, top = 5 })
	end
	local function loftBridge(id: string, A: { any }, B: { any }, inset: number)
		local dx, dz = B[1] - A[1], B[2] - A[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		K.bridge({
			id = id,
			a = { A[1] + ux * inset, A[2] + uz * inset, 5.04 },
			b = { B[1] - ux * inset, B[2] - uz * inset, 5.04 },
			color = TIMBER,
			mat = "WoodPlanks",
			railStyle = "timber",
			walk = true,
		})
	end
	loftBridge("loft-bridge1", lofts[1], lofts[2], 1.8)
	loftBridge("loft-bridge2", lofts[2], lofts[3], 3.4)

	-- Harbour masts with yardarms (6 lit) ---------------------------------------
	local masts: { { any } } = {
		{ 46, -20, true },
		{ 48, 18, true },
		{ 20, 47, true },
		{ -22, 48, true },
		{ -48, 4, true },
		{ -24, -44, true },
		{ -42, -8, false },
		{ 42.5, -30, false },
		{ -4, 26, false },
		{ -44, 18, false },
	}
	for i, m in masts do
		K.mast({
			id = "mast" .. i,
			x = m[1],
			z = m[2],
			h = 22,
			w = 1.6,
			color = TIMBER,
			mat = "Wood",
			armColor = TIMBER,
			armMat = "Wood",
			tip = if m[3] then rgb(255, 214, 150) else nil,
			lit = m[3],
		})
		K.box({
			id = "mast" .. i .. "/foot",
			kind = "post",
			set = "decor",
			x = m[1],
			z = m[2],
			w = 2.2,
			d = 2.2,
			h0 = 0,
			h1 = 0.6,
			color = rgb(110, 110, 106),
			mat = "Slate",
		})
	end

	-- Ferry pier: south from the Tideline to (0, 80), with a lamp ----------------
	K.box({
		id = "ferry",
		kind = "deck",
		x = 0,
		z = 70,
		w = 3,
		d = 20.4,
		h0 = 0,
		h1 = 0.4,
		color = PLANK,
		mat = "WoodPlanks",
	})
	for i, z in { 64, 72, 79.5 } do
		for j, x in { -1.2, 1.2 } do
			K.cyl({
				id = "ferry/post" .. i .. j,
				kind = "post",
				x = x,
				z = z,
				w = 0.6,
				h0 = SEABED,
				h1 = 0,
				color = TIMBER,
				mat = "Wood",
			})
		end
	end
	K.lamp({ id = "ferry/lamp", x = 1.2, z = 79.5, h = 7.4, lit = true, color = rgb(255, 214, 150) })

	-- Sea stacks: basalt columns at r 64, the outer ring of anchors --------------
	for i, b in { 45, 67.5, 112.5, 135, 225, 247.5, 270, 292.5, 315 } do
		local x, z = K.around(b, 64)
		K.mass({
			id = "stack" .. i,
			kind = "rock",
			x = x,
			z = z,
			w = 6,
			h0 = SEABED,
			h = 30,
			yaw = -b,
			color = IRON,
			mat = "Basalt",
			trim = { h = -0.25, t = 0.4, color = rgb(220, 226, 230), alpha = 0.3 },
		})
	end

	-- Fog-bell towers: the R1 inward anchors -------------------------------------
	for i, t in { { 8.5, -14.7 }, { 17, -17 }, { -17, -17 }, { -8, 13.5 }, { 12, 10 } } do
		local north = i == 2 or i == 3
		K.mass({
			id = "bell" .. i,
			kind = "tower",
			x = t[1],
			z = t[2],
			w = 5,
			h = 30,
			color = TAR,
			mat = "Wood",
		})
		K.ball({
			id = "bell" .. i .. "/bell",
			kind = "bell",
			set = "decor",
			x = t[1],
			z = t[2],
			dia = 2.4,
			h = 31.3,
			color = rgb(181, 140, 60),
			mat = "Metal",
		})
		K.box({
			id = "bell" .. i .. "/cap",
			kind = "roof",
			set = "decor",
			x = t[1],
			z = t[2],
			w = 6,
			d = 6,
			h0 = 32.6,
			h1 = 33.4,
			color = rgb(54, 46, 40),
			mat = "Wood",
			light = if north then { color = rgb(255, 214, 150), range = 30, bright = 1.2 } else nil,
		})
	end

	-- Seeded detail: island trees, rocks and crates (cover) ----------------------
	K.scatter({
		id = "tree",
		n = 10,
		radius = 1.5,
		region = { r0 = 20, r1 = 52 },
		make = function(id: string, x: number, z: number, rng: any)
			K.tree({ id = id, x = x, z = z, h = rng.num(10, 16), kind = "broadleaf", color = rgb(74, 110, 80) })
		end,
	})
	K.scatter({
		id = "rock",
		n = 12,
		radius = 1.5,
		region = { r0 = 18, r1 = 52 },
		make = function(id: string, x: number, z: number, rng: any)
			local s = rng.num(2.2, 3)
			K.box({
				id = id,
				kind = "rock",
				x = x,
				z = z,
				w = s,
				d = s * rng.num(0.8, 1.2),
				h0 = 0,
				h1 = s * 0.9,
				yaw = rng.num(0, 90),
				color = rgb(96, 98, 100),
				mat = "Slate",
				lean = { rng.num(-8, 8), 0, rng.num(-8, 8) },
			})
		end,
	})
	K.scatter({
		id = "crate",
		n = 16,
		radius = 1.8,
		region = { r0 = 18, r1 = 50 },
		make = function(id: string, x: number, z: number, rng: any)
			K.crate({ id = id, x = x, z = z, yaw = rng.num(0, 90) })
		end,
	})
end
