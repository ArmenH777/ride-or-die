-- Lobby UI: matchmaking menu, "leaving in" panel, open trains list and the lobby hint.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local padsFolder = workspace:WaitForChild("Lobby"):WaitForChild("Pads")

local FONT = Enum.Font.FredokaOne
local NAVY = Color3.fromRGB(22, 26, 46)
local BLUE = Color3.fromRGB(30, 120, 210)
local WHITE = Color3.new(1, 1, 1)

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
local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end
local function stroke(color, thickness)
	return new("UIStroke", { Color = color or WHITE, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
-- shared cartoon style (outlined text, glossy outlined buttons)
local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local function text(props)
	return UI.text(props)
end
local function button(props)
	local color = props.BackgroundColor3
	props.BackgroundColor3 = nil
	return UI.button(props, color)
end

local gui = new("ScreenGui", { Name = "LobbyUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

------------------------------------------------------------------ hint (top centre)
local hint = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(460, 40),
	BackgroundColor3 = NAVY, BackgroundTransparency = 0.1, Parent = gui,
}, { corner(20), stroke(Color3.fromRGB(150, 80, 230), 2) })
text({ Size = UDim2.fromScale(1, 1), Text = "🚇 Step on a glowing platform to host a ride!", TextSize = 18, Parent = hint })

------------------------------------------------------------------ matchmaking menu
local menu = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 330),
	BackgroundColor3 = Color3.fromRGB(235, 242, 250), Visible = false, Parent = gui,
}, { corner(14), stroke(BLUE, 4) })
local header = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = BLUE, Parent = menu }, { corner(12) })
text({ Size = UDim2.fromScale(1, 1), Text = "MATCHMAKING", TextSize = 28, TextStrokeTransparency = 0.5, Parent = header })
local closeButton = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(36, 36), Text = "X", TextSize = 22, BackgroundColor3 = Color3.fromRGB(220, 50, 50), Parent = header })

local function rowLabel(y, title, subtitle)
	text({ Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(200, 22), Text = title, TextSize = 20, TextColor3 = Color3.fromRGB(30, 50, 80), TextXAlignment = Enum.TextXAlignment.Left, Parent = menu })
	text({ Position = UDim2.fromOffset(20, y + 22), Size = UDim2.fromOffset(220, 16), Text = subtitle, TextSize = 12, TextColor3 = Color3.fromRGB(90, 110, 140), TextXAlignment = Enum.TextXAlignment.Left, Parent = menu })
end

local choice = { Max = 4, Difficulty = "Easy", FriendsOnly = false }

-- players
rowLabel(66, "PLAYERS", "More players = more passengers")
local minus = button({ Position = UDim2.fromOffset(270, 68), Size = UDim2.fromOffset(36, 36), Text = "◀", TextSize = 18, BackgroundColor3 = BLUE, Parent = menu })
local count = text({ Position = UDim2.fromOffset(310, 68), Size = UDim2.fromOffset(60, 36), Text = "4", TextSize = 26, TextColor3 = Color3.fromRGB(30, 50, 80), Parent = menu })
local plus = button({ Position = UDim2.fromOffset(374, 68), Size = UDim2.fromOffset(36, 36), Text = "▶", TextSize = 18, BackgroundColor3 = BLUE, Parent = menu })

-- difficulty
rowLabel(122, "DIFFICULTY", "Harder rides pay more Tokens")
local difficultyButtons = {}
for i, name in Config.DifficultyOrder do
	local d = Config.Difficulties[name]
	local b = button({
		Position = UDim2.fromOffset(20 + (i - 1) * 102, 162), Size = UDim2.fromOffset(96, 40),
		Text = name .. "\nx" .. d.Reward, TextSize = 15, BackgroundColor3 = d.Color, Parent = menu,
	})
	local s = stroke(Color3.fromRGB(30, 50, 80), 0)
	s.Parent = b
	difficultyButtons[name] = { Button = b, Stroke = s }
end

-- friends only
rowLabel(214, "FRIENDS ONLY?", "Only your friends can join")
local friendsButton = button({ Position = UDim2.fromOffset(300, 216), Size = UDim2.fromOffset(110, 36), Text = "OFF", TextSize = 18, BackgroundColor3 = Color3.fromRGB(150, 155, 165), Parent = menu })

local startButton = button({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 268), Size = UDim2.fromOffset(200, 48),
	Text = "START", TextSize = 28, BackgroundColor3 = Color3.fromRGB(60, 190, 90), Parent = menu,
})
stroke(Color3.fromRGB(20, 90, 40), 3).Parent = startButton

local function refreshMenu()
	count.Text = tostring(choice.Max)
	for name, b in difficultyButtons do
		b.Stroke.Thickness = name == choice.Difficulty and 4 or 0
		b.Button.BackgroundTransparency = name == choice.Difficulty and 0 or 0.35
	end
	friendsButton.Text = choice.FriendsOnly and "ON" or "OFF"
	friendsButton.BackgroundColor3 = choice.FriendsOnly and Color3.fromRGB(60, 190, 90) or Color3.fromRGB(150, 155, 165)
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
	menu.Visible = false
	Remotes.PadSetup:FireServer(choice)
