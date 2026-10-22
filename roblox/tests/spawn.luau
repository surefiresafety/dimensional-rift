--!nocheck
-- Runs the real spawn and dress paths (docs/design/characters.md §6.2) on real Roblox instances
-- (Lune), with what Lune cannot provide stubbed: services, physics, animation, remotes, events.
--   lune run tests/spawn   (from the roblox folder; builds build/spawn-test.rbxl with rojo)
-- Checks: Enemies.spawn for every enemy id (normal / alpha / charBoss / finale as the data has
-- them), every id as an elite with each affix and as a stitched elite; no runtime error, the
-- §6.3 caps, e.pal / NatureColor, the Highlight budget (§6.4), Combat.kill leaving the costume
-- to the client (Dying), the Tell attribute, summons; every player style dressed through
-- Looks.dressPlayer with its Weapon and Suit listeners; the ward and Kit.ally; Hyakunui phases.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Instance, Vector3, CFrame, Color3, Enum =
	roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

-- the place ----------------------------------------------------------------------------------
local placeFile = "build/spawn-test.rbxl"
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
local RS = place:GetService("ReplicatedStorage")
local Shared = RS:FindFirstChild("Shared")
local Server = place:GetService("ServerScriptService"):FindFirstChild("Server")

-- what Lune lacks ----------------------------------------------------------------------------
local clock = 0
local function signal()
	local s = { fns = {} }
	function s:Connect(fn)
		local c = { Connected = true }
		function c.Disconnect()
			c.Connected = false
		end
		table.insert(s.fns, { fn = fn, c = c })
		return c
	end
	function s:Fire(...)
		for _, h in table.clone(s.fns) do
			if h.c.Connected then
				h.fn(...)
			end
		end
	end
	function s:live()
		local n = 0
		for _, h in s.fns do
			if h.c.Connected then
				n += 1
			end
		end
		return n
	end
	return s
end
local destroying = setmetatable({}, { __mode = "k" })
local attrSignals = setmetatable({}, { __mode = "k" })
roblox.implementMethod("Instance", "WaitForChild", function(self, n)
	return self:FindFirstChild(n)
end)
roblox.implementProperty("Instance", "Destroying", function(self)
	destroying[self] = destroying[self] or signal()
	return destroying[self]
end)
roblox.implementProperty("Instance", "AttributeChanged", function(self)
	attrSignals[self] = attrSignals[self] or signal()
	return attrSignals[self]
end)
roblox.implementMethod("Model", "PivotTo", function(self, cf)
	local root = self:FindFirstChild("HumanoidRootPart") or self:FindFirstChildWhichIsA("BasePart")
	if not root then
		return
	end
	local delta = cf * root.CFrame:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
			d.Position = d.CFrame.Position -- Lune stores Position separately
		end
	end
end)
roblox.implementMethod("BasePart", "SetNetworkOwner", function() end)
roblox.implementProperty("BasePart", "Position", function(self)
	return self.CFrame.Position
end, function(self, v)
	self.CFrame = CFrame.new(v) * self.CFrame.Rotation
end)
roblox.implementMethod("BasePart", "ApplyImpulse", function() end)
roblox.implementProperty("BasePart", "AssemblyLinearVelocity", function()
	return Vector3.zero
end, function() end)
roblox.implementProperty("BasePart", "AssemblyMass", function()
	return 1
end)
roblox.implementMethod("Humanoid", "MoveTo", function() end)
roblox.implementMethod("Humanoid", "ApplyDescriptionAsync", function() end)
roblox.implementMethod("Animator", "LoadAnimation", function()
	return {
		Play = function() end,
		Stop = function() end,
		AdjustSpeed = function() end,
	}
end)
local fired = {}
roblox.implementMethod("RemoteEvent", "FireAllClients", function(_, kind, payload)
	table.insert(fired, { kind = kind, payload = payload })
end)
roblox.implementMethod("RemoteEvent", "FireClient", function() end)
roblox.implementProperty("RemoteEvent", "OnServerEvent", function()
	return signal()
end)

