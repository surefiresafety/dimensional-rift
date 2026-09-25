--!strict
-- Tells the story (Shared.Story) as the rift moves: a card when a world opens,
-- a line after certain waves, and a line when a world's last boss falls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local StoryData = require(Shared.Story)
local Worlds = require(Shared.Worlds)

local Waves = require(script.Parent.Waves)

local StoryRemote = Remotes.get("Story")

local Story = {}

function Story.start()
	Waves.onStarted(function(mapId)
		local ch = StoryData.CHAPTERS[mapId]
		local map = Worlds.get(mapId)
		if not ch or not map then
			return
		end
		StoryRemote:FireAllClients("card", {
			chapter = if Waves.tier > 1 then ch.chapter .. "  ·  LOOSE THREADS" else ch.chapter,
			title = map.name,
			sub = map.sub,
			text = if Waves.tier > 1 then StoryData.POSTGAME else ch.intro,
		})
	end)
	Waves.onCleared(function(mapId, n)
		local ch = StoryData.CHAPTERS[mapId]
		local line = ch and ch.lines[n]
		if line and Waves.tier == 1 then
			StoryRemote:FireAllClients("line", line)
		end
	end)
	Waves.onWorldCleared(function(mapId)
		local ch = StoryData.CHAPTERS[mapId]
		if ch and Waves.tier == 1 then
			StoryRemote:FireAllClients("line", ch.cleared)
		end
	end)
end

return Story
