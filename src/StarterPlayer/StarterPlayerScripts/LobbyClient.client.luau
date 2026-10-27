-- Lobby UI: hint + open trains list (top centre), matchmaking window and the "leaving in" panel (bottom centre).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local padsFolder = workspace:WaitForChild("Lobby"):WaitForChild("Pads")
local C = UI.Colors
local new, text = UI.new, UI.text

local gui = new("ScreenGui", { Name = "LobbyUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

------------------------------------------------------------------ top centre: hint + open trains
local top = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(480, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
local topScale = new("UIScale", { Parent = top })
local hint = new("Frame", { Size = UDim2.fromOffset(480, 44), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, LayoutOrder = 0, Parent = top }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
})
text({ Size = UDim2.fromScale(1, 1), Text = "🚇 Step on a glowing platform to host a ride!", TextSize = 21, Parent = hint })
local listTitle = text({ Size = UDim2.fromOffset(380, 32), Text = "OPEN TRAINS - HOP ON!", TextSize = 26, Font = UI.TitleFont, Outline = 2.5, LayoutOrder = 1, Parent = top })
local cards = {}

local function card(index)
	local c = new("Frame", { Size = UDim2.fromOffset(380, 56), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.12, LayoutOrder = 1 + index, Parent = top }, { UI.corner(14), UI.stroke(C.Outline, 2) })
	local tag = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(92, 40), BackgroundColor3 = C.Grey, Parent = c }, { UI.corner(10), UI.stroke(C.Outline, 2) })
	UI.gloss(tag)
	local tagText = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 18, Parent = tag })
	local title = text({ Position = UDim2.fromOffset(110, 6), Size = UDim2.fromOffset(170, 24), Text = "", TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
	local detail = text({
		Position = UDim2.fromOffset(110, 30), Size = UDim2.fromOffset(170, 20), Text = "", TextSize = 15, TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = c,
	})
	local join = UI.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(86, 40), Text = "JOIN", TextSize = 22, Parent = c }, C.Lime)
	join.Activated:Connect(function()
		Remotes.JoinPad:FireServer(index)
	end)
	cards[index] = { Frame = c, Tag = tag, TagText = tagText, Title = title, Detail = detail }
	return cards[index]
end

------------------------------------------------------------------ matchmaking window (opens when you step on a free platform)
local W = 480
local menu = UI.window({
	Title = "MATCHMAKING", Icon = "🚇", Width = W, Height = 330, Parent = gui,
	-- closing it with the X (or by opening another window) means you're not hosting after all
	OnClose = function()
		Remotes.PadCancel:FireServer()
	end,
})
local body = menu.Body

local function rowLabel(y, title, subtitle)
	text({ Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(240, 26), Text = title, TextSize = 23, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
	text({ Position = UDim2.fromOffset(24, y + 26), Size = UDim2.fromOffset(260, 18), Text = subtitle, TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
end

local choice = { Max = 4, Difficulty = "Easy", FriendsOnly = false }

-- players
rowLabel(22, "PLAYERS", "More players = more passengers")
local minus = UI.button({ Position = UDim2.fromOffset(W - 206, 22), Size = UDim2.fromOffset(46, 44), Text = "-", TextSize = 40, Parent = body }, C.Blue)
local count = text({ Position = UDim2.fromOffset(W - 156, 22), Size = UDim2.fromOffset(62, 44), Text = "4", TextSize = 38, Font = UI.TitleFont, Outline = 2.5, Parent = body })
local plus = UI.button({ Position = UDim2.fromOffset(W - 90, 22), Size = UDim2.fromOffset(46, 44), Text = "+", TextSize = 36, Parent = body }, C.Blue)

-- difficulty
rowLabel(86, "DIFFICULTY", "Harder rides pay more Tokens")
local difficultyButtons = {}
local DW = (W - 48 - 3 * 8) / 4
for i, name in Config.DifficultyOrder do
	local d = Config.Difficulties[name]
	local b = UI.button({
		Position = UDim2.fromOffset(24 + (i - 1) * (DW + 8), 136), Size = UDim2.fromOffset(DW, 52),
		Text = name .. "\nx" .. d.Reward .. " 🎫", TextSize = 17, Parent = body,
	}, d.Color)
	difficultyButtons[name] = { Button = b, Stroke = UI.border(b) }
end

-- friends only
rowLabel(204, "FRIENDS ONLY?", "Only your friends can join")
local friendsButton = UI.button({ Position = UDim2.fromOffset(W - 154, 206), Size = UDim2.fromOffset(124, 42), Text = "OFF", TextSize = 22, Parent = body }, C.Grey)

local startButton = UI.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(240, 58), Text = "START!", TextSize = 34, Parent = body }, C.Lime)

local function refreshMenu()
	count.Text = tostring(choice.Max)
	for name, b in difficultyButtons do
		local on = name == choice.Difficulty
		b.Stroke.Color = on and C.White or C.Outline
		b.Stroke.Thickness = on and 4 or 3
		b.Button.BackgroundTransparency = on and 0 or 0.45
	end
	friendsButton.Text = choice.FriendsOnly and "ON" or "OFF"
	friendsButton.BackgroundColor3 = choice.FriendsOnly and C.Lime or C.Grey
end
refreshMenu()

minus.Activated:Connect(function()
	choice.Max = math.max(1, choice.Max - 1)
	refreshMenu()
end)
plus.Activated:Connect(function()
	choice.Max = math.min(Config.MaxPartySize, choice.Max + 1)
	refreshMenu()
end)
for name, b in difficultyButtons do
	b.Button.Activated:Connect(function()
		choice.Difficulty = name
		refreshMenu()
	end)
end
friendsButton.Activated:Connect(function()
	choice.FriendsOnly = not choice.FriendsOnly
	refreshMenu()
end)
startButton.Activated:Connect(function()
	menu.Frame.Visible = false
	Remotes.PadSetup:FireServer(choice)
end)
Remotes.OpenMatchmaking.OnClientEvent:Connect(function()
	refreshMenu()
	menu.Open()
end)
Remotes.CloseMatchmaking.OnClientEvent:Connect(function()
	menu.Frame.Visible = false
end)

------------------------------------------------------------------ "leaving in" panel (bottom centre) while waiting on a pad
local waiting = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(400, 116),
	BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08, Visible = false, Parent = gui,
}, { UI.corner(18), UI.stroke(C.Outline, 3) })
local waitScale = new("UIScale", { Parent = waiting })
local waitTitle = text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 17, TextColor3 = C.Muted, Parent = waiting })
local waitTimer = text({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 34), Text = "", TextSize = 32, Font = UI.TitleFont, TextColor3 = C.Yellow, Outline = 2.5, Parent = waiting })
local leaveButton = UI.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, 91, 0, 70), Size = UDim2.fromOffset(150, 36), Text = "LEAVE", TextSize = 19, Parent = waiting }, C.Red)
local departButton = UI.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 70), Size = UDim2.fromOffset(200, 36), Text = "DEPART NOW", TextSize = 19, Parent = waiting }, C.Lime)
leaveButton.Activated:Connect(function()
	Remotes.PadCancel:FireServer()
end)
departButton.Activated:Connect(function()
	Remotes.DepartNow:FireServer()
end)

