--!nocheck
-- Mounts every §2.3 kit piece and every STYLE with the real Kit code on real Roblox instances
-- (Lune), on a dummy R15 rig at scale 1 and at a larger scale:
--   lune run tests/kit          (from the roblox folder; builds build/kit-test.rbxl with rojo)
-- Checks part counts per code against docs/design/characters.md §2.3, the costume flags,
-- welds, CostumeDetail/CastShadow, the face-zone rule (§2.2, orbiting pieces at 36 phases),
-- ringOver, emblem Frame counts, budget trimming, each style's +N (§3) with every kit entry
-- built (largest prop and default prop), the suit tendrils, and every Arsenal prop (§2.6).
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
			for _, cf in headFrames(head, weld) do
				if hitsZone(cf, p) then
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

-- 1. every §2.3 code ------------------------------------------------------------------------
local LOOK = {
	colors = {
		skin = 0xf3c9a0,
		hair = 0x3a2a24,
		brow = 0x3a2a24,
		eye = 0x5a7a4a,
		top = 0x2f8f86,
		sleeves = 0x2f8f86,
		bottom = 0xc9b48a,
		trim = 0x2b3350,
		sig = 0xe8b040,
	},
}

-- entry, parts expected from §2.3 (and its variants)
local CASES = {
	{ { "FP" }, 1 },
	{ { "HR" }, 1 },
	{ { "HR", variant = "shaved sides", scale = { x = 1.1 } }, 1 },
	{ { "HR·s", n = 3 }, 3 },
	{ { "HR·s", n = 2 }, 2 },
	{ { "HR·w", n = 2 }, 2 },
	{ { "HR·w", n = 1, side = "R" }, 1 },
	{ { "HR·w", n = 1, x = 0, variant = "crest" }, 1 },
	{ { "HR·p", h = 1.5 }, 1 },
	{ { "HR·p", n = 2, h = 0.7, x = 0.3, w = 0.5 }, 2 },
	{ { "HR·f", side = "L" }, 1 },
	{ { "HR·k" }, 1 },
	{ { "HR·k", variant = "topknot" }, 1 },
	{ { "HR·t", n = 2 }, 2 },
	{ { "HB" }, 1 },
	{ { "HB·t" }, 2 },
	{ { "VB" }, 1 },
	{ { "VB·m" }, 1 },
	{ { "LM" }, 1 },
	{ { "CK" }, 1 },
	{ { "FM", variant = "blocks" }, 3 },
	{ { "FM", variant = "round", accent = 0xffb347 }, 3 },
	{ { "FM", n = 2, variant = "slit", tints = { slit = 0x4ae0c0 } }, 2 },
	{ { "BK" }, 1 },
	{ { "HD" }, 3 },
	{
		{
			"HD·d",
			gui = { kind = "patch", side = "L", w = 60, h = 40, fill = 0x9b1a2a, border = "E11", color = 0xe8e0d0 },
		},
		1,
	},
	{ { "HN" }, 2 },
	{ { "HN", variant = "branches" }, 2 },
	{ { "EP", n = 2, variant = "ears" }, 2 },
	{ { "EP", n = 2, variant = "ears", mount = "NeckAttachment", pos = { 0.55, 0.3, 0.2 } }, 2 },
	{ { "EP", n = 1, variant = "fin", fx = "drip" }, 1 },
	{ { "EC", side = "R" }, 1 },
	{ { "GG" }, 2 },
	{ { "GG", variant = "up", tint = 0x2a2d34, accent = 0x9fe0ff }, 2 },
	{ { "HP", n = 2 }, 2 },
	{ { "CR" }, 4 },
	{ { "CR", n = 1 }, 1 },
	{ { "OR", n = 3 }, 3 },
	{ { "SC", side = "L" }, 2 },
	{ { "SC", emblem = "E8", at = "tail", emblemColor = 0x8ad0e0 }, 2 },
	{ { "SG", n = 2 }, 2 },
	{ { "SG", n = 1, side = "L" }, 1 },
	{ { "HC", gui = { kind = "edge", color = 0x6a7a9a } }, 1 },
	{ { "LP", gui = { kind = "beads", color = 0x8a7ab0 } }, 2 },
	{ { "VS", gui = { kind = "stripe", color = 0xe8c86a } }, 1 },
	{ { "EM", emblem = "E1", at = "waist" }, 1 },
	{ { "EM", emblem = "E10", at = "back" }, 1 },
	{ { "EM", variant = "pendant", material = "Glass", reflectance = 0.5 }, 1 },
	{ { "CT" }, 2 },
	{ { "CP" }, 1 },
	{ { "CP", variant = "short" }, 1 },
	{ { "SB" }, 1 },
	{ { "SB", tail = true, gui = { kind = "dots", count = 8, glow = 0x3ad86a } }, 2 },
	{ { "SB", pouch = 2 }, 3 },
	{ { "SB", pouch = 1, gui = { kind = "nails", count = 3, color = 0x9aa4b0 } }, 2 },
	{ { "MT" }, 1 },
	{ { "CO" }, 1 },
	{ { "CO", variant = "diamond" }, 1 },
	{ { "BW" }, 2 },
	{ { "BW", n = 2, variant = "katana" }, 2 },
	{ { "BW", variant = "short" }, 1 },
	{ { "BA", n = 8, segs = 2 }, 8 },
	{ { "BA", n = 12, segs = 3, tints = { claw = 0xe89a4a } }, 12 },
	{ { "TN", n = 2 }, 2 },
	{ { "TN", n = 3 }, 3 },
	{ { "WG", gui = { kind = "dots", color = 0xffb347, count = 2, glow = true } }, 1 },
	{ { "WG", variant = "wings" }, 2 },
	{ { "GL", n = 2 }, 2 },
	{ { "GL", n = 1, side = "L" }, 1 },
	{ { "GL", n = 2, gui = { kind = "ring", emblem = "E7", side = "R", glow = 0x5ad4ff } }, 2 },
	{ { "GL", n = 2, gui = { kind = "palm", color = 0x5ad4ff, face = "Bottom", glow = true } }, 2 },
	{ { "FB", n = 2 }, 2 },
	{ { "FB", n = 2, variant = "long" }, 2 },
	{ { "MA", side = "right", accent = 0x9fe0ff }, 1 },
	{ { "XA", n = 4 }, 4 },
	{ { "WR", n = 2 }, 2 },
	{ { "FS", n = 2 }, 2 },
	{ { "SD" }, 1 },
	-- §3.1 bespoke pieces and the §2.6 Prop slot (Bespoke.luau)
	{ { "HAT", n = 3, tints = { b = 0x101010, c = 0x101010, n = 0x9b1a2a } }, 3 },
	{ { "FTH", n = 2 }, 2 },
	{ { "CLP", fx = "ember", fxAt = "hands", fxColor = 0x5a5a78 }, 1 },
	{ { "LF" }, 1 },
	{ { "BLM" }, 1 },
	{ { "ORB" }, 1 },
	{ { "WSP", fx = "wind" }, 1 },
	{ { "SHD", n = 4, tints = { beam = 0x8a6cff }, gui = { kind = "edge", glow = 0x8a6cff } }, 4 },
	{ { "VL", n = 2 }, 2 },
	{ { "TIE", gui = { kind = "stripes", bars = 3, rot = 30, color = 0x8a6a4a } }, 1 },
	{ { "WCH" }, 1 },
	{ { "BLD", gui = { kind = "gripWrap", bands = 3, color = 0x3a3a42 } }, 1 },
	{ { "HMR", n = 2, tints = { s = 0x5a4a3a, h = 0x9aa4b0 } }, 2 },
	{ { "FLT" }, 1 },
	{ { "CN" }, 1 },
	{ { "MZ" }, 1 },
	{ { "STF", fx = "spark", fxAt = "tips" }, 1 },
	{ { "TIP" }, 1 },
	{ { "PLT", n = 2, tints = { L = 0xd8c0a8, R = 0x8a6244 }, gui = { kind = "edge", emblem = "E11" } }, 2 },
	{ { "SEAM" }, 1 },
	{ { "TSL", n = 2 }, 2 },
	{ { "EDG" }, 1 },
	{ { "CRY", n = 3 }, 3 },
	{ { "SPL", n = 2, gui = { kind = "ring", color = 0x2fb7a8 } }, 2 },
	{ { "SM", n = 4 }, 4 },
	{ { "Prop", max = 3, style = "tophat", key = "sniper" }, 3 },
}

