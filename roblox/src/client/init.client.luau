--!strict
-- Dimensional Rift, client. Builds the screens and listens.

local Hud = require(script.Hud)
local Select = require(script.Select)
local Fx = require(script.Fx)
local Hub = require(script.Hub)
local Loadout = require(script.Loadout)
local Input = require(script.Input)
local Tips = require(script.Tips)

Hud.build()
Select.build()
Hub.build()
Loadout.build()
Hud.onMenu = Hub.toggle
Fx.start()
Input.start()
Select.show() -- nobody spawns until they have picked someone
Tips.start()
