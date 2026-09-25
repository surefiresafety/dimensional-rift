--!strict
-- The menu (J, or MENU on the HUD): the daily reward and its streak, today's
-- quests, the global boards and your numbers. It opens on its own when a
-- daily reward is waiting, which is the first thing a returning player sees.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Worlds)
local Progression = require(Shared.Progression)
local Styles = require(Shared.Data.Styles)

local Ui = require(script.Parent.Ui)
local Profile = require(script.Parent.Profile)
local Hud = require(script.Parent.Hud)
local Loadout = require(script.Parent.Loadout)
local Select = require(script.Parent.Select)

local player = Players.LocalPlayer

local Hub = {}

local gui: ScreenGui
local content: Frame
local tabButtons: { [string]: TextButton } = {}
local current = "daily"
local busy = false
local boardName = "wave"
local boardRows: { [string]: { any } } = {}
local autoOpened = false
local rendered = "" -- what the open tab was last drawn from

--- The part of a snapshot a tab draws. A snapshot that leaves it unchanged
--- (quest progress in a fight, while the Daily tab is open) redraws nothing,
--- so a button is never swapped out from under a finger.
local function signature(tab: string, d: any): string
	local part: any = if tab == "daily"
		then { d.daily }
		elseif tab == "quests" then { d.quests, d.rerolled, d.shards }
		elseif tab == "upgrades" then { d.upgrades, d.shards }
		elseif tab == "worlds" then { d.cleared, d.best, d.world }
		elseif tab == "stats" then {
			stats = d.stats,
			level = d.level,
			xp = d.xp,
			shards = d.shards,
			best = d.best,
			cleared = d.cleared,
			roster = #d.unlocked,
			learned = #d.learned,
		}
		else { board = boardName, loaded = boardRows[boardName] ~= nil }
	return tab .. HttpService:JSONEncode(part)
end

local TABS = {
	{ "daily", "Daily" },
	{ "quests", "Quests" },
	{ "upgrades", "Upgrades" },
	{ "worlds", "Worlds" },
	{ "boards", "Boards" },
	{ "stats", "Stats" },
}

local function clear()
	for _, c in content:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function button(text: string, colour: Color3, enabled: boolean, parent: Instance, order: number?): TextButton
	return Ui.make("TextButton", {
		Text = text,
		Font = Ui.BOLD,
		TextSize = 14,
		TextColor3 = if enabled then Color3.new(1, 1, 1) else Ui.DIM,
		BackgroundColor3 = if enabled then colour else Ui.INK,
		AutoButtonColor = enabled,
		Active = enabled,
		LayoutOrder = order or 0,
		Size = UDim2.fromOffset(150, 36),
		Parent = parent,
	}, { Ui.corner(18) })
end

--- Runs a request, logs the answer, and stops a double click sending two.
local function request(action: string, a: any?, b: any?)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local r = Profile.ask(action, a, b)
		busy = false
		if r.message then
			Hud.log(r.message, if r.ok then "gold" else nil)
		end
	end)
end

--- Time until midnight UTC, when the daily reward and the quests turn over.
local function untilTomorrow(): string
	local now = workspace:GetServerTimeNow()
	local left = math.max(0, 86400 - (now % 86400))
	return string.format("%dh %02dm", math.floor(left / 3600), math.floor(left % 3600 / 60))
end

local function heading(text: string, order: number)
	Ui.label({
		Text = text,
		Font = Ui.BOLD,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(58, 224, 255),
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = order,
		Parent = content,
	})
end

local renders: { [string]: (any) -> () } = {}

