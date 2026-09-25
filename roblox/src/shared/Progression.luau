--!strict
-- What a player keeps between sessions, and the rules for earning it: levels,
-- Rift Shards, the roster, absorbed techniques and loadouts, the daily reward
-- streak, daily quests, best waves and worlds cleared.
--
-- Like Rules, nothing in here touches Roblox: no Instances, no services, no
-- clock, no random numbers of its own. Time and seeds come in as arguments, so
-- every rule runs under Lune (tests/progression.spec.luau). The server applies
-- the results and saves them (src/server/Progress.luau, Profiles.luau).

local Progression = {}

Progression.VERSION = 1

-- Free from the first session: one from each corner of the multiverse, so
-- nobody has to grind before they can play the universe they came for.
Progression.STARTERS = { "spiderman", "naruto", "yuji", "megumi", "sasuke", "nobara" }

-- Everyone else joins by beating their boss, or for Rift Shards.
Progression.PRICE = 350
Progression.PREMIUM_PRICE = 900
Progression.PREMIUM = {
	gojo = true,
	sukuna = true,
	venom = true,
	itachi = true,
	pain = true,
	strange = true,
	jean = true,
	yuta = true,
	kenjaku = true,
	might_guy = true,
}

-- Seven days, then it starts again. Day seven is worth coming back for.
Progression.DAILY = {
	{ shards = 40, xp = 60 },
	{ shards = 60, xp = 80 },
	{ shards = 80, xp = 100 },
	{ shards = 100, xp = 140 },
	{ shards = 130, xp = 180 },
	{ shards = 160, xp = 220 },
	{ shards = 300, xp = 400 },
}

export type Quest = {
	id: string, -- the template
	kind: string, -- which event advances it
	best: boolean?, -- keeps the best value seen instead of adding up
	text: string,
	goal: number,
	progress: number,
	claimed: boolean,
	shards: number,
	xp: number,
}

-- `kind` is the event that advances it (see Progression.questEvent). A goal
-- is picked from `goals` by the day's seed.
Progression.QUESTS = {
	{ id = "kills", kind = "kill", text = "Defeat %d enemies", goals = { 30, 45, 60 }, shards = 60, xp = 120 },
	{ id = "elites", kind = "elite", text = "Defeat %d alphas or bosses", goals = { 2, 3, 4 }, shards = 80, xp = 160 },
	{ id = "waves", kind = "wave", text = "Clear %d waves", goals = { 6, 10, 14 }, shards = 70, xp = 140 },
	{ id = "casts", kind = "cast", text = "Use %d techniques", goals = { 40, 60, 90 }, shards = 50, xp = 100 },
	{
		id = "crits",
		kind = "crit",
		text = "Land %d Black Flashes or critical hits",
		goals = { 3, 5, 8 },
		shards = 70,
		xp = 140,
	},
	{ id = "damage", kind = "damage", text = "Deal %d damage", goals = { 8000, 15000, 25000 }, shards = 60, xp = 120 },
	{ id = "strikes", kind = "strike", text = "Land %d basic attacks", goals = { 60, 100, 150 }, shards = 40, xp = 90 },
	{
		id = "charged",
		kind = "output",
		text = "Release %d charged techniques (B)",
		goals = { 3, 5, 8 },
		shards = 60,
		xp = 120,
	},
	-- `best`: progress is the best single value seen, not a running total.
	{
		id = "combo",
		kind = "combo",
		best = true,
		text = "Reach a %d-hit combo",
		goals = { 20, 35, 50 },
		shards = 70,
		xp = 140,
	},
}
Progression.QUESTS_PER_DAY = 3
Progression.QUEST_REROLL_COST = 25

export type Profile = {
	version: number,
	xp: number, -- lifetime; the level is worked out from it
	shards: number,
	unlocked: { [string]: boolean },
	learned: { [string]: boolean }, -- techniques absorbed from enemies
	loadouts: { [string]: { string } }, -- per style, when changed from its default
	best: { [string]: number }, -- best wave reached, per world
	cleared: { [string]: boolean }, -- worlds whose last scripted wave fell
	daily: { day: number, streak: number },
	quests: { day: number, list: { Quest }, rerolled: boolean },
	stats: { [string]: number },
	badges: { [string]: boolean },
	upgrades: { [string]: number }, -- permanent upgrades bought with shards
	lastStyle: string?,
}

