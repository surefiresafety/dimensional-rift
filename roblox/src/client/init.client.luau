--!strict
-- Dimensional Rift, client. Builds the screens and listens.

local Hud = require(script.Hud)
local Select = require(script.Select)
local Fx = require(script.Fx)
local Input = require(script.Input)

Hud.build()
Select.build()
Fx.start()
Input.start()
Select.show() -- nobody spawns until they have picked someone