renders.daily = function(d)
	local ready = d.daily.ready
	local streak = if ready then d.daily.next else d.daily.streak
	heading(
		if ready
			then `DAY {streak} OF YOUR STREAK IS READY`
			else `STREAK: {d.daily.streak} DAY{if d.daily.streak == 1 then "" else "S"}`,
		1
	)
	Ui.label({
		Text = if ready
			then "Come back every day: the rewards grow for seven days, and day seven is the big one. Miss a day and the streak starts again."
			else `Claimed. The next one opens in {untilTomorrow()}. Keep the streak going.`,
		TextColor3 = Ui.DIM,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 2,
		Parent = content,
	})
	local row = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = content,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- Where in the seven-day cycle today's (or the next) claim lands.
	local slot = ((streak - 1) % #Progression.DAILY) + 1
	for i, r in Progression.DAILY do
		local isNext = i == slot
		local done = if ready then i < slot else i <= slot
		Ui.make("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1 / 7, -6, 1, 0),
			BackgroundColor3 = if isNext and ready then Ui.ACCENT else Ui.INK,
			BackgroundTransparency = if done then 0.6 else 0.1,
			Parent = row,
		}, {
			Ui.corner(10),
			Ui.stroke(if i == 7 then Ui.GOLD else Ui.LINE, if isNext then 2 else 1, 0.2),
			Ui.label({
				Text = `DAY {i}`,
				Font = Ui.BOLD,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 6),
				Size = UDim2.new(1, 0, 0, 14),
			}),
			Ui.label({
				Text = if done then "✓" else tostring(r.shards),
				Font = Ui.DISPLAY,
				TextSize = 26,
				TextColor3 = if i == 7 then Ui.GOLD else Ui.TEXT,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 30),
			}),
			Ui.label({
				Text = if done then "" else `SHARDS\n+{r.xp} XP`,
				TextSize = 9,
				TextColor3 = Ui.DIM,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 58),
				Size = UDim2.new(1, 0, 0, 28),
			}),
		})
	end
	local b = button(if ready then "Claim" else "Claimed", Ui.ACCENT, ready, content, 4)
	b.Size = UDim2.fromOffset(200, 40)
	if ready then
		b.Activated:Connect(function()
			request("claimDaily")
		end)
	end
end

renders.quests = function(d)
	heading("TODAY'S QUESTS", 1)
	Ui.label({
		Text = `New quests in {untilTomorrow()}. You can swap one unfinished quest a day for {Progression.QUEST_REROLL_COST} shards.`,
		TextColor3 = Ui.DIM,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 2,
		Parent = content,
	})
	for i, q in d.quests do
		local done = q.progress >= q.goal
		local card = Ui.make("Frame", {
			LayoutOrder = 2 + i,
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundColor3 = Ui.INK,
			BackgroundTransparency = 0.1,
			Parent = content,
		}, { Ui.corner(12), Ui.stroke(if done and not q.claimed then Ui.GOLD else Ui.LINE), Ui.pad(10) })
		Ui.label({
			Text = q.text,
			Font = Ui.BOLD,
			TextSize = 15,
			Size = UDim2.new(1, -170, 0, 20),
			Parent = card,
		})
		Ui.label({
			Text = `+{q.shards} shards  ·  +{q.xp} XP`,
			TextSize = 12,
			TextColor3 = Ui.ACCENT,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -170, 0, 16),
			Parent = card,
		})
		local track = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, -170, 0, 8),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Parent = card,
		}, { Ui.corner(4) })
		Ui.make("Frame", {
			Size = UDim2.fromScale(math.clamp(q.progress / q.goal, 0, 1), 1),
			BackgroundColor3 = if done then Ui.GOLD else Ui.HP,
			BorderSizePixel = 0,
			Parent = track,
		}, { Ui.corner(4) })
		Ui.label({
			Text = `{math.floor(q.progress)} / {q.goal}`,
			TextSize = 11,
			TextColor3 = Ui.DIM,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -164, 0, 40),
			Size = UDim2.fromOffset(60, 16),
			Parent = card,
		})
		local b
		if q.claimed then
			b = button("Claimed", Ui.ACCENT, false, card)
		elseif done then
			b = button("Claim", Ui.ACCENT, true, card)
			b.Activated:Connect(function()
				request("claimQuest", i)
			end)
		else
			local can = not d.rerolled and d.shards >= Progression.QUEST_REROLL_COST
			b = button(`Swap · {Progression.QUEST_REROLL_COST}`, Ui.LINE, can, card)
			if can then
				b.Activated:Connect(function()
					request("rerollQuest", i)
				end)
			end
		end
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, 0, 0.5, 0)
	end
