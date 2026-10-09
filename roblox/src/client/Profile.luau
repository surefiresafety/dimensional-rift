--!strict
-- This player's progress as the server last described it, and one way to ask
-- the server for things. Every screen that shows progress reads from here and
-- redraws on `changed`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Profile = {}

--- The latest snapshot (Progress.snapshot on the server), or nil until the
--- save has loaded.
Profile.data = nil :: { [string]: any }?

local changedEvent = Instance.new("BindableEvent")
--- Fires with (new, old) every time a snapshot arrives.
Profile.changed = changedEvent.Event

local AskRemote = Remotes.fn("Ask")

Remotes.get("Profile").OnClientEvent:Connect(function(snapshot: any)
	local old = Profile.data
	Profile.data = snapshot
	changedEvent:Fire(snapshot, old)
end)

export type Answer = { ok: boolean, message: string?, [string]: any }

--- Asks the server to do something. Never errors: a failed call comes back
--- as { ok = false, message = ... }.
function Profile.ask(action: string, a: any?, b: any?): Answer
	local ok, result = pcall(function()
		return AskRemote:InvokeServer(action, a, b)
	end)
	if not ok or type(result) ~= "table" then
		return { ok = false, message = "The server did not answer. Try again." }
	end
	return result :: Answer
end

-- In case the first snapshot went out before anything here was listening.
task.spawn(function()
	for _ = 1, 20 do
		if Profile.data then
			return
		end
		local r = Profile.ask("sync")
		if r.ok then
			return
		end
		task.wait(1.5) -- still loading
	end
end)

function Profile.has(styleId: string): boolean
	local d = Profile.data
	return d ~= nil and table.find(d.unlocked, styleId) ~= nil
end

--- Rift Shards, formatted with thousands separators.
function Profile.shards(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

return Profile
