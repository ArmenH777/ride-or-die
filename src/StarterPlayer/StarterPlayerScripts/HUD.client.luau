-- Ride or Die HUD (in-ride): route bar, passenger faces, track alerts, warnings, messages,
-- speed + driver controls, tokens and the countdown / results window.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local RoundState = ReplicatedStorage:WaitForChild("RoundState")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local train = workspace:WaitForChild("Train")
local driverSeat = train:WaitForChild("Cab"):WaitForChild("DriverSeat")

local C = UI.Colors
local new, text = UI.new, UI.text
local KIND_COLORS = {
	Good = Color3.fromRGB(110, 245, 130),
	Bad = Color3.fromRGB(255, 95, 85),
	Warn = Color3.fromRGB(255, 195, 60),
	Info = C.White,
}

local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

-- everything in rideLayer only shows while you're on the train (not in the lobby)
local powerTint = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 0, 0), BackgroundTransparency = 1, Parent = gui })
local rideLayer = new("Frame", { Name = "Ride", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
powerTint.Parent = rideLayer

------------------------------------------------------------------ route bar (top centre)
local ROUTE_W = 520
local route = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(ROUTE_W, 44),
	BackgroundColor3 = Color3.fromRGB(245, 248, 255), Parent = rideLayer,
}, { UI.corner(12), UI.stroke(C.Blue, 4) })
local TRACK_X, TRACK_W = 16, ROUTE_W - 32
local track = new("Frame", { Position = UDim2.fromOffset(TRACK_X, 7), Size = UDim2.fromOffset(TRACK_W, 16), Parent = route }, {
	UI.corner(8), UI.stroke(C.Outline, 2),
	new("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 205, 95)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(250, 220, 50)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 150, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 50, 50)),
	}) }),
})
for _, station in Config.Stations do
	local x = TRACK_X + station.Mile / Config.RouteMiles * TRACK_W
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 15), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.White, ZIndex = 2, Parent = route }, { UI.corner(5), UI.stroke(C.Outline, 2) })
	text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, 25), Size = UDim2.fromOffset(110, 16), Text = station.Name, TextSize = 12, TextColor3 = Color3.fromRGB(40, 55, 90), Outline = false, Parent = route })
end
local trainIcon = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(TRACK_X, 14), Size = UDim2.fromOffset(34, 34), Text = "🚇", TextSize = 30, ZIndex = 3, Outline = false, Parent = route })

local distancePill = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.fromOffset(240, 28),
	BackgroundColor3 = C.Dark, BackgroundTransparency = 0.15, Parent = rideLayer,
}, { UI.corner(14) })
local distanceText = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 18, Parent = distancePill })

------------------------------------------------------------------ passenger faces
local facePill = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.fromOffset(240, 60),
	BackgroundColor3 = C.Dark, BackgroundTransparency = 0.25, Parent = rideLayer,
}, { UI.corner(14) })
local faceRow = new("Frame", { Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -16, 0, 32), BackgroundTransparency = 1, Parent = facePill }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local passengerCount = text({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 18), Text = "", TextSize = 15, Parent = facePill })
local faces = {}

------------------------------------------------------------------ track alert
local alert = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 152), Size = UDim2.fromOffset(470, 36),
	BackgroundColor3 = C.Orange, Visible = false, Parent = rideLayer,
}, { UI.corner(10), UI.stroke(C.Outline, 3) })
UI.gloss(alert)
local alertText = text({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Text = "", TextSize = 18, TextScaled = false, TextWrapped = true, Parent = alert })

------------------------------------------------------------------ warnings (right side)
local warnings = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 200), Size = UDim2.fromOffset(300, 400), BackgroundTransparency = 1, Parent = rideLayer }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
})

------------------------------------------------------------------ message feed (centre bottom, above the hotbar)
local feed = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(700, 140), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local feedOrder = 0