--- A new player's save.
function Progression.newProfile(): Profile
	local unlocked = {}
	for _, id in Progression.STARTERS do
		unlocked[id] = true
	end
	return {
		version = Progression.VERSION,
		xp = 0,
		shards = 0,
		unlocked = unlocked,
		learned = {},
		loadouts = {},
		best = {},
		cleared = {},
		daily = { day = -1, streak = 0 },
		quests = { day = -1, list = {}, rerolled = false },
		stats = {},
		badges = {},
		upgrades = {},
		lastStyle = nil,
	}
end

--- Brings any saved table up to the current shape: missing fields get their
--- defaults, wrong types are replaced, and the starters are always unlocked.
--- Safe to run on every load, and on a table from an older version.
function Progression.reconcile(saved: any): Profile
	local fresh = Progression.newProfile()
	if type(saved) ~= "table" then
		return fresh
	end
	local out: any = {}
	for k, v in fresh :: any do
		local s = saved[k]
		out[k] = if s ~= nil and type(s) == type(v) then s else v
	end
	if type(saved.lastStyle) == "string" then
		out.lastStyle = saved.lastStyle
	end
	if type(out.daily.day) ~= "number" or type(out.daily.streak) ~= "number" then
		out.daily = fresh.daily
	end
	if type(out.quests.day) ~= "number" or type(out.quests.list) ~= "table" then
		out.quests = fresh.quests
	end
	out.quests.rerolled = out.quests.rerolled == true
	for _, id in Progression.STARTERS do
		out.unlocked[id] = true
	end
	out.xp = math.max(0, math.floor(tonumber(out.xp) or 0))
	out.shards = math.max(0, math.floor(tonumber(out.shards) or 0))
	out.version = Progression.VERSION
	return out
end

-- Levels -------------------------------------------------------------------

Progression.MAX_LEVEL = 100

--- Experience to go from `level` to the next one.
function Progression.xpToNext(level: number): number
	return math.floor(100 * level ^ 1.35)
end

--- The level lifetime experience reaches, how far into it, and how much the
--- level takes in total.
function Progression.levelOf(xp: number): (number, number, number)
	local level, left = 1, xp
	while level < Progression.MAX_LEVEL do
		local need = Progression.xpToNext(level)
		if left < need then
			return level, left, need
		end
		left -= need
		level += 1
	end
	return level, 0, 0
end

--- Shards for reaching a level: more the higher you go.
function Progression.levelReward(level: number): number
	return 20 + level * 5
end

-- Earning ------------------------------------------------------------------

--- What an enemy is worth: `id` and its template (Data/Enemies). The data
--- marks all three kinds of boss with `boss`; the id tells them apart.
function Progression.killReward(id: string, t: { hp: number, boss: boolean? }): (number, number)
	if string.match(id, "^boss_") then
		return 150, 25 -- a character boss
	elseif string.match(id, "_alpha$") then
		return 60, 8
	elseif t.boss then
		return 100, 15 -- a story boss (Kazan, the Nuime body, ...)
	end
	return math.max(5, math.floor(t.hp / 20 + 0.5)), 1
end

--- What clearing wave `n` (1-based) is worth to everyone who was there.
function Progression.waveReward(n: number): (number, number)
	return 20 + 5 * n, 2 + math.floor(n / 5) * 3
end

--- Clearing a whole world: the last scripted wave, which is its last boss.
function Progression.worldReward(firstTime: boolean): (number, number)
	if firstTime then
		return 600, 250
	end
	return 200, 60
end

--- Playing with friends: +10% experience for each friend on the server, up
--- to three.
function Progression.friendMul(friends: number): number
	return 1 + 0.1 * math.clamp(friends, 0, 3)
end

