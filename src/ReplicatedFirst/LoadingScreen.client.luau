-- Loading screen (ReplicatedFirst, so it shows before anything else has loaded).
-- You're on the train looking at the closed doors while the tunnel rushes past the windows, and a little
-- train runs along the Line 13 map as the game loads. When it's ready the train brakes into the station,
-- the door light turns green and the doors slide open onto the game.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
ReplicatedFirst:RemoveDefaultLoadingScreen()

local MIN_TIME = 3.5 -- the ride always lasts at least this long, so the animation gets seen
local SKIP_AFTER = 2.5
local GIVE_UP_AFTER = 25 -- never keep anyone waiting longer than this
local ARRIVE_TIME = 1.5 -- braking into the station
local OPEN_TIME = 1.0 -- doors sliding open

local STATIONS = {
	{ "Start", 0 }, { "Elm Street", 0.25 }, { "Old Mill", 0.525 }, { "Hollow Park", 0.775 }, { "Midnight Station", 1 },
}
local MESSAGES = {
	"Warming up the engine", "Checking the brakes", "Stocking the snack machine", "Taping up the windows",
	"Waking up the driver", "Polishing the handrails", "Calming the passengers", "Clearing the tracks",
}
local TIPS = {
	"Hold the right tool in your hand to fix a breakdown.",
	"Scared passengers calm down when you chat with them.",
	"Hungry passengers get scared. Bring them the snack they want!",
	"Slow down for curves and stop at red signals.",
	"Pick the right track at a junction, or CRASH!",
	"Get the VIP to Midnight Station for bonus Tokens.",
	"Harder rides pay more Tokens.",
	"Power out? Flip the breaker by the cab door.",
}

local FONT = Enum.Font.FredokaOne
local TITLE = Enum.Font.LuckiestGuy
local WHITE = Color3.new(1, 1, 1)
local OUTLINE = Color3.fromRGB(10, 12, 24)
local YELLOW = Color3.fromRGB(255, 201, 40)
local RED = Color3.fromRGB(235, 50, 60)
local GREEN = Color3.fromRGB(60, 225, 100)
local MUTED = Color3.fromRGB(184, 190, 210)
local PANEL = Color3.fromRGB(10, 13, 26)
local LAMP = Color3.fromRGB(255, 241, 196)

------------------------------------------------------------------ helpers
local function new(class, props, children)
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

local function round(radius)
	return new("UICorner", { CornerRadius = radius })
end

