--!nocheck
-- Dresses every enemy id (Finale ids excepted) with the real Kit + Creatures code on real Roblox
-- instances (Lune), in every role: normal, alpha, charBoss, elite with each affix, stitched with
-- each affix. Checks §6.3 caps, every W/R entry mounted (test 3), scaling (test 12), piece flags,
-- the face zone for human enemies and the grey (test 10), the ward and Kit.ally.
--   lune run tests/creatures   (from the roblox folder; builds build/kit-test.rbxl with rojo)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")

local Instance, Vector3, CFrame, Color3, Enum =
	roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

-- the place ----------------------------------------------------------------------------------
local placeFile = "build/kit-test.rbxl"
do
	local home = process.env.HOME or ""
	local ok = false
	for _, rojo in { home .. "/bin/rojo", "rojo" } do
		local r = select(2, pcall(process.exec, rojo, { "build", "default.project.json", "-o", placeFile }))
		if type(r) == "table" and r.ok then
			ok = true
			break
		end
	end
	if not ok then
		placeFile = "build/DimensionalRift.rbxl"
		print("WARN rojo build failed; using " .. placeFile)
	end
end
local place = roblox.deserializePlace(fs.readFile(placeFile))
local Shared = place:GetService("ReplicatedStorage"):FindFirstChild("Shared")

local services = {
	CollectionService = {
		AddTag = function(_, inst, tag)
			inst:AddTag(tag)
		end,
	},
}
local fakeGame = {
	GetService = function(_, n)
		return services[n] or error("no service " .. n)
	end,
}
-- Lune instances have no WaitForChild: modules see their instances through this proxy.
local unwrap = setmetatable({}, { __mode = "k" })
local function wrap(inst)
	if typeof(inst) ~= "Instance" then
		return inst
	end
	local proxy = setmetatable({}, {
		__index = function(_, k)
			if k == "WaitForChild" or k == "FindFirstChild" then
				return function(_, n)
					return wrap(inst:FindFirstChild(n))
				end
			elseif k == "Parent" then
				return wrap(inst.Parent)
			end
			local v = inst[k]
			if type(v) == "function" then
				return function(_, ...)
					return v(inst, ...)
				end
			end
			if typeof(v) == "Instance" then
				return wrap(v)
			end
			return v
		end,
	})
	unwrap[proxy] = inst
	return proxy
end
services.ReplicatedStorage = wrap(place:GetService("ReplicatedStorage"))

local cache = {}
local function load(mod)
	mod = unwrap[mod] or mod
	if cache[mod] ~= nil then
		return cache[mod]
	end
	local env = setmetatable({
		script = wrap(mod),
		game = fakeGame,
		require = function(m)
			return load(m)
		end,
		Instance = Instance,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Vector2 = roblox.Vector2,
		ColorSequence = roblox.ColorSequence,
		NumberSequence = roblox.NumberSequence,
		NumberRange = roblox.NumberRange,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		warn = function(...)
			print("WARN", ...)
		end,
	}, { __index = _G })
	local fn = luau.load(mod.Source, { debugName = mod:GetFullName(), environment = env })
	local r = fn()
	cache[mod] = r
	return r
end

local Kit = load(place:GetService("ServerScriptService").Server.Kit)
local Creatures = load(place:GetService("ServerScriptService").Server.Kit.Creatures)

local costumesOk, Costumes = false, nil
do
	local m = Shared:FindFirstChild("Costumes")
	if m and m:IsA("ModuleScript") then
		costumesOk, Costumes = pcall(load, m)
		if not costumesOk then
			print("NOTE Costumes did not load (" .. tostring(Costumes) .. "); reading Styles directly")
			Costumes = nil
		end
	end
end