end

renders.upgrades = function(d)
	heading(`PERMANENT, FOR EVERY CHARACTER  ·  {Profile.shards(d.shards)} SHARDS`, 1)
	for i, u in Progression.UPGRADES do
		local level = (d.upgrades or {})[u.key] or 0
		local maxed = level >= u.max
		local cost = Progression.upgradeCost(u, level)
		local card = Ui.make("Frame", {
			LayoutOrder = 1 + i,
			Size = UDim2.new(1, 0, 0, 62),
			BackgroundColor3 = Ui.INK,
			BackgroundTransparency = 0.1,
			Parent = content,
		}, { Ui.corner(12), Ui.stroke(), Ui.pad(10) })
		Ui.label({
			Text = u.name,
			Font = Ui.BOLD,
			TextSize = 16,
			Size = UDim2.new(1, -170, 0, 20),
			Parent = card,
		})
		Ui.label({
			Text = `{u.text} a level  ·  now +{math.floor(level * u.per * 100 + 0.5)}%`,
			TextSize = 12,
			TextColor3 = Ui.DIM,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -170, 0, 16),
			Parent = card,
		})
		-- Pips for each level.
		for l = 1, u.max do
			Ui.make("Frame", {
				Position = UDim2.fromOffset((l - 1) * 16, 40),
				Size = UDim2.fromOffset(12, 5),
				BackgroundColor3 = if l <= level then Ui.GOLD else Ui.LINE,
				BorderSizePixel = 0,
				Parent = card,
			}, { Ui.corner(2) })
		end
		local can = not maxed and d.shards >= cost
		local b = button(if maxed then "Maxed" else `Buy · {cost}`, Ui.ACCENT, can, card)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, 0, 0.5, 0)
		if can then
			b.Activated:Connect(function()
				request("upgrade", u.key)
			end)
		end
	end
end

renders.worlds = function(d)
	heading("THE RIFT'S WORLDS  ·  CLEAR ONE TO OPEN THE NEXT", 1)
	for i, id in Worlds.ORDER do
		local m = Worlds.get(id)
		local cleared = table.find(d.cleared, id) ~= nil
		local open = d.studio == true or i == 1 or table.find(d.cleared, Worlds.ORDER[i - 1]) ~= nil
		local here = d.world == id
		local card = Ui.make("Frame", {
			LayoutOrder = 1 + i,
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundColor3 = if here then Ui.ACCENT else Ui.INK,
			BackgroundTransparency = if here then 0.55 else 0.1,
			Parent = content,
		}, { Ui.corner(12), Ui.stroke(if cleared then Ui.GOLD else Ui.LINE), Ui.pad(10) })
		Ui.label({
			Text = (if cleared then "✓  " elseif open then "" else "🔒  ") .. m.name,
			Font = Ui.BOLD,
			TextSize = 15,
			Size = UDim2.new(1, -170, 0, 18),
			Parent = card,
		})
		local best = d.best[id]
		Ui.label({
			Text = if open
				then `{m.sub or ""}  ·  {#m.waves} waves{if best then `  ·  best wave {best}` else ""}`
				else `Clear {Worlds.get(Worlds.ORDER[i - 1]).name} to open`,
			TextSize = 12,
			TextColor3 = Ui.DIM,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, -170, 0, 16),
			Parent = card,
		})
		local b = button(if here then "You are here" else "Travel", Ui.ACCENT, open and not here, card)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, 0, 0.5, 0)
		if open and not here then
			b.Activated:Connect(function()
				request("travel", id)
			end)
		end
	end
end

local function fetchBoard(name: string)
	task.spawn(function()
		local r = Profile.ask("board", name)
		boardRows[name] = if r.ok and type(r.rows) == "table" then r.rows else {}
		if r.message then
			Hud.log(r.message)
		end
		if gui.Enabled and current == "boards" then
			Hub.render()
		end
	end)
