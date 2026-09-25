--!strict
-- Dimensional Rift, server. Wires the services together and runs the clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Styles = require(Shared.Data.Styles)
local RulesData = require(Shared.Data.Rules)
local Arsenals = require(Shared.Data.Arsenals)

local Combat = require(script.Combat)
local Abilities = require(script.Abilities)
local Projectiles = require(script.Projectiles)
local Enemies = require(script.Enemies)
local Waves = require(script.Waves)
local World = require(script.World)
local Looks = require(script.Looks)
local Symbiote = require(script.Symbiote)
local Pickups = require(script.Pickups)
local FinaleFight = require(script.FinaleFight)
local Story = require(script.Story)
local Profiles = require(script.Profiles)
local Progress = require(script.Progress)
local Signature = require(Shared.Signature)

-- Create every remote before anyone can ask for one.
local SelectStyle = Remotes.get("SelectStyle")
local Cast = Remotes.get("Cast")
local Action = Remotes.get("Action")

Players.CharacterAutoLoads = false -- a character is chosen before anyone spawns

--- Clears everything a fight leaves on a player: buffs, shields, summons, a
--- stored charge. Used on respawn and on picking a new character.
local function resetCombat(ps: Combat.PState)
	ps.transformUntil = nil
	ps.buff, ps.domain, ps.minions = nil, nil, {}
	ps.shield, ps.shieldUntil, ps.shieldReflect = 0, 0, 0
	ps.evadeUntil, ps.invulnUntil, ps.decoy = 0, 0, false
	ps.output, ps.chargeStart = nil, nil
	ps.player:SetAttribute("ChargeStart", nil)
end

--- Puts a player into a style: its kit, its energy, its body. `keepHealth`
--- keeps their health and where they stand (a transform, or a switch
--- mid-fight); without it they arrive fresh at the spawn.
local function applyStyle(ps: Combat.PState, styleId: string, keepHealth: boolean?)
	local st = Styles[styleId]
	ps.style = styleId
	-- The player's own loadout for this character, if they saved one.
	ps.slots = Progress.slotsFor(ps.player, styleId)
	ps.maxSe = (st.energy or Config.PLAYER_MAX_SE) * ps.spiritMul
	ps.se = math.min(ps.se, ps.maxSe)
	if ps.maxSe == math.huge then
		ps.se = math.huge
	end
	for _, id in st.pool do
		ps.learned[id] = true
	end
	-- A weapon set starts drawn: the current one if it belongs to this set,
	-- else the first (applyStyle in the web build).
	-- Auto-attack is for a kit with limbs or webbing of its own.
	if not (st.autoLimbs or st.autoWeb) then
		ps.autoAttack = false
	end
	local set = (Arsenals :: any)[styleId]
	if not (set and ps.weapon and set.items[ps.weapon]) then
		ps.weapon = if set then set.order[1] else nil
	end
	Combat.checkInfinity(ps)
	if not keepHealth then
		table.clear(ps.history) -- nothing to rewind to
	end
	local hum = Combat.humanoidOf(ps.player)
	local hp = if hum and keepHealth then hum.Health else nil
	ps.reloading = true
	Looks.dressPlayer(ps.player, styleId)
	ps.reloading = false
	local newHum = Combat.humanoidOf(ps.player)
	local root = Combat.rootOf(ps.player)
	if newHum then
		newHum.MaxHealth = Config.PLAYER_MAX_HP * Progress.upgradeMul(ps.player, "vitality")
		newHum.Health = math.min(hp or newHum.MaxHealth, newHum.MaxHealth)
		newHum.WalkSpeed = Config.WALK_SPEED
	end
	if root and not keepHealth then
		root.CFrame = CFrame.new(World.spawnPoint())
	end
	Progress.nameplate(ps.player)
	Combat.publish(ps)
end

