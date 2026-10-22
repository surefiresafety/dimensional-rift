--!strict
-- The HUD: vitals, the ability rail with its cooldowns, the wave chip, the
-- combat log and the big centre banner. Thin, corner-pinned and unlit, like
-- the web build's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Worlds)
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)
local RulesData = require(Shared.Data.Rules)
local Skills = require(Shared.Data.Skills)
local Styles = require(Shared.Data.Styles)
local Arsenals = require(Shared.Data.Arsenals)
local Rules = require(Shared.Rules)

local Ui = require(script.Parent.Ui)
local Profile = require(script.Parent.Profile)
local Sfx = require(script.Parent.Sfx)
local Radar = require(script.Parent.Radar)
local Progression = require(Shared.Progression)

local player = Players.LocalPlayer
local Hud = {}

local gui: ScreenGui
local hpFill: Frame, hpText: TextLabel, seFill: Frame, seText: TextLabel, nameText: TextLabel
local status: TextLabel
local levelText: TextLabel, xpFill: Frame, shardText: TextLabel, menuDot: Frame
local waveTitle: TextLabel, waveSub: TextLabel, mapName: TextLabel
local rail: Frame
local logBox: Frame
local banner: TextLabel
local tiles: { { frame: Frame, cd: Frame, key: string } } = {}
local cooldowns: { [string]: { readyAt: number, duration: number } } = {}

local function bar(parent: Instance, y: number, colour: Color3): (Frame, TextLabel, TextLabel)
	local label = Ui.label({
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 11,
		TextColor3 = Ui.DIM,
		Font = Ui.BOLD,
		Parent = parent,
	})
	local value = Ui.label({
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Ui.BOLD,
		Parent = parent,
	})
	local track = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, y + 17),
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = parent,
	}, { Ui.corner(5) })
	local fill = Ui.make(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = colour, BorderSizePixel = 0, Parent = track },
		{ Ui.corner(5) }
	)
	return fill, label, value
end

local SYM = Color3.fromRGB(255, 107, 122)
-- Roblox's own top bar (menu, chat) sits over the first 58 pixels.
local TOP = 66

--- One line under the vitals for whatever this character carries: the drawn
--- weapon, a stored or building charge, and the symbiote's three bars.
local function statusText(now: number): string
	local bits = {}
	local weapon = player:GetAttribute("Weapon") :: string?
	local style = player:GetAttribute("Style") :: string?
	local set = style and (Arsenals :: any)[style]
	if set then
		local w = if weapon then set.items[weapon] else nil
		table.insert(bits, if w then string.upper(w.name) else "NOTHING DRAWN")
	end
	local start = player:GetAttribute("ChargeStart") :: number?
	if start then
		local held = now - start
		local tier = RulesData.OUTPUT_TIERS[Rules.outputTier(RulesData.OUTPUT_TIERS, held)]
		table.insert(bits, `POWERING UP: {string.upper(tier.name)} {string.format("%.1f", held)}s`)
	else
		local output = player:GetAttribute("Output") :: string?
		if output then
			table.insert(bits, string.upper(output) .. " STORED")
		end
	end
	local suit = player:GetAttribute("Suit") :: number?
	if suit then
		table.insert(bits, `SUIT {suit}/{player:GetAttribute("SuitMax")}`)
	end
	local hunger = player:GetAttribute("Hunger") :: number?
	if hunger then
		table.insert(bits, `HUNGER {hunger}%`)
	end
	local bond = player:GetAttribute("Bond") :: number?
	if bond then
		table.insert(bits, `BOND {bond}%`)
	end
	if player:GetAttribute("LooseSuit") then
		table.insert(bits, "SUIT ON THE GROUND: F")
	end
	return table.concat(bits, "  ·  ")
end

