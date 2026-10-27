-- Shared look for all Ride or Die screens (chunky cartoon style: bold text with dark outlines,
-- glossy colored buttons, near-black rounded windows with the title above them and a red X).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.TitleFont = Enum.Font.LuckiestGuy
UI.Colors = {
	Navy = Color3.fromRGB(22, 26, 52),
	Dark = Color3.fromRGB(12, 14, 30),
	Panel = Color3.fromRGB(12, 12, 16), -- window body
	Card = Color3.fromRGB(32, 32, 38), -- cards inside windows
	Grey = Color3.fromRGB(110, 112, 120),
	Muted = Color3.fromRGB(180, 183, 195), -- small helper text
	Blue = Color3.fromRGB(35, 140, 240),
	Cyan = Color3.fromRGB(80, 210, 255),
	Yellow = Color3.fromRGB(255, 200, 40),
	Orange = Color3.fromRGB(255, 150, 30),
	Green = Color3.fromRGB(70, 205, 95),
	Lime = Color3.fromRGB(30, 225, 70), -- big "Claim" / "Start" buttons
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

-- the border stroke of a frame/button (to recolor it, e.g. for "selected")
function UI.border(object)
	for _, child in object:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			return child
		end
	end
	return nil
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

-- glossy colored button with bold outlined text and a thin light rim inside the border
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
	UI.new("Frame", { Name = "Rim", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1, Parent = b }, {
		UI.corner(8),
		UI.new("UIStroke", { Color = UI.Colors.White, Thickness = 1.5, Transparency = 0.55 }),
	})
	return b
end

-- red square X button
function UI.closeButton(props)
	props.Size = props.Size or UDim2.fromOffset(48, 48)
	props.Text = "X"
	props.TextSize = props.TextSize or 30
	props.Font = UI.TitleFont
	return UI.button(props, Color3.fromRGB(228, 45, 45))
end

-- little red "!" bubble on the top-right corner of a button (hidden until you show it)
function UI.badge(parent)
	local dot = UI.new("Frame", {
		Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = UI.Colors.Red, Visible = false, ZIndex = 5, Parent = parent,
	}, { UI.corner(13), UI.stroke(UI.Colors.White, 2.5) })
	UI.text({ Size = UDim2.fromScale(1, 1), Text = "!", TextSize = 20, Font = UI.TitleFont, ZIndex = 6, Parent = dot })
	return dot
end

-- chunky tick made of two bars with a dark outline (the ✔ character shows up as a grey emoji).
-- props needs a square offset Size.
function UI.check(props, color)
	props.BackgroundTransparency = 1
	local holder = UI.new("Frame", props)
	local s = props.Size.X.Offset
	local t = s * 0.18
	local joint = Vector2.new(s * 0.4, s * 0.72)
	local function arm(length, angle, fill, extra, z)
		local center = joint + Vector2.new(math.cos(math.rad(angle)), math.sin(math.rad(angle))) * (length / 2)
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(length + t + extra, t + extra),
			Rotation = angle, BackgroundColor3 = fill, BorderSizePixel = 0, ZIndex = z, Parent = holder,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	for z, layer in { { UI.Colors.Outline, 6 }, { color or UI.Colors.Lime, 0 } } do
		arm(s * 0.3, 225, layer[1], layer[2], z) -- short arm, up-left
		arm(s * 0.62, -50, layer[1], layer[2], z) -- long arm, up-right
	end
	return holder
end

-- rounded progress bar with text in the middle. Use bar.Set(0..1, "3 / 5").
-- It never gets thinner than a dot, so an empty bar still shows a little blob like the reference.
function UI.bar(props, fillColor)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.new(0, 0, 0)
	props.BackgroundTransparency = props.BackgroundTransparency or 0.35
	local back = UI.new("Frame", props, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }), UI.stroke(UI.Colors.Outline, 2) })
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = fillColor or UI.Colors.Yellow, Parent = back }, {
		UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UI.new("UISizeConstraint", { MinSize = Vector2.new(props.Size.Y.Offset, 0) }),
	})
	UI.gloss(fill)
	local label = UI.text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 14, ZIndex = 2, Parent = back })
	local bar = { Frame = back, Fill = fill, Label = label }
	function bar.Set(fraction, message)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		label.Text = message or ""
	end
	return bar
end

-- sunburst behind a reward icon: soft rays + a glow in the middle.
-- Returns the ray holder; turn its Rotation to spin the rays.
function UI.rays(parent, color, count)
	count = count or 10
	local clip = UI.new("Frame", {
		Name = "Rays", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = parent,
	})
	for _, size in { 1.15, 0.8, 0.5 } do
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(size, size),
			SizeConstraint = Enum.SizeConstraint.RelativeXX, BackgroundColor3 = color, BackgroundTransparency = 0.84, Parent = clip,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	local spin = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Parent = clip })
	for i = 1, count do
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 18),
			Rotation = (i - 1) * 180 / count, BackgroundColor3 = color, BorderSizePixel = 0, Parent = spin,
		}, {
			UI.new("UIGradient", { Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}) }),
		})
	end
	return spin
end