------------------------------------------------------------------ speed (bottom left)
local speedPanel = new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(220, 66),
	BackgroundColor3 = C.Navy, BackgroundTransparency = 0.05, Parent = rideLayer,
}, { UI.corner(14), UI.stroke(C.White, 3) })
local speedIcon = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = C.Blue, Parent = speedPanel }, { UI.corner(25), UI.stroke(C.Outline, 3) })
text({ Size = UDim2.fromScale(1, 1), Text = "🚇", TextSize = 28, Outline = false, Parent = speedIcon })
local speedText = text({ Position = UDim2.fromOffset(66, 4), Size = UDim2.fromOffset(146, 32), Text = "0 MPH", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Parent = speedPanel })
local throttleBack = new("Frame", { Position = UDim2.fromOffset(66, 40), Size = UDim2.fromOffset(144, 16), BackgroundColor3 = C.Dark, Parent = speedPanel }, { UI.corner(8), UI.stroke(C.White, 2) })
local throttleFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Green, Parent = throttleBack }, { UI.corner(8) })
text({ Size = UDim2.fromScale(1, 1), Text = "THROTTLE", TextSize = 11, ZIndex = 2, Parent = throttleBack })

------------------------------------------------------------------ driver controls (above the speed panel)
local driverPanel = new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -88), Size = UDim2.fromOffset(220, 128),
	BackgroundColor3 = C.Navy, BackgroundTransparency = 0.05, Visible = false, Parent = rideLayer,
}, { UI.corner(14), UI.stroke(C.Yellow, 3) })
text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 22), Text = "YOU'RE DRIVING", TextSize = 20, TextColor3 = C.Yellow, Parent = driverPanel })
local upButton = UI.button({ Position = UDim2.fromOffset(10, 30), Size = UDim2.fromOffset(60, 40), Text = "▲", TextSize = 22 }, C.Green)
upButton.Parent = driverPanel
local downButton = UI.button({ Position = UDim2.fromOffset(10, 76), Size = UDim2.fromOffset(60, 40), Text = "▼", TextSize = 22 }, C.Red)
downButton.Parent = driverPanel
text({ Position = UDim2.fromOffset(78, 28), Size = UDim2.fromOffset(134, 18), Text = "TRACK SWITCH", TextSize = 14, Parent = driverPanel })
local leftButton = UI.button({ Position = UDim2.fromOffset(78, 48), Size = UDim2.fromOffset(64, 36), Text = "◀ L", TextSize = 18 }, C.Blue)
leftButton.Parent = driverPanel
local rightButton = UI.button({ Position = UDim2.fromOffset(148, 48), Size = UDim2.fromOffset(64, 36), Text = "R ▶", TextSize = 18 }, C.Blue)
rightButton.Parent = driverPanel
text({ Position = UDim2.fromOffset(78, 88), Size = UDim2.fromOffset(134, 34), Text = "W/S throttle • A/D track\nJump to leave", TextSize = 11, TextWrapped = true, Parent = driverPanel })

------------------------------------------------------------------ tokens (bottom right)
local tokens = new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -14), Size = UDim2.fromOffset(150, 40),
	BackgroundColor3 = C.Dark, BackgroundTransparency = 0.1, Parent = gui,
}, { UI.corner(20), UI.stroke(C.Outline, 3) })
local coin = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(4, 20), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = C.Yellow, ZIndex = 2, Parent = tokens }, { UI.corner(25), UI.stroke(C.Outline, 3) })
UI.gloss(coin)
text({ Size = UDim2.fromScale(1, 1), Text = "🎫", TextSize = 26, ZIndex = 3, Outline = false, Parent = coin })
local tokenText = text({ Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -38, 1, 0), Text = "0", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right, Parent = tokens })

------------------------------------------------------------------ countdown / results window
local overlay = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(470, 250),
	BackgroundColor3 = Color3.fromRGB(235, 242, 250), Visible = false, Parent = rideLayer,
}, { UI.corner(16), UI.stroke(C.Blue, 4) })
local overlayHeader = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.Blue, Parent = overlay }, { UI.corner(14) })
UI.gloss(overlayHeader)
local overlayTitle = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 34, Font = UI.TitleFont, Outline = 3, Parent = overlayHeader })
local overlayBody = text({ Position = UDim2.fromOffset(20, 68), Size = UDim2.new(1, -40, 1, -78), Text = "", TextSize = 19, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(30, 50, 80), Outline = false, Parent = overlay })
local overlayScale = new("UIScale", { Parent = overlay })

------------------------------------------------------------------ messages
local soundTemplates = ReplicatedStorage:WaitForChild("Sounds")
local function playUiSound(name)
	local template = name and soundTemplates:FindFirstChild(name)
	if template then
		local sound = template:Clone()
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end
end

