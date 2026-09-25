--!strict
-- Story mode: The Hundred Seams.
--
-- Nuime, the Stitched One, has never had a body of his own. He opened the
-- rift to sew every world into one body that would last him forever, and
-- each world's boss ladder guards one of his stitches. Beat the ladder and the
-- stitch comes loose. Break all nine and the Seam opens: the tenth world,
-- where he waits stitched to Patchwork as Hyakunui, the Hundred-Seam.
--
-- Plain data, no Roblox: a card when a world opens, a line after some waves,
-- a line when its last boss falls, and the ending. The server sends them
-- (src/server/Story.luau); the client shows them (src/client/StoryUi.luau).

export type Line = { speaker: string, text: string }
export type Chapter = {
	chapter: string, -- "Stitch 1 of 9"
	intro: string, -- the world card
	lines: { [number]: Line }, -- after wave N is cleared
	cleared: Line, -- when the world's last boss falls
}

local Story = {}

Story.FINAL = "the_seam"

Story.CHAPTERS = {
	times_square = {
		chapter = "Stitch 1 of 9",
		intro = "The rift opened over the plaza and has not closed since. Whatever came through is still coming. Whoever you were before, this is the body you arrived in.",
		lines = {
			[3] = {
				speaker = "Aoi Hakumei",
				text = "You can see it too? That line in the sky. That is not a crack. That is a seam.",
			},
			[7] = {
				speaker = "Aoi Hakumei",
				text = "Kazan and Thornbloom came through first. Curses do not travel. Something carried them.",
			},
		},
		cleared = {
			speaker = "Aoi Hakumei",
			text = "Did you feel that? Something let go when the last one fell. Someone is sewing the worlds together, and you just pulled a stitch.",
		},
	},
	jujutsu_high = {
		chapter = "Stitch 2 of 9",
		intro = "The academy on the edge of the city still stands. Sorcerers, shinobi and strays alike are sheltering behind its wards, for now.",
		lines = {
			[4] = {
				speaker = "Overtime",
				text = "Every stitch is anchored in a fighter. Beat the anchor, the thread goes slack. That is the job. It does not pay enough.",
			},
			[8] = {
				speaker = "Overtime",
				text = "Doctor Eightfold is holding one down. Take him apart. I clock off when this is done.",
			},
		},
		cleared = { speaker = "Overtime", text = "Two loose. Whoever is doing the sewing will have noticed by now." },
	},
	star_corridor = {
		chapter = "Stitch 3 of 9",
		intro = "Beneath the academy, the Ribbed Vault, a tomb under the stars. Something down here has been reading very old names.",
		lines = {
			[3] = {
				speaker = "???",
				text = "Such a lovely body you have borrowed. I have worn better. I will wear better still.",
			},
			[6] = {
				speaker = "Aoi Hakumei",
				text = "His name is Nuime. A thousand years old and he has never once lived in his own skin. The rift is his needle.",
			},
		},
		cleared = {
			speaker = "Nuime",
			text = "Pull all the threads you like. I have a hundred more, and nothing but time.",
		},
	},
	kyoto_academy = {
		chapter = "Stitch 4 of 9",
		intro = "The sister school has chosen a side. Its elders say a world stitched together is a world at peace. They have been promised a place in it.",
		lines = {
			[4] = { speaker = "Kotodama", text = "They are not listening. They never listen. Stop. Stop. STOP." },
			[8] = {
				speaker = "Overtime",
				text = "Zero has been seen near the seam. He does not care who wins. He cares who pays.",
			},
		},
		cleared = {
			speaker = "Antidote",
			text = "The Walled Compound's stitch is out. The elders will not forgive you. The rest of us might.",
		},
	},
	culling_colony = {
		chapter = "Stitch 5 of 9",
		intro = "The Sealed Block: a points game, a city block fenced in, fighters thrown at each other. The points were never for the players. They are Nuime's harvest.",
		lines = {
			[3] = {
				speaker = "Patchwork",
				text = "Every soul you send through the seam, I get to hold for a moment. Shape it. Keep going. Please.",
			},
			[7] = {
				speaker = "Threadrunner",
				text = "Patchwork is feeding him. Every fighter who falls in here becomes thread.",
			},
		},
		cleared = { speaker = "Threadrunner", text = "The Block is down. Nobody else gets turned into string. Not today." },
	},
	land_of_wind = {
		chapter = "Stitch 6 of 9",
		intro = "Dunewatch, a caravan fort half buried in sand that fell from another sky. The Vessel was seen here. So was the king he carries.",
		lines = {
			[3] = {
				speaker = "Blackmaw",
				text = "We can smell him. The one with the king inside. The needle-man wants that body. WE want that body.",
			},
			[6] = {
				speaker = "Haru Takane",
				text = "Akuro is not a passenger. He is a lock. If Nuime gets him out of me, he gets everything.",
			},
		},
		cleared = {
			speaker = "Akuro",
			text = "The stitched fool wants my body? Let him come and ask for it. I will answer.",
		},
	},
	land_of_earth = {
		chapter = "Stitch 7 of 9",
		intro = "Quarry Hollow. Someone has been selling curses here by the thousand, and the buyer always pays in stitches.",
		lines = {
			[4] = { speaker = "Zero", text = "Nothing personal. Nuime paid first. You can outbid him, if you live." },
			[8] = {
				speaker = "Hoshiro Genma",
				text = "Every curse you have fought, I sold. I collect. He sews. Business is business.",
			},
		},
		cleared = {
			speaker = "Aoi Hakumei",
			text = "Seven. The seam is fraying now; you can see it in the sky from anywhere.",
		},
	},
	land_of_water = {
		chapter = "Stitch 8 of 9",
		intro = "Mistreach, a stilt village in a grey sea. Nuime has come to hold this stitch himself.",
		lines = {
			[3] = {
				speaker = "Nuime",
				text = "You are very good at unpicking things. Let us see how you are at being unpicked.",
			},
			[7] = {
				speaker = "Akagane",
				text = "Blood remembers where it came from. His does not. He has been too many people.",
			},
		},
		cleared = {
			speaker = "Nuime",
			text = "Enough. Patchwork, come. We will not hold the thread. We will BECOME it.",
		},
	},
	land_of_lightning = {
		chapter = "Stitch 9 of 9",
		intro = "Thunderspire, a monastery in the storm. Kazan, Thornbloom and Tidehollow guard the last stitch, the one that holds the Seam shut.",
		lines = {
			[3] = {
				speaker = "Kazan",
				text = "You think you are saving the worlds. We are nature. Stitched or torn, we remain.",
			},
			[6] = {
				speaker = "Thornbloom",
				text = "Every stitch you tear, the worlds bleed a little. Is that what you wanted?",
			},
		},
		cleared = {
			speaker = "Aoi Hakumei",
			text = "That was the last one. The Seam is open. Whatever is on the other side is waiting for you. Travel there when you are ready.",
		},
	},
	the_seam = {
		chapter = "The Seam",
		intro = "The space between every world, stitched shut with a hundred threads. At its centre, Nuime and Patchwork have sewn themselves into one thing: Hyakunui, the Hundred-Seam.",
		lines = {
			[1] = {
				speaker = "Hyakunui",
				text = "Everything you fought was a thread of me. Everything you are will be one.",
			},
			[2] = { speaker = "Aoi Hakumei", text = "Its seams show before it cuts. Watch the ground, and move." },
		},
		cleared = { speaker = "Aoi Hakumei", text = "It's coming apart. All of it. Hold on." },
	},
}

-- What the boss says at each phase, and its phase names.
Story.PHASES = {
	{ banner = "HYAKUNUI", text = "The Hundred-Seam opens its eyes." },
	{
		banner = "THE TEMPEST FOX AND THE UNBIDDEN",
		text = "It tears two things from its own stitching. The Unbidden learns: change how you hit it.",
	},
	{ banner = "THE LAST SEAM", text = "It reaches for bodies now. Don't be where its grasp lands." },
}

Story.ENDING = {
	title = "THE RIFT IS CLOSED",
	text = "The Hundred-Seam comes undone thread by thread, and the worlds slide back to where they belong. The sky over the plaza is just sky.",
}

-- A last line for the universe of the character who closed it.
Story.EPILOGUE = {
	naruto = "In the Shinobi Lands the villages count their missing, and find them all coming home.",
	jjk = "At the academy the wards hold, and for the first time in a long time nobody is on watch.",
	marvel = "Skyline City wakes to headlines about a portal that was never there. Somebody swings home.",
	other = "Nobody from Elsewhere has a home to go back to. You stay. The rift left a door, and you keep it.",
} :: { [string]: string }

Story.POSTGAME =
	"Loose threads remain. Every world is harder now, and pays better. The rift may be closed, but it remembers you."

return Story
