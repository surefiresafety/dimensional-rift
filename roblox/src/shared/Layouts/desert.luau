--!strict
-- Dunewatch, a caravan ksar at noon. Design: docs/design/worlds.md §3.6.
-- A sundial Well Square ringed by gnomon pillars, a covered souk running
-- east, three mudbrick quarters whose roofs (h 5-7.4) are tied by plank and
-- rope bridges, a citadel with its signal tower on -Z, a cistern oasis to the
-- south-west, and eight ksar towers standing in the dunes.

return function(K: any)
	local rgb = K.rgb
	K.budget(400, 12)
	K.ground("Sand", rgb(222, 190, 140))
	K.hero(0, -48, 38, { "signal" })

	local MUD = rgb(196, 150, 100)
	local SANDSTONE = rgb(206, 170, 120)
	local TIMBER = rgb(110, 78, 50)
	local STEEL = rgb(120, 124, 130)
	local DARK = rgb(60, 44, 30)
	local BRONZE = rgb(140, 110, 60)
	local ROPE = rgb(150, 110, 70)

	-- Pads (10, 3 boss) --------------------------------------------------------
	for _, p in { { 0, 40 }, { -38, 6 }, { 48, -2 } } do
		K.pad(p[1], p[2], 0, true)
	end
	for _, p in { { 8, -22 }, { -8, -22 }, { 11, 20 }, { -14, 20 }, { 20, 45 }, { 22, -44 }, { -22, -44 } } do
		K.pad(p[1], p[2])
	end

	-- Hills (dunes) and the rock ring --------------------------------------------
	local keepOut = { { bearing = 90, halfWidth = 30 } }
	for k = 0, 7 do
		table.insert(keepOut, { bearing = 22.5 + 45 * k, halfWidth = 5 })
	end
	K.hills({ minGround = 66, keepOut = keepOut, count = 30, rMin = 12, rMax = 30, material = "Sand" })

	-- Rock outcrops at r 70-86, in the gaps between the ksar towers' sectors and
	-- never in the open south (bearings 60-120): a ball at each end of a gap and
	-- a tilted block between them.
	local ROCK = rgb(170, 122, 84)
	local n = 0
	for _, g in
		{
			{ 27.5, 60 },
			{ 120, 152.5 },
			{ 162.5, 197.5 },
			{ 207.5, 242.5 },
			{ 252.5, 287.5 },
			{ 297.5, 332.5 },
			{ 342.5, 377.5 },
		}
	do
		local lo, hi = g[1], g[2]
		for i, b in { lo + 7.5, (lo + hi) / 2, hi - 7.5 } do
			n += 1
			local r = 78 + (if i == 2 then 1 else -1) * (n % 3)
			local x, z = K.around(b, r)
			if i == 2 then
				K.terrain({
					op = "block",
					x = x,
					z = z,
					w = 11,
					d = 7,
					h0 = -2,
					h1 = 6 + n % 4,
					yaw = -b + 20 * ((n % 3) - 1),
					material = "Rock",
					color = ROCK,
				})
			else
				local dia = 13 + n % 3
				K.terrain({ op = "ball", x = x, z = z, w = dia, h0 = -4, h1 = -4, material = "Rock", color = ROCK })
			end
		end
	end

	-- Well Square: sundial inlay and the 4 gnomon pillars (R1 inward anchors) ---
	K.inlay({
		id = "sundial",
		r = 10,
		w = 0.5,
		color = rgb(255, 200, 90),
		fill = rgb(196, 160, 110),
		fillMat = "Sandstone",
	})
	for i, b in { 45, 135, 225, 315 } do
		local x, z = K.around(b, 15)
		local id = "gnomon" .. i
		K.mass({
			id = id,
			x = x,
			z = z,
			w = 4,
			h = 30,
			color = SANDSTONE,
			mat = "Sandstone",
			trim = { h = 30, t = 0.6, color = BRONZE, mat = "Metal" },
		})
		-- the neon hour-notch strip on the corner that faces the square
		local sx, sz = K.around(b, 15 - math.sqrt(2) * 2.05)
		K.box({
			id = id .. "/notch",
			kind = "glow",
			set = "decor",
			x = sx,
			z = sz,
			w = 0.3,
			d = 0.3,
			h0 = 2,
			h1 = 28,
			yaw = -b + 45,
			color = rgb(255, 196, 80),
			mat = "Neon",
		})
	end

	-- Covered Souk: z -3..3, x 14..40 -------------------------------------------
	local awnings = { rgb(190, 70, 50), rgb(40, 110, 150), rgb(220, 160, 50) }
	local goods = { rgb(230, 170, 60), rgb(200, 90, 60), rgb(120, 150, 90) }
	for i, x in { 18, 26, 34 } do
		for j, s in { -1, 1 } do
			K.stall({
				id = `stall{i}{j}`,
				x = x,
				z = s * 4.5,
				yaw = if s < 0 then 180 else 0,
				color = awnings[(i + j) % 3 + 1],
				goods = goods[(i + 2 * j) % 3 + 1],
				lit = (i == 1 and j == 1) or (i == 2 and j == 2) or (i == 3 and j == 1),
			})
		end
	end
	for i, x in { 15, 23, 31, 39 } do
		K.box({
			id = "souk/beam" .. i,
			kind = "beam",
			set = "decor",
			x = x,
			z = 0,
			w = 0.4,
			d = 12,
			h0 = 4.7,
			h1 = 5.1,
			color = TIMBER,
			mat = "Wood",
		})
	end
	for i, c in { { 19, rgb(200, 90, 60) }, { 35, rgb(220, 180, 110) } } do
		K.box({
			id = "souk/canopy" .. i,
			kind = "awning",
			set = "decor",
			x = c[1],
			z = 0,
			w = 8,
			d = 11,
			h0 = 5.1,
			h1 = 5.2,
			color = c[2],
			mat = "Fabric",
		})
	end

	-- Quarters: 3 blocks of 4 mudbrick houses, their roofs the upper route -------
	-- mirror (mx, mz) puts house A (h 5) on the corner nearest the centre.
	local quarters = {
		{ name = "ne", cx = 30, cz = -24, mx = 1, mz = 1, ramp = { 9.25, -33.5, 0 }, truss = -19 },
		{ name = "nw", cx = -30, cz = -24, mx = -1, mz = 1, ramp = { -9.25, -33.5, 180 }, truss = -19 },
		{ name = "se", cx = 30, cz = 26, mx = 1, mz = -1, ramp = { 9.25, 34.5, 0 }, truss = 21 },
	}
	local HOUSE_TINT = { rgb(196, 150, 100), rgb(204, 160, 110), rgb(188, 142, 94), rgb(200, 154, 104) }

	-- Rails along an edge from a to b (plan), with gaps { centre (distance from a), width }.
	local function edgeRail(id: string, a: { number }, b: { number }, h: number, gaps: { { number } })
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local ux, uz = (b[1] - a[1]) / len, (b[2] - a[2]) / len
		local pieces = { { 0, len } }
		for _, g in gaps do
			local g0, g1 = g[1] - g[2] / 2, g[1] + g[2] / 2
			local nxt = {}
			for _, p in pieces do
				if g1 <= p[1] or g0 >= p[2] then
					table.insert(nxt, p)
				else
					if g0 > p[1] then
						table.insert(nxt, { p[1], g0 })
					end
					if g1 < p[2] then
						table.insert(nxt, { g1, p[2] })
					end
				end
			end
			pieces = nxt
		end
		local k = 0
		for _, p in pieces do
			if p[2] - p[1] >= 0.9 then
				k += 1
				K.rail({
					id = id .. "-" .. k,
					a = { a[1] + ux * p[1], a[2] + uz * p[1] },
					b = { a[1] + ux * p[2], a[2] + uz * p[2] },
					h = h,
					style = "timber",
					color = ROPE,
				})
			end
		end
	end

	for _, q in quarters do
		local houses = {}
		for i, o in { { -1, -1, 5 }, { 1, -1, 6.2 }, { 1, 1, 7.4 }, { -1, 1, 6.2 } } do
			local hx, hz = q.cx + 7.5 * o[1] * q.mx, q.cz + 7.5 * o[2] * q.mz
			local sx, sz = o[1] * q.mx, o[2] * q.mz -- away from the quarter centre
			houses[i] = { x = hx, z = hz, h = o[3], sx = sx, sz = sz }
		end
		for i, hs in houses do
			local letter = string.sub("abcd", i, i)
			local id = `{q.name}-{letter}`
			local isA = i == 1
			-- the roof clutter (local -2.25, +2.25) lands in the inner corner
			local yaw = if -hs.sx < 0 then (if -hs.sz > 0 then 0 else 270) else (if -hs.sz > 0 then 90 else 180)
			K.house({ id = id, x = hs.x, z = hs.z, h = hs.h, yaw = yaw, color = HOUSE_TINT[i], clutter = not isA })
			-- windcatcher: at the roof centre on A, in the outer corner elsewhere.
			-- The corner ones stand 0.25 proud of both outer walls (centre offset
			-- 2.5, not the design's 2.25): flush, a grazing hit on the NW D and SE B
			-- windcatchers' inner corners (15.5) fails the fan at (-30, -10) and (30, 40).
			local wx, wz = hs.x, hs.z
			if not isA then
				wx, wz = hs.x + hs.sx * 2.5, hs.z + hs.sz * 2.5
			end
			K.windcatcher({ id = id .. "/wind", x = wx, z = wz, h0 = hs.h, top = 26, color = SANDSTONE })
			-- rails on the two outer faces (clear of the windcatcher), with gaps at
			-- the ramp, the trusses and the souk bridges
			local fx = hs.x + hs.sx * (4.5 - 0.15)
			local fz = hs.z + hs.sz * (4.5 - 0.15)
			local zFrom, zTo = hs.z - hs.sz * 4.35, if isA then hs.z + hs.sz * 4.35 else hs.z
			local xFrom, xTo = hs.x - hs.sx * 4.35, if isA then hs.x + hs.sx * 4.35 else hs.x
			local xGaps, zGaps = {}, {}
			if isA then
				table.insert(xGaps, { math.abs(q.ramp[2] - zFrom), 3.6 })
			end
			if i == 3 then
				table.insert(xGaps, { math.abs(q.truss - zFrom), 3 })
			end
			if q.name ~= "nw" and (i == 3 or i == 4) then
				local bx = if i == 3 then 35.5 else 24.5
				table.insert(zGaps, { math.abs(bx - xFrom), 3.2 })
				if i == 4 then
					table.insert(zGaps, { math.abs(26.6 - xFrom), 3 })
				end
			end
			edgeRail(id .. "/rail-x", { fx, zFrom }, { fx, zTo }, hs.h, xGaps)
			edgeRail(id .. "/rail-z", { xFrom, fz }, { xTo, fz }, hs.h, zGaps)
		end
		-- plank bridges between neighbours, landing mid-edge
		for i = 1, 4 do
			local p, r = houses[i], houses[i % 4 + 1]
			local dx, dz = r.x - p.x, r.z - p.z
			local l = math.sqrt(dx * dx + dz * dz)
			local ux, uz = dx / l, dz / l
			K.bridge({
				id = `{q.name}-plank{i}`,
				a = { p.x + ux * 4.5, p.z + uz * 4.5, p.h },
				b = { r.x - ux * 4.5, r.z - uz * 4.5, r.h },
				w = 3,
				t = 0.4,
				style = "flat",
				railStyle = "timber",
				railColor = ROPE,
				color = rgb(134, 98, 62),
				mat = "WoodPlanks",
				walk = true,
			})
		end
		-- the ramp onto house A, and the outer truss on house C
		K.ramp({
			id = q.name .. "-ramp",
			x = q.ramp[1],
			z = q.ramp[2],
			run = q.ramp[3],
			w = 3,
			rise = 5,
			color = rgb(190, 146, 98),
			mat = "Sandstone",
		})
		local c = houses[3]
		K.ladder({
			id = q.name .. "-c/truss",
			x = c.x + c.sx * 4.92,
			z = q.truss,
			top = c.h,
			color = TIMBER,
			mat = "Wood",
		})
	end

	-- Souk link: rope bridges between the NE and SE quarters, and the trusses
	-- on the D houses' souk faces.
	K.bridge({ id = "souk-rope1", a = { 24.5, -12, 6.2 }, b = { 24.5, 14, 6.2 }, style = "rope", walk = true })
	K.bridge({ id = "souk-rope2", a = { 35.5, -12, 7.4 }, b = { 35.5, 14, 7.4 }, style = "rope", walk = true })
	K.ladder({ id = "ne-d/truss", x = 26.6, z = -11.58, top = 6.2, color = TIMBER, mat = "Wood" })
	K.ladder({ id = "se-d/truss", x = 26.6, z = 13.58, top = 6.2, color = TIMBER, mat = "Wood" })

	-- Citadel (hero): two terraces and the signal tower ------------------------
	local TERRACE = rgb(200, 160, 108)
	K.rect({
		id = "citadel/lower",
		kind = "deck",
		x0 = -12,
		x1 = 12,
		z0 = -52,
		z1 = -36,
		h0 = 0,
		h1 = 4,
		color = TERRACE,
		mat = "Sandstone",
		floor = true,
	})
	K.rect({
		id = "citadel/upper",
		kind = "deck",
		x0 = -8,
		x1 = 8,
		z0 = -51,
		z1 = -41,
		h0 = 0,
		h1 = 8,
		color = rgb(208, 170, 118),
		mat = "Sandstone",
		floor = true,
	})
	K.box({
		id = "signal",
		kind = "tower",
		x = 0,
		z = -48,
		w = 5,
		d = 5,
		h0 = 0,
		h1 = 38,
		color = rgb(214, 178, 128),
		mat = "Sandstone",
	})
	K.box({
		id = "signal/crown",
		kind = "trim",
		set = "decor",
		x = 0,
		z = -48,
		w = 5.8,
		d = 5.8,
		h0 = 35,
		h1 = 36,
		color = rgb(176, 132, 86),
		mat = "Sandstone",
	})
	K.box({
		id = "signal/brazier",
		kind = "glow",
		set = "decor",
		x = 0,
		z = -48,
		w = 3,
		d = 3,
		h0 = 38,
		h1 = 38.8,
		color = BRONZE,
		mat = "Metal",
		fire = true,
		light = { color = rgb(255, 170, 80), range = 60, bright = 2 },
	})
	-- Ramp 1 (main, 8 wide) up the south face; Ramp 2 up the east strip with its
	-- landing against the upper terrace; Ramp 3, the back stair, down to the north.
	K.ramp({ id = "citadel/ramp1", x = 0, z = -29, run = 270, w = 8, rise = 4, color = TERRACE, mat = "Sandstone" })
	K.ramp({
		id = "citadel/ramp2",
		x = 10,
		z = -36,
		run = 270,
		w = 4,
		rise = 4,
		h0 = 4,
		landing = true,
		color = TERRACE,
		mat = "Sandstone",
	})
	K.ramp({ id = "citadel/ramp3", x = 0, z = -59, run = 90, w = 4, rise = 4, color = TERRACE, mat = "Sandstone" })
	K.railRect({
		id = "citadel/rail",
		x0 = -8,
		x1 = 8,
		z0 = -51,
		z1 = -41,
		h = 8,
		faces = { "n", "w", "s" },
		style = "timber",
		color = ROPE,
	})

	-- Cistern Oasis --------------------------------------------------------------
	K.water({ x = -28, z = 26, r = 8 })
	for i, p in
		{
			{ -38, 26, 13 },
			{ -35.1, 33.1, 12 },
			{ -35.1, 18.9, 14 },
			{ -28, 36, 12.5 },
			{ -28, 16, 13.5 },
			{ -20, 30, 11 },
		}
	do
		K.tree({ id = "palm" .. i, x = p[1], z = p[2], h = p[3], kind = "palm" })
	end
	for i, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		K.box({
			id = "pergola/post" .. i,
			kind = "post",
			x = -14 + s[1] * 3.6,
			z = 38 + s[2] * 3.6,
			w = 0.5,
			d = 0.5,
			h0 = 0,
			h1 = 4.4,
			color = TIMBER,
			mat = "Wood",
		})
	end
	K.box({
		id = "pergola",
		kind = "roof",
		set = "decor",
		x = -14,
		z = 38,
		w = 8.4,
		d = 8.4,
		h0 = 4.4,
		h1 = 4.7,
		color = rgb(150, 112, 70),
		mat = "WoodPlanks",
		alpha = 0.25,
	})
	for i, p in { { -48, 30 }, { -18, 46 } } do
		K.mast({
			id = "oasis-mast" .. i,
			x = p[1],
			z = p[2],
			h = 22,
			color = TIMBER,
			mat = "Wood",
			armColor = STEEL,
			armMat = "Metal",
		})
	end

	-- Caravan masts --------------------------------------------------------------
	for i, p in { { 10, 56, 22 }, { -10, 56, 22 }, { 12, -58, 20 }, { -12, -58, 20 } } do
		K.mast({
			id = "caravan-mast" .. i,
			x = p[1],
			z = p[2],
			h = p[3],
			color = TIMBER,
			mat = "Wood",
			armColor = STEEL,
			armMat = "Metal",
			tip = rgb(255, 190, 110),
			lit = i <= 2,
		})
	end

	-- Edge: wall fragments at r 52 (r 57 on 220 and 320, clear of the NW and NE
	-- B houses, which reach r 55) ------------------------------------------------
	for i, b in { 30, 110, 140, 170, 200, 220, 320, 340 } do
		local r = if b == 220 or b == 320 then 57 else 52
		local x, z = K.around(b, r)
		K.box({
			id = "wall" .. i,
			kind = "wall",
			x = x,
			z = z,
			w = 1,
			d = 8,
			h0 = 0,
			h1 = 2.4,
			yaw = -b,
			color = rgb(180, 136, 90),
			mat = "Sandstone",
		})
	end

	-- Ksar towers: the outer ring of wide masses ---------------------------------
	for k = 0, 7 do
		local b = 22.5 + 45 * k
		local r = if b == 67.5 or b == 112.5 then 62 else 60
		local x, z = K.around(b, r)
		local id = "ksar" .. (k + 1)
		K.mass({
			id = id,
			x = x,
			z = z,
			w = 7,
			h = 30,
			yaw = -b,
			color = MUD,
			mat = "Sandstone",
			backdrop = true,
			keep = true,
			trim = { h = 30, t = 1, color = rgb(176, 132, 86), mat = "Sandstone" },
		})
		-- slit windows on the face toward C
		local sx, sz = K.around(b, r - 3.55)
		K.box({
			id = id .. "/slits",
			kind = "window",
			set = "decor",
			x = sx,
			z = sz,
			w = 0.1,
			d = 1,
			h0 = 14,
			h1 = 24,
			yaw = -b,
			color = DARK,
			mat = "Wood",
			backdrop = true,
		})
	end

	-- Dovecotes ---------------------------------------------------------------------
	for i, p in { { 36, -43 }, { -4, 23.5 }, { -35.5, -6.5 } } do
		local id = "dovecote" .. i
		K.mass({
			id = id,
			x = p[1],
			z = p[2],
			w = 4.5,
			h = 26,
			color = rgb(186, 140, 92),
			mat = "Sandstone",
			trim = { h = 26, t = 0.4, color = rgb(170, 126, 82), mat = "Sandstone", grow = 0.8 },
		})
		-- the band of pigeon holes, on the face toward C
		local face = if math.abs(p[1]) > math.abs(p[2])
			then (if p[1] > 0 then "Left" else "Right")
			else (if p[2] > 0 then "Front" else "Back")
		K.box({
			id = id .. "/holes",
			kind = "band",
			set = "decor",
			x = p[1],
			z = p[2],
			w = 4.6,
			d = 4.6,
			h0 = 20,
			h1 = 24,
			color = rgb(190, 146, 98),
			mat = "Sandstone",
			text = { text = "● ● ●\n● ● ●\n● ● ●", face = face, color = DARK },
		})
	end

	-- Oil lanterns -------------------------------------------------------------------
	for i, p in { { 14, -7 }, { 14, 7 }, { -5.5, -30 }, { 5.5, -30 }, { 9, 38.5 }, { -22, 36 } } do
		K.box({
			id = "lantern" .. i,
			kind = "lantern",
			x = p[1],
			z = p[2],
			w = 0.5,
			d = 0.5,
			h0 = 0,
			h1 = 2.8,
			color = TIMBER,
			mat = "Wood",
		})
		K.box({
			id = "lantern" .. i .. "/glow",
			kind = "glow",
			set = "decor",
			x = p[1],
			z = p[2],
			w = 0.8,
			d = 0.8,
			h0 = 2.8,
			h1 = 3.7,
			color = rgb(255, 184, 100),
			mat = "Neon",
			light = if i == 3 or i == 4 then { color = rgb(255, 184, 100), range = 22, bright = 1.2 } else nil,
		})
	end

	-- Cover: crates, sacks and pots (seeded) -------------------------------------------
	K.scatter({
		id = "cover",
		n = 16,
		radius = 1.5,
		region = { r0 = 20, r1 = 50 },
		make = function(id: string, x: number, z: number, rng: any)
			local kind = rng.int(1, 3)
			local yaw = rng.num(0, 90)
			if kind == 1 then
				K.crate({ id = id, x = x, z = z, yaw = yaw, color = rgb(150, 112, 68) })
			elseif kind == 2 then
				K.box({
					id = id,
					kind = "sacks",
					x = x,
					z = z,
					w = 2.6,
					d = 1.8,
					h0 = 0,
					h1 = 2.2,
					yaw = yaw,
					color = rgb(200, 176, 130),
					mat = "Fabric",
				})
			else
				K.cyl({
					id = id,
					kind = "pot",
					x = x,
					z = z,
					w = 2,
					h0 = 0,
					h1 = 2.4,
					color = rgb(176, 96, 60),
					mat = "Slate",
				})
			end
		end,
	})
end
