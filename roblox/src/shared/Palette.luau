--!strict
-- The data stores colours as 0xRRGGBB integers, the way the web build does.

local Palette = {}

function Palette.rgb(n: number): (number, number, number)
	return bit32.extract(n, 16, 8), bit32.extract(n, 8, 8), bit32.extract(n, 0, 8)
end

function Palette.color(n: number?): Color3
	if n == nil then
		return Color3.new(1, 1, 1)
	end
	return Color3.fromRGB(Palette.rgb(n))
end

return Palette
