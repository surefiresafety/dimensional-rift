--!strict
-- The E key. Movement signatures (swing, fly) run on the client, which owns its
-- character's physics; the rest cast one technique, named here. The server
-- only accepts an E cast that matches this table.

return {
	naruto = "rasengan_n",
	sasuke = "chidori",
	yuji = "dismantle_s",
	megumi = "chimera_garden",
} :: { [string]: string }
