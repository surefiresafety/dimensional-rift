--!strict
-- Select Character: every fighter as a card, filtered by universe and searched
-- by name or technique, the same way the web build's screen works.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)
local RulesData = require(Shared.Data.Rules)
local Styles = require(Shared.Data.Styles)
local Skills = require(Shared.Data.Skills)
local Characters = require(Shared.Data.Characters)
local EnemyData = require(Shared.Data.Enemies)
local Progression = require(Shared.Progression)

local Ui = require(script.Parent.Ui)
local Profile = require(script.Parent.Profile)
local Hud = require(script.Parent.Hud)

local SelectStyle = Remotes.get("SelectStyle")

local Select = {}

local gui: ScreenGui
local grid: ScrollingFrame
local countLabel: TextLabel
local cards: { { frame: Frame, world: string, find: string, id: string, pick: TextButton, lock: TextLabel } } = {}
local continueButton: TextButton
local pending: string? = nil -- asked for, not yet confirmed by the server

--- Asks for a character. The screen closes when the server has put them in
--- (their Style changes), not before: a refused pick leaves it open.
local function choose(id: string)
	local player = Players.LocalPlayer
	if player:GetAttribute("Style") == id then
		SelectStyle:FireServer(id)
		Select.hide()
		return
	end
	pending = id
	SelectStyle:FireServer(id)
	task.delay(3, function()
		if pending == id then
			pending = nil
			Hud.log("That did not go through. Try again in a moment.")
		end
	end)
end
local rosterLabel: TextLabel
local busy = false
local world = "all"
local query = ""

local WORLDS = {
	{ "all", "All" },
	{ "naruto", RulesData.WORLD_LABEL.naruto },
	{ "jjk", RulesData.WORLD_LABEL.jjk },
	{ "marvel", RulesData.WORLD_LABEL.marvel },
	{ "other", RulesData.WORLD_LABEL.other },
}

local function refilter()
	local shown = 0
	for _, c in cards do
		local ok = (world == "all" or c.world == world) and (query == "" or string.find(c.find, query, 1, true) ~= nil)
		c.frame.Visible = ok
		if ok then
			shown += 1
		end
	end
	countLabel.Text = if shown == #cards then `{shown} CHARACTERS` else `{shown} OF {#cards} CHARACTERS`
end

--- Owned, before the save has loaded: the starters.
local function owns(id: string): boolean
	if Profile.data then
		return Profile.has(id)
	end
	return table.find(Progression.STARTERS, id) ~= nil
end

--- How a locked character is won, in a few words.
local function howToUnlock(id: string): string
	local boss = EnemyData["boss_" .. id]
	local price = Progression.priceOf(id)
	if boss then
		return `Beat {boss.name} in the rift, or {price} shards`
	end
	return `{price} shards`
end

local function refreshLocks()
	local d = Profile.data
	local shards = if d then d.shards else 0
	local owned = 0
	for _, c in cards do
		local has = owns(c.id)
		if has then
			owned += 1
			c.pick.Text = "Play as this"
			c.pick.BackgroundColor3 = Ui.ACCENT
			c.pick.TextColor3 = Color3.new(1, 1, 1)
			c.lock.Visible = false
		else
			local price = Progression.priceOf(c.id)
			local afford = d ~= nil and shards >= price
			c.pick.Text = if afford then `Unlock · {price} shards` else `Locked · {price} shards`
			c.pick.BackgroundColor3 = if afford then Color3.fromRGB(200, 150, 30) else Ui.INK
			c.pick.TextColor3 = if afford then Color3.new(1, 1, 1) else Ui.DIM
			c.lock.Text = "🔒  " .. howToUnlock(c.id)
			c.lock.Visible = true
		end
	end
	rosterLabel.Text = if d
		then `ROSTER {owned} / {#cards}  ·  {Profile.shards(shards)} SHARDS`
		else "LOADING YOUR SAVE…"
	local last = d and d.lastStyle
	continueButton.Visible = last ~= nil and Styles[last] ~= nil and owns(last)
	if continueButton.Visible then
		continueButton.Text = "Continue as " .. string.split(Styles[last].name, ":")[1]
	end