end)
closeButton.Activated:Connect(function()
	menu.Visible = false
	Remotes.PadCancel:FireServer()
end)
Remotes.OpenMatchmaking.OnClientEvent:Connect(function()
	refreshMenu()
	menu.Visible = true
end)
Remotes.CloseMatchmaking.OnClientEvent:Connect(function()
	menu.Visible = false
end)

------------------------------------------------------------------ "leaving in" panel (bottom left) while waiting on a pad
local waiting = new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(300, 96),
	BackgroundColor3 = NAVY, BackgroundTransparency = 0.1, Visible = false, Parent = gui,
}, { corner(12), stroke(Color3.fromRGB(255, 185, 50), 2) })
local waitTitle = text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = waiting })
local waitTimer = text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 26), Text = "", TextSize = 24, TextColor3 = Color3.fromRGB(255, 185, 50), TextXAlignment = Enum.TextXAlignment.Left, Parent = waiting })
local leaveButton = button({ Position = UDim2.fromOffset(12, 60), Size = UDim2.fromOffset(120, 28), Text = "LEAVE", TextSize = 16, BackgroundColor3 = Color3.fromRGB(200, 60, 60), Parent = waiting })
local departButton = button({ Position = UDim2.fromOffset(140, 60), Size = UDim2.fromOffset(148, 28), Text = "DEPART NOW", TextSize = 16, BackgroundColor3 = Color3.fromRGB(60, 170, 90), Parent = waiting })
leaveButton.Activated:Connect(function()
	Remotes.PadCancel:FireServer()
end)
departButton.Activated:Connect(function()
	Remotes.DepartNow:FireServer()
end)

------------------------------------------------------------------ open trains list (right side)
local list = new("Frame", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 100), Size = UDim2.fromOffset(240, 300),
	BackgroundTransparency = 1, Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
text({ Size = UDim2.fromOffset(240, 24), Text = "OPEN TRAINS", TextSize = 20, TextStrokeTransparency = 0.3, LayoutOrder = 0, Parent = list })
local noneLabel = text({ Size = UDim2.fromOffset(240, 20), Text = "None yet. Host one!", TextSize = 14, TextColor3 = Color3.fromRGB(200, 200, 220), TextStrokeTransparency = 0.5, LayoutOrder = 99, Parent = list })
local cards = {}

local function card(index)
	local c = new("Frame", { Size = UDim2.fromOffset(240, 52), BackgroundColor3 = NAVY, BackgroundTransparency = 0.1, LayoutOrder = index, Parent = list }, { corner(10), stroke(WHITE, 1.5) })
	local title = text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(150, 22), Text = "", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
	local detail = text({ Position = UDim2.fromOffset(10, 26), Size = UDim2.fromOffset(150, 20), Text = "", TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 220), TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
	local join = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(66, 34), Text = "JOIN", TextSize = 16, BackgroundColor3 = Color3.fromRGB(240, 170, 40), Parent = c })
	join.Activated:Connect(function()
		Remotes.JoinPad:FireServer(index)
	end)
	cards[index] = { Frame = c, Title = title, Detail = detail }
	return cards[index]
end

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

	local shopOpen = player:GetAttribute("ShopOpen") == true or player:GetAttribute("QuestOpen") == true
	hint.Visible = not inRide and not padId and not menu.Visible and not shopOpen
	if inRide then
		menu.Visible = false
	end

	-- waiting panel
	local myPad = padId and padsFolder:FindFirstChild("Pad" .. padId)
	if myPad and myPad:GetAttribute("State") == "Open" and not inRide then
		waiting.Visible = true
		waitTitle.Text = string.format("PLATFORM %d  •  %s  •  %d/%d", padId, string.upper(myPad:GetAttribute("Difficulty")), myPad:GetAttribute("Count"), myPad:GetAttribute("Max"))
		if myPad:GetAttribute("Waiting") then
			waitTimer.Text = "WAITING FOR THE TRAIN..."
		else
			waitTimer.Text = "LEAVING IN: " .. math.max(0, math.ceil(myPad:GetAttribute("LeaveAt") - now)) .. "s"
		end
		departButton.Visible = myPad:GetAttribute("HostId") == player.UserId
	elseif myPad and myPad:GetAttribute("State") == "Launching" then
		waiting.Visible = true
		waitTimer.Text = "DEPARTING!"
		departButton.Visible = false
	else
		waiting.Visible = false
	end

	-- open trains list
	list.Visible = not inRide and not padId and not shopOpen
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
			c.Title.Text = "Platform " .. index .. "  •  " .. difficulty
			c.Title.TextColor3 = Config.Difficulties[difficulty] and Config.Difficulties[difficulty].Color or WHITE
			c.Detail.Text = string.format("%s  •  %d/%d  •  %ds", model:GetAttribute("Host"), model:GetAttribute("Count"), model:GetAttribute("Max"), math.max(0, math.ceil((model:GetAttribute("LeaveAt") or 0) - now)))
		elseif c then
			c.Frame.Visible = false
		end
	end
	noneLabel.Visible = not any
end)
