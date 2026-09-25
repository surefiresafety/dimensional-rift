--!strict
-- Draws what the server says happened. Nothing here decides anything: shots
-- are replayed from the start and velocity the server used, and removed when
-- the server says they ended.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)

local Hud = require(script.Parent.Hud)
local Sfx = require(script.Parent.Sfx)

local Fx = {}

local dangerGui: ScreenGui? = nil

--- An attack winding up somewhere you cannot see: an arrow at the edge of
--- the screen pointing at it, for as long as the wind-up lasts. Only for
--- things close enough to matter.
function Fx.danger(at: Vector3, colour: number, duration: number)
	local c = Players.LocalPlayer.Character
	local me = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not me or (me.Position - at).Magnitude > 60 then
		return
	end
	local cam = workspace.CurrentCamera
	local _, onScreen = cam:WorldToViewportPoint(at)
	if onScreen then
		return
	end
	if not dangerGui then
		local g = Instance.new("ScreenGui")
		g.Name = "Danger"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 7
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		dangerGui = g
	end
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromOffset(48, 48)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Text = "▲"
	arrow.TextScaled = true
	arrow.Font = Enum.Font.GothamBold
	arrow.TextColor3 = Palette.color(colour)
	arrow.TextStrokeTransparency = 0.2
	arrow.Parent = dangerGui
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if os.clock() - started > duration or not arrow.Parent then
			conn:Disconnect()
			arrow:Destroy()
			return
		end
		-- Direction on the screen from the centre towards the threat.
		local rel = cam.CFrame:PointToObjectSpace(at)
		local dir = Vector2.new(rel.X, -rel.Y)
		if rel.Z > 0 then
			dir = Vector2.new(rel.X, math.abs(rel.Y) + 1) -- behind: point down
		end
		if dir.Magnitude < 1e-3 then
			dir = Vector2.new(0, 1)
		end
		dir = dir.Unit
		local size = cam.ViewportSize
		local half = size / 2 - Vector2.new(50, 50)
		local k = math.min(half.X / math.max(math.abs(dir.X), 1e-3), half.Y / math.max(math.abs(dir.Y), 1e-3))
		local p = size / 2 + dir * k
		arrow.Position = UDim2.fromOffset(p.X, p.Y)
		arrow.Rotation = math.deg(math.atan2(dir.X, -dir.Y))
		arrow.TextTransparency = 0.5 * math.abs(math.sin((os.clock() - started) * 14))
	end)
end

local layer = Instance.new("Folder")
layer.Name = "Fx"
layer.Parent = workspace

