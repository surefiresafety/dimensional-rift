--!strict
-- Thunderspire (Land of Lightning), a cliff monastery in a storm at dusk.
-- Design: docs/design/worlds.md §3.9. Two terraces climb north to the Great
-- Hall and its stupa spire; the Horn Pinnacles flank the court with ledges at
-- h 8, bridged to piers at h 7 (the upper U). Copper rod towers, storm stones
-- and lantern towers are the swing anchors; slate hills and a snowfield beyond.

return function(K: any)
	local rgb = K.rgb
	K.budget(270, 26)
	K.ground("Slate", rgb(64, 66, 72))
	K.hero(0, -48, 34, { "hall" })

	local GRANITE = rgb(92, 94, 100)
	local COPPER = rgb(184, 115, 51)
	local STONE = rgb(118, 114, 108)
	local PALE = rgb(150, 146, 138)
	local ROCK = rgb(74, 76, 82)
	local WHITE = rgb(226, 222, 212)
	local OCHRE = rgb(196, 140, 60)
	local MAROON = rgb(128, 38, 32)
	local ROOF = rgb(58, 62, 70)
	local GILT = rgb(196, 150, 60)
	local PLANK = rgb(120, 92, 64)
	local SPARK = rgb(150, 200, 255)
	local LANTERN = rgb(255, 196, 120)

	-- Pads (11, 5 boss) ---------------------------------------------------------
	K.pad(0, 40, 0, true)
	K.pad(36, 14, 0, true)
	K.pad(-36, 14, 0, true)
	K.pad(29, -39, 3, true)
	K.pad(-29, -39, 3, true)
	K.pad(20, 6)
	K.pad(-20, 6)
	K.pad(0, -24, 3)
	K.pad(0, 26)
	K.pad(38, 30)
	K.pad(-38, 30)

	-- Terraces and glacis --------------------------------------------------------
	-- The middle terrace's back corners are cut to x +-36 for z < -46, so no
	-- corner stands beyond r 62 (hills start at 66; (40, -50) would be r 64).
	K.rect({
		id = "terrace-mid",
		kind = "terrace",
		x0 = -40,
		x1 = 40,
		z0 = -46,
		z1 = -20,
		h0 = 0,
		h1 = 3,
		floor = true,
		color = STONE,
		mat = "Slate",
	})
	K.rect({
		id = "terrace-mid/back",
		kind = "terrace",
		x0 = -36,
		x1 = 36,
		z0 = -50,
		z1 = -46,
		h0 = 0,
		h1 = 3,
		floor = true,
		color = STONE,
		mat = "Slate",
	})
	K.rect({
		id = "terrace-up",
		kind = "terrace",
		x0 = -20,
		x1 = 20,
		z0 = -56,
		z1 = -36,
		h0 = 0,
		h1 = 6,
		floor = true,
		color = PALE,
		mat = "Slate",
	})
	for _, x in { -32, -16, 0, 16, 32 } do
		K.ramp({ id = `glacis-mid{x}`, x = x, z = -14.75, run = 270, w = 8, rise = 3, color = STONE, mat = "Slate" })
	end
	for _, x in { -12, 0, 12 } do
		K.ramp({
			id = `glacis-up{x}`,
			x = x,
			z = -30.75,
			run = 270,
			w = 8,
			rise = 3,
			h0 = 3,
			color = PALE,
			mat = "Slate",
		})
	end

	-- The Great Hall (hero), x -13..13, z -55..-41 on the upper terrace ---------
	local B = 6.6 -- podium top
	K.rect({
		id = "hall/podium",
		kind = "podium",
		x0 = -13,
		x1 = 13,
		z0 = -55,
		z1 = -41,
		h0 = 6,
		h1 = B,
		floor = true,
		color = rgb(170, 166, 158),
		mat = "Slate",
	})
	K.wedge({
		id = "hall/step",
		kind = "stairs",
		x = 0,
		z = -41 + 0.525,
		w = 1.05,
		d = 6,
		h0 = 6,
		h1 = B,
		run = 270,
		color = rgb(170, 166, 158),
		mat = "Slate",
	})
	for i, x in { -12.4, -4.2, 4.2, 12.4 } do
		K.box({
			id = "hall/post" .. i,
			kind = "post",
			x = x,
			z = -41.6,
			w = 0.8,
			d = 0.8,
			h0 = B,
			h1 = 16.6,
			color = MAROON,
			mat = "Wood",
		})
	end
	for i, x in { -12.7, 12.7 } do
		K.rect({
			id = "hall/side" .. i,
			kind = "wall",
			x0 = x - 0.3,
			x1 = x + 0.3,
			z0 = -55,
			z1 = -44,
			h0 = B,
			h1 = 16.6,
			color = WHITE,
			mat = "SmoothPlastic",
		})
	end
	K.rect({
		id = "hall/back",
		kind = "wall",
		x0 = -12.4,
		x1 = 12.4,
		z0 = -55,
		z1 = -54.4,
		h0 = B,
		h1 = 16.6,
		color = WHITE,
		mat = "SmoothPlastic",
	})
	K.rect({
		id = "hall/roof",
		kind = "roof",
		x0 = -13.5,
		x1 = 13.5,
		z0 = -55.5,
		z1 = -40.5,
		h0 = 16.6,
		h1 = 17.4,
		color = ROOF,
		mat = "Slate",
	})
	K.rect({
		id = "hall/drum",
		kind = "wall",
		x0 = -11,
		x1 = 11,
		z0 = -53.5,
		z1 = -42.5,
		h0 = 17.4,
		h1 = 20,
		color = MAROON,
		mat = "WoodPlanks",
	})
	K.rect({
		id = "hall/clerestory",
		kind = "hall",
		x0 = -13,
		x1 = 13,
		z0 = -55,
		z1 = -41,
		h0 = 20,
		h1 = 26,
		color = WHITE,
		mat = "SmoothPlastic",
	})
	K.rect({
		id = "hall/band",
		kind = "band",
		set = "decor",
		x0 = -13.15,
		x1 = 13.15,
		z0 = -55.15,
		z1 = -40.85,
		h0 = 24,
		h1 = 25.2,
		color = OCHRE,
		mat = "SmoothPlastic",
	})
	K.rect({
		id = "hall/roof2",
		kind = "roof",
		x0 = -14,
		x1 = 14,
		z0 = -56,
		z1 = -40.5,
		h0 = 26,
		h1 = 26.8,
		color = ROOF,
		mat = "Slate",
	})
	K.box({
		id = "hall/ridge",
		kind = "roof",
		x = 0,
		z = -48,
		w = 16,
		d = 0.6,
		h0 = 26.8,
		h1 = 27.3,
		color = GILT,
		mat = "Metal",
		light = { color = LANTERN, range = 24, bright = 1 },
	})
	-- Stupa spire: a 4 x 4 shaft to 34, a gilt bell and finial (decor).
	K.box({
		id = "hall/spire",
		kind = "tower",
		x = 0,
		z = -52,
		w = 4,
		d = 4,
		h0 = 26.8,
		h1 = 34,
		color = WHITE,
		mat = "SmoothPlastic",
	})
	K.cyl({
		id = "hall/spire/bell",
		kind = "bell",
		set = "decor",
		x = 0,
		z = -52,
		w = 5.2,
		h0 = 27.3,
		h1 = 30,
		color = GILT,
		mat = "Metal",
	})
	K.cyl({
		id = "hall/spire/finial",
		kind = "finial",
		set = "decor",
		x = 0,
		z = -52,
		w = 1,
		h0 = 34,
		h1 = 37.5,
		color = GILT,
		mat = "Metal",
	})

	-- Rod towers (8): granite base 5 x 5 x 22, copper mast to 30 --------------
	local function rod(id: string, x: number, z: number, bw: number, bh: number, top: number)
		K.box({
			id = id,
			kind = "tower",
			x = x,
			z = z,
			w = bw,
			d = bw,
			h0 = 0,
			h1 = bh,
			color = GRANITE,
			mat = "Slate",
		})
		K.mast({
			id = id .. "/mast",
			x = x,
			z = z,
			h0 = bh,
			h = top,
			w = 1.2,
			color = COPPER,
			mat = "Metal",
			tip = SPARK,
			lit = true,
		})
	end
	local rods = { { 30, -8 }, { 44, -30 }, { 18, 30 }, { 32, 46 } }
	for i, p in rods do
		for _, s in { 1, -1 } do
			rod(`rod{if s > 0 then "e" else "w"}{i}`, s * p[1], p[2], 5, 22, 30)
		end
	end
	-- Threshold rods (2): the revision 4 build, the R1 inward anchors.
	for _, s in { 1, -1 } do
		rod(`threshold{if s > 0 then "e" else "w"}`, s * 14.5, -4, 4, 14, 26)
	end

	-- Storm stones (4): granite spires 6 x 6 x 30, yaw -b, copper band at 24 ----
	for i, p in { { 12, 56 }, { -12, 56 }, { 53.1, 14.2 }, { -53.1, 14.2 } } do
		K.mass({
			id = "stone" .. i,
			kind = "stone",
			x = p[1],
			z = p[2],
			w = 6,
			h = 30,
			yaw = -K.bearing(0, 0, p[1], p[2]),
			color = GRANITE,
			mat = "Slate",
			trim = { h = 24, t = 1, color = COPPER, mat = "Metal" },
		})
	end

	-- Lantern towers (2): 5 x 5 x 24 with a lit cage ---------------------------
	for _, s in { 1, -1 } do
		local id = `lantern-tower{if s > 0 then "e" else "w"}`
		K.mass({ id = id, kind = "tower", x = s * 14, z = 23, w = 5, h = 24, color = PALE, mat = "Slate" })
		K.box({
			id = id .. "/cage",
			kind = "glow",
			set = "decor",
			x = s * 14,
			z = 23,
			w = 3.2,
			d = 3.2,
			h0 = 24,
			h1 = 26.4,
			color = LANTERN,
			mat = "Neon",
			alpha = 0.2,
			light = { color = LANTERN, range = 24, bright = 1.4 },
		})
	end

	-- Horn Pinnacles, ledges, ledge stairs, piers and bridges (the upper U) ------
	for _, s in { 1, -1 } do
		local side = if s > 0 then "e" else "w"
		local id = "pinnacle-" .. side
		K.rect({
			id = id,
			kind = "rock",
			x0 = s * 40,
			x1 = s * 54,
			z0 = -20,
			z1 = -6,
			h0 = 0,
			h1 = 40,
			color = ROCK,
			mat = "Slate",
		})
		K.box({
			id = id .. "/horn",
			kind = "rock",
			x = s * 48,
			z = -14,
			w = 6,
			d = 6,
			h0 = 40,
			h1 = 47,
			yaw = 20 * s,
			color = ROCK,
			mat = "Slate",
			lean = { 0, 0, -6 * s },
		})
		K.box({
			id = id .. "/strata",
			kind = "trim",
			set = "decor",
			x = s * 47,
			z = -13,
			w = 14.3,
			d = 14.3,
			h0 = 22,
			h1 = 23.2,
			color = rgb(104, 100, 96),
			mat = "Slate",
		})
		-- The ledge on the inner face, h 8.
		K.rect({
			id = id .. "/ledge",
			kind = "deck",
			x0 = s * 36,
			x1 = s * 40,
			z0 = -20,
			z1 = -6,
			h0 = 0,
			h1 = 8,
			color = rgb(96, 94, 90),
			mat = "Slate",
		})
		-- Ledge stair along the south face (z -6..-2), climbing toward C.
		K.ledgeStair({
			id = id .. "/stair",
			x = s * 58,
			z = -4,
			run = if s > 0 then 180 else 0,
			w = 4,
			rise1 = 4,
			land = 4,
			rise2 = 4,
			top = 4,
			color = rgb(110, 106, 100),
			mat = "Slate",
		})
		K.rail({
			id = id .. "/rail",
			a = { s * 36.15, -6 },
			b = { s * 36.15, -17.6 },
			h = 8,
			style = "timber",
		})
		K.walk(id .. "/walk", { s * 38, -4, 8 }, { s * 38, -19, 8 }, 4)

		-- Mid pier: deck 6 x 6 at h 7 on 4 posts standing on the terrace.
		local pier = "pier-" .. side
		K.deck({ id = pier, x = s * 30, z = -26, w = 6, d = 6, h = 7, posts = 4, base = 3, color = PLANK })
		K.ramp({
			id = pier .. "/ramp",
			x = s * 20,
			z = -26,
			run = if s > 0 then 0 else 180,
			w = 3,
			rise = 4,
			h0 = 3,
			color = STONE,
			mat = "Slate",
		})
		local bridgeFace = if s > 0 then "e" else "w"
		local rampFace = if s > 0 then "w" else "e"
		-- 3.4 u gaps where the bridge crosses the pier's SE corner, and one at the ramp top.
		local gaps: { { any } } = {
			{ bridgeFace, -24.6, 3.4 },
			{ "s", s * 32.4, 3.4 },
			{ rampFace, -26, 3.6 },
		}
		K.railRect({
			id = pier .. "/rail",
			x0 = s * 27,
			x1 = s * 33,
			z0 = -29,
			z1 = -23,
			h = 7,
			style = "timber",
			gaps = gaps,
		})
		-- Bridge from the ledge (h 8) down to the pier (h 7).
		K.bridge({
			id = "bridge-" .. side,
			a = { s * 38, -19, 8 },
			b = { s * 31, -26, 7 },
			style = "flat",
			w = 3,
			color = PLANK,
			mat = "WoodPlanks",
			railStyle = "timber",
			walk = true,
		})
		K.walk(pier .. "/walk", { s * 31, -26, 7 }, { s * 27, -26, 7 }, 3)
	end

	-- Lower Court: pilgrim shelters (open 8 x 6) ------------------------------
	for _, s in { 1, -1 } do
		local id = `shelter{if s > 0 then "e" else "w"}`
		local cx, cz = s * 16, 46
		for i, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			K.box({
				id = id .. "/post" .. i,
				kind = "post",
				x = cx + c[1] * 3.6,
				z = cz + c[2] * 2.6,
				w = 0.6,
				d = 0.6,
				h0 = 0,
				h1 = 4.2,
				color = MAROON,
				mat = "Wood",
			})
		end
		K.box({
			id = id,
			kind = "roof",
			x = cx,
			z = cz,
			w = 8,
			d = 6,
			h0 = 4.2,
			h1 = 4.8,
			color = ROOF,
			mat = "Slate",
		})
		K.box({
			id = id .. "/ridge",
			kind = "roof",
			x = cx,
			z = cz,
			w = 6,
			d = 0.5,
			h0 = 4.8,
			h1 = 5.2,
			color = GILT,
			mat = "Metal",
			light = { color = LANTERN, range = 20, bright = 1 },
		})
	end

	-- Stone lanterns on the terraces (6) ---------------------------------------
	for i, p in
		{ { 17, -40, 6 }, { -17, -40, 6 }, { 17, -52, 6 }, { -17, -52, 6 }, { 38.5, -44, 3 }, { -38.5, -44, 3 } }
	do
		K.stoneLantern({ id = "lantern" .. i, x = p[1], z = p[2], h0 = p[3], color = LANTERN })
	end

	-- Prayer flags: strings between the rods, towers and the hall (Beams) ------
	local FLAGS = { rgb(60, 110, 200), rgb(236, 232, 222), rgb(200, 50, 44), rgb(60, 150, 80), rgb(236, 190, 50) }
	local function flags(a: { number }, b: { number }, sag: number)
		local n = #FLAGS
		local function at(t: number): { number }
			return {
				a[1] + (b[1] - a[1]) * t,
				a[2] + (b[2] - a[2]) * t,
				a[3] + (b[3] - a[3]) * t - sag * 4 * t * (1 - t),
			}
		end
		for i = 1, n do
			K.beam({
				a = at((i - 1) / n),
				b = at(i / n),
				color = FLAGS[i],
				width = 1.4,
				alpha = 0.1,
				emission = 0.2,
			})
		end
	end
	for _, s in { 1, -1 } do
		flags({ s * 44, -30, 21.5 }, { s * 30, -8, 21.5 }, 2.5)
		flags({ s * 30, -8, 21.5 }, { s * 14.5, -4, 13.5 }, 1.5)
		flags({ s * 32, 46, 21.5 }, { s * 18, 30, 21.5 }, 2)
		flags({ s * 18, 30, 21.5 }, { s * 14, 23, 23.5 }, 0.5)
		flags({ s * 13.5, -40.5, 16.6 }, { s * 20, -36, 6.4 }, 1)
	end
	flags({ -14, 23, 23.5 }, { 14, 23, 23.5 }, 3)

	-- Beyond: rock spires (backdrop), far outbuildings (keep) and the snowfield --
	for k = 0, 9 do
		local b = 18 + 36 * k
		local x, z = K.around(b, 90)
		K.box({
			id = "spire" .. (k + 1),
			kind = "rock",
			x = x,
			z = z,
			w = 6,
			d = 6,
			h0 = 0,
			h1 = K.rng.num(20, 34),
			yaw = -b,
			color = rgb(84, 86, 92),
			mat = "Slate",
			backdrop = true,
		})
	end
	for i, b in { 200, 235, 305, 340 } do
		local x, z = K.around(b, 84)
		local id = "outbuilding" .. i
		K.box({
			id = id,
			kind = "wall",
			x = x,
			z = z,
			w = 6,
			d = 6,
			h0 = 0,
			h1 = 8,
			yaw = -b,
			color = rgb(214, 208, 196),
			mat = "SmoothPlastic",
			backdrop = true,
			keep = true,
		})
		K.box({
			id = id .. "/roof",
			kind = "roof",
			x = x,
			z = z,
			w = 7,
			d = 7,
			h0 = 8,
			h1 = 8.8,
			yaw = -b,
			color = ROOF,
			mat = "Slate",
			backdrop = true,
			keep = true,
		})
		local wx, wz = K.around(b, 84 - 3.05)
		K.box({
			id = id .. "/window",
			kind = "window",
			set = "decor",
			x = wx,
			z = wz,
			w = 0.1,
			d = 1.6,
			h0 = 4.4,
			h1 = 5.8,
			yaw = -b,
			color = LANTERN,
			mat = "Neon",
			backdrop = true,
		})
	end
	-- Snowfield: 16 radial blocks from r 70 out, a thin layer over the ground.
	for k = 0, 15 do
		local b = k * 22.5
		local x, z = K.around(b, 115)
		K.terrain({
			op = "block",
			x = x,
			z = z,
			w = 90,
			d = 2 * 160 * math.tan(math.rad(11.25)) + 2,
			h0 = -1.5,
			h1 = 0.5,
			yaw = -b,
			material = "Snow",
			color = rgb(214, 220, 230),
		})
	end
	K.hills({
		minGround = 66,
		keepOut = {
			{ bearing = 200, halfWidth = 6 },
			{ bearing = 235, halfWidth = 6 },
			{ bearing = 305, halfWidth = 6 },
			{ bearing = 340, halfWidth = 6 },
		},
		count = 36,
		rMin = 18,
		rMax = 40,
		material = "Slate",
	})

	-- Seeded cover: 12 cairns and 20 boulders in the court --------------------
	K.scatter({
		id = "cairn",
		n = 12,
		radius = 1,
		region = { r0 = 18, r1 = 52 },
		make = function(id: string, x: number, z: number, rng: any)
			K.box({
				id = id,
				kind = "cairn",
				x = x,
				z = z,
				w = 1.6,
				d = 1.6,
				h0 = 0,
				h1 = rng.num(2.3, 3),
				yaw = rng.num(0, 90),
				color = rgb(128, 124, 118),
				mat = "Slate",
				lean = { rng.num(-4, 4), 0, rng.num(-4, 4) },
			})
		end,
	})
	K.scatter({
		id = "boulder",
		n = 20,
		radius = 2,
		region = { r0 = 18, r1 = 52 },
		make = function(id: string, x: number, z: number, rng: any)
			local dia = rng.num(3, 4)
			K.ball({
				id = id,
				kind = "boulder",
				x = x,
				z = z,
				dia = dia,
				h = dia * 0.3,
				color = rgb(88, 90, 96),
				mat = "Slate",
			})
		end,
	})
end