end

local function card(id: string, st: any): Frame
	local look = Characters[id] or Characters.default
	local wid = RulesData.WORLD_OF[id] or "other"
	local f = Ui.make("Frame", {
		Name = id,
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.15,
	}, { Ui.corner(14), Ui.stroke(), Ui.pad(12) })
	-- The palette as a strip: skin, top, bottom, signature.
	local strip = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundTransparency = 1,
		Parent = f,
	}, { Ui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }) })
	for _, key in { "skin", "top", "bottom", "sig" } do
		Ui.make("Frame", {
			Size = UDim2.new(0.25, -3, 1, 0),
			BackgroundColor3 = Palette.color(look[key] or 0x888888),
			BorderSizePixel = 0,
			Parent = strip,
		}, { Ui.corner(3) })
	end
	Ui.label({
		Text = string.upper(RulesData.WORLD_LABEL[wid] or "Elsewhere"),
		TextColor3 = Color3.fromRGB(58, 224, 255),
		TextSize = 11,
		Font = Ui.BOLD,
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = f,
	})
	Ui.label({
		Text = st.name,
		Font = Ui.DISPLAY,
		TextSize = 26,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 30),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = f,
	})
	Ui.label({
		Text = st.blurb,
		TextColor3 = Ui.DIM,
		TextSize = 13,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 34),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = f,
	})
	local names = {}
	for i, k in st.slots do
		table.insert(names, `{i}  {Skills[k].name}`)
	end
	table.insert(names, `G  {st.ultimate.name}`)
	Ui.label({
		Text = table.concat(names, "\n"),
		TextSize = 13,
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.new(1, 0, 0, 104),
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.1,
		Parent = f,
	})
	local pick = Ui.make("TextButton", {
		Text = "Play as this",
		Font = Ui.BOLD,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Ui.ACCENT,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 36),
		AutoButtonColor = true,
		Parent = f,
	}, { Ui.corner(18) })
	pick.Activated:Connect(function()
		if owns(id) then
			choose(id)
			return
		end
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = Profile.ask("buy", id)
			busy = false
			Hud.log(r.message or "", if r.ok then "gold" else nil)
		end)
	end)
	local lock = Ui.label({
		Text = "",
		Font = Ui.BOLD,
		TextSize = 11,
		TextColor3 = Ui.GOLD,
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -42),
		Size = UDim2.new(1, 0, 0, 22),
		Visible = false,
		Parent = f,
	})
	Ui.corner(8).Parent = lock
	local find = string.lower(st.name .. " " .. st.blurb .. " " .. table.concat(names, " "))
	for _, k in st.pool do
		find ..= " " .. string.lower(Skills[k].name)
	end
	table.insert(cards, { frame = f, world = wid, find = find, id = id, pick = pick, lock = lock })
	return f
end