local function border(color, thickness, transparency)
	return new("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props, strokeThickness)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	local l = new("TextLabel", props)
	if strokeThickness then
		new("UIStroke", { Color = OUTLINE, Thickness = strokeThickness, Parent = l })
	end
	return l
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

-- overshoots a little and settles: the "pop" used for everything that appears
local function backOut(x)
	x = clamp01(x)
	local c1 = 1.70158
	return 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function sound(name, volume)
	local folder = ReplicatedStorage:FindFirstChild("Sounds")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return nil
	end
	local s = template:Clone()
	s.Volume = volume
	s.Parent = SoundService
	s:Play()
	if not s.Looped then
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	return s
end

------------------------------------------------------------------ screen
local gui = new("ScreenGui", {
	Name = "LoadingScreen", IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, ResetOnSpawn = false, DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- everything that rumbles with the train
local shake = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

------------------------------------------------------------------ doors with a window each
local views = {} -- the tunnel seen through each window

local function makeView(parent)
	local view = new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 1, -16),
		BackgroundColor3 = Color3.fromRGB(6, 7, 14), Parent = parent,
	}, { round(UDim.new(0, 26)) })
	-- tunnel wall: dark, a little lighter where the lamps are (its own layer: a gradient on the group would darken everything)
	new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = view }, {
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 7, 14)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(30, 37, 66)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(15, 18, 32)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 6, 12)),
			}),
		}),
	})
	for _, y in { 0.6, 0.64, 0.69 } do -- cables along the wall
		new("Frame", { Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(44, 50, 78), BorderSizePixel = 0, Parent = view })
	end

	local movers = {}
	local function mover(obj, speed, x, margin, rerollY)
		obj.Position = UDim2.fromScale(x, obj.Position.Y.Scale)
		table.insert(movers, { Obj = obj, Speed = speed, X = x, Y = obj.Position.Y.Scale, Margin = margin, RerollY = rerollY })
	end
	-- tunnel ribs flicking past
	for i = 1, 3 do
		local rib = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.06, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(2, 3, 8),
			BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = view,
		})
		mover(rib, 2.6, (i - 1) * 0.6, 0.1)
	end
	-- lamps on the wall, with a soft glow (stretched a bit, like motion blur)
	for i = 1, 3 do
		local glow = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(0.62, 0.2),
			BackgroundColor3 = LAMP, BackgroundTransparency = 0.93, BorderSizePixel = 0, Parent = view,
		}, {
			round(UDim.new(1, 0)),
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.82, 0.6), BackgroundColor3 = LAMP, BackgroundTransparency = 0.85, BorderSizePixel = 0 }, { round(UDim.new(1, 0)) }),
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.64, 0.36), BackgroundColor3 = LAMP, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, { round(UDim.new(1, 0)) }),
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.46, 0.2), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, { round(UDim.new(1, 0)) }),
		})
		mover(glow, 1.6, 0.25 + (i - 1) * 0.7, 0.35)
	end
	-- speed streaks
	for _ = 1, 14 do
		local streak = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.08 + math.random() * 0.84),
			Size = UDim2.new(0.18 + math.random() * 0.4, 0, 0, math.random(1, 3)),
			BackgroundColor3 = Color3.fromRGB(196, 214, 255), BorderSizePixel = 0, Parent = view,
		}, {
			new("UIGradient", { Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3 + math.random() * 0.45), NumberSequenceKeypoint.new(1, 1),
			}) }),
		})
		mover(streak, 3 + math.random() * 2.2, math.random() * 1.4, 0.35, true)
	end
	-- warm station light that fills the window as the train pulls in
	local station = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 238, 205), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = view })
	-- glass shine
	for _, shine in { { 0.3, 0.16, 0.92 }, { 0.43, 0.05, 0.93 } } do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(shine[1], 0.45), Size = UDim2.fromScale(shine[2], 2), Rotation = 24,
			BackgroundColor3 = WHITE, BackgroundTransparency = shine[3], BorderSizePixel = 0, Parent = view,
		})
	end
	table.insert(views, { Movers = movers, Station = station })
end

local function makeDoor(side) -- -1 = left leaf, 1 = right leaf
	local inner = side < 0 and 1 or 0 -- the edge where the two leaves meet
	local door = new("Frame", {
		Name = side < 0 and "LeftDoor" or "RightDoor", Position = UDim2.fromScale(side < 0 and 0 or 0.5, 0), Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = shake,
	}, {
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(60, 70, 108), Color3.fromRGB(30, 36, 62)) }),
	})
	-- raised panel line
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, side * -10, 0.5, -6), Size = UDim2.new(1, -60, 1, -60),
		BackgroundTransparency = 1, Parent = door,
	}, { round(UDim.new(0, 24)), border(WHITE, 2, 0.9) })
	-- steel kick plate
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.03), BackgroundColor3 = WHITE,
		BorderSizePixel = 0, Parent = door,
	}, {
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 158, 174), Color3.fromRGB(80, 86, 102)) }),
		new("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.fromRGB(210, 216, 228), BorderSizePixel = 0 }),
	})
	-- yellow rubber edge + the dark seam between the leaves
	new("Frame", {
		AnchorPoint = Vector2.new(inner, 0), Position = UDim2.fromScale(inner, 0), Size = UDim2.new(0, 9, 1, 0), BackgroundColor3 = WHITE,
		BorderSizePixel = 0, Parent = door,
	}, {
		new("UIGradient", { Rotation = side < 0 and 0 or 180, Color = ColorSequence.new(Color3.fromRGB(240, 196, 60), Color3.fromRGB(176, 124, 14)) }),
	})
	new("Frame", { AnchorPoint = Vector2.new(inner, 0), Position = UDim2.fromScale(inner, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = OUTLINE, BorderSizePixel = 0, Parent = door })
	-- window: black rubber gasket around a rounded view of the tunnel
	local gasket = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, side * -10, 0.07, -8), Size = UDim2.new(0.56, 16, 0.4, 16),
		BackgroundColor3 = Color3.fromRGB(12, 14, 22), Parent = door,
	}, { round(UDim.new(0, 34)), border(WHITE, 2, 0.84) })
	makeView(gasket)
	return door
