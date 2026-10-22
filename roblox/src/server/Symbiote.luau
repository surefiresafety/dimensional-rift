--!strict
-- The symbiote, for the styles that wear one: its suit mending, its hunger
-- and what it says about it, the bond that fire and sound strip, the takeover
-- when it starves, and coming off you. Ported from updateSuit, bondHit,
-- detachSymbiote and updateLooseSuit in web3d/rift3d.html.
--
-- The panic is here too (the suit covering you on its own under 100 health);
-- the tendrils and webbing on R are Abilities.stepAuto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Rules = require(Shared.Rules)
local RulesData = require(Shared.Data.Rules)
local Styles = require(Shared.Data.Styles)

local Combat = require(script.Parent.Combat)
local Abilities = require(script.Parent.Abilities)

local STUDS = Config.STUDS_PER_UNIT
local BOND_MAX = RulesData.BOND_MAX
local LINES = RulesData.SYM_LINES :: { [string]: { string } }
local IDLE = RulesData.SYM_IDLE :: { string }

local Symbiote = {}

-- Set by init: puts a player into a style, keeping their health and place.
local restyle: (ps: Combat.PState, styleId: string) -> () = function() end
function Symbiote.setRestyle(fn: (Combat.PState, string) -> ())
	restyle = fn
end

local function symOf(ps: Combat.PState): any
	local st = ps.style and Styles[ps.style]
	return st and st.symbiote
end

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

--- A line from the suit. Loud ones go up as a banner as well.
function Symbiote.say(ps: Combat.PState, text: string, loud: boolean?)
	Combat.notice(ps.player, text, "sym")
	if loud then
		Combat.fx("banner", { text = string.upper(text), color = 0xc0294a })
	end
end
Abilities.say = Symbiote.say

--- It comes off. You have a minute to get it back, or you never do.
function Symbiote.detach(ps: Combat.PState, cause: string)
	if ps.looseSuit then
		return
	end
	local root = Combat.rootOf(ps.player)
	if not root then
		return
	end
	local host = ps.baseStyle or ps.style :: string
	local transformed = ps.baseStyle ~= nil
	ps.bond, ps.hunger, ps.feeding = 0, 100, false
	local at = root.Position + Vector3.new(2.5, 0, 2.5) * STUDS
	local blob = Instance.new("Part")
	blob.Name = "LooseSymbiote"
	blob.Shape = Enum.PartType.Ball
	blob.Size = Vector3.one * 1.1 * STUDS
	blob.Color = Palette.color(0x1a1a24)
	blob.Material = Enum.Material.SmoothPlastic
	blob.Anchored = true
	blob.CanCollide = false
	blob.CFrame = CFrame.new(at.X, root.Position.Y - 2, at.Z)
	blob.Parent = workspace
	ps.looseSuit = { untilT = Combat.now() + 60, host = host, at = blob.Position, part = blob :: BasePart }
	-- A takeover transform is undone too: the suit was the transform. After
	-- looseSuit is set, so nothing can detach it twice while the body reloads.
	if transformed then
		Combat.revert(ps)
	end
	Symbiote.say(ps, "NO. No, no, we need you.", true)
	Combat.fx("banner", { text = "THE SYMBIOTE IS OFF", color = 0xc0294a })
	Combat.fx("burst", { at = root.Position, color = 0x1a1a24, count = 34 })
	Combat.notice(
		ps.player,
		`{string.upper(string.sub(cause, 1, 1)) .. string.sub(cause, 2)} tore it off you. It is on the ground: walk into it and press F to put it back on, or leave it and it finds someone else.`,
		"gold"
	)
	Combat.publish(ps)
end

--- F, standing on it: it climbs back on.
function Symbiote.rebond(ps: Combat.PState)
	local L = ps.looseSuit
	local root = Combat.rootOf(ps.player)
	if not L or not root then
		return
	end
	if ((root.Position - L.at) * Vector3.new(1, 0, 1)).Magnitude > 3.2 * STUDS then
		Combat.notice(ps.player, "Stand on it to put it back on.")
		return
	end
	L.part:Destroy()
	ps.looseSuit = nil
	ps.bond, ps.suitHp, ps.suitBroken = BOND_MAX, nil, false
	restyle(ps, L.host)
	Symbiote.say(ps, "...thank you.")
	Combat.fx("banner", { text = "BONDED AGAIN", color = 0xc0294a })
	Combat.publish(ps)
end

--- What a hit does to the bond: fire and noise strip it.
--- Pushes back and stuns everything within `radius` units: a takeover
--- clears itself some room.
function Symbiote.shove(ps: Combat.PState, radius: number, push: number, stun: number)
	local root = Combat.rootOf(ps.player)
	if not root then
		return
	end
	for _, e in Combat.enemiesNear(root.Position, radius * STUDS) do
		local away = (e.root.Position - root.Position) * Vector3.new(1, 0, 1)
		if away.Magnitude > 0.01 then
			e.root.CFrame += away.Unit * push * STUDS
		end
		e.status.stun = math.max(e.status.stun or 0, stun)
	end
end

