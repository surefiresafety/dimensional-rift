--!strict
-- Two moments that deserve the whole screen: going down (what did it, and
-- when you are back), and clearing a world (what the run was worth).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Ui = require(script.Parent.Ui)
local Profile = require(script.Parent.Profile)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local Screens = {}

local RESPAWN = 4 -- seconds, as the server waits

local function fmtTime(s: number): string
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function Screens.build()
	local gui = Ui.make("ScreenGui", {
		Name = "Screens",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 15,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Down --------------------------------------------------------------------
	local down = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 0, 10),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = gui,
	})
	Ui.label({
		Text = "DOWN",
		Font = Ui.DISPLAY,
		TextSize = 72,
		TextColor3 = Color3.fromRGB(255, 90, 100),
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(600, 80),
		Parent = down,
	})
	local why = Ui.label({
		Text = "",
		TextSize = 18,
		Font = Ui.BOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.49),
		Size = UDim2.fromOffset(600, 50),
		Parent = down,
	})
	local function watch(character: Model)
		local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		down.Visible = false
		hum.Died:Connect(function()
			down.Visible = true
			for s = RESPAWN, 1, -1 do
				if not down.Visible then
					return
				end
				why.Text = `Back in {s}…`
				task.wait(1)
			end
		end)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	-- World cleared -------------------------------------------------------------
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 330),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(18), Ui.stroke(Ui.GOLD, 2, 0.2), Ui.pad(20) })
	local title = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 40,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = card,
	})
	local sub = Ui.label({
		Text = "",
		TextSize = 13,
		TextColor3 = Ui.DIM,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = card,
	})
	local rows = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 180),
		BackgroundTransparency = 1,
		Parent = card,
	}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local ok = Ui.make("TextButton", {
		Text = "Onward",
		Font = Ui.BOLD,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Ui.ACCENT,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(180, 40),
		Parent = card,
	}, { Ui.corner(20) })
	ok.Activated:Connect(function()
		card.Visible = false
	end)
	Remotes.get("Summary").OnClientEvent:Connect(function(run: any)
		title.Text = string.upper(run.world) .. " CLEARED"
		sub.Text = if run.first
			then "First clear. The rift opens onto the next world."
			else "The rift opens onto the next world."
		for _, c in rows:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local d = Profile.data
		local lines = {
			{ "Time", fmtTime(run.seconds) },
			{ "Enemies defeated", tostring(run.kills) },
			{ "Best combo", `{run.bestCombo} hits` },
			{ "Experience", `+{run.xp}` },
			{ "Rift Shards", `+{run.shards}` .. (if d then `  ({Profile.shards(d.shards)} held)` else "") },
			{ "Level", tostring(run.level) },
		}
		for i, l in lines do
			Ui.make("Frame", {
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Parent = rows,
			}, {
				Ui.label({ Text = l[1], TextColor3 = Ui.DIM, TextSize = 15, Size = UDim2.new(0.5, 0, 1, 0) }),
				Ui.label({
					Text = l[2],
					Font = Ui.BOLD,
					TextSize = 15,
					TextXAlignment = Enum.TextXAlignment.Right,
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.new(0.5, 0, 1, 0),
				}),
			})
		end
		local scale = card:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", { Parent = card })
		scale.Scale = 0.6
		card.Visible = true
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Sfx.play("level")
		-- Out of the way before the next world's first wave.
		task.delay(13, function()
			card.Visible = false
		end)
	end)
end

return Screens