end

local leftDoor = makeDoor(-1)
local rightDoor = makeDoor(1)

-- darker corners, so the middle (and the logo) stands out
local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui }, {
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.22, 1), NumberSequenceKeypoint.new(0.78, 1), NumberSequenceKeypoint.new(1, 0.45),
	}) }),
})

-- door light above the seam: blinks red while loading, turns green when the doors are about to open
local lampHousing = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(84, 32),
	BackgroundColor3 = Color3.fromRGB(14, 17, 30), Parent = shake,
}, { round(UDim.new(1, 0)), border(WHITE, 2, 0.75) })
local lampGlow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = RED, BackgroundTransparency = 0.75, Parent = lampHousing,
}, { round(UDim.new(1, 0)) })
local lamp = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20),
	BackgroundColor3 = RED, Parent = lampHousing,
}, { round(UDim.new(1, 0)), border(OUTLINE, 2) })
local lampScale = new("UIScale", { Parent = lamp })

------------------------------------------------------------------ logo, line map, tips (1280x720 canvas, scaled to fit)
local content = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local canvas = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1280, 720),
	BackgroundTransparency = 1, Parent = content,
})
local canvasScale = new("UIScale", { Parent = canvas })

local LOGO_Y = 395
local logo = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, LOGO_Y), Size = UDim2.fromOffset(1000, 126),
	BackgroundTransparency = 1, Parent = canvas,
})
local logoScale = new("UIScale", { Scale = 0, Parent = logo })
local dieWords = {} -- "DIE!" (and its shadow) gives a spooky little wobble now and then
local function logoRow(shadow)
	local row = new("Frame", {
		Position = shadow and UDim2.fromOffset(6, 9) or UDim2.new(), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = logo,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 24), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, word in { { "RIDE OR", WHITE, Color3.fromRGB(255, 226, 140) }, { "DIE!", Color3.fromRGB(255, 96, 70), Color3.fromRGB(196, 14, 44) } } do
		local l = label({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = word[1], Font = TITLE, TextSize = 120, LayoutOrder = i, Parent = row })
		if i == 2 then
			table.insert(dieWords, l)
		end
		if shadow then
			l.TextColor3 = Color3.new(0, 0, 0)
			l.TextTransparency = 0.5
			new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 9, Transparency = 0.5, Parent = l })
		else
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(word[2], word[3]), Parent = l })
			new("UIStroke", { Color = OUTLINE, Thickness = 9, Parent = l })
		end
	end
end
logoRow(true)
logoRow(false)

local subtitle = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 490), Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.1, Parent = canvas,
}, {
	round(UDim.new(1, 0)), border(YELLOW, 2.5),
	new("UIPadding", { PaddingLeft = UDim.new(0, 24), PaddingRight = UDim.new(0, 24) }),
	label({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "LINE 13   •   NEXT STOP: MIDNIGHT STATION", TextSize = 21, TextColor3 = YELLOW }),
})
local subtitleScale = new("UIScale", { Scale = 0, Parent = subtitle })

