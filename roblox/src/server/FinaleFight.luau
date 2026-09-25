--!strict
-- Hyakunui, the Hundred-Seam: the last fight. It fights like any boss (Rules.
-- aiStep drives it) and on top of that runs three phases by its health:
--   1. Seam cuts: every few seconds a ring opens under each player near it,
--      and a moment later the ground there is cut. Move, or dodge through.
--   2. At two thirds it tears the Tempest Fox and the Unbidden out of its
--      own stitching. The Unbidden adapts to any nature that hits it three
--      times, so vary how you fight it.
--   3. At a third it starts reaching for bodies: a wider ring on one player.
--      Caught inside, the Vessel's king answers (Akuro takes over, if he has
--      not yet this life), a symbiote is starved on the spot, and anyone else
--      loses a quarter of their health.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Finale = require(Shared.Finale)
local Remotes = require(Shared.Remotes)
local Story = require(Shared.Story)
local Styles = require(Shared.Data.Styles)

local Combat = require(script.Parent.Combat)
local Enemies = require(script.Parent.Enemies)

local STUDS = Config.STUDS_PER_UNIT
local StoryRemote = Remotes.get("Story")

local FinaleFight = {}

type Fight = { phase: number, nextCut: number, nextGrasp: number }
local fights: { [Combat.Enemy]: Fight } = setmetatable({}, { __mode = "k" }) :: any

local function announce(phase: number)
	local p = Story.PHASES[phase]
	Combat.fx("banner", { text = p.banner, color = 0xff2d55 })
	StoryRemote:FireAllClients("line", { speaker = "", text = p.text })
end

--- Players alive within `range` studs of `at`.
local function playersNear(at: Vector3, range: number): { Combat.PState }
	local out = {}
	for _, ps in Combat.states do
		local hum = Combat.humanoidOf(ps.player)
		local root = Combat.rootOf(ps.player)
		if hum and root and hum.Health > 0 and (root.Position - at).Magnitude < range then
			table.insert(out, ps)
		end
	end
	return out
end

local function seamCut(e: Combat.Enemy)
	local cfg = Finale.SEAM_CUT
	local radius = cfg.radius * STUDS
	for _, ps in playersNear(e.root.Position, 60 * STUDS) do
		local root = Combat.rootOf(ps.player)
		if root then
			local spot = root.Position
			Combat.fx("telegraph", { at = spot, radius = radius, color = 0xff2d55, duration = cfg.warn })
			task.delay(cfg.warn, function()
				Combat.fx("ring", { at = spot, radius = radius, color = 0xff2d55 })
				for _, other in Combat.states do
					local r = Combat.rootOf(other.player)
					if r and ((r.Position - spot) * Vector3.new(1, 0, 1)).Magnitude <= radius then
						Combat.hurtPlayer(other, cfg.power, "cursed", if e.dead then nil else e)
					end
				end
			end)
		end
	end
end

local function grasp(e: Combat.Enemy)
	local cfg = Finale.GRASP
	local near = playersNear(e.root.Position, 70 * STUDS)
	if #near == 0 then
		return
	end
	local ps = near[math.random(1, #near)]
	local root = Combat.rootOf(ps.player)
	if not root then
		return
	end
	local spot = root.Position
	local radius = cfg.radius * STUDS
	Combat.fx("telegraph", { at = spot, radius = radius, color = 0xb06cff, duration = cfg.warn })
	task.delay(cfg.warn, function()
		local r = Combat.rootOf(ps.player)
		local hum = Combat.humanoidOf(ps.player)
		if not r or not hum or hum.Health <= 0 then
			return
		end
		Combat.fx("ring", { at = spot, radius = radius, color = 0xb06cff })
		if ((r.Position - spot) * Vector3.new(1, 0, 1)).Magnitude > radius then
			return -- got out
		end
		local st = ps.style and Styles[ps.style]
		local sym = st and st.symbiote
		if st and st.takeover and not ps.takeoverUsed and Combat.onLethal(ps) then
			StoryRemote:FireClient(ps.player, "line", {
				speaker = "Akuro",
				text = "You reach for MY body? Then take your hand back. You will not have it for long.",
			})
		elseif sym and sym.hunger and not ps.looseSuit then
			ps.hunger = 0
			StoryRemote:FireClient(
				ps.player,
				"line",
				{ speaker = "Blackmaw", text = "It pulled something out of us. We are EMPTY." }
			)
		else
			Combat.hurtPlayer(ps, math.floor(hum.MaxHealth * cfg.share), "cursed", if e.dead then nil else e)
		end
	end)
end

--- Once a tenth of a second, from the server's clock.
function FinaleFight.step()
	local now = Combat.now()
	for _, e in Combat.enemies do
		if e.dead or not e.t.finale then
			continue
		end
		local f = fights[e]
		if not f then
			f = { phase = 1, nextCut = now + 5, nextGrasp = now + 4 }
			fights[e] = f
			announce(1)
		end
		local phase = Finale.phaseOf(e.hum.Health / e.hum.MaxHealth)
		if phase > f.phase then
			f.phase = phase
			announce(phase)
			if phase == 2 then
				-- It tears two things out of its own stitching.
				for i, id in { "tempest_fox", "the_unbidden" } do
					local side = e.root.CFrame.RightVector * (if i == 1 then 1 else -1) * 8 * STUDS
					local add = Enemies.spawn(id, e.root.Position + side)
					if add then
						add.alerted = true
					end
				end
			end
		end
		if now >= f.nextCut then
			f.nextCut = now + Finale.SEAM_CUT.every * (if f.phase >= 3 then 0.7 else 1)
			seamCut(e)
		end
		if f.phase >= 3 and now >= f.nextGrasp then
			f.nextGrasp = now + Finale.GRASP.every
			grasp(e)
		end
	end
end

return FinaleFight
