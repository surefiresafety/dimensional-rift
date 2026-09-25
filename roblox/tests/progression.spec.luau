--!strict
-- The progression rules: levels, rewards, the roster, loadouts, the daily
-- streak and quests. All of it is plain data, so it runs under Lune.

local H = require("./harness")
local Progression = require("../src/shared/Progression")
local Styles = require("../src/shared/Data/Styles")
local Skills = require("../src/shared/Data/Skills")
local Enemies = require("../src/shared/Data/Enemies")
local RulesData = require("../src/shared/Data/Rules")

print("Progression")

H.test("a new profile has the starters and nothing else", function()
	local p = Progression.newProfile()
	for _, id in Progression.STARTERS do
		H.eq(p.unlocked[id], true, id)
		assert(Styles[id], "starter " .. id .. " is not a character")
	end
	H.eq(p.shards, 0, "no shards")
	H.eq(p.xp, 0, "no experience")
	H.eq((Progression.levelOf(0)), 1, "level 1")
end)

H.test("every premium character exists", function()
	for id in Progression.PREMIUM do
		assert(Styles[id], "premium " .. id .. " is not a character")
	end
end)

H.test("reconcile repairs and upgrades a save", function()
	local p = Progression.reconcile(nil)
	H.eq(p.version, Progression.VERSION, "nil becomes a new profile")
	local old = Progression.reconcile({ xp = 250.7, shards = "lots", unlocked = { gojo = true }, daily = 5 })
	H.eq(old.xp, 250, "whole experience")
	H.eq(old.shards, 0, "a wrong type falls back")
	H.eq(old.unlocked.gojo, true, "what was unlocked stays unlocked")
	H.eq(old.unlocked.naruto, true, "starters are always there")
	H.eq(old.daily.day, -1, "a broken daily resets")
	H.eq(type(old.quests.list), "table", "missing quests are filled in")
	H.eq(old.lastStyle, nil, "no last style")
	local kept = Progression.reconcile({ lastStyle = "gojo", quests = { day = 3, list = {}, rerolled = true } })
	H.eq(kept.lastStyle, "gojo", "last style kept")
	H.eq(kept.quests.rerolled, true, "reroll flag kept")
end)

H.test("levels: the curve, and levelOf inverts it", function()
	H.eq(Progression.xpToNext(1), 100, "level 1 takes 100")
	local total = 0
	for level = 1, 30 do
		local l, into, need = Progression.levelOf(total)
		H.eq(l, level, "exactly at the start of level " .. level)
		H.eq(into, 0, "nothing into it")
		H.eq(need, Progression.xpToNext(level), "need")
		local l2 = Progression.levelOf(total + Progression.xpToNext(level) - 1)
		H.eq(l2, level, "one short of level " .. (level + 1))
		total += Progression.xpToNext(level)
	end
	local cap = Progression.levelOf(1e12)
	H.eq(cap, Progression.MAX_LEVEL, "capped")
end)

