--!strict
-- Where the tests find each world's layout and seed.

local Layouts = require("../src/shared/Layouts")
local Maps = require("../src/shared/Data/Maps")
local Finale = require("../src/shared/Finale")
local fs = require("@lune/fs")

local W = {}

--- The seed a theme's map uses, as Arenas passes it.
function W.seed(theme: string): number
	if theme == "seam" then
		return (Finale.MAP :: any).seed
	end
	for _, m in Maps :: any do
		if Layouts.THEME_OF[m.build] == theme then
			return m.seed
		end
	end
	return 1
end

--- Whether a theme's layout file exists yet.
function W.has(theme: string): boolean
	return fs.isFile("src/shared/Layouts/" .. theme .. ".luau")
end

function W.plan(theme: string): Layouts.Plan
	local def = (require :: any)("../src/shared/Layouts/" .. theme)
	return Layouts.plan(theme, def, W.seed(theme))
end

return W
