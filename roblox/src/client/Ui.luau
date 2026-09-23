--!strict
-- A little helper for building interface in code: one call per instance, with
-- its properties and children, so the screens read top to bottom.

local Ui = {}

Ui.INK = Color3.fromRGB(11, 9, 24)
Ui.PANEL = Color3.fromRGB(22, 18, 44)
Ui.LINE = Color3.fromRGB(80, 66, 140)
Ui.TEXT = Color3.fromRGB(237, 235, 247)
Ui.DIM = Color3.fromRGB(164, 157, 194)
Ui.ACCENT = Color3.fromRGB(176, 108, 255)
Ui.GOLD = Color3.fromRGB(255, 213, 74)
Ui.HP = Color3.fromRGB(61, 220, 151)
Ui.SE = Color3.fromRGB(78, 168, 255)
Ui.DISPLAY = Enum.Font.Bangers
Ui.BODY = Enum.Font.GothamMedium
Ui.BOLD = Enum.Font.GothamBold

function Ui.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Ui.corner(r: number): UICorner
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, r) })
end

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Ui.make("UIStroke", {
		Color = color or Ui.LINE,
		Thickness = thickness or 1,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.pad(px: number): UIPadding
	local u = UDim.new(0, px)
	return Ui.make("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		TextColor3 = Ui.TEXT,
		Font = Ui.BODY,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Ui.make("TextLabel", defaults)
end

return Ui