local function renderRail()
	for _, c in rail:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	table.clear(tiles)
	local styleId = player:GetAttribute("Style") :: string?
	local slotsAttr = (player:GetAttribute("Slots") :: string?) or ""
	if not styleId or slotsAttr == "" then
		return
	end
	local entries = {}
	for i, id in string.split(slotsAttr, ",") do
		local s = Skills[id]
		if s then
			table.insert(entries, {
				key = id,
				label = tostring(i),
				name = s.name,
				sub = RulesData.NATURE[s.nature].label,
				cost = s.cost,
				color = RulesData.NATURE[s.nature].color,
				ult = false,
			})
		end
	end
	local u = Styles[styleId].ultimate
	table.insert(
		entries,
		{ key = "ult", label = "G", name = u.name, sub = "Ultimate", cost = u.cost, color = 0xffd54a, ult = true }
	)
	for i, en in entries do
		local f = Ui.make("Frame", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(88, 86),
			BackgroundColor3 = Ui.PANEL,
			BackgroundTransparency = 0.12,
			ClipsDescendants = true,
			Parent = rail,
		}, { Ui.corner(14), Ui.stroke(if en.ult then Ui.GOLD else Ui.LINE, 1, if en.ult then 0.2 else 0.4) })
		Ui.label({
			Text = en.label,
			Font = Ui.BOLD,
			TextSize = 11,
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(20, 14),
			Parent = f,
		})
		Ui.label({
			Text = `{en.cost} SE`,
			TextSize = 10,
			TextColor3 = Ui.SE,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -58, 0, 6),
			Size = UDim2.fromOffset(50, 14),
			Parent = f,
		})
		Ui.label({
			Text = en.name,
			Font = Ui.BOLD,
			TextSize = 12,
			Position = UDim2.fromOffset(8, 24),
			Size = UDim2.new(1, -14, 0, 42),
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Parent = f,
		})
		Ui.label({
			Text = string.upper(en.sub),
			TextSize = 9,
			TextColor3 = Palette.color(en.color),
			Position = UDim2.new(0, 8, 1, -18),
			Size = UDim2.new(1, -14, 0, 12),
			Parent = f,
		})
		local cd = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = f,
		})
		table.insert(tiles, { frame = f, cd = cd, key = en.key })
	end
end

--- How much of a technique's cooldown is left, 0 (ready) to 1.
function Hud.cooldownLeft(key: string): number
	local c = cooldowns[key]
	if not c or c.duration <= 0 then
		return 0
	end
	return math.clamp((c.readyAt - workspace:GetServerTimeNow()) / c.duration, 0, 1)
end

function Hud.log(text: string, tone: string?)
	local line = Ui.label({
		Text = text,
		TextSize = 14,
		Font = if tone == "gold" or tone == "sym" then Ui.BOLD else Ui.BODY,
		TextColor3 = if tone == "gold" then Ui.GOLD elseif tone == "sym" then SYM else Ui.TEXT,
		TextStrokeTransparency = 0.5,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = math.floor(os.clock() * 1000),
		Parent = logBox,
	})
	local lines = {}
	for _, c in logBox:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(lines, c)
		end
	end
	if #lines > 6 then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	task.delay(9, function()
		if line.Parent then
			TweenService:Create(line, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.6)
			line:Destroy()
		end
	end)
end

function Hud.banner(text: string, colour: number?)
	banner.Text = text
	banner.TextColor3 = Palette.color(colour or 0xffd54a)
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	TweenService:Create(
		banner,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.1),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
end

--- Set by the client's entry point: what the MENU button opens.
Hud.onMenu = function() end

local function renderProfile(d: { [string]: any }?)
	if not d then
		levelText.Text = "LOADING SAVE"
		xpFill.Size = UDim2.fromScale(0, 1)
		shardText.Text = ""
		menuDot.Visible = false
		return
	end
	levelText.Text = `LV {d.level}`
	xpFill.Size = UDim2.fromScale(if d.need > 0 then math.clamp(d.into / d.need, 0, 1) else 1, 1)
	shardText.Text = `{Profile.shards(d.shards)} SHARDS`
	-- A dot on the menu button when something is waiting to be claimed.
	local waiting = d.daily.ready
	for _, q in d.quests do
		waiting = waiting or (q.progress >= q.goal and not q.claimed)
	end
	menuDot.Visible = waiting
end