------------------------------------------------------------------ update
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local rideDensity = atmosphere and atmosphere.Density or 0.42

RunService.RenderStepped:Connect(function()
	local inRide = player:GetAttribute("InRide") == true
	local padId = player:GetAttribute("PadId")
	local now = workspace:GetServerTimeNow()
	if atmosphere then
		atmosphere.Density = inRide and rideDensity or 0.12
	end
	-- keep the camera close: inside the train you can't zoom out past the tunnel
	local maxZoom = inRide and 12 or 28
	if player.CameraMaxZoomDistance ~= maxZoom then
		player.CameraMaxZoomDistance = maxZoom
	end
	if inRide then
		menu.Frame.Visible = false
	end
	local view = workspace.CurrentCamera.ViewportSize
	local fit = math.clamp(math.min(view.X / 900, (view.Y - 60) / 640), 0.6, 1)
	topScale.Scale = fit
	waitScale.Scale = fit

	-- waiting panel
	local myPad = padId and padsFolder:FindFirstChild("Pad" .. padId)
	if myPad and myPad:GetAttribute("State") == "Open" and not inRide then
		waiting.Visible = true
		waitTitle.Text = string.format("PLATFORM %d  •  %s  •  %d/%d PLAYERS", padId, string.upper(myPad:GetAttribute("Difficulty")), myPad:GetAttribute("Count"), myPad:GetAttribute("Max"))
		if myPad:GetAttribute("Waiting") then
			waitTimer.Text = "WAITING FOR THE TRAIN..."
		else
			waitTimer.Text = "LEAVING IN " .. math.max(0, math.ceil(myPad:GetAttribute("LeaveAt") - now)) .. "s"
		end
		departButton.Visible = myPad:GetAttribute("HostId") == player.UserId
	elseif myPad and myPad:GetAttribute("State") == "Launching" then
		waiting.Visible = true
		waitTimer.Text = "DEPARTING!"
		departButton.Visible = false
	else
		waiting.Visible = false
	end
	-- LEAVE sits in the middle when there's no DEPART NOW button
	leaveButton.Position = departButton.Visible and UDim2.new(0, 91, 0, 70) or UDim2.new(0.5, 0, 0, 70)

	-- hint + open trains list
	top.Visible = not inRide and not padId and not UI.anyWindowOpen()
	local any = false
	for _, model in padsFolder:GetChildren() do
		local index = model:GetAttribute("Index")
		local open = model:GetAttribute("State") == "Open" and (model:GetAttribute("Count") or 0) < (model:GetAttribute("Max") or 0)
		local c = cards[index]
		if open then
			any = true
			c = c or card(index)
			c.Frame.Visible = true
			local difficulty = model:GetAttribute("Difficulty")
			local d = Config.Difficulties[difficulty]
			c.TagText.Text = difficulty
			c.Tag.BackgroundColor3 = d and d.Color or C.Grey
			c.Title.Text = "Platform " .. index
			c.Detail.Text = string.format("%s  •  %d/%d  •  %ds", model:GetAttribute("Host"), model:GetAttribute("Count"), model:GetAttribute("Max"), math.max(0, math.ceil((model:GetAttribute("LeaveAt") or 0) - now)))
		elseif c then
			c.Frame.Visible = false
		end
	end
	listTitle.Visible = any
end)