function Select.build()
	local player = Players.LocalPlayer
	gui = Ui.make("ScreenGui", {
		Name = "SelectCharacter",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local shade = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, {
		Ui.make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(60, 30, 110), Ui.INK),
			Rotation = 90,
		}),
	})
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.94, 0, 0.92, 0),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.2,
		Parent = shade,
	}, { Ui.corner(18), Ui.stroke(), Ui.pad(22), Ui.make("UISizeConstraint", { MaxSize = Vector2.new(1240, 1000) }) })
	Ui.label({
		Text = "WHO WALKS INTO THE RIFT",
		TextColor3 = Color3.fromRGB(58, 224, 255),
		Font = Ui.BOLD,
		TextSize = 11,
		Size = UDim2.new(1, 0, 0, 14),
		Parent = panel,
	})
	Ui.label({
		Text = "Select Character",
		Font = Ui.DISPLAY,
		TextColor3 = Ui.GOLD,
		TextSize = 44,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 46),
		Parent = panel,
	})
	-- Filters and search.
	local bar = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local tabs: { TextButton } = {}
	for i, w in WORLDS do
		local b = Ui.make("TextButton", {
			LayoutOrder = i,
			Text = string.upper(w[2]),
			Font = Ui.BOLD,
			TextSize = 12,
			TextColor3 = Ui.DIM,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			BackgroundColor3 = Ui.ACCENT,
			BackgroundTransparency = 1,
			Parent = bar,
		}, { Ui.corner(16), Ui.make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
		table.insert(tabs, b)
		b.Activated:Connect(function()
			world = w[1]
			for j, o in tabs do
				o.BackgroundTransparency = if j == i then 0.7 else 1
				o.TextColor3 = if j == i then Ui.TEXT else Ui.DIM
			end
			refilter()
		end)
	end
	tabs[1].BackgroundTransparency = 0.7
	tabs[1].TextColor3 = Ui.TEXT
	local search = Ui.make("TextBox", {
		LayoutOrder = 10,
		PlaceholderText = "Search a name or a technique",
		Text = "",
		Font = Ui.BODY,
		TextSize = 13,
		TextColor3 = Ui.TEXT,
		PlaceholderColor3 = Ui.DIM,
		BackgroundColor3 = Ui.INK,
		Size = UDim2.fromOffset(250, 32),
		ClearTextOnFocus = false,
		Parent = bar,
	}, { Ui.corner(16), Ui.stroke() })
	search:GetPropertyChangedSignal("Text"):Connect(function()
		query = string.lower(search.Text)
		refilter()
	end)
	countLabel = Ui.label({
		LayoutOrder = 11,
		Text = "",
		TextColor3 = Ui.DIM,
		Font = Ui.BOLD,
		TextSize = 11,
		Size = UDim2.fromOffset(170, 32),
		Parent = bar,
	})
	-- Your roster and shards, and straight back into the last one you played.
	rosterLabel = Ui.label({
		Text = "",
		TextColor3 = Ui.GOLD,
		Font = Ui.BOLD,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(320, 14),
		Parent = panel,
	})
	continueButton = Ui.make("TextButton", {
		Text = "",
		Font = Ui.BOLD,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 150, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 22),
		Size = UDim2.fromOffset(260, 38),
		Visible = false,
		Parent = panel,
	}, { Ui.corner(19) })
	continueButton.Activated:Connect(function()
		local d = Profile.data
		local last = d and d.lastStyle
		if last and owns(last) then
			choose(last)
		end
	end)
	grid = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 1, -116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.ACCENT,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, {
		Ui.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(290, 262),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local ids: { string } = {}
	for id in Styles do
		table.insert(ids, id :: string)
	end
	-- Grouped by universe, then by name, so the grid reads in a stable order.
	table.sort(ids, function(a, b)
		local wa, wb = RulesData.WORLD_OF[a] or "zz", RulesData.WORLD_OF[b] or "zz"
		if wa ~= wb then
			return wa < wb
		end
		return Styles[a].name < Styles[b].name
	end)
	for i, id in ids do
		local f = card(id, Styles[id])
		f.LayoutOrder = i
		f.Parent = grid
	end
	refilter()
	refreshLocks()
	Profile.changed:Connect(refreshLocks)
	player:GetAttributeChangedSignal("Style"):Connect(function()
		if pending and player:GetAttribute("Style") == pending then
			pending = nil
			Select.hide()
		end
	end)
end

function Select.show()
	gui.Enabled = true
end

function Select.hide()
	gui.Enabled = false
end

function Select.toggle()
	gui.Enabled = not gui.Enabled
end

function Select.isOpen(): boolean
	return gui.Enabled
end

return Select
