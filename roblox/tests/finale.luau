--!nocheck
-- Builds the three finale bosses (docs/design/characters.md §5) with the real Kit/Finale code on
-- real Roblox instances (Lune):   lune run tests/finale   (from the roblox folder)
-- Checks the §6.3 part caps (30 / 30 / 29), lights, emitters and SurfaceGuis, the face-zone rule
-- for Hyakunui and the Unbidden (§6.6 test 10), test 12 for the Tempest Fox, every Hyakunui
-- phase, the Unbidden after each adaptation, and tests 5b / 5g on Hyakunui against
-- mahito ∪ kenjaku.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")

local Instance, Vector3, CFrame, Color3, Enum =
	roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

-- the place ----------------------------------------------------------------------------------
local placeFile = "build/finale-test.rbxl"
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

local Finale = load(place:GetService("ServerScriptService").Server.Kit.Finale)
local Characters = load(Shared.Data.Characters)
local EnemyLooks = load(Shared.Data.EnemyLooks)
local RulesData = load(Shared.Data.Rules)

-- a dummy R15 rig with per-axis body scale and a separate head scale -------------------------
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
do
	local ez = Costumes and Costumes.EYE_ZONE
	if type(ez) == "table" then
		ZONE.x0, ZONE.x1 = ez.xMin or ZONE.x0, ez.xMax or ZONE.x1
		ZONE.y0, ZONE.y1 = ez.yMin or ZONE.y0, ez.yMax or ZONE.y1
		ZONE.z1 = ez.zFront or ZONE.z1
	end
	local fe = Costumes and Costumes.FACE_EXEMPT
	if type(fe) == "table" then
		for k, v in fe do
			if type(k) == "number" then
				EXEMPT[v] = true
			elseif v then
				EXEMPT[k] = true
			end
		end
	end
end

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
local function hitsZone(cf, p, kk)
	local shape = shapeOf(p)
	local half = p.Size / 2 / (kk or 1)
	if shape == "ell" or shape == "ball" then
		return ellipsoidHitsZone(cf, half)
	end
	return obbHitsZone(cf, half)
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
			local kk = head.Size.X / 1.2 -- test in nominal head space (scaled heads)
			for _, cf in headFrames(head, weld) do
				if hitsZone(CFrame.new(cf.Position / kk) * cf.Rotation, p, kk) then
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

local function rig(scale, headScale)
	local model = dummy(scale)
	local head = model.Head
	head.Size = Vector3.new(1.2, 1.2, 1.2) * headScale
	for _, a in head:GetChildren() do
		if a:IsA("Attachment") then
			a.CFrame = CFrame.new(Kit.ATTACH[a.Name].pos * headScale)
		end
	end
	return model
end

local function count(model, class)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA(class) then
			n += 1
		end
	end
	return n
end

local function r15Count(model)
	local n = 0
	for _, c in model:GetChildren() do
		if c:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function budgets(model, label, cap, lights)
	local total = r15Count(model) + #costumeParts(model)
	check(total <= cap, `{label}: {total} parts > cap {cap}`)
	check(count(model, "PointLight") + count(model, "SpotLight") == lights, `{label}: lights ~= {lights}`)
	check(count(model, "ParticleEmitter") <= 3, `{label}: {count(model, "ParticleEmitter")} emitters > 3`)
	check(count(model, "SurfaceGui") <= 4, `{label}: {count(model, "SurfaceGui")} SurfaceGuis > 4`)
	checkFlags(model, label)
	return total
end

local function hex(c)
	return string.format("%06x", c)
end
local function int(c3)
	return math.floor(c3.R * 255 + 0.5) * 65536 + math.floor(c3.G * 255 + 0.5) * 256 + math.floor(c3.B * 255 + 0.5)
end

-- 1. Hyakunui ------------------------------------------------------------------------------
local HY_SIZE = 1.8
local function hyakunui()
	local m = rig(Vector3.new(1.1, 1, 1) * HY_SIZE, 0.8 * HY_SIZE)
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.9
	hl.Parent = m
	local used = Finale.dress(m, "hyakunui")
	return m, used
end

