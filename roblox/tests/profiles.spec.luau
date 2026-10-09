--!strict
-- Saving and loading against a fake DataStore: the session lock, retries,
-- and that a server which lost the lock can never overwrite newer progress.

local H = require("./harness")
local Progression = require("../src/shared/Progression")
local ProfileStore = require("../src/server/ProfileStore")

print("Profiles")

local clock = 1000
local function server(store: any, job: string, retries: number?): any
	return ProfileStore.new(store, {
		jobId = job,
		reconcile = Progression.reconcile,
		now = function()
			return clock
		end,
		wait = function(s: number)
			clock += s
		end,
		retries = retries or 3,
		lockTimeout = 600,
	})
end

H.test("a new player gets a fresh profile, and it round-trips", function()
	local store = ProfileStore.memory()
	local a = server(store, "A")
	local p = a:load("u1")
	assert(p, "loaded")
	H.eq(p.unlocked.naruto, true, "a starter")
	p.shards = 123
	p.learned.rasengan = true
	H.eq((a:save("u1", p, true)), true, "saved")
	local again = server(store, "B"):load("u1")
	H.eq(again.shards, 123, "shards kept")
	H.eq(again.learned.rasengan, true, "techniques kept")
end)

H.test("a profile held by another live server is waited on, never forced", function()
	local store = ProfileStore.memory()
	local a = server(store, "A")
	local p = a:load("u2")
	p.shards = 50
	a:save("u2", p)
	local start = clock
	local none, why = server(store, "B", 3):load("u2")
	H.eq(none, nil, "B does not take a fresh lock")
	assert(why and string.find(why, "another server"), "and says why")
	assert(clock > start, "it waited first")
	H.eq((a:save("u2", p)), true, "A still holds it and can save")
end)

H.test("a server that lost its lock can never overwrite newer progress", function()
	local store = ProfileStore.memory()
	local a = server(store, "A")
	local p = a:load("u9")
	clock += 601 -- A goes quiet long enough to count as dead
	local q = server(store, "B"):load("u9")
	q.shards = 70
	server(store, "B"):save("u9", q)
	p.shards = 1
	local ok, why = a:save("u9", p)
	H.eq(ok, false, "A's save is refused")
	assert(why, "and says why")
	H.eq(store.data.u9.profile.shards, 70, "B's progress is safe")
end)

H.test("the last save lands while the next server waits, and it gets that save", function()
	local store = ProfileStore.memory()
	local a = server(store, "A")
	local p = a:load("u10")
	p.shards = 88
	-- A's release arrives during B's first wait.
	local b = ProfileStore.new(store, {
		jobId = "B",
		reconcile = Progression.reconcile,
		now = function()
			return clock
		end,
		wait = function(s: number)
			clock += s
			if p then
				a:save("u10", p, true)
				p = nil :: any
			end
		end,
		retries = 3,
		lockTimeout = 600,
	})
	local q = b:load("u10")
	assert(q, "loaded once A let go")
	H.eq(q.shards, 88, "with A's last save")
end)

H.test("a lock from a dead server is taken at once", function()
	local store = ProfileStore.memory()
	server(store, "A"):load("u3")
	clock += 601
	local start = clock
	local p = server(store, "B"):load("u3")
	assert(p, "loaded")
	H.eq(clock, start, "no waiting")
end)

H.test("releasing the lock lets the next server in straight away", function()
	local store = ProfileStore.memory()
	local a = server(store, "A")
	local p = a:load("u4")
	a:save("u4", p, true)
	local start = clock
	assert(server(store, "B"):load("u4"), "loaded")
	H.eq(clock, start, "no waiting")
end)

H.test("store failures are retried, and a store that stays down fails cleanly", function()
	local store = ProfileStore.memory()
	store.failNext = 2
	local p = server(store, "A", 3):load("u5")
	assert(p, "third time lucky")
	store.failNext = 10
	local none, why = server(store, "B", 3):load("u6")
	H.eq(none, nil, "gives up")
	assert(why and string.find(why, "simulated"), "and says why")
	store.failNext = 1
	local a = server(store, "A")
	H.eq((a:save("u5", p)), true, "a failed save is retried")
end)

H.test("an old or broken save is repaired on load", function()
	local store = ProfileStore.memory()
	store.data.u7 = { profile = { xp = 500, shards = -20, unlocked = { toji = true } } }
	local p = server(store, "A"):load("u7")
	H.eq(p.xp, 500, "experience kept")
	H.eq(p.shards, 0, "never negative")
	H.eq(p.unlocked.toji, true, "unlock kept")
	H.eq(p.unlocked.spiderman, true, "starters added")
end)

H.test("saving writes a copy, not the live table", function()
	local store = ProfileStore.memory()
	local a = server(store, "A")
	local p = a:load("u8")
	p.shards = 10
	a:save("u8", p)
	p.shards = 999
	H.eq(store.data.u8.profile.shards, 10, "unchanged until the next save")
end)

return H
