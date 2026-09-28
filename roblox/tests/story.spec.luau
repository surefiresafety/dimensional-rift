--!strict
-- Story mode: every world has its chapter, the Seam's waves and bosses exist,
-- the finale's phases, the Unbidden's adaptation, the stitched elites, and
-- where a returning player carries on from.

local H = require("./harness")
local Story = require("../src/shared/Story")
local Finale = require("../src/shared/Finale")
local Rules = require("../src/shared/Rules")
local Progression = require("../src/shared/Progression")
local RulesData = require("../src/shared/Data/Rules")
local Maps = require("../src/shared/Data/Maps")
local Enemies = require("../src/shared/Data/Enemies")

print("Story")

-- The rift's order as the game builds it (Worlds.ORDER).
local ORDER = table.clone(RulesData.MAP_IDS)
table.insert(ORDER, Story.FINAL)

local function mapOf(id: string): any
	return if id == Story.FINAL then Finale.MAP else (Maps :: any)[id]
end

H.test("every world has a chapter, and its lines fall on real waves", function()
	for _, id in ORDER do
		local ch = (Story.CHAPTERS :: any)[id]
		assert(ch, id .. " has no chapter")
		assert(#ch.intro > 20, id .. " has no intro")
		assert(ch.cleared and #ch.cleared.text > 0, id .. " has no closing line")
		local waves = #mapOf(id).waves
		for n in ch.lines do
			assert(n >= 1 and n < waves, `{id}: a line after wave {n} of {waves} never shows`)
		end
	end
	for _, key in { "naruto", "jjk", "marvel", "other" } do
		assert(Story.EPILOGUE[key], "no epilogue for " .. key)
	end
end)

H.test("the Seam's waves, filler and bosses all exist", function()
	for _, wave in Finale.MAP.waves do
		for _, id in wave do
			assert((Enemies :: any)[id] or (Finale.ENEMIES :: any)[id], "the Seam spawns unknown " .. id)
		end
	end
	for _, id in Finale.MAP.filler do
		assert((Enemies :: any)[id], "unknown filler " .. id)
	end
	local last = Finale.MAP.waves[#Finale.MAP.waves]
	H.eq(last[1], "hyakunui", "Hyakunui is the last wave")
	H.eq(Finale.ENEMIES.hyakunui.finale, true, "and runs the finale")
	H.eq(Finale.ENEMIES.the_unbidden.adapts, true, "the Unbidden adapts")
	for id, t in Finale.ENEMIES :: any do
		assert(t.hp > 0 and t.atk > 0 and t.speed > 0 and RulesData.NATURE[t.nature], id .. " is incomplete")
	end
end)

H.test("the finale's phases", function()
	H.eq(Finale.phaseOf(1), 1, "full")
	H.eq(Finale.phaseOf(0.67), 1, "just above two thirds")
	H.eq(Finale.phaseOf(0.66), 2, "two thirds")
	H.eq(Finale.phaseOf(0.34), 2, "just above a third")
	H.eq(Finale.phaseOf(0.33), 3, "a third")
	H.eq(Finale.phaseOf(0), 3, "the end")
	H.eq(#Story.PHASES, 3, "a banner for each")
end)

H.test("the Unbidden learns a nature after three hits", function()
	local counts = {}
	for i = 1, 3 do
		local mul, adapted = Rules.adapt(counts, "fire")
		H.eq(mul, 1, "hit " .. i)
		H.eq(adapted, false, "not yet")
	end
	local mul, adapted = Rules.adapt(counts, "fire")
	H.eq(mul, 0.2, "the fourth fire hit")
	H.eq(adapted, true, "adapted")
	H.eq((Rules.adapt(counts, "water")), 1, "water is still new")
end)

H.test("in the Seam everything but the bosses is stitched from the first wave", function()
	H.eq(Rules.rollAffix(1, false, 0.99, 0, 1) ~= nil, true, "wave 1, any roll")
	H.eq(Rules.rollAffix(1, true, 0, 0, 1), nil, "never a boss")
	H.eq(Rules.rollAffix(1, false, 0, 0, 0.15), nil, "Loose Threads alone does not start at wave 1")
	H.eq(Rules.rollAffix(3, false, 0.2, 0, 0.15) ~= nil, true, "but raises the chance")
end)

H.test("the Seam opens after the ninth world, and a returning player carries on", function()
	local p = Progression.newProfile()
	H.eq(Progression.frontier(p, ORDER), ORDER[1], "a new player starts at the start")
	for i = 1, 4 do
		p.cleared[ORDER[i]] = true
	end
	H.eq(Progression.frontier(p, ORDER), ORDER[5], "carries on at the fifth")
	H.eq(Progression.worldUnlocked(p, ORDER, Story.FINAL), false, "the Seam is shut")
	for i = 1, 9 do
		p.cleared[ORDER[i]] = true
	end
	H.eq(Progression.worldUnlocked(p, ORDER, Story.FINAL), true, "open after all nine")
	H.eq(Progression.frontier(p, ORDER), Story.FINAL, "and that is where they carry on")
	p.cleared[Story.FINAL] = true
	H.eq(Progression.frontier(p, ORDER), ORDER[1], "all done: round again")
	H.eq(Progression.nextWorld(ORDER, Story.FINAL), ORDER[1], "after the Seam, the start")
	local old = Progression.reconcile({ xp = 10 })
	H.eq(old.closed, 0, "old saves have never closed the rift")
end)

H.test("the story calls the worlds by their Roblox names", function()
	local OLD = {
		"Times Square",
		"Star Vault",
		"Kyoto",
		"Survival Colony",
		"Land of",
		"Mist Village",
		"Storm Village",
		"Desert Village",
		"Stone Village",
	}
	local function scan(t: any)
		for _, v in t do
			if type(v) == "string" then
				for _, old in OLD do
					assert(not string.find(v, old, 1, true), `"{old}" in: {v}`)
				end
			elseif type(v) == "table" then
				scan(v)
			end
		end
	end
	scan(Story)
end)

return H
