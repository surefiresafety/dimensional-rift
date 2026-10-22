--!strict
-- The Walled Compound (Kyoto Imperial Academy), dusk, blossom. Design:
-- docs/design/worlds.md §3.4. A courtyard inside an octagonal plaster wall
-- whose wall-walk (h 6.5) is the upper loop, with corner bastions, four
-- watchtowers on the diagonals and a gatehouse on the south flat. The
-- Five-Tier Pagoda stands to the north, the Thousand-Gate Path of torii runs
-- south to the gate, lecture halls flank the court, a pond garden with a tea
-- pavilion lies to the south-east and a bamboo grove to the south-west.

return function(K: any)
	local rgb = K.rgb
	K.budget(500, 21)
	K.ground("Grass", rgb(92, 104, 70))
	K.hero(0, -38, 36, { "pagoda" })

	local PLASTER = rgb(232, 226, 214)
	local STONE = rgb(118, 112, 104)
	local PAVING = rgb(140, 132, 120)
	local VERMILION = rgb(196, 52, 38)
	local TILE = rgb(52, 56, 66)
	local DARKWOOD = rgb(70, 48, 36)
	local GOLD = rgb(181, 140, 60)
	local GLOW = rgb(255, 190, 120)

	local WALK = 6.5 -- wall-walk height
	local AP = 54 -- apothem of the wall's centre line
	local HALF = 22.5
	local tanH = math.tan(math.rad(HALF))

	--- A point on the flat centred on bearing b: `ap` out, `t` along it (toward b + 90).
	local function flat(b: number, ap: number, t: number): (number, number)
		return K.toWorld(0, 0, -b, ap, t)
	end

	-- Pads (11, 4 boss) ---------------------------------------------------------
	for _, p in { { 26, -30 }, { -26, -30 }, { 24, 32 }, { -24, 32 } } do
		K.pad(p[1], p[2], 0, true)
	end
	for _, p in { { 15, -28 }, { -15, -28 }, { 24, 0 }, { -24, 0 }, { -36, 20 }, { 45, -14 }, { -45, -14 } } do
		K.pad(p[1], p[2])
	end

	-- Ground dressing: raked gravel round the plaza and along the torii path ----
	K.terrain({
		op = "block",
		x = 0,
		z = 31,
		w = 10,
		d = 40,
		h0 = -1.67,
		h1 = 0,
		material = "Sand",
		color = rgb(204, 196, 178),
	})
	K.terrain({ op = "cyl", x = 0, z = 0, w = 26, h0 = -1.67, h1 = 0, material = "Sand" })
	K.terrain({ op = "block", x = 0, z = -24, w = 8, d = 12, h0 = -1.67, h1 = 0, material = "Sand" })
	K.inlay({ id = "plaza", r = 12, w = 0.4, color = GLOW, fill = rgb(196, 188, 170), fillMat = "Sand" })

	-- The octagonal wall (upper loop, h 6.5) -----------------------------------
	local NAMES =
		{ [0] = "e", [45] = "se", [90] = "s", [135] = "sw", [180] = "w", [225] = "nw", [270] = "n", [315] = "ne" }
	for b = 0, 315, 45 do
		local name = NAMES[b]
		if b == 90 then
			-- the south flat, cut by the 8 u gate (x -4..4)
			for i, x in { { 4, 22.35 }, { -22.35, -4 } } do
				K.rect({
					id = "wall/s" .. i,
					kind = "wall",
					x0 = x[1],
					x1 = x[2],
					z0 = AP - 1.5,
					z1 = AP + 1.5,
					h0 = 0,
					h1 = WALK,
					color = PLASTER,
					mat = "Plaster",
				})
			end
		else
			local x, z = K.around(b, AP)
			K.box({
				id = "wall/" .. name,
				kind = "wall",
				x = x,
				z = z,
				w = 3,
				d = 44.7,
				h0 = 0,
				h1 = WALK,
				yaw = -b,
				color = PLASTER,
				mat = "Plaster",
			})
		end
		-- outer rail, 46.0 long at apothem 55.35, with a 3 u gap at a tower truss
		local half = 55.5 * tanH
		local ax, az = flat(b, 55.35, -half)
		local bx, bz = flat(b, 55.35, half)
		K.rail({
			id = "wall/rail-" .. name,
			a = { ax, az },
			b = { bx, bz },
			h = WALK,
			style = "timber",
			color = DARKWOOD,
			gaps = if b % 90 == 45 then { { half - 1.5, half + 1.5 } } else nil,
		})
		-- the walk: vertex to vertex on the centre line
		local vr = AP / math.cos(math.rad(HALF))
		local wax, waz = K.around(b - HALF, vr)
		local wbx, wbz = K.around(b + HALF, vr)
		K.walk("wall/" .. name, { wax, waz, WALK }, { wbx, wbz, WALK }, 3)
	end
	-- Corner bastions over the vertices (their tops carry the walk's outer corner).
	for k = 0, 7 do
		local b = 22.5 + 45 * k
		local x, z = K.around(b, 59.5)
		K.box({
			id = "bastion" .. (k + 1),
			kind = "wall",
			x = x,
			z = z,
			w = 5,
			d = 5,
			h0 = 0,
			h1 = 6.6,
			yaw = -b,
			color = STONE,
			mat = "Cobblestone",
		})
	end

	-- Main gate: the gatehouse deck over the 8 u gap, a roof on 4 posts ---------
	K.rect({
		id = "gate",
		kind = "deck",
		x0 = -4,
		x1 = 4,
		z0 = AP - 1.5,
		z1 = AP + 1.5,
		h0 = 6,
		h1 = WALK,
		color = rgb(120, 92, 64),
		mat = "WoodPlanks",
	})
	-- A tall gate canopy (underside 16.4) on 4 posts on the wall-walk and 2 on the
	-- landings; it reaches over the landings so the court just inside the gate
	-- has a swing anchor (design: roof to 10; see the report).
	for i, p in { { -4.3, 52.8 }, { 4.3, 52.8 }, { 4.3, 55.2 }, { -4.3, 55.2 }, { 4.6, 49.8 }, { -4.6, 49.8 } } do
		K.box({
			id = "gate/post" .. i,
			kind = "post",
			x = p[1],
			z = p[2],
			w = 0.6,
			d = 0.6,
			h0 = WALK,
			h1 = 16.4,
			color = VERMILION,
			mat = "Wood",
		})
	end
	K.box({
		id = "gate/tie",
		kind = "beam",
		set = "decor",
		x = 0,
		z = 52.8,
		w = 9.2,
		d = 0.5,
		h0 = 12,
		h1 = 12.6,
		color = VERMILION,
		mat = "Wood",
	})
	K.box({
		id = "gate/roof",
		kind = "roof",
		x = 0,
		z = 53.05,
		w = 17,
		d = 7.5,
		h0 = 16.4,
		h1 = 17,
		color = TILE,
		mat = "Slate",
	})
	K.box({
		id = "gate/roof2",
		kind = "roof",
		x = 0,
		z = 53.05,
		w = 12,
		d = 4.5,
		h0 = 17,
		h1 = 17.8,
		color = TILE,
		mat = "Slate",
	})
	K.box({
		id = "gate/ridge",
		kind = "roof",
		set = "decor",
		x = 0,
		z = 53.05,
		w = 9,
		d = 0.6,
		h0 = 17.8,
		h1 = 18.3,
		color = GOLD,
		mat = "Metal",
		light = { color = GLOW, range = 26, bright = 1.2 },
	})
	-- Gate stairs on the inner face, x +-(7..18.4), climbing toward the gate onto
	-- 3 x 3 plaster landings flush with the wall-walk; a rail on each landing's gate edge.
	for i, s in { 1, -1 } do
		K.ramp({
			id = "gate/stair" .. i,
			x = 18.4 * s,
			z = 51,
			run = if s > 0 then 180 else 0,
			w = 3,
			rise = WALK,
			len = 11.4,
			stairs = true,
			landing = 3,
			color = PAVING,
			mat = "Cobblestone",
			landColor = PLASTER,
			landMat = "SmoothPlastic",
		})
		K.rail({
			id = "gate/rail" .. i,
			a = { 4.15 * s, 49.5 },
			b = { 4.15 * s, 52.5 },
			h = WALK,
			style = "timber",
			color = VERMILION,
		})
	end

	-- Wall accesses: tangential ramps with landings on the E, W and N flats -----
	-- (each ramp and its landing centred on the flat, the landing against the wall)
	for _, a in
		{
			{ id = "e", x = 51, z = 7.2, run = 270 },
			{ id = "w", x = -51, z = 7.2, run = 270 },
			{ id = "n", x = -7.2, z = -51, run = 0 },
		}
	do
		K.ramp({
			id = "access/" .. a.id,
			x = a.x,
			z = a.z,
			run = a.run,
			w = 3,
			rise = WALK,
			len = 11.4,
			landing = true,
			color = PAVING,
			mat = "Cobblestone",
		})
	end
	-- Tower ramps along the diagonal flats at apothem 51: foot toward the tower,
	-- top and landing toward the E or W vertex.
	for _, t in { { 45, -1 }, { 315, 1 }, { 135, 1 }, { 225, -1 } } do
		local b, sgn = t[1], t[2]
		local fx, fz = flat(b, 51, 4.3 * sgn)
		K.ramp({
			id = "access/" .. NAMES[b],
			x = fx,
			z = fz,
			run = b + 90 * sgn,
			w = 3,
			rise = WALK,
			len = 11.4,
			landing = true,
			color = PAVING,
			mat = "Cobblestone",
		})
	end

	-- Watchtowers (B5) outside the diagonal flats, apothem 58.5 -----------------
	-- The truss is on the inner face, standing on the wall-walk (h 6.5 -> 13).
	for _, b in { 45, 135, 225, 315 } do
		local x, z = K.around(b, 58.5)
		local id = "tower-" .. NAMES[b]
		K.watchtower({
			id = id,
			x = x,
			z = z,
			deck = 13,
			top = 20,
			yaw = -b,
			truss = "w",
			trussBase = WALK,
			color = rgb(120, 92, 64),
			coreColor = PLASTER,
			roof = TILE,
		})
		local dx, dz = flat(b, 58.5 - 2.55, 1.6)
		K.box({
			id = id .. "/door",
			kind = "door",
			set = "decor",
			x = dx,
			z = dz,
			w = 0.1,
			d = 1.6,
			h0 = WALK,
			h1 = WALK + 3,
			yaw = -b,
			color = DARKWOOD,
			mat = "Wood",
		})
	end

	-- The Five-Tier Pagoda (hero), (0, -38) -------------------------------------
	K.rect({
		id = "pagoda/ledge",
		kind = "podium",
		x0 = -8,
		x1 = 8,
		z0 = -46,
		z1 = -30,
		h0 = 0,
		h1 = 6,
		color = rgb(150, 146, 138),
		mat = "Slate",
	})
	K.ramp({
		id = "pagoda/stair",
		x = 0,
		z = -19.5,
		run = 270,
		w = 6,
		rise = 6,
		stairs = true,
		color = rgb(150, 146, 138),
		mat = "Slate",
	})
	K.railRect({
		id = "pagoda/rail",
		x0 = -8,
		x1 = 8,
		z0 = -46,
		z1 = -30,
		h = 6,
		gaps = { { "s", 0, 6 } :: { any } },
		style = "timber",
		color = VERMILION,
	})
	for k = 1, 5 do
		local base = 6 + 6 * (k - 1)
		local w = 12 - 1.5 * (k - 1)
		K.box({
			id = "pagoda/tier" .. k,
			kind = "tower",
			x = 0,
			z = -38,
			w = w,
			d = w,
			h0 = base,
			h1 = base + 5,
			color = rgb(110, 62, 42),
			mat = "WoodPlanks",
		})
		K.box({
			id = "pagoda/eave" .. k,
			kind = "roof",
			x = 0,
			z = -38,
			w = w + 3.5,
			d = w + 3.5,
			h0 = base + 5,
			h1 = base + 6,
			color = TILE,
			mat = "Slate",
		})
	end
	K.cyl({
		id = "pagoda/finial",
		kind = "finial",
		set = "decor",
		x = 0,
		z = -38,
		w = 0.6,
		h0 = 36,
		h1 = 42,
		color = GOLD,
		mat = "Metal",
	})
	K.ball({
		id = "pagoda/jewel",
		kind = "glow",
		set = "decor",
		x = 0,
		z = -38,
		dia = 1.2,
		h = 42.4,
		color = GLOW,
		mat = "Neon",
		light = { color = GLOW, range = 40, bright = 1.5 },
	})

	-- The Thousand-Gate Path: 8 torii at z 16 + 4.6k ---------------------------
	for k = 0, 7 do
		K.torii({ id = "torii" .. (k + 1), x = 0, z = 16 + 4.6 * k })
	end

	-- Lecture halls (B4) 18 x 12, x +-(20..38), z -20..-8, fronts to the south --
	for i, s in { 1, -1 } do
		K.pavilion({
			id = "hall" .. i,
			x = 29 * s,
			z = -14,
			w = 18,
			d = 12,
			h = 8,
			yaw = 180,
			wall = rgb(214, 204, 186),
			post = VERMILION,
			roof = TILE,
		})
	end

	-- Pond garden: water, a red arched bridge, the tea pavilion and 4 rocks -----
	K.water({ x = 36, z = 18, r = 9 })
	K.bridge({ id = "pond/bridge", a = { 36, 10, 0 }, b = { 36, 26, 0 }, style = "arch", railColor = VERMILION })
	K.teahouse({ id = "tea", x = 36, z = 5, run = 90, foot = { 36, -1.625 } })
	for i, r in { { 27.5, 13, 2.4 }, { 27.5, 21.5, 2.2 }, { 45.5, 15, 2.6 }, { 43.5, 26.5, 2 } } do
		K.ball({
			id = "pond/rock" .. i,
			kind = "rock",
			x = r[1],
			z = r[2],
			dia = r[3],
			h = r[3] * 0.2,
			color = rgb(104, 100, 96),
			mat = "Rock",
		})
	end

	-- Stone lanterns: 8 at r 21 on 22.5 + 45k --------------------------------------
	for k = 0, 7 do
		local b = 22.5 + 45 * k
		local x, z = K.around(b, 21)
		K.stoneLantern({ id = "lantern" .. (k + 1), x = x, z = z, yaw = -b })
	end

	-- Cedars: old cedars in the court, the ring outside the wall ------------------
	for i, c in { { 38, -28 }, { -38, -28 }, { 20, 44 }, { -20, 44 }, { 46, 4 }, { -46, 4 }, { 14, 10 }, { -14, 10 } } do
		K.tree({ id = "cedar" .. i, x = c[1], z = c[2], h = 34, kind = "cedar" })
	end
	for i, c in
		{
			{ 0, 63 },
			{ 56.25, 63 },
			{ 123.75, 63 },
			{ 180, 63 },
			{ 236.25, 63 },
			{ 303.75, 63 },
			{ 45, 67 },
			{ 135, 67 },
		}
	do
		local x, z = K.around(c[1], c[2])
		K.tree({ id = "ringcedar" .. i, x = x, z = z, h = 44, kind = "cedar" })
	end

	-- Backdrop: 4 decor cedars and mountains ----------------------------------
	for i, c in { { 205, 96, 36 }, { 250, 104, 40 }, { 292, 100, 34 }, { 335, 92, 38 } } do
		local x, z = K.around(c[1], c[2])
		K.tree({ id = "backcedar" .. i, x = x, z = z, h = c[3], kind = "backdrop" })
	end
	for _, m in
		{
			{ 270, 190, 120, -30 },
			{ 235, 200, 100, -30 },
			{ 305, 205, 110, -35 },
			{ 200, 215, 90, -30 },
			{ 340, 220, 95, -32 },
			{ 150, 230, 80, -30 },
			{ 30, 235, 85, -32 },
		}
	do
		local x, z = K.around(m[1], m[2])
		K.terrain({
			op = "ball",
			x = x,
			z = z,
			w = m[3],
			d = m[3],
			h0 = m[4] - m[3] / 2,
			h1 = m[4] + m[3] / 2,
			material = "Rock",
			color = rgb(86, 88, 104),
		})
	end

	-- Seeded scatter ---------------------------------------------------------
	-- Bamboo grove in the SW quadrant (36 canes, 18 leaf tufts), leaving the (-36, 20) clearing.
	local canes = 0
	K.scatter({
		id = "bamboo",
		n = 36,
		radius = 0.5,
		region = { x0 = -50, x1 = -20, z0 = 4, z1 = 34 },
		make = function(id: string, x: number, z: number, rng: any)
			canes += 1
			local h = rng.num(14, 22)
			K.cyl({
				id = id,
				kind = "cane",
				x = x,
				z = z,
				w = 0.5,
				h0 = 0,
				h1 = h,
				color = rgb(122, 150, 74),
				mat = "Wood",
			})
			if canes % 2 == 0 then
				K.ball({
					id = id .. "/tuft",
					kind = "crown",
					set = "decor",
					x = x,
					z = z,
					dia = 3.2,
					h = h - 1.2,
					color = rgb(86, 130, 66),
					mat = "Grass",
				})
			end
		end,
	})
	-- Blossom trees at r 22-30, kept off the torii path and the pagoda stair.
	for i, sector in { { 102, 258 }, { 282, 438 } } do
		K.scatter({
			id = "blossom" .. i .. "-",
			n = 7,
			radius = 1,
			region = { r0 = 22, r1 = 30, b0 = sector[1], b1 = sector[2] },
			make = function(id: string, x: number, z: number, rng: any)
				K.tree({ id = id, x = x, z = z, h = rng.num(10, 14), kind = "blossom" })
			end,
		})
	end
end
