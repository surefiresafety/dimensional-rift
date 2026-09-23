--!strict
-- Turns a character's palette into a Roblox body. R15 already has a neck,
-- shoulders and proportions, so what carries over from the web build is the
-- colour blocking (skin, top, sleeves, bottom), the height, and a hair shape.
--
-- Hair is built from parts here so it works with no catalog access. The
-- intended upgrade is real accessories: put catalog asset ids in ACCESSORIES
-- and they are added to the HumanoidDescription instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Characters = require(Shared.Data.Characters)

local Looks = {}

--- styleId -> comma-separated catalog asset ids (hair, hats, faces). Empty
--- until someone picks them in the catalog; see roblox/README.md.
Looks.ACCESSORIES = {} :: { [string]: { hair: string?, hat: string?, face: number? } }

function Looks.lookFor(styleId: string?): { [string]: any }
	return (styleId and Characters[styleId]) or Characters.default
end

function Looks.description(look: { [string]: any }, styleId: string?): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin = Palette.color(look.skin)
	local top = Palette.color(if look.bare then look.skin else look.top)
	local arms = Palette.color(look.sleeves or (if look.bare then look.skin else look.top))
	local legs = Palette.color(look.bottom)
	d.HeadColor = skin
	d.TorsoColor = top
	d.LeftArmColor = arms
	d.RightArmColor = arms
	d.LeftLegColor = legs
	d.RightLegColor = legs
	local h = look.height or 1
	d.HeightScale = h
	d.WidthScale = math.clamp(0.9 + (h - 1) * 0.6, 0.75, 1.2)
	d.DepthScale = d.WidthScale
	d.HeadScale = 1
	local extra = styleId and Looks.ACCESSORIES[styleId]
	if extra then
		d.HairAccessory = extra.hair or ""
		d.HatAccessory = extra.hat or ""
		if extra.face then
			d.Face = extra.face
		end
	end
	return d
end

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

--- A hair shape out of parts, sized to the head it sits on.
function Looks.dressHair(model: Model, look: { [string]: any })
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head or look.hairStyle == "none" or look.mask then
		return
	end
	local style = look.hairStyle or "crop"
	local colour = Palette.color(look.hair)
	local s = head.Size
	local folder = Instance.new("Folder")
	folder.Name = "Hair"
	folder.Parent = model
	local function piece(shape: Enum.PartType, size: Vector3, offset: CFrame)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.Color = colour
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		weld(p, head, offset)
		p.Parent = folder
	end
	-- Every style starts from a cap over the crown.
	piece(Enum.PartType.Ball, Vector3.new(s.X * 1.08, s.Y * 0.85, s.Z * 1.1), CFrame.new(0, s.Y * 0.22, -s.Z * 0.04))
	if style == "long" or style == "ponytail" or style == "megumi" or style == "yuta" then
		piece(
			Enum.PartType.Block,
			Vector3.new(s.X * 0.9, s.Y * (if style == "long" then 1.3 else 0.9), s.Z * 0.3),
			CFrame.new(0, -s.Y * 0.2, -s.Z * 0.5)
		)
	end
	if
		style == "spiky"
		or style == "naruto"
		or style == "gojo"
		or style == "sasuke"
		or style == "kakashi"
		or style == "sukuna"
	then
		local n = if style == "gojo" then 9 else 7
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			local tilt = CFrame.Angles(math.sin(a) * 0.7, 0, math.cos(a) * 0.7)
			piece(
				Enum.PartType.Block,
				Vector3.new(s.X * 0.22, s.Y * 0.7, s.Z * 0.22),
				CFrame.new(math.cos(a) * s.X * 0.28, s.Y * 0.62, math.sin(a) * s.Z * 0.28) * tilt
			)
		end
	end
	if style == "bun" then
		piece(
			Enum.PartType.Ball,
			Vector3.new(s.X * 0.45, s.Y * 0.45, s.Z * 0.45),
			CFrame.new(0, s.Y * 0.55, -s.Z * 0.45)
		)
	end
end

--- Respawns the player in the look for `styleId`.
function Looks.dressPlayer(player: Player, styleId: string)
	local look = Looks.lookFor(styleId)
	player:LoadCharacterWithHumanoidDescriptionAsync(Looks.description(look, styleId))
	local character = player.Character
	if character then
		Looks.dressHair(character, look)
	end
end

--- An R15 model for an enemy or a character boss.
function Looks.buildNpc(look: { [string]: any }, size: number): Model
	local d = Looks.description(look, nil)
	d.HeightScale *= size
	d.WidthScale *= size
	d.DepthScale *= size
	d.HeadScale = size
	local model = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	Looks.dressHair(model, look)
	return model
end

return Looks
