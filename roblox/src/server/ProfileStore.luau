--!strict
-- Loading and saving profiles with a session lock, over anything that has a
-- DataStore's UpdateAsync. No Roblox services and no requires in here: the
-- store, the clock, the wait, the server's id and the profile's reconcile are
-- passed in, so the locking and retry rules
-- run under Lune against a fake store (tests/profiles.spec.luau).
--
-- The lock stops two servers writing the same player at once (they joined a
-- second server before the first one saved them out). A server that finds a
-- fresh lock from another server waits and tries again; a lock older than
-- `lockTimeout` belongs to a server that died and is taken over. A save only
-- writes while this server still holds the lock, so a stale server can never
-- roll a player's progress back.

export type Store = {
	UpdateAsync: (self: any, key: string, fn: (old: any, info: any) -> any) -> any,
}

export type Options = {
	jobId: string,
	reconcile: (saved: any) -> any, -- brings a saved profile up to date (Progression.reconcile)
	now: () -> number,
	wait: (seconds: number) -> (),
	lockTimeout: number?, -- seconds before another server's lock counts as dead
	retries: number?,
	warn: ((string) -> ())?,
}

export type ProfileStore = {
	store: Store,
	opts: Options,
	load: (self: ProfileStore, key: string) -> (any?, string?),
	save: (self: ProfileStore, key: string, profile: any, release: boolean?) -> (boolean, string?),
}

local ProfileStore = {}

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end
ProfileStore.deepCopy = deepCopy

--- An in-memory stand-in with the same UpdateAsync contract: the callback gets
--- a copy, and returning nil leaves the stored value alone. Used in Studio when
--- the place has no access to DataStores, and by the tests.
function ProfileStore.memory(): Store & { data: { [string]: any }, failNext: number }
	local m = { data = {}, failNext = 0 }
	function m.UpdateAsync(self: any, key: string, fn: (any, any) -> any): any
		if self.failNext > 0 then
			self.failNext -= 1
			error("simulated DataStore failure")
		end
		local new = fn(deepCopy(self.data[key]), nil)
		if new ~= nil then
			self.data[key] = deepCopy(new)
		end
		return new
	end
	return m :: any
end

function ProfileStore.new(store: Store, opts: Options): ProfileStore
	local self = { store = store, opts = opts } :: any
	local timeout = opts.lockTimeout or 1800
	local retries = opts.retries or 5
	local warnf = opts.warn or function(_: string) end

	--- Reads a profile and takes its lock. Returns nil and a reason if the store
	--- keeps failing, or if another server still holds a fresh lock after every
	--- retry. A fresh lock is never forced: its server may still be writing
	--- the player's last save, and loading before it lands would lose that
	--- progress or let a reward be claimed twice.
	function self.load(this: ProfileStore, key: string): (any?, string?)
		local lastErr = "unknown"
		for attempt = 1, retries do
			local loaded: any? = nil
			local blocked = false
			local ok, err = pcall(function()
				this.store:UpdateAsync(key, function(old: any)
					local data = if type(old) == "table" then old else {}
					local lock = data.lock
					local now = opts.now()
					if
						type(lock) == "table"
						and lock.job ~= opts.jobId
						and now - (tonumber(lock.time) or 0) < timeout
					then
						blocked = true
						return nil
					end
					blocked = false
					data.profile = opts.reconcile(data.profile)
					data.lock = { job = opts.jobId, time = now }
					loaded = data.profile
					return data
				end)
			end)
			if ok and loaded then
				return loaded, nil
			end
			lastErr = if ok then "held by another server" else tostring(err)
			if not ok then
				warnf(`Profile {key}: load attempt {attempt} failed: {lastErr}`)
			end
			if attempt < retries then
				opts.wait(if blocked then 2 else math.min(8, 2 ^ (attempt - 1)))
			end
		end
		return nil, lastErr
	end

	--- Writes a profile, if this server still holds its lock. `release` drops
	--- the lock (the player left). Retries a failed write a few times.
	function self.save(this: ProfileStore, key: string, profile: any, release: boolean?): (boolean, string?)
		local copy = deepCopy(profile)
		local lastErr = "unknown"
		for attempt = 1, 3 do
			local stolen = false
			local ok, err = pcall(function()
				this.store:UpdateAsync(key, function(old: any)
					local data = if type(old) == "table" then old else {}
					local lock = data.lock
					if type(lock) == "table" and lock.job ~= opts.jobId then
						stolen = true
						return nil
					end
					data.profile = copy
					data.lock = if release then nil else { job = opts.jobId, time = opts.now() }
					return data
				end)
			end)
			if ok then
				if stolen then
					return false, "another server holds this profile"
				end
				return true, nil
			end
			lastErr = tostring(err)
			warnf(`Profile {key}: save attempt {attempt} failed: {lastErr}`)
			if attempt < 3 then
				opts.wait(attempt)
			end
		end
		return false, lastErr
	end

	return self
end

return ProfileStore
