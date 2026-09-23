--!strict
-- The E key's movement signatures, run on the client because the client owns
-- its own character's physics (anything it does to its HumanoidRootPart
-- replicates).
--
-- Swing: the web build's anchor search, a fan of rays above the aim that
-- prefers the highest hit, then a real RopeConstraint, so the arc is Roblox's
-- own pendulum. Flight: a LinearVelocity along the camera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RulesData = require(Shared.Data.Rules)

local STUDS = Config.STUDS_PER_UNIT
local ROPE_REACH = 60 * STUDS

local player = Players.LocalPlayer
local Movement = {}

local swing: { anchor: Part, rope: RopeConstraint, a0: Attachment }? = nil
local flight: { lv: LinearVelocity, a0: Attachment, conn: RBXScriptConnection }? = nil

local function parts(): (Humanoid?, BasePart?)
	local c = player.Character
	if not c then
		return nil, nil
	end
	return c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Movement.kind(): string?
	local style = player:GetAttribute("Style") :: string?
	return style and RulesData.E_ACTION[style]
end

local function findAnchor(root: BasePart): Vector3?
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		look = root.CFrame.LookVector
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis).Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { player.Character :: Instance }
	for _, name in { "Enemies", "Fx" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	local best, bestScore = nil, -math.huge
	for i = 0, 8 do
		local elevation = math.rad(25 + 55 * i / 8)
		for _, yaw in { -0.9, -0.45, 0, 0.45, 0.9 } do
			local flat = CFrame.fromAxisAngle(Vector3.yAxis, yaw) * look
			local dir = (CFrame.fromAxisAngle(right, elevation) * flat).Unit
			local hit = workspace:Raycast(root.Position, dir * ROPE_REACH, params)
			if hit and hit.Position.Y > root.Position.Y + 4 * STUDS then
				-- Prefer height, then how far ahead it is: a long arc, not a wall in your face.
				local score = hit.Position.Y * 2 + (hit.Position - root.Position):Dot(look)
				if score > bestScore then
					best, bestScore = hit.Position, score
				end
			end
		end
	end
	return best
end

function Movement.startSwing(): boolean
	local hum, root = parts()
	if not hum or not root or swing then
		return false
	end
	local at = findAnchor(root)
	if not at then
		return false
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = workspace
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor
	local a0 = Instance.new("Attachment")
	a0.Name = "SwingAttachment"
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = root
	local rope = Instance.new("RopeConstraint")
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Length = (at - root.Position).Magnitude * 0.92
	rope.Visible = true
	rope.Color = BrickColor.new("Institutional white")
	rope.Thickness = 0.12
	rope.Parent = root
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	-- A push along the aim gets the pendulum going.
	local look = workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.01 then
		root.AssemblyLinearVelocity += look.Unit * 30
	end
	swing = { anchor = anchor, rope = rope, a0 = a0 }
	return true
end

function Movement.releaseSwing()
	local s = swing
	if not s then
		return
	end
	swing = nil
	s.rope:Destroy()
	s.a0:Destroy()
	s.anchor:Destroy()
	local _, root = parts()
	if root then
		root.AssemblyLinearVelocity += Vector3.new(0, 25, 0)
	end
end

function Movement.startFlight()
	local hum, root = parts()
	if not hum or not root or flight then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "FlightAttachment"
	a0.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = a0
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.new(0, 20, 0)
	lv.Parent = root
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	local conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local moving = hum.MoveDirection.Magnitude > 0.1
		lv.VectorVelocity = if moving then cam.CFrame.LookVector * 70 else Vector3.new(0, 1.5, 0)
	end)
	flight = { lv = lv, a0 = a0, conn = conn }
end

function Movement.endFlight()
	local f = flight
	if not f then
		return
	end
	flight = nil
	f.conn:Disconnect()
	f.lv:Destroy()
	f.a0:Destroy()
end

--- Drops whatever is holding the character up (on death or a style change).
function Movement.reset()
	Movement.releaseSwing()
	Movement.endFlight()
end

return Movement
