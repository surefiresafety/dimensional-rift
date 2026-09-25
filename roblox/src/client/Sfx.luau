--!strict
-- Sound and camera shake. Sounds come from Config.SOUNDS; each name plays at
-- most every 60 ms so a burst of twenty hits is one crunch, not twenty. A
-- sound with a position plays in the world; without one it plays flat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Sfx = {}

local last: { [string]: number } = {}
local shake = 0

local holder = Instance.new("Part")
holder.Name = "SfxAnchor"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.Transparency = 1
holder.Size = Vector3.one
holder.Parent = workspace

--- Plays a named sound, at a place if given. `pitch` varies it a little.
function Sfx.play(name: string, at: Vector3?, pitch: number?)
	local def = (Config.SOUNDS :: any)[name]
	if not def then
		return
	end
	local now = os.clock()
	if now - (last[name] or 0) < 0.06 then
		return
	end
	last[name] = now
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = def.volume or 0.5
	s.PlaybackSpeed = (pitch or 1) * (0.94 + math.random() * 0.12)
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = holder
		s.RollOffMaxDistance = 300
		s.Parent = a
		s.Ended:Connect(function()
			a:Destroy()
		end)
		task.delay(8, function()
			a:Destroy()
		end)
	else
		s.Parent = SoundService
		s.Ended:Connect(function()
			s:Destroy()
		end)
		task.delay(8, function()
			s:Destroy()
		end)
	end
	s:Play()
end

--- Shakes the camera; strengths add up and fade over about half a second.
function Sfx.shake(amount: number)
	shake = math.min(1.2, shake + amount)
end

local function myRoot(): BasePart?
	local c = Players.LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(at: Vector3?, studs: number): boolean
	local r = myRoot()
	return r ~= nil and at ~= nil and (r.Position - at).Magnitude < studs
end

--- The sound (and shake) for an Fx event.
function Sfx.forFx(kind: string, d: any)
	if kind == "burst" then
		local big = (d.count or 0) >= 16
		Sfx.play(if big then "heavy" else "hit", d.at, if big then 0.8 else 1.2)
		if big and near(d.at, 40) then
			Sfx.shake(0.25)
		end
	elseif kind == "slash" then
		Sfx.play("slash", d.at)
	elseif kind == "dash" then
		Sfx.play("dash", d.from)
	elseif kind == "beam" then
		Sfx.play("beam", d.from, 0.8)
	elseif kind == "shot" then
		Sfx.play("shot", d.pos, 1.3)
	elseif kind == "number" and d.tone == "hurt" and near(d.at, 8) then
		Sfx.play("hurt", nil, 0.9)
		Sfx.shake(0.35)
	elseif kind == "alert" then
		-- Only for enemies near enough to matter to this player.
		local m = d.model :: Model?
		local r = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and near(r.Position, 60) then
			Sfx.play("alert", r.Position, 1.6)
		end
	elseif kind == "telegraph" then
		local m = d.model :: Model?
		local r = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and near(r.Position, 30) then
			Sfx.play("warn", r.Position, 0.7)
		end
	elseif kind == "domain" then
		Sfx.play("domain")
		Sfx.shake(0.6)
	elseif kind == "pickup" and d.player == Players.LocalPlayer then
		Sfx.play("pickup", nil, 1.5)
	elseif kind == "banner" then
		Sfx.play("banner")
	end
end

-- Shake through the humanoid's camera offset rather than the camera itself:
-- the camera scripts read their own CFrame back next frame, so rotating it
-- would leave the aim drifting after every shake.
RunService.RenderStepped:Connect(function(dt: number)
	local c = Players.LocalPlayer.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if shake <= 0.001 then
		if shake > 0 or hum.CameraOffset.Magnitude > 0 then
			shake = 0
			hum.CameraOffset = Vector3.zero
		end
		return
	end
	local s = shake * shake * 1.2
	hum.CameraOffset =
		Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, (math.random() - 0.5) * s * 0.5)
	shake = math.max(0, shake - dt * 2.2)
end)

return Sfx