Combat.afterHurt = function(ps: Combat.PState, dmg: number, nature: string)
	local sym = symOf(ps)
	if not sym or ps.looseSuit then
		return
	end
	-- Under the line it stops waiting to be asked: the suit covers him, and
	-- stays until G (symbioteTakeover in the web build).
	local hum = Combat.humanoidOf(ps.player)
	local now = Combat.now()
	local st = Styles[ps.style :: string]
	local u = st and st.ultimate
	if
		sym.panicUnder
		and hum
		and hum.Health > 0
		and hum.Health < sym.panicUnder
		and now >= ps.symbioteCd
		and not ps.baseStyle
		and not ps.reloading
		and u
		and u.toggle
		and u.into
	then
		ps.symbioteCd = now + (sym.panicCd or 45)
		ps.invulnUntil = math.max(ps.invulnUntil, now + 1.5) -- covered while it takes him
		table.clear(ps.cooldowns)
		Combat.fx("banner", { text = "THE SUIT TAKES OVER", color = 0xf0f0f0 })
		Combat.notice(
			ps.player,
			"It did not wait to be asked. The symbiote covers him and starts hitting back (G to take it off).",
			"gold"
		)
		Symbiote.shove(ps, 12, 4, 1.2)
		Abilities.transform(ps, u.into)
	end
	local loss = Rules.bondLoss(nature, dmg)
	if loss <= 0 then
		return
	end
	ps.bond = math.max(0, ps.bond - loss)
	if ps.bond > 0 and ps.bond < 35 and not ps.bondWarned then
		ps.bondWarned = true
		Symbiote.say(ps, if nature == "sound" then "The noise. Stop the NOISE." else "It burns, it BURNS.", true)
	end
	if ps.bond <= 0 then
		Symbiote.detach(ps, if nature == "sound" then "the noise" else "the fire")
	end
end

local function stepOne(ps: Combat.PState, dt: number, now: number)
	-- A suit left on the ground: a minute, then it is gone for good, and what
	-- is left is the four arms he built himself.
	local L = ps.looseSuit
	if L and now > L.untilT then
		L.part:Destroy()
		ps.looseSuit = nil
		if Styles.ironspider then
			restyle(ps, "ironspider")
			Combat.fx("banner", { text = "IRONTHREAD", color = 0xffc83d })
		end
		Combat.notice(
			ps.player,
			"It gave up on you and crawled away. What you have left is four arms of your own making.",
			"gold"
		)
		return
	end

	local sym = symOf(ps)
	if not sym then
		return
	end
	local sinceHurt = now - ps.suitHurtAt
	local wasBroken = ps.suitBroken
	ps.suitHp, ps.suitBroken = Rules.suitRegen(sym, ps.suitHp or sym.suit, ps.suitBroken, sinceHurt, dt)
	if wasBroken and not ps.suitBroken then
		Combat.notice(ps.player, "The symbiote has knitted itself back together.", "gold")
	end

	if sym.hunger then
		local after, mark = Rules.hungerStep(ps.hunger, sym.hunger.drain, dt)
		ps.hunger = after
		if mark then
			Symbiote.say(ps, pick(LINES[tostring(mark)]), mark <= 15)
		end
		ps.symChat -= dt
		if ps.symChat <= 0 then
			ps.symChat = 16 + math.random() * 14
			if ps.hunger > 40 then
				Symbiote.say(ps, pick(IDLE))
			end
		end
	end

	if not ps.looseSuit then
		ps.bond = Rules.bondStep(ps.bond, BOND_MAX, if sym.hunger then ps.hunger else 100, sinceHurt, dt)
		if ps.bond > 45 then
			ps.bondWarned = false
		end
		if ps.bond <= 0 then
			Symbiote.detach(ps, "the hunger")
			return
		end
	end

	if not sym.hunger or ps.looseSuit then
		return
	end
	-- Nothing left: it stops asking and drives.
	if ps.hunger <= 0 and not ps.feeding then
		ps.feeding = true
		Symbiote.say(ps, LINES["0"][1], true)
		Combat.fx("banner", { text = "IT TAKES OVER", color = 0xc0294a })
		Combat.notice(ps.player, "The symbiote stops asking. It has the body now, and it is going to eat.", "gold")
		local u = Styles[ps.style :: string].ultimate
		if not ps.baseStyle and u and u.toggle and u.into then
			Abilities.transform(ps, u.into)
		end
	end
	if ps.feeding then
		-- It hunts on its own until it has eaten enough to settle.
		ps.feedTry -= dt
		if ps.feedTry <= 0 then
			ps.feedTry = 0.8
			table.clear(ps.cooldowns)
			ps.se = math.max(ps.se, 40)
			local root = Combat.rootOf(ps.player)
			Abilities.cast(ps, "symbiote_feed", if root then root.CFrame.LookVector else Vector3.zAxis, { free = true })
		end
		if ps.hunger > 55 then
			ps.feeding = false
			Symbiote.say(ps, "...better. For now.")
			Combat.notice(ps.player, "It has had enough. You have the body back.")
		end
	end
end

function Symbiote.step(dt: number)
	local now = Combat.now()
	for _, ps in Combat.states do
		local hum = Combat.humanoidOf(ps.player)
		if hum and hum.Health > 0 then
			stepOne(ps, dt, now)
		end
	end
end

--- A new life: a full stomach, a whole bond, and nothing on the ground.
function Symbiote.reset(ps: Combat.PState)
	if ps.looseSuit then
		ps.looseSuit.part:Destroy()
		ps.looseSuit = nil
	end
	ps.hunger, ps.bond, ps.feeding, ps.symChat = 100, BOND_MAX, false, 14
	ps.suitHp, ps.suitBroken = nil, false
	ps.bondWarned = false
end

return Symbiote
