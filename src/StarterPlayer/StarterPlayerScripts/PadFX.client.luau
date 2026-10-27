-- Lobby pads: a glowing "beam me up" effect in each pad's colour. Light walls fade upward, rounded
-- rings float up off the pad, sparkles rise, and arrows on the floor march toward it. Everything
-- speeds up while a pad is being hosted and bursts when the train is departing. Client-only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local padsFolder = workspace:WaitForChild("Lobby"):WaitForChild("Pads")

local HEIGHT = 9 -- how high the light goes
local RINGS = 3
local CHEVRONS = 3
local WHITE = Color3.new(1, 1, 1)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "PadFX"
fxFolder.Parent = workspace

local function holder(name, size, cf, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function surface(part, face, pixelsPerStud)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0 -- glows in the dark
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pixelsPerStud
	g.Parent = part
	return g
end

local function wallFade(bottom)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, bottom),
		NumberSequenceKeypoint.new(0.45, 0.55 + bottom * 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local effects = {}

local function build(model)
	local pad = model:WaitForChild("Pad")
	local base = pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0) -- top of the pad
	local width = pad.Size.X
	local folder = Instance.new("Folder")
	folder.Name = model.Name
	folder.Parent = fxFolder
	local fx = { Model = model, Pad = pad, Phase = math.random(), Walls = {}, Rings = {}, Chevrons = {} }

	-- light walls along the four edges
	for i = 0, 3 do
		local cf = base * CFrame.Angles(0, math.rad(90 * i), 0) * CFrame.new(0, HEIGHT / 2, width / 2 - 0.35)
		local wall = holder("Wall", Vector3.new(width - 2.2, HEIGHT, 0.05), cf, folder)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromScale(1, 1)
			frame.BorderSizePixel = 0
			frame.Parent = surface(wall, face, 8)
			local fade = Instance.new("UIGradient")
			fade.Rotation = -90 -- solid at the bottom, gone at the top
			fade.Parent = frame
			table.insert(fx.Walls, { Frame = frame, Fade = fade })
		end
	end

	-- rounded rings that rise off the pad and fade out
	for k = 1, RINGS do
		local part = holder("Ring", Vector3.new(width, 0.05, width), base, folder)
		local ring = { Part = part, Offset = (k - 1) / RINGS, Frames = {}, Strokes = {} }
		for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
			local frame = Instance.new("Frame")
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromScale(0.5, 0.5)
			frame.BackgroundTransparency = 1
			frame.Parent = surface(part, face, 16)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.15, 0)
			corner.Parent = frame
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 14
			stroke.Parent = frame
			table.insert(ring.Frames, frame)
			table.insert(ring.Strokes, stroke)
		end
		table.insert(fx.Rings, ring)
	end

	-- sparkles drifting up
	local emitterPart = holder("Sparkles", Vector3.new(width - 1.5, 0.2, width - 1.5), base * CFrame.new(0, 0.2, 0), folder)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparkles.Lifetime = NumberRange.new(1.4, 2.4)
	sparkles.Speed = NumberRange.new(3, 6)
	sparkles.SpreadAngle = Vector2.new(6, 6)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Parent = emitterPart
	fx.Sparkles = sparkles

	-- glowing arrows on the floor in front of the pad, pointing at it (the pad is toward -Z)
	local tip, tail = Vector3.new(0, 0, -0.6), 1.0
	for i = 1, CHEVRONS do
		local origin = base * CFrame.new(0, -0.47, width / 2 + 0.9 + 1.9 * i)
		local bars = {}
		for _, side in { -1, 1 } do
			local back = Vector3.new(side * tail, 0, 0.45)
			local bar = holder("Arrow", Vector3.new(0.4, 0.06, (back - tip).Magnitude + 0.2), origin * CFrame.lookAt((tip + back) / 2, back), folder)
			bar.Material = Enum.Material.Neon
			table.insert(bars, bar)
		end
		table.insert(fx.Chevrons, { Bars = bars, Index = i })
	end

	fx.Base = base
	effects[model] = fx
end

for _, model in padsFolder:GetChildren() do
	task.spawn(build, model)
end
padsFolder.ChildAdded:Connect(build)

RunService.Heartbeat:Connect(function(dt)
	local inRide = player:GetAttribute("InRide") == true
	fxFolder.Parent = if inRide then nil else workspace
	if inRide then
		return
	end
	for _, fx in effects do
		local state = fx.Model:GetAttribute("State")
		local launching = state == "Launching"
		local busy = state == "Setup" or state == "Open"
		local mood = if launching then "Launch" elseif busy then "Busy" else "Idle"
		fx.Phase += dt * (if launching then 1.6 elseif busy then 0.7 else 0.35)
		local color = fx.Pad.Color

		if mood ~= fx.Mood or color ~= fx.Color then
			fx.Mood, fx.Color = mood, color
			local fade = wallFade(if launching then 0 elseif busy then 0.1 else 0.25)
			for _, wall in fx.Walls do
				wall.Frame.BackgroundColor3 = color
				wall.Fade.Transparency = fade
			end
			fx.Sparkles.Color = ColorSequence.new(color:Lerp(WHITE, 0.35))
			fx.Sparkles.Rate = if launching then 80 elseif busy then 30 else 14
		end

		for _, ring in fx.Rings do
			local u = (fx.Phase + ring.Offset) % 1
			ring.Part.CFrame = fx.Base * CFrame.new(0, 0.15 + u * HEIGHT, 0)
			local size = UDim2.fromScale(0.9 - 0.16 * u, 0.9 - 0.16 * u)
			for i, frame in ring.Frames do
				frame.Size = size
				ring.Strokes[i].Color = color:Lerp(WHITE, 0.25)
				ring.Strokes[i].Transparency = u * u
			end
		end

		-- arrows light up one after another, outermost first, so they "march" toward the pad
		for _, chevron in fx.Chevrons do
			local u = (fx.Phase * 1.5 - (CHEVRONS - chevron.Index) / CHEVRONS) % 1
			local glow = 0.15 + 0.75 * u
			for _, bar in chevron.Bars do
				bar.Color = color:Lerp(WHITE, 0.2)
				bar.Transparency = glow
			end
		end
	end
end)