-- workspace: a Model with the members the server modules use
local ws = Instance.new("Model")
ws.Name = "Workspace"
roblox.implementMethod("Model", "GetServerTimeNow", function()
	return clock
end)
roblox.implementMethod("Model", "Raycast", function()
	return nil
end)
roblox.implementMethod("Model", "Spherecast", function()
	return nil
end)
roblox.implementMethod("Model", "GetPartsInPart", function()
	return {}
end)

-- a dummy R15 rig from a HumanoidDescription --------------------------------------------------
local LAYOUT = {
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
local Kit -- set after loading
local descriptions = 0
local function rigFrom(d)
	descriptions += 1
	local scale = Vector3.new(d.WidthScale, d.HeightScale, d.DepthScale)
	local model = Instance.new("Model")
	model.Name = "Rig"
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 2 * scale.Y
	hum.Parent = model
	Instance.new("Animator").Parent = hum
	for _, row in LAYOUT do
		local p = Instance.new("Part")
		p.Name = row[1]
		p.Size = if row[1] == "Head" then row[2] * d.HeadScale else row[2] * scale
		p.CFrame = CFrame.new(row[3] * scale)
		p.Position = row[3] * scale
		pcall(function()
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyMass = 1
		end)
		p.Transparency = if row[1] == "HumanoidRootPart" then 1 else 0
		p.Parent = model
	end
	local lt, ut = model:FindFirstChild("LowerTorso"), model:FindFirstChild("UpperTorso")
	local root = Instance.new("Motor6D")
	root.Name = "Root"
	root.Part0 = model:FindFirstChild("HumanoidRootPart")
	root.Part1 = lt
	root.Parent = lt
	local _ = ut
	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
	for name, a in Kit.ATTACH do
		local host = model:FindFirstChild(a.host)
		local att = Instance.new("Attachment")
		att.Name = name
		att.CFrame = CFrame.new(a.pos * (if a.host == "Head" then Vector3.one * d.HeadScale else scale))
		att.Parent = host
	end
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Parent = model:FindFirstChild("Head")
	return model
end

-- services and the loader ---------------------------------------------------------------------
local tweens = {}
local services = {
	ReplicatedStorage = RS,
	CollectionService = {
		AddTag = function(_, inst, tag)
			inst:AddTag(tag)
		end,
		GetTagged = function()
			return {}
		end,
	},
	TweenService = {
		Create = function(_, inst, _info, goal)
			local t = { inst = inst, goal = goal }
			function t.Play()
				table.insert(tweens, t)
			end
			return t
		end,
	},
	RunService = {
		IsServer = function()
			return true
		end,
		IsStudio = function()
			return false
		end,
	},
	Players = {
		CreateHumanoidModelFromDescription = function(_, d)
			return rigFrom(d)
		end,
		GetPlayers = function()
			return {}
		end,
	},
	PathfindingService = {
		CreatePath = function()
			return {}
		end,
	},
	HttpService = {
		GenerateGUID = function()
			return tostring(math.random())
		end,
	},
}
local fakeGame = {
	GetService = function(_, n)
		return services[n] or error("no service " .. n)
	end,
}
local fakeTask = {
	delay = function(_, fn, ...)
		return nil -- deferred work (fades, model destruction) is not run here
	end,
	spawn = function(fn, ...)
		return fn(...)
	end,
	wait = function()
		return 0
	end,
	defer = function(fn, ...)
		return fn(...)
	end,
}
local _ = task

local cache = {}
local function load(mod)
	if cache[mod] ~= nil then
		return cache[mod]
	end
	local env = setmetatable({
		script = mod,
		game = fakeGame,
		workspace = ws,
		require = function(m)
			return load(m)
		end,
		task = fakeTask,
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
		TweenInfo = {
			new = function(...)
				return { ... }
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		OverlapParams = {
			new = function()
				return {}
			end,
		},
		warn = function(...)
			print("WARN", ...)
		end,
	}, { __index = _G })
	local fn = luau.load(mod.Source, { debugName = mod:GetFullName(), environment = env })
	local r = fn()
	cache[mod] = r
	return r
end

Kit = load(Server.Kit)
local Costumes = load(Shared.Costumes)
local Rules = load(Shared.Rules)
local Combat = load(Server.Combat)
local Looks = load(Server.Looks)
local Enemies = load(Server.Enemies)
local Finale = load(Shared.Finale)
local EnemyData = load(Shared.Data.Enemies)
local Arsenals = load(Shared.Data.Arsenals)

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

local function partsOf(model)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end
local CAP = { the_unbidden = 29, grey = 21, grey_alpha = 21 }

local function reset()
	for _, e in table.clone(Combat.enemies) do
		Enemies.releaseHighlight(e.model)
		e.dead = true
	end
	table.clear(Combat.enemies)
	for _, name in { "Enemies", "Worn" } do
		local f = ws:FindFirstChild(name)
		if f then
			f:ClearAllChildren()
		end
	end
end

local ids = {}
for id in EnemyData do
	table.insert(ids, id)
end
for id in Finale.ENEMIES do
	table.insert(ids, id)
end
table.sort(ids)

local roleSeen = {}
local maxParts = {}
local function spawnOne(id, affix, label)
	reset()
	local ok, e = pcall(Enemies.spawn, id, Vector3.new(0, 0, 0), affix)
	check(ok, `{label} {id}: Enemies.spawn errored: {e}`)
	if not ok then
		return nil
	end
	check(e ~= nil, `{label} {id}: no enemy`)
	if not e then
		return nil
	end
	local role = e.model:GetAttribute("Role")
	roleSeen[role] = (roleSeen[role] or 0) + 1
	local cap = CAP[id] or 30
	local n = partsOf(e.model)
	maxParts[role] = math.max(maxParts[role] or 0, n)
	check(n <= cap, `{label} {id} ({role}): {n} parts > {cap}`)
	check(e.model:FindFirstChild("Costume") ~= nil or id == "grey", `{label} {id}: no Costume`)
	check(type(e.pal) == "table" and type(e.pal.base) == "number", `{label} {id}: no e.pal`)
	check(e.model:GetAttribute("NatureColor") == e.pal.nature, `{label} {id}: NatureColor`)
	if affix then
		check(
			e.pal.base ~= affix.color or (EnemyData[id] or {}).color == affix.color,
			`{label} {id}: pal.base is the affix colour`
		)
	end
	local head = e.model:FindFirstChild("Head")
	check(not (head and head:FindFirstChild("face")), `{label} {id}: default face decal kept`)
	for _, d in e.model:GetDescendants() do
		if
			d:IsA("BasePart")
			and d:IsDescendantOf(e.model:FindFirstChild("Costume") or e.model)
			and d.Parent ~= e.model
		then
			if d.CanQuery or d.CanCollide then
				check(false, `{label} {id}: costume part {d.Name} collides or queries`)
				break
			end
		end
	end
	return e
end

-- every id as the data has it (normal, alpha, charBoss, finale)
local plain = 0
for _, id in ids do
	if spawnOne(id, nil, "plain") then
		plain += 1
	end
end
print(("plain spawns: %d ids"):format(plain))

-- every non-boss id as an elite with each affix, and stitched
local eliteRuns = 0
for _, id in ids do
	local t = EnemyData[id]
	if t and not t.boss then
		for _, affix in Rules.AFFIXES do
			Enemies.stitched = false
			if spawnOne(id, affix, "elite/" .. affix.name) then
				eliteRuns += 1
			end
		end
		Enemies.stitched = true
		local e = spawnOne(id, Rules.AFFIXES[1], "stitched")
		if e then
			check(e.stitched == true, `stitched {id}: not marked stitched`)
			check(e.model:FindFirstChildOfClass("Highlight") == nil, `stitched {id}: has a Highlight`)
		end
		Enemies.stitched = false
	end
end
print(("elite spawns: %d"):format(eliteRuns))
for r, n in maxParts do
	print(("  most parts as %-8s %d"):format(r, n))
end
for _, r in { "normal", "alpha", "charBoss", "finale", "elite" } do
	check((roleSeen[r] or 0) > 0, "no spawn ran in role " .. r)
end

-- Highlight budget (§6.4) -----------------------------------------------------------------------
do
	reset()
	local Config = load(Shared.Config)
	local elite
	for _, id in ids do
		local t = EnemyData[id]
		if t and not t.boss and t.shape == "human" then
			elite = id
			break
		end
	end
	for _ = 1, Config.MAX_ENEMIES - 2 do
		Enemies.spawn(elite, Vector3.zero, Rules.AFFIXES[1])
	end
	check(Enemies.highlightCount() <= 12, "elite Highlights over 12: " .. Enemies.highlightCount())
	check(Enemies.highlightCount() == 12, "elites did not fill the Highlight budget: " .. Enemies.highlightCount())
	local boss = Enemies.spawn("hyakunui", Vector3.zero)
	check(boss and boss.model:FindFirstChildOfClass("Highlight") ~= nil, "finale boss without a Highlight")
	check(Enemies.highlightCount() <= 16, "Highlights over 16")
	-- kill one: costume left to the client, Highlight released
	local before = Enemies.highlightCount()
	table.clear(tweens)
	local victim = boss
	Combat.kill(victim, nil)
	check(victim.model:GetAttribute("Dying") == true, "kill: Dying not set")
	check(Enemies.highlightCount() == before - 1, "kill: Highlight not released")
	local costume = victim.model:FindFirstChild("Costume")
	local touched = 0
	for _, t in tweens do
		if costume and t.inst:IsDescendantOf(costume) then
			touched += 1
		end
	end
	check(#tweens > 0 and touched == 0, ("kill: server tweened %d costume parts (%d tweens)"):format(touched, #tweens))
	reset()
	check(Enemies.highlightCount() == 0, "Highlights leaked: " .. Enemies.highlightCount())
end

-- Tell attribute (§5.2) ---------------------------------------------------------------------------
do
	reset()
	local fox = Enemies.spawn("tempest_fox", Vector3.zero)
	local FinaleKit = load(Server.Kit.Finale)
	FinaleKit.setTell(fox.model, FinaleKit.tellAction("tell"))
	check(fox.model:GetAttribute("Tell") == true, "Tell not set on tell")
	FinaleKit.setTell(fox.model, FinaleKit.tellAction("cancel"))
	check(fox.model:GetAttribute("Tell") == false, "Tell not cleared on cancel")
	-- Hyakunui phases
	local h = Enemies.spawn("hyakunui", Vector3.zero)
	for phase = 1, 3 do
		local ok, err = pcall(Looks.finalePhase, h.model, phase)
		check(ok, "finalePhase " .. phase .. ": " .. tostring(err))
		check(partsOf(h.model) <= 30, "Hyakunui phase " .. phase .. " over 30 parts")
	end
	-- the Unbidden's Adapted_ attribute
	local u = Enemies.spawn("the_unbidden", Vector3.zero)
	u.model:SetAttribute("Adapted_fire", true)
	local ok, err = pcall(FinaleKit.applyAdapted, u.model)
	check(ok, "applyAdapted: " .. tostring(err))
end

-- summons pass stitchedParent -------------------------------------------------------------------
do
	reset()
	local child = Enemies.spawn(ids[1], Vector3.zero, nil, nil, { stitchedParent = true })
	check(child ~= nil, "summon with stitchedParent did not spawn")
	if child then
		local strips = 0
		for _, d in child.model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "STRIP" then
				strips += 1
			end
		end
		check(strips > 0 or child.model:GetAttribute("Stitched") == true, "stitched summon has no stitched look")
		check(partsOf(child.model) <= 30, "stitched summon over 30 parts")
	end
end

-- Kit.ally on a worn body and the ward (§4.5, §4.6) ---------------------------------------------
do
	reset()
	local e = Enemies.spawn(ids[1], Vector3.zero, Rules.AFFIXES[1])
	Combat.take(e)
	local ok, err = pcall(Kit.ally, e.model, Enemies.releaseHighlight)
	check(ok, "Kit.ally: " .. tostring(err))
	check(e.model:GetAttribute("Worn") == true, "Kit.ally: not Worn")
	check(e.model:FindFirstChildOfClass("Highlight") == nil, "Kit.ally: Highlight kept")
	local okW, ward = pcall(Looks.buildAlly, "the_unbidden", 1.3)
	check(okW, "buildAlly: " .. tostring(ward))
	if okW then
		check(partsOf(ward) <= 30, "ward: " .. partsOf(ward) .. " parts > 30")
		check(ward:HasTag("Ward"), "ward not tagged")
	end
end

-- players: every style through Looks.dressPlayer -----------------------------------------------
local function fakePlayer()
	local p = { attrs = {}, signals = {}, Character = nil, UserId = 1 }
	function p:SetAttribute(k, v)
		local old = self.attrs[k]
		self.attrs[k] = v
		if old ~= v and self.signals[k] then
			self.signals[k]:Fire()
		end
	end
	function p:GetAttribute(k)
		return self.attrs[k]
	end
	function p:GetAttributeChangedSignal(k)
		self.signals[k] = self.signals[k] or signal()
		return self.signals[k]
	end
	function p:LoadCharacterWithHumanoidDescriptionAsync(d)
		if self.Character then
			local old = self.Character
			if destroying[old] then
				destroying[old]:Fire()
			end
			old:Destroy()
		end
		self.Character = rigFrom(d)
		self.Character.Parent = ws
	end
	return p
end

local styles = {}
for id in Costumes.STYLE do
	table.insert(styles, id)
end
table.sort(styles)
local dressed = 0
for _, styleId in styles do
	local p = fakePlayer()
	local set = Arsenals[styleId]
	local first = set and set.order[1] or nil
	local ok, err = pcall(Looks.dressPlayer, p, styleId, first)
	check(ok, `player {styleId}: dressPlayer errored: {err}`)
	if ok then
		dressed += 1
		local c = p.Character
		check(partsOf(c) <= 30, `player {styleId}: {partsOf(c)} parts > 30`)
		check(c:GetAttribute("Weapon") == first, `player {styleId}: Weapon attribute not set before the build`)
		local head = c:FindFirstChild("Head")
		check(not head:FindFirstChild("face"), `player {styleId}: default face kept`)
		-- the Weapon listener: every key in the set
		if set then
			for _, key in set.order do
				local okW, errW = pcall(p.SetAttribute, p, "Weapon", key)
				check(okW, `player {styleId}: Weapon {key}: {errW}`)
				check(partsOf(p.Character) <= 30, `player {styleId} with {key}: over 30 parts`)
				local spec = Costumes.ARSENAL_PROP[styleId] and Costumes.ARSENAL_PROP[styleId][key]
				if spec and not spec.suit and spec.pieces and #spec.pieces > 0 then
					local costume = p.Character:FindFirstChild("Costume")
					local prop = costume and costume:FindFirstChild("Prop")
					check(prop and #prop:GetChildren() > 0, `player {styleId}: Weapon {key} mounted no prop`)
				end
			end
		end
		-- the Suit listener: edge-triggered, suitTN styles only
		local look = Costumes.effectiveLook(styleId, "player")
		if look.suitTN then
			local function tn()
				local costume = c:FindFirstChild("Costume")
				local f = costume and costume:FindFirstChild("SuitTN")
				return f and #f:GetChildren() or 0
			end
			p:SetAttribute("Suit", 260)
			local on = tn()
			check(on > 0, `player {styleId}: suit on mounted no TN`)
			p:SetAttribute("Suit", 251)
			check(tn() == on, `player {styleId}: a hit remounted the TN`)
			p:SetAttribute("Suit", 0)
			check(tn() == 0, `player {styleId}: suit off kept the TN`)
			p:SetAttribute("Suit", 30)
			check(tn() == on, `player {styleId}: suit back on`)
			check(partsOf(c) <= 30, `player {styleId} with suit: over 30 parts`)
		else
			check(
				p.signals.Suit == nil or p.signals.Suit:live() == 0,
				`player {styleId}: Suit listener on a non-suit style`
			)
		end
		-- listeners go with the character
		local w = p.signals.Weapon
		check(w and w:live() == 1, `player {styleId}: Weapon listener count {w and w:live()}`)
		Looks.dressPlayer(p, styleId, first)
		check(w:live() == 1, `player {styleId}: listeners leaked across respawns ({w:live()})`)
	end
end
print(("players dressed: %d styles"):format(dressed))

print(("\n%d passed, %d failed"):format(passes, failures))
if failures > 0 then
	process.exit(1)
end