end

renders.boards = function(_d)
	heading("THE WHOLE RIFT", 1)
	local switch = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = content,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, b in { { "wave", "Best wave" }, { "xp", "Experience" } } do
		local on = boardName == b[1]
		local btn = button(b[2], Ui.ACCENT, true, switch, i)
		btn.BackgroundTransparency = if on then 0 else 0.7
		btn.Activated:Connect(function()
			boardName = b[1]
			Hub.render()
		end)
	end
	local rows = boardRows[boardName]
	if not rows then
		Ui.label({
			Text = "Loading…",
			TextColor3 = Ui.DIM,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = 3,
			Parent = content,
		})
		fetchBoard(boardName)
		return
	end
	if #rows == 0 then
		Ui.label({
			Text = "Nobody on this board yet. It fills in as players save.",
			TextColor3 = Ui.DIM,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = 3,
			Parent = content,
		})
	end
	for i, r in rows do
		local me = r.userId == player.UserId
		local value = if boardName == "xp"
			then `LV {(Progression.levelOf(r.value))}  ·  {Profile.shards(r.value)} XP`
			else `Wave {r.value}`
		Ui.make("Frame", {
			LayoutOrder = 3 + i,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = if me then Ui.ACCENT else Ui.INK,
			BackgroundTransparency = if me then 0.5 else 0.3,
			Parent = content,
		}, {
			Ui.corner(8),
			Ui.label({
				Text = `#{r.rank}`,
				Font = Ui.DISPLAY,
				TextSize = 20,
				TextColor3 = if r.rank <= 3 then Ui.GOLD else Ui.TEXT,
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.fromOffset(44, 22),
			}),
			Ui.label({
				Text = r.name,
				Font = Ui.BOLD,
				TextSize = 14,
				Position = UDim2.fromOffset(60, 7),
				Size = UDim2.new(1, -260, 0, 18),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
			}),
			Ui.label({
				Text = value,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -200, 0, 7),
				Size = UDim2.fromOffset(190, 18),
			}),
		})
	end
	local refresh = button("Refresh", Ui.LINE, true, content, 20)
	refresh.Activated:Connect(function()
		boardRows[boardName] = nil
		Hub.render()
	end)
end

