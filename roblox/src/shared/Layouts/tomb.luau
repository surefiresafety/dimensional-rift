--!strict
-- The Ribbed Vault (Tombs of the Star Vault), night. Design: docs/design/worlds.md §3.3.
-- A ring of 12 pillars carries 12 radial ribs at h 57 round an open oculus;
-- star chains hang from the ribs. The Keeper's Dais stands to the north, the
-- Processional Gallery (h 8) runs round the inside of a 12-sided wall with
-- four Star Gates, and sarcophagi and crystal groves give the floor its cover.

return function(K: any)
	local rgb = K.rgb
	K.budget(340, 16)
	K.ground("Slate", rgb(34, 30, 44))
	K.hero(0, -26, 6, { "dais" })

	local STONE = rgb(74, 66, 92) -- pillars, ribs, rings
	local WALL = rgb(46, 42, 58)
	local DECK = rgb(58, 52, 70)
	local BRONZE = rgb(140, 110, 60)
	local STAR = rgb(150, 140, 220)
	local CHAIN = rgb(176, 180, 214)
	local EMBER = rgb(255, 150, 70)

	-- Pads (11, 4 boss) ----------------------------------------------------------
	for _, p in { { 28.3, 28.3 }, { -28.3, 28.3 }, { -28.3, -28.3 }, { 28.3, -28.3 } } do
		K.pad(p[1], p[2], 0, true)
	end
	for _, p in { { 24, 0 }, { 0, 24 }, { -24, 0 }, { 42, 0 }, { 0, 42 }, { -42, 0 } } do
		K.pad(p[1], p[2])
	end
	K.pad(0, -26, 3) -- the dais top

	-- A radial box on bearing b: `r0..r1` out from C, `wide` across, yaw -b.
	local function radial(o: { [string]: any })
		local x, z = K.around(o.b, (o.r0 + o.r1) / 2)
		o.x, o.z, o.w, o.d, o.yaw = x, z, o.r1 - o.r0, o.wide, -o.b
		o.b, o.r0, o.r1, o.wide = nil, nil, nil, nil
		return K.box(o)
	end

	-- The Vault: 12 pillars, 12 ribs, the crown ring and the outer ring beam ---------
	for i = 1, 12 do
		local b = (i - 1) * 30
		local x, z = K.around(b, 34)
		local id = "pillar" .. i
		K.box({
			id = id,
			kind = "pillar",
			x = x,
			z = z,
			w = 3,
			d = 3,
			h0 = 0,
			h1 = 57,
			yaw = -b,
			color = STONE,
			mat = "Slate",
		})
		K.box({
			id = id .. "/plinth",
			kind = "trim",
			set = "decor",
			x = x,
			z = z,
			w = 3.6,
			d = 3.6,
			h0 = 0,
			h1 = 1.2,
			yaw = -b,
			color = WALL,
			mat = "Slate",
		})
		K.box({
			id = id .. "/capital",
			kind = "trim",
			set = "decor",
			x = x,
			z = z,
			w = 3.8,
			d = 3.8,
			h0 = 55.4,
			h1 = 57,
			yaw = -b,
			color = BRONZE,
			mat = "Metal",
		})
		K.box({
			id = id .. "/glyph",
			kind = "glow",
			set = "decor",
			x = x,
			z = z,
			w = 3.1,
			d = 3.1,
			h0 = 12,
			h1 = 12.4,
			yaw = -b,
			color = STAR,
			mat = "Neon",
			alpha = 0.3,
		})
		radial({
			id = "rib" .. i,
			kind = "rib",
			b = b,
			r0 = 12,
			r1 = 34,
			wide = 3,
			h0 = 57,
			h1 = 58.5,
			color = STONE,
			mat = "Slate",
		})
		-- Ring segments between the ribs, on the half bearings.
		local hb = b + 15
		local cx, cz = K.around(hb, 12 * math.cos(math.rad(15)))
		K.box({
			id = "crown" .. i,
			kind = "rib",
			x = cx,
			z = cz,
			w = 3,
			d = 2 * 12 * math.sin(math.rad(15)) + 1.5,
			h0 = 57,
			h1 = 58.5,
			yaw = -hb,
			color = STONE,
			mat = "Slate",
		})
		local ox, oz = K.around(hb, 34 * math.cos(math.rad(15)))
		K.box({
			id = "ringbeam" .. i,
			kind = "rib",
			x = ox,
			z = oz,
			w = 3,
			d = 2 * 34 * math.sin(math.rad(15)),
			h0 = 57,
			h1 = 58.5,
			yaw = -hb,
			color = STONE,
			mat = "Slate",
		})
	end

	-- Star chains: 4 query-only cores over the crystal groves, chained to the ribs ---
	for i = 1, 4 do
		local b = 45 + (i - 1) * 90
		local x, z = K.around(b, 20)
		K.cyl({
			id = "chain" .. i,
			kind = "core",
			set = "core",
			x = x,
			z = z,
			w = 1.2,
			h0 = 30,
			h1 = 40,
			color = rgb(96, 90, 128),
			mat = "Metal",
		})
		K.ball({
			id = "chain" .. i .. "/star",
			kind = "star",
			set = "decor",
			x = x,
			z = z,
			dia = 1.8,
			h = 29.2,
			color = rgb(220, 214, 255),
			mat = "Neon",
		})
		for _, rb in { b - 15, b + 15 } do
			local rx, rz = K.around(rb, 20 * math.cos(math.rad(15)))
			K.beam({ a = { rx, rz, 57 }, b = { x, z, 40 }, color = CHAIN, width = 0.35, alpha = 0.1, emission = 0.6 })
		end
	end

	-- Keeper's Dais (hero): 5 stepped discs, the seat, the orb, 8 hanging stars -----
	for i = 1, 5 do
		K.cyl({
			id = "dais/step" .. i,
			kind = "dais",
			x = 0,
			z = -26,
			w = 2 * (12 - (i - 1) * 1.4),
			h0 = (i - 1) * 0.6,
			h1 = i * 0.6,
			color = if i % 2 == 1 then rgb(88, 80, 112) else rgb(70, 64, 90),
			mat = "Slate",
			floor = true,
		})
	end
	K.box({
		id = "dais/seat",
		kind = "seat",
		x = 0,
		z = -35,
		w = 5,
		d = 5,
		h0 = 0,
		h1 = 6,
		color = rgb(40, 36, 52),
		mat = "Basalt",
	})
	K.ball({
		id = "dais/orb",
		kind = "orb",
		set = "decor",
		x = 0,
		z = -35,
		dia = 2.2,
		h = 8.2,
		color = rgb(190, 180, 255),
		mat = "Neon",
		light = { color = rgb(170, 160, 255), range = 40, bright = 1.6 },
	})
	for i, s in
		{
			{ 270, 16, 22 },
			{ 270, 22, 27 },
			{ 270, 28, 20 },
			{ 270, 33, 25 },
			{ 240, 20, 24 },
			{ 240, 28, 18 },
			{ 300, 20, 24 },
			{ 300, 28, 18 },
		}
	do
		local x, z = K.around(s[1], s[2])
		K.ball({
			id = "dais/star" .. i,
			kind = "star",
			set = "decor",
			x = x,
			z = z,
			dia = 1.2,
			h = s[3],
			color = rgb(220, 214, 255),
			mat = "Neon",
		})
		K.beam({ a = { x, z, 57 }, b = { x, z, s[3] + 0.6 }, color = CHAIN, width = 0.2, alpha = 0.2, emission = 0.6 })
	end

	-- Star-chart floor ------------------------------------------------------------
	K.inlay({ id = "chart16", r = 16, w = 0.4, color = STAR, fill = rgb(34, 30, 44) })
	K.inlay({ id = "chart30", r = 30, w = 0.4, color = STAR, fill = rgb(34, 30, 44) })

	-- Processional Gallery (h 8) ----------------------------------------------------
	-- The 8 tangential ramps: along the inner edge of the decks either side of each
	-- diagonal, climbing toward the diagonal, their landings flush with the deck edge.
	local S_TOP = -2 -- the landing's far end, u along the deck edge from the deck's centre
	local gaps = {}
	local nRamp = 0
	for _, d in { 45, 135, 225, 315 } do
		for _, sg in { 1, -1 } do
			nRamp += 1
			local b = d - 15 * sg -- the deck it serves
			local tx, tz = -math.sin(math.rad(b)) * sg, math.cos(math.rad(b)) * sg -- along the edge, toward d
			local cx, cz = K.around(b, 47)
			local sFoot = S_TOP - 18
			K.ramp({
				id = "ramp" .. nRamp,
				x = cx + tx * sFoot,
				z = cz + tz * sFoot,
				run = b + 90 * sg,
				w = 4,
				rise = 8,
				landing = true,
				color = DECK,
				mat = "Slate",
			})
			-- the rail gap over the landing (its centre is 2 u short of S_TOP)
			local sMid = S_TOP - 2
			table.insert(gaps, { at = b + sg * math.deg(math.atan(sMid / 49.15)), edge = "inner", width = 4 })
		end
	end
	K.chordRing({
		id = "gallery",
		b0 = -15,
		b1 = 345,
		n = 12,
		rIn = 49,
		rOut = 55,
		top = 8,
		t = 0.4,
		capW = 4.5,
		color = DECK,
		mat = "Slate",
		capColor = BRONZE,
		capMat = "Metal",
		rails = { inner = true, color = rgb(96, 82, 64), gaps = gaps },
	})
	for i = 1, 12 do
		local b = (i - 1) * 30
		radial({
			id = "gallery/post" .. i,
			kind = "post",
			b = b,
			r0 = 49,
			r1 = 50,
			wide = 1,
			h0 = 0,
			h1 = 7.6,
			color = STONE,
			mat = "Slate",
		})
	end

	-- Outer wall: 12 flats (4 Star Gates), clerestory strips, 12 pilasters -----------
	local FLAT = 2 * 55 * math.tan(math.rad(15))
	local nGate = 0
	for i = 1, 12 do
		local b = (i - 1) * 30
		local id = "wall" .. i
		if b % 90 == 0 then
			nGate += 1
			local side = (FLAT - 6) / 2
			for j, s in { -1, 1 } do
				local x, z = K.toWorld(0, 0, -b, 56, s * (3 + side / 2))
				K.box({
					id = id .. "/" .. j,
					kind = "wall",
					x = x,
					z = z,
					w = 2,
					d = side,
					h0 = 0,
					h1 = 26,
					yaw = -b,
					color = WALL,
					mat = "Slate",
				})
			end
			radial({
				id = id .. "/lintel",
				kind = "wall",
				b = b,
				r0 = 55,
				r1 = 57,
				wide = 6,
				h0 = 6.5,
				h1 = 26,
				color = WALL,
				mat = "Slate",
			})
			-- the gate's brazier, inside the gate beside the passage
			local gx, gz = K.toWorld(0, 0, -b, 53.8, 4.6)
			K.cyl({
				id = "gate" .. nGate .. "/brazier",
				kind = "brazier",
				x = gx,
				z = gz,
				w = 1.4,
				h0 = 0,
				h1 = 2.2,
				color = BRONZE,
				mat = "Metal",
				fire = true,
				light = { color = EMBER, range = 30, bright = 1.6 },
			})
		else
			radial({
				id = id,
				kind = "wall",
				b = b,
				r0 = 55,
				r1 = 57,
				wide = FLAT,
				h0 = 0,
				h1 = 26,
				color = WALL,
				mat = "Slate",
			})
		end
		radial({
			id = id .. "/strip",
			kind = "glow",
			set = "decor",
			b = b,
			r0 = 54.9,
			r1 = 55,
			wide = FLAT,
			h0 = 21,
			h1 = 21.6,
			color = STAR,
			mat = "Neon",
			alpha = 0.4,
		})
		local pb = b + 15
		radial({
			id = "pilaster" .. i,
			kind = "wall",
			b = pb,
			r0 = 56.9,
			r1 = 59.9,
			wide = 3,
			h0 = 0,
			h1 = 27,
			color = rgb(70, 62, 84),
			mat = "Slate",
		})
		local sx, sz = K.around(pb, 58.4)
		K.ball({
			id = "pilaster" .. i .. "/star",
			kind = "star",
			set = "decor",
			x = sx,
			z = sz,
			dia = 1.4,
			h = 27.7,
			color = STAR,
			mat = "Neon",
		})
	end

	-- Crystal groves: 5 crystals in a 6 x 6 x 4 patch under each star chain ----------
	local shards = {
		{ 0, 0, 1.4, 4 },
		{ -1.8, 1.2, 1, 2.8 },
		{ 1.6, 1.6, 1, 2.2 },
		{ 1.4, -1.8, 1.1, 3.2 },
		{ -1.6, -1.6, 0.9, 1.8 },
	}
	for i = 1, 4 do
		local b = 45 + (i - 1) * 90
		local gx, gz = K.around(b, 20)
		for j, c in shards do
			local x, z = K.toWorld(gx, gz, -b, c[1], c[2])
			K.box({
				id = "grove" .. i .. "/" .. j,
				kind = "crystal",
				x = x,
				z = z,
				w = c[3],
				d = c[3],
				h0 = 0,
				h1 = c[4],
				yaw = -b + j * 23,
				color = if j % 2 == 0 then rgb(120, 200, 255) else rgb(170, 130, 255),
				mat = "Glass",
				alpha = 0.15,
				refl = 0.3,
				lean = if j == 1 then nil else { c[2] * 5, 0, -c[1] * 5 },
				light = if j == 1 then { color = rgb(150, 150, 255), range = 24, bright = 1.4 } else nil,
			})
		end
	end

	-- Braziers at r 38 --------------------------------------------------------------
	for i, b in { 15, 105, 195 } do
		local x, z = K.around(b, 38)
		K.cyl({
			id = "brazier" .. i,
			kind = "brazier",
			x = x,
			z = z,
			w = 1,
			h0 = 0,
			h1 = 2.2,
			color = rgb(60, 54, 70),
			mat = "Slate",
		})
		K.cyl({
			id = "brazier" .. i .. "/bowl",
			kind = "brazier",
			set = "decor",
			x = x,
			z = z,
			w = 1.8,
			h0 = 2.2,
			h1 = 2.8,
			color = BRONZE,
			mat = "Metal",
			fire = true,
			light = { color = EMBER, range = 28, bright = 1.5 },
		})
	end

	-- Sarcophagi: 8 pairs on bearings 22.5 + 45k --------------------------------------
	for i = 1, 8 do
		local b = 22.5 + (i - 1) * 45
		-- the two north pairs would stand on the dais steps at r 30, so they sit at r 39
		local r = if b == 247.5 or b == 292.5 then 39 else 29.2
		local px, pz = K.around(b, r)
		for j, s in { -1, 1 } do
			local x, z = K.toWorld(px, pz, -b, 0, s * 1.7)
			local id = "sarc" .. i .. "/" .. j
			K.box({
				id = id,
				kind = "sarcophagus",
				x = x,
				z = z,
				w = 6,
				d = 2.6,
				h0 = 0,
				h1 = 2.2,
				yaw = -b,
				color = rgb(112, 104, 124),
				mat = "Limestone",
			})
			K.box({
				id = id .. "/lid",
				kind = "lid",
				set = "decor",
				x = x,
				z = z,
				w = 6.3,
				d = 2.9,
				h0 = 2.2,
				h1 = 2.5,
				yaw = -b,
				color = rgb(84, 76, 98),
				mat = "Slate",
			})
		end
	end
end