-- the line map: a train runs from Start to Midnight Station as things load
local BAR_W = 760
local progress = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 538), Size = UDim2.fromOffset(BAR_W, 112),
	BackgroundTransparency = 1, Parent = canvas,
})
local progressScale = new("UIScale", { Scale = 0, Parent = progress })
-- dark glass panel behind the map, so the door seam doesn't run through it
new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -16), Size = UDim2.new(1, 120, 1, 26),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, ZIndex = 0, Parent = progress,
}, { round(UDim.new(0, 22)), border(WHITE, 2, 0.88) })
local status = label({ Size = UDim2.new(1, -100, 0, 26), Text = "", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = progress }, 2)
local percent = label({
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(100, 28), Text = "0%",
	Font = TITLE, TextSize = 30, TextColor3 = YELLOW, TextXAlignment = Enum.TextXAlignment.Right, Parent = progress,
}, 2.5)
local track = new("Frame", {
	Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = PANEL, Parent = progress,
}, { round(UDim.new(1, 0)), border(WHITE, 2, 0.72) })
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, ClipsDescendants = true, Parent = track }, {
	round(UDim.new(1, 0)),
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(80, 226, 110), YELLOW) }),
})
local sheen = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(60, 40), Rotation = 20,
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = fill,
})
local dots = {}
for i, st in STATIONS do
	local x = st[2] * BAR_W
	local nameAnchor = i == 1 and 0.3 or i == #STATIONS and 0.7 or 0.5 -- end names lean inward so they stay on the panel
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 72), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(28, 33, 58), ZIndex = 2, Parent = progress,
	}, { round(UDim.new(1, 0)), border(WHITE, 3) })
	local name = label({
		AnchorPoint = Vector2.new(nameAnchor, 0), Position = UDim2.fromOffset(x, 90), Size = UDim2.fromOffset(170, 22), Text = st[1],
		TextSize = 19, TextColor3 = MUTED, Parent = progress,
	}, 1.5)
	table.insert(dots, { Dot = dot, Name = name, At = st[2], Lit = false, LitAt = 0, Scale = new("UIScale", { Parent = dot }) })
end
local trainMarker = label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(48, 40), Text = "🚇",
	TextSize = 38, ZIndex = 3, Parent = progress,
})

local tip = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 682), Size = UDim2.fromOffset(1100, 28), Text = "",
	TextSize = 22, TextColor3 = MUTED, TextTransparency = 1, Parent = canvas,
}, 1.5)
local tipStroke = tip:FindFirstChildOfClass("UIStroke")

local skipButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(1250, 680), Size = UDim2.fromOffset(124, 42), Text = "SKIP  ▶",
	Font = FONT, TextSize = 21, TextColor3 = WHITE, BackgroundColor3 = WHITE, BackgroundTransparency = 1, TextTransparency = 1,
	AutoButtonColor = true, Visible = false, Parent = canvas,
}, { round(UDim.new(1, 0)) })
local skipStroke = border(WHITE, 2, 1)
skipStroke.Parent = skipButton

-- fades in from black when you join
local fadeIn = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 10, Parent = gui })

gui.Parent = player:WaitForChild("PlayerGui")

------------------------------------------------------------------ loading
local gameLoaded = game:IsLoaded()
local preloaded, toPreload, preloadDone = 0, 0, false
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	gameLoaded = true
	-- the item pictures, sounds and the station's meshes, so the lobby doesn't pop in after the doors open
	-- (images go in as ids; sounds and meshes go in as the objects themselves, so they load as the right type)
	local assets, seen = {}, {}
	local function add(item, key)
		if key and key ~= "" and not seen[key] then
			seen[key] = true
			table.insert(assets, item)
		end
	end
	local config = ReplicatedStorage:WaitForChild("Config", 10)
	if config then
		local ok, cfg = pcall(require, config)
		if ok and type(cfg.Icons) == "table" then
			for _, id in cfg.Icons do
				add(id, id)
			end
		end
	end
	local sounds = ReplicatedStorage:FindFirstChild("Sounds")
	for _, s in sounds and sounds:GetChildren() or {} do
		if s:IsA("Sound") then
			add(s, s.SoundId)
		end
	end
	local lobby = workspace:FindFirstChild("Lobby")
	for _, d in lobby and lobby:GetDescendants() or {} do
		if d:IsA("MeshPart") then
			add(d, d.MeshId)
		end
	end
	toPreload = #assets
	pcall(ContentProvider.PreloadAsync, ContentProvider, assets, function()
		preloaded += 1
	end)
	preloadDone = true
