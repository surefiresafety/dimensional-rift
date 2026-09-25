--!strict
-- Turns what happens in a fight into progress that is kept: experience and
-- levels, Rift Shards, characters joining the roster, absorbed techniques,
-- daily quests, best waves and cleared worlds, plus the daily reward, global
-- boards, badges and the friends bonus. The rules are in Shared.Progression;
-- saving is Profiles.
--
-- Clients ask for things through the Ask RemoteFunction and are told the new
-- state through the Profile event. They never say how much of anything they
-- have: every number here is the server's.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local RulesData = require(Shared.Data.Rules)
local Skills = require(Shared.Data.Skills)
local Styles = require(Shared.Data.Styles)
local Maps = require(Shared.Data.Maps)

local Combat = require(script.Parent.Combat)
local Profiles = require(script.Parent.Profiles)
local Waves = require(script.Parent.Waves)
local Pickups = require(script.Parent.Pickups)

local ProfileRemote = Remotes.get("Profile")
local Ask = Remotes.fn("Ask")

local BOARD_WAVE = "RiftBestWave_v1"
local BOARD_XP = "RiftExperience_v1"

local Progress = {}

local dirty: { [Player]: boolean } = {}
local urgent: { [Player]: boolean } = {}
local lastSent: { [Player]: number } = {}
local badgePending: { [string]: boolean } = {}
-- Hits in a row, and when the last one landed.
local combos: { [Player]: { hits: number, last: number } } = {}
local friends: { [Player]: number } = {}
local friendPairs: { [string]: boolean } = {}
local lastAsk: { [Player]: number } = {}

local function today(): number
	return Progression.dayOf(os.time())
end

-- A player's quests are seeded by who they are, so two friends get different
-- ones but the same player gets the same set on any server that day.
local function seedOf(player: Player): number
	return player.UserId % 1000003
end

local function sortedKeys(t: { [string]: boolean }): { string }
	local out = {}
	for k, v in t do
		if v then
			table.insert(out, k)
		end
	end
	table.sort(out)
	return out
end

--- What the client is told: everything it draws, nothing it could change.
function Progress.snapshot(player: Player, p: Progression.Profile): { [string]: any }
	local level, into, need = Progression.levelOf(p.xp)
	local day = today()
	return {
		loaded = true,
		persistent = Profiles.persistent,
		level = level,
		into = into,
		need = need,
		xp = p.xp,
		shards = p.shards,
		unlocked = sortedKeys(p.unlocked),
		learned = sortedKeys(p.learned),
		loadouts = p.loadouts,
		best = p.best,
		cleared = sortedKeys(p.cleared),
		upgrades = p.upgrades,
		tutorial = p.badges.tutorial == true,
		lastStyle = p.lastStyle,
		daily = {
			ready = Progression.canClaimDaily(p, day),
			streak = p.daily.streak,
			next = Progression.nextStreak(p, day),
		},
		quests = p.quests.list,
		rerolled = p.quests.rerolled,
		stats = p.stats,
		friends = friends[player] or 0,
		friendMul = Progression.friendMul(friends[player] or 0),
	}
end

--- Something the client should see. Most changes go out within a third of
--- a second; quest progress ticking up in a fight (`soon`) at most every
--- two seconds, so a fight does not resend the whole snapshot constantly.
local function mark(player: Player, soon: boolean?)
	dirty[player] = true
	if not soon then
		urgent[player] = true
	end
end
Progress.mark = mark

local function flush()
	local now = os.clock()
	for player in dirty do
		if urgent[player] or now - (lastSent[player] or 0) >= 2 then
			dirty[player], urgent[player] = nil, nil
			lastSent[player] = now
			local p = Profiles.get(player)
			if p and player.Parent then
				ProfileRemote:FireClient(player, Progress.snapshot(player, p))
			end
		end
	end
end

local function setStat(player: Player, name: string, value: number)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	if v and v:IsA("IntValue") then
		v.Value = value
	end
end

local function refreshLeaderstats(player: Player, p: Progression.Profile)
	setStat(player, "Level", (Progression.levelOf(p.xp)))
	setStat(player, "Best Wave", Progression.bestWave(p))
end

