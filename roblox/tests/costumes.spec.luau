--!strict
-- Costumes against the pure checks of docs/design/characters.md §6.6: 1
-- (coverage), 4 (banned content), 5a–5g (colour, on effectiveLook, for every
-- style present in both the player and charBoss roles), 6, 7, 8, 9, 11, 13.
-- Styles come from src/shared/Costumes/Styles/*.luau; a missing file makes
-- the coverage and colour tests fail and name the styles it should hold.

local H = require("./harness")
local Costumes = require("../src/shared/Costumes")
local Styles = require("../src/shared/Data/Styles")
local Characters = require("../src/shared/Data/Characters")
local EnemyLooks = require("../src/shared/Data/EnemyLooks")
local Enemies = require("../src/shared/Data/Enemies")
local Arsenals = require("../src/shared/Data/Arsenals")
local RulesData = require("../src/shared/Data/Rules") :: any
local Rules = require("../src/shared/Rules")
local Finale = require("../src/shared/Finale") :: any

print("Costumes")

local C = Costumes :: any
local ROLES = { "player", "charBoss" }

local function sortedKeys(t: { [string]: any }): { string }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

local function hex(c: number): string
	return string.format("%06x", c)
end

--- Fails with every collected problem, one per line.
local function report(fails: { string }, what: string)
	if #fails > 0 then
		local shown = {}
		for i = 1, math.min(#fails, 40) do
			shown[i] = fails[i]
		end
		local more = if #fails > 40 then `\n       ... and {#fails - 40} more` else ""
		error(`{#fails} {what}:\n       ` .. table.concat(shown, "\n       ") .. more, 2)
	end
end

-- Which styles are present, and which are missing (by the file they belong in).
local styleIds = sortedKeys(Styles :: any)
local present: { string } = {}
local missingByFile: { [string]: { string } } = {}
for _, id in styleIds do
	if C.STYLE[id] then
		table.insert(present, id)
	else
		local file = C.UNIVERSE_FILE[RulesData.WORLD_OF[id]] or "?"
		missingByFile[file] = missingByFile[file] or {}
		table.insert(missingByFile[file], id)
	end
end

local function missingLines(): { string }
	local out = {}
	for _, file in sortedKeys(missingByFile) do
		local why = C.STYLE_ERRORS[file]
		table.insert(
			out,
			`Styles/{file}.luau: {table.concat(missingByFile[file], ", ")}{if why then " (" .. why .. ")" else ""}`
		)
	end
	return out
end

--- The colour tests check the styles present, then fail naming the rest.
local function checkMissing(fails: { string })
	for _, line in missingLines() do
		table.insert(fails, "not checked, no STYLE entry: " .. line)
	end
end

local function isSkyline(id: string): boolean
	return RulesData.WORLD_OF[id] == "marvel"
end

--- Walks a table, calling fn(key, value, path) on every field.
local function walk(t: any, fn: (any, any, string) -> (), path: string?, seen: { [any]: boolean }?)
	local s = seen or {}
	if type(t) ~= "table" or s[t] then
		return
	end
	s[t] = true
	for k, val in t do
		local p = (path or "") .. "." .. tostring(k)
		fn(k, val, p)
		walk(val, fn, p, s)
	end
end

local function deepEq(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, val in a do
		if not deepEq(val, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function skinExempt(u: any): boolean
	return u.skin and C.isSkinTone(u.base)
end

------------------------------------------------------------------------------
-- 1. Coverage
------------------------------------------------------------------------------

H.test("1: every Styles id has a STYLE entry", function()
	report(missingLines(), "Styles files missing styles")
	for file, why in C.STYLE_ERRORS do
		error(`Styles/{file}.luau: {why}`)
	end
end)

H.test("1: every STYLE has 9 colours, a preset and a height", function()
	local fails = {}
	local presets = { lean = true, standard = true, heavy = true, small = true, towering = true }
	for _, id in present do
		local s = C.STYLE[id]
		for _, k in { "skin", "hair", "brow", "eye", "top", "sleeves", "bottom", "trim", "sig" } do
			if type(s.colors) ~= "table" or type(s.colors[k]) ~= "number" then
				table.insert(fails, `{id}: colors.{k}`)
			end
		end
		if not presets[s.preset] then
			table.insert(fails, `{id}: preset {tostring(s.preset)}`)
		end
		if type(s.height) ~= "number" then
			table.insert(fails, `{id}: height`)
		end
		if type(s.kit) ~= "table" or (s.kit[1] and s.kit[1][1]) ~= "FP" then
			table.insert(fails, `{id}: kit must start with FP`)
		end
	end
	for id in C.STYLE do
		if not (Styles :: any)[id] then
			table.insert(fails, `{id}: STYLE entry for an unknown style`)
		end
	end
	report(fails, "STYLE entries incomplete")
end)

H.test("1: every kit code has a PARTS entry and a tint rule", function()
	local fails = {}
	for _, id in present do
		for i, e in C.STYLE[id].kit do
			local code = e[1]
			if C.PARTS[code] == nil then
				table.insert(fails, `{id} kit[{i}]: no PARTS["{tostring(code)}"]`)
			elseif code ~= "FP" and code ~= "Prop" and e.tint == nil and C.DEFAULT_TINT[code] == nil then
				table.insert(fails, `{id} kit[{i}]: {code} has no tint and no DEFAULT_TINT`)
			end
		end
	end
	report(fails, "unknown kit codes")
end)

H.test("1: every §3.1 code has a PARTS entry", function()
	local codes = {
		"HAT·b",
		"HAT·c",
		"HAT·n",
		"FTH",
		"CLP",
		"LF",
		"BLM",
		"ORB",
		"WSP",
		"SHD",
		"VL",
		"TIE",
		"WCH",
		"BLD",
		"HMR·s",
		"HMR·h",
		"FLT",
		"CN",
		"MZ",
		"STF",
		"TIP",
		"PLT",
		"SEAM",
		"TSL",
		"EDG",
		"CRY",
		"SPL",
		"SM",
		"WG",
		"HP",
		"BA",
		"GR·e",
		"UB·p",
		"UB·d",
		"UB·t",
		"HY·p",
		"HY·s",
		"HY·n",
	}
	local fails = {}
	for _, code in codes do
		if type(C.PARTS[code]) ~= "number" then
			table.insert(fails, code)
		end
	end
	report(fails, "§3.1 codes without PARTS")
	H.eq(C.PARTS["UB·t"], 8, "UB·t")
	H.eq(C.PARTS["SHD"], 4, "SHD")
end)

H.test("1: every character boss resolves to a style", function()
	local fails = {}
	for _, id in RulesData.BOSS_IDS do
		if not (Styles :: any)[C.styleFromEnemyId(id)] then
			table.insert(fails, id)
		end
	end
	for id, t in Enemies :: any do
		if C.role(id, t, nil) == "charBoss" and not (Styles :: any)[C.styleFromEnemyId(id)] then
			table.insert(fails, id .. " -> " .. C.styleFromEnemyId(id))
		end
	end
	report(fails, "character bosses without a style")
	H.eq(C.styleFromEnemyId("boss_might_guy"), "might_guy")
	H.eq(C.styleFromEnemyId("mahito_b"), "mahito")
	H.eq(C.styleFromEnemyId("hanami"), "hanami")
end)

H.test("1: every enemy id resolves through baseId", function()
	local fails = {}
	for id in Enemies :: any do
		local b = C.baseId(id)
		if not (Enemies :: any)[b] then
			table.insert(fails, id .. " -> " .. b)
		end
	end
	report(fails, "enemy ids without a base")
	H.eq(C.baseId("akatsuki_nin_alpha"), "akatsuki_nin")
	H.eq(C.baseId("boss_gojo"), "boss_gojo")
end)

H.test("1: ENEMY covers akatsuki_nin, gate_monk, ufo, the finale and every creature", function()
	local fails = {}
	for _, id in { "akatsuki_nin", "gate_monk", "ufo" } do
		if not C.ENEMY[id] then
			table.insert(fails, id)
		end
	end
	for id in Finale.ENEMIES do
		local e = C.ENEMY[id]
		if not (e and e.builder == id) then
			table.insert(fails, id .. " (builder)")
		end
	end
	for id, t in Enemies :: any do
		local role = C.role(id, t, nil)
		if t.shape ~= "human" and role ~= "finale" then
			local e = C.ENEMY[C.baseId(id)]
			if not e then
				table.insert(fails, id)
			elseif e.shape ~= t.shape then
				table.insert(fails, `{id}: shape {tostring(e.shape)}, data {t.shape}`)
			end
		end
	end
	report(fails, "enemies without an ENEMY entry")
end)

H.test("1: §4.3 creature part counts match their pieces", function()
	local fails = {}
	for id, e in C.ENEMY do
		if e.shape and e.shape ~= "human" then
			local n = C.variantParts(id)
			if n ~= e.parts then
				table.insert(fails, `{id}: pieces sum to {tostring(n)}, §4.3 says {tostring(e.parts)}`)
			end
			if (n or 0) > 14 then
				table.insert(fails, `{id}: {n} parts over the 14 budget`)
			end
		end
	end
	for shape, total in { toad = 14, blob = 11, wraith = 12, golem = 11, imp = 11, ufo = 8 } do
		local n = 0
		for _, piece in C.TIER.family[shape] do
			n += piece.parts
		end
		if n ~= total then
			table.insert(fails, `{shape}: family sums to {n}, §4.2 says {total}`)
		end
	end
	report(fails, "part counts off")
end)

------------------------------------------------------------------------------
-- 4. Banned content
------------------------------------------------------------------------------

local function humanIds(): { string }
	local out = {}
	for id, t in Enemies :: any do
		local role = C.role(id, t, nil)
		if t.shape == "human" and role ~= "charBoss" and role ~= "finale" then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

H.test("4: no human-enemy look keeps a BANNED flag", function()
	local fails = {}
	for _, id in humanIds() do
		local look = C.humanLook(id, EnemyLooks)
		for k in look do
			if C.BANNED[k] then
				table.insert(fails, `{id}: {k}`)
			end
		end
	end
	for id, e in C.ENEMY do
		walk(e, function(k, _, path)
			if type(k) == "string" and C.BANNED[k] then
				table.insert(fails, `ENEMY.{id}{path}`)
			end
		end)
	end
	-- the stripping itself
	local raw = EnemyLooks :: any
	local sawBanned = false
	for _, id in humanIds() do
		for k in raw[C.baseId(id)] or {} do
			sawBanned = sawBanned or C.BANNED[k] ~= nil
		end
	end
	report(fails, "banned flags kept")
	H.eq(C.dropBanned({ webs = true, top = 1 }).webs, nil, "dropBanned")
	local _ = sawBanned
end)

H.test("4: no STYLE carries data flags (banned flags, hairStyle)", function()
	local fails = {}
	for _, id in present do
		walk(C.STYLE[id], function(k, _, path)
			if type(k) == "string" and (C.BANNED[k] or k == "hairStyle" or k == "hairLen") then
				table.insert(fails, id .. path)
			end
		end)
	end
	checkMissing(fails)
	report(fails, "data flags in STYLE")
end)

H.test("4: only emblems E1–E11 are used", function()
	local fails = {}
	local function check(where: string, t: any)
		walk(t, function(k, val, path)
			if type(val) == "string" and string.match(val, "^E%d+$") then
				local n = tonumber(string.sub(val, 2)) :: number
				if n < 1 or n > 11 then
					table.insert(fails, `{where}{path} = {val}`)
				end
			elseif (k == "emblem" or k == "border") and type(val) == "string" and not string.match(val, "^E%d+$") then
				table.insert(fails, `{where}{path} = {val} (not an E-number)`)
			end
		end)
	end
	for _, id in present do
		check(id, C.STYLE[id])
	end
	for id, e in C.ENEMY do
		check("ENEMY." .. id, e)
	end
	check("FACTION", C.FACTION)
	report(fails, "unknown emblems")
end)

H.test("4: no Shinobi forehead plate, no scratched ninja mark", function()
	local fails = {}
	for _, id in present do
		if RulesData.WORLD_OF[id] == "naruto" then
			for i, e in C.STYLE[id].kit do
				if e[1] == "HB" or e[1] == "HB·t" then
					walk(e, function(k, val, path)
						-- a plate key (headbandPlate) that is set, or a variant naming a
						-- plate other than "no plate"
						local key = string.lower(tostring(k))
						local s = string.gsub(string.lower(tostring(val)), "no plate", "")
						if (string.find(key, "plate", 1, true) and val) or string.find(s, "plate", 1, true) then
							table.insert(fails, `{id} kit[{i}]{path}`)
						end
					end)
				end
			end
		end
	end
	for _, id in C.FACTION.ninja.members do
		for _, look in { C.humanLook(id, EnemyLooks), C.ENEMY[id] or {} } do
			walk(look, function(k, val, path)
				local s = string.lower(tostring(k) .. " " .. tostring(val))
				if string.find(s, "scratch", 1, true) or string.find(s, "plate", 1, true) then
					table.insert(fails, `{id}{path}`)
				end
			end)
		end
	end
	if C.FACTION.ninja.faction.code ~= "HB" or C.FACTION.ninja.faction.variant ~= "cloth" then
		table.insert(fails, "ninja faction piece must be a cloth HB")
	end
	report(fails, "plates or scratched marks")
end)

------------------------------------------------------------------------------
-- 5. Colour, on effectiveLook, both roles
------------------------------------------------------------------------------

-- Every present style's look, built once per role.
local looks: { [string]: { [string]: any } } = {}
local lookErrors: { string } = {}
for _, id in present do
	looks[id] = {}
	for _, role in ROLES do
		local ok, res = pcall(C.effectiveLook, id, role)
		if ok then
			looks[id][role] = res
		else
			table.insert(lookErrors, `{id} ({role}): {tostring(res)}`)
		end
	end
end

local function eachLook(fn: (string, string, any) -> ())
	for _, id in present do
		for _, role in ROLES do
			local l = looks[id][role]
			if l then
				fn(id, role, l)
			end
		end
	end
end

local function isRed(c: number, sat: number): boolean
	local h, s = C.hsv(c)
	return (h < 20 or h > 340) and s > sat
end

local function isBlue(c: number): boolean
	local h, s = C.hsv(c)
	return h >= 200 and h <= 250 and s > 0.4
end

H.test("5a: effectiveLook never reads data, and every style builds", function()
	local fails = table.clone(lookErrors)
	eachLook(function(id, role, l)
		if not deepEq(C.effectiveLook(id, role, {}), l) then
			table.insert(fails, `{id} ({role}): differs with Characters = \{\}`)
		end
		if not deepEq(C.effectiveLook(id, role, Characters), l) then
			table.insert(fails, `{id} ({role}): differs with Characters passed`)
		end
	end)
	checkMissing(fails)
	report(fails, "look problems")
end)

-- FP canvas 90×55: eyes centred (21,20) and (69,20), mouth (45,46).
local function cheekOf(m: any): string?
	local x, y = m.x, m.y
	if type(x) ~= "number" or type(y) ~= "number" or y < 24 then
		return nil
	end
	if x < 38 then
		return "right cheek"
	elseif x > 52 then
		return "left cheek"
	end
	return nil
end

H.test("5a: no parallel cheek lines, no mark under the nose, no face or neck seam", function()
	local fails = {}
	for _, id in present do
		local s = C.STYLE[id]
		local marks = (s.face and s.face.marks) or {}
		local byCheek: { [string]: { any } } = {}
		for i, m in marks do
			if type(m) == "table" then
				local cheek = cheekOf(m)
				if cheek then
					byCheek[cheek] = byCheek[cheek] or {}
					table.insert(byCheek[cheek], m)
				end
				if
					type(m.x) == "number"
					and type(m.y) == "number"
					and m.x >= 38
					and m.x <= 52
					and m.y >= 26
					and m.y <= 44
				then
					table.insert(fails, `{id}: mark {i} under the nose`)
				end
				local text = string.lower(tostring(m.kind or "") .. tostring(m.emblem or "") .. tostring(m.name or ""))
				if string.find(text, "stitch", 1, true) or string.find(text, "seam", 1, true) or text == "e11" then
					table.insert(fails, `{id}: stitch or seam mark {i} on the face`)
				end
				if type(m.count) == "number" and m.count >= 2 and cheek then
					table.insert(fails, `{id}: mark {i} repeats {m.count} times on the {cheek}`)
				end
			end
		end
		for cheek, list in byCheek do
			for a = 1, #list do
				for b = a + 1, #list do
					local ra, rb = tonumber(list[a].rot) or 0, tonumber(list[b].rot) or 0
					local d = math.abs(ra - rb) % 180
					if math.min(d, 180 - d) < 8 then
						table.insert(fails, `{id}: parallel Frames on the {cheek}`)
					end
				end
			end
		end
		-- seams and stitches on the face or neck: the head, CK, HC
		local function neckish(g: any, where: string)
			if type(g) ~= "table" then
				return
			end
			local text = string.lower(
				tostring(g.kind or "") .. " " .. tostring(g.emblem or "") .. " " .. tostring(g.border or "")
			)
			if
				string.find(text, "stitch", 1, true)
				or string.find(text, "seam", 1, true)
				or string.find(text, "e11", 1, true)
			then
				table.insert(fails, `{id}: {where} is a stitch or seam on the face or neck`)
			end
		end
		for i, e in s.kit do
			if e[1] == "CK" or e[1] == "HC" or e[1] == "FP" then
				neckish(e.gui, `kit[{i}] {e[1]} gui`)
				if e.emblem then
					neckish({ emblem = e.emblem }, `kit[{i}] {e[1]}`)
				end
			end
		end
		for i, g in s.guis or {} do
			local host = g.host or (type(g.parts) == "table" and g.parts[1]) or ""
			if host == "Head" or string.find(string.lower(tostring(g.at or g.face or "")), "neck", 1, true) then
				neckish(g, `guis[{i}] on {host}`)
			end
		end
	end
	checkMissing(fails)
	report(fails, "face marks")
end)

H.test("5b: no effective colour near a TRADE_DRESS source colour", function()
	local fails = {}
	eachLook(function(id, role, l)
		local guards = C.TRADE_DRESS[id]
		if not guards then
			return
		end
		for _, u in l.all do
			local _, _, val = C.hsv(u.color)
			if not skinExempt(u) and val >= 0.3 then
				for _, g in guards do
					if (not g.hairOnly or u.hair) and C.dist(u.color, g.color) <= 30 then
						table.insert(
							fails,
							`{id} ({role}) {u.where} {hex(u.color)} is {math.floor(C.dist(u.color, g.color))} from {hex(
								g.color
							)}`
						)
					end
				end
			end
		end
	end)
	checkMissing(fails)
	report(fails, "trade-dress colours")
end)

H.test("5c: no Skyline colour is red (hue < 20° or > 340°, saturation > 0.5)", function()
	local fails = {}
	eachLook(function(id, role, l)
		if isSkyline(id) then
			for _, u in l.all do
				if isRed(u.color, 0.5) then
					table.insert(fails, `{id} ({role}) {u.where} {hex(u.color)}`)
				end
			end
		end
	end)
	checkMissing(fails)
	report(fails, "red Skyline colours")
end)

H.test("5d: no Skyline look pairs a red with a blue", function()
	local fails = {}
	eachLook(function(id, role, l)
		if isSkyline(id) then
			local red, blue
			for _, u in l.all do
				if isRed(u.color, 0.4) then
					red = u
				end
				if isBlue(u.color) then
					blue = u
				end
			end
			if red and blue then
				table.insert(fails, `{id} ({role}): {red.where} {hex(red.color)} with {blue.where} {hex(blue.color)}`)
			end
		end
	end)
	checkMissing(fails)
	report(fails, "red-and-blue pairs")
end)

H.test("5e: Threadrunner has no amber and no pale head colour", function()
	local fails = {}
	if not C.STYLE.spiderman then
		table.insert(fails, "no STYLE entry for spiderman (Styles/skyline.luau)")
	end
	eachLook(function(id, role, l)
		if id ~= "spiderman" then
			return
		end
		for _, u in l.all do
			local h, s, val = C.hsv(u.color)
			local dh = math.abs(h - 35.2)
			dh = math.min(dh, 360 - dh)
			if not skinExempt(u) and s >= 0.25 and dh <= 20 then
				table.insert(fails, `({role}) {u.where} {hex(u.color)} is amber (hue {math.floor(h)})`)
			end
			if u.head and val > 0.85 and s < 0.15 then
				table.insert(fails, `({role}) {u.where} {hex(u.color)} is a pale head colour`)
			end
		end
	end)
	report(fails, "Threadrunner colours")
end)

H.test("5f: character-boss FaceGlow is colors.sig", function()
	local fails = {}
	eachLook(function(id, role, l)
		if role == "charBoss" then
			local sig = C.STYLE[id].colors.sig
			if l.faceGlow ~= sig then
				table.insert(fails, `{id}: FaceGlow {tostring(l.faceGlow)} ~= sig {hex(sig)}`)
			elseif isSkyline(id) and isRed(sig, 0.5) then
				table.insert(fails, `{id}: FaceGlow {hex(sig)} is red`)
			end
		elseif l.faceGlow ~= nil then
			table.insert(fails, `{id} ({role}): a FaceGlow outside the boss role`)
		end
	end)
	checkMissing(fails)
	report(fails, "boss FaceGlows")
end)

-- The style's source colours, read here only (never at runtime, §2.7).
local NOT_COLOURS = { browAngle = true, hairLen = true, height = true, headScale = true }
local function sourceColours(id: string): { number }
	local out = {}
	local rows = {
		(Characters :: any)[id],
		(Characters :: any)[id .. "C"],
		(EnemyLooks :: any)["boss_" .. id],
		(EnemyLooks :: any)[id .. "_b"],
		(EnemyLooks :: any)[id],
	}
	for i = 1, 5 do
		local row = rows[i]
		if type(row) == "table" then
			for k, val in row do
				if type(val) == "number" and not NOT_COLOURS[k] then
					table.insert(out, val)
				end
			end
		end
	end
	return out
end

local WORLD: { [number]: boolean } = {}
for _, c in C.WORLD_CONST do
	WORLD[c] = true
end
local BODY_SLOT = { top = true, sleeves = true, bottom = true, trim = true, hair = true }

H.test("5g: at most 2 verbatim source colours per style, none on the body", function()
	local fails = {}
	eachLook(function(id, role, l)
		local src = sourceColours(id)
		local copied: { [number]: string } = {}
		local body: { string } = {}
		for _, u in l.all do
			local _, _, val = C.hsv(u.color)
			if not (skinExempt(u) or val < 0.25 or WORLD[u.color] or WORLD[u.base]) then
				for _, sc in src do
					if C.dist(u.color, sc) < 8 then
						copied[u.color] = copied[u.color] or `{u.where} {hex(u.color)}~{hex(sc)}`
						if u.slot and (BODY_SLOT[u.slot] or string.match(u.slot, "^limbs%.")) then
							table.insert(body, `{u.where} {hex(u.color)}~{hex(sc)}`)
						end
						break
					end
				end
			end
		end
		local list = {}
		for _, what in copied do
			table.insert(list, what)
		end
		table.sort(list)
		if #list > 2 then
			table.insert(fails, `{id} ({role}): {#list} copies: {table.concat(list, ", ")}`)
		end
		for _, b in body do
			table.insert(fails, `{id} ({role}): body colour copied: {b}`)
		end
	end)
	checkMissing(fails)
	report(fails, "verbatim copies")
end)

------------------------------------------------------------------------------
-- 6. Palette
------------------------------------------------------------------------------

H.test("6: palette base is captured before the affix", function()
	local fails = {}
	local all: { [string]: any } = table.clone(Enemies :: any)
	for id, t in Finale.ENEMIES do
		all[id] = t
	end
	for id, t in all do
		local entry = C.ENEMY[C.baseId(id)]
		for _, a in Rules.AFFIXES do
			local template = table.clone(t)
			local pal = C.palette(template, a, entry)
			local own = (entry and entry.variant.color) or t.color
			if pal.base == a.color and own ~= a.color then
				table.insert(fails, `{id} + {a.key}: base took the affix colour`)
			end
			if pal.affix ~= a.color then
				table.insert(fails, `{id} + {a.key}: affix colour not kept`)
			end
			-- after applyAffix the template colour is the affix's (F10); the
			-- captured palette must not change
			Rules.applyAffix(template, a)
			if C.palette(t, a, entry).base ~= pal.base then
				table.insert(fails, `{id} + {a.key}: palette depends on the affixed copy`)
			end
		end
		local pal = C.palette(t, nil, entry)
		if pal.nature ~= RulesData.NATURE[t.nature].color then
			table.insert(fails, `{id}: nature colour`)
		end
	end
	report(fails, "palette problems")
	H.eq(C.palette((Enemies :: any).goblin_drone, nil, C.ENEMY.goblin_drone).base, 0xc8642a, "goblin_drone base")
	H.eq(C.darken(0x2a2a30), 0x2a2a30, "darken fixed point")
	H.eq(C.darken(0xffffff), C.lerp(0xffffff, 0x2a2a30, 0.2), "darken is the 20% lerp")
	H.eq(C.bossShade(0x14040a), 0x14040a, "boss shade fixed point")
end)

------------------------------------------------------------------------------
-- 7. Adaptation order
------------------------------------------------------------------------------

H.test("7: ADAPT_ORDER is a permutation of the natures", function()
	local seen: { [string]: boolean } = {}
	for _, n in C.ADAPT_ORDER do
		if not RulesData.NATURE[n] then
			error("not a nature: " .. n)
		end
		if seen[n] then
			error("repeated: " .. n)
		end
		seen[n] = true
	end
	for n in RulesData.NATURE do
		if not seen[n] then
			error("missing: " .. n)
		end
	end
	H.eq(#C.ADAPT_ORDER, 8, "natures")
end)

------------------------------------------------------------------------------
-- 8. Props
------------------------------------------------------------------------------

H.test("8: every arsenal key has a prop of at most 3 parts; only ironman suits", function()
	local fails = {}
	for style, a in Arsenals :: any do
		local props = C.ARSENAL_PROP[style]
		for _, key in a.order do
			local pr = props and props[key]
			if not pr then
				table.insert(fails, `{style}.{key}: no prop`)
			else
				local n = pr.parts
				if type(n) ~= "number" or n > 3 then
					table.insert(fails, `{style}.{key}: {tostring(n)} parts`)
				end
				if pr.pieces and #pr.pieces ~= n then
					table.insert(fails, `{style}.{key}: {#pr.pieces} pieces for {n} parts`)
				end
				if (pr.suit == true) ~= (style == "ironman") then
					table.insert(fails, `{style}.{key}: suit = {tostring(pr.suit)}`)
				end
			end
		end
	end
	for style, props in C.ARSENAL_PROP do
		for key in props do
			local a = (Arsenals :: any)[style]
			if not (a and table.find(a.order, key)) then
				table.insert(fails, `{style}.{key}: not in Arsenals`)
			end
		end
	end
	report(fails, "prop problems")
end)

------------------------------------------------------------------------------
-- 9. Roles
------------------------------------------------------------------------------

H.test("9: roles follow the §1.5 precedence", function()
	local fails = {}
	local E = Enemies :: any
	for _, id in RulesData.ALPHA_IDS do
		local r = C.role(id, E[id], nil)
		if r ~= "alpha" then
			table.insert(fails, `{id}: {r}`)
		end
	end
	for id, t in Finale.ENEMIES do
		local r = C.role(id, t, nil)
		if r ~= "finale" then
			table.insert(fails, `{id}: {r}`)
		end
	end
	for _, id in RulesData.BOSS_IDS do
		local r = C.role(id, E[id], nil)
		if r ~= "charBoss" then
			table.insert(fails, `{id}: {r}`)
		end
	end
	for _, id in { "hanami", "jogo", "mahito_b", "dagon_b", "kenjaku_b", "toji_b" } do
		local r = C.role(id, E[id], nil)
		if r ~= "charBoss" then
			table.insert(fails, `{id}: {r}`)
		end
	end
	for w = 1, 30 do
		if Rules.rollAffix(w, true, 0, 0, 1) ~= nil then
			table.insert(fails, `rollAffix gave a boss an affix in wave {w}`)
		end
	end
	report(fails, "role problems")
	H.eq(C.role("rogue_ninja", E.rogue_ninja, nil), "normal", "rogue_ninja")
	H.eq(C.role("rogue_ninja", E.rogue_ninja, Rules.AFFIXES[1]), "elite", "rogue_ninja + affix")
	H.eq(C.role("hyakunui", nil, nil, false), "normal", "isFinale overrides")
	H.eq(C.role("anything", nil, nil, true), "finale", "isFinale overrides")
end)

------------------------------------------------------------------------------
-- 11. Ellipsoids
------------------------------------------------------------------------------

H.test("11: a ball has three equal axes, anything else is an ellipsoid", function()
	local fails = {}
	for _, r in C.ROUND do
		local s = r.size
		local equal = s.x == s.y and s.y == s.z
		if r.kind == "ball" and not equal then
			table.insert(fails, `{r.code}: ball with unequal axes`)
		elseif r.kind ~= "ball" and r.kind ~= "ell" then
			table.insert(fails, `{r.code}: kind {r.kind}`)
		end
	end
	for style, props in C.ARSENAL_PROP do
		for key, pr in props do
			for _, piece in pr.pieces or {} do
				local s = piece.size
				if piece.kind == "ball" and not (s.x == s.y and s.y == s.z) then
					table.insert(fails, `{style}.{key}: ball with unequal axes`)
				end
			end
		end
	end
	report(fails, "round pieces")
end)

------------------------------------------------------------------------------
-- 13. Suit listener
------------------------------------------------------------------------------

H.test("13: the Suit listener is edge-triggered", function()
	local seq: { number? } = { 260, 251, 240, 12, 0, nil, 30 }
	local state, changed = C.suitEdge(nil, seq[1])
	H.eq(state, true, "initial state")
	H.eq(changed, true, "initial mount")
	local transitions = {}
	for i = 2, 7 do
		local now, edge = C.suitEdge(state, seq[i])
		if edge then
			table.insert(transitions, `{if now then "on" else "off"} at {tostring(seq[i])}`)
		end
		state = now
	end
	H.eq(table.concat(transitions, ", "), "off at 0, on at 30", "transitions")
	local s0, c0 = C.suitEdge(nil, nil)
	H.eq(s0, false, "no suit at first read")
	H.eq(c0, false, "nothing to mount")
end)
