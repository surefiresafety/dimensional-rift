--!strict
-- One world's layout checks in detail, for writing a layout:
--   lune run tests/world city        (from the roblox folder)
--   lune run tests/world city fan    (also print every grid point's facings)

local process = require("@lune/process")
local C = require("./layoutcheck")
local W = require("./worlds")

local theme = process.args[1] or "city"
local verbose = process.args[2] == "fan"
local P = W.plan(theme)
print(
	`{theme}: {P.parts} parts, {P.lights} lights in the layout (+ portal, weather, Nav), budget {P.budget.parts} / {P.budget.lights}`
)
print(`{#P.pads} pads, {#P.walks} walks, {#P.access} accesses`)

local total = 0
local function report(name: string, fails: { string })
	total += #fails
	print(`{if #fails == 0 then "ok  " else "FAIL"} {name}{if #fails > 0 then " (" .. #fails .. ")" else ""}`)
	for i, f in fails do
		if i > 40 then
			print("       ...")
			break
		end
		print("       " .. f)
	end
end

report("ids", C.ids(P))
report("pads", C.pads(P))
report("walks within 25 u of access", C.walks(P))
report("walk support", C.support(P))
report("access widths", C.access(P))
report("plaza", C.plaza(P))
report("budget", C.budget(P))
report("hero sightline", C.hero(P))
report("hills", C.hills(P))
report("anchors 5 x 5", C.anchors(P))
local F = C.fan(P)
report(`swing fan: {F.points} points, {F.skipped} skipped, {F.full} 4-of-4`, F.fails)
local expect = C.EXPECT[theme]
if expect and math.abs(F.points - expect) > 3 then
	print(`WARN grid points {F.points}, design expects {expect}`)
end
if verbose then
	local keys = {}
	for k in F.heights do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in keys do
		local h = F.heights[k]
		print(string.format("  (%s) N%.1f E%.1f S%.1f W%.1f", k, h[1], h[2], h[3], h[4]))
	end
end
print(if total == 0 then "ALL PASS" else `{total} failures`)
process.exit(if total == 0 then 0 else 1)
