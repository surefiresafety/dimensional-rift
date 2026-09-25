--!strict
-- Every player's saved profile: loaded when they join, saved every minute and
-- a half, when they leave, and when the server shuts down. The locking and
-- retry rules are in ProfileStore; this file points them at DataStoreService.
--
-- In Studio, saving only works with Game Settings > Security > "Enable Studio
-- Access to API Services" turned on. Without it this falls back to a store
-- that lives in memory for the session, and says so in the output.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Progression)

local ProfileStore = require(script.Parent.ProfileStore)

local STORE_NAME = "RiftProfiles_v1"
local AUTOSAVE_EVERY = 90

local Profiles = {}
Profiles.persistent = true -- false when running on the in-memory fallback

local function openStore(): ProfileStore.Store
	local ok, store = pcall(function()
		local s = DataStoreService:GetDataStore(STORE_NAME)
		-- GetDataStore succeeds in Studio even without access; a read does not.
		s:GetAsync("__probe")
		return s
	end)
	if ok then
		return store :: any
	end
	Profiles.persistent = false
	warn(
		"[Profiles] DataStores are not available ("
			.. tostring(store)
			.. "). Progress will last for this session only. In Studio: Game Settings > Security > Enable Studio Access to API Services."
	)
	return ProfileStore.memory()
end

local store = ProfileStore.new(openStore(), {
	jobId = if RunService:IsStudio() then "studio-" .. HttpService:GenerateGUID(false) else game.JobId,
	reconcile = Progression.reconcile,
	now = os.time,
	wait = function(s: number)
		task.wait(s)
	end,
	warn = function(msg: string)
		warn("[Profiles] " .. msg)
	end,
})

local loaded: { [Player]: Progression.Profile } = {}
local loading: { [Player]: boolean } = {}
local loadedHandlers: { (Player, Progression.Profile) -> () } = {}
local savingHandlers: { (Player, Progression.Profile) -> () } = {}

local function keyOf(player: Player): string
	return "u" .. player.UserId
end

--- The player's profile, or nil while it is still loading (or failed).
function Profiles.get(player: Player): Progression.Profile?
	return loaded[player]
end

function Profiles.onLoaded(fn: (Player, Progression.Profile) -> ())
	table.insert(loadedHandlers, fn)
end

--- Runs just before every save: the place to copy live numbers into it.
function Profiles.onSaving(fn: (Player, Progression.Profile) -> ())
	table.insert(savingHandlers, fn)
end

local function beforeSave(player: Player, profile: Progression.Profile)
	for _, fn in savingHandlers do
		local ok, err = pcall(function()
			fn(player, profile)
		end)
		if not ok then
			warn("[Profiles] onSaving handler failed: " .. tostring(err))
		end
	end
end

function Profiles.save(player: Player, release: boolean?): boolean
	local profile = loaded[player]
	if not profile then
		return false
	end
	beforeSave(player, profile)
	local ok, err = store:save(keyOf(player), profile, release)
	if not ok then
		warn(`[Profiles] could not save {player.Name}: {err}`)
	end
	return ok
end

local function load(player: Player)
	if loading[player] or loaded[player] then
		return
	end
	loading[player] = true
	local profile, err = store:load(keyOf(player))
	loading[player] = nil
	if not player.Parent then
		-- They left while it loaded: give the lock straight back.
		if profile then
			store:save(keyOf(player), profile, true)
		end
		return
	end
	if not profile then
		warn(`[Profiles] could not load {player.Name}: {err}`)
		player:Kick("Your save could not be loaded right now. Please rejoin in a minute; nothing has been lost.")
		return
	end
	loaded[player] = profile
	for _, fn in loadedHandlers do
		task.spawn(fn, player, profile)
	end
end

function Profiles.start()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		if loaded[player] then
			Profiles.save(player, true)
			loaded[player] = nil
		end
	end)
	-- Autosave, spread out so a full server does not save everyone at once.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_EVERY)
			for player in table.clone(loaded) do
				if player.Parent and loaded[player] then
					task.spawn(Profiles.save, player, false)
					task.wait(0.5)
				end
			end
		end
	end)
	-- Shutdown: save everyone left, in parallel, and wait for all of them.
	game:BindToClose(function()
		local pending = 0
		for player in table.clone(loaded) do
			pending += 1
			task.spawn(function()
				Profiles.save(player, true)
				loaded[player] = nil
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- Global boards --------------------------------------------------------------

export type BoardRow = { rank: number, name: string, value: number, userId: number }

local boards: { [string]: OrderedDataStore? } = {}
local boardCache: { [string]: { at: number, rows: { BoardRow } } } = {}
local nameCache: { [number]: string } = {}
local lastPosted: { [string]: { [number]: number } } = {}

local function board(name: string): OrderedDataStore?
	if boards[name] == nil and Profiles.persistent then
		local ok, s = pcall(function()
			return DataStoreService:GetOrderedDataStore(name)
		end)
		boards[name] = if ok then s else nil
	end
	return boards[name]
end

--- Posts a player's value to a board, if it changed since the last post.
function Profiles.post(boardName: string, userId: number, value: number)
	local posted = lastPosted[boardName] or {}
	lastPosted[boardName] = posted
	if posted[userId] == value then
		return
	end
	local b = board(boardName)
	if not b then
		return
	end
	posted[userId] = value
	task.spawn(function()
		local ok, err = pcall(function()
			(b :: OrderedDataStore):SetAsync(tostring(userId), math.floor(value))
		end)
		if not ok then
			posted[userId] = nil
			warn(`[Profiles] could not post to {boardName}: {err}`)
		end
	end)
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local n = if ok and name then name else "Player " .. userId
	nameCache[userId] = n
	return n
end

--- The top ten on a board, cached for two minutes. Empty without DataStores.
function Profiles.top(boardName: string): { BoardRow }
	local c = boardCache[boardName]
	if c and os.clock() - c.at < 120 then
		return c.rows
	end
	local b = board(boardName)
	if not b then
		return {}
	end
	local rows: { BoardRow } = {}
	local ok, err = pcall(function()
		local page = (b :: OrderedDataStore):GetSortedAsync(false, 10):GetCurrentPage()
		for i, entry in page do
			local id = tonumber(string.match(entry.key, "%d+")) or 0
			table.insert(rows, { rank = i, name = nameOf(id), value = entry.value, userId = id })
		end
	end)
	if not ok then
		warn(`[Profiles] could not read {boardName}: {err}`)
		return if c then c.rows else {}
	end
	boardCache[boardName] = { at = os.clock(), rows = rows }
	return rows
end

return Profiles
