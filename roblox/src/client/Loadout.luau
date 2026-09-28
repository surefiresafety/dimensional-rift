--!strict
-- The loadout screen (Tab): pick up to five techniques for the character you
-- are playing, from their own pool and from every technique you have absorbed
-- from an enemy. Saved per character, and on the server's say-so.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Palette)
local RulesData = require(Shared.Data.Rules)
local Skills = require(Shared.Data.Skills)
local Styles = require(Shared.Data.Styles)

local Ui = require(script.Parent.Ui)
local Profile = require(script.Parent.Profile)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local Loadout = {}

local gui: ScreenGui
local title: TextLabel
local equippedRow: Frame
local list: ScrollingFrame
local picked: { string } = {}
local styleId: string? = nil
local busy = false

local function styleNow(): string?
	return player:GetAttribute("Style") :: string?
end

local function chip(id: string, parent: Instance, order: number, onClick: () -> (), tag: string?): TextButton
	local s = Skills[id]
	local b = Ui.make("TextButton", {
		Text = "",
		LayoutOrder = order,
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		Parent = parent,
	}, { Ui.corner(10), Ui.stroke(Palette.color(RulesData.NATURE[s.nature].color), 1, 0.4), Ui.pad(8) })
	Ui.label({
		Text = s.name,
		Font = Ui.BOLD,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = b,
	})
	Ui.label({
		Text = string.upper(`{RulesData.NATURE[s.nature].label} · {s.type} · {s.cost} SE`)
			.. (if tag then "  ·  " .. tag else ""),
		TextSize = 9,
		TextColor3 = Palette.color(RulesData.NATURE[s.nature].color),
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = b,
	})
	Ui.label({
		Text = s.desc or "",
		TextSize = 11,
		TextColor3 = Ui.DIM,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = b,
	})
	b.Activated:Connect(onClick)
	return b
end

local function render()
	for _, c in equippedRow:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local id = styleId
	if not id or not Styles[id] then
		title.Text = "Pick a character first"
		return
	end
	local st = Styles[id]
	title.Text = `Loadout: {st.name}`
	for i = 1, RulesData.MAX_SLOTS do
		local k = picked[i]
		if k then
			local b = chip(k, equippedRow, i, function()
				table.remove(picked, table.find(picked, k) :: number)
				render()
			end, `SLOT {i}`)
			b.Size = UDim2.new(1 / RulesData.MAX_SLOTS, -8, 1, 0)
		else
			Ui.make("Frame", {
				LayoutOrder = i,
				Size = UDim2.new(1 / RulesData.MAX_SLOTS, -8, 1, 0),
				BackgroundTransparency = 0.8,
				BackgroundColor3 = Ui.INK,
				Parent = equippedRow,
			}, {
				Ui.corner(10),
				Ui.stroke(),
				Ui.label({
					Text = `SLOT {i}\nempty`,
					TextColor3 = Ui.DIM,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
				}),
			})
		end
	end
	-- Their own techniques first, then everything absorbed, each by name.
	local own, absorbed = {}, {}
	for _, k in st.pool do
		if not table.find(picked, k) then
			table.insert(own, k)
		end
	end
	local d = Profile.data
	local learned: { string } = if d then d.learned else {}
	for _, k in learned do
		if Skills[k] and not table.find(st.pool, k) and not table.find(picked, k) then
			table.insert(absorbed, k)
		end
	end
	local byName = function(a: string, b: string)
		return Skills[a].name < Skills[b].name
	end
	table.sort(own, byName)
	table.sort(absorbed, byName)
	local order = 0
	local function offer(k: string, tag: string?)
		order += 1
		chip(k, list, order, function()
			if #picked >= RulesData.MAX_SLOTS then
				Hud.log("All five slots are full. Click an equipped technique to take it off.")
				return
			end
			table.insert(picked, k)
			render()
		end, tag)
	end
	for _, k in own do
		offer(k)
	end
	for _, k in absorbed do
		offer(k, "ABSORBED")
	end
	if #absorbed == 0 then
		order += 1
		Ui.label({
			LayoutOrder = order,
			Text = "Defeat enemies to absorb their techniques. Anything you absorb can go in any character's loadout.",
			TextColor3 = Ui.DIM,
			TextSize = 12,
			Parent = list,
		})
	end
end

function Loadout.open()
	-- While transformed the kit on screen is the transform's, not theirs.
	if player:GetAttribute("BaseStyle") then
		Hud.log("Change back first (G), then set your loadout.")
		return
	end
	styleId = styleNow()
	local slots = (player:GetAttribute("Slots") :: string?) or ""
	picked = if slots == "" then {} else string.split(slots, ",")
	gui.Enabled = true
	render()
end

function Loadout.close()
	gui.Enabled = false
end

function Loadout.toggle()
	if gui.Enabled then
		Loadout.close()
	else
		Loadout.open()
	end
end

function Loadout.isOpen(): boolean
	return (gui :: ScreenGui?) ~= nil and gui.Enabled
end

local function save(slots: { string })
	if busy or not styleId then
		return
	end
	busy = true
	task.spawn(function()
		local r = Profile.ask("loadout", styleId, slots)
		busy = false
		Hud.log(r.message or (if r.ok then "Saved." else "Could not save."), if r.ok then "gold" else nil)
		if r.ok then
			Loadout.close()
		end
	end)
end

function Loadout.build()
	gui = Ui.make("ScreenGui", {
		Name = "Loadout",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 25,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.88),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.05,
		Active = true,
		Parent = gui,
	}, { Ui.corner(18), Ui.stroke(), Ui.pad(18), Ui.make("UISizeConstraint", { MaxSize = Vector2.new(980, 680) }) })
	title = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 34,
		TextColor3 = Ui.GOLD,
		Size = UDim2.new(1, -60, 0, 38),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = panel,
	})
	local close = Ui.make("TextButton", {
		Text = "✕",
		Font = Ui.BOLD,
		TextSize = 18,
		TextColor3 = Ui.TEXT,
		BackgroundColor3 = Ui.INK,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(36, 36),
		Parent = panel,
	}, { Ui.corner(18) })
	close.Activated:Connect(Loadout.close)
	Ui.label({
		Text = "EQUIPPED: CLICK ONE TO TAKE IT OFF",
		Font = Ui.BOLD,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(58, 224, 255),
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = panel,
	})
	equippedRow = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Ui.label({
		Text = "AVAILABLE: CLICK ONE TO EQUIP IT",
		Font = Ui.BOLD,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(58, 224, 255),
		Position = UDim2.fromOffset(0, 170),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = panel,
	})
	list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 188),
		Size = UDim2.new(1, 0, 1, -240),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.ACCENT,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, {
		Ui.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(220, 92),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local buttons = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local reset = Ui.make("TextButton", {
		Text = "Their default",
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = Ui.TEXT,
		BackgroundColor3 = Ui.LINE,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(160, 38),
		Parent = buttons,
	}, { Ui.corner(19) })
	reset.Activated:Connect(function()
		if styleId and Styles[styleId] then
			save(table.clone(Styles[styleId].slots))
		end
	end)
	local ok = Ui.make("TextButton", {
		Text = "Save loadout",
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Ui.ACCENT,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(180, 38),
		Parent = buttons,
	}, { Ui.corner(19) })
	ok.Activated:Connect(function()
		if #picked == 0 then
			Hud.log("Equip at least one technique.")
			return
		end
		save(table.clone(picked))
	end)
end

return Loadout
