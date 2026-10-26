-- Lobby shop: Train Yard (buy/equip trains) and Perk Shop. Also applies the Fast Hands perk locally.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local NAVY = Color3.fromRGB(22, 26, 46)
local YELLOW = Color3.fromRGB(250, 195, 40)
local BLUE = Color3.fromRGB(30, 120, 210)
local GREEN = Color3.fromRGB(60, 190, 90)
local RED = Color3.fromRGB(215, 50, 50)
local WHITE = Color3.new(1, 1, 1)
local TOKEN = "🎫"

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
local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	return new("TextLabel", props)
end
local function button(props)
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	local b = new("TextButton", props)
	corner(10).Parent = b
	return b
end

local function owns(id)
	return player:GetAttribute("Owned_" .. id) == true
end
local function tokens()
	local stats = player:FindFirstChild("leaderstats")
	local t = stats and stats:FindFirstChild("Tokens")
	return t and t.Value or 0
end

local gui = new("ScreenGui", { Name = "ShopUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })

------------------------------------------------------------------ side buttons (lobby only)
local side = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(84, 180),
	BackgroundTransparency = 1, Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
local trainsButton = button({ Size = UDim2.fromOffset(84, 84), Text = "🚇\nTRAINS", TextSize = 18, BackgroundColor3 = YELLOW, TextStrokeTransparency = 0.4, LayoutOrder = 1, Parent = side })
stroke(Color3.fromRGB(90, 60, 0), 3).Parent = trainsButton
local perksButton = button({ Size = UDim2.fromOffset(84, 84), Text = "⭐\nPERKS", TextSize = 18, BackgroundColor3 = GREEN, TextStrokeTransparency = 0.4, LayoutOrder = 2, Parent = side })
stroke(Color3.fromRGB(20, 80, 40), 3).Parent = perksButton

------------------------------------------------------------------ train shop
local trainShop = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(780, 440),
	BackgroundTransparency = 1, Visible = false, Parent = gui,
})

-- left: list of trains
local listPanel = new("Frame", { Size = UDim2.fromOffset(250, 440), BackgroundColor3 = Color3.fromRGB(250, 236, 190), Parent = trainShop }, { corner(14), stroke(YELLOW, 4) })
local listHeader = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = YELLOW, Parent = listPanel }, { corner(12) })
text({ Size = UDim2.fromScale(1, 1), Text = "🚇 TRAINS", TextSize = 28, TextColor3 = Color3.fromRGB(40, 30, 10), Parent = listHeader })
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 58), Size = UDim2.new(1, -16, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = listPanel,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

-- middle: preview + buy button
local middle = new("Frame", { Position = UDim2.fromOffset(262, 0), Size = UDim2.fromOffset(250, 440), BackgroundTransparency = 1, Parent = trainShop })
local viewport = new("ViewportFrame", {
	Size = UDim2.fromOffset(250, 250), BackgroundColor3 = Color3.fromRGB(30, 34, 56), Ambient = Color3.fromRGB(150, 150, 160),
	LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -0.5), Parent = middle,
}, { corner(14), stroke(WHITE, 3) })
local previewCamera = new("Camera", { FieldOfView = 40, Parent = viewport })
viewport.CurrentCamera = previewCamera
local actionButton = button({ Position = UDim2.fromOffset(0, 262), Size = UDim2.fromOffset(250, 56), Text = "", TextSize = 26, BackgroundColor3 = GREEN, TextStrokeTransparency = 0.5, Parent = middle })
stroke(Color3.fromRGB(20, 80, 40), 3).Parent = actionButton
local balance = new("Frame", { Position = UDim2.fromOffset(25, 328), Size = UDim2.fromOffset(200, 40), BackgroundColor3 = NAVY, Parent = middle }, { corner(10) })
local balanceText = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 20, Parent = balance })
local statusText = text({ Position = UDim2.fromOffset(0, 372), Size = UDim2.fromOffset(250, 22), Text = "", TextSize = 16, TextStrokeTransparency = 0.3, Parent = middle })
local closeTrains = button({ Position = UDim2.fromOffset(55, 396), Size = UDim2.fromOffset(140, 42), Text = "CLOSE", TextSize = 22, BackgroundColor3 = RED, Parent = middle })
stroke(Color3.fromRGB(90, 10, 10), 3).Parent = closeTrains