H.test("addXp reports every level passed and pays for each", function()
	local p = Progression.newProfile()
	local reached, paid = Progression.addXp(p, Progression.xpToNext(1) + Progression.xpToNext(2))
	H.eq(table.concat(reached, ","), "2,3", "two levels at once")
	H.eq(paid, Progression.levelReward(2) + Progression.levelReward(3), "paid")
	H.eq(p.shards, paid, "added")
	local none = Progression.addXp(p, 1)
	H.eq(#none, 0, "no level")
	Progression.addXp(p, -50)
	H.eq(p.xp, Progression.xpToNext(1) + Progression.xpToNext(2) + 1, "negative experience is ignored")
end)

H.test("rewards: kills, waves, worlds, friends", function()
	local xp, shards = Progression.killReward("grade4", Enemies.grade4)
	H.eq(xp, math.floor(Enemies.grade4.hp / 20 + 0.5), "a grade 4")
	H.eq(shards, 1, "one shard")
	xp, shards = Progression.killReward("boss_gojo", Enemies.boss_gojo)
	H.eq(xp, 150, "a boss")
	H.eq(shards, 25, "boss shards")
	xp, shards = Progression.killReward("grade4_alpha", Enemies.grade4_alpha)
	H.eq(xp, 60, "an alpha, though the data calls it a boss")
	H.eq(shards, 8, "alpha shards")
	xp, shards = Progression.killReward("jogo", Enemies.jogo)
	H.eq(xp, 100, "a story boss")
	H.eq(shards, 15, "story boss shards")
	xp, shards = Progression.waveReward(10)
	H.eq(xp, 70, "wave 10 experience")
	H.eq(shards, 8, "wave 10 shards")
	local firstXp = Progression.worldReward(true)
	local againXp = Progression.worldReward(false)
	assert(firstXp > againXp, "the first clear is worth more")
	H.eq(Progression.friendMul(0), 1, "alone")
	H.near(Progression.friendMul(2), 1.2, 1e-9, "two friends")
	H.near(Progression.friendMul(9), 1.3, 1e-9, "capped at three")
end)

H.test("every boss unlocks a real character", function()
	for _, id in RulesData.BOSS_IDS do
		local style = Progression.bossStyle(id)
		assert(style and Styles[style], id .. " unlocks nobody")
	end
	H.eq(Progression.bossStyle("grade4"), nil, "not a boss")
end)

H.test("buying a character", function()
	local p = Progression.newProfile()
	local ok, why = Progression.buy(p, "toji", true)
	H.eq(ok, false, "too poor")
	assert(why and string.find(why, "350"), "says the price")
	p.shards = 1000
	ok = Progression.buy(p, "toji", true)
	H.eq(ok, true, "bought")
	H.eq(p.shards, 650, "paid 350")
	H.eq(p.unlocked.toji, true, "unlocked")
	H.eq((Progression.buy(p, "toji", true)), false, "not twice")
	H.eq((Progression.buy(p, "gojo", true)), false, "premium costs more than 650")
	H.eq((Progression.buy(p, "nobody", false)), false, "not a character")
end)

H.test("loadouts: own pool or absorbed, no repeats, 1 to 5", function()
	local p = Progression.newProfile()
	local st = Styles.naruto
	local exists = function(id: string)
		return Skills[id] ~= nil
	end
	local ok = Progression.setLoadout(p, st, "naruto", { st.pool[1] }, 5, exists)
	H.eq(ok, true, "one of his own")
	H.eq(#Progression.slotsFor(p, st, "naruto"), 1, "saved")
	H.eq((Progression.setLoadout(p, st, "naruto", {}, 5, exists)), false, "none")
	H.eq((Progression.setLoadout(p, st, "naruto", { st.pool[1], st.pool[1] }, 5, exists)), false, "repeat")
	H.eq((Progression.setLoadout(p, st, "naruto", { "no_such" }, 5, exists)), false, "unknown")
	H.eq((Progression.setLoadout(p, st, "naruto", { "infinity" }, 5, exists)), false, "not absorbed")
	p.learned.infinity = true
	H.eq((Progression.setLoadout(p, st, "naruto", { "infinity" }, 5, exists)), true, "absorbed")
	H.eq((Progression.setLoadout(p, st, "naruto", { 12 :: any }, 5, exists)), false, "not a string")
	-- Saving the default clears it.
	H.eq((Progression.setLoadout(p, st, "naruto", table.clone(st.slots), 5, exists)), true, "default")
	H.eq(p.loadouts.naruto, nil, "stored as none")
	-- A saved loadout that no longer checks out falls back to the default.
	p.loadouts.naruto = { "some_forgotten_move" }
	H.eq(table.concat(Progression.slotsFor(p, st, "naruto"), ","), table.concat(st.slots, ","), "fallback")
	H.eq(table.concat(Progression.slotsFor(nil, st, "naruto"), ","), table.concat(st.slots, ","), "no profile")
end)

H.test("the daily streak grows, wraps at seven, and breaks", function()
	local p = Progression.newProfile()
	local day = 20000
	local reward, streak = Progression.claimDaily(p, day)
	H.eq(streak, 1, "first day")
	H.eq((reward :: any).shards, Progression.DAILY[1].shards, "day 1 reward")
	H.eq((Progression.claimDaily(p, day)), nil, "not twice a day")
	for d = 2, 7 do
		reward, streak = Progression.claimDaily(p, day + d - 1)
		H.eq(streak, d, "day " .. d)
	end
	H.eq((reward :: any).shards, Progression.DAILY[7].shards, "day 7 is the big one")
	reward, streak = Progression.claimDaily(p, day + 7)
	H.eq(streak, 8, "the streak keeps counting")
	H.eq((reward :: any).shards, Progression.DAILY[1].shards, "and the rewards wrap")
	reward, streak = Progression.claimDaily(p, day + 9)
	H.eq(streak, 1, "a missed day starts again")
	H.eq(Progression.dayOf(86400 * 3 + 5), 3, "day number")
end)

H.test("quests: the same three for a player all day, and they count", function()
	local a = Progression.rollQuests(100, 42)
	local b = Progression.rollQuests(100, 42)
	H.eq(#a, Progression.QUESTS_PER_DAY, "three")
	for i = 1, #a do
		H.eq(a[i].id, b[i].id, "same quest")
		H.eq(a[i].goal, b[i].goal, "same goal")
	end
	local ids = {}
	for _, q in a do
		assert(not ids[q.id], "a quest twice in one day")
		ids[q.id] = true
	end
	-- Another day or another player: different at least somewhere in a week.
	local differs = false
	for d = 101, 107 do
		local c = Progression.rollQuests(d, 42)
		for i = 1, #a do
			differs = differs or c[i].id ~= a[i].id
		end
	end
	H.eq(differs, true, "quests change from day to day")

	local p = Progression.newProfile()
	H.eq(Progression.refreshQuests(p, 100, 42), true, "rolled")
	H.eq(Progression.refreshQuests(p, 100, 42), false, "not again the same day")
	local q = p.quests.list[1]
	local done = Progression.questEvent(p, q.kind, q.goal - 1)
	H.eq(#done, 0, "not yet")
	H.eq((Progression.claimQuest(p, 1)), nil, "cannot claim early")
	done = Progression.questEvent(p, q.kind, 5)
	H.eq(#done, 1, "finished")
	H.eq(q.progress, q.goal, "capped at the goal")
	H.eq(#Progression.questEvent(p, q.kind, 1), 0, "finished only once")
	local claimed = Progression.claimQuest(p, 1)
	H.eq(claimed ~= nil, true, "claimed")
	H.eq(p.shards, q.shards, "paid")
	H.eq((Progression.claimQuest(p, 1)), nil, "not twice")
	H.eq((Progression.claimQuest(p, 99)), nil, "no such quest")
end)

H.test("a quest can be swapped once a day, for shards", function()
	local p = Progression.newProfile()
	Progression.refreshQuests(p, 300, 7)
	local ok, why = Progression.rerollQuest(p, 2, 7)
	H.eq(ok, false, "costs shards")
	assert(why, "says why")
	p.shards = 100
	local before = p.quests.list[2].id
	ok = Progression.rerollQuest(p, 2, 7)
	H.eq(ok, true, "swapped")
	assert(p.quests.list[2].id ~= before, "a different quest")
	local ids = {}
	for _, q in p.quests.list do
		assert(not ids[q.id], "the swap duplicated a quest")
		ids[q.id] = true
	end
	H.eq(p.shards, 100 - Progression.QUEST_REROLL_COST, "paid")
	H.eq((Progression.rerollQuest(p, 1, 7)), false, "once a day")
	Progression.refreshQuests(p, 301, 7)
	H.eq(p.quests.rerolled, false, "a new day, a new swap")
end)

H.test("every quest kind is one the server sends", function()
	-- Kept in step with Combat.emit and Progress.luau.
	local SENT = {
		kill = true,
		elite = true,
		wave = true,
		cast = true,
		crit = true,
		damage = true,
		strike = true,
		output = true,
	}
	for _, q in Progression.QUESTS do
		assert(SENT[q.kind], q.id .. " waits for an event nothing sends: " .. q.kind)
		assert(string.find(q.text, "%d", 1, true), q.id .. " has no goal in its text")
	end
end)

H.test("worlds: best waves and the order they come in", function()
	local p = Progression.newProfile()
	H.eq(Progression.recordWave(p, "times_square", 4), true, "a first best")
	H.eq(Progression.recordWave(p, "times_square", 3), false, "not better")
	H.eq(Progression.recordWave(p, "jujutsu_high", 9), true, "another world")
	H.eq(Progression.bestWave(p), 9, "best anywhere")
	local order = RulesData.MAP_IDS
	H.eq(Progression.nextWorld(order, order[1]), order[2], "next")
	H.eq(Progression.nextWorld(order, order[#order]), order[1], "wraps")
end)

return H