local function part(shape: Enum.PartType, size: Vector3, cf: CFrame, colour: number, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = Palette.color(colour)
	p.Material = Enum.Material.Neon
	p.Transparency = transparency or 0
	p.Parent = layer
	return p
end

local function fade(p: BasePart, time: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, time + 0.05)
end

-- Live shots, replayed on this machine.
local shots: { [string]: { part: Part, pos: Vector3, vel: Vector3, gravity: number, life: number } } = {}

local handlers: { [string]: (any) -> () } = {}

handlers.shot = function(d)
	local p = part(Enum.PartType.Ball, Vector3.one * d.radius * 2, CFrame.new(d.pos), d.color, 0)
	local halo = part(Enum.PartType.Ball, Vector3.one * d.radius * 3.6, CFrame.new(d.pos), d.color, 0.7)
	local w = Instance.new("WeldConstraint")
	halo.Anchored = false
	w.Part0, w.Part1 = p, halo
	w.Parent = halo
	halo.Massless = true
	halo.Parent = p -- goes when the shot goes
	shots[d.id] = { part = p, pos = d.pos, vel = d.vel, gravity = d.gravity, life = d.life }
end

handlers.shotEnd = function(d)
	local s = shots[d.id]
	if s then
		shots[d.id] = nil
		s.part:Destroy()
	end
	local pop = part(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(d.at), 0xffffff, 0.2)
	fade(pop, 0.25, Vector3.one * 7)
end

handlers.number = function(d)
	local anchor = part(Enum.PartType.Ball, Vector3.one * 0.1, CFrame.new(d.at), 0xffffff, 1)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.AlwaysOnTop = true
	bb.StudsOffset = Vector3.new(math.random() * 2 - 1, 1, 0)
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextSize = if d.tone == "se" then 30 else 22
	t.Text = d.text
	t.TextStrokeTransparency = 0.2
	t.TextColor3 = if d.tone == "se"
		then Color3.fromRGB(255, 213, 74)
		elseif d.tone == "nve" then Color3.fromRGB(170, 170, 170)
		elseif d.tone == "hurt" then Color3.fromRGB(255, 107, 107)
		elseif d.tone == "heal" then Color3.fromRGB(86, 227, 159)
		else Color3.new(1, 1, 1)
	t.Parent = bb
	TweenService:Create(bb, TweenInfo.new(1.1), { StudsOffset = bb.StudsOffset + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(
		t,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	Debris:AddItem(anchor, 1.2)
end

handlers.burst = function(d)
	for _ = 1, math.min(d.count or 12, 30) do
		local p = part(Enum.PartType.Ball, Vector3.one * 0.7, CFrame.new(d.at + Vector3.new(0, 2, 0)), d.color, 0)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		TweenService:Create(
			p,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad),
			{ Position = p.Position + dir * math.random(6, 14), Transparency = 1, Size = Vector3.one * 0.2 }
		):Play()
		Debris:AddItem(p, 0.5)
	end
end

handlers.ring = function(d)
	local cf = CFrame.new(d.at * Vector3.new(1, 0, 1) + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local size = Vector3.new(0.4, d.radius * 2, d.radius * 2)
	if d.implode then
		local p = part(Enum.PartType.Cylinder, size, cf, d.color, 0.3)
		fade(p, 0.9, Vector3.new(0.4, 1, 1))
	else
		local p = part(Enum.PartType.Cylinder, Vector3.new(0.4, 2, 2), cf, d.color, 0.2)
		fade(p, 0.5, size)
	end
end

handlers.beam = function(d)
	local length = (d.to - d.from).Magnitude
	local cf = CFrame.lookAt(d.from:Lerp(d.to, 0.5), d.to) * CFrame.Angles(0, math.pi / 2, 0)
	local p = part(Enum.PartType.Cylinder, Vector3.new(length, d.width * 2, d.width * 2), cf, d.color, 0.1)
	fade(p, d.life or 0.35, Vector3.new(length, 0.1, 0.1))
end

handlers.slash = function(d)
	local cf = CFrame.lookAt(d.at, d.at + d.dir) * CFrame.new(0, 0, -d.reach * 0.4)
	local p = part(
		Enum.PartType.Block,
		Vector3.new(d.reach * 1.4, 0.3, d.reach * 0.7),
		cf * CFrame.Angles(0, 0, math.rad(math.random(-25, 25))),
		d.color,
		0.15
	)
	fade(p, 0.22)
end

handlers.dash = function(d)
	local length = (d.to - d.from).Magnitude
	if length < 0.5 then
		return
	end
	local mid = d.from:Lerp(d.to, 0.5) + Vector3.new(0, 2, 0)
	local p = part(
		Enum.PartType.Block,
		Vector3.new(1.2, 1.2, length),
		CFrame.lookAt(mid, d.to + Vector3.new(0, 2, 0)),
		d.color,
		0.3
	)
	fade(p, 0.35, Vector3.new(0.1, 0.1, length))
end

-- Something picked up: a pop, and what it was worth for whoever took it.
handlers.pickup = function(d)
	local p = part(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(d.at + Vector3.new(0, 2, 0)), d.color, 0.2)
	fade(p, 0.3, Vector3.one * 6)
	if d.player == Players.LocalPlayer then
		handlers.number({ at = d.at + Vector3.new(0, 4, 0), text = d.text, tone = "heal" })
	end
end

-- It has seen you: a "!" over its head.
handlers.alert = function(d)
	local model = d.model :: Model?
	local head = model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(40, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "!"
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.TextColor3 = Palette.color(d.color or 0xffd54a)
	t.TextStrokeTransparency = 0
	t.Parent = bb
	bb.Parent = layer
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = t
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.1, function()
		TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(bb, 0.35)
	end)
end

-- What it is about to do: a ring on the ground under it that pulses until
-- the attack comes. Red a swing, yellow a shot, orange a charge.
handlers.telegraph = function(d)
	local model = d.model :: Model?
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root and d.at then
		-- A fixed spot on the ground (a volatile elite's blast).
		local spot = Instance.new("Part")
		spot.Anchored = true
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanQuery = false
		spot.Size = Vector3.one
		spot.CFrame = CFrame.new(d.at * Vector3.new(1, 0, 1) + Vector3.new(0, 2.8, 0))
		spot.Parent = layer
		Debris:AddItem(spot, (d.duration or 1) + 0.5)
		root = spot
	end
	if not root then
		return
	end
	local duration = math.max(0.15, d.duration or 0.7)
	-- At its feet, however tall it is.
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local drop = if hum then hum.HipHeight + root.Size.Y / 2 - 0.2 else 2.6
	local ring = part(
		Enum.PartType.Cylinder,
		Vector3.new(0.3, d.radius * 2, d.radius * 2),
		CFrame.new(root.Position.X, root.Position.Y - drop, root.Position.Z) * CFrame.Angles(0, 0, math.pi / 2),
		d.color,
		0.55
	)
	Fx.danger(root.Position, d.color, duration)
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= duration or not root.Parent then
			conn:Disconnect()
			fade(ring, 0.15, Vector3.new(0.3, d.radius * 2.6, d.radius * 2.6))
			return
		end
		ring.CFrame = CFrame.new(root.Position.X, root.Position.Y - drop, root.Position.Z)
			* CFrame.Angles(0, 0, math.pi / 2)
		-- Faster and brighter as the hit gets closer.
		ring.Transparency = 0.15 + 0.5 * math.abs(math.sin(t * (10 + 25 * t / duration)))
	end)
end

handlers.banner = function(d)
	Hud.banner(d.text, d.color)
end

local function follow(
	player: Player,
	colour: number,
	duration: number,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	transparency: number
)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local p = part(shape, size, root.CFrame * offset, colour, transparency)
	p.Anchored = false
	p.Massless = true
	p.Material = Enum.Material.ForceField
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, p
	w.Parent = p
	task.delay(duration, function()
		if p.Parent then
			fade(p, 0.4)
		end
	end)
end

handlers.aura = function(d)
	follow(
		d.player,
		d.color,
		d.duration,
		Enum.PartType.Cylinder,
		Vector3.new(0.3, 9, 9),
		CFrame.new(0, -2.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
		0.2
	)
end

handlers.shield = function(d)
	follow(d.player, d.color, d.duration, Enum.PartType.Ball, Vector3.one * 9, CFrame.new(), 0.3)
end

local function tint(colour: number, duration: number, brightness: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = Palette.color(colour):Lerp(Color3.new(1, 1, 1), 0.55)
	cc.Brightness = brightness
	cc.Parent = Lighting
	TweenService:Create(
		cc,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, math.max(0, duration - 0.6)),
		{ TintColor = Color3.new(1, 1, 1), Brightness = 0 }
	):Play()
	Debris:AddItem(cc, duration + 0.1)
end

handlers.flash = function(d)
	tint(d.color, d.duration or 1, 0.15)
end

handlers.domain = function(d)
	Hud.banner(d.title, d.edge)
	tint(d.color, d.duration, -0.05)
	if not d.open then
		local dome = part(Enum.PartType.Ball, Vector3.one * 4, CFrame.new(d.at), d.color, 0.25)
		dome.Material = Enum.Material.ForceField
		TweenService:Create(dome, TweenInfo.new(0.8, Enum.EasingStyle.Back), { Size = Vector3.one * d.radius * 2 })
			:Play()
		task.delay(d.duration, function()
			fade(dome, 0.6)
		end)
	end
	local floor = part(
		Enum.PartType.Cylinder,
		Vector3.new(0.3, d.radius * 2, d.radius * 2),
		CFrame.new(d.at * Vector3.new(1, 0, 1) + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		d.floor,
		0.35
	)
	task.delay(d.duration, function()
		fade(floor, 0.6)
	end)
end

function Fx.start()
	Remotes.get("Fx").OnClientEvent:Connect(function(kind: string, payload: any)
		local h = handlers[kind]
		if h then
			h(payload)
		end
		Sfx.forFx(kind, payload)
	end)
	RunService.RenderStepped:Connect(function(dt)
		-- The arena's weather falls round this player: keep its emitter over
		-- the camera (a local move; the server's copy stays put).
		local arena = workspace:FindFirstChild("Arena")
		local sky = arena and arena:FindFirstChild("Weather") :: BasePart?
		if sky then
			sky.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 30, 0))
		end
		for id, s in shots do
			s.vel -= Vector3.new(0, s.gravity * dt, 0)
			s.pos += s.vel * dt
			s.life -= dt
			s.part.CFrame = CFrame.new(s.pos)
			if s.life <= 0 then
				shots[id] = nil
				s.part:Destroy()
			end
		end
	end)
end

return Fx