-- Transform ultimates (Blackmaw, Antidote, Akuro) borrow another style's body
-- and kit, and give it back.
local function transform(ps: Combat.PState, into: string?)
	local root = Combat.rootOf(ps.player)
	local where = root and root.CFrame
	if into then
		ps.baseStyle = ps.baseStyle or ps.style
		applyStyle(ps, into, true)
		Combat.fx("banner", { text = string.upper(Styles[into].name), color = 0xffffff })
	elseif ps.baseStyle then
		local back = ps.baseStyle
		ps.baseStyle = nil
		applyStyle(ps, back, true)
	end
	local newRoot = Combat.rootOf(ps.player)
	if newRoot and where then
		newRoot.CFrame = where
	end
end
Abilities.setTransform(transform)

-- The Vessel's one save per life: the blow that would kill him lets Akuro
-- out instead, at full health and energy, with room cleared around him
-- (sukunaTakeover in the web build). He is himself again when he respawns.
Combat.onLethal = function(ps)
	local st = ps.style and Styles[ps.style]
	local into = st and st.takeover
	if not into or ps.takeoverUsed or not Styles[into] then
		return false
	end
	ps.takeoverUsed = true
	ps.invulnUntil = Combat.now() + 2.5
	table.clear(ps.cooldowns)
	Combat.fx("banner", { text = "AKURO TAKES OVER", color = 0xff2d55 })
	Combat.notice(
		ps.player,
		'"Know your place." Akuro has taken the body: full health, full energy, his techniques.',
		"gold"
	)
	Symbiote.shove(ps, 16, 6, 1.8)
	task.spawn(function()
		-- One body change at a time: let one already under way finish.
		while ps.reloading do
			task.wait()
		end
		transform(ps, into)
		ps.transformUntil = nil
		ps.se = ps.maxSe
		local hum = Combat.humanoidOf(ps.player)
		if hum then
			hum.Health = hum.MaxHealth
		end
		ps.invulnUntil = Combat.now() + 2.5
		Combat.publish(ps)
	end)
	return true
end
-- Changing body reloads the character, which yields. Anything that happens
-- inside the server's frame loop (a transform running out, the symbiote)
-- does it on its own thread so the loop never stalls halfway.
Combat.revert = function(ps)
	task.spawn(transform, ps, nil)
end
-- The symbiote puts you back in the suit, or leaves you in Ironthread.
Symbiote.setRestyle(function(ps, styleId)
	ps.baseStyle, ps.transformUntil = nil, nil
	task.spawn(function()
		local root = Combat.rootOf(ps.player)
		local where = root and root.CFrame
		applyStyle(ps, styleId, true)
		local newRoot = Combat.rootOf(ps.player)
		if newRoot and where then
			newRoot.CFrame = where
		end
	end)
end)

local function onPlayerAdded(player: Player)
	if Combat.states[player] then
		return
	end
	Combat.newState(player)
	player.CharacterAdded:Connect(function(character)
		local hum = character:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			Progress.died(player)
			-- Rise again as the same character after a beat, unless they have
			-- already picked someone new in the meantime.
			task.delay(4, function()
				local ps = Combat.states[player]
				if ps and ps.style and player.Parent and player.Character == character then
					-- Back as who they chose, not as whatever they had turned into.
					local chosen = ps.baseStyle or ps.style :: string
					ps.style = chosen
					ps.baseStyle = nil
					resetCombat(ps)
					ps.takeoverUsed = false -- a new life, a new save (not on a re-pick)
					Symbiote.reset(ps)
					applyStyle(ps, chosen)
				end
			end)
		end)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
-- In Studio the first player can arrive before this script runs.
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	local ps = Combat.states[player]
	if ps then
		Symbiote.reset(ps)
	end
	Combat.states[player] = nil
	Combat.lastHitBy[player] = nil
end)

