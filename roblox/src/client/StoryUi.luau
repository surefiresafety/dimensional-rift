--!strict
-- The story on screen: a card when a world opens (its chapter, name and a
-- few lines of what is happening), and spoken lines as subtitles across the
-- lower third, one after another.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local StoryUi = {}

function StoryUi.build()
	local gui = Ui.make("ScreenGui", {
		Name = "Story",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 12,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- The world card --------------------------------------------------------
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.6, 0, 0, 190),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(18),
		Ui.stroke(Color3.fromRGB(255, 45, 85), 1, 0.3),
		Ui.pad(20),
		Ui.make("UISizeConstraint", { MaxSize = Vector2.new(720, 220), MinSize = Vector2.new(300, 150) }),
	})
	local chapter = Ui.label({
		Text = "",
		Font = Ui.BOLD,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 120, 140),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 14),
		Parent = card,
	})
	local title = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 44,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 46),
		Parent = card,
	})
	local sub = Ui.label({
		Text = "",
		TextSize = 12,
		TextColor3 = Ui.DIM,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = card,
	})
	local body = Ui.label({
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 1, -86),
		Parent = card,
	})
	local cardShown = 0

	-- Subtitles ---------------------------------------------------------------
	local caption = Ui.label({
		Text = "",
		RichText = true,
		TextSize = 18,
		Font = Ui.BOLD,
		TextStrokeTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.78, 0),
		Size = UDim2.new(0.62, 0, 0, 60),
		TextTransparency = 1,
		Parent = gui,
	})
	local queue: { any } = {}
	local speaking = false

	local function speakNext()
		if speaking or #queue == 0 then
			return
		end
		speaking = true
		local line = table.remove(queue, 1)
		local who = if line.speaker ~= "" then `<font color="#ff8aa0">{string.upper(line.speaker)}</font>   ` else ""
		caption.Text = who .. line.text
		caption.TextTransparency = 0
		caption.TextStrokeTransparency = 0.25
		-- Long enough to read: a second plus a beat for every eight words.
		local words = #string.split(line.text, " ")
		task.delay(2 + words / 8 * 1.6, function()
			TweenService:Create(caption, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
			task.wait(0.5)
			speaking = false
			speakNext()
		end)
	end

	Remotes.get("Story").OnClientEvent:Connect(function(kind: string, d: any)
		if kind == "card" then
			chapter.Text = string.upper(d.chapter or "")
			title.Text = d.title or ""
			sub.Text = d.sub or ""
			body.Text = d.text or ""
			card.Visible = true
			cardShown += 1
			local mine = cardShown
			local scale = card:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", { Parent = card })
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			task.delay(8, function()
				if cardShown == mine then
					card.Visible = false
				end
			end)
		elseif kind == "line" then
			table.insert(queue, d)
			speakNext()
		end
	end)
end

return StoryUi