local function pushMessage(kind, message, sound)
	playUiSound(sound)
	feedOrder += 1
	local label = text({
		Size = UDim2.fromOffset(700, 28), Text = message, TextSize = 22, LayoutOrder = feedOrder,
		TextColor3 = KIND_COLORS[kind] or C.White, Parent = feed,
	})
	local items = {}
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(items, child)
		end
	end
	if #items > 4 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(4, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			local outline = label:FindFirstChildOfClass("UIStroke")
			if outline then
				TweenService:Create(outline, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
			task.wait(0.6)
			label:Destroy()
		end
	end)
end
Remotes.Notify.OnClientEvent:Connect(pushMessage)

------------------------------------------------------------------ warnings
local URGENT = { Power = true, Fire = true }
local function refreshWarnings()
	for _, child in warnings:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local ok, counts = pcall(HttpService.JSONDecode, HttpService, RoundState:GetAttribute("Breakdowns") or "{}")
	if not ok then
		return
	end
	local order = 0
	for kind, count in counts do
		order += 1
		local cfg = Config.Breakdowns[kind]
		local card = new("Frame", {
			Size = UDim2.fromOffset(286, 40), LayoutOrder = order,
			BackgroundColor3 = URGENT[kind] and C.Red or C.Orange, Parent = warnings,
		}, { UI.corner(10), UI.stroke(C.Outline, 3) })
		UI.gloss(card)
		local badge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.Yellow, ZIndex = 2, Parent = card }, { UI.corner(20), UI.stroke(C.Outline, 3) })
		text({ Size = UDim2.fromScale(1, 1), Text = "!", TextSize = 28, TextColor3 = C.Outline, Outline = false, ZIndex = 3, Font = UI.TitleFont, Parent = badge })
		text({
			Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -36, 1, 0), Text = cfg.Label .. (count > 1 and (" x" .. count) or ""),
			TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
		})
	end
end
RoundState:GetAttributeChangedSignal("Breakdowns"):Connect(refreshWarnings)
refreshWarnings()

------------------------------------------------------------------ passengers
local function refreshPassengers()
	local list = {}
	local folder = workspace:FindFirstChild("Passengers")
	if folder then
		for _, model in folder:GetChildren() do
			if model:GetAttribute("Index") then
				list[model:GetAttribute("Index")] = model
			end
		end
	end
	local total = RoundState:GetAttribute("PassengersTotal") or 0
	for i = 1, math.max(total, #faces) do
		local face = faces[i]
		if i > total then
			if face then
				face.Frame.Visible = false
			end
			continue
		end
		if not face then
			local frame = new("Frame", { Size = UDim2.fromOffset(30, 30), LayoutOrder = i, Parent = faceRow }, { UI.corner(8) })
			local stroke = UI.stroke(C.Outline, 2)
			stroke.Parent = frame
			local label = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 20, Outline = false, Parent = frame })
			face = { Frame = frame, Label = label, Stroke = stroke }
			faces[i] = face
		end
		face.Frame.Visible = true
		local model = list[i]
		local vip = model and model:GetAttribute("VIP")
		face.Stroke.Color = vip and C.Yellow or C.Outline
		face.Stroke.Thickness = vip and 3 or 2
		if model and model:GetAttribute("State") == "Seated" then
			local mood = Config.MoodFor(model:GetAttribute("Fear") or 0)
			face.Label.Text = mood.Face
			face.Frame.BackgroundColor3 = mood.Color
		else
			face.Label.Text = "💨"
			face.Frame.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		end
	end
	facePill.Size = UDim2.fromOffset(math.max(220, total * 34 + 20), 60)
	passengerCount.Text = "PASSENGERS: " .. (RoundState:GetAttribute("PassengersLeft") or 0) .. " / " .. total
end

------------------------------------------------------------------ driving input
local keys = { Up = false, Down = false, ButtonUp = false, ButtonDown = false }
local sentInput = 0

local function isDriving()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart == driverSeat
end

local function sendInput()
	local input = 0
	if isDriving() then
		if keys.Up or keys.ButtonUp then
			input += 1
		end
		if keys.Down or keys.ButtonDown then
			input -= 1
		end
	end
	if input ~= sentInput then
		sentInput = input
		Remotes.DriverInput:FireServer(input)
	end
end

local function switchTrack(side)
	if isDriving() then
		Remotes.SwitchTrack:FireServer(side)
	end
end