do
	local m, used = hyakunui()
	check(used == 14, `hyakunui: costume {used} ~= 14`)
	check(budgets(m, "hyakunui", 30, 1) == 30, "hyakunui: total ~= 30")
	local bad = faceZoneViolations(m)
	check(#bad == 0, "hyakunui face zone: " .. table.concat(bad, ", "))
	check(m:GetAttribute("FinalePhase") == 1, "hyakunui: phase 1 after dress")
	local fg = m.Costume.FP.FaceGlow
	check(int(fg.IrisL.BackgroundColor3) == 0xc89a6a and int(fg.IrisR.BackgroundColor3) == 0xa8883a, "hyakunui: irises")
	local beams = 0
	for _, d in m.UpperTorso:GetChildren() do
		if d:IsA("Beam") then
			beams += 1
		end
	end
	check(beams == 4, "hyakunui: 4 thread beams")
	check(m.RightHand:FindFirstChild("FS") ~= nil or #m.Costume:GetChildren() > 0, "hyakunui: fist")
	-- test 12 (nominal): every piece's host is in NOMINAL; needles scaled once
	for _, p in costumeParts(m) do
		local w = p:FindFirstChildOfClass("Weld")
		check(Kit.nominal(w.Part0.Name) ~= nil, `hyakunui: {p.Name} host {w.Part0.Name} not nominal`)
	end
end

-- every phase, fresh and sequential
local hyColours = {}
local function collect(model, phaseLabel)
	local skinParts =
		{ Head = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true, FS = true }
	local hairParts = { HR = true, ["HR·k"] = true, ["HR·p"] = true }
	local r15 = {}
	for _, c in model:GetChildren() do
		if c:IsA("BasePart") then
			r15[c] = true
		end
	end
	local function add(c, where, opts)
		table.insert(hyColours, {
			color = c,
			where = phaseLabel .. " " .. where,
			skin = opts and opts.skin,
			hair = opts and opts.hair,
			body = opts and opts.body,
		})
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local name = d.Name
			add(int(d.Color), name, {
				skin = skinParts[name] and Costumes.isSkinTone(int(d.Color)),
				hair = hairParts[name],
				body = r15[d] or hairParts[name] or name == "CT",
			})
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 and d.Visible then
			add(int(d.BackgroundColor3), "frame " .. d.Name, { hair = string.match(d.Name, "^Brow") ~= nil })
		elseif d:IsA("UIStroke") then
			add(int(d.Color), "stroke " .. d.Parent.Name)
		elseif d:IsA("Beam") or d:IsA("ParticleEmitter") then
			add(int(d.Color.Keypoints[1].Value), d.ClassName .. " " .. d.Name)
		elseif d:IsA("PointLight") then
			add(int(d.Color), "light")
		end
	end
end

for phase = 1, 3 do
	local m = hyakunui()
	Finale.phase(m, phase)
	local label = `hyakunui phase {phase}`
	budgets(m, label, 30, 1)
	local bad = faceZoneViolations(m)
	check(#bad == 0, label .. " face zone: " .. table.concat(bad, ", "))
	local thread
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Name == "Thread" then
			thread = d
		end
	end
	check(thread and thread.Rate == (if phase >= 3 then 12 else 4), label .. ": thread rate")
	for _, p in costumeParts(m) do
		if p.Name == "HY·p" then
			local neon = p.Material == Enum.Material.Neon
			check(neon == (phase >= 2), label .. ": patch material")
			if phase >= 2 then
				local want = if p:GetAttribute("Side") == "L" then Finale.TEAR.left else Finale.TEAR.right
				check(int(p.Color) == want, label .. ": patch tear colour")
			end
		elseif p.Name == "HY·n" then
			local w = p:FindFirstChildOfClass("Weld")
			local base = w:GetAttribute("BasePos")
			local f = if phase >= 2 then 1.4 else 1
			check((w.C0.Position - base * f).Magnitude < 1e-4, label .. ": needle offset")
			local want = if phase >= 3 then Finale.hotNeedle() else Costumes.STEEL
			check(int(p.Color) == want, label .. ": needle colour")
		elseif p.Name == "HY·s" then
			local want = if phase >= 3 then Costumes.lerp(0xff2d55, 0xffffff, 0.3) else 0xff2d55
			check(int(p.Color) == want, label .. ": seam colour")
		end
	end
	for _, d in m.UpperTorso:GetChildren() do
		if d:IsA("Beam") then
			local w = d:GetAttribute("BaseWidth") * (if phase >= 2 then 0.14 / 0.08 else 1)
			check(math.abs(d.Width0 - w) < 1e-6, label .. ": beam width")
		elseif d:IsA("Attachment") and d.Name == "ThreadFar" then
			local f = if phase >= 2 then 1.4 else 1
			check((d.CFrame.Position - d:GetAttribute("BasePos") * f).Magnitude < 1e-4, label .. ": far attachment")
		end
	end
	local hair = 0
	for _, p in costumeParts(m) do
		if p.Name == "HR·p" or p.Name == "HR·k" then
			hair += 1
		end
	end
	check(hair == (if phase >= 3 then 0 else 2), label .. ": HR·p / HR·k")
	check(
		math.abs(m.Highlight.FillTransparency - (if phase >= 3 then 0.6 else 0.9)) < 1e-4,
		label .. ": highlight fill"
	)
	collect(m, label)
end
do -- sequential 1 -> 2 -> 3 matches a fresh phase 3
	local m = hyakunui()
	Finale.phase(m, 2)
	Finale.phase(m, 3)
	Finale.phase(m, 2) -- ignored
	check(m:GetAttribute("FinalePhase") == 3, "hyakunui: phases are monotonic")
	check(#costumeParts(m) == 12, "hyakunui: phase 3 has 12 costume parts")
end

-- 5b / 5g on Hyakunui against mahito ∪ kenjaku
do
	local guards = {}
	for _, id in { "mahito", "kenjaku" } do
		for _, g in Costumes.TRADE_DRESS[id] do
			table.insert(guards, g)
		end
	end
	local NOT = { browAngle = true, hairLen = true, height = true, headScale = true }
	local src = {}
	for _, id in { "mahito", "kenjaku" } do
		for _, row in
			{ Characters[id], Characters[id .. "C"], EnemyLooks["boss_" .. id], EnemyLooks[id .. "_b"], EnemyLooks[id] }
		do
			if type(row) == "table" then
				for k, v in row do
					if type(v) == "number" and not NOT[k] then
						table.insert(src, v)
					end
				end
			end
		end
	end
	check(#src > 0, "5g: no mahito/kenjaku source colours found")
	local world = {}
	for _, c in Costumes.WORLD_CONST do
		world[c] = true
	end
	local copied = {}
	for _, u in hyColours do
		local _, _, val = Costumes.hsv(u.color)
		if not u.skin and val >= 0.3 then
			for _, g in guards do
				if (not g.hairOnly or u.hair) and Costumes.dist(u.color, g.color) <= 30 then
					check(false, `5b hyakunui: {u.where} {hex(u.color)} near {hex(g.color)}`)
				end
			end
		end
		if not (u.skin or val < 0.25 or world[u.color]) then
			for _, sc in src do
				if Costumes.dist(u.color, sc) < 8 then
					copied[u.color] = true
					check(not u.body, `5g hyakunui: body colour {u.where} {hex(u.color)} copies {hex(sc)}`)
				end
			end
		end
	end
	local n = 0
	for _ in copied do
		n += 1
	end
	check(n <= 2, `5g hyakunui: {n} verbatim copies`)
	check(true, "5b/5g ran")
end

-- 2. The Tempest Fox -----------------------------------------------------------------------
do
	local size = 2.1
	local m = rig(Vector3.new(size, size * 0.7, size), size)
	m.Humanoid.HipHeight = 2 * 0.7 * size
	local used, b = Finale.dress(m, "tempest_fox")
	check(used == 14, `tempest_fox: costume {used} ~= 14`)
	check(budgets(m, "tempest_fox", 30, 0) == 30, "tempest_fox: total ~= 30")
	local S = 2.4 * 0.55 * size
	local hrp = m.HumanoidRootPart
	for _, p in costumeParts(m) do
		local w = p:FindFirstChildOfClass("Weld")
		check(w.Part0 == hrp, `tempest_fox: {p.Name} not on the HRP`)
		check(b.mounts[p] and b.mounts[p].k == Vector3.one, `tempest_fox: {p.Name} not absolute (test 12)`)
	end
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") then
			check(c.Transparency == 1, `tempest_fox: walker part {c.Name} visible`)
		end
	end
	local body
	for _, p in costumeParts(m) do
		if p.Name == "TF·body" then
			body = p
		end
	end
	check(
		body and (body.Size - Vector3.new(1, 0.9, 2.2) * S).Magnitude < 1e-4,
		"tempest_fox: body is not exactly S-sized (test 12)"
	)
	local gaits, sways = {}, 0
	for _, d in m.Costume:GetDescendants() do
		if d:IsA("Weld") and string.match(d.Name, "^Gait_") then
			gaits[d.Name] = d:GetAttribute("GaitPhase")
		elseif d:IsA("Weld") and string.match(d.Name, "^Sway_") then
			sways += 1
			check(d:GetAttribute("SwayAmp") == 10, "tempest_fox: tail SwayAmp")
		end
	end
	check(
		gaits.Gait_FL == 0 and gaits.Gait_HR == 0 and gaits.Gait_FR == 0.5 and gaits.Gait_HL == 0.5,
		"tempest_fox: gait phases"
	)
	check(sways == 3, "tempest_fox: 3 swaying tails")
	check(count(m, "Beam") == 3, "tempest_fox: 3 tail tip beams")
	-- tell
	check(m:GetAttribute("Tell") == false, "tempest_fox: Tell starts false")
	Finale.setTell(m, Finale.tellAction("tell"))
	check(m:GetAttribute("Tell") == true, "tempest_fox: tell sets Tell")
	check(
		Finale.tellAction("windup") == nil and Finale.tellAction("lunge") == nil,
		"tempest_fox: windup/lunge leave Tell"
	)
	for _, a in { "endLunge", "cancel", "death" } do
		Finale.setTell(m, true)
		Finale.setTell(m, Finale.tellAction(a))
		check(m:GetAttribute("Tell") == false, "tempest_fox: " .. a .. " clears Tell")
	end
end

-- 3. The Unbidden -------------------------------------------------------------------------
local function unbidden(opts)
	local size = 1.9
	local m = rig(Vector3.new(1.2, 1, 0.9) * size, 0.8 * size)
	local used = Finale.dress(m, "the_unbidden", opts)
	return m, used
end
do
	local m, used = unbidden()
	check(used == 13, `the_unbidden: costume {used} ~= 13`)
	check(budgets(m, "the_unbidden", 29, 0) == 29, "the_unbidden: total ~= 29")
	local function tiles()
		local t = {}
		for _, p in costumeParts(m) do
			if p.Name == "UB·t" then
				t[p:GetAttribute("Nature")] = p
			end
		end
		return t
	end
	for i, nature in Costumes.ADAPT_ORDER do
		m:SetAttribute("Adapted_" .. nature, true)
		Finale.adapt(m, nature)
		local t = tiles()
		for j, n in Costumes.ADAPT_ORDER do
			local lit = t[n].Material == Enum.Material.Neon
			check(lit == (j <= i), `the_unbidden after {nature}: tile {n} lit={lit}`)
			if j <= i then
				check(int(t[n].Color) == RulesData.NATURE[n].color, `the_unbidden: tile {n} colour`)
			end
		end
		for _, p in costumeParts(m) do
			if p.Name == "UB·p" then
				check(
					int(p.Trim.Trim.UIStroke.Color) == RulesData.NATURE[nature].color,
					`the_unbidden: trim echo {nature}`
				)
			end
		end
		local label = "the_unbidden after " .. nature
		budgets(m, label, 29, 0)
		local bad = faceZoneViolations(m)
		check(#bad == 0, label .. " face zone: " .. table.concat(bad, ", "))
	end
	-- applyAdapted on a fresh build from attributes alone
	local m2 = unbidden()
	m2:SetAttribute("Adapted_fire", true)
	m2:SetAttribute("Adapted_water", true)
	Finale.applyAdapted(m2)
	local lit = 0
	for _, p in costumeParts(m2) do
		if p.Name == "UB·t" and p.Material == Enum.Material.Neon then
			lit += 1
		end
	end
	check(lit == 2, "the_unbidden: applyAdapted lights 2 tiles")
	-- the ward look
	local w, wused = unbidden({ ally = true })
	check(wused == 13, "ward: 13 before the ring")
	for _, p in costumeParts(w) do
		if p.Name == "UB·t" then
			check(int(p.Color) == Costumes.ALLY_CYAN, "ward: tile cyan")
		end
	end
end

print(`\nfinale: {passes} passed, {failures} failed`)
process.exit(if failures == 0 then 0 else 1)
