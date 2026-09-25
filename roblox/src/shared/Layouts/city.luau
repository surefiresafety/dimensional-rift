--!strict
-- The Crossroads (Times Square), night. Design: docs/design/worlds.md §3.1.
-- A crossroads of avenues inside a Ring Street, a High Line of walk-ups,
-- corner decks and sky-bridges at h 9, and the Beacon to the north.

return function(K: any)
	local rgb = K.rgb
	K.budget(540, 36)
	K.ground("Asphalt", rgb(40, 38, 46))
	K.hero(0, -26, 36, { "beacon" })

	-- Pads (12, 4 boss)
	for _, p in { { 0, -40 }, { 40, 0 }, { -40, 0 }, { 0, 40 } } do
		K.pad(p[1], p[2], 0, true)
	end
	for _, p in { { 30, -30 }, { -32, -32 }, { 30, 30 }, { -32, 35 }, { 26, -33 }, { -24, 0 }, { 32, 11 }, { -32, 9 } } do
		K.pad(p[1], p[2])
	end

	-- Dressing: ring inlay, crosswalks, lane dashes -------------------------
	K.inlay({ id = "ring", r = 12, color = rgb(58, 224, 255) })
	for i, c in { { 0, -34, 90 }, { 0, 34, 90 }, { 34, 0, 0 }, { -34, 0, 0 } } do
		K.box({
			id = "crosswalk" .. i,
			kind = "paint",
			set = "decor",
			x = c[1],
			z = c[2],
			w = 8,
			d = 11,
			h0 = 0,
			h1 = 0.04,
			yaw = c[3],
			color = rgb(220, 220, 214),
			mat = "SmoothPlastic",
			alpha = 0.3,
		})
	end
	local n = 0
	for _, b in { 0, 90, 180, 270 } do
		for r = 16, 72, 8 do
			if r < 29 or r > 39 then
				n += 1
				local x, z = K.around(b, r)
				K.box({
					id = "dash" .. n,
					kind = "paint",
					set = "decor",
					x = x,
					z = z,
					w = 4,
					d = 0.4,
					h0 = 0,
					h1 = 0.04,
					yaw = -b,
					color = rgb(255, 214, 90),
					mat = "Neon",
				})
			end
		end
	end

	-- The Beacon (hero): open legs, a tall lit mass, screens facing south ----
	for i, c in { { -3.25, -29.25 }, { 3.25, -29.25 }, { 3.25, -22.75 }, { -3.25, -22.75 } } do
		K.box({
			id = "beacon/leg" .. i,
			kind = "tower",
			x = c[1],
			z = c[2],
			w = 1.5,
			d = 1.5,
			h0 = 0,
			h1 = 6,
			color = rgb(46, 42, 60),
			mat = "Metal",
		})
	end
	K.box({
		id = "beacon",
		kind = "tower",
		x = 0,
		z = -26,
		w = 8,
		d = 8,
		h0 = 6,
		h1 = 36,
		color = rgb(38, 34, 52),
		mat = "Glass",
		refl = 0.1,
	})
	local screens = {
		{ "RIFT NEWS 24/7", rgb(255, 61, 127) },
		{ "MIDTOWN LEDGER", rgb(58, 224, 255) },
		{ "THE SKY IS FINE", rgb(255, 213, 74) },
	}
	for i, s in screens do
		K.box({
			id = "beacon/screen" .. i,
			kind = "sign",
			set = "decor",
			x = 0,
			z = -21.9,
			w = 7.4,
			d = 0.2,
			h0 = 8 + (i - 1) * 9,
			h1 = 15 + (i - 1) * 9,
			color = rgb(14, 14, 20),
			text = { text = s[1], face = "Back", color = s[2] },
		})
	end
	K.box({
		id = "beacon/crown",
		kind = "glow",
		set = "decor",
		x = 0,
		z = -26,
		w = 8.4,
		d = 8.4,
		h0 = 35,
		h1 = 36.4,
		color = rgb(255, 61, 127),
		mat = "Neon",
		light = { color = rgb(255, 61, 127), range = 60, bright = 2 },
	})

	-- Billboard pylons: the inward anchors -----------------------------------
	local signs = { "SHARD COLA", "MULTIVERSE TOURS", "NOODLE BAR 88", "SALE 70% OFF" }
	local neon = { rgb(255, 61, 127), rgb(58, 224, 255), rgb(255, 213, 74), rgb(155, 108, 255) }
	for i, c in { { 12, -12 }, { 12, 12 }, { -12, 12 }, { -12, -12 } } do
		K.mast({ id = "pylon" .. i, x = c[1], z = c[2], h = 26, w = 1.6, color = rgb(60, 64, 70) })
		local b = K.bearing(c[1], c[2], 0, 0)
		local sx, sz = K.around(K.bearing(0, 0, c[1], c[2]), math.sqrt(c[1] ^ 2 + c[2] ^ 2) + 0.9)
		K.box({
			id = "pylon" .. i .. "/sign",
			kind = "sign",
			set = "decor",
			x = sx,
			z = sz,
			w = 0.3,
			d = 6,
			h0 = 17,
			h1 = 21,
			yaw = -b,
			color = rgb(14, 14, 20),
			text = { text = signs[i], face = "Right", color = neon[i] },
			light = { color = neon[i], range = 30, bright = 2 },
		})
	end

	-- Neon Theatre (B3), x 13..27, z -23..-13, front to the south ------------
	K.arcade({
		id = "theatre",
		x = 20,
		z = -18,
		yaw = 180,
		truss = "n",
		trussAt = -0.5,
		sign = "NOW SHOWING",
		signColor = rgb(255, 61, 127),
		color = rgb(70, 40, 80),
	})

	-- Red Steps: a deck at 4 with a wide ramp down to the south -------------
	K.rect({
		id = "steps",
		kind = "deck",
		x0 = -26,
		x1 = -10,
		z0 = -25,
		z1 = -21,
		h0 = 0,
		h1 = 4,
		color = rgb(170, 40, 50),
		mat = "SmoothPlastic",
	})
	K.ramp({
		id = "steps/ramp",
		x = -18,
		z = -14,
		run = 270,
		w = 16,
		rise = 4,
		color = rgb(170, 40, 50),
		mat = "SmoothPlastic",
	})
	for i = 1, 7 do
		local z = -14 - i * 7 / 8
		K.box({
			id = "steps/tread" .. i,
			kind = "tread",
			set = "decor",
			x = -18,
			z = z,
			w = 16,
			d = 0.15,
			h0 = 0,
			h1 = 4 * i / 8 + 0.03,
			color = rgb(255, 61, 127),
			mat = "Neon",
		})
	end
	K.railRect({ id = "steps/rail", x0 = -26, x1 = -10, z0 = -25, z1 = -21, h = 4, faces = { "n", "w", "e" } })

	-- Market Alley -------------------------------------------------------------
	local awnings = { rgb(200, 60, 50), rgb(60, 140, 200), rgb(230, 170, 40) }
	for row, x in { -16, -26 } do
		for i, z in { 18, 22, 26 } do
			K.stall({
				id = "stall" .. row .. i,
				x = x,
				z = z,
				yaw = if row == 1 then 90 else -90,
				color = awnings[i],
				lit = i ~= 2 and (row + i) % 2 == 0 or (row == 1 and i == 2),
			})
		end
	end

	-- Transit Plaza -------------------------------------------------------------
	K.box({
		id = "kiosk",
		kind = "kiosk",
		x = 18,
		z = 18,
		w = 6,
		d = 4,
		h0 = 0,
		h1 = 2.4,
		color = rgb(60, 64, 70),
		mat = "Metal",
		light = { color = rgb(58, 224, 255), range = 20, bright = 1 },
	})
	for i, s in { { 24, 8, 90 }, { 8, 24, 0 } } do
		local bx, bz = K.toWorld(s[1], s[2], s[3], 0, 0.9)
		K.box({
			id = "shelter" .. i,
			kind = "shelter",
			x = bx,
			z = bz,
			w = 4,
			d = 0.2,
			h0 = 0,
			h1 = 2.8,
			yaw = s[3],
			color = rgb(150, 200, 220),
			mat = "Glass",
			alpha = 0.5,
		})
		K.box({
			id = "shelter" .. i .. "/roof",
			kind = "shelter",
			x = s[1],
			z = s[2],
			w = 4,
			d = 2,
			h0 = 2.8,
			h1 = 3,
			yaw = s[3],
			color = rgb(60, 64, 70),
			mat = "Metal",
		})
	end
	for i, p in { { 12, 21 }, { 21, 12 }, { 27, 20 }, { 20, 27 } } do
		K.box({
			id = "planter" .. i,
			kind = "planter",
			x = p[1],
			z = p[2],
			w = 2.4,
			d = 2.4,
			h0 = 0,
			h1 = 1.2,
			color = rgb(110, 106, 118),
			mat = "Concrete",
		})
	end
	K.box({
		id = "subway",
		kind = "subway",
		set = "decor",
		x = 16,
		z = 12,
		w = 5,
		d = 3,
		h0 = 0,
		h1 = 0.05,
		color = rgb(20, 20, 24),
		mat = "SmoothPlastic",
	})
	K.box({
		id = "subway/sign",
		kind = "sign",
		set = "decor",
		x = 16,
		z = 10.4,
		w = 3,
		d = 0.2,
		h0 = 2.2,
		h1 = 3,
		color = rgb(47, 111, 255),
		mat = "Neon",
	})

	-- The High Line (h 9) -----------------------------------------------------
	local H = 9
	-- Walk-ups on the four approaches; the truss faces Ring Street.
	local lit = 0
	for _, w in
		{
			{ 16, -46, "s", "w", "e" },
			{ -16, -46, "s", "w", "e" },
			{ 16, 46, "n", "w", "e" },
			{ -16, 46, "n", "w", "e" },
			{ 46, -16, "w", "n", "s" },
			{ 46, 16, "w", "n", "s" },
			{ -46, -16, "e", "n", "s" },
			{ -46, 16, "e", "n", "s" },
		}
	do
		lit += 1
		K.walkup({
			id = `walkup{w[1]}_{w[2]}`,
			x = w[1],
			z = w[2],
			truss = w[3],
			open = { { w[4], nil, 3.6 }, { w[5], nil, 3.6 } },
			lit = lit % 2 == 0,
		})
	end
	-- Corner decks: solid 14 x 14 x 9, with a switchback down the outer x face.
	for _, c in { { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } } do
		local cx, cz = 46 * c[1], 46 * c[2]
		local id = `corner{cx}_{cz}`
		K.box({
			id = id,
			kind = "deck",
			x = cx,
			z = cz,
			w = 14,
			d = 14,
			h0 = 0,
			h1 = H,
			color = rgb(92, 86, 96),
			mat = "Concrete",
		})
		K.box({
			id = id .. "/band",
			kind = "band",
			set = "decor",
			x = cx,
			z = cz,
			w = 14.1,
			d = 14.1,
			h0 = 6,
			h1 = 6.6,
			color = rgb(255, 214, 140),
			mat = "Neon",
		})
		-- the upper flight on the side away from C (|z| 46..50), top at the deck face
		local dir = if c[1] > 0 then 0 else 180
		local side = if c[1] * c[2] > 0 then 1 else -1
		K.switchback({
			id = id .. "/stair",
			x = cx + 7 * c[1],
			z = cz,
			dir = dir,
			w = 4,
			rise = H,
			side = side,
			color = rgb(110, 106, 118),
		})
		K.railRect({
			id = id .. "/rail",
			x0 = cx - 7,
			x1 = cx + 7,
			z0 = cz - 7,
			z1 = cz + 7,
			h = H,
			gaps = {
				{ if c[1] > 0 then "w" else "e", cz, 3.6 }, -- corner bridge along x
				{ if c[2] > 0 then "n" else "s", cx, 3.6 }, -- corner bridge along z
				{ if c[1] > 0 then "e" else "w", cz + 2 * c[2], 4.2 }, -- switchback top
			},
		})
	end
	-- Sky-bridges (20 u) and corner bridges (17 u), underside 8.6.
	local function span(id: string, a: { number }, b: { number })
		K.bridge({
			id = id,
			a = { a[1], a[2], H },
			b = { b[1], b[2], H },
			w = 3,
			t = 0.4,
			color = rgb(60, 64, 70),
			mat = "Metal",
		})
	end
	span("sky-n", { -10, -46 }, { 10, -46 })
	span("sky-s", { -10, 46 }, { 10, 46 })
	span("sky-e", { 46, -10 }, { 46, 10 })
	span("sky-w", { -46, -10 }, { -46, 10 })
	for _, c in { { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } } do
		span(`cb{c[1]}{c[2]}x`, { 22 * c[1], 46 * c[2] }, { 39 * c[1], 46 * c[2] })
		span(`cb{c[1]}{c[2]}z`, { 46 * c[1], 22 * c[2] }, { 46 * c[1], 39 * c[2] })
	end
	-- The loop, corner to corner.
	K.walk("hl-n", { -46, -46, H }, { 46, -46, H }, 3)
	K.walk("hl-e", { 46, -46, H }, { 46, 46, H }, 3)
	K.walk("hl-s", { 46, 46, H }, { -46, 46, H }, 3)
	K.walk("hl-w", { -46, 46, H }, { -46, -46, H }, 3)

	-- Cover ---------------------------------------------------------------------
	for i, c in
		{
			{ 34, -18, 90 },
			{ -34, -18, 90 },
			{ 36, 21, 90 },
			{ -35, 24, 90 },
			{ 18, 34, 0 },
			{ -16, 36, 0 },
			{ 12, -34, 0 },
			{ -18, -36, 0 },
			{ 34, -44, 90 },
			{ -34, 44, 90 },
		}
	do
		K.car({ id = "car" .. i, x = c[1], z = c[2], yaw = c[3] })
	end
	for i, c in
		{
			{ 37, -26, 90 },
			{ -36, 20, 0 },
			{ 22, 38, 90 },
			{ -22, 38, 90 },
			{ 36, -22, 0 },
			{ -38, -20, 0 },
			{ -12, -37, 90 },
			{ -22, -30, 90 },
		}
	do
		K.jersey({ id = "jersey" .. i, x = c[1], z = c[2], yaw = c[3] })
	end
	n = 0
	for _, p in { { 8.5, 20 }, { 8.5, 54 }, { 20, 7.5 }, { 54, 7.5 } } do
		for _, s in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			n += 1
			K.lamp({ id = "lamp" .. n, x = p[1] * s[1], z = p[2] * s[2], lit = n % 2 == 0 })
		end
	end

	-- Towers: the near ring (anchors, with billboards) and a seeded far skyline --
	local ads = {
		"RIFT NEWS 24/7",
		"SHARD COLA",
		"GRAND OPENING",
		"EVACUATE CALMLY",
		"MIDTOWN LEDGER",
		"SALE 70% OFF",
		"MULTIVERSE TOURS",
		"NOODLE BAR 88",
	}
	for i, t in
		{
			{ 62, -26, 44 },
			{ 62, 26, 38 },
			{ -62, -26, 40 },
			{ -62, 26, 48 },
			{ 26, -62, 50 },
			{ -26, -62, 36 },
			{ 26, 62, 42 },
			{ -26, 62, 46 },
		}
	do
		K.tower({
			id = "tower" .. i,
			x = t[1],
			z = t[2],
			w = 14,
			d = 14,
			h = t[3],
			bands = 3,
			band = rgb(255, 232, 170),
			sign = { text = ads[i], color = neon[(i - 1) % 4 + 1] },
		})
	end
	for i = 1, 10 do
		local b = (i - 0.5) * 36 + K.rng.num(-8, 8)
		local x, z = K.around(b, K.rng.num(80, 100))
		K.tower({
			id = "far" .. i,
			x = x,
			z = z,
			w = K.rng.num(14, 22),
			d = K.rng.num(14, 20),
			h = K.rng.num(50, 100),
			yaw = -b,
			bands = 2,
			band = rgb(255, 232, 170),
			backdrop = true,
			roof = true,
		})
	end
end
