--!strict
-- Every world's layout against the design's checks (docs/design/worlds.md §4.5).
-- `lune run tests/world <theme>` prints one world's checks in detail.

local H = require("./harness")
local Layouts = require("../src/shared/Layouts")
local C = require("./layoutcheck")
local W = require("./worlds")

print("Layouts")

for _, theme in Layouts.THEMES do
	if not W.has(theme) then
		H.test(theme .. ": has a layout", function()
			error("no src/shared/Layouts/" .. theme .. ".luau")
		end)
		continue
	end
	local P = W.plan(theme)
	local function gate(name: string, fails: { string })
		H.test(`{theme}: {name}`, function()
			assert(#fails == 0, table.concat(fails, "\n       "))
		end)
	end
	gate("ids are unique", C.ids(P))
	gate("pads are clear", C.pads(P))
	gate("walks are near an access", C.walks(P))
	gate("walks are supported", C.support(P))
	gate("accesses are wide enough", C.access(P))
	gate("the plaza is open", C.plaza(P))
	gate("within budget", C.budget(P))
	gate("the hero is in sight", C.hero(P))
	gate("hills keep clear", C.hills(P))
	gate("anchors are big enough", C.anchors(P))
	local F = C.fan(P)
	gate(`every point can swing ({F.points} points, {F.full} 4-of-4)`, F.fails)
	if math.abs(F.points - (C.EXPECT[theme] or F.points)) > 3 then
		print(`  WARN {theme}: {F.points} grid points, design expects {C.EXPECT[theme]}`)
	end
end
