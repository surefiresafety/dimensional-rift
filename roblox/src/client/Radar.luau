--!strict
-- A round radar under the level chip: you in the middle facing up, every
-- enemy within 70 units as a dot. Yellow dots have not seen you, red ones are
-- hunting you, bosses are bigger and violet-rimmed. Enemies now wait to be
-- found, so this is how you find them. Edges show the ones further out.

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Radar = {}

local RANGE = 70 * 2.4 -- studs

--- `compact`: a phone, where the right side belongs to the touch pad; the
--- radar sits smaller beside the vitals instead.
function Radar.build(parent: ScreenGui, top: number, compact: boolean?)
	local SIZE = if compact then 96 else 140
	local disc = Ui.make("Frame", {
		Name = "Radar",
		AnchorPoint = if compact then Vector2.new(0, 0) else Vector2.new(1, 0),
		-- On a phone: under the vitals and the status line, clear of the pad.
		Position = if compact then UDim2.fromOffset(20, top - 132 + 110) else UDim2.new(1, -20, 0, top),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.35,
		ClipsDescendants = true,
		Parent = parent,
	}, { Ui.corner(SIZE // 2), Ui.stroke() })
	for _, r in { 0.33, 0.66 } do
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(r, r),
			BackgroundTransparency = 1,
			Parent = disc,
		}, { Ui.corner(SIZE), Ui.stroke(Ui.LINE, 1, 0.6) })
	end
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Rotation = 45,
		ZIndex = 3,
		Parent = disc,
	})
	local count = Ui.label({
		Text = "",
		Font = Ui.BOLD,
		TextSize = 10,
		TextColor3 = Ui.DIM,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(100, 12),
		ZIndex = 4,
		Parent = disc,
	})

	local dots: { Frame } = {}
	local function dot(i: number): Frame
		local d = dots[i]
		if not d then
			d = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = disc,
			}, { Ui.corner(6) })
			dots[i] = d
		end
		return d
	end

	task.spawn(function()
		while disc.Parent do
			local n, hunting = 0, 0
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			local folder = workspace:FindFirstChild("Enemies")
			if root and folder then
				-- Up on the radar is where the camera looks.
				local look = workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
				local yaw = math.atan2(-look.X, -look.Z)
				local basis = CFrame.Angles(0, yaw, 0)
				for _, m in folder:GetChildren() do
					local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
					local hum = m:FindFirstChildOfClass("Humanoid")
					if r and hum and hum.Health > 0 then
						local rel = basis:VectorToObjectSpace(r.Position - root.Position)
						local dist = Vector2.new(rel.X, rel.Z).Magnitude
						local k = math.min(dist / RANGE, 1) * 0.46
						local dir = if dist > 0.01 then Vector2.new(rel.X, rel.Z).Unit else Vector2.zero
						n += 1
						local isHunting = m:GetAttribute("Hunting") == true
						if isHunting then
							hunting += 1
						end
						local d = dot(n)
						local boss = m:GetAttribute("Boss") == true
						d.Visible = true
						d.Size = UDim2.fromOffset(if boss then 11 else 7, if boss then 11 else 7)
						d.Position = UDim2.fromScale(0.5 + dir.X * k, 0.5 + dir.Y * k)
						d.BackgroundColor3 = if isHunting then Color3.fromRGB(255, 70, 80) else Ui.GOLD
						d.BackgroundTransparency = if dist > RANGE then 0.5 else 0
						local stroke = d:FindFirstChildOfClass("UIStroke")
						if boss and not stroke then
							Ui.stroke(Ui.ACCENT, 2, 0).Parent = d
						elseif not boss and stroke then
							stroke:Destroy()
						end
					end
				end
			end
			for i = n + 1, #dots do
				dots[i].Visible = false
			end
			count.Text = if n == 0 then "" else `{n} LEFT · {hunting} HUNTING`
			task.wait(0.1)
		end
	end)
end

return Radar