local function badge(player: Player, p: Progression.Profile, key: string)
	if p.badges[key] then
		return
	end
	local id = (Config.BADGES :: any)[key]
	if type(id) ~= "number" or id <= 0 then
		p.badges[key] = true -- not set up: tracked, nothing to award
		return
	end
	-- Recorded only once Roblox has it, so a failed award is tried again later.
	local pendingKey = player.UserId .. ":" .. key
	if badgePending[pendingKey] then
		return
	end
	badgePending[pendingKey] = true
	task.spawn(function()
		local ok, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, id)
		end)
		badgePending[pendingKey] = nil
		if ok then
			p.badges[key] = true
		else
			warn(`[Progress] badge {key} for {player.Name}: {err}`)
		end
	end)
end

local function checkRoster(player: Player, p: Progression.Profile)
	local n = 0
	for _, v in p.unlocked do
		if v then
			n += 1
		end
	end
	if n >= 15 then
		badge(player, p, "roster_15")
	end
end

--- Pays out experience and shards. The friends bonus applies to experience
--- earned in a fight, not to rewards that are claimed.
local function award(player: Player, p: Progression.Profile, xp: number, shards: number, claimed: boolean?)
	local mul = if claimed then 1 else Progression.friendMul(friends[player] or 0)
	-- Fortune: more shards from fighting.
	p.shards += math.floor(shards * Progression.upgradeMul(p, "fortune") + 0.5)
	local reached = Progression.addXp(p, xp * mul)
	for _, level in reached do
		Combat.notice(player, `Level {level}! +{Progression.levelReward(level)} Rift Shards.`, "gold")
		if level >= 10 then
			badge(player, p, "level_10")
		end
		if level >= 25 then
			badge(player, p, "level_25")
		end
	end
	refreshLeaderstats(player, p)
	-- A level-up shows at once; shards and experience from a kill can wait.
	mark(player, #reached == 0 and not claimed)
end

local function quest(player: Player, p: Progression.Profile, kind: string, amount: number?)
	local done, moved = Progression.questEvent(p, kind, amount)
	for _, q in done do
		Combat.notice(player, `Quest complete: {q.text}. Claim it from the menu (J).`, "gold")
	end
	if #done > 0 then
		mark(player)
	elseif moved then
		mark(player, true)
	end
end

local function unlock(player: Player, p: Progression.Profile, styleId: string, why: string)
	if p.unlocked[styleId] or not Styles[styleId] then
		return
	end
	p.unlocked[styleId] = true
	Combat.notice(player, `{Styles[styleId].name} joins your roster: {why}.`, "gold")
	checkRoster(player, p)
	mark(player)
end

--- An upgrade's multiplier for this player (1 before their save loads).
function Progress.upgradeMul(player: Player, key: string): number
	return Progression.upgradeMul(Profiles.get(player), key)
end

--- Puts the player's upgrades into their fight: damage, energy, speed, and
--- health at once (keeping how hurt they are).
function Progress.applyUpgrades(player: Player)
	local ps = Combat.states[player]
	local p = Profiles.get(player)
	if not ps or not p then
		return
	end
	ps.powerMul = Progression.upgradeMul(p, "power")
	ps.moveMul = Progression.upgradeMul(p, "swiftness")
	local spirit = Progression.upgradeMul(p, "spirit")
	if ps.maxSe ~= math.huge then
		ps.maxSe = ps.maxSe / ps.spiritMul * spirit
	end
	ps.spiritMul = spirit
	local hum = Combat.humanoidOf(player)
	if hum and hum.Health > 0 then
		local frac = hum.Health / hum.MaxHealth
		hum.MaxHealth = Config.PLAYER_MAX_HP * Progression.upgradeMul(p, "vitality")
		hum.Health = hum.MaxHealth * frac
	end
	Combat.publish(ps)
end

--- Can this player pick this character? Before the save loads, only the
--- starters.
function Progress.canPlay(player: Player, styleId: string): boolean
	if not Styles[styleId] then
		return false
	end
	local p = Profiles.get(player)
	if not p then
		return table.find(Progression.STARTERS, styleId) ~= nil
	end
	return p.unlocked[styleId] == true
end

--- The slots a style starts with for this player: their saved loadout, or the
--- style's own.
function Progress.slotsFor(player: Player, styleId: string): { string }
	return Progression.slotsFor(Profiles.get(player), Styles[styleId], styleId)
end

function Progress.chose(player: Player, styleId: string)
	local p = Profiles.get(player)
	if p then
		p.lastStyle = styleId
		Progression.bump(p, "picks")
		mark(player)
	end
end

function Progress.died(player: Player)
	local p = Profiles.get(player)
	if p then
		Progression.bump(p, "deaths")
		mark(player)
	end
end

-- Friends --------------------------------------------------------------------

local function pairKey(a: Player, b: Player): string
	local x, y = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	return x .. ":" .. y
end

--- `leaving` is a player on their way out: still in GetPlayers during
--- PlayerRemoving, but no longer anyone's bonus.
local function recount(leaving: Player?)
	local gone = if leaving then leaving.UserId else -1
	for _, a in Players:GetPlayers() do
		if a.UserId == gone then
			continue
		end
		local n = 0
		for _, b in Players:GetPlayers() do
			if a ~= b and b.UserId ~= gone and friendPairs[pairKey(a, b)] then
				n += 1
			end
		end
		if friends[a] ~= n then
			local was = friends[a] or 0
			friends[a] = n
			if n > was then
				Combat.notice(
					a,
					`Playing with {n} friend{if n == 1 then "" else "s"}: +{math.floor(
						(Progression.friendMul(n) - 1) * 100 + 0.5
					)}% experience.`,
					"gold"
				)
			end
			mark(a)
		end
	end
end

local function checkFriends(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player and friendPairs[pairKey(player, other)] == nil then
			local ok, yes = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			friendPairs[pairKey(player, other)] = ok and yes == true
		end
	end
	recount()
end

-- Requests -------------------------------------------------------------------

type Answer = { ok: boolean, message: string?, [string]: any }

local function answer(ok: boolean, message: string?, extra: { [string]: any }?): Answer
	local a: Answer = { ok = ok, message = message }
	if extra then
		for k, v in extra do
			a[k] = v
		end
	end
	return a
end

local asks: { [string]: (Player, Progression.Profile, any, any) -> Answer } = {}

asks.claimDaily = function(player, p)
	local reward, streak = Progression.claimDaily(p, today())
	if not reward then
		return answer(false, "Already claimed today. Come back tomorrow for day " .. (p.daily.streak + 1) .. ".")
	end
	award(player, p, reward.xp, 0, true)
	if streak >= 7 then
		badge(player, p, "streak_7")
	end
	Progression.bump(p, "dailies")
	return answer(true, `Day {streak}: +{reward.shards} Rift Shards and +{reward.xp} experience.`)
end

asks.claimQuest = function(player, p, index)
	if type(index) ~= "number" or index % 1 ~= 0 then
		return answer(false, "No such quest.")
	end
	local q, why = Progression.claimQuest(p, index)
	if not q then
		return answer(false, why)
	end
	award(player, p, q.xp, 0, true)
	Progression.bump(p, "quests")
	return answer(true, `+{q.shards} Rift Shards and +{q.xp} experience.`)
end

asks.rerollQuest = function(player, p, index)
	if type(index) ~= "number" or index % 1 ~= 0 then
		return answer(false, "No such quest.")
	end
	local ok, why = Progression.rerollQuest(p, index, seedOf(player))
	mark(player)
	return answer(ok, if ok then "Quest swapped." else why)
end

asks.buy = function(player, p, styleId)
	if type(styleId) ~= "string" then
		return answer(false, "No such character.")
	end
	local ok, why = Progression.buy(p, styleId, Styles[styleId] ~= nil)
	if ok then
		Combat.notice(player, `{Styles[styleId].name} joins your roster.`, "gold")
		checkRoster(player, p)
		mark(player)
	end
	return answer(ok, if ok then "Unlocked." else why)
end

asks.loadout = function(player, p, styleId, slots)
	if type(styleId) ~= "string" or not Styles[styleId] or not p.unlocked[styleId] then
		return answer(false, "That character is not on your roster.")
	end
	local ok, why = Progression.setLoadout(p, Styles[styleId], styleId, slots, RulesData.MAX_SLOTS, function(id)
		return Skills[id] ~= nil
	end)
	if not ok then
		return answer(false, why)
	end
	-- Playing as them right now (and not transformed): it takes effect at once.
	local ps = Combat.states[player]
	if ps and ps.style == styleId and not ps.baseStyle then
		ps.slots = Progress.slotsFor(player, styleId)
		Combat.checkInfinity(ps)
		Combat.publish(ps)
	end
	mark(player)
	return answer(true, "Loadout saved.")
end

-- The client is listening: send it the state now.
asks.sync = function(player, _p)
	mark(player)
	return answer(true)
end

asks.tutorialDone = function(player, p)
	if not p.badges.tutorial then
		p.badges.tutorial = true
		mark(player)
	end
	return answer(true)
end

asks.upgrade = function(player, p, key)
	if type(key) ~= "string" then
		return answer(false, "No such upgrade.")
	end
	local ok, why = Progression.buyUpgrade(p, key)
	if ok then
		Progress.applyUpgrades(player)
		mark(player)
	end
	return answer(ok, if ok then "Upgraded." else why)
end

asks.board = function(_player, _p, name)
	local rows = if name == "wave" then Profiles.top(BOARD_WAVE) elseif name == "xp" then Profiles.top(BOARD_XP) else {}
	return answer(true, if Profiles.persistent then nil else "Global boards need DataStores.", { rows = rows })
end

-- Wiring ---------------------------------------------------------------------

local function onLoaded(player: Player, p: Progression.Profile)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = ls
	local wave = Instance.new("IntValue")
	wave.Name = "Best Wave"
	wave.Parent = ls
	ls.Parent = player
	refreshLeaderstats(player, p)

	Progression.refreshQuests(p, today(), seedOf(player))
	Progress.applyUpgrades(player)
	-- Anything absorbed in earlier sessions can be slotted again.
	local ps = Combat.states[player]
	if ps then
		for id in p.learned do
			ps.learned[id] = true
		end
		Combat.publish(ps)
	end
	if not p.badges.welcome then
		badge(player, p, "welcome")
		Combat.notice(player, "Welcome to the rift. Six fighters are yours already; beat a boss to win theirs.", "gold")
	elseif Progression.canClaimDaily(p, today()) then
		Combat.notice(
			player,
			`Welcome back. Your day {Progression.nextStreak(p, today())} reward is waiting (J).`,
			"gold"
		)
	end
	checkRoster(player, p)
	mark(player)
	task.spawn(checkFriends, player)
end

local function onSaving(player: Player, p: Progression.Profile)
	local ps = Combat.states[player]
	if ps and ps.style then
		p.lastStyle = ps.baseStyle or ps.style
	end
	Profiles.post(BOARD_XP, player.UserId, p.xp)
	Profiles.post(BOARD_WAVE, player.UserId, Progression.bestWave(p))
end

function Progress.start()
	Profiles.onLoaded(onLoaded)
	Profiles.onSaving(onSaving)

	Combat.onKilled(function(e, by)
		if not by then
			return
		end
		local player = by.player
		local p = Profiles.get(player)
		if not p then
			return
		end
		local xp, shards = Progression.killReward(e.id, e.t)
		if e.affix then
			xp *= 2 -- elites are worth twice the experience
		end
		award(player, p, xp, shards)
		Progression.bump(p, "kills")
		quest(player, p, "kill")
		if e.t.boss then
			quest(player, p, "elite")
		end
		if e.t.drops and Skills[e.t.drops] and not p.learned[e.t.drops] then
			p.learned[e.t.drops] = true
		end
		local styleId = Progression.bossStyle(e.id)
		if styleId and Styles[styleId] then
			Progression.bump(p, "bosses")
			badge(player, p, "first_boss")
			unlock(player, p, styleId, "you beat them")
		end
	end)

	Combat.onEvent(function(ps, kind, amount)
		if kind == "damage" and amount > 0 then
			local c = combos[ps.player]
			if not c then
				c = { hits = 0, last = 0 }
				combos[ps.player] = c
			end
			c.hits += 1
			c.last = os.clock()
			ps.player:SetAttribute("Combo", c.hits)
		end
		local p = Profiles.get(ps.player)
		if not p then
			return
		end
		if kind == "damage" then
			Progression.bump(p, "damage", math.floor(amount))
		else
			Progression.bump(p, kind .. "s")
		end
		quest(ps.player, p, kind, amount)
	end)

	Waves.onCleared(function(mapId, n)
		for player, ps in Combat.states do
			local p = Profiles.get(player)
			if p and ps.style then
				local xp, shards = Progression.waveReward(n)
				award(player, p, xp, shards)
				Progression.bump(p, "waves")
				quest(player, p, "wave")
				if Progression.recordWave(p, mapId, n) then
					refreshLeaderstats(player, p)
				end
			end
		end
	end)

	Waves.onWorldCleared(function(mapId)
		for player, ps in Combat.states do
			local p = Profiles.get(player)
			if p and ps.style then
				local first = not p.cleared[mapId]
				p.cleared[mapId] = true
				local xp, shards = Progression.worldReward(first)
				award(player, p, xp, shards)
				Progression.bump(p, "worlds")
				badge(player, p, "world_clear")
				Combat.notice(
					player,
					`{Maps[mapId].name} cleared{if first then " for the first time" else ""}: +{shards} Rift Shards.`,
					"gold"
				)
			end
		end
	end)

	Ask.OnServerInvoke = function(player: Player, action: any, a: any, b: any): Answer
		local now = os.clock()
		if now - (lastAsk[player] or 0) < 0.2 then
			return answer(false, "Slow down.")
		end
		lastAsk[player] = now
		local p = Profiles.get(player)
		if not p then
			return answer(false, "Your save is still loading.")
		end
		local fn = if type(action) == "string" then asks[action] else nil
		if not fn then
			return answer(false, "Unknown request.")
		end
		local ok, result = pcall(fn, player, p, a, b)
		if not ok then
			warn(`[Progress] {action} for {player.Name} failed: {result}`)
			return answer(false, "Something went wrong. Try again.")
		end
		return result
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		recount(player)
		dirty[player], urgent[player], lastSent[player] = nil, nil, nil
		combos[player] = nil
		friends[player] = nil
		lastAsk[player] = nil
		for key in friendPairs do
			local a, b = string.match(key, "^(%d+):(%d+)$")
			if tonumber(a) == player.UserId or tonumber(b) == player.UserId then
				friendPairs[key] = nil
			end
		end
	end)

	-- Once a minute: play time, and a new day's quests for anyone online
	-- when midnight UTC goes past.
	task.spawn(function()
		while true do
			task.wait(60)
			local day = today()
			for _, player in Players:GetPlayers() do
				local p = Profiles.get(player)
				if p then
					Progression.bump(p, "minutes")
					if Progression.refreshQuests(p, day, seedOf(player)) then
						Combat.notice(player, "A new day: new quests, and a new daily reward (J).", "gold")
					end
					mark(player)
				end
			end
		end
	end)

	-- Shards picked up off the floor.
	Pickups.onShards = function(player, n)
		local p = Profiles.get(player)
		if p then
			local got = math.floor(n * Progression.upgradeMul(p, "fortune") + 0.5)
			p.shards += got
			Progression.bump(p, "shardsFound", got)
			mark(player, true)
		end
	end
	Combat.onKilled(function(e)
		Pickups.fromKill(e)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.3 then
			acc = 0
			flush()
			-- A combo ends three seconds after its last hit, and pays out.
			local now = os.clock()
			for player, c in combos do
				if now - c.last > Progression.COMBO_WINDOW then
					combos[player] = nil
					if player.Parent then
						player:SetAttribute("Combo", nil)
						local p = Profiles.get(player)
						if p and c.hits >= 5 then
							local xp, shards = Progression.comboReward(c.hits)
							award(player, p, xp, shards)
							quest(player, p, "combo", c.hits)
							if c.hits > (p.stats.bestCombo or 0) then
								p.stats.bestCombo = c.hits
							end
							if c.hits >= 10 then
								Combat.notice(
									player,
									`{Progression.comboRank(c.hits)} rank: {c.hits}-hit combo. +{xp} XP{if shards
											> 0
										then `, +{shards} shards`
										else ""}.`,
									"gold"
								)
							end
						end
					end
				end
			end
		end
	end)
end

return Progress