local KEYMAP = { [Enum.KeyCode.W] = "Up", [Enum.KeyCode.Up] = "Up", [Enum.KeyCode.S] = "Down", [Enum.KeyCode.Down] = "Down" }
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = KEYMAP[input.KeyCode]
	if key then
		keys[key] = true
		sendInput()
	elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		switchTrack("Left")
	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		switchTrack("Right")
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local key = KEYMAP[input.KeyCode]
	if key then
		keys[key] = false
		sendInput()
	end
end)
for button, key in { [upButton] = "ButtonUp", [downButton] = "ButtonDown" } do
	button.MouseButton1Down:Connect(function()
		keys[key] = true
		sendInput()
	end)
	button.MouseButton1Up:Connect(function()
		keys[key] = false
		sendInput()
	end)
	button.MouseLeave:Connect(function()
		keys[key] = false
		sendInput()
	end)
end
leftButton.Activated:Connect(function()
	switchTrack("Left")
end)
rightButton.Activated:Connect(function()
	switchTrack("Right")
end)

------------------------------------------------------------------ track alert logic
local events = {}
local function loadEvents()
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, RoundState:GetAttribute("TrackEvents") or "[]")
	events = ok and decoded or {}
end
RoundState:GetAttributeChangedSignal("TrackEvents"):Connect(loadEvents)
loadEvents()

local function feet(miles)
	return math.max(0, math.floor(miles * 5280 / 10) * 10) .. " ft"
end