local lastSelect: { [Player]: number } = {}
SelectStyle.OnServerEvent:Connect(function(player, styleId)
	local ps = Combat.states[player]
	if not ps or type(styleId) ~= "string" or not Styles[styleId] then
		return
	end
	-- Every pick reloads the character: once a second and a half at most.
	local clock = os.clock()
	if clock - (lastSelect[player] or -99) < 1.5 then
		return
	end
	lastSelect[player] = clock
	if not Progress.canPlay(player, styleId) then
		Combat.notice(player, Styles[styleId].name .. " is not on your roster yet.")
		return
	end
	Progress.chose(player, styleId)
	-- Switching mid-fight keeps your health and your place: a new character
	-- is not a free heal. The first pick, or a pick while down, starts fresh.
	local hum = Combat.humanoidOf(player)
	local switching = ps.style ~= nil and hum ~= nil and hum.Health > 0
	ps.baseStyle = nil
	resetCombat(ps)
	Symbiote.reset(ps)
	applyStyle(ps, styleId, switching)
	if not Waves.started then
		-- The first player on a fresh server carries on where they left off:
		-- the furthest world they have opened.
		Waves.start(Progress.startWorld(player))
	end
end)

-- Clients may say which slot and where they are aiming. Everything else is
-- decided here.
local lastCast: { [Player]: number } = {}
Cast.OnServerEvent:Connect(function(player, which, aim)
	local ps = Combat.states[player]
	if not ps then
		return
	end
	local now = os.clock()
	if now - (lastCast[player] or 0) < 0.08 then
		return -- no more than a dozen casts a second from anyone
	end
	lastCast[player] = now
	local okWhich = false
	if which == "ult" then
		okWhich = true
	elseif type(which) == "number" then
		okWhich = which >= 1 and which <= RulesData.MAX_SLOTS and which % 1 == 0
	elseif type(which) == "string" then
		-- A signature (E) action names its technique; only the style's own is allowed.
		okWhich = Signature[ps.style or ""] == which
	end
	-- A direction, finite and roughly unit length. Nothing else is trusted.
	if not okWhich or typeof(aim) ~= "Vector3" or aim.Magnitude ~= aim.Magnitude or aim.Magnitude > 1.5 then
		return
	end
	Abilities.cast(ps, which, aim)
end)

-- A direction, finite and roughly unit length. Nothing else is trusted.
local function okAim(aim: any): boolean
	return typeof(aim) == "Vector3" and aim.Magnitude == aim.Magnitude and aim.Magnitude <= 1.5
end

local lastAction: { [Player]: number } = {}
Action.OnServerEvent:Connect(function(player, name, aim)
	local ps = Combat.states[player]
	if not ps or type(name) ~= "string" then
		return
	end
	-- Letting go of B is never dropped, or a quick tap would leave you charging.
	if name == "chargeEnd" then
		Abilities.releaseCharge(ps)
		return
	end
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.05 then
		return
	end
	lastAction[player] = now
	if name == "strike" then
		if okAim(aim) then
			Abilities.strike(ps, aim)
		end
	elseif name == "chargeStart" then
		Abilities.startCharge(ps)
	elseif name == "cycle" then
		-- Only a set that lives on R (Yuji's); the rest are a technique in a slot.
		local a = ps.style and (Arsenals :: any)[ps.style]
		if a and a.key == "r" then
			Abilities.cycleWeapon(ps)
		end
	elseif name == "rebond" then
		Symbiote.rebond(ps)
	elseif name == "auto" then
		Abilities.toggleAuto(ps)
	elseif name == "dodge" then
		if okAim(aim) then
			Abilities.dodge(ps, aim)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastCast[player] = nil
	lastAction[player] = nil
	lastSelect[player] = nil
end)

-- Progress first, so it hears about every profile, including one that
-- loads instantly (the in-memory store in Studio).
Progress.start()
Story.start()
Profiles.start()

World.load(Config.START_MAP) -- the waves start when the first player picks a character

local thinkAcc = 0
local autoAcc = 0
RunService.Heartbeat:Connect(function(dt)
	Projectiles.step(dt)
	Combat.step(dt)
	Symbiote.step(dt)
	Pickups.step(dt)
	autoAcc += dt
	if autoAcc >= 0.1 then
		Abilities.stepAuto(autoAcc)
		FinaleFight.step()
		autoAcc = 0
	end
	thinkAcc += dt
	if thinkAcc >= Config.ENEMY_THINK_INTERVAL then
		thinkAcc = 0
		Enemies.think()
	end
end)
