--!strict
-- On phones and tablets: a pad of buttons beside the jump button, laid out by
-- hand rather than left to ContextActionService, which stacks its own touch
-- buttons on top of each other once there are more than a few. Each shows its
-- cooldown, since the ability rail is hidden on a small screen.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Ui)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local TouchPad = {}

export type Handlers = {
	cast: (which: number | string) -> (),
	strike: () -> (),
	signature: (down: boolean) -> (),
	charge: (down: boolean) -> (),
}

-- Column, row from the bottom-right corner of the pad; the label; what it does.
local LAYOUT: { { col: number, row: number, label: string, key: string } } = {
	{ col = 0, row = 0, label = "HIT", key = "strike" },
	{ col = 1, row = 0, label = "E", key = "sig" },
	{ col = 2, row = 0, label = "B", key = "charge" },
	{ col = 0, row = 1, label = "1", key = "1" },
	{ col = 1, row = 1, label = "2", key = "2" },
	{ col = 2, row = 1, label = "3", key = "3" },
	{ col = 0, row = 2, label = "4", key = "4" },
	{ col = 1, row = 2, label = "5", key = "5" },
	{ col = 2, row = 2, label = "G", key = "ult" },
}

local SIZE = 58
local GAP = 8

function TouchPad.build(h: Handlers)
	local gui = Ui.make("ScreenGui", {
		Name = "TouchPad",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Left of the jump button, which Roblox keeps in the bottom-right corner.
	local pad = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -130, 1, -16),
		Size = UDim2.fromOffset(3 * SIZE + 2 * GAP, 3 * SIZE + 2 * GAP),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local shades: { { shade: Frame, key: string } } = {}
	local held: { [InputObject]: string } = {}
	for _, b in LAYOUT do
		local btn = Ui.make("TextButton", {
			Text = b.label,
			Font = Ui.DISPLAY,
			TextSize = 24,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = if b.key == "ult" then Color3.fromRGB(200, 150, 30) else Ui.PANEL,
			BackgroundTransparency = 0.25,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -b.col * (SIZE + GAP), 1, -b.row * (SIZE + GAP)),
			Size = UDim2.fromOffset(SIZE, SIZE),
			ClipsDescendants = true,
			Parent = pad,
		}, { Ui.corner(SIZE // 2), Ui.stroke(Ui.LINE, 1, 0.2) })
		local shade = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Parent = btn,
		})
		table.insert(shades, { shade = shade, key = b.key })
		btn.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			if b.key == "sig" or b.key == "charge" then
				held[input] = b.key
			end
			if b.key == "strike" then
				h.strike()
			elseif b.key == "sig" then
				h.signature(true)
			elseif b.key == "charge" then
				h.charge(true)
			elseif b.key == "ult" then
				h.cast("ult")
			else
				h.cast(tonumber(b.key) :: number)
			end
		end)
	end
	-- A held button lets go when that finger lifts, wherever it has slid to:
	-- the button's own InputEnded never fires once the finger leaves it.
	UserInputService.TouchEnded:Connect(function(input)
		local key = held[input]
		if not key then
			return
		end
		held[input] = nil
		if key == "sig" then
			h.signature(false)
		else
			h.charge(false)
		end
	end)
	-- Beside Roblox's jump button, wherever this device puts it.
	task.spawn(function()
		local touchGui = player:WaitForChild("PlayerGui"):WaitForChild("TouchGui", 10)
		local frame = touchGui and touchGui:WaitForChild("TouchControlFrame", 5)
		local jump = frame and frame:WaitForChild("JumpButton", 5)
		if not jump or not jump:IsA("GuiObject") then
			return
		end
		local function place()
			local origin = gui.AbsolutePosition
			local right = jump.AbsolutePosition.X - origin.X - 12
			local bottom = jump.AbsolutePosition.Y + jump.AbsoluteSize.Y - origin.Y
			pad.Position = UDim2.fromOffset(right, bottom)
		end
		place()
		jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
		jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	end)
	-- Cooldowns: the slot's technique, or the ultimate.
	task.spawn(function()
		while gui.Parent do
			local slots = string.split((player:GetAttribute("Slots") :: string?) or "", ",")
			for _, s in shades do
				local key = if s.key == "ult" then "ult" else slots[tonumber(s.key) or 0]
				s.shade.Size = UDim2.fromScale(1, if key then Hud.cooldownLeft(key) else 0)
			end
			task.wait(0.1)
		end
	end)
end

return TouchPad