--- Adds experience. Returns every level newly reached, in order, and the
--- shards they paid out (already added).
function Progression.addXp(p: Profile, amount: number): ({ number }, number)
	local before = Progression.levelOf(p.xp)
	p.xp += math.max(0, math.floor(amount + 0.5))
	local after = Progression.levelOf(p.xp)
	local reached, paid = {}, 0
	for l = before + 1, after do
		table.insert(reached, l)
		paid += Progression.levelReward(l)
	end
	p.shards += paid
	return reached, paid
end

function Progression.bump(p: Profile, stat: string, by: number?)
	p.stats[stat] = (p.stats[stat] or 0) + (by or 1)
end

-- The roster ---------------------------------------------------------------

function Progression.priceOf(styleId: string): number
	return if Progression.PREMIUM[styleId] then Progression.PREMIUM_PRICE else Progression.PRICE
end

--- The character a boss unlocks, from its enemy id ("boss_gojo" -> "gojo").
function Progression.bossStyle(enemyId: string): string?
	return string.match(enemyId, "^boss_(.+)$")
end

--- Buys a character. Returns whether it worked and, if not, why.
function Progression.buy(p: Profile, styleId: string, exists: boolean): (boolean, string?)
	if not exists then
		return false, "No such character."
	end
	if p.unlocked[styleId] then
		return false, "Already on your roster."
	end
	local price = Progression.priceOf(styleId)
	if p.shards < price then
		return false, `Not enough Rift Shards: {price} needed, {p.shards} held.`
	end
	p.shards -= price
	p.unlocked[styleId] = true
	return true, nil
end

-- Loadouts -----------------------------------------------------------------

--- Checks and saves a loadout for a style: 1 to `maxSlots` techniques, no
--- repeats, each from that style's own pool or absorbed from an enemy. A
--- loadout equal to the default is stored as no loadout.
function Progression.setLoadout(
	p: Profile,
	style: { pool: { string }, slots: { string } },
	styleId: string,
	slots: { any },
	maxSlots: number,
	skillExists: (string) -> boolean
): (boolean, string?)
	if type(slots) ~= "table" or #slots < 1 or #slots > maxSlots then
		return false, `Pick between 1 and {maxSlots} techniques.`
	end
	local seen, clean = {}, {}
	for _, id in slots do
		if type(id) ~= "string" or not skillExists(id) then
			return false, "Unknown technique."
		end
		if seen[id] then
			return false, "A technique can only be in one slot."
		end
		if not table.find(style.pool, id) and not p.learned[id] then
			return false, "You have not absorbed that technique yet."
		end
		seen[id] = true
		table.insert(clean, id)
	end
	local same = #clean == #style.slots
	for i, id in clean do
		same = same and style.slots[i] == id
	end
	-- A loadout equal to the default is stored as none, so a later change to
	-- the style's defaults reaches this player too.
	(p.loadouts :: { [string]: { string }? })[styleId] = if same then nil else clean
	return true, nil
end

--- The slots a style starts with for this player: their saved loadout if it
--- still checks out, otherwise the style's own.
function Progression.slotsFor(p: Profile?, style: { pool: { string }, slots: { string } }, styleId: string): { string }
	local saved: { string }? = if p then p.loadouts[styleId] else nil
	if p and saved then
		for _, id in saved do
			if not table.find(style.pool, id) and not p.learned[id] then
				return table.clone(style.slots)
			end
		end
		return table.clone(saved)
	end
	return table.clone(style.slots)
end

-- The daily reward ---------------------------------------------------------

