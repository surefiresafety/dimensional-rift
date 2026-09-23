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

local Combat = require(script.Combat)
local Abilities = require(script.Abilities)
local Projectiles = require(script.Projectiles)
local Enemies = require(script.Enemies)
local Waves = require(script.Waves)
local World = require(script.World)
local Looks = require(script.Looks)
local Signature = require(Shared.Signature)

-- Create every remote before anyone can ask for one.
local SelectStyle = Remotes.get("SelectStyle")
local Cast = Remotes.get("Cast")

Players.CharacterAutoLoads = false -- a character is chosen before anyone spawns

--- Puts a player into a style: its kit, its energy, its body.
local function applyStyle(ps: Combat.PState, styleId: string, keepHealth: boolean?)
	local st = Styles[styleId]
	ps.style = styleId
	ps.slots = table.clone(st.slots)
	ps.maxSe = st.energy or Config.PLAYER_MAX_SE
	ps.se = math.min(ps.se, ps.maxSe)
	if ps.maxSe == math.huge then
		ps.se = math.huge
	end
	for _, id in st.pool do
		ps.learned[id] = true
	end
	local hum = Combat.humanoidOf(ps.player)
	local hp = if hum and keepHealth then hum.Health else nil
	Looks.dressPlayer(ps.player, styleId)
	local newHum = Combat.humanoidOf(ps.player)
	local root = Combat.rootOf(ps.player)
	if newHum then
		newHum.MaxHealth = Config.PLAYER_MAX_HP
		newHum.Health = hp or Config.PLAYER_MAX_HP
		newHum.WalkSpeed = Config.WALK_SPEED
	end
	if root and not keepHealth then
		root.CFrame = CFrame.new(World.spawnPoint())
	end
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
Combat.revert = function(ps)
	transform(ps, nil)
end

Players.PlayerAdded:Connect(function(player)
	Combat.newState(player)
	player.CharacterAdded:Connect(function(character)
		local hum = character:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			-- Rise again as the same character after a beat.
			task.delay(4, function()
				local ps = Combat.states[player]
				if ps and ps.style and player.Parent then
					ps.baseStyle = nil
					ps.buff, ps.domain, ps.minions = nil, nil, {}
					applyStyle(ps, ps.style)
				end
			end)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	Combat.states[player] = nil
end)

SelectStyle.OnServerEvent:Connect(function(player, styleId)
	local ps = Combat.states[player]
	if not ps or type(styleId) ~= "string" or not Styles[styleId] then
		return
	end
	ps.baseStyle = nil
	applyStyle(ps, styleId)
	if not Waves.running then
		Waves.start(Config.START_MAP)
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

World.load(Config.START_MAP) -- the waves start when the first player picks a character

local thinkAcc = 0
RunService.Heartbeat:Connect(function(dt)
	Projectiles.step(dt)
	Combat.step(dt)
	thinkAcc += dt
	if thinkAcc >= Config.ENEMY_THINK_INTERVAL then
		thinkAcc = 0
		Enemies.think()
	end
end)
