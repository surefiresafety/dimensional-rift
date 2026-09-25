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
local Config = require(Shared.Config)
local Arsenals = require(Shared.Data.Arsenals)
local Styles = require(Shared.Data.Styles)

local Movement = require(script.Parent.Movement)
local Select = require(script.Parent.Select)
local Hud = require(script.Parent.Hud)
local Hub = require(script.Parent.Hub)
local Loadout = require(script.Parent.Loadout)
local TouchPad = require(script.Parent.TouchPad)

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

--- A screen is up: keys and clicks go to it, not to the fight.
local function menuOpen(): boolean
	return Select.isOpen() or Hub.isOpen() or Loadout.isOpen()
end

local function cast(which: number | string)
	if menuOpen() then
		return
	end
	CastRemote:FireServer(which, aim())
end

local function act(name: string)
	if menuOpen() or not player:GetAttribute("Style") then
		return
	end
	ActionRemote:FireServer(name, aim())
end

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

--- E: swing, fly, or the character's signature technique.
local function signature(down: boolean)
	local kind = Movement.kind()
	if down then
		if menuOpen() then
			return
		end
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
	elseif kind == "swing" then
		Movement.releaseSwing()
	elseif kind == "fly" then
		Movement.endFlight()
	end
end

-- Q: dodge the way you are moving (or facing), with a moment of
-- invulnerability. The client moves itself; the server grants the i-frames.
local lastDodge = 0
local function dodge()
	if menuOpen() or not player:GetAttribute("Style") then
		return
	end
	local now = os.clock()
	if now - lastDodge < Config.DODGE_COOLDOWN then
		return
	end
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return
	end
	lastDodge = now
	local dir = hum.MoveDirection * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	dir = dir.Unit
	ActionRemote:FireServer("dodge", dir)
	local speed = Config.DODGE_SPEED * Config.STUDS_PER_UNIT
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < Config.DODGE_TIME and root.Parent do
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, math.min(v.Y, 8), dir.Z * speed)
			task.wait()
		end
	end)
end

--- B: hold to power up, let go to store it for the next technique.
local function charge(down: boolean)
	if down then
		act("chargeStart")
	else
		ActionRemote:FireServer("chargeEnd")
	end
end

function Input.start()
	-- 1 to 5 are techniques here, not the tool hotbar.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	-- Touch screens get the TouchPad instead of ContextActionService's buttons.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touch then
		TouchPad.build({
			cast = cast,
			strike = function()
				act("strike")
			end,
			signature = signature,
			charge = charge,
			dodge = dodge,
		})
	end
	for i, key in KEYS do
		ContextActionService:BindAction("Slot" .. i, function(_, state)
			if state == Enum.UserInputState.Begin then
				cast(i)
			end
			return Enum.ContextActionResult.Sink
		end, false, key)
	end
	ContextActionService:BindAction("Ultimate", function(_, state)
		if state == Enum.UserInputState.Begin then
			cast("ult")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonY)

	ContextActionService:BindAction("Signature", function(_, state)
		if state == Enum.UserInputState.Begin then
			signature(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			signature(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonL2)

	-- The basic attack. A click is read through UserInputService so a click on
	-- the interface never swings.
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
	end, false, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("Dodge", function(_, state)
		if state == Enum.UserInputState.Begin then
			dodge()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	ContextActionService:BindAction("Charge", function(_, state)
		if state == Enum.UserInputState.Begin then
			charge(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			charge(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B, Enum.KeyCode.ButtonB)

	-- R: the next weapon, for a set that lives on R; or, for a style with
	-- limbs or webbing of its own, hand the fight to them.
	ContextActionService:BindAction("Cycle", function(_, state)
		local style = player:GetAttribute("Style") :: string?
		local a = style and (Arsenals :: any)[style]
		local st = style and Styles[style]
		if state == Enum.UserInputState.Begin then
			if a and a.key == "r" then
				act("cycle")
				return Enum.ContextActionResult.Sink
			elseif st and (st.autoLimbs or st.autoWeb) then
				act("auto")
				return Enum.ContextActionResult.Sink
			end
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

	-- J: the menu (daily reward, quests, boards, stats). L: the loadout.
	ContextActionService:BindAction("Menu", function(_, state)
		if state == Enum.UserInputState.Begin then
			Loadout.close()
			Hub.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.J)
	ContextActionService:BindAction("Loadout", function(_, state)
		if state == Enum.UserInputState.Begin and player:GetAttribute("Style") and not Select.isOpen() then
			Hub.close()
			Loadout.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.L)

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
