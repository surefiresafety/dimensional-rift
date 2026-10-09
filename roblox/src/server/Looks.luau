--!strict
-- Turns a look into a Roblox body (docs/design/characters.md §1.2, §6.2).
--
-- Players and character bosses read only Costumes.effectiveLook (STYLE); human enemies read
-- their EnemyLooks row through Creatures.humanColors; finale bosses read Finale.BODY. The R15
-- description carries the six colours and the §1.2 proportion preset; everything else (face,
-- markers, kit pieces, props) is mounted by Kit through Looks.dress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Costumes = require(Shared.Costumes) :: any

local Kit = require(script.Parent.Kit) :: any
local Creatures = require(script.Parent.Kit.Creatures) :: any
local Finale = require(script.Parent.Kit.Finale) :: any

local Looks = {}

--- styleId -> catalog asset ids. Optional; nothing reads data hair for a player any more.
-- optional Creator Store asset here: ACCESSORIES[styleId].hair = "<id>"
Looks.ACCESSORIES = {} :: { [string]: { hair: string?, hat: string?, face: number? } }

export type Preset = {
	WidthScale: number,
	DepthScale: number,
	HeadScale: number,
	BodyTypeScale: number,
	ProportionScale: number,
}

--- §1.2 proportion presets.
Looks.PRESETS = {
	lean = { WidthScale = 0.88, DepthScale = 0.9, HeadScale = 1.0, BodyTypeScale = 0.3, ProportionScale = 0.6 },
	standard = { WidthScale = 1.0, DepthScale = 1.0, HeadScale = 1.0, BodyTypeScale = 0.2, ProportionScale = 0.3 },
	heavy = { WidthScale = 1.25, DepthScale = 1.15, HeadScale = 0.9, BodyTypeScale = 0.1, ProportionScale = 0.0 },
	small = { WidthScale = 0.95, DepthScale = 0.95, HeadScale = 1.35, BodyTypeScale = 0.0, ProportionScale = 0.0 },
	towering = { WidthScale = 1.1, DepthScale = 1.0, HeadScale = 0.8, BodyTypeScale = 0.5, ProportionScale = 1.0 },
} :: { [string]: Preset }

--- The old data path, kept for anything outside the costume system (never players or bosses).
function Looks.lookFor(styleId: string?): { [string]: any }
	local Characters = require(Shared.Data.Characters) :: any
	return (styleId and Characters[styleId]) or Characters.default
end

--- A HumanoidDescription for `look`:
---   an effectiveLook (has `body`): STYLE colours and limbs, its preset and height;
---   a Finale.BODY row (colors keyed Head/Torso/...): its preset and scale overrides;
---   otherwise a human-enemy look: today's bare/sleeves rules, look.height, look.headScale
---   clamped to 0.8–1.1, banned flags dropped.
function Looks.description(look: { [string]: any }, preset: string?): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local human = false
	local six: { [string]: number }
	if type(look.body) == "table" then
		six = look.body
	elseif type(look.colors) == "table" and look.colors.Head ~= nil then
		six = look.colors
	else
		human = true
		look = Costumes.dropBanned(look)
		local skin = look.skin or 0xd8c0b0
		local top = if look.bare then skin else (look.top or 0x2a2f45)
		local arms = look.sleeves or (if look.bare then skin else top)
		local legs = look.bottom or 0x24242c
		six = { Head = skin, Torso = top, LeftArm = arms, RightArm = arms, LeftLeg = legs, RightLeg = legs }
	end
	local function col(k: string, fallback: number): Color3
		local c = six[k]
		return Palette.color(if type(c) == "number" then c else fallback)
	end
	local grey = 0x8a8a90
	d.HeadColor = col("Head", grey)
	d.TorsoColor = col("Torso", grey)
	d.LeftArmColor = col("LeftArm", grey)
	d.RightArmColor = col("RightArm", grey)
	d.LeftLegColor = col("LeftLeg", grey)
	d.RightLegColor = col("RightLeg", grey)

	local p = Looks.PRESETS[preset or look.preset or "standard"] or Looks.PRESETS.standard
	d.HeightScale = look.heightScale or look.height or 1
	d.WidthScale = look.widthScale or p.WidthScale
	d.DepthScale = look.depthScale or p.DepthScale
	d.HeadScale = p.HeadScale
	if type(look.headScale) == "number" then
		d.HeadScale = if human then math.clamp(look.headScale, 0.8, 1.1) else look.headScale
	end
	d.BodyTypeScale = p.BodyTypeScale
	d.ProportionScale = p.ProportionScale
	local extra = look.styleId and Looks.ACCESSORIES[look.styleId]
	if extra then
		d.HairAccessory = extra.hair or ""
		d.HatAccessory = extra.hat or ""
	end
	return d