--- Whole days since 1970, UTC. The day turns over at midnight UTC for everyone.
function Progression.dayOf(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

--- The streak a claim today would be on: one more than yesterday's, or back
--- to one after a missed day.
function Progression.nextStreak(p: Profile, today: number): number
	if p.daily.day == today - 1 then
		return p.daily.streak + 1
	end
	return 1
end

function Progression.canClaimDaily(p: Profile, today: number): boolean
	return p.daily.day ~= today
end

--- Claims today's reward. Returns the reward and the streak day it was for,
--- or nil if today's is already claimed. Experience is not added here: the
--- caller adds it with addXp so level-ups are reported.
function Progression.claimDaily(p: Profile, today: number): ({ shards: number, xp: number }?, number)
	if not Progression.canClaimDaily(p, today) then
		return nil, p.daily.streak
	end
	local streak = Progression.nextStreak(p, today)
	p.daily = { day = today, streak = streak }
	local reward = Progression.DAILY[((streak - 1) % #Progression.DAILY) + 1]
	p.shards += reward.shards
	return reward, streak
end

-- Daily quests -------------------------------------------------------------

-- A small, fixed LCG so a day's quests are the same on every server.
local function lcg(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

--- The quests for `day`, the same for a player wherever they join from.
function Progression.rollQuests(day: number, seed: number): { Quest }
	local rand = lcg(day * 7919 + seed)
	local pool = table.clone(Progression.QUESTS)
	local out: { Quest } = {}
	for _ = 1, math.min(Progression.QUESTS_PER_DAY, #pool) do
		local i = math.floor(rand() * #pool) + 1
		local q = table.remove(pool, i) :: any
		local goal = q.goals[math.floor(rand() * #q.goals) + 1]
		table.insert(out, {
			id = q.id,
			kind = q.kind,
			best = q.best,
			text = string.format(q.text, goal),
			goal = goal,
			progress = 0,
			claimed = false,
			shards = q.shards,
			xp = q.xp,
		})
	end
	return out
end

--- Makes sure the profile holds today's quests. Returns whether they changed.
function Progression.refreshQuests(p: Profile, today: number, seed: number): boolean
	if p.quests.day == today then
		return false
	end
	p.quests = { day = today, list = Progression.rollQuests(today, seed), rerolled = false }
	return true
end

--- Advances every unclaimed quest of that kind. Returns the ones this event
--- finished, and whether any quest moved at all.
function Progression.questEvent(p: Profile, kind: string, amount: number?): ({ Quest }, boolean)
	local done, moved = {}, false
	for _, q in p.quests.list do
		if q.kind == kind and not q.claimed and q.progress < q.goal then
			local before = q.progress
			q.progress = if q.best
				then math.min(q.goal, math.max(q.progress, amount or 1))
				else math.min(q.goal, q.progress + (amount or 1))
			moved = moved or q.progress ~= before
			if q.progress >= q.goal then
				table.insert(done, q)
			end
		end
	end
	return done, moved
end

--- Claims a finished quest. Adds its shards; the caller adds its experience.
function Progression.claimQuest(p: Profile, index: number): (Quest?, string?)
	local q = p.quests.list[index]
	if not q then
		return nil, "No such quest."
	end
	if q.claimed then
		return nil, "Already claimed."
	end
	if q.progress < q.goal then
		return nil, "Not finished yet."
	end
	q.claimed = true
	p.shards += q.shards
	return q, nil
end

--- Swaps one unfinished quest for a different one, once a day, for shards.
function Progression.rerollQuest(p: Profile, index: number, seed: number): (boolean, string?)
	local q = p.quests.list[index]
	if not q then
		return false, "No such quest."
	end
	if q.claimed or q.progress >= q.goal then
		return false, "That one is already done."
	end
	if p.quests.rerolled then
		return false, "One swap a day."
	end
	if p.shards < Progression.QUEST_REROLL_COST then
		return false, `Swapping costs {Progression.QUEST_REROLL_COST} Rift Shards.`
	end
	local taken = {}
	for _, o in p.quests.list do
		taken[o.id] = true
	end
	-- Try the day's other quests in seeded order until one is not already held.
	local rand = lcg(p.quests.day * 104729 + seed + index)
	local pool = {}
	for _, t in Progression.QUESTS do
		if not taken[t.id] then
			table.insert(pool, t)
		end
	end
	if #pool == 0 then
		return false, "Nothing to swap it for."
	end
	local t = pool[math.floor(rand() * #pool) + 1] :: any
	local goal = t.goals[math.floor(rand() * #t.goals) + 1]
	p.quests.list[index] = {
		id = t.id,
		kind = t.kind,
		best = t.best,
		text = string.format(t.text, goal),
		goal = goal,
		progress = 0,
		claimed = false,
		shards = t.shards,
		xp = t.xp,
	}
	p.shards -= Progression.QUEST_REROLL_COST
	p.quests.rerolled = true
	return true, nil
end

-- Upgrades ----------------------------------------------------------------

export type Upgrade = {
	key: string,
	name: string,
	text: string, -- what one level does
	per: number, -- added to the multiplier per level
	max: number,
	cost: number, -- the first level
	growth: number, -- each level costs this much more than the last
}

-- Permanent, for every character: where shards go once the roster is full.
Progression.UPGRADES = {
	{ key = "vitality", name = "Vitality", text = "+6% health", per = 0.06, max = 10, cost = 120, growth = 1.45 },
	{ key = "power", name = "Power", text = "+5% damage", per = 0.05, max = 10, cost = 150, growth = 1.45 },
	{
		key = "spirit",
		name = "Spirit",
		text = "+8% Spirit Energy and its regeneration",
		per = 0.08,
		max = 10,
		cost = 120,
		growth = 1.45,
	},
	{ key = "swiftness", name = "Swiftness", text = "+3% run speed", per = 0.03, max = 8, cost = 100, growth = 1.5 },
	{
		key = "fortune",
		name = "Fortune",
		text = "+10% Rift Shards from fighting",
		per = 0.1,
		max = 5,
		cost = 250,
		growth = 1.6,
	},
} :: { Upgrade }

local function upgradeDef(key: string): Upgrade?
	for _, u in Progression.UPGRADES do
		if u.key == key then
			return u
		end
	end
	return nil
end

--- What the next level of an upgrade costs from `level`.
function Progression.upgradeCost(u: Upgrade, level: number): number
	return math.floor(u.cost * u.growth ^ level + 0.5)
end

--- The multiplier an upgrade gives at the player's level: 1 with none, or
--- with no profile.
function Progression.upgradeMul(p: Profile?, key: string): number
	local u = upgradeDef(key)
	if not p or not u then
		return 1
	end
	return 1 + u.per * math.clamp(p.upgrades[key] or 0, 0, u.max)
end

--- Buys the next level of an upgrade.
function Progression.buyUpgrade(p: Profile, key: string): (boolean, string?)
	local u = upgradeDef(key)
	if not u then
		return false, "No such upgrade."
	end
	local level = p.upgrades[key] or 0
	if level >= u.max then
		return false, `{u.name} is maxed.`
	end
	local cost = Progression.upgradeCost(u, level)
	if p.shards < cost then
		return false, `Not enough Rift Shards: {cost} needed, {p.shards} held.`
	end
	p.shards -= cost
	p.upgrades[key] = level + 1
	return true, nil
end

-- Combos ------------------------------------------------------------------

Progression.COMBO_WINDOW = 3 -- seconds between hits before a combo drops

local RANKS: { { at: number, rank: string } } = {
	{ at = 120, rank = "SSS" },
	{ at = 80, rank = "SS" },
	{ at = 50, rank = "S" },
	{ at = 35, rank = "A" },
	{ at = 20, rank = "B" },
	{ at = 10, rank = "C" },
}

--- The letter a combo of `hits` has earned.
function Progression.comboRank(hits: number): string
	for _, r in RANKS do
		if hits >= r.at then
			return r.rank
		end
	end
	return "D"
end

--- What a finished combo is worth: two experience a hit, and a shard for
--- every fifteen hits, doubled from S rank up.
function Progression.comboReward(hits: number): (number, number)
	local shards = math.floor(hits / 15)
	if hits >= 50 then
		shards *= 2
	end
	return hits * 2, shards
end

-- Worlds -------------------------------------------------------------------

--- Records the wave a world reached. Returns whether it beat the old best.
function Progression.recordWave(p: Profile, mapId: string, wave: number): boolean
	if wave > (p.best[mapId] or 0) then
		p.best[mapId] = wave
		return true
	end
	return false
end

--- The world after `mapId` in the rift's order, wrapping round.
function Progression.nextWorld(order: { string }, mapId: string): string
	local i = table.find(order, mapId) or 0
	return order[(i % #order) + 1]
end

--- The best wave across every world: what the global board ranks.
function Progression.bestWave(p: Profile): number
	local best = 0
	for _, w in p.best do
		best = math.max(best, w)
	end
	return best
end

return Progression