renders.stats = function(d)
	local s = d.stats
	local roster = 0
	for _ in Styles do
		roster += 1
	end
	local lines = {
		{ "Level", `{d.level}  ({Profile.shards(d.xp)} XP)` },
		{ "Rift Shards", Profile.shards(d.shards) },
		{ "Roster", `{#d.unlocked} of {roster} characters` },
		{ "Techniques absorbed", tostring(#d.learned) },
		{ "Worlds cleared", `{#d.cleared} of {#Worlds.ORDER}` },
		{ "Enemies defeated", Profile.shards(s.kills or 0) },
		{ "Bosses beaten", tostring(s.bosses or 0) },
		{ "Waves cleared", tostring(s.waves or 0) },
		{ "Techniques used", Profile.shards(s.casts or 0) },
		{ "Black Flashes and crits", tostring(s.crits or 0) },
		{ "Damage dealt", Profile.shards(s.damage or 0) },
		{ "Time in the rift", `{math.floor((s.minutes or 0) / 60)}h {(s.minutes or 0) % 60}m` },
	}
	for _, id in Worlds.ORDER do
		local best = d.best[id]
		if best then
			table.insert(
				lines,
				{ Worlds.get(id).name, `best wave {best}{if table.find(d.cleared, id) then "  ·  cleared" else ""}` }
			)
		end
	end
	heading(if d.persistent then "YOUR RIFT" else "YOUR RIFT  ·  NOT SAVING (STUDIO WITHOUT API ACCESS)", 1)
	for i, l in lines do
		Ui.make("Frame", {
			LayoutOrder = 1 + i,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Parent = content,
		}, {
			Ui.label({ Text = l[1], TextColor3 = Ui.DIM, TextSize = 14, Size = UDim2.new(0.5, 0, 1, 0) }),
			Ui.label({
				Text = l[2],
				Font = Ui.BOLD,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(0.5, 0, 1, 0),
			}),
		})
	end
end

function Hub.render()
	if not gui then
		return
	end
	for id, b in tabButtons do
		b.BackgroundTransparency = if id == current then 0.2 else 0.85
		b.TextColor3 = if id == current then Ui.TEXT else Ui.DIM
	end
	clear()
	local d = Profile.data
	if not d then
		rendered = ""
		Ui.label({ Text = "Loading your save…", TextColor3 = Ui.DIM, Size = UDim2.new(1, 0, 0, 20), Parent = content })
		return
	end
	rendered = signature(current, d)
	renders[current](d)
end

function Hub.open(tab: string?)
	if tab then
		current = tab
	end
	gui.Enabled = true
	Hub.render()
end

function Hub.close()
	gui.Enabled = false
end

function Hub.toggle()
	if gui.Enabled then
		Hub.close()
	else
		Hub.open()
	end
end

function Hub.isOpen(): boolean
	return (gui :: ScreenGui?) ~= nil and gui.Enabled
end

function Hub.build()
	gui = Ui.make("ScreenGui", {
		Name = "Hub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30, -- over Select Character: the daily reward comes first
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local shade = Ui.make("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 0.35,
		Parent = gui,
	})
	shade.Activated:Connect(Hub.close)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.88),
		BackgroundColor3 = Ui.PANEL,
		Active = true, -- clicks on the panel do not reach the shade behind it
		Parent = gui,
	}, { Ui.corner(18), Ui.stroke(), Ui.pad(18), Ui.make("UISizeConstraint", { MaxSize = Vector2.new(760, 600) }) })
	Ui.label({
		Text = "The Rift",
		Font = Ui.DISPLAY,
		TextSize = 38,
		TextColor3 = Ui.GOLD,
		Size = UDim2.new(1, -60, 0, 40),
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
	close.Activated:Connect(Hub.close)
	local tabs = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, t in TABS do
		local b = Ui.make("TextButton", {
			LayoutOrder = i,
			Text = string.upper(t[2]),
			Font = Ui.BOLD,
			TextSize = 12,
			TextColor3 = Ui.DIM,
			BackgroundColor3 = Ui.ACCENT,
			BackgroundTransparency = 0.85,
			Size = UDim2.fromOffset(78, 32),
			Parent = tabs,
		}, { Ui.corner(16) })
		tabButtons[t[1]] = b
		b.Activated:Connect(function()
			current = t[1]
			Hub.render()
		end)
	end
	-- The other screens, from here too: on a phone there is no L or M key.
	for i, t in { { "LOADOUT", "loadout" }, { "CHARACTERS", "characters" } } do
		local b = Ui.make("TextButton", {
			LayoutOrder = 10 + i,
			Text = t[1],
			Font = Ui.BOLD,
			TextSize = 12,
			TextColor3 = Ui.GOLD,
			BackgroundColor3 = Ui.INK,
			Size = UDim2.fromOffset(92, 32),
			Parent = tabs,
		}, { Ui.corner(16), Ui.stroke(Ui.GOLD, 1, 0.5) })
		b.Activated:Connect(function()
			if not player:GetAttribute("Style") then
				Hud.log("Pick a character first.")
				return
			end
			Hub.close()
			if t[2] == "loadout" then
				Loadout.open()
			else
				Select.show()
			end
		end)
	end
	content = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 94),
		Size = UDim2.new(1, 0, 1, -94),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.ACCENT,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, {
		Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Ui.make("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	Profile.changed:Connect(function(new: any)
		if gui.Enabled and current ~= "boards" and signature(current, new) ~= rendered then
			Hub.render()
		end
		-- The first time the save arrives with a reward waiting, show it.
		if not autoOpened and new.daily.ready then
			autoOpened = true
			Hub.open("daily")
		end
	end)
end

return Hub