end

--- A fallback hair for a look that carries no kit (§6.2): a cap plus at most one extra, at +Z,
--- mounted through Kit (Weld C0, ellipsoids). Skipped under FM or HD. Players and bosses never
--- come here: their hair is STYLE kit entries.
function Looks.dressHair(model: Model, look: { [string]: any })
	if look.hairStyle == "none" or look.mask or not model:FindFirstChild("Head") then
		return
	end
	local rig = Kit.rig(model)
	if rig.worn.FM or rig.worn.HD then
		return
	end
	local tint = look.hair or 0x1a1a22
	local entries: { any } = { { "HR", tint = tint } }
	local style = look.hairStyle
	if style == "spiky" then
		table.insert(entries, { "HR·s", n = 3, tint = tint })
	elseif style == "long" or style == "ponytail" or style == "bun" then
		table.insert(entries, { "HR·p", tint = tint })
	end
	local b = Kit.new(model, 4)
	for _, e in entries do
		Kit.mountEntry(b, rig, e, { colors = { hair = tint } }, "R")
	end
end

export type DressOpts = {
	styleId: string?,
	enemyId: string?,
	role: string,
	grade: any?,
	faction: string?,
	pal: any?,
	budget: number?,
	t: any?,
	affix: any?,
	stitched: boolean?,
	mapId: string?,
	seed: number?,
}

--- Dresses a built model: destroys Head.face, mounts FP and the face, markers, then the kit by
--- tier, and paints (Kit.build / Creatures.dress / Finale.dress). Returns the parts used.
function Looks.dress(model: Model, look: { [string]: any }?, opts: DressOpts): number
	local head = model:FindFirstChild("Head")
	local decal = head and head:FindFirstChild("face")
	if decal then
		decal:Destroy()
	end
	local role = opts.role
	if role == "finale" then
		return (Finale.dress(model, opts.enemyId or "", { t = opts.t, pal = opts.pal, budget = opts.budget }))
	end
	if (role == "player" or role == "ally") and opts.styleId then
		local l = look or Costumes.effectiveLook(opts.styleId, "player")
		return (Kit.build(model, l, { role = role, styleId = opts.styleId, budget = opts.budget }))
	end
	return (
		Creatures.dress(model, {
			enemyId = opts.enemyId,
			role = role,
			t = opts.t,
			pal = opts.pal,
			affix = opts.affix,
			stitched = opts.stitched,
			budget = opts.budget,
			mapId = opts.mapId,
			seed = opts.seed,
			grade = opts.grade,
		})
	)
end

--------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------

type PlayerState = { conns: { RBXScriptConnection }, suit: boolean, weapon: string? }
local playerState: { [Model]: PlayerState } = setmetatable({}, { __mode = "k" }) :: any
local playerConns: { [Player]: { RBXScriptConnection } } = {}

local function disconnect(list: { RBXScriptConnection }?)
	if list then
		for _, c in list do
			c:Disconnect()
		end
	end
end

local function weaponOf(character: Model): string?
	local w = character:GetAttribute("Weapon")
	return if type(w) == "string" then w else nil
end

local function isSuitKey(styleId: string, key: string?): boolean
	local props = key and Costumes.ARSENAL_PROP[styleId]
	local spec = props and props[key :: string]
	return spec ~= nil and spec.suit == true
end

--- The suit key (ironman) worn, else nil: only `suit=true` keys change the body.
local function suitKey(styleId: string, key: string?): string?
	return if isSuitKey(styleId, key) then key else nil
end

