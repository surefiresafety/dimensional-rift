--!strict
-- The first run: a handful of tips, each moving on when the player does the
-- thing it describes (or after a while). Shown once per player; the server
-- remembers it was finished. A Skip button ends it at any point.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Ui)
local Profile = require(script.Parent.Profile)

local player = Players.LocalPlayer

local Tips = {}

type Step = { text: string, touch: string?, done: (() -> boolean)?, wait: number }

local function hasHunter(): boolean
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return false
	end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("Hunting") then
			return true
		end
	end
	return false
end

local struck = false

local STEPS: { Step } = {
	{
		text = "Left click to attack. Your five techniques are on 1 to 5.",
		touch = "Tap HIT to attack. Your five techniques are 1 to 5 on the pad.",
		done = function()
			return struck
		end,
		wait = 20,
	},
	{
		text = "Enemies do not see you until you get close. The radar shows them: yellow have not spotted you, red are hunting you.",
		done = hasHunter,
		wait = 18,
	},
	{
		text = "A ring flashing under an enemy means it is about to attack: red a swing, yellow a shot, orange a charge. Press Q to dodge through it.",
		touch = "A ring flashing under an enemy means it is about to attack: red a swing, yellow a shot, orange a charge. Tap DODGE to slip through it.",
		wait = 12,
	},
	{
		text = "Hold B to power up your next technique. G is your ultimate.",
		touch = "Hold B on the pad to power up your next technique. G is your ultimate.",
		done = function()
			return player:GetAttribute("ChargeStart") ~= nil
		end,
		wait = 14,
	},
	{
		text = "Enemies drop orbs: green heals, blue restores Spirit Energy, violet is Rift Shards. Keep hitting to build a combo.",
		wait = 10,
	},
	{
		text = "Press J for your daily reward, quests and upgrades, and L to change your loadout. Beat a boss to win that character.",
		touch = "Tap MENU for your daily reward, quests and upgrades. Beat a boss to win that character.",
		wait = 12,
	},
}

function Tips.start()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local gui = Ui.make("ScreenGui", {
		Name = "Tips",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.new(0.5, 0, 0, 64),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.stroke(Ui.GOLD, 1, 0.3),
		Ui.pad(12),
		Ui.make("UISizeConstraint", { MaxSize = Vector2.new(620, 90), MinSize = Vector2.new(280, 60) }),
	})
	local text = Ui.label({
		Text = "",
		TextSize = 15,
		Font = Ui.BOLD,
		Size = UDim2.new(1, -70, 1, 0),
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = card,
	})
	local skip = Ui.make("TextButton", {
		Text = "Skip",
		Font = Ui.BOLD,
		TextSize = 12,
		TextColor3 = Ui.DIM,
		BackgroundColor3 = Ui.INK,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(56, 28),
		Parent = card,
	}, { Ui.corner(14) })
	local skipped = false
	skip.Activated:Connect(function()
		skipped = true
	end)

	-- Something was hit or cast: the first tip is done.
	player:GetAttributeChangedSignal("Combo"):Connect(function()
		struck = true
	end)

	task.spawn(function()
		-- Only for someone who has not been through it, once they are playing.
		while not Profile.data do
			task.wait(0.5)
		end
		if (Profile.data :: any).tutorial then
			return
		end
		while not player:GetAttribute("Style") do
			task.wait(0.5)
		end
		task.wait(2)
		gui.Enabled = true
		for _, step in STEPS do
			if skipped then
				break
			end
			text.Text = if touch and step.touch then step.touch else step.text
			card.BackgroundColor3 = Ui.ACCENT
			TweenService:Create(card, TweenInfo.new(0.6), { BackgroundColor3 = Ui.PANEL }):Play()
			local started = os.clock()
			while not skipped and os.clock() - started < step.wait do
				if step.done and os.clock() - started > 2 and step.done() then
					break
				end
				task.wait(0.25)
			end
			task.wait(if skipped then 0 else 0.6)
		end
		gui.Enabled = false
		Profile.ask("tutorialDone")
	end)
end

return Tips