function Hud.build()
	gui = Ui.make("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local vitals = Ui.make("Frame", {
		Position = UDim2.fromOffset(20, TOP),
		Size = UDim2.fromOffset(292, 84),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.4,
		Parent = gui,
	}, { Ui.corner(14), Ui.stroke(), Ui.pad(12) })
	local hpLabel, seLabel
	hpFill, hpLabel, hpText = bar(vitals, 0, Ui.HP)
	seFill, seLabel, seText = bar(vitals, 32, Ui.SE)
	status = Ui.label({
		Position = UDim2.fromOffset(20, TOP + 88),
		Size = UDim2.fromOffset(520, 16),
		TextSize = 11,
		Font = Ui.BOLD,
		TextColor3 = Ui.DIM,
		TextStrokeTransparency = 0.6,
		TextWrapped = false,
		Parent = gui,
	})
	hpLabel.Text = "HEALTH"
	seLabel.Text = "SPIRIT ENERGY"
	nameText = hpLabel

	local wave = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, TOP),
		Size = UDim2.fromOffset(240, 72),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.4,
		Parent = gui,
	}, { Ui.corner(14), Ui.stroke(), Ui.pad(10) })
	mapName = Ui.label({
		Text = "",
		Font = Ui.BOLD,
		TextSize = 10,
		TextColor3 = Ui.ACCENT,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 12),
		Parent = wave,
	})
	waveTitle = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 28,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = wave,
	})
	waveSub = Ui.label({
		Text = "",
		TextSize = 11,
		TextColor3 = Ui.DIM,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = wave,
	})

	-- Level, experience and shards, under the wave chip, with the menu button.
	local chip = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, TOP + 78),
		Size = UDim2.fromOffset(240, 46),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.4,
		Parent = gui,
	}, { Ui.corner(14), Ui.stroke(), Ui.pad(8) })
	levelText = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 20,
		TextColor3 = Ui.GOLD,
		Size = UDim2.fromOffset(110, 18),
		Parent = chip,
	})
	shardText = Ui.label({
		Text = "",
		Font = Ui.BOLD,
		TextSize = 10,
		TextColor3 = Ui.ACCENT,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, -66, 0, 14),
		Parent = chip,
	})
	local xpTrack = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -66, 0, 6),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = chip,
	}, { Ui.corner(3) })
	xpFill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.GOLD,
		BorderSizePixel = 0,
		Parent = xpTrack,
	}, { Ui.corner(3) })
	local menu = Ui.make("TextButton", {
		Text = "MENU",
		Font = Ui.BOLD,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Ui.ACCENT,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(58, 28),
		Parent = chip,
	}, { Ui.corner(14) })
	menuDot = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.fromRGB(255, 70, 90),
		Visible = false,
		Parent = menu,
	}, { Ui.corner(5) })
	menu.Activated:Connect(function()
		Hud.onMenu()
	end)
	renderProfile(Profile.data)
	Profile.changed:Connect(function(new: any, old: any)
		renderProfile(new)
		if old and new.level > old.level then
			Hud.banner(`LEVEL {new.level}`, 0xffd54a)
			Sfx.play("level")
		end
	end)

	Radar.build(gui, TOP + 132, UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

	-- A boss that is after you gets its name and health across the top.
	local bossBar = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP),
		Size = UDim2.new(0.4, 0, 0, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Ui.make("UISizeConstraint", { MaxSize = Vector2.new(560, 44), MinSize = Vector2.new(220, 44) }) })
	local bossName = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(255, 120, 130),
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = bossBar,
	})
	local bossTrack = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		Parent = bossBar,
	}, { Ui.corner(6), Ui.stroke(Color3.fromRGB(255, 70, 90), 1, 0.3) })
	local bossFill = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(230, 50, 70),
		BorderSizePixel = 0,
		Parent = bossTrack,
	}, { Ui.corner(6) })
	task.spawn(function()
		while gui.Parent do
			local best, bestD = nil, math.huge
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			local folder = workspace:FindFirstChild("Enemies")
			if root and folder then
				for _, m in folder:GetChildren() do
					local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
					local hum = m:FindFirstChildOfClass("Humanoid")
					if m:GetAttribute("Boss") and m:GetAttribute("Hunting") and r and hum and hum.Health > 0 then
						local d = (r.Position - root.Position).Magnitude
						if d < bestD then
							best, bestD = m, d
						end
					end
				end
			end
			local hum = best and best:FindFirstChildOfClass("Humanoid")
			bossBar.Visible = hum ~= nil
			if hum then
				bossName.Text = string.upper(string.split(hum.DisplayName, "  ·  ")[1])
				bossFill.Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1)
			end
			task.wait(0.1)
		end
	end)

	-- The combo: hits in a row and the rank they have reached, at the right
	-- edge of the screen, punching bigger with every hit.
	local combo = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.62, 0),
		Size = UDim2.fromOffset(200, 96),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local rank = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 64,
		TextColor3 = Ui.GOLD,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 62),
		Parent = combo,
	})
	local hits = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 26,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = combo,
	})
	local pop = Ui.make("UIScale", { Parent = combo })
	local RANK_COLOUR: { [string]: Color3 } = {
		D = Color3.fromRGB(160, 160, 180),
		C = Color3.fromRGB(120, 200, 255),
		B = Color3.fromRGB(80, 230, 150),
		A = Color3.fromRGB(255, 213, 74),
		S = Color3.fromRGB(255, 140, 60),
		SS = Color3.fromRGB(255, 70, 90),
		SSS = Color3.fromRGB(200, 110, 255),
	}
	player:GetAttributeChangedSignal("Combo"):Connect(function()
		local n = player:GetAttribute("Combo") :: number?
		if not n or n < 2 then
			combo.Visible = false
			return
		end
		local r = Progression.comboRank(n)
		combo.Visible = true
		rank.Text = r
		rank.TextColor3 = RANK_COLOUR[r] or Ui.GOLD
		hits.Text = `{n} HITS`
		pop.Scale = 1.25
		TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)

	rail = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(600, 86),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Above the ability rail, so the two never overlap on a narrow screen.
	logBox = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -124),
		Size = UDim2.fromOffset(340, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.make("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})

	banner = Ui.label({
		Text = "",
		Font = Ui.DISPLAY,
		TextSize = 56,
		TextColor3 = Ui.GOLD,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 70),
		Parent = gui,
	})

	-- On a phone the TouchPad shows the techniques; the rail would sit under it.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		rail.Visible = false
		logBox.Position = UDim2.new(0, 20, 1, -16)
		logBox.Size = UDim2.fromOffset(300, 96)
	end

	player:GetAttributeChangedSignal("Slots"):Connect(renderRail)
	player:GetAttributeChangedSignal("Style"):Connect(renderRail)
	renderRail()

	Remotes.get("Cooldown").OnClientEvent:Connect(function(key: string, readyAt: number, duration: number)
		cooldowns[key] = { readyAt = readyAt, duration = duration }
	end)
	Remotes.get("Notice").OnClientEvent:Connect(Hud.log)
	local countdown = 0
	Remotes.get("Wave").OnClientEvent:Connect(function(mapId: string, n: number, left: number, nextIn: number?)
		local m = Worlds.get(mapId)
		mapName.Text = string.upper(if m then m.name else mapId)
		waveTitle.Text = `Wave {n}`
		countdown += 1
		if nextIn then
			-- Between waves: count down to the next one.
			local mine = countdown
			task.spawn(function()
				for s = math.ceil(nextIn), 1, -1 do
					if countdown ~= mine then
						return
					end
					waveSub.Text = `next wave in {s}`
					task.wait(1)
				end
			end)
		else
			waveSub.Text = `{left} enem{if left == 1 then "y" else "ies"} left`
		end
	end)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			hpFill.Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1)
			hpText.Text = `{math.floor(hum.Health)} / {math.floor(hum.MaxHealth)}`
		end
		local se = (player:GetAttribute("SE") :: number?) or 0
		local maxSe = (player:GetAttribute("MaxSE") :: number?) or 1000
		if maxSe < 0 then -- infinite
			seFill.Size = UDim2.fromScale(1, 1)
			seText.Text = "∞"
		else
			seFill.Size = UDim2.fromScale(math.clamp(se / maxSe, 0, 1), 1)
			seText.Text = `{math.floor(se)} / {maxSe}`
		end
		local styleId = player:GetAttribute("Style") :: string?
		nameText.Text = if styleId then string.upper(string.split(Styles[styleId].name, ":")[1]) else "HEALTH"
		local now = workspace:GetServerTimeNow()
		status.Text = statusText(now)
		for _, t in tiles do
			local c = cooldowns[t.key]
			local k = if c and c.duration > 0 then math.clamp((c.readyAt - now) / c.duration, 0, 1) else 0
			t.cd.Size = UDim2.fromScale(1, k)
		end
	end)
end

return Hud