-- quick bounce (e.g. when you claim something)
function UI.pop(object)
	local scale = object:FindFirstChild("PopScale") or UI.new("UIScale", { Name = "PopScale", Parent = object })
	scale.Scale = 1.18
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- "+50 🎫" that floats up and fades away. position is in the ScreenGui's pixels.
function UI.popText(parent, position, message, color)
	local label = UI.text({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(260, 44), Text = message,
		TextSize = 36, Font = UI.TitleFont, TextColor3 = color or UI.Colors.Yellow, Outline = 3, ZIndex = 50, Parent = parent,
	})
	local outline = label:FindFirstChildOfClass("UIStroke")
	TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = position - UDim2.fromOffset(0, 90) }):Play()
	local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.8)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(outline, fade, { Transparency = 1 }):Play()
	task.delay(1.4, function()
		label:Destroy()
	end)
end

------------------------------------------------------------------ windows
-- Every window made with UI.window is listed here, so opening one closes the others
-- and other UI can ask whether any window is open.
local windows = {}

function UI.anyWindowOpen()
	for _, w in windows do
		if w.Frame.Visible then
			return true
		end
	end
	return false
end

function UI.closeWindows()
	for _, w in windows do
		if w.Frame.Visible then
			w.Close()
		end
	end
end

-- Title (with a tilted icon) above a near-black rounded panel, red X on its top-right corner.
-- opts: Title, Icon, Width, Height (of the panel), Parent, OnClose.
-- Put content in .Body. Use .Open() / .Close(). Shrinks itself to fit small screens.
function UI.window(opts)
	local w, h = opts.Width, opts.Height
	local root = UI.new("Frame", {
		Name = opts.Name or "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h + 50), BackgroundTransparency = 1, Visible = false, Parent = opts.Parent,
	})
	local scale = UI.new("UIScale", { Parent = root })
	UI.text({ Position = UDim2.fromOffset(-4, -4), Size = UDim2.fromOffset(54, 54), Text = opts.Icon or "", TextSize = 42, Rotation = -12, Outline = false, Parent = root })
	UI.text({
		Position = UDim2.fromOffset(opts.Icon and 54 or 8, 0), Size = UDim2.new(1, -120, 0, 50), Text = opts.Title,
		TextSize = 40, Font = UI.TitleFont, Outline = 3, TextXAlignment = Enum.TextXAlignment.Left, Parent = root,
	})
	local body = UI.new("Frame", {
		Name = "Body", Position = UDim2.fromOffset(0, 50), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.04, Parent = root,
	}, { UI.corner(22), UI.stroke(UI.Colors.Outline, 3) })
	local closeButton = UI.closeButton({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -10, 0, 56), ZIndex = 10, Parent = root })

	local win = { Frame = root, Body = body, CloseButton = closeButton }
	local openedAt = 0
	function win.Close()
		root.Visible = false
		if opts.OnClose then
			opts.OnClose()
		end
	end
	function win.Open()
		for _, other in windows do
			if other ~= win and other.Frame.Visible then
				other.Close()
			end
		end
		if not root.Visible then
			openedAt = os.clock()
		end
		root.Visible = true
	end
	closeButton.Activated:Connect(win.Close)
	table.insert(windows, win)

	RunService.RenderStepped:Connect(function()
		if root.Visible then
			local view = workspace.CurrentCamera.ViewportSize
			local fit = math.min(1, (view.X - 30) / w, (view.Y - 100) / (h + 50))
			-- little bounce when it opens
			local t = math.min(1, (os.clock() - openedAt) / 0.3) - 1
			local bounce = 0.85 + 0.15 * (1 + 2.7 * t ^ 3 + 1.7 * t ^ 2)
			scale.Scale = fit * bounce
		end
	end)
	return win
end

------------------------------------------------------------------ lobby menu buttons (left edge)
-- Big square buttons stacked down the left side (Rewards, Trains, Perks...). Hidden during rides.
local menuColumn

function UI.menuButton(order, icon, label, color)
	if not menuColumn then
		local player = Players.LocalPlayer
		local gui = UI.new("ScreenGui", { Name = "MenuButtons", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 4, Parent = player:WaitForChild("PlayerGui") })
		-- on phones the movement stick is in the bottom-left corner, so the buttons sit higher
		menuColumn = UI.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, UserInputService.TouchEnabled and 0.4 or 0.5, 0), Size = UDim2.fromOffset(90, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui,
		}, { UI.new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local scale = UI.new("UIScale", { Parent = menuColumn })
		RunService.RenderStepped:Connect(function()
			gui.Enabled = player:GetAttribute("InRide") ~= true
			scale.Scale = math.clamp((workspace.CurrentCamera.ViewportSize.Y - 80) / 620, 0.55, 1)
		end)
	end
	local b = UI.button({ Size = UDim2.fromOffset(90, 90), Text = "", LayoutOrder = order, Parent = menuColumn }, color)
	UI.border(b).Thickness = 3.5
	UI.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(64, 56), Text = icon, TextSize = 46, Outline = false, Parent = b })
	UI.text({
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, 10, 0, 24), Text = label,
		TextSize = 19, Font = UI.TitleFont, Outline = 2.5, Parent = b,
	})
	return b, UI.badge(b)
end

return UI