print("§2.3 pieces (scale 1 and scale 1.3):")
local seen = {}
for _, case in CASES do
	local entry, want = case[1], case[2]
	local code = entry[1]
	seen[code] = true
	for _, s in { 1, 1.3 } do
		local model = dummy(Vector3.one * s)
		local rig = Kit.rig(model)
		local b = Kit.new(model, 99)
		local ok, err = pcall(Kit.mountEntry, b, rig, entry, LOOK, "R")
		check(ok, `{code}: {err}`)
		local got = #costumeParts(model)
		local label = `{code}{entry.variant and (" " .. entry.variant) or ""} @{s}`
		check(got == want, `{label}: {got} parts, §2.3 says {want}`)
		check(Kit.count(entry) == want, `{label}: Kit.count {Kit.count(entry)} ~= {want}`)
		checkFlags(model, label)
		if s == 1 then
			local bad = faceZoneViolations(model)
			check(#bad == 0, `{label}: face zone crossed by {table.concat(bad, ", ")}`)
			print(string.format("  %-6s %-14s %d parts (want %d)", code, entry.variant or "", got, want))
		end
	end
end
for code in Kit.PIECES do
	check(seen[code], `PIECES.{code} has no test case`)
end

-- scaling: a relative piece scales with its host, an absolute one does not (§2.1)
do
	local model = dummy(Vector3.new(1.25, 1.1, 1.15))
	local rig = Kit.rig(model)
	local b = Kit.new(model, 99)
	local cap = b:mount(model.Head, nil, "ell", Kit.CAP, CFrame.new(0, 0.26, 0.06))
	local k = model.Head.Size / Vector3.new(1.2, 1.2, 1.2)
	check((cap.Size - Kit.CAP * k).Magnitude < 1e-4, "HR cap scales with the head")
	local w = cap:FindFirstChildOfClass("Weld")
	check((w.C0.Position - Vector3.new(0, 0.26, 0.06) * k).Magnitude < 1e-4, "HR offset scales with the head")
	local rod = b:mount(model.UpperTorso, nil, "cyl", Vector3.new(1, 0.2, 0.2), Kit.CYL_UP)
	local kt = model.UpperTorso.Size / Vector3.new(2, 1.6, 1)
	check(
		math.abs(rod.Size.X - kt.Y) < 1e-4 and math.abs(rod.Size.Y - 0.2 * kt.X) < 1e-4,
		"CYL_UP length follows host Y"
	)
	local sd = Kit.PIECES.SD(b, rig, { "SD", footprint = 2 }, LOOK)[1]
	check(math.abs(sd.Size.Y - 2.4) < 1e-4, "SD is absolute")
	local ok = pcall(function()
		local odd = Instance.new("Part")
		odd.Name = "NotAnR15Part"
		odd.Parent = model
		b:mount(odd, nil, "block", Vector3.one)
	end)
	check(not ok, "a relative mount on a host with no NOMINAL errors")
end

-- the face-zone check itself catches violations (negative controls)
do
	local model = dummy()
	local b = Kit.new(model, 99)
	b:mount(model.Head, nil, "block", Vector3.new(0.2, 0.6, 0.1), CFrame.new(-0.30, 0.12, -0.6), { name = "XX" })
	check(#faceZoneViolations(model) == 1, "control: a forelock at x -0.30 crosses the eye zone")
	model = dummy()
	b = Kit.new(model, 99)
	-- the revision-4 OR rest height (y 0.35, z -0.95) fails at some orbit phase, not at rest
	local p = b:mount(
		model.Head,
		nil,
		"wedge",
		Vector3.new(0.12, 0.35, 0.2),
		Kit.ry(90) * CFrame.new(0, 0.35, -0.95),
		{ name = "OR" }
	)
	local restFrame = model.Head.CFrame:Inverse() * model.Head.CFrame * p:FindFirstChildOfClass("Weld").C0
	check(not hitsZone(restFrame, p), "control: old OR is clear at its rest phase")
	b:orbit(Vector3.yAxis, 0.25, 0, Vector3.zero, "old", p)
	check(#faceZoneViolations(model) == 1, "control: old OR crosses the eyes during its orbit")
	model = dummy()
	b = Kit.new(model, 99)
	b:mount(model.Head, nil, "ell", Vector3.new(1.28, 1.3, 1.3), CFrame.identity, { name = "YY" })
	check(#faceZoneViolations(model) == 1, "control: a full-head ellipsoid crosses the eye zone")
end

-- band over hair (§2.1): HB at y 0.36 over the raised cap
do
	local need = Kit.ringOver(Kit.CAP, Vector3.new(0, 0.32, 0.06), 0.36)
	check(math.abs(need.X - 1.356) < 0.002 and math.abs(need.Y - 1.376) < 0.002, `ringOver {need}`)
	check(1.40 >= need.X and 1.40 >= need.Y, "HB 1.40×1.40 covers the cap")
end

-- emblems: at most 6 Frames each, gradients within 20 keypoints (§2.5)
do
	local model = dummy()
	local plate = Instance.new("Part")
	plate.Size = Vector3.new(0.55, 0.55, 0.05)
	plate.Parent = model
	local line = {}
	for i = 1, 11 do
		local id = "E" .. i
		local g = Kit.emblem(plate, id, { stroke = 0xffffff })
		check(g ~= nil, id .. " exists")
		local frames = 0
		for _, d in g:GetDescendants() do
			if d.ClassName == "Frame" then
				frames += 1
			end
			if d.ClassName == "UIGradient" then
				check(#d.Transparency.Keypoints <= 20, id .. " gradient keypoints")
			end
		end
		check(frames >= 1 and frames <= 6, `{id}: {frames} Frames`)
		table.insert(line, `{id} {frames}`)
	end
	print("emblem Frames: " .. table.concat(line, ", "))
end

-- budget: whole entries only, skipped when they do not fit, rolled back when a count lies
do
	local model = dummy()
	local rig = Kit.rig(model)
	local b = Kit.new(model, 3)
	check(Kit.mountEntry(b, rig, { "HR·s", n = 2 }, LOOK, "R"), "first entry fits")
	check(not Kit.mountEntry(b, rig, { "SB", tail = true }, LOOK, "D"), "2-part entry skipped at 1 left")
	check(b.used == 2 and #costumeParts(model) == 2, "no partial entry")
	b.code = "liar"
	local ok = b:entry("D", function()
		Kit.PIECES.GL(b, rig, { "GL", n = 2 }, LOOK)
	end, 1)
	check(not ok and b.used == 2 and #costumeParts(model) == 2, "under-counted entry rolled back")
	check(Kit.mountEntry(b, rig, { "HB" }, LOOK, "D") and b.used == 3, "1-part entry still fits")
	check(b:mount(model.Head, nil, "block", Vector3.one) == nil, "mount returns nil once the budget is spent")
end

-- 2. every STYLE ----------------------------------------------------------------------------
local PLUS_N = {
	naruto = 13,
	sasuke = 11,
	kakashi = 8,
	itachi = 8,
	might_guy = 9,
	pain = 10,
	gojo = 13,
	sukuna = 11,
	yuji = 8,
	megumi = 9,
	toji = 10,
	kashimo = 7,
	geto = 7,
	kenjaku = 6,
	choso = 8,
	mahito = 8,
	jogo = 6,
	hanami = 8,
	dagon = 5,
	nanami = 6,
	nobara = 8,
	toge = 5,
	maki = 10,
	naoya = 7,
	yuta = 8,
	ishigori = 8,
	uro = 6,
	todo = 7,
	hakari = 7,
	yuki = 9,
	spiderman = 10,
	insomniac = 8,
	miles = 8,
	ironspider = 14,
	venom = 7,
	carnage = 8,
	antivenom = 6,
	docock = 14,
	winter = 8,
	ironman = 10,
	jean = 7,
	strange = 7,
	goblin = 8,
	wolverine = 8,
	eleven = 6,
	tophat = 12,
}

local STYLES = {}
if Costumes and type(Costumes.STYLE) == "table" then
	STYLES = Costumes.STYLE
else
	for _, m in Shared.Costumes.Styles:GetChildren() do
		for id, st in load(m) do
			STYLES[id] = st
		end
	end
end

local Arsenals = load(Shared.Data.Arsenals)

-- the largest prop key of a style (Arsenals order), and its parts
local function largestProp(id)
	local a = Arsenals[id]
	if not a then
		return nil, 0
	end
	local best, n = nil, -1
	for _, key in a.order do
		local p = Kit.propParts(id, key)
		if p > n then
			best, n = key, p
		end
	end
	return best, n
end

print("\nstyles (+N from §3; built with the largest prop, and with the default prop):")
local ids = {}
for id in STYLES do
	table.insert(ids, id)
end
table.sort(ids)
local count = 0
for _, id in ids do
	local st = STYLES[id]
	for _, code in
		(function()
			local t = {}
			for _, e in st.kit do
				table.insert(t, e[1])
			end
			return t
		end)()
	do
		check(Kit.PIECES[code] ~= nil, `{id}: kit code {code} has no builder`)
	end
	local bigKey = largestProp(id)
	for _, role in { "player", "charBoss" } do
		local look = st
		if Costumes and Costumes.effectiveLook then
			local ok, eff = pcall(Costumes.effectiveLook, id, role)
			if ok and type(eff) == "table" then
				look = eff
			end
		end
		for _, weapon in (if bigKey then { bigKey, false } else { false }) do
			local model = dummy()
			if weapon then
				model:SetAttribute("Weapon", weapon)
			end
			local ok, used, b = pcall(Kit.build, model, look, { role = role, style = st })
			check(ok, `{id} {role}: {used}`)
			if ok then
				local want = PLUS_N[id]
				check(want ~= nil, `{id}: no +N in the test table`)
				local propMax, propBuilt = 0, 0
				for _, e in st.kit do
					if e[1] == "Prop" then
						propMax = e.max or 3
					end
				end
				if propMax > 0 then
					local def = weapon or (st.props and st.props.default)
					propBuilt = Kit.propParts(id, def)
				end
				if want then
					check(
						used == want - (propMax - propBuilt),
						`{id} {role} {weapon or "default"}: built {used}, §3 +{want} (prop {propBuilt}/{propMax})`
					)
					if weapon then
						check(used == want, `{id} {role}: largest prop {weapon} builds {used}, §3 +{want}`)
					end
				end
				check(16 + used <= 30, `{id}: {16 + used} parts over the cap`)
				for _, rec in b.log do
					check(not rec.missing, `{id}: {rec.code} skipped as missing`)
					check(rec.mounted, `{id} {role}: {rec.code} not mounted`)
				end
				check(
					#costumeParts(model) == used,
					`{id} {role}: Costume holds {#costumeParts(model)} parts, builder says {used}`
				)
				checkFlags(model, id)
				local bad = faceZoneViolations(model)
				check(#bad == 0, `{id} {role}: face zone crossed by {table.concat(bad, ", ")}`)
				if st.sigPiece then
					local found = false
					for _, rec in b.log do
						if rec.code == st.sigPiece and rec.mounted then
							found = true
						end
					end
					check(found, `{id}: sigPiece {st.sigPiece} did not survive`)
				end
				local fp = Kit.faceOf(model)
				check(fp ~= nil and fp:FindFirstChild("FaceBase") and fp:FindFirstChild("FaceGlow"), `{id}: face guis`)
				check(model.Head:FindFirstChild("face") == nil, `{id}: default face decal destroyed`)
				if st.suitTN then
					local tn = Kit.suitTN(model, true, look)
					check(#tn == 2 and #model.Costume.SuitTN:GetChildren() == 2, `{id}: suit TN mounts 2`)
					check(#costumeParts(model) == want + 2, `{id}: with the suit {#costumeParts(model)} ~= {want + 2}`)
					check(#faceZoneViolations(model) == 0, `{id}: suit TN face zone`)
					Kit.suitTN(model, false)
					check(model.Costume:FindFirstChild("SuitTN") == nil, `{id}: suit TN removed`)
				end
				if role == "player" and weapon == false then
					count += 1
					print(string.format("  %-11s +%-2d built %-2d (default prop)", id, want or -1, used))
				end
			end
		end
	end
end
check(count == 46, `{count} styles built, 46 expected`)

-- Kit.count agrees with Costumes.entryParts on every STYLE entry the Kit builds
if Costumes and Costumes.entryParts then
	local agreed = 0
	for _, id in ids do
		for _, e in STYLES[id].kit do
			if Kit.PIECES[e[1]] then
				local mine, theirs = Kit.count(e), Costumes.entryParts(e)
				check(mine == theirs, `{id} {e[1]}: Kit.count {mine}, Costumes.entryParts {theirs}`)
				agreed += 1
			end
		end
	end
	print(`Kit.count = Costumes.entryParts on {agreed} style entries (Costumes.effectiveLook used for the builds)`)
else
	print("NOTE Costumes not loaded: styles built from the raw Styles data")
end

-- props (§2.6, test 8): every key in Arsenals order exists, builds at most 3 parts, swaps cleanly
do
	local n = 0
	for style, a in Arsenals do
		for _, key in a.order do
			local spec = Costumes.ARSENAL_PROP[style] and Costumes.ARSENAL_PROP[style][key]
			check(spec ~= nil, `ARSENAL_PROP.{style}.{key} missing`)
			check((spec and spec.suit == true) == (style == "ironman"), `{style}.{key}: suit flag`)
			if spec and STYLES[style] then
				local model = dummy()
				Kit.build(model, Costumes.effectiveLook(style, "player"), { style = STYLES[style] })
				local before = #costumeParts(model)
				Kit.prop(model, style, key)
				Kit.prop(model, style, key) -- a second swap replaces, never stacks
				local folder = model.Costume:FindFirstChild("Prop")
				local got = if folder then #folder:GetChildren() else 0
				local inProp = 0
				if folder then
					for _, d in folder:GetDescendants() do
						if d:IsA("BasePart") then
							inProp += 1
						end
					end
				end
				check(inProp <= 3, `{style}.{key}: {inProp} prop parts`)
				check(inProp == (spec.pieces and #spec.pieces or 0), `{style}.{key}: {inProp} ~= spec`)
				check(got == inProp, `{style}.{key}: prop folder holds only parts`)
				check(#costumeParts(model) - before <= 3, `{style}.{key}: prop grew the costume past 3`)
				checkFlags(model, style .. "." .. key)
				check(#faceZoneViolations(model) == 0, `{style}.{key}: face zone`)
				if spec.glTint then
					for _, p in model.Costume:GetChildren() do
						if p.Name == "GL" then
							check(p.Color == Color3.fromRGB(0xd8, 0x68, 0x3a), `{style}.{key}: GL tape recoloured`)
						end
					end
					Kit.prop(model, style, "knife")
					for _, p in model.Costume:GetChildren() do
						if p.Name == "GL" then
							check(p.Color == Color3.fromRGB(0xe8, 0xe0, 0xd0), `{style}: GL tape restored`)
						end
					end
				end
				n += 1
			end
		end
	end
	print(`props: {n} Arsenal keys built`)
end

-- LP forms a V: each lapel's top sits further out than its bottom
do
	local model = dummy()
	local rig = Kit.rig(model)
	local b = Kit.new(model, 99)
	for _, p in Kit.PIECES.LP(b, rig, { "LP" }, LOOK) do
		local c0 = p:FindFirstChildOfClass("Weld").C0
		local up = c0.YVector * p.Size.Y / 2
		local top, bot = c0.Position + up, c0.Position - up
		check(math.abs(top.X) > math.abs(bot.X), `LP lapel top {top.X} not outside bottom {bot.X}`)
	end
end

-- BA tips end behind the back plane, z > +0.5 in UpperTorso space (§2.3 worked example)
do
	local model = dummy()
	local rig = Kit.rig(model)
	local b = Kit.new(model, 99)
	for _, entry in { { "BA", n = 8, segs = 2 }, { "BA", n = 12, segs = 3 } } do
		for _, p in Kit.PIECES.BA(b, rig, entry, LOOK) do
			local w = p:FindFirstChildOfClass("Weld")
			local axis = if p.ClassName == "Part" then w.C0.XVector else w.C0.YVector
			local len = if p.ClassName == "Part" then p.Size.X else p.Size.Y
			local tipA = w.C0.Position + axis * len / 2
			local tipB = w.C0.Position - axis * len / 2
			check(math.max(tipA.Z, tipB.Z) > 0.5, `BA segment ends behind the back ({tipA.Z}, {tipB.Z})`)
		end
	end
end

print(`\n{passes} checks passed, {failures} failed`)
process.exit(if failures == 0 then 0 else 1)
