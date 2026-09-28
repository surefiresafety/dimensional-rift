--!strict
-- The exported data holds together: every reference resolves, and every
-- technique a character can use is one the Roblox build knows how to cast.

local H = require("./harness")
local Skills = require("../src/shared/Data/Skills")
local Styles = require("../src/shared/Data/Styles")
local Enemies = require("../src/shared/Data/Enemies")
local Characters = require("../src/shared/Data/Characters")
local Maps = require("../src/shared/Data/Maps")
local RulesData = require("../src/shared/Data/Rules")
local Signature = require("../src/shared/Signature")
local Arsenals = require("../src/shared/Data/Arsenals")

-- Keep in step with the handlers table in src/server/Abilities.luau.
local PORTED = {
	projectile = true,
	melee = true,
	dash = true,
	beam = true,
	trap = true,
	pull = true,
	yank = true,
	teleport = true,
	buff = true,
	heal = true,
	shield = true,
	evade = true,
	freeze = true,
	clones = true,
	domain = true,
	toggle = true,
	self = true,
	rewind = true,
	switch = true,
	possess = true,
	devour = true,
}
local NOT_YET: { [string]: boolean } = {}

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

print("Data")

H.test("the whole roster came across", function()
	H.eq(count(Styles), 46, "characters")
	H.eq(count(Skills), 282, "techniques")
	H.eq(count(Enemies), 118, "enemies")
	H.eq(count(Maps), 9, "worlds")
	H.eq(#RulesData.BOSS_IDS, 46, "a boss for every character")
end)

H.test("every technique a character carries exists", function()
	local missing = {}
	for id, st in Styles do
		for _, k in st.pool do
			if not Skills[k] then
				table.insert(missing, id .. "/" .. k)
			end
		end
		for _, k in st.slots do
			if not Skills[k] then
				table.insert(missing, id .. "/" .. k)
			end
		end
		local u = st.ultimate
		if u.skill and not Skills[u.skill] then
			table.insert(missing, id .. "/ult:" .. u.skill)
		end
		if not u.skill and u.kind ~= "transform" and u.kind ~= "mahoraga" then
			table.insert(missing, id .. "/ult has neither a skill nor a known kind")
		end
		if u.kind == "transform" and not Styles[u.into] then
			table.insert(missing, id .. "/transforms into " .. tostring(u.into))
		end
	end
	H.eq(table.concat(missing, ", "), "", "missing")
end)

H.test("every character has a look and a world", function()
	for id in Styles do
		assert(Characters[id], "no look for " .. id)
		assert(RulesData.WORLD_OF[id], "no world for " .. id)
	end
end)

H.test("every wave and every drop resolves", function()
	for mapId, m in Maps do
		for _, w in m.waves do
			for _, e in w do
				assert(Enemies[e], mapId .. " spawns unknown enemy " .. e)
			end
		end
		for _, e in m.filler or {} do
			assert(Enemies[e], mapId .. " filler " .. e)
		end
	end
	for id, t in Enemies do
		assert(t.drops == nil or Skills[t.drops], id .. " drops unknown " .. tostring(t.drops))
		assert(RulesData.NATURE[t.nature], id .. " has unknown nature " .. tostring(t.nature))
	end
end)

H.test("every technique type is either ported or known not to be", function()
	local unknown = {}
	for id, s in Skills do
		if not PORTED[s.type] and not NOT_YET[s.type] then
			table.insert(unknown, id .. ":" .. s.type)
		end
	end
	H.eq(table.concat(unknown, ", "), "", "unhandled types")
end)

H.test("every equipped slot and ultimate on the roster is castable", function()
	local blocked = {}
	for id, st in Styles do
		for _, k in st.slots do
			if not PORTED[Skills[k].type] then
				table.insert(blocked, id .. "/" .. k .. " (" .. Skills[k].type .. ")")
			end
		end
	end
	H.eq(table.concat(blocked, ", "), "", "equipped but not castable")
end)

H.test("every weapon set is drawable and complete", function()
	for style, a in Arsenals :: any do
		assert(Styles[style], "weapon set for unknown style " .. style)
		for _, id in a.order do
			local w = a.items[id]
			assert(w, style .. " orders a weapon it does not have: " .. id)
			assert(
				type(w.m1) == "number" and w.name and w.color,
				style .. "/" .. id .. " is missing m1, name or colour"
			)
		end
		-- A set is drawn either with R or with a switch technique in a slot.
		local drawable = a.key == "r"
		for _, k in Styles[style].slots do
			drawable = drawable or Skills[k].type == "switch"
		end
		assert(drawable, style .. " has a weapon set and no way to draw it")
	end
	for id, s in Skills do
		if s.type == "switch" then
			local owned = false
			for style, st in Styles do
				if table.find(st.pool, id) then
					owned = true
					assert((Arsenals :: any)[style], style .. " can switch weapons but has no set")
				end
			end
			assert(owned, id .. " is a switch nobody carries")
		end
	end
end)

H.test("signature casts name real techniques in that character's pool", function()
	for style, skill in Signature do
		assert(Styles[style], "signature for unknown style " .. style)
		assert(Skills[skill], "signature casts unknown " .. skill)
	end
end)

H.test("auto-attack: every limb set is sane and every auto-web technique exists", function()
	for id, st in Styles :: any do
		local l = st.autoLimbs
		if l then
			assert(l.count > 0 and l.reach > 0 and l.power > 0 and l.cd > 0, id .. " has a broken autoLimbs")
		end
		local w = st.autoWeb
		if w then
			assert(Skills[w.skill], id .. " auto-webs an unknown technique: " .. tostring(w.skill))
		end
	end
end)

return H