-- right: stats
local statsPanel = new("Frame", { Position = UDim2.fromOffset(524, 0), Size = UDim2.fromOffset(256, 440), BackgroundColor3 = Color3.fromRGB(225, 236, 250), Parent = trainShop }, { corner(14), stroke(BLUE, 4) })
local statsHeader = new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = BLUE, Parent = statsPanel }, { corner(12) })
local trainName = text({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 36), Text = "", TextSize = 26, TextStrokeTransparency = 0.5, Parent = statsHeader })
local rarityText = text({ Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 0, 24), Text = "", TextSize = 18, TextStrokeTransparency = 0.3, Parent = statsHeader })
local statRows = {}
for i, stat in { "Max Speed", "Acceleration", "Brakes", "Build Quality" } do
	local y = 82 + (i - 1) * 46
	local back = new("Frame", { Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(232, 36), BackgroundColor3 = Color3.fromRGB(40, 60, 100), Parent = statsPanel }, { corner(18) })
	local fill = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.fromRGB(110, 220, 120), Parent = back }, { corner(18) })
	text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Text = stat, TextSize = 17, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = back })
	local value = text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Text = "", TextSize = 17, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2, Parent = back })
	statRows[stat] = { Fill = fill, Value = value }
end
local description = text({ Position = UDim2.fromOffset(14, 270), Size = UDim2.fromOffset(228, 150), Text = "", TextSize = 17, TextWrapped = true, TextColor3 = Color3.fromRGB(30, 50, 80), TextYAlignment = Enum.TextYAlignment.Top, Parent = statsPanel })

