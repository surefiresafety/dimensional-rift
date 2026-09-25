--!strict
-- The Seam: "The Stitchyard" (the finale), midnight. Design: docs/design/worlds.md §3.10.
-- A basalt Hem round the rift, nine patches of the other worlds stitched
-- together round it, each with a small vignette and its anchor, the Thread
-- Walk (rope bridges between four vignettes) behind the spawn, fragments and
-- stitched pillars beyond, and the Spindle, a giant needle, to the north.

return function(K: any)
	local rgb = K.rgb
	local CRIMSON = rgb(220, 30, 70)
	local BASALT = rgb(40, 36, 44)
	local COPPER = rgb(184, 115, 51)
	K.budget(280, 18)
	K.r0(26)
	K.ground("Basalt", BASALT)
	K.hero(0, -60, 70, { "spindle" })

	--- A point in a vignette's frame: r out along bearing b, t across it (toward b + 90).
	local function at(b: number, r: number, t: number): (number, number)
		return K.toWorld(0, 0, -b, r, t)
	end

	-- Pads (12, 3 boss): r 28 on bearing θ + 11, bosses at r 44 for θ = 0, 280, 320
	for _, p in
		{
			{ 27.5, 5.3 },
			{ 17.6, 21.8 },
			{ -0.5, 28.0 },
			{ -18.4, 21.1 },
			{ -27.7, 4.4 },
			{ -24.0, -14.4 },
			{ -9.1, -26.5 },
			{ 10.0, -26.1 },
			{ 24.5, -13.6 },
		}
	do
		K.pad(p[1], p[2])
	end
	for _, p in { { 43.2, 8.4 }, { 15.8, -41.1 }, { 38.5, -21.3 } } do
		K.pad(p[1], p[2], 0, true)
	end

	-- The Hem: basalt to r 18 (the ground), a crimson inlay, and 6 floating shards --
	K.inlay({ id = "hem", r = 18, color = CRIMSON, fill = BASALT, fillMat = "Basalt" })
	for i = 0, 5 do
		local b = i * 60
		local x, z = K.around(b, 15)
		K.box({
			id = "shard" .. i + 1,
			kind = "shard",
			set = "core",
			x = x,
			z = z,
			w = 6,
			d = 6,
			h0 = 24,
			h1 = 30,
			yaw = -b,
			color = BASALT,
			mat = "Basalt",
		})
		K.box({
			id = "shard" .. i + 1 .. "/seam",
			kind = "glow",
			set = "decor",
			x = x,
			z = z,
			w = 6.1,
			d = 0.3,
			h0 = 24,
			h1 = 30,
			yaw = -b + 35,
			color = CRIMSON,
			mat = "Neon",
		})
		local tx, tz = K.around(b, 18)
		K.beam({ a = { x, z, 24 }, b = { tx, tz, 0.05 }, color = CRIMSON, width = 0.3, emission = 1 })
	end

	-- Nine Patches (terrain) and the crimson seams between them ----------------
	local patches = {
		{ mat = "Asphalt", color = rgb(52, 50, 58) }, -- 0 City
		{ mat = "Grass", color = rgb(74, 104, 60) }, -- 40 Academy
		{ mat = "Concrete", color = rgb(118, 114, 108) }, -- 80 Colony
		{ mat = "Sand", color = rgb(196, 164, 112) }, -- 120 Wind
		{ mat = "Rock", color = rgb(112, 98, 86) }, -- 160 Earth
		{ mat = "Ground", color = rgb(84, 72, 60) }, -- 200 Water
		{ mat = "Cobblestone", color = rgb(110, 106, 100) }, -- 240 Kyoto
		{ mat = "Snow", color = rgb(210, 216, 226) }, -- 280 Lightning
		{ mat = "Slate", color = rgb(64, 60, 84) }, -- 320 Star Vault
	}
	for i, p in patches do
		local theta = (i - 1) * 40
		for _, db in { -13.33, 0, 13.33 } do
			local b = theta + db
			local x, z = K.around(b, 36)
			K.terrain({
				op = "block",
				x = x,
				z = z,
				w = 32,
				d = 12.2,
				h0 = -1.6,
				h1 = 0,
				yaw = -b,
				material = p.mat,
				color = p.color,
			})
		end
		local sb = theta + 20
		local sx, sz = K.around(sb, 36)
		K.box({
			id = "seam" .. i,
			kind = "paint",
			set = "decor",
			x = sx,
			z = sz,
			w = 32,
			d = 0.5,
			h0 = 0,
			h1 = 0.06,
			yaw = -sb,
			color = CRIMSON,
			mat = "Neon",
		})
	end

	-- Vignettes: each sits on bearing β = θ - 9, anchor at r 42 -----------------

	-- 0 City: crosswalk, car, lamp, pylon 20 with crossarms
	do
		local b = 351
		for i, t in { -2.25, -0.75, 0.75, 2.25 } do
			local x, z = at(b, 38, t)
			K.box({
				id = "city/crosswalk" .. i,
				kind = "paint",
				set = "decor",
				x = x,
				z = z,
				w = 6.5,
				d = 0.8,
				h0 = 0,
				h1 = 0.05,
				yaw = -b,
				color = rgb(220, 220, 214),
				mat = "SmoothPlastic",
			})
		end
		local cx, cz = at(b, 46, 0)
		K.car({ id = "city/car", x = cx, z = cz, yaw = -(b + 90) })
		local lx, lz = at(b, 36, -2.8)
		K.lamp({ id = "city/lamp", x = lx, z = lz, lit = true })
		local px, pz = at(b, 42, 0)
		K.mast({ id = "city/pylon", x = px, z = pz, h = 20, w = 1.6, color = rgb(60, 64, 70) })
		local sx, sz = at(b, 41, 0)
		K.box({
			id = "city/pylon/sign",
			kind = "sign",
			set = "decor",
			x = sx,
			z = sz,
			w = 0.3,
			d = 5,
			h0 = 13,
			h1 = 16.5,
			yaw = -b,
			color = rgb(14, 14, 20),
			text = { text = "NOODLE BAR 88", face = "Left", color = rgb(255, 213, 74) },
			light = { color = rgb(255, 213, 74), range = 30, bright = 2 },
		})
	end

	-- 40 Academy: torii, stone lantern, cedar (core 28.5)
	do
		local b = 31
		local tx, tz = at(b, 37, 0)
		K.torii({ id = "academy/torii", x = tx, z = tz, yaw = -(b + 90) })
		local lx, lz = at(b, 46, 2.5)
		K.stoneLantern({ id = "academy/lantern", x = lx, z = lz, yaw = -b })
		local cx, cz = at(b, 42, 0)
		K.tree({ id = "academy/cedar", x = cx, z = cz, h = 30, kind = "cedar" })
	end

	-- 80 Colony: gantry 20 whose beam runs out over a 2-high container stack; ramp to 5.2
	-- (the Thread Walk's start is on the stack top)
	do
		local b = 71
		for i, r in { 38, 49 } do
			local x, z = at(b, r, 0)
			K.box({
				id = "colony/gantry/leg" .. i,
				kind = "mast",
				x = x,
				z = z,
				w = 5,
				d = 5,
				h0 = 0,
				h1 = 20,
				yaw = -b,
				color = rgb(200, 150, 40),
				mat = "DiamondPlate",
				anchor = true,
			})
		end
		local gx, gz = at(b, 43.5, 0)
		K.box({
			id = "colony/gantry",
			kind = "beam",
			x = gx,
			z = gz,
			w = 16,
			d = 2,
			h0 = 18.5,
			h1 = 20,
			yaw = -b,
			color = rgb(200, 150, 40),
			mat = "DiamondPlate",
		})
		local cx, cz = at(b, 43.5, 0)
		K.container({ id = "colony/container1", x = cx, z = cz, yaw = -(b + 90), color = rgb(170, 70, 50) })
		K.container({ id = "colony/container2", x = cx, z = cz, h0 = 2.6, yaw = -(b + 90), color = rgb(60, 110, 150) })
		local fx, fz = at(b, 43.5, -3 - 9.1)
		K.ramp({
			id = "colony/ramp",
			x = fx,
			z = fz,
			run = b + 90,
			w = 4,
			rise = 5.2,
			color = rgb(96, 100, 108),
			mat = "DiamondPlate",
		})
	end

	-- 120 Wind: house (roof 6) with a ramp and landing, windcatcher 20 on the roof
	do
		local b = 111
		local hx, hz = at(b, 43.5, 0)
		K.house({ id = "wind/house", x = hx, z = hz, h = 6, size = 7, yaw = -b, rails = { "w" }, clutter = false })
		local wx, wz = at(b, 41.75, 0)
		K.windcatcher({ id = "wind/windcatcher", x = wx, z = wz, w = 3.5, h0 = 6, top = 20, yaw = -b })
		local fx, fz = at(b, 49, -3.5 - 10.5)
		K.ramp({
			id = "wind/ramp",
			x = fx,
			z = fz,
			run = b + 90,
			w = 4,
			rise = 6,
			landing = true,
			color = rgb(196, 150, 100),
			mat = "Sandstone",
		})
	end

	-- 160 Earth: rock stack 20, a ledge at 8 on its outer face, switchback up to it
	do
		local b = 151
		local rx, rz = at(b, 42, 0)
		K.box({
			id = "earth/stack",
			kind = "rock",
			x = rx,
			z = rz,
			w = 7,
			d = 7,
			h0 = 0,
			h1 = 20,
			yaw = -b,
			color = rgb(112, 98, 86),
			mat = "Rock",
			anchor = true,
		})
		local lx, lz = at(b, 47.5, 1.65)
		K.box({
			id = "earth/ledge",
			kind = "wall",
			x = lx,
			z = lz,
			w = 4,
			d = 10.3,
			h0 = 0,
			h1 = 8,
			yaw = -b,
			color = rgb(128, 112, 96),
			mat = "Rock",
		})
		local sx, sz = at(b, 49.5, 3.8)
		K.switchback({
			id = "earth/stair",
			x = sx,
			z = sz,
			dir = b,
			w = 3,
			rise = 8,
			side = -1,
			color = rgb(128, 112, 96),
			mat = "Slate",
		})
		local cx, cz = at(b, 38, -2)
		K.box({
			id = "earth/cairn",
			kind = "rock",
			set = "decor",
			x = cx,
			z = cz,
			w = 1.6,
			d = 1.4,
			h0 = 0,
			h1 = 1.2,
			yaw = -b + 20,
			color = rgb(96, 84, 74),
			mat = "Rock",
		})
	end

	-- 200 Water: stilt deck at 5 with a ramp, hut, mast 22 with yardarms (Thread Walk end)
	do
		local b = 191
		local dx, dz = at(b, 46.25, 0)
		K.deck({ id = "water/deck", x = dx, z = dz, w = 6.5, d = 7, h = 5, yaw = -b, posts = 4 })
		local fx, fz = at(b, 47, 3.5 + 8.75)
		K.ramp({
			id = "water/ramp",
			x = fx,
			z = fz,
			run = b - 90,
			w = 4,
			rise = 5,
			color = rgb(120, 92, 64),
			mat = "WoodPlanks",
		})
		local mx, mz = at(b, 42, 0)
		K.mast({ id = "water/mast", x = mx, z = mz, h = 22, w = 1.6, color = rgb(96, 72, 52), mat = "Wood" })
		local hx, hz = at(b, 37, -1)
		K.box({
			id = "water/hut",
			kind = "wall",
			x = hx,
			z = hz,
			w = 4.5,
			d = 4.5,
			h0 = 0,
			h1 = 3.5,
			yaw = -b,
			color = rgb(150, 124, 90),
			mat = "WoodPlanks",
		})
		K.box({
			id = "water/hut/roof",
			kind = "roof",
			x = hx,
			z = hz,
			w = 5.5,
			d = 5.5,
			h0 = 3.5,
			h1 = 4.1,
			yaw = -b,
			color = rgb(60, 80, 100),
			mat = "Slate",
		})
		local ox, oz = at(b, 34.7, -1)
		K.box({
			id = "water/hut/door",
			kind = "door",
			set = "decor",
			x = ox,
			z = oz,
			w = 0.1,
			d = 1.6,
			h0 = 0,
			h1 = 2.6,
			yaw = -b,
			color = rgb(255, 196, 120),
			mat = "Neon",
			light = { color = rgb(255, 190, 120), range = 20, bright = 1 },
		})
		local nx, nz = at(b, 49.4, 0)
		K.box({
			id = "water/net",
			kind = "net",
			set = "decor",
			x = nx,
			z = nz,
			w = 0.1,
			d = 5,
			h0 = 1,
			h1 = 4.4,
			yaw = -b,
			color = rgb(170, 150, 110),
			mat = "Fabric",
			alpha = 0.4,
		})
	end

	-- 240 Kyoto: a 3-torii tunnel toward the pagoda tiers (16) on an 8 x 8 base
	do
		local b = 231
		for i, r in { 34.9, 36.5, 38 } do
			local x, z = at(b, r, 0)
			K.torii({ id = "kyoto/torii" .. i, x = x, z = z, yaw = -(b + 90) })
		end
		local px, pz = at(b, 42.5, 0)
		local tiers = {
			{ id = "kyoto/pagoda", w = 8, h0 = 0, h1 = 12, color = rgb(150, 60, 44), mat = "WoodPlanks" },
			{ id = "kyoto/pagoda/eave", w = 8.6, h0 = 12, h1 = 12.8, color = rgb(58, 62, 70), mat = "Slate" },
			{ id = "kyoto/pagoda/upper", w = 5.5, h0 = 12.8, h1 = 15.2, color = rgb(150, 60, 44), mat = "WoodPlanks" },
			{ id = "kyoto/pagoda/cap", w = 6.5, h0 = 15.2, h1 = 16, color = rgb(58, 62, 70), mat = "Slate" },
		}
		for _, t in tiers do
			K.box({
				id = t.id,
				kind = "tower",
				x = px,
				z = pz,
				w = t.w,
				d = t.w,
				h0 = t.h0,
				h1 = t.h1,
				yaw = -b,
				color = t.color,
				mat = t.mat,
				anchor = if t.id == "kyoto/pagoda" then true else nil, -- the 8 x 8 base
			})
		end
	end

	-- 280 Lightning: rod tower 26 with copper crossarms, rock horn 24 at bearing 266
	do
		local b = 271
		local x, z = at(b, 42, 0)
		K.box({
			id = "storm/rodtower",
			kind = "tower",
			x = x,
			z = z,
			w = 5,
			d = 5,
			h0 = 0,
			h1 = 26,
			yaw = -b,
			color = rgb(92, 94, 100),
			mat = "Slate",
			anchor = true,
		})
		K.crossarms({ id = "storm/rodtower", x = x, z = z, top = 26, len = 9, color = COPPER })
		K.box({
			id = "storm/rodtower/rod",
			kind = "mast",
			set = "decor",
			x = x,
			z = z,
			w = 0.5,
			d = 0.5,
			h0 = 26,
			h1 = 28.4,
			color = COPPER,
			mat = "Metal",
		})
		K.ball({
			id = "storm/rodtower/tip",
			kind = "tip",
			set = "decor",
			x = x,
			z = z,
			dia = 1.1,
			h = 28.8,
			color = rgb(150, 200, 255),
			mat = "Neon",
			light = { color = rgb(150, 200, 255), range = 36, bright = 1.4 },
		})
		local hx, hz = K.around(266, 44)
		K.box({
			id = "storm/horn",
			kind = "rock",
			x = hx,
			z = hz,
			w = 6,
			d = 6,
			h0 = 0,
			h1 = 24,
			yaw = -266,
			color = rgb(70, 66, 74),
			mat = "Basalt",
			anchor = true,
		})
	end

	-- 320 Star Vault: 2 star pillars 24 and a crystal bed
	do
		for i, p in { { 311, 42 }, { 314, 48 } } do
			local x, z = K.around(p[1], p[2])
			K.box({
				id = "vault/pillar" .. i,
				kind = "tower",
				x = x,
				z = z,
				w = 6,
				d = 6,
				h0 = 0,
				h1 = 24,
				yaw = -p[1],
				color = rgb(46, 42, 58),
				mat = "Slate",
				anchor = true,
			})
			K.box({
				id = "vault/pillar" .. i .. "/star",
				kind = "glow",
				set = "decor",
				x = x,
				z = z,
				w = 1.4,
				d = 1.4,
				h0 = 24,
				h1 = 25.4,
				yaw = -p[1] + 45,
				color = rgb(150, 140, 220),
				mat = "Neon",
			})
		end
		local b = 311
		for i, c in
			{
				{ 36, -2.2, 1.0, 2.6, 12 },
				{ 36.8, 1.6, 0.8, 1.8, -10 },
				{ 38.2, -0.4, 1.2, 3.0, 6 },
				{ 35.2, 0.6, 0.7, 1.4, -18 },
				{ 38.6, 2.6, 0.9, 2.2, 15 },
				{ 39.4, -2.8, 0.8, 1.6, -8 },
			}
		do
			local x, z = at(b, c[1], c[2])
			K.box({
				id = "vault/crystal" .. i,
				kind = "crystal",
				x = x,
				z = z,
				w = c[3],
				d = c[3],
				h0 = 0,
				h1 = c[4],
				yaw = -b + i * 25,
				color = rgb(150, 140, 220),
				mat = "Glass",
				alpha = 0.2,
				lean = { c[5], 0, c[5] * 0.6 },
			})
		end
		for i, c in { { 37, 0.2 }, { 35.6, -1.4 }, { 39, 1 } } do
			local x, z = at(b, c[1], c[2])
			K.box({
				id = "vault/glow" .. i,
				kind = "glow",
				set = "decor",
				x = x,
				z = z,
				w = 0.4,
				d = 0.4,
				h0 = 0,
				h1 = 1.2,
				yaw = -b,
				color = rgb(190, 180, 255),
				mat = "Neon",
				light = if i == 1 then { color = rgb(150, 140, 220), range = 24, bright = 1.2 } else nil,
			})
		end
	end

	-- The Thread Walk (behind the spawn): container 5.2 -> roof 6 -> ledge 8 -> deck 5 --
	-- Each platform carries a walk across it; rope bridges join them.
	local plats = {
		{ b = 71, r = 43.5, h = 5.2, t0 = -3, t1 = 2 },
		{ b = 111, r = 45, h = 6, t0 = -2.3, t1 = 2.3 },
		{ b = 151, r = 47.5, h = 8, t0 = -2.3, t1 = 5.6 },
		{ b = 191, r = 47, h = 5, t0 = -2.3, t1 = 3.5 },
	}
	for i, p in plats do
		local ax, az = at(p.b, p.r, p.t0)
		local bx, bz = at(p.b, p.r, p.t1)
		K.walk("thread/p" .. i, { ax, az, p.h }, { bx, bz, p.h }, 2.5)
		local q = plats[i + 1]
		if q then
			local cx, cz = at(q.b, q.r, q.t0)
			K.bridge({
				id = "thread/bridge" .. i,
				a = { bx, bz, p.h },
				b = { cx, cz, q.h },
				style = "rope",
				walk = true,
				railColor = CRIMSON,
			})
		end
	end

	-- Beyond: fragments, stitched pillars, sky threads --------------------------
	local fragMats = {
		{ mat = "Asphalt", color = rgb(52, 50, 58), topMat = "Grass", top = rgb(74, 104, 60) },
		{ mat = "Sandstone", color = rgb(196, 164, 112), topMat = "Sand", top = rgb(206, 176, 122) },
		{ mat = "WoodPlanks", color = rgb(120, 92, 64), topMat = "Ground", top = rgb(84, 72, 60) },
		{ mat = "Slate", color = rgb(92, 94, 100), topMat = "Snow", top = rgb(210, 216, 226) },
		{ mat = "Brick", color = rgb(92, 70, 64), topMat = "Concrete", top = rgb(118, 114, 108) },
		{ mat = "Slate", color = rgb(64, 60, 84), topMat = "Neon", top = rgb(150, 140, 220) },
	}
	-- A collidable fragment: one 6 x h x 6 column of torn ground, a patch of another
	-- world on top, a broken shelf and a crimson seam (decor, lit).
	for i, b in { 20, 110, 200, 290 } do
		local m = fragMats[i]
		local h = ({ 26, 30, 34, 28 })[i]
		local x, z = K.around(b, 64)
		local id = "fragment" .. i
		K.box({
			id = id,
			kind = "fragment",
			x = x,
			z = z,
			w = 6,
			d = 6,
			h0 = 0,
			h1 = h,
			yaw = -b,
			color = m.color,
			mat = m.mat,
			anchor = true,
			backdrop = true,
		})
		K.box({
			id = id .. "/top",
			kind = "fragment",
			set = "decor",
			x = x,
			z = z,
			w = 6.6,
			d = 6.6,
			h0 = h,
			h1 = h + 0.6,
			yaw = -b,
			color = m.top,
			mat = m.topMat,
			backdrop = true,
			lean = { 4, 0, -3 },
		})
		local sx, sz = K.around(b, 60.4)
		K.box({
			id = id .. "/shelf",
			kind = "fragment",
			set = "decor",
			x = sx,
			z = sz,
			w = 2.4,
			d = 4.4,
			h0 = h - 6,
			h1 = h - 4.6,
			yaw = -b,
			color = m.color,
			mat = m.mat,
			backdrop = true,
			lean = { 0, 0, -12 },
		})
		K.box({
			id = id .. "/crack",
			kind = "fragment",
			set = "decor",
			x = x,
			z = z,
			w = 6.2,
			d = 0.25,
			h0 = h - 9,
			h1 = h - 1,
			yaw = -b + 60,
			color = rgb(24, 20, 26),
			mat = "Basalt",
			backdrop = true,
		})
		K.box({
			id = id .. "/seam",
			kind = "glow",
			set = "decor",
			x = x,
			z = z,
			w = 6.2,
			d = 0.3,
			h0 = 1,
			h1 = h - 1,
			yaw = -b + 30,
			color = CRIMSON,
			mat = "Neon",
			backdrop = true,
			light = { color = CRIMSON, range = 30, bright = 1.2 },
		})
	end

	-- 8 decor fragments drifting at r 70-90: a torn block, its patch, its underside
	for i, f in
		{
			{ 50, 78, 34 },
			{ 80, 88, 48 },
			{ 140, 72, 40 },
			{ 170, 84, 30 },
			{ 230, 80, 44 },
			{ 250, 70, 36 },
			{ 320, 86, 50 },
			{ 350, 74, 38 },
		}
	do
		local m = fragMats[(i + 2) % #fragMats + 1]
		local x, z = K.around(f[1], f[2])
		local h0, h1 = f[3], f[3] + 5 + (i % 3) * 2
		local id = "drift" .. i
		local tip = { (i % 3 - 1) * 7, 0, (i % 2) * 10 - 5 }
		for _, p in
			{
				{ id = "", w = 7, h0 = h0, h1 = h1, color = m.color, mat = m.mat, turn = 0 },
				{ id = "/top", w = 7.4, h0 = h1, h1 = h1 + 0.6, color = m.top, mat = m.topMat, turn = 0 },
				{ id = "/under", w = 4.9, h0 = h0 - 3, h1 = h0, color = rgb(70, 58, 50), mat = "Rock", turn = 15 },
				{ id = "/root", w = 2.4, h0 = h0 - 5.5, h1 = h0 - 3, color = rgb(56, 46, 40), mat = "Rock", turn = 40 },
			}
		do
			K.box({
				id = id .. p.id,
				kind = "fragment",
				set = "decor",
				x = x,
				z = z,
				w = p.w,
				d = p.w,
				h0 = p.h0,
				h1 = p.h1,
				yaw = -f[1] + p.turn,
				color = p.color,
				mat = p.mat,
				backdrop = true,
				lean = tip,
			})
		end
		K.box({
			id = id .. "/seam",
			kind = "glow",
			set = "decor",
			x = x,
			z = z,
			w = 7.2,
			d = 0.3,
			h0 = h0 + 0.5,
			h1 = h1 - 0.5,
			yaw = -f[1] + 30,
			color = CRIMSON,
			mat = "Neon",
			backdrop = true,
			lean = tip,
		})
	end

	-- 9 stitched pillars 3 x 3 x 30 (the one on 270 gives way to the Spindle)
	for i, p in
		{
			{ b = 0, r = 56 },
			{ b = 30, r = 56, lit = true },
			{ b = 40, r = 56 },
			{ b = 90, r = 56 },
			{ b = 150, r = 55.5, lit = true },
			{ b = 170, r = 56 },
			{ b = 210, r = 56, lit = true },
			{ b = 330, r = 57.5 },
			{ b = 240, r = 60 },
		}
	do
		local b, r = p.b, p.r
		local x, z = K.around(b, r)
		K.box({
			id = "pillar" .. i,
			kind = "pillar",
			x = x,
			z = z,
			w = 3,
			d = 3,
			h0 = 0,
			h1 = 30,
			yaw = -b,
			color = rgb(52, 46, 58),
			mat = "Basalt",
			backdrop = true,
		})
		local sx, sz = K.around(b, r - 1.55)
		K.box({
			id = "pillar" .. i .. "/stitch",
			kind = "glow",
			set = "decor",
			x = sx,
			z = sz,
			w = 0.1,
			d = 0.6,
			h0 = 2,
			h1 = 28,
			yaw = -b,
			color = CRIMSON,
			mat = "Neon",
			backdrop = true,
			light = if p.lit then { color = CRIMSON, range = 28, bright = 1.2 } else nil,
		})
	end

	-- 18 sky threads (decor): long crimson strands high over the Stitchyard
	for i = 1, 18 do
		local b = (i - 1) * 20 + 7
		local r = 95 + (i % 3) * 15
		local x, z = K.around(b, r)
		K.box({
			id = "skythread" .. i,
			kind = "thread",
			set = "decor",
			x = x,
			z = z,
			w = 70,
			d = 0.35,
			h0 = 78 + (i % 4) * 9,
			h1 = 78.35 + (i % 4) * 9,
			yaw = -b + 70,
			color = CRIMSON,
			mat = "Neon",
			alpha = 0.35,
			backdrop = true,
			lean = { 0, 0, if i % 2 == 0 then 14 else -14 },
		})
	end

	-- The Spindle (hero): a needle through a thimble on a spool of crimson thread --
	local NEEDLE = rgb(196, 200, 210)
	K.cyl({
		id = "spindle/plinth",
		kind = "plinth",
		x = 0,
		z = -60,
		w = 14,
		h0 = 0,
		h1 = 2,
		color = BASALT,
		mat = "Basalt",
	})
	K.cyl({
		id = "spindle/spool",
		kind = "spool",
		x = 0,
		z = -60,
		w = 8,
		h0 = 2,
		h1 = 12,
		color = rgb(120, 20, 44),
		mat = "Fabric",
	})
	for i, h in { 2, 11 } do
		K.cyl({
			id = "spindle/flange" .. i,
			kind = "spool",
			x = 0,
			z = -60,
			w = 12,
			h0 = h,
			h1 = h + 1,
			color = rgb(120, 84, 52),
			mat = "Wood",
		})
	end
	K.box({
		id = "spindle",
		kind = "needle",
		x = 0,
		z = -60,
		w = 2.4,
		d = 2.4,
		h0 = 12,
		h1 = 60,
		color = NEEDLE,
		mat = "Metal",
		refl = 0.2,
	})
	for i, s in { -1, 1 } do
		K.box({
			id = "spindle/eye" .. i,
			kind = "needle",
			x = s * 0.8,
			z = -60,
			w = 0.8,
			d = 2.4,
			h0 = 60,
			h1 = 66,
			color = NEEDLE,
			mat = "Metal",
			refl = 0.2,
		})
	end
	K.box({
		id = "spindle/crown",
		kind = "needle",
		x = 0,
		z = -60,
		w = 2.4,
		d = 2.4,
		h0 = 66,
		h1 = 68,
		color = NEEDLE,
		mat = "Metal",
		refl = 0.2,
		light = { color = CRIMSON, range = 40, bright = 2 },
	})
	-- the tip: two wedges meeting in a ridge along x
	for i, t in { { -60.6, 90 }, { -59.4, 270 } } do
		K.wedge({
			id = "spindle/tip" .. i,
			kind = "needle",
			x = 0,
			z = t[1],
			w = 1.2,
			d = 2.4,
			h0 = 68,
			h1 = 70,
			run = t[2],
			color = NEEDLE,
			mat = "Metal",
			refl = 0.2,
		})
	end
	K.cyl({
		id = "spindle/thimble",
		kind = "thimble",
		x = 0,
		z = -60,
		w = 6,
		h0 = 40,
		h1 = 43,
		color = rgb(181, 140, 60),
		mat = "Metal",
	})
	-- Thread 1: from under the eye crown, through the slot, down to the top of the spool.
	K.beam({ a = { 0, -60, 65.8 }, b = { 2.6, -60, 12.05 }, color = CRIMSON, width = 0.5, emission = 1 })
	-- Thread 2: from the eye, swooping down into the rift (the portal ring's top, h 17).
	K.beam({
		a = { 0, -60, 63 },
		b = { 0, 0, 17 },
		color = CRIMSON,
		width = 0.5,
		emission = 1,
		curve0 = 30,
		curve1 = -10,
	})
	K.highlight("spindle", CRIMSON)
	K.emitter("spindle/spool", {
		Rate = 6,
		Lifetime = 4,
		Speed = 2,
		Color = CRIMSON,
		LightEmission = 1,
	})
end