end)

local skipped = false
skipButton.Activated:Connect(function()
	skipped = true
end)

------------------------------------------------------------------ animation
local started = os.clock()
local phase, phaseStart = "Loading", started
local shown = 0 -- what the bar shows (eases toward the real progress)
local speed = 1 -- train speed: 1 while loading, brakes to 0 when arriving
local messageIndex, messageAt = math.random(#MESSAGES), 0
local tipIndex, tipAt = math.random(#TIPS), -1
local rumble, greenLit, greenAt = nil, false, 0
local connection

local function finish()
	phase, phaseStart = "Opening", os.clock()
	sound("DoorOpen", 0.7)
	local info = TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	TweenService:Create(leftDoor, info, { Position = UDim2.fromScale(-0.52, 0) }):Play()
	TweenService:Create(rightDoor, info, { Position = UDim2.fromScale(1.02, 0) }):Play()
	TweenService:Create(vignette, TweenInfo.new(OPEN_TIME * 0.6), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(lampHousing, TweenInfo.new(OPEN_TIME * 0.5), { Position = UDim2.new(0.5, 0, 0, -60) }):Play()
	task.delay(OPEN_TIME + 0.1, function()
		connection:Disconnect()
		if rumble then
			rumble:Destroy()
		end
		gui:Destroy()
	end)
end

connection = RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local t = now - started
	local view = workspace.CurrentCamera.ViewportSize
	canvasScale.Scale = math.min(view.X / 1280, view.Y / 720)

	-- real progress: waiting for the game, then preloading; the bar never runs ahead of MIN_TIME
	local target
	if not gameLoaded then
		target = 0.08 + 0.12 * clamp01(t / 4)
	elseif not preloadDone then
		target = 0.2 + 0.78 * (toPreload > 0 and preloaded / toPreload or 1)
	else
		target = 1
	end
	if skipped then
		target = 1
	else
		target = math.min(target, t / MIN_TIME)
	end
	shown = math.max(shown, shown + (target - shown) * clamp01(dt * 5))
	if target >= 1 and shown > 0.995 then
		shown = 1
	end

	-- appear: logo, then the subtitle, then the line map
	logoScale.Scale = backOut((t - 0.15) / 0.6)
	subtitleScale.Scale = backOut((t - 0.45) / 0.5)
	progressScale.Scale = backOut((t - 0.6) / 0.5)
	fadeIn.BackgroundTransparency = clamp01(t / 0.45)
	logo.Rotation = -2 + math.sin(t * 1.2) * 1.2
	logo.Position = UDim2.fromOffset(640, LOGO_Y + math.sin(t * 1.7) * 5)
	local wobble = (t % 3.2) - 2.6 -- a quick shiver every 3.2 seconds
	for _, word in dieWords do
		word.Rotation = (wobble > 0 and wobble < 0.36) and math.sin(wobble * 55) * 5 * (1 - wobble / 0.36) or 0
	end

	-- line map
	fill.Size = UDim2.fromScale(shown, 1)
	sheen.Position = UDim2.new((t * 0.6) % 1.4 - 0.2, 0, 0.5, 0)
	trainMarker.Position = UDim2.fromOffset(shown * BAR_W, 62 + math.sin(t * 14) * 1.2 * speed)
	percent.Text = math.floor(shown * 100 + 0.5) .. "%"
	for _, d in dots do
		if not d.Lit and shown >= d.At - 0.001 and t > 0.7 then
			d.Lit, d.LitAt = true, now
			d.Dot.BackgroundColor3 = YELLOW
			d.Name.TextColor3 = WHITE
		end
		d.Scale.Scale = d.Lit and (1 + 0.45 * math.max(0, 1 - (now - d.LitAt) / 0.3)) or 1
	end

	-- status text and tips
	if phase == "Loading" then
		if t - messageAt > 1.5 then
			messageAt = t
			messageIndex = messageIndex % #MESSAGES + 1
		end
		status.Text = MESSAGES[messageIndex] .. string.rep(".", 1 + math.floor(t * 3) % 3)
	else
		status.Text = "Arriving at Central Station!"
	end
	if tipAt < 0 or t - tipAt > 4.5 then
		tipAt = math.max(t, 1)
		tipIndex = tipIndex % #TIPS + 1
		tip.Text = "💡 TIP: " .. TIPS[tipIndex]
	end
	local tipAge = t - tipAt
	local tipAlpha = clamp01(math.min(tipAge / 0.4, (4.5 - tipAge) / 0.4)) * clamp01((t - 1) / 0.4)
	tip.TextTransparency = 1 - tipAlpha
	tipStroke.Transparency = 1 - tipAlpha

	if t > SKIP_AFTER and phase == "Loading" then
		local a = clamp01((t - SKIP_AFTER) / 0.4)
		skipButton.Visible = true
		skipButton.BackgroundTransparency = 1 - 0.18 * a
		skipButton.TextTransparency = 1 - a
		skipStroke.Transparency = 1 - 0.6 * a
	end

	-- train rumble: everything on board shakes a tiny bit
	if not rumble and ReplicatedStorage:FindFirstChild("Sounds") then
		rumble = sound("Rumble", 0)
	end
	if rumble then
		rumble.Volume += (0.22 * speed - rumble.Volume) * clamp01(dt * 3)
	end
	shake.Position = UDim2.fromOffset(math.noise(t * 9, 0.5) * 2 * speed, math.noise(0.5, t * 9) * 1.5 * speed)

	-- tunnel rushing past the windows
	for _, v in views do
		for _, m in v.Movers do
			m.X -= m.Speed * speed * dt
			if m.X < -m.Margin then
				m.X += 1 + 2 * m.Margin + math.random() * 0.4
				if m.RerollY then
					m.Y = 0.08 + math.random() * 0.84
				end
			end
			m.Obj.Position = UDim2.fromScale(m.X, m.Y)
		end
	end

	-- door light
	if not greenLit then
		local blink = 0.5 + 0.5 * math.sin(t * 7)
		lamp.BackgroundTransparency = 0.1 + 0.35 * blink
		lampGlow.BackgroundTransparency = 0.7 + 0.2 * blink
	end
	lampScale.Scale = greenLit and (1 + 0.5 * clamp01(1 - (now - greenAt) / 0.3)) or 1

	-- phases
	if phase == "Loading" then
		local ready = preloadDone and shown >= 1 and t >= MIN_TIME
		-- Studio only: the workspace attribute HoldLoadingScreen keeps the screen up for a closer look
		local hold = RunService:IsStudio() and workspace:GetAttribute("HoldLoadingScreen") == true
		if (ready and not hold) or skipped or (t > GIVE_UP_AFTER and not hold) then
			phase, phaseStart = "Arriving", now
			shown = math.max(shown, target)
			sound("Squeal", 0.25)
		end
	elseif phase == "Arriving" then
		-- brake into the station: the tunnel slows down and station light fills the windows
		local a = clamp01((now - phaseStart) / (ARRIVE_TIME - 0.3))
		speed = (1 - a) ^ 2.2
		for _, v in views do
			v.Station.BackgroundTransparency = 1 - 0.82 * a
		end
		skipButton.Visible = false
		if not greenLit and now - phaseStart > 0.8 then
			greenLit, greenAt = true, now
			lamp.BackgroundColor3 = GREEN
			lamp.BackgroundTransparency = 0
			lampGlow.BackgroundColor3 = GREEN
			lampGlow.BackgroundTransparency = 0.6
			sound("Switch", 0.6)
		end
		content.GroupTransparency = clamp01((now - phaseStart - 0.85) / 0.5)
		if now - phaseStart >= ARRIVE_TIME then
			finish()
		end
	end
end)