------------------------------------------------------------------ preview model
local previewModel
local function buildPreview(def)
	if previewModel then
		previewModel:Destroy()
	end
	local model = Instance.new("Model")
	local function part(size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local body = part(Vector3.new(14, 4.4, 4.4), CFrame.new(0, 0, 0), def.Body, Enum.Material.Metal)
	model.PrimaryPart = body
	part(Vector3.new(14.05, 0.5, 4.45), CFrame.new(0, -0.7, 0), def.Accent)
	part(Vector3.new(14.05, 1.6, 4.45), CFrame.new(0, -1.6, 0), def.Lower)
	part(Vector3.new(13.6, 0.5, 3.8), CFrame.new(0, 2.45, 0), def.Body:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Metal)
	for x = -5.5, 5.5, 2.75 do
		part(Vector3.new(2, 1.3, 4.5), CFrame.new(x, 0.8, 0), Color3.fromRGB(20, 24, 34), Enum.Material.Glass)
	end
	part(Vector3.new(0.2, 1.8, 3.4), CFrame.new(7.05, 0.7, 0), Color3.fromRGB(20, 24, 34), Enum.Material.Glass)
	for _, z in { -1.2, 1.2 } do
		part(Vector3.new(0.2, 0.5, 0.8), CFrame.new(7.05, -1.4, z), Color3.fromRGB(255, 245, 220), Enum.Material.Neon)
	end
	for _, x in { -4.5, -3, 3, 4.5 } do
		part(Vector3.new(0.4, 1.2, 1.2), CFrame.new(x, -2.6, -1.9) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(30, 30, 34), nil, Enum.PartType.Cylinder)
		part(Vector3.new(0.4, 1.2, 1.2), CFrame.new(x, -2.6, 1.9) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(30, 30, 34), nil, Enum.PartType.Cylinder)
	end
	if not owns(def.Id) then
		for _, p in model:GetChildren() do
			p.Color = p.Color:Lerp(Color3.fromRGB(20, 20, 30), 0.55)
		end
	end
	model.Parent = viewport
	previewModel = model
	previewCamera.CFrame = CFrame.lookAt(Vector3.new(16, 8, 22), Vector3.new(0, -0.5, 0))
end

------------------------------------------------------------------ train shop logic
local selected = Config.Trains[1]
local cards = {}

local function refreshTrainShop()
	local equipped = player:GetAttribute("EquippedTrain")
	for _, def in Config.Trains do
		local c = cards[def.Id]
		local owned = owns(def.Id)
		c.Price.Text = def.Id == equipped and "EQUIPPED" or owned and "OWNED" or (TOKEN .. " " .. def.Price)
		c.Price.TextColor3 = def.Id == equipped and Color3.fromRGB(90, 235, 120) or WHITE
		c.Lock.Visible = not owned
		c.Stroke.Thickness = def == selected and 4 or 0
	end

	trainName.Text = selected.Name
	rarityText.Text = selected.Rarity:upper()
	rarityText.TextColor3 = Config.Rarities[selected.Rarity]
	local values = {
		["Max Speed"] = { selected.MaxSpeed, 70, selected.MaxSpeed .. " mph" },
		Acceleration = { selected.Accel, 6, tostring(selected.Accel) },
		Brakes = { selected.Brake, 12, tostring(selected.Brake) },
		["Build Quality"] = { Config.BuildQuality(selected), 100, tostring(Config.BuildQuality(selected)) },
	}
	for stat, v in values do
		statRows[stat].Fill.Size = UDim2.fromScale(math.clamp(v[1] / v[2], 0.08, 1), 1)
		statRows[stat].Value.Text = v[3]
	end
	description.Text = selected.Description

	if selected.Id == equipped then
		actionButton.Text = "EQUIPPED ✔"
		actionButton.BackgroundColor3 = Color3.fromRGB(120, 125, 140)
	elseif owns(selected.Id) then
		actionButton.Text = "EQUIP"
		actionButton.BackgroundColor3 = BLUE
	else
		actionButton.Text = "BUY  " .. TOKEN .. " " .. selected.Price
		actionButton.BackgroundColor3 = tokens() >= selected.Price and GREEN or Color3.fromRGB(150, 150, 160)
	end
	balanceText.Text = "BALANCE: " .. TOKEN .. " " .. tokens()
	buildPreview(selected)
end

for i, def in Config.Trains do
	local rarity = Config.Rarities[def.Rarity]
	local c = button({ Size = UDim2.new(1, -8, 0, 62), Text = "", BackgroundColor3 = rarity:Lerp(Color3.fromRGB(30, 30, 50), 0.45), LayoutOrder = i, Parent = list })
	local s = stroke(WHITE, 0)
	s.Parent = c
	text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 28), Text = def.Name, TextSize = 20, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
	local price = text({ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 24), Text = "", TextSize = 17, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
	local lock = text({ Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(44, 44), Text = "🔒", TextSize = 30, Parent = c })
	c.Activated:Connect(function()
		selected = def
		statusText.Text = ""
		refreshTrainShop()
	end)
	cards[def.Id] = { Price = price, Lock = lock, Stroke = s }
end

local busy = false
actionButton.Activated:Connect(function()
	if busy or selected.Id == player:GetAttribute("EquippedTrain") then
		return
	end
	busy = true
	local remote = owns(selected.Id) and Remotes.ShopEquip or Remotes.ShopBuy
	local ok, message = remote:InvokeServer(selected.Id)
	statusText.Text = message or ""
	statusText.TextColor3 = ok and Color3.fromRGB(90, 235, 120) or Color3.fromRGB(255, 110, 100)
	busy = false
	refreshTrainShop()
end)

------------------------------------------------------------------ perk shop
local perkShop = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(560, 420),
	BackgroundColor3 = Color3.fromRGB(225, 245, 232), Visible = false, Parent = gui,
}, { corner(14), stroke(GREEN, 4) })
local perkHeader = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = GREEN, Parent = perkShop }, { corner(12) })
text({ Size = UDim2.fromScale(1, 1), Text = "⭐ PERKS", TextSize = 28, TextStrokeTransparency = 0.5, Parent = perkHeader })
local closePerks = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(36, 36), Text = "X", TextSize = 22, BackgroundColor3 = RED, Parent = perkHeader })
local perkBalance = text({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 24), Text = "", TextSize = 18, TextColor3 = Color3.fromRGB(30, 60, 40), Parent = perkShop })
local perkStatus = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 16, TextStrokeTransparency = 0.3, Parent = perkShop })
local perkGrid = new("Frame", { Position = UDim2.fromOffset(16, 84), Size = UDim2.new(1, -32, 0, 296), BackgroundTransparency = 1, Parent = perkShop }, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(256, 140), CellPadding = UDim2.fromOffset(16, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local perkCards = {}
for i, perk in Config.Perks do
	local c = new("Frame", { BackgroundColor3 = NAVY, LayoutOrder = i, Parent = perkGrid }, { corner(12) })
	text({ Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(56, 56), Text = perk.Icon, TextSize = 40, Parent = c })
	text({ Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -78, 0, 26), Text = perk.Name, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
	text({ Position = UDim2.fromOffset(70, 34), Size = UDim2.new(1, -78, 0, 48), Text = perk.Description, TextSize = 14, TextWrapped = true, TextColor3 = Color3.fromRGB(200, 205, 225), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
	local b = button({ Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 0, 38), Text = "", TextSize = 20, BackgroundColor3 = GREEN, Parent = c })
	b.Activated:Connect(function()
		if busy or owns(perk.Id) then
			return
		end
		busy = true
		local ok, message = Remotes.ShopBuy:InvokeServer(perk.Id)
		perkStatus.Text = message or ""
		perkStatus.TextColor3 = ok and Color3.fromRGB(40, 150, 70) or Color3.fromRGB(210, 60, 50)
		busy = false
	end)
	perkCards[perk.Id] = b
end

local function refreshPerks()
	for _, perk in Config.Perks do
		local b = perkCards[perk.Id]
		if owns(perk.Id) then
			b.Text = "OWNED ✔"
			b.BackgroundColor3 = Color3.fromRGB(120, 125, 140)
		else
			b.Text = "BUY  " .. TOKEN .. " " .. perk.Price
			b.BackgroundColor3 = tokens() >= perk.Price and GREEN or Color3.fromRGB(150, 150, 160)
		end
	end
	perkBalance.Text = "BALANCE: " .. TOKEN .. " " .. tokens()
end

------------------------------------------------------------------ opening / closing
local function open(which)
	if player:GetAttribute("InRide") then
		return
	end
	trainShop.Visible = which == "Trains"
	perkShop.Visible = which == "Perks"
	statusText.Text = ""
	perkStatus.Text = ""
	if which == "Trains" then
		for _, def in Config.Trains do
			if def.Id == player:GetAttribute("EquippedTrain") then
				selected = def
			end
		end
		refreshTrainShop()
	else
		refreshPerks()
	end
end
local function close()
	trainShop.Visible = false
	perkShop.Visible = false
end

trainsButton.Activated:Connect(function()
	if trainShop.Visible then
		close()
	else
		open("Trains")
	end
end)
perksButton.Activated:Connect(function()
	if perkShop.Visible then
		close()
	else
		open("Perks")
	end
end)
closeTrains.Activated:Connect(close)
closePerks.Activated:Connect(close)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		open(prompt:GetAttribute("Shop"))
	end
end)

player.AttributeChanged:Connect(function(name)
	if name:sub(1, 6) == "Owned_" or name == "EquippedTrain" then
		if trainShop.Visible then
			refreshTrainShop()
		end
		if perkShop.Visible then
			refreshPerks()
		end
	end
end)

------------------------------------------------------------------ per frame: spin preview, hide in rides, Fast Hands perk
-- shrink the shop windows to fit small screens (phones)
local trainScale = new("UIScale", { Parent = trainShop })
local perkScale = new("UIScale", { Parent = perkShop })

local fastHandsTimer = 0
RunService.RenderStepped:Connect(function(dt)
	local inRide = player:GetAttribute("InRide") == true
	side.Visible = not inRide
	local viewportSize = workspace.CurrentCamera.ViewportSize
	trainScale.Scale = math.min(1, (viewportSize.X - 24) / 780, (viewportSize.Y - 100) / 440)
	perkScale.Scale = math.min(1, (viewportSize.X - 24) / 560, (viewportSize.Y - 100) / 420)
	-- lets the lobby UI hide its hint and list while a shop is open
	player:SetAttribute("ShopOpen", trainShop.Visible or perkShop.Visible)
	if inRide and (trainShop.Visible or perkShop.Visible) then
		close()
	end
	if previewModel and trainShop.Visible then
		previewModel:PivotTo(previewModel:GetPivot() * CFrame.Angles(0, dt * 0.6, 0))
	end

	fastHandsTimer += dt
	if fastHandsTimer >= 1 then
		fastHandsTimer = 0
		local train = workspace:FindFirstChild("Train")
		if train then
			local factor = owns("FastHands") and 0.65 or 1
			for _, prompt in train:GetDescendants() do
				if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("BaseHold") then
					prompt.HoldDuration = prompt:GetAttribute("BaseHold") * factor
				end
			end
		end
	end
end)
