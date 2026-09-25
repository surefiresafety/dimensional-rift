--!strict
-- Every client/server message goes through one of these. The server creates
-- them at startup; clients wait for them.
--
--   Client -> server
--     SelectStyle(styleId)                  pick a character
--     Cast(slotIndex | "ult", aimDirection) use a technique
--     Action(name, aimDirection?)           everything that is not a technique:
--                                           "strike" (basic attack), "chargeStart"
--                                           and "chargeEnd" (B), "cycle" (R, for a
--                                           weapon set on R), "rebond" (F)
--   Server -> client
--     Cooldown(skillId, readyAt, duration)  readyAt is workspace:GetServerTimeNow()
--     Fx(kind, payload)                     something to draw
--     Notice(text, tone?)                   a line for the combat log
--     Wave(mapId, waveNumber, enemiesLeft)
--     Profile(snapshot)                     the player's progress (Progress.snapshot)
--   Client -> server, with an answer (RemoteFunction)
--     Ask(action, ...) -> { ok, message?, ... }
--                                           claimDaily, claimQuest(i), rerollQuest(i),
--                                           buy(styleId), loadout(styleId, slots),
--                                           board(name)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "SelectStyle", "Cast", "Action", "Cooldown", "Fx", "Notice", "Wave", "Profile" }
local FUNCTIONS = { "Ask" }

local Remotes = {}

local function folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		for _, name in NAMES do
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = f
		end
		for _, name in FUNCTIONS do
			local e = Instance.new("RemoteFunction")
			e.Name = name
			e.Parent = f
		end
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Remotes.fn(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

return Remotes