-- Returns text, colour (or nil when there's nothing to say).
local function trackAlert(distance, speed)
	local red, amber, green = C.Red, C.Orange, C.Green
	for _, e in events do
		if e.Type == "Split" then
			if RoundState:GetAttribute("SplitWrong") == e.Id then
				return "💥 WRONG TRACK! BRACE FOR IMPACT!", red
			end
			local ahead = e.Mile - distance
			if ahead > 0 and ahead < Config.SplitWarning then
				local switch = RoundState:GetAttribute("Switch") or "Right"
				local right = switch == e.Correct
				return string.format("⚠ JUNCTION in %s: take %s!  Track: %s %s", feet(ahead), e.Correct:upper(), switch:upper(), right and "✔" or "✖ (A / D)"), right and green or red
			end
		end
	end
	for _, e in events do
		if e.Type == "Curve" and distance >= e.Start and distance <= e.End then
			local tooFast = speed > e.Limit + 3
			return "↪ IN A CURVE: max " .. e.Limit .. " mph" .. (tooFast and " - SLOW DOWN!" or ""), tooFast and red or amber
		end
	end
	for _, e in events do
		if e.Type == "Signal" then
			local ahead = e.Mile - distance
			if ahead > -0.001 and ahead < 0.3 then
				if RoundState:GetAttribute("Signal" .. e.Id) == "Green" then
					return "🟢 Signal is green, go!", green
				end
				return "🚦 RED SIGNAL in " .. feet(ahead) .. ": stop and wait!", red
			end
		elseif e.Type == "Curve" then
			local ahead = e.Start - distance
			if ahead > 0 and ahead < 0.25 then
				return "↪ CURVE in " .. feet(ahead) .. ": slow to " .. e.Limit .. " mph", amber
			end
		end
	end
	if RoundState:GetAttribute("Driver") == "" and speed < 1 then
		return "🚇 Nobody is driving! Sit in the seat in the cab (front).", amber
	end
	if RoundState:GetAttribute("Power") == false then
		return "⚡ No power! Flip the breaker by the cab door.", red
	end
	for i, station in Config.Stations do
		local ahead = station.Mile - distance
		if i == #Config.Stations and ahead < 0.25 then
			return "🏁 Arriving at " .. station.Name .. "!", green
		elseif i > 1 and math.abs(ahead) < 0.06 then
			return "Passing " .. station.Name, C.Blue
		end
	end
	return nil
end

------------------------------------------------------------------ main update loop
local resultsEndsAt = 0
RoundState:GetAttributeChangedSignal("State"):Connect(function()
	if RoundState:GetAttribute("State") == "Ended" then
		resultsEndsAt = os.clock() + Config.ResultsTime
	end
end)

local RESULT_TITLES = {
	Win = { "YOU MADE IT! 🎉", C.Green },
	Lose = { "EVERYONE FLED! 😱", C.Red },
	Crash = { "YOU CRASHED! 💥", C.Red },
	Abandoned = { "RIDE OVER", C.Blue },
}

local screen = train.Cab:FindFirstChild("Screen")
local screenText = screen and screen:FindFirstChild("Speed", true)
local slowTimer = 0

RunService.RenderStepped:Connect(function(dt)
	rideLayer.Visible = player:GetAttribute("InRide") == true
	local state = RoundState:GetAttribute("State") or "Waiting"
	local distance = RoundState:GetAttribute("Distance") or 0
	local speed = RoundState:GetAttribute("Speed") or 0
	local throttle = RoundState:GetAttribute("Throttle") or 0
	local remaining = math.max(0, Config.RouteMiles - distance)
	local final = Config.Stations[#Config.Stations].Name

	local frac = math.clamp(distance / Config.RouteMiles, 0, 1)
	trainIcon.Position = UDim2.fromOffset(TRACK_X + frac * TRACK_W, 14)
	distanceText.Text = string.format("%.2f mi away", remaining)

	speedText.Text = math.floor(speed + 0.5) .. " MPH"
	throttleFill.Size = UDim2.fromScale(throttle, 1)
	if screenText then
		screenText.Text = string.format("%d MPH\nTHR %d%%", math.floor(speed + 0.5), math.floor(throttle * 100 + 0.5))
	end
	driverPanel.Visible = isDriving()
	if not driverPanel.Visible and sentInput ~= 0 then
		sendInput()
	end
	local switch = RoundState:GetAttribute("Switch")
	leftButton.BackgroundColor3 = switch == "Left" and C.Cyan or C.Blue
	rightButton.BackgroundColor3 = switch == "Right" and C.Cyan or C.Blue

	local message, color
	if state == "Running" then
		message, color = trackAlert(distance, speed)
	end
	alert.Visible = message ~= nil
	warnings.Visible = state == "Running"
	if message then
		alertText.Text = message
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 6)
		alert.BackgroundColor3 = color:Lerp(C.White, 0.12 * pulse)
	end

	local power = RoundState:GetAttribute("Power") ~= false
	powerTint.BackgroundTransparency = power and 1 or (0.82 + 0.08 * math.sin(os.clock() * 4))

	local viewport = workspace.CurrentCamera.ViewportSize
	overlayScale.Scale = math.min(1, (viewport.X - 24) / 470, (viewport.Y - 40) / 250)
	if state == "Countdown" then
		overlay.Visible = true
		overlayTitle.Text = "DOORS CLOSE IN " .. (RoundState:GetAttribute("Countdown") or 0)
		overlayBody.Text = "🚇 Drive from the cab (W / S, A / D at junctions).\n🥪 Grab snacks at the back and HOLD them to feed passengers.\n🔧 Grab tools, hold the right one and fix what breaks.\n⭐ Keep the VIP happy for a bonus!"
	elseif state == "Ended" then
		overlay.Visible = true
		local result = RESULT_TITLES[RoundState:GetAttribute("Result")] or RESULT_TITLES.Abandoned
		overlayTitle.Text = result[1]
		overlayHeader.BackgroundColor3 = result[2]
		local t = RoundState:GetAttribute("RideTime") or 0
		local vip = RoundState:GetAttribute("VIPBonus") or 0
		overlayBody.Text = string.format(
			"Passengers saved: %d / %d\nRepairs: %d    Snacks served: %d\nRide time: %d:%02d\n+%d Tokens%s\n\nBack to the station in %d...",
			RoundState:GetAttribute("Saved") or 0, RoundState:GetAttribute("PassengersTotal") or 0,
			RoundState:GetAttribute("Fixes") or 0, RoundState:GetAttribute("Feeds") or 0,
			t // 60, t % 60, RoundState:GetAttribute("Reward") or 0, vip > 0 and ("   ⭐ VIP bonus +" .. vip) or "",
			math.max(0, math.ceil(resultsEndsAt - os.clock()))
		)
	elseif state == "Returning" then
		overlay.Visible = true
		overlayTitle.Text = "ALL CHANGE!"
		overlayHeader.BackgroundColor3 = C.Blue
		overlayBody.Text = "Heading back to Central Station..."
	else
		overlay.Visible = false
	end
	if state ~= "Ended" then
		overlayHeader.BackgroundColor3 = C.Blue
	end

	slowTimer += dt
	if slowTimer >= 0.25 then
		slowTimer = 0
		refreshPassengers()
		local stats = player:FindFirstChild("leaderstats")
		local t = stats and stats:FindFirstChild("Tokens")
		tokenText.Text = tostring(t and t.Value or 0)
	end
end)
