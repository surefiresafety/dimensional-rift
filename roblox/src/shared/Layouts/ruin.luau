--!strict
-- The Sealed Block (Survival Colony), dusk, ash. Design: docs/design/worlds.md §3.5.
-- A quarantined city block: the Broken Overpass (an open U at h 7 round the
-- north half), the Headcount Board on -Z, the Container Yard to the SE, the
-- Leaning Block to the SW, a scrap market, a water-tower cistern, and an amber
-- light-curtain fence out at r 100.

return function(K: any)
	local rgb = K.rgb
	K.budget(460, 24)
	K.ground("Asphalt", rgb(62, 60, 58))
	K.hero(0, -30, 22, { "board" })

	local CONCRETE = rgb(128, 124, 118)
	local STEEL = rgb(120, 124, 130)
	local RUST = rgb(112, 84, 64)

	-- Pads (10, 3 boss) ----------------------------------------------------------
	for _, p in { { 0, 40 }, { 40, 13 }, { -40, 13 } } do
		K.pad(p[1], p[2], 0, true)
	end
	for _, p in { { 28, 31 }, { -22, -22 }, { 32, -12 }, { 0, -23 }, { -14, 28 }, { -20, -2 }, { 22, 6 } } do
		K.pad(p[1], p[2])
	end

	-- The Broken Overpass: an open U at h 7 from bearing 180 to 360 -------------
	-- Rail gaps: the on-ramps, the switchback top (0..4 u clockwise of the
	-- 247.5 joint), the trusses, and the Fallen Span on the inner edge.
	local railGaps: { any } = {
		{ at = 354, edge = "outer", width = 8 },
		{ at = 186, edge = "outer", width = 8 },
		{ bearing = 247.5, edge = "outer", from = 0, to = 4 },
		{ at = 202.5, edge = "outer", width = 3 },
		{ at = 337.5, edge = "outer", width = 3 },
		{ at = 303.75, edge = "inner", width = 8 },
	}
	K.chordRing({
		id = "overpass",
		b0 = 180,
		b1 = 360,
		n = 8,
		rIn = 40,
		rOut = 48,
		top = 7,
		t = 0.8,
		capW = 6,
		color = CONCRETE,
		mat = "Concrete",
		capColor = rgb(88, 90, 94),
		capMat = "DiamondPlate",
		rails = {
			outer = true,
			inner = true,
			color = rgb(140, 136, 128),
			gaps = railGaps,
		},
	})
	for j = 0, 8 do
		local b = 180 + 22.5 * j
		local x, z = K.around(b, 44)
		K.box({
			id = "overpass/pier" .. (j + 1),
			kind = "pier",
			x = x,
			z = z,
			w = 2,
			d = 2,
			h0 = 0,
			h1 = 7,
			yaw = -b,
			color = rgb(104, 100, 96),
			mat = "Concrete",
		})
	end

	-- Accesses (6) ------------------------------------------------------------------
	-- Radial on-ramps, 8 wide, from r 60.25 up to the outer edge at r 48.
	for i, b in { 354, 186 } do
		local x, z = K.around(b, 60.25)
		K.ramp({
			id = "overpass/onramp" .. i,
			x = x,
			z = z,
			run = b + 180,
			w = 8,
			rise = 7,
			color = CONCRETE,
			mat = "Concrete",
		})
	end
	-- The Fallen Span: an inward spur off the inner edge, down to (14.4, -21.6).
	K.ramp({
		id = "overpass/span",
		x = 14.4,
		z = -21.6,
		run = 303.7,
		w = 8,
		rise = 7,
		len = math.sqrt(7.8 ^ 2 + 11.7 ^ 2),
		color = rgb(116, 112, 106),
		mat = "Concrete",
	})
	-- Switchback outward from r 48 on the 247.5 joint; its upper flight is the
	-- clockwise one, under the rail gap 0..4 u clockwise of the joint.
	do
		local x, z = K.around(247.5, 48)
		K.switchback({
			id = "overpass/switchback",
			x = x,
			z = z,
			dir = 247.5,
			w = 4,
			rise = 7,
			side = 1,
			color = rgb(110, 106, 100),
			mat = "Concrete",
		})
	end
	-- Trusses on the outer edge, facing in, touching the cap ends at r 48.94.
	for i, b in { 202.5, 337.5 } do
		local x, z = K.around(b, 49.36)
		K.ladder({ id = "overpass/truss" .. i, x = x, z = z, top = 7.1, yaw = -b })
	end

	-- Sign gantries (cantilever) on the 225 and 315 joints ------------------------
	local gantries: { { any } } = { { 225, "EXIT 7" }, { 315, "ZONE CLOSED" } }
	for i, g in gantries do
		local b = g[1]
		local mx, mz = K.around(b, 50.2)
		K.box({
			id = "gantry" .. i,
			kind = "mast",
			x = mx,
			z = mz,
			w = 1.2,
			d = 1.2,
			h0 = 0,
			h1 = 22,
			yaw = -b,
			color = STEEL,
			mat = "Metal",
		})
		local bx, bz = K.around(b, 45)
		K.box({
			id = "gantry" .. i .. "/beam",
			kind = "beam",
			x = bx,
			z = bz,
			w = 11,
			d = 1,
			h0 = 21,
			h1 = 22,
			yaw = -b,
			color = STEEL,
			mat = "Metal",
		})
		K.box({
			id = "gantry" .. i .. "/sign",
			kind = "sign",
			x = bx,
			z = bz,
			w = 8,
			d = 0.3,
			h0 = 16,
			h1 = 19,
			yaw = -b,
			color = rgb(24, 96, 60),
			mat = "SmoothPlastic",
			text = { text = g[2], face = "Front", color = rgb(240, 240, 236), bg = rgb(24, 96, 60) },
			light = { color = rgb(210, 240, 220), range = 24, bright = 1 },
		})
		for j, off in { -3, 3 } do
			local hx, hz = K.around(b, 45 + off)
			K.box({
				id = "gantry" .. i .. "/hanger" .. j,
				kind = "hanger",
				set = "decor",
				x = hx,
				z = hz,
				w = 0.2,
				d = 0.2,
				h0 = 19,
				h1 = 21,
				yaw = -b,
				color = STEEL,
				mat = "Metal",
			})
		end
	end

	-- The Headcount Board (hero) --------------------------------------------------
	K.box({
		id = "board",
		kind = "sign",
		x = 0,
		z = -30,
		w = 20,
		d = 1,
		h0 = 12,
		h1 = 22,
		color = rgb(26, 28, 30),
		mat = "Metal",
		text = {
			text = "BLOCK 01 · HEADCOUNT\nPRESENT   0214\nMISSING   0037\nCURFEW   19:00",
			face = "Back",
			color = rgb(255, 176, 60),
			bg = rgb(26, 28, 30),
		},
	})
	for i, x in { -9.42, -8.58, 8.58, 9.42 } do
		K.ladder({ id = "board/leg" .. i, x = x, z = -30, top = 12 })
	end
	K.box({
		id = "board/catwalk",
		kind = "deck",
		x = 0,
		z = -28.5,
		w = 20,
		d = 2,
		h0 = 11.7,
		h1 = 12,
		color = rgb(88, 90, 94),
		mat = "DiamondPlate",
	})
	K.rail({ id = "board/rail", a = { -9.85, -27.65 }, b = { 9.85, -27.65 }, h = 12, color = STEEL })
	K.box({
		id = "board/lamps",
		kind = "glow",
		set = "decor",
		x = 0,
		z = -29.3,
		w = 19,
		d = 0.4,
		h0 = 22,
		h1 = 22.4,
		color = rgb(255, 214, 150),
		mat = "Neon",
		light = { color = rgb(255, 214, 150), range = 40, bright = 1.5 },
	})

	-- Container Yard (SE), round the court at (28, 31) --------------------------
	local boxes: { { any } } = {
		{ "A", 19, 27, 90, 0, rgb(150, 70, 48) },
		{ "G", 19, 27, 90, 2.6, rgb(52, 92, 120) },
		{ "B", 19, 33.5, 90, 0, rgb(96, 104, 64) },
		{ "C", 37, 27, 90, 0, rgb(120, 60, 56) },
		{ "D", 37, 35, 90, 0, rgb(70, 84, 96) },
		{ "H", 37, 35, 90, 2.6, rgb(170, 110, 40) },
		{ "E", 28, 21, 0, 0, rgb(92, 60, 50) },
		{ "F", 28, 41, 0, 0, rgb(60, 90, 76) },
	}
	for _, c in boxes do
		K.container({ id = "yard/" .. c[1], x = c[2], z = c[3], yaw = c[4], h0 = c[5], color = c[6] })
	end
	K.ramp({ id = "yard/rampG", x = 8.65, z = 27, run = 0, w = 3, rise = 5.2, color = RUST, mat = "DiamondPlate" })
	K.ramp({ id = "yard/rampH", x = 47.35, z = 35, run = 180, w = 3, rise = 5.2, color = RUST, mat = "DiamondPlate" })
	K.ramp({ id = "yard/rampE", x = 28, z = 15.2, run = 90, w = 3, rise = 2.6, color = RUST, mat = "DiamondPlate" })
	K.crate({ id = "yard/crate1", x = 22.5, z = 21, yaw = 12 })
	K.crate({ id = "yard/crate2", x = 33.5, z = 23, yaw = -8 })
	for i, c in { { 43, 28 }, { 14, 34 } } do
		K.cyl({
			id = "yard/drum" .. i,
			kind = "drum",
			x = c[1],
			z = c[2],
			w = 2.2,
			h0 = 0,
			h1 = 2.4,
			color = rgb(96, 70, 48),
			mat = "WoodPlanks",
		})
	end

	-- The Leaning Block (SW) -------------------------------------------------------
	-- A B3 arcade built upright on x -45..-31, z 28..38, then rolled 6 degrees
	-- about the +Z axis through its east bottom edge (x -31, h 0). The tilt is
	-- render only, so its parts are `nocheck`; the checks see the ghost box the
	-- design states and a ghost wedge for the sloped roof (8.95 at x -31.94 down
	-- to 7.49 at x -45.86).
	local TILT = { -31, 0, 33, 0, 0, 6 }
	local BRICK = rgb(120, 72, 58)
	local function lean(o: { [string]: any })
		o.tilt = TILT
		o.nocheck = true
		o.color = o.color or BRICK
		o.mat = o.mat or "Brick"
		return K.box(o)
	end
	lean({ id = "block/back", kind = "wall", x = -38, z = 37.7, w = 14, d = 0.6, h0 = 0, h1 = 5 })
	lean({ id = "block/side", kind = "wall", x = -44.7, z = 33, w = 0.6, d = 10, h0 = 0, h1 = 5 })
	for i, x in { -44.6, -38, -31.4 } do
		lean({ id = "block/col" .. i, kind = "wall", x = x, z = 28.4, w = 0.8, d = 0.8, h0 = 0, h1 = 5 })
	end
	lean({ id = "block", kind = "roof", x = -38, z = 33, w = 14, d = 10, h0 = 5, h1 = 9 })
	lean({
		id = "block/counter",
		kind = "wall",
		x = -37,
		z = 36,
		w = 6,
		d = 1.2,
		h0 = 0,
		h1 = 1.1,
		color = rgb(120, 92, 64),
		mat = "WoodPlanks",
	})
	lean({
		id = "block/sign",
		kind = "sign",
		set = "decor",
		x = -38,
		z = 27.85,
		w = 11.2,
		d = 0.2,
		h0 = 5.6,
		h1 = 8.4,
		color = rgb(14, 14, 20),
		mat = "SmoothPlastic",
		text = { text = "RATION HALL", face = "Front", color = rgb(255, 176, 60) },
		light = { color = rgb(255, 176, 60), range = 24, bright = 1.2 },
	})
	-- Roof rails; the east rail leaves z 29..32 open for the stair plate.
	local RAIL = rgb(90, 80, 72)
	local rails: { { any } } = {
		{ "n", -38, 28.15, 13.7, 0.3 },
		{ "s", -38, 37.85, 13.7, 0.3 },
		{ "w", -44.85, 33, 0.3, 9.7 },
		{ "e1", -31.15, 28.575, 0.3, 0.85 },
		{ "e2", -31.15, 34.925, 0.3, 5.85 },
	}
	for _, r in rails do
		lean({
			id = "block/rail-" .. r[1],
			kind = "rail",
			set = "rail",
			x = r[2],
			z = r[3],
			w = r[4],
			d = r[5],
			h0 = 9,
			h1 = 10.1,
			color = RAIL,
			mat = "Metal",
		})
	end
	-- Fallen brick at the sunk west foot (decor).
	for i, c in { { -46.8, 30.5, 20 }, { -46.4, 35.8, -35 } } do
		K.box({
			id = "block/rubble" .. i,
			kind = "rubble",
			set = "decor",
			x = c[1],
			z = c[2],
			w = 2.2,
			d = 1.6,
			h0 = 0,
			h1 = 0.9,
			yaw = c[3],
			color = BRICK,
			mat = "Brick",
			lean = { 8, 0, -12 },
		})
	end
	-- What the checks see.
	K.box({
		id = "block/ghost",
		kind = "wall",
		ghost = true,
		x = -38.45,
		z = 33,
		w = 14.9,
		d = 10,
		h0 = -1.5,
		h1 = 8.95,
		color = BRICK,
		mat = "Brick",
	})
	K.wedge({
		id = "block/ghost-roof",
		kind = "roof",
		ghost = true,
		x = -38.9,
		z = 33,
		w = 13.92,
		d = 10,
		h0 = 7.49,
		h1 = 8.95,
		run = 0,
		color = BRICK,
		mat = "Brick",
	})
	-- The annex, its rubble ramp, the roof stairs and the stair plate onto the leaning roof.
	local ANNEX = rgb(110, 108, 104)
	K.rect({
		id = "annex",
		kind = "roof",
		x0 = -30,
		x1 = -22,
		z0 = 28,
		z1 = 38,
		h0 = 0,
		h1 = 6,
		color = ANNEX,
		mat = "Concrete",
	})
	K.ramp({
		id = "annex/rubble",
		x = -26,
		z = 48.5,
		run = 270,
		w = 4,
		rise = 6,
		color = rgb(96, 90, 84),
		mat = "Slate",
	})
	K.ramp({
		id = "annex/stairs",
		x = -25.2,
		z = 30.5,
		run = 180,
		w = 3,
		rise = 3,
		h0 = 6,
		stairs = true,
		color = ANNEX,
		mat = "Concrete",
	})
	K.rect({
		id = "annex/plate",
		kind = "landing",
		x0 = -32.4,
		x1 = -30.4,
		z0 = 29,
		z1 = 32,
		h0 = 8.6,
		h1 = 9,
		color = rgb(88, 90, 94),
		mat = "DiamondPlate",
	})

	-- Scrap Market: rows at x -40 and -32 facing the aisle -----------------------
	local awnings = { rgb(150, 110, 60), rgb(96, 110, 120), rgb(140, 70, 50) }
	for row, x in { -40, -32 } do
		for i, z in { -14, -8, -2 } do
			K.stall({
				id = "stall" .. row .. i,
				x = x,
				z = z,
				yaw = if row == 1 then -90 else 90,
				color = awnings[i],
				goods = rgb(150, 140, 120),
				lit = (row + i) % 2 == 1,
			})
		end
	end

	-- Quarantine fence: 10 amber pylons at r 100 with light curtains --------------
	K.pylonFence({ id = "fence", n = 10, r = 100, h = 14, glow = rgb(255, 170, 40) })

	-- Floodlight masts (22, crossarms) and the north lamp-bank floodlights --------
	for i, c in { { 48, 24 }, { -48, 24 }, { 24, 46 }, { -24, 46 } } do
		K.floodlight({ id = "flood" .. i, x = c[1], z = c[2], h = 22, lit = true })
	end
	for i, b in { 255, 285 } do
		local x, z = K.around(b, 54)
		K.floodlight({ id = "northflood" .. i, x = x, z = z, h = 24, head = "bank", color = rgb(60, 64, 70) })
	end

	-- The block cistern (water tower) at (0, 20) -----------------------------------
	K.cistern({ id = "cistern", x = 0, z = 20, stencil = "01" })

	-- Burning barrels ----------------------------------------------------------------
	for i, c in { { 13, 13 }, { -13, 13 }, { 13, -13 }, { -13, -13 } } do
		K.cyl({
			id = "barrel" .. i,
			kind = "barrel",
			x = c[1],
			z = c[2],
			w = 1.2,
			h0 = 0,
			h1 = 1.6,
			color = rgb(80, 56, 40),
			mat = "CorrodedMetal",
			fire = true,
			light = if i <= 2 then { color = rgb(255, 150, 70), range = 20, bright = 1.4 } else nil,
		})
	end

	-- Street lamps (8, every second lit) ------------------------------------------
	local lamps = {}
	for _, s in { { 10, 54 }, { 45, 54 }, { 80, 54 }, { 100, 54 }, { 135, 56 }, { 170, 54 } } do
		local x, z = K.around(s[1], s[2])
		table.insert(lamps, { x, z })
	end
	table.insert(lamps, { 18.6, -18.8 })
	table.insert(lamps, { 10.2, -24.4 })
	for i, p in lamps do
		K.lamp({ id = "lamp" .. i, x = p[1], z = p[2], lit = i % 2 == 0, pole = rgb(52, 52, 56) })
	end

	-- Skyline: 10 dead towers (anchors) and 15 seeded leaning towers -----------------
	local DEAD = rgb(92, 90, 88)
	local fixed =
		{ { 64, -4, 0 }, { -64, -4, 0 }, { 52, -40, 0 }, { -52, -40, 0 }, { 0, -66, 0 }, { 34, 62, 0 }, { -34, 62, 0 } }
	for _, b in { 30, 90, 150 } do
		local x, z = K.around(b, 68)
		table.insert(fixed, { x, z, -b })
	end
	for i, t in fixed do
		K.tower({
			id = "tower" .. i,
			x = t[1],
			z = t[2],
			w = 14,
			d = 14,
			h = 34,
			yaw = t[3],
			color = DEAD,
			bands = 2,
			band = rgb(44, 42, 40),
			roof = true,
		})
		local ax, az = K.toWorld(t[1], t[2], t[3], -3, -3)
		K.box({
			id = "tower" .. i .. "/antenna",
			kind = "antenna",
			set = "decor",
			x = ax,
			z = az,
			w = 0.3,
			d = 0.3,
			h0 = 34,
			h1 = 40,
			color = rgb(60, 60, 64),
			mat = "Metal",
		})
	end
	for i = 1, 15 do
		local b = (i - 0.5) * 24 + K.rng.num(-6, 6)
		local r = K.rng.num(70, 110)
		local x, z = K.around(b, r)
		local w, d, h = K.rng.num(12, 20), K.rng.num(12, 18), K.rng.num(36, 80)
		local tilt = K.rng.num(4, 10)
		-- Yaw 0 here: the tilt turns it to face C (-b) and leans it outward about
		-- its tangential axis, pivoting at the base centre (design §3.5).
		local tiltF = { x, 0, z, 0, -b, -tilt }
		K.box({
			id = "far" .. i,
			kind = "tower",
			x = x,
			z = z,
			w = w,
			d = d,
			h0 = -2,
			h1 = h,
			color = rgb(78, 76, 76),
			mat = "Concrete",
			backdrop = true,
			nocheck = true,
			tilt = tiltF,
		})
		for j = 1, 2 do
			local bh = h * (0.35 + 0.3 * j)
			K.box({
				id = "far" .. i .. "/band" .. j,
				kind = "band",
				set = "decor",
				x = x,
				z = z,
				w = w + 0.1,
				d = d + 0.1,
				h0 = bh,
				h1 = bh + 0.8,
				color = rgb(40, 38, 38),
				mat = "Concrete",
				backdrop = true,
				tilt = tiltF,
			})
		end
		K.box({
			id = "far" .. i .. "/roof",
			kind = "roof",
			x = x + w * 0.15,
			z = z,
			w = w * 0.3,
			d = d * 0.3,
			h0 = h,
			h1 = h + 2,
			color = rgb(60, 58, 64),
			mat = "Metal",
			backdrop = true,
			nocheck = true,
			tilt = tiltF,
		})
	end

	-- Cover: wrecked cars, jersey barriers, rubble (seeded, with rejection) --------
	K.scatter({
		id = "wreck",
		n = 14,
		radius = 2.5,
		region = { r0 = 20, r1 = 50 },
		make = function(id: string, x: number, z: number, rng: any)
			K.car({ id = id, x = x, z = z, yaw = rng.num(0, 360), wrecked = true, fire = rng.num() < 0.4 })
		end,
	})
	K.scatter({
		id = "jersey",
		n = 10,
		radius = 2,
		region = { r0 = 20, r1 = 50 },
		make = function(id: string, x: number, z: number, rng: any)
			K.jersey({ id = id, x = x, z = z, yaw = rng.num(0, 180), color = rgb(176, 170, 160) })
		end,
	})
	K.scatter({
		id = "rubble",
		n = 12,
		radius = 1.7,
		region = { r0 = 20, r1 = 50 },
		make = function(id: string, x: number, z: number, rng: any)
			local s = rng.num(2, 2.8)
			K.box({
				id = id,
				kind = "rubble",
				x = x,
				z = z,
				w = s,
				d = rng.num(1.8, 2.6),
				h0 = 0,
				h1 = rng.num(2.2, 2.8),
				yaw = rng.num(0, 90),
				color = rgb(104, 100, 94),
				mat = "Slate",
				lean = { rng.num(-6, 6), 0, rng.num(-6, 6) },
			})
		end,
	})
end