--- Re-dresses a character in place (a suit Weapon key): ApplyDescription, then Costume, FP
--- and paint again (ApplyDescription resets part colours). Never runs on a Suit change.
function Looks.redress(character: Model)
	local styleId = character:GetAttribute("StyleId")
	if type(styleId) ~= "string" then
		return
	end
	local look = Costumes.effectiveLook(styleId, "player", nil, suitKey(styleId, weaponOf(character)))
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum:ApplyDescriptionAsync(Looks.description(look))
		end)
	end
	Looks.dress(character, look, { styleId = styleId, role = "player" })
	local st = playerState[character]
	if st and st.suit then
		Kit.suitTN(character, true) -- the rebuild dropped Costume/SuitTN
	end
end

--- Respawns the player in the look for `styleId`, then connects the Weapon listener and, for
--- suitTN styles, the edge-triggered Suit listener (both gone on character.Destroying).
function Looks.dressPlayer(player: Player, styleId: string, weapon: string?)
	disconnect(playerConns[player])
	playerConns[player] = nil
	local key = weapon or (player:GetAttribute("Weapon") :: any)
	if type(key) ~= "string" then
		key = nil
	end
	player:SetAttribute("Weapon", key)
	local look = Costumes.effectiveLook(styleId, "player", nil, suitKey(styleId, key))
	player:LoadCharacterWithHumanoidDescriptionAsync(Looks.description(look))
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("StyleId", styleId)
	character:SetAttribute("Weapon", key) -- before Kit.build: the Prop entry reads it
	Looks.dress(character, look, { styleId = styleId, role = "player" })

	local st: PlayerState = { conns = {}, suit = false, weapon = key }
	playerState[character] = st
	playerConns[player] = st.conns
	table.insert(
		st.conns,
		player:GetAttributeChangedSignal("Weapon"):Connect(function()
			local now = player:GetAttribute("Weapon")
			local k: string? = if type(now) == "string" then now else nil
			if k == st.weapon then
				return
			end
			local wasSuit = isSuitKey(styleId, st.weapon)
			st.weapon = k
			character:SetAttribute("Weapon", k)
			if isSuitKey(styleId, k) or wasSuit then
				Looks.redress(character)
			elseif k then
				Kit.prop(character, styleId, k)
			end
		end)
	)
	if look.suitTN then
		local has = (tonumber(player:GetAttribute("Suit")) or 0) > 0
		st.suit = has
		if has then
			Kit.suitTN(character, true)
		end
		table.insert(
			st.conns,
			player:GetAttributeChangedSignal("Suit"):Connect(function()
				local now, changed = Costumes.suitEdge(st.suit, tonumber(player:GetAttribute("Suit")))
				st.suit = now
				if changed then
					Kit.suitTN(character, now)
				end
			end)
		)
	end
	table.insert(
		st.conns,
		character.Destroying:Connect(function()
			disconnect(st.conns)
			if playerConns[player] == st.conns then
				playerConns[player] = nil
			end
		end)
	)
end

--------------------------------------------------------------------------------
-- NPCs
--------------------------------------------------------------------------------

--- An R15 model for `look` (preset first, then every scale × size, HeadScale *= size), dressed
--- through Looks.dress when `opts` is given.
function Looks.buildNpc(look: { [string]: any }, size: number, opts: DressOpts?): Model
	local d = Looks.description(look, nil)
	d.HeightScale *= size
	d.WidthScale *= size
	d.DepthScale *= size
	d.HeadScale *= size
	local model = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	if opts then
		Looks.dress(model, look, opts)
	end
	return model
end

--- A friendly figure built from a finale body: the_unbidden is Kage Inukai's ward (§4.6, 30
--- parts, tagged "Ward", not parented or placed).
function Looks.buildAlly(id: string, size: number): Model
	local body = Finale.BODY[id] or Finale.BODY.the_unbidden
	local model = Looks.buildNpc(body, size)
	if id == "the_unbidden" then
		return Creatures.buildWard(nil, model)
	end
	Looks.dress(model, nil, { enemyId = id, role = "finale" })
	Kit.ally(model)
	return model
end

--- Hyakunui's phase looks (§5.1).
function Looks.finalePhase(model: Model, phase: number)
	Finale.phase(model, phase)
end

return Looks