-- a dummy R15 rig ---------------------------------------------------------------------------
local LAYOUT = { -- name, nominal size, world centre at scale 1
	{ "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0.2, 0) },
	{ "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 0, 0) },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 1.0, 0) },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2.3, 0) },
	{ "LeftUpperArm", Vector3.new(1, 1.17, 1), Vector3.new(-1.5, 1.2, 0) },
	{ "LeftLowerArm", Vector3.new(1, 1.05, 1), Vector3.new(-1.5, 0.1, 0) },
	{ "LeftHand", Vector3.new(1, 0.3, 1), Vector3.new(-1.5, -0.6, 0) },
	{ "RightUpperArm", Vector3.new(1, 1.17, 1), Vector3.new(1.5, 1.2, 0) },
	{ "RightLowerArm", Vector3.new(1, 1.05, 1), Vector3.new(1.5, 0.1, 0) },
	{ "RightHand", Vector3.new(1, 0.3, 1), Vector3.new(1.5, -0.6, 0) },
	{ "LeftUpperLeg", Vector3.new(1, 1.22, 1), Vector3.new(-0.5, -0.81, 0) },
	{ "LeftLowerLeg", Vector3.new(1, 1.19, 1), Vector3.new(-0.5, -2.0, 0) },
	{ "LeftFoot", Vector3.new(1, 0.3, 1), Vector3.new(-0.5, -2.75, 0) },
	{ "RightUpperLeg", Vector3.new(1, 1.22, 1), Vector3.new(0.5, -0.81, 0) },
	{ "RightLowerLeg", Vector3.new(1, 1.19, 1), Vector3.new(0.5, -2.0, 0) },
	{ "RightFoot", Vector3.new(1, 0.3, 1), Vector3.new(0.5, -2.75, 0) },
}

local function dummy(scale)
	scale = scale or Vector3.one
	local model = Instance.new("Model")
	model.Name = "Dummy"
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 2 * scale.Y
	hum.Parent = model
	for _, row in LAYOUT do
		local p = Instance.new("Part")
		p.Name = row[1]
		p.Size = row[2] * scale
		p.CFrame = CFrame.new(row[3] * scale)
		p.Anchored = true
		p.Transparency = if row[1] == "HumanoidRootPart" then 1 else 0
		p.Parent = model
	end
	for name, a in Kit.ATTACH do
		local host = model:FindFirstChild(a.host)
		local att = Instance.new("Attachment")
		att.Name = name
		att.CFrame = CFrame.new(a.pos * scale)
		att.Parent = host
	end
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Parent = model.Head
	return model
end

-- checks ------------------------------------------------------------------------------------
local failures, passes = 0, 0
local function check(ok, msg)
	if ok then
		passes += 1
	else
		failures += 1
		print("  FAIL " .. msg)
	end
end

local EXEMPT = { FP = true, VB = true, ["VB·m"] = true, GG = true, FM = true, BK = true, ["GR·e"] = true }
local ZONE = { x0 = -0.33, x1 = 0.33, y0 = 0.06, y1 = 0.24, z0 = -20, z1 = -0.60 }

local function inZone(p)
	return p.X >= ZONE.x0 and p.X <= ZONE.x1 and p.Y >= ZONE.y0 and p.Y <= ZONE.y1 and p.Z <= ZONE.z1 and p.Z >= ZONE.z0
end

-- oriented box vs the zone box (separating axis test)
local function obbHitsZone(cf, half)
	local zc = Vector3.new((ZONE.x0 + ZONE.x1) / 2, (ZONE.y0 + ZONE.y1) / 2, (ZONE.z0 + ZONE.z1) / 2)
	local zh = Vector3.new((ZONE.x1 - ZONE.x0) / 2, (ZONE.y1 - ZONE.y0) / 2, (ZONE.z1 - ZONE.z0) / 2)
	local A = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	local B = { cf.XVector, cf.YVector, cf.ZVector }
	local hb = { half.X, half.Y, half.Z }
	local ha = { zh.X, zh.Y, zh.Z }
	local d = cf.Position - zc
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, A[i])
		table.insert(axes, B[i])
		for j = 1, 3 do
			local c = A[i]:Cross(B[j])
			if c.Magnitude > 1e-6 then
				table.insert(axes, c.Unit)
			end
		end
	end
	for _, ax in axes do
		local ra, rb = 0, 0
		for i = 1, 3 do
			ra += ha[i] * math.abs(A[i]:Dot(ax))
			rb += hb[i] * math.abs(B[i]:Dot(ax))
		end
		if math.abs(d:Dot(ax)) > ra + rb + 1e-6 then
			return false
		end
	end
	return true
end

local function shapeOf(p)
	if p.ClassName == "WedgePart" then
		return "wedge"
	elseif p.ClassName == "CornerWedgePart" then
		return "corner"
	elseif p:FindFirstChildOfClass("SpecialMesh") then
		return "ell"
	elseif p.ClassName ~= "Part" then
		return "block"
	elseif p.Shape == Enum.PartType.Ball then
		return "ball"
	elseif p.Shape == Enum.PartType.Cylinder then
		return "cyl"
	end
	return "block"
end

-- An ellipsoid meets the zone box iff min over the box of |ellipsoid coords|^2 <= 1.
-- The quadratic is convex, so exact coordinate descent with clamping converges.
local function ellipsoidHitsZone(cf, half)
	local lo = { ZONE.x0, ZONE.y0, ZONE.z0 }
	local hi = { ZONE.x1, ZONE.y1, ZONE.z1 }
	local c = { cf.Position.X, cf.Position.Y, cf.Position.Z }
	local axes = { cf.XVector, cf.YVector, cf.ZVector }
	local semi = { half.X, half.Y, half.Z }
	local Q = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
	for k = 1, 3 do
		local u = { axes[k].X, axes[k].Y, axes[k].Z }
		for i = 1, 3 do
			for j = 1, 3 do
				Q[i][j] += u[i] * u[j] / (semi[k] * semi[k])
			end
		end
	end
	local p = {}
	for i = 1, 3 do
		p[i] = math.clamp(c[i], lo[i], hi[i])
	end
	for _ = 1, 400 do
		for i = 1, 3 do
			local s2 = 0
			for j = 1, 3 do
				if j ~= i then
					s2 += Q[i][j] * (p[j] - c[j])
				end
			end
			p[i] = math.clamp(c[i] - s2 / Q[i][i], lo[i], hi[i])
		end
	end
	local f = 0
	for i = 1, 3 do
		for j = 1, 3 do
			f += (p[i] - c[i]) * Q[i][j] * (p[j] - c[j])
		end
	end
	return f <= 1 + 1e-9
end

--- Exact for blocks, ellipsoids and balls; wedges, corner wedges and cylinders are tested as
--- their bounding boxes (conservative: a pass on the box is a pass on the shape).
local function hitsZone(cf, p)
	local shape = shapeOf(p)
	if shape == "ell" or shape == "ball" then
		return ellipsoidHitsZone(cf, p.Size / 2)
	end
	return obbHitsZone(cf, p.Size / 2)
end

--- The pieces' rest frames in Head space (Orbit_* welds at 36 phases, §2.1 driver formula).
local function headFrames(head, weld)
	local out = {}
	local base = head.CFrame:Inverse() * weld.Part0.CFrame
	if string.match(weld.Name, "^Orbit_") then
		local axis = weld:GetAttribute("OrbitAxis")
		local c = weld:GetAttribute("OrbitCenter") or Vector3.zero
		for i = 0, 35 do
			local th = 2 * math.pi * i / 36
			table.insert(out, base * CFrame.new(c) * CFrame.fromAxisAngle(axis, th) * CFrame.new(-c) * weld.C0)
		end
	else
		table.insert(out, base * weld.C0)
	end
	return out
end

local function faceZoneViolations(model)
	local bad = {}
	local head = model.Head
	for _, p in model.Costume:GetDescendants() do
		if p:IsA("BasePart") and not EXEMPT[p.Name] then
			local weld = p:FindFirstChildOfClass("Weld")
			local k = head.Size.Y / 1.2 -- nominal head space (uniformly scaled dummy)
			local fake = {
				Size = p.Size / k,
				ClassName = p.ClassName,
				Shape = if p:IsA("Part") then p.Shape else nil,
				FindFirstChildOfClass = function(_, c)
					return p:FindFirstChildOfClass(c)
				end,
			}
			for _, cf in headFrames(head, weld) do
				cf = CFrame.new(cf.Position / k) * cf.Rotation
				if hitsZone(cf, fake) then
					table.insert(bad, p.Name)
					break
				end
			end
		end
	end
	return bad
end

local function costumeParts(model)
	local out = {}
	local c = model:FindFirstChild("Costume")
	if c then
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function checkFlags(model, label)
	for _, p in costumeParts(model) do
		local w = p:FindFirstChildOfClass("Weld")
		local big = math.max(p.Size.X, p.Size.Y, p.Size.Z)
		check(
			not p.CanCollide and not p.CanQuery and not p.CanTouch and p.Massless and not p.Anchored,
			`{label}: {p.Name} collide/query/touch/massless/anchored flags`
		)
		check(w ~= nil and w.Part1 == p and w.Part0 ~= nil and w.C1 == CFrame.identity, `{label}: {p.Name} weld`)
		if big < 0.6 then
			check(not p.CastShadow, `{label}: {p.Name} small piece casts a shadow`)
		else
			check(not p:HasTag("CostumeDetail"), `{label}: {p.Name} large piece tagged CostumeDetail`)
		end
		if p.ClassName == "Part" and p.Shape == Enum.PartType.Ball then
			check(p.Size.X == p.Size.Y and p.Size.Y == p.Size.Z, `{label}: {p.Name} ball with unequal axes`)
		end
	end
end

-- record every mount's host and scaling mode (test 12)
local mounts = {}
do
	local Bm = getmetatable(Kit.new(dummy(), 1)).__index
	local orig = Bm.mount
	Bm.mount = function(self, host, attach, kind, size, cf, props, opts)
		local p = orig(self, host, attach, kind, size, cf, props, opts)
		if p then
			mounts[p] = { host = host.Name, absolute = opts and opts.absolute == true }
		end
		return p
	end
end

local Enemies = load(Shared.Data.Enemies)
local Rules = load(Shared.Rules)
local CAP = { human = 30, grey = 21, creature = 30, charBoss = 30 }
local ids = {}
for id in Enemies do
	if not (Costumes.role(id, Enemies[id], nil, false) == "finale") then
		table.insert(ids, id)
	end
end
table.sort(ids)
local Bsum = { builds = 0 }
for _, id in ids do
	local t0 = Enemies[id]
	local base = Costumes.baseId(id)
	local roleOf = Costumes.role(id, t0, nil, false)
	local cases = {}
	if roleOf == "alpha" or roleOf == "charBoss" then
		table.insert(cases, { role = roleOf })
	else
		table.insert(cases, { role = "normal" })
		for _, a in Rules.AFFIXES do
			table.insert(cases, { role = "elite", affix = a })
			table.insert(cases, { role = "elite", affix = a, stitched = true })
		end
	end
	for _, case in cases do
		local t = table.clone(t0)
		local pal = Costumes.palette(t0, case.affix, Costumes.ENEMY[base])
		if case.affix then
			Rules.applyAffix(t, case.affix)
		end
		local s = t.size or 1
		local model = dummy(Vector3.one * s)
		local label =
			`{id} {case.role}{case.affix and (" " .. case.affix.key) or ""}{case.stitched and " stitched" or ""}`
		local ok, used, b = pcall(Creatures.dress, model, {
			enemyId = id,
			role = case.role,
			t = t,
			pal = pal,
			affix = case.affix,
			stitched = case.stitched,
			seed = 3,
		})
		check(ok, `{label}: {used}`)
		if ok then
			Bsum.builds += 1
			local kind = if case.role == "charBoss"
				then "charBoss"
				elseif base == "grey" then "grey"
				elseif t0.shape == "human" then "human"
				else "creature"
			check(16 + used <= CAP[kind], `{label}: 16 + {used} over cap {CAP[kind]}`)
			check(#costumeParts(model) == used, `{label}: costume {#costumeParts(model)} vs used {used}`)
			if case.role ~= "charBoss" then
				for _, rec in b.log do
					if rec.tier == "W" or rec.tier == "R" then
						check(rec.mounted and not rec.missing, `{label}: {rec.tier} entry {rec.code} not mounted`)
					end
				end
			end
			checkFlags(model, label)
			local shape = Costumes.ENEMY[base] and Costumes.ENEMY[base].shape
			for _, p in costumeParts(model) do
				local m = mounts[p]
				if m then
					if (shape and Creatures.ABSOLUTE_FAMILY[shape]) or m.host == "HumanoidRootPart" then
						check(m.absolute, `{label}: {p.Name} on {m.host} not absolute`)
					elseif not m.absolute then
						check(Kit.nominal(m.host) ~= nil, `{label}: {p.Name} host {m.host} has no NOMINAL`)
					end
				end
			end
			if kind == "human" or kind == "grey" then
				local bad = faceZoneViolations(model)
				check(#bad == 0, `{label}: face zone crossed by {table.concat(bad, ", ")}`)
			end
		end
	end
end
print(`{Bsum.builds} enemy builds`)

-- test 12 magnitudes
do
	local t = table.clone(Enemies.mass_curse)
	local model = dummy(Vector3.one * 1.6)
	Creatures.dress(
		model,
		{ enemyId = "mass_curse", role = "normal", t = t, pal = Costumes.palette(t, nil, Costumes.ENEMY.mass_curse) }
	)
	local found = false
	for _, p in costumeParts(model) do
		if p.Name == "chest" then
			found = true
			check((p.Size - Vector3.new(1, 1.5, 0.6) * 1.6).Magnitude < 1e-4, `golem chest {p.Size} not x1.6 once`)
		end
	end
	check(found, "golem chest mounted")
	t = table.clone(Enemies.cursed_toad)
	model = dummy(Vector3.one * t.size)
	Creatures.dress(
		model,
		{ enemyId = "cursed_toad", role = "normal", t = t, pal = Costumes.palette(t, nil, Costumes.ENEMY.cursed_toad) }
	)
	local B = 2.6 * 2.4 * 0.55 * t.size
	for _, p in costumeParts(model) do
		if p.Name == "body" then
			check(math.abs(p.Size.X - B) < 1e-4, `toad body {p.Size.X} ~= B {B}`)
		end
	end
end

-- ward and ally
do
	local model = dummy(Vector3.one * 1.3)
	local w = Creatures.buildWard(nil, model)
	check(#costumeParts(w) == 14, `ward {#costumeParts(w)} parts, want 14`)
	for _, d in w:GetDescendants() do
		if d:IsA("BasePart") then
			check(not d.CanQuery, "ward CanQuery")
		end
	end
	local t = table.clone(Enemies.rogue_ninja)
	local m = dummy()
	Creatures.dress(m, {
		enemyId = "rogue_ninja",
		role = "elite",
		t = t,
		pal = Costumes.palette(t, Rules.AFFIXES[1], nil),
		affix = Rules.AFFIXES[1],
		stitched = true,
	})
	Kit.ally(m)
	local strips, cyan = 0, false
	for _, p in costumeParts(m) do
		if p.Name == "STRIP" and p.Parent then
			strips += 1
		end
		if p.Name == "RING" and p.Color == Color3.fromRGB(90, 212, 255) then
			cyan = true
		end
	end
	check(strips == 0 and cyan, "Kit.ally removes strips and turns the ring cyan")
end

print(`\n{passes} checks passed, {failures} failed`)
process.exit(if failures == 0 then 0 else 1)
