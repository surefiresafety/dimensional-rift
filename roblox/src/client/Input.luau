--!strict
-- Keys to actions. ContextActionService also makes touch buttons for the
-- important ones, so the game is playable on a phone from the start.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signature = require(Shared.Signature)
local Arsenals = require(Shared.Data.Arsenals)

local Movement = require(script.Parent.Movement)
local Select = require(script.Parent.Select)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local CastRemote = Remotes.get("Cast")
local ActionRemote = Remotes.get("Action")

local Input = {}

--- Where the player is aiming: at the cursor on a computer, along the camera
--- everywhere else.
local function aim(): Vector3
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	if root and mouse.Hit then
		local to = mouse.Hit.Position - (root.Position + Vector3.new(0, 1.5, 0))
		if to.Magnitude > 1 then
			return to.Unit
		end
	end
	return cam.CFrame.LookVector
end

local function cast(which: number | string)
	if Select.isOpen() then
		return
	end
	CastRemote:FireServer(which, aim())
end

local function act(name: string)
	if Select.isOpen() or not player:GetAttribute("Style") then
		return
	end
	ActionRemote:FireServer(name, aim())
end

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

function Input.start()
	-- 1 to 5 are techniques here, not the tool hotbar.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	for i, key in KEYS do
		ContextActionService:BindAction("Slot" .. i, function(_, state)
			if state == Enum.UserInputState.Begin then
				cast(i)
			end
			return Enum.ContextActionResult.Sink
		end, true, key)
		ContextActionService:SetTitle("Slot" .. i, tostring(i))
	end
	ContextActionService:BindAction("Ultimate", function(_, state)
		if state == Enum.UserInputState.Begin then
			cast("ult")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.G)
	ContextActionService:SetTitle("Ultimate", "G")

	ContextActionService:BindAction("Signature", function(_, state)
		local kind = Movement.kind()
		if state == Enum.UserInputState.Begin then
			if kind == "swing" then
				if not Movement.startSwing() then
					Hud.log("No anchor in reach. Aim higher.")
				end
			elseif kind == "fly" then
				Movement.startFlight()
			else
				local style = player:GetAttribute("Style") :: string?
				local id = style and Signature[style]
				if id then
					cast(id)
				end
			end
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			if kind == "swing" then
				Movement.releaseSwing()
			elseif kind == "fly" then
				Movement.endFlight()
			end
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.E)
	ContextActionService:SetTitle("Signature", "E")

	-- The basic attack. A click is read through UserInputService so a click on
	-- the interface never swings; phones and pads get a button of their own.
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			act("strike")
		end
	end)
	ContextActionService:BindAction("Strike", function(_, state)
		if state == Enum.UserInputState.Begin then
			act("strike")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("Strike", "Hit")

	-- Hold B to power up; let go to store it for the next technique.
	ContextActionService:BindAction("Charge", function(_, state)
		if state == Enum.UserInputState.Begin then
			act("chargeStart")
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			ActionRemote:FireServer("chargeEnd")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.B)
	ContextActionService:SetTitle("Charge", "B")

	-- R: the next weapon, for a set that lives on R.
	ContextActionService:BindAction("Cycle", function(_, state)
		local style = player:GetAttribute("Style") :: string?
		local a = style and (Arsenals :: any)[style]
		if state == Enum.UserInputState.Begin and a and a.key == "r" then
			act("cycle")
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R)

	-- F: put a symbiote that came off back on.
	ContextActionService:BindAction("Rebond", function(_, state)
		if state == Enum.UserInputState.Begin and player:GetAttribute("LooseSuit") then
			act("rebond")
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F)

	ContextActionService:BindAction("Characters", function(_, state)
		if state == Enum.UserInputState.Begin and player:GetAttribute("Style") then
			Select.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)

	player.CharacterAdded:Connect(function()
		Movement.reset()
	end)
end

return Input
