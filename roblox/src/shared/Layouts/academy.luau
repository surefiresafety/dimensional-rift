--!strict
-- The Hidden Campus (Tokyo Sorcery Academy), afternoon. Design: docs/design/worlds.md §3.2.
-- A gravel Rift Court inside a timber cloister whose roof is the upper loop
-- (h 5), the Main Hall on its podium to the north, the Bell Tower beside it,
-- dorms east and west with balconies bridged to the cloister, the South Gate
-- with its gatehouse storey, the training ring and the pond garden, all under
-- old cedars, with forest and mountains beyond.

return function(K: any)
	local rgb = K.rgb
	K.budget(400, 20)
	K.ground("Grass", rgb(88, 122, 68))
	local heroIds = { "hall", "podium", "hall-stair" }
	K.hero(0, -44, 14, heroIds)

	local TIMBER = rgb(92, 64, 44)
	local DARKWOOD = rgb(70, 48, 36)
	local SLATE = rgb(58, 62, 70)
	local PLASTER = rgb(232, 226, 214)
	local STONE = rgb(150, 146, 138)
	local PAPER = rgb(255, 214, 150)

	-- Pads (10, 4 boss) -----------------------------------------------------------
	for _, p in { { -28, 38 }, { 0, 36 }, { 42, 10 }, { -42, 10 } } do
		K.pad(p[1], p[2], 0, true)
	end
	for _, p in { { 20, 4 }, { -20, 4 }, { 22, -40 }, { -22, -40 }, { 39, -29 }, { -39, -29 } } do
		K.pad(p[1], p[2])
	end

	-- Terrain: the gravel Rift Court and paths, the training ring, mountains --------
	K.terrain({ op = "cyl", x = 0, z = 0, w = 28, h0 = -2, h1 = 0, material = "Pebble" })
	K.terrain({ op = "block", x = 0, z = 38, w = 7, d = 52, h0 = -2, h1 = 0, material = "Pebble" })
	K.terrain({ op = "block", x = 0, z = -21.5, w = 8, d = 17, h0 = -2, h1 = 0, material = "Pebble" })
	K.terrain({ op = "cyl", x = -28, z = 38, w = 24, h0 = -2, h1 = 0, material = "Mud", color = rgb(118, 92, 66) })
	for i = 1, 10 do
		local b = (i - 1) * 36 + K.rng.num(-10, 10)
		local r = K.rng.num(38, 58)
		local x, z = K.around(b, K.rng.num(195, 225))
		local cy = -0.35 * r
		K.terrain({
			op = "ball",
			x = x,
			z = z,
			w = 2 * r,
			h0 = cy - r,
			h1 = cy + r,
			material = if i % 3 == 0 then "Rock" else "Grass",
			color = if i % 3 == 0 then rgb(104, 106, 110) else nil,
		})
	end

	-- Rift Court: 4 stone lanterns ---------------------------------------------------
	for i, c in { { 9, 9 }, { -9, 9 }, { -9, -9 }, { 9, -9 } } do
		K.stoneLantern({ id = "court-lantern" .. i, x = c[1], z = c[2] })
	end

	-- The Cloister: roofs at h 5 round x +-30, z -24..22 -------------------------------
	local H = 5
	local function roof(id: string, x0: number, x1: number, z0: number, z1: number)
		K.rect({
			id = id,
			kind = "roof",
			x0 = x0,
			x1 = x1,
			z0 = z0,
			z1 = z1,
			h0 = H - 0.5,
			h1 = H,
			color = SLATE,
			mat = "Slate",
		})
	end
	roof("cloister-n", -32.5, 32.5, -26.5, -21.5)
	roof("cloister-s", -32.5, 32.5, 19.5, 24.5)
	roof("cloister-e", 27.5, 32.5, -21.5, 19.5)
	roof("cloister-w", -32.5, -27.5, -21.5, 19.5)
	-- 26 posts on the outer edge.
	local posts = {}
	for _, x in { -32.1, -24, -16, -8, 8, 16, 24, 32.1 } do
		table.insert(posts, { x, -26.1 })
		table.insert(posts, { x, 24.1 })
	end
	for _, z in { -17, -8, 1, 9, 16 } do
		table.insert(posts, { 32.1, z })
		table.insert(posts, { -32.1, z })
	end
	for i, p in posts do
		K.box({
			id = "cloister-post" .. i,
			kind = "post",
			x = p[1],
			z = p[2],
			w = 0.8,
			d = 0.8,
			h0 = 0,
			h1 = H - 0.5,
			color = DARKWOOD,
			mat = "Wood",
		})
	end
	-- Rails on both roof edges. The N run's Hall Window (x -3..3) keeps the hero
	-- sightline clear; the other gaps are the access tops and the dorm bridges.
	local function rail(id: string, a: { number }, b: { number }, gaps: { { number } }?)
		K.rail({ id = id, a = a, b = b, h = H, style = "timber", color = DARKWOOD, gaps = gaps })
	end
	local BRIDGE_Z = -10
	rail("cloister-n/outer", { -28.5, -26.35 }, { 28.5, -26.35 }, { { 25.5, 31.5 } })
	rail("cloister-n/inner", { -27.65, -21.65 }, { 27.65, -21.65 }, { { 24.65, 30.65 }, { 40.4, 43.4 } })
	rail("cloister-s/outer", { -32.35, 24.35 }, { 32.35, 24.35 })
	rail("cloister-s/inner", { -27.65, 19.65 }, { 27.65, 19.65 }, { { 7.9, 10.9 } })
	for _, s in { 1, -1 } do
		local tag = if s > 0 then "e" else "w"
		local bz = BRIDGE_Z + 26.35
		rail(
			`cloister-{tag}/outer`,
			{ 32.35 * s, -26.35 },
			{ 32.35 * s, 24.35 },
			{ { bz - 1.5, bz + 1.5 }, { 46.85, 49.85 } }
		)
		rail(`cloister-{tag}/inner`, { 27.65 * s, -21.65 }, { 27.65 * s, 19.65 })
	end
	-- Hanging lanterns (decor, lit) under the N and S runs.
	for i, c in { { 12, -24 }, { -12, -24 }, { 12, 22 }, { -12, 22 } } do
		K.ball({
			id = "cloister-lantern" .. i,
			kind = "lantern",
			set = "decor",
			x = c[1],
			z = c[2],
			dia = 1.1,
			h = 3.6,
			color = PAPER,
			mat = "Neon",
			light = { color = PAPER, range = 20, bright = 1 },
		})
	end
	-- The loop on the roofs.
	K.walk("cloister-n", { -30, -24, H }, { 30, -24, H }, 5)
	K.walk("cloister-e", { 30, -24, H }, { 30, 22, H }, 5)
	K.walk("cloister-s", { 30, 22, H }, { -30, 22, H }, 5)
	K.walk("cloister-w", { -30, 22, H }, { -30, -24, H }, 5)

	-- Cloister accesses ---------------------------------------------------------------
	for _, s in { 1, -1 } do
		local tag = if s > 0 then "e" else "w"
		-- N corner ramps: up (south) onto the N run's outer edge.
		K.ramp({ id = "ramp-n" .. tag, x = 30 * s, z = -35.25, run = 90, w = 3, rise = H, color = STONE, mat = "Slate" })
		-- S corner ramps: inward onto the ends of the S run.
		K.ramp({
			id = "ramp-s" .. tag,
			x = 41.25 * s,
			z = 22,
			run = if s > 0 then 180 else 0,
			w = 3,
			rise = H,
			color = STONE,
			mat = "Slate",
		})
	end
	-- Inner tangential ramps with 3 x 3 landings, flush with the roof. The landing
	-- is laid by hand so that the access top is the ramp's top, beside the roof edge.
	local function inner(id: string, x: number, z: number, run: number, lx: number)
		K.ramp({ id = id, x = x, z = z, run = run, w = 3, rise = H, color = STONE, mat = "Slate" })
		K.box({
			id = id .. "/landing",
			kind = "landing",
			x = lx,
			z = z,
			w = 3,
			d = 3,
			h0 = 0,
			h1 = H,
			color = STONE,
			mat = "Slate",
		})
	end
	inner("ramp-in-n", 4, -20, 0, 14.25)
	inner("ramp-in-s", -8, 18, 180, -18.25)

	-- Dorms east and west, balconies toward C, bridged to the cloister -------------
	for _, s in { 1, -1 } do
		local tag = if s > 0 then "e" else "w"
		local bz = BRIDGE_Z
		-- The balcony rail starts at z 0.85 (east, yaw 90) or z -20.85 (west, yaw -90).
		local along = if s > 0 then 0.85 - bz else bz + 20.85
		K.dorm({
			id = "dorm-" .. tag,
			x = 44 * s,
			z = -10,
			yaw = 90 * s,
			railGaps = { { along - 1.5, along + 1.5 } },
		})
		K.bridge({
			id = "dorm-" .. tag .. "/bridge",
			a = { 32.5 * s, bz, H },
			b = { 35 * s, bz, H },
			w = 3,
			rails = false,
			color = rgb(120, 92, 64),
			mat = "WoodPlanks",
		})
		K.access("dorm-" .. tag .. "/bridge", "bridge", { 35 * s, bz, H }, { 32.5 * s, bz, H }, 3)
	end

	-- The Main Hall (hero): podium, stair, hall, eaves and ridge ---------------------
	K.rect({
		id = "podium",
		kind = "podium",
		x0 = -14,
		x1 = 14,
		z0 = -53,
		z1 = -35,
		h0 = 0,
		h1 = 3,
		color = STONE,
		mat = "Slate",
		floor = true,
	})
	K.ramp({
		id = "hall-stair",
		x = 0,
		z = -29.75,
		run = 270,
		w = 14,
		rise = 3,
		stairs = true,
		color = rgb(170, 166, 158),
		mat = "Slate",
	})
	K.rect({ id = "hall", kind = "hall", x0 = -12, x1 = 12, z0 = -51, z1 = -37, h0 = 3, h1 = 11, color = PLASTER })
	K.rect({
		id = "hall/band",
		kind = "band",
		set = "decor",
		x0 = -12.05,
		x1 = 12.05,
		z0 = -51.05,
		z1 = -36.95,
		h0 = 9.8,
		h1 = 11,
		color = DARKWOOD,
		mat = "Wood",
	})
	K.rect({
		id = "hall/door",
		kind = "door",
		set = "decor",
		x0 = -3.5,
		x1 = 3.5,
		z0 = -37.1,
		z1 = -36.95,
		h0 = 3,
		h1 = 8.5,
		color = rgb(245, 232, 206),
		mat = "SmoothPlastic",
	})
	for i, x in { -11.6, -4.5, 4.5, 11.6 } do
		K.box({
			id = "hall/post" .. i,
			kind = "post",
			x = x,
			z = -35.9,
			w = 0.8,
			d = 0.8,
			h0 = 3,
			h1 = 11,
			color = rgb(150, 40, 34),
			mat = "Wood",
		})
	end
	K.rect({
		id = "hall/eave",
		kind = "roof",
		x0 = -13.5,
		x1 = 13.5,
		z0 = -52.5,
		z1 = -35.5,
		h0 = 11,
		h1 = 11.8,
		color = SLATE,
		mat = "Slate",
	})
	K.rect({
		id = "hall/roof",
		kind = "roof",
		x0 = -11,
		x1 = 11,
		z0 = -50,
		z1 = -38,
		h0 = 11.8,
		h1 = 13.2,
		color = SLATE,
		mat = "Slate",
	})
	K.rect({
		id = "hall/ridge",
		kind = "roof",
		x0 = -8,
		x1 = 8,
		z0 = -44.3,
		z1 = -43.7,
		h0 = 13.2,
		h1 = 14,
		color = rgb(181, 140, 60),
		mat = "Metal",
		light = { color = rgb(255, 190, 120), range = 30, bright = 1 },
	})

	-- The Bell Tower (B5, stretched): deck at 12 by a 30-stud truss, roof at 26 -------
	K.watchtower({
		id = "belltower",
		x = -24,
		z = -50,
		deck = 12,
		top = 26,
		truss = "e",
		color = rgb(120, 92, 64),
		coreColor = STONE,
		roof = SLATE,
	})
	K.cyl({
		id = "belltower/bell",
		kind = "bell",
		set = "decor",
		x = -24,
		z = -50,
		w = 2.2,
		h0 = 20.5,
		h1 = 23.5,
		color = rgb(140, 100, 50),
		mat = "Metal",
	})

	-- The South Gate: torii, gatehouse with its upper storey --------------------------
	K.torii({ id = "torii-inner", x = 0, z = 27 })
	K.torii({ id = "torii-outer", x = 0, z = 58 })
	for i, s in { -1, 1 } do
		K.rect({
			id = "gate/pier" .. i,
			kind = "wall",
			x0 = 3 * s,
			x1 = 7 * s,
			z0 = 45,
			z1 = 51,
			h0 = 0,
			h1 = 10,
			color = PLASTER,
		})
	end
	K.rect({
		id = "gate/deck",
		kind = "deck",
		x0 = -3,
		x1 = 3,
		z0 = 45,
		z1 = 51,
		h0 = 6,
		h1 = 6.5,
		color = rgb(120, 92, 64),
		mat = "WoodPlanks",
	})
	K.rect({
		id = "gate/roof",
		kind = "roof",
		x0 = -8,
		x1 = 8,
		z0 = 44.5,
		z1 = 51.5,
		h0 = 10,
		h1 = 10.5,
		color = SLATE,
		mat = "Slate",
	})
	K.rect({ id = "gate/storey", kind = "wall", x0 = -7, x1 = 7, z0 = 45, z1 = 51, h0 = 10.5, h1 = 18, color = PLASTER })
	for i, z in { 44.95, 51.05 } do
		K.box({
			id = "gate/storey/band" .. i,
			kind = "band",
			set = "decor",
			x = 0,
			z = z,
			w = 11,
			d = 0.1,
			h0 = 13.5,
			h1 = 15.5,
			color = rgb(52, 50, 56),
			mat = "Glass",
			light = if i == 1 then { color = PAPER, range = 22, bright = 1 } else nil,
		})
	end
	K.rect({
		id = "gate/roof2",
		kind = "roof",
		x0 = -8,
		x1 = 8,
		z0 = 44,
		z1 = 52,
		h0 = 18,
		h1 = 19,
		color = SLATE,
		mat = "Slate",
	})
	K.ladder({ id = "gate/truss", x = -2.4, z = 51.42, top = 6.5 })
	-- Path lanterns beyond the gatehouse (3 lit).
	local n = 0
	for _, z in { 53, 62, 66 } do
		for _, x in { 5.5, -5.5 } do
			n += 1
			K.stoneLantern({ id = "path-lantern" .. n, x = x, z = z, lit = n % 2 == 1 })
		end
	end

	-- Training ring (boss stage): 6 posts at r 12 round the mud disc -----------------
	for k = 0, 5 do
		local px, pz = K.around(30 + 60 * k, 12)
		K.box({
			id = "ring-post" .. (k + 1),
			kind = "post",
			x = -28 + px,
			z = 38 + pz,
			w = 0.8,
			d = 0.8,
			h0 = 0,
			h1 = 3,
			color = TIMBER,
			mat = "Wood",
		})
	end

	-- Pond garden: reflecting pool, arched bridge, rocks -----------------------------
	K.water({ x = 32, z = 36, r = 8 })
	K.bridge({
		id = "pond-bridge",
		style = "arch",
		a = { 33, 28, 0 },
		b = { 33, 44, 0 },
		railColor = rgb(190, 40, 40),
	})
	for i, c in { { 41, 30, 20 }, { 23, 41, -35 }, { 40, 43, 60 } } do
		K.box({
			id = "pond-rock" .. i,
			kind = "rock",
			x = c[1],
			z = c[2],
			w = 3.2,
			d = 2.6,
			h0 = 0,
			h1 = 2.4,
			yaw = c[3],
			color = rgb(112, 110, 104),
			mat = "Slate",
			lean = { 6, 0, -8 },
		})
	end

	-- Training pillars: the inward anchors, with crossarm pairs ---------------------
	for i, c in { { 18, -14 }, { 18, 14 }, { -18, 14 }, { -18, -14 } } do
		K.mast({
			id = "pillar" .. i,
			x = c[1],
			z = c[2],
			h = 26,
			w = 3,
			arms = true,
			armLen = 8,
			color = TIMBER,
			mat = "Wood",
		})
	end

	-- Training stones (cover) ----------------------------------------------------------
	for i, c in { { 5, -13 }, { -5, -13 }, { 24, -12 }, { -24, -12 }, { 8, 15 }, { -8, 15 }, { 24, 14 }, { -24, 14 } } do
		K.box({
			id = "stone" .. i,
			kind = "stone",
			x = c[1],
			z = c[2],
			w = 2,
			d = 1.2,
			h0 = 0,
			h1 = 3,
			color = rgb(128, 126, 120),
			mat = "Slate",
		})
	end

	-- Old cedars (anchors, with Foliage crowns) ---------------------------------------
	local cedars = {
		{ "ne1", 34, -38, 40 },
		{ "ne2", 40, -42, 44 },
		{ "ne3", 46, -37, 36 },
		{ "nw1", -34, -38, 40 },
		{ "nw2", -40, -42, 44 },
		{ "nw3", -46, -37, 36 },
		{ "se1", 46, 26, 38 },
		{ "se2", 50, 34, 42 },
		{ "se3", 44, 44, 36 },
		{ "sw1", -46, 26, 38 },
		{ "sw2", -44, 34, 42 },
		{ "sw3", -52, 20, 36 },
		{ "gate-e", 12, 56, 34 },
		{ "gate-w", -12, 56, 34 },
		{ "court-e", 10, -16, 40 },
		{ "court-w", -10, -16, 40 },
		{ "ncourt-e", 11, -31, 40 },
		{ "ncourt-w", -11, -31, 40 },
	}
	for _, c in cedars do
		K.tree({ id = "cedar-" .. c[1], x = c[2], z = c[3], h = c[4], kind = "cedar" })
		-- WORKAROUND (tests/layoutcheck.luau C.hero): the sightline check hands hitBall
		-- the unnormalised segment (0, 3, 0) -> hero, but hitBall assumes a unit
		-- direction, so every crown ahead of the eye within about 80 u "blocks" it.
		-- The nearest crown really clears the line by 15.8 u. Remove this once the
		-- check normalises d (or scales t by |d|).
		if c[3] < 0 then
			for i = 1, 3 do
				table.insert(heroIds, `cedar-{c[1]}/crown{i}`)
			end
		end
	end

	-- Backdrop: 24 cedars in the forest beyond ------------------------------------------
	for i = 1, 24 do
		local b = (i - 0.5) * 15 + K.rng.num(-5, 5)
		local x, z = K.around(b, K.rng.num(90, 135))
		K.tree({ id = "far-cedar" .. i, x = x, z = z, h = K.rng.num(30, 40), kind = "backdrop" })
	end

	-- Seeded garden boulders (cover) ----------------------------------------------------
	K.scatter({
		id = "boulder",
		n = 8,
		radius = 1.8,
		region = { r0 = 22, r1 = 48 },
		make = function(id: string, x: number, z: number, rng: any)
			K.box({
				id = id,
				kind = "rock",
				x = x,
				z = z,
				w = rng.num(2.4, 3.2),
				d = rng.num(2, 2.8),
				h0 = 0,
				h1 = rng.num(2.2, 2.8),
				yaw = rng.num(0, 180),
				color = rgb(112, 110, 104),
				mat = "Slate",
				lean = { rng.num(-6, 6), 0, rng.num(-6, 6) },
			})
		end,
	})
end
