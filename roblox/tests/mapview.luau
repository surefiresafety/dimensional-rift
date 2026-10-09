--!strict
-- Draws layouts from above as SVG, from the same plan the game builds:
--   lune run tests/mapview [theme ...]     (default: every theme with a layout)
-- Writes docs/design/maps/<theme>.svg. Parts are filled in their own colour,
-- drawn low to high; rails are dark lines, walks dashed yellow, accesses
-- green arrows, pads rings (boss pads red), the hero sightline a white line.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Layouts = require("../src/shared/Layouts")
local W = require("./worlds")

local VIEW = 75 -- units either side of the centre
local S = 6 -- pixels per unit
local SIZE = VIEW * 2 * S

local function px(x: number): number
	return (x + VIEW) * S
end

local function hex(c: number): string
	return string.format("#%06x", c)
end

local function draw(theme: string)
	local P = W.plan(theme)
	local out = {}
	local function add(s: string)
		table.insert(out, s)
	end
	add(
		`<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE + 40}" viewBox="0 0 {SIZE} {SIZE + 40}" font-family="sans-serif">`
	)
	local g = if P.ground then (P.ground.color or 0x556655) else 0x556655
	add(`<rect width="{SIZE}" height="{SIZE + 40}" fill="#111"/>`)
	add(`<rect width="{SIZE}" height="{SIZE}" fill="{hex(g)}"/>`)
	for _, w in P.water do
		if w.r then
			add(`<circle cx="{px(w.x)}" cy="{px(w.z)}" r="{w.r * S}" fill="#2f6f9f"/>`)
		end
	end
	-- rings: plaza, pad band
	for _, r in { 12, 20, 50 } do
		add(`<circle cx="{px(0)}" cy="{px(0)}" r="{r * S}" fill="none" stroke="#ffffff" stroke-opacity="0.15"/>`)
	end
	local recs = table.clone(P.recs)
	table.sort(recs, function(a, b)
		return a.h1 < b.h1
	end)
	for _, r in recs do
		if r.ghost then
			continue
		end
		local op = if r.set == "decor" then 0.45 elseif r.set == "core" or r.set == "foliage" then 0.35 else 0.95
		local stroke = if r.set == "rail"
			then ` stroke="#101014" stroke-width="2"`
			else ` stroke="#000" stroke-opacity="0.35" stroke-width="0.6"`
		local fill = hex(r.color)
		if r.shape == "cyl" or r.shape == "ball" then
			add(`<circle cx="{px(r.x)}" cy="{px(r.z)}" r="{r.w / 2 * S}" fill="{fill}" fill-opacity="{op}"{stroke}/>`)
		else
			local pts = {}
			for _, q in Layouts.corners(r) do
				table.insert(pts, `{px(q[1])},{px(q[2])}`)
			end
			add(`<polygon points="{table.concat(pts, " ")}" fill="{fill}" fill-opacity="{op}"{stroke}/>`)
			if r.run then
				local x1, z1 = Layouts.toWorld(r.x, r.z, r.yaw, -r.w / 2, 0)
				local x2, z2 = Layouts.toWorld(r.x, r.z, r.yaw, r.w / 2, 0)
				add(
					`<line x1="{px(x1)}" y1="{px(z1)}" x2="{px(x2)}" y2="{px(z2)}" stroke="#fff" stroke-opacity="0.5" stroke-width="1"/>`
				)
			end
		end
	end
	for _, w in P.walks do
		add(
			`<line x1="{px(w.a[1])}" y1="{px(w.a[2])}" x2="{px(w.b[1])}" y2="{px(w.b[2])}" stroke="#ffd54a" stroke-width="2" stroke-dasharray="6 4"/>`
		)
	end
	for _, a in P.access do
		add(
			`<line x1="{px(a.foot[1])}" y1="{px(a.foot[2])}" x2="{px(a.top[1])}" y2="{px(a.top[2])}" stroke="#3ddc97" stroke-width="3"/>`
		)
		add(`<circle cx="{px(a.top[1])}" cy="{px(a.top[2])}" r="4" fill="#3ddc97"/>`)
	end
	for _, p in P.pads do
		local e = if p.boss then 8 else 6
		local col = if p.boss then "#ff3b5c" else "#3ae0ff"
		add(
			`<rect x="{px(p.x - e)}" y="{px(p.z - e)}" width="{2 * e * S}" height="{2 * e * S}" fill="none" stroke="{col}" stroke-dasharray="4 3"/>`
		)
		add(`<circle cx="{px(p.x)}" cy="{px(p.z)}" r="5" fill="{col}"/>`)
	end
	if P.hero then
		add(
			`<line x1="{px(0)}" y1="{px(0)}" x2="{px(P.hero.x)}" y2="{px(P.hero.z)}" stroke="#fff" stroke-width="1.5" stroke-dasharray="2 3"/>`
		)
	end
	add(`<circle cx="{px(0)}" cy="{px(0)}" r="6" fill="#b06cff"/>`)
	add(`<text x="{px(0)}" y="14" fill="#fff" font-size="13" text-anchor="middle">N</text>`)
	add(
		`<text x="10" y="{SIZE + 26}" fill="#ddd" font-size="16">{theme}: {P.parts + Layouts.FIXED_PARTS} parts, {P.lights + Layouts.FIXED_LIGHTS} lights, {#P.pads} pads · 1 grid square = 10 u · yellow dashes: upper route · green: stairs/ladders · red squares: boss pads</text>`
	)
	-- a 10 u grid, faint
	for i = -7, 7 do
		add(`<line x1="{px(i * 10)}" y1="0" x2="{px(i * 10)}" y2="{SIZE}" stroke="#fff" stroke-opacity="0.05"/>`)
		add(`<line x1="0" y1="{px(i * 10)}" x2="{SIZE}" y2="{px(i * 10)}" stroke="#fff" stroke-opacity="0.05"/>`)
	end
	add("</svg>")
	fs.writeFile("../docs/design/maps/" .. theme .. ".svg", table.concat(out, "\n"))
	print("wrote docs/design/maps/" .. theme .. ".svg")
end

local themes = if #process.args > 0 then process.args else Layouts.THEMES
for _, t in themes do
	if W.has(t) then
		draw(t)
	end
end
