-- Shared look for all Ride or Die screens (chunky cartoon style: bold text with dark outlines,
-- thick white borders, glossy colored buttons).
local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.TitleFont = Enum.Font.LuckiestGuy
UI.Colors = {
	Navy = Color3.fromRGB(22, 26, 52),
	Dark = Color3.fromRGB(12, 14, 30),
	Blue = Color3.fromRGB(35, 140, 240),
	Cyan = Color3.fromRGB(80, 210, 255),
	Yellow = Color3.fromRGB(255, 200, 40),
	Orange = Color3.fromRGB(255, 150, 30),
	Green = Color3.fromRGB(70, 205, 95),
	Red = Color3.fromRGB(225, 55, 55),
	Purple = Color3.fromRGB(150, 80, 230),
	White = Color3.new(1, 1, 1),
	Outline = Color3.fromRGB(10, 10, 20),
}

function UI.new(class, props, children)
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

function UI.corner(radius)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

-- border around a frame/button
function UI.stroke(color, thickness)
	return UI.new("UIStroke", { Color = color or UI.Colors.White, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- subtle top-to-bottom shine
function UI.gloss(parent)
	return UI.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210)),
		Parent = parent,
	})
end

-- bold text with a dark outline
function UI.text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or UI.Font
	props.TextColor3 = props.TextColor3 or UI.Colors.White
	local outline = props.Outline
	props.Outline = nil
	-- dark text on light panels reads better without the outline
	local c = props.TextColor3
	if outline == nil and (0.3 * c.R + 0.59 * c.G + 0.11 * c.B) < 0.45 then
		outline = false
	end
	local label = UI.new("TextLabel", props)
	if outline ~= false then
		UI.new("UIStroke", { Color = UI.Colors.Outline, Thickness = outline or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	end
	return label
end

-- dark panel with a thick white border and a soft drop shadow
function UI.panel(props, borderColor)
	props.BackgroundColor3 = props.BackgroundColor3 or UI.Colors.Navy
	local frame = UI.new("Frame", props)
	UI.corner(14).Parent = frame
	UI.stroke(borderColor or UI.Colors.White, 3).Parent = frame
	return frame
end

-- glossy colored button with bold outlined text
function UI.button(props, color)
	props.Font = props.Font or UI.Font
	props.TextColor3 = props.TextColor3 or UI.Colors.White
	props.BackgroundColor3 = color or props.BackgroundColor3 or UI.Colors.Green
	props.AutoButtonColor = true
	local b = UI.new("TextButton", props)
	UI.corner(10).Parent = b
	UI.new("UIStroke", { Color = UI.Colors.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	UI.new("UIStroke", { Color = UI.Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = b })
	UI.gloss(b)
	return b
end

return UI
