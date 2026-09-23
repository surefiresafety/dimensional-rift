--!strict
-- Every client/server message goes through one of these. The server creates
-- them at startup; clients wait for them.
--
--   Client -> server
--     SelectStyle(styleId)                  pick a character
--     Cast(slotIndex | "ult", aimDirection) use a technique
--   Server -> client
--     Cooldown(skillId, readyAt, duration)  readyAt is workspace:GetServerTimeNow()
--     Fx(kind, payload)                     something to draw
--     Notice(text, tone?)                   a line for the combat log
--     Wave(mapId, waveNumber, enemiesLeft)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "SelectStyle", "Cast", "Cooldown", "Fx", "Notice", "Wave" }

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
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

return Remotes
