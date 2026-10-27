-- Lobby shop: Train Yard (buy/equip trains) and Perk Shop. Also applies the Fast Hands perk locally.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local C = UI.Colors
local new, text = UI.new, UI.text
local TOKEN = "🎫"
local GOOD, BAD = Color3.fromRGB(90, 235, 120), Color3.fromRGB(255, 110, 100)

local function owns(id)
	return player:GetAttribute("Owned_" .. id) == true
end
local function tokens()
	local stats = player:FindFirstChild("leaderstats")
	local t = stats and stats:FindFirstChild("Tokens")
	return t and t.Value or 0
end
local function price(n)
	return TOKEN .. " " .. UI.comma(n)
end

local gui = new("ScreenGui", { Name = "ShopUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })

------------------------------------------------------------------ train yard window
local trainWin = UI.window({ Title = "TRAIN YARD", Icon = "🚇", Width = 820, Height = 440, Parent = gui })
local trainBody = trainWin.Body

-- left: list of trains
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(256, 408), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, ScrollBarImageColor3 = C.Grey, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = trainBody,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
})

-- middle: spinning preview on a sunburst, buy/equip button (your balance is in the Tokens pill)
local previewBack = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(418, 141), Size = UDim2.fromOffset(260, 250), BackgroundColor3 = C.Card, Parent = trainBody }, { UI.corner(16) })
local previewStroke = UI.stroke(C.Grey, 3)
previewStroke.Parent = previewBack
local previewRays = UI.rays(previewBack, C.Grey, 12)
local viewport = new("ViewportFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 150, 160),
	LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -0.5), ZIndex = 2, Parent = previewBack,
})
local previewCamera = new("Camera", { FieldOfView = 40, Parent = viewport })
viewport.CurrentCamera = previewCamera
local rarityTag = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(112, 28), BackgroundColor3 = C.Grey, ZIndex = 3, Parent = previewBack }, { UI.corner(8), UI.stroke(C.Outline, 2) })
local rarityText = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 17, ZIndex = 3, Parent = rarityTag })
local actionButton = UI.button({ Position = UDim2.fromOffset(288, 278), Size = UDim2.fromOffset(260, 60), Text = "", TextSize = 28, Parent = trainBody }, C.Lime)
local statusText = text({ Position = UDim2.fromOffset(288, 352), Size = UDim2.fromOffset(260, 60), Text = "", TextSize = 18, TextWrapped = true, Parent = trainBody })

-- right: name, rarity and stat bars
local statsPanel = new("Frame", { Position = UDim2.fromOffset(564, 16), Size = UDim2.fromOffset(240, 408), BackgroundColor3 = C.Card, Parent = trainBody }, { UI.corner(16), UI.stroke(Color3.fromRGB(60, 62, 72), 2) })
local trainName = text({ Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 36), Text = "", TextScaled = true, Font = UI.TitleFont, Outline = 2.5, Parent = statsPanel })
new("UITextSizeConstraint", { MaxTextSize = 30, Parent = trainName })
local descriptionText = text({ Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 0, 44), Text = "", TextSize = 15, TextWrapped = true, TextColor3 = C.Muted, Parent = statsPanel })
local statBars = {}
for i, stat in { "Max Speed", "Acceleration", "Brakes", "Build Quality" } do
	local y = 104 + (i - 1) * 74
	text({ Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 24), Text = stat, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = statsPanel })
	local bar = UI.bar({ Position = UDim2.fromOffset(12, y + 28), Size = UDim2.new(1, -24, 0, 26), Parent = statsPanel }, C.Green)
	bar.Label.TextSize = 16
	statBars[stat] = bar
end

------------------------------------------------------------------ preview model
local previewModel
local function buildPreview(def)
	if previewModel then
		previewModel:Destroy()
	end
	-- the real Blender train (ReplicatedStorage.TrainPreview), painted in this train's colours
	local model = ReplicatedStorage:WaitForChild("TrainPreview"):Clone()
	local paints = { Body = def.Body, Accent = def.Accent, Lower = def.Lower }
	for _, p in model:GetChildren() do
		local paint = paints[p:GetAttribute("Paint")]
		if paint then
			p.Color = paint
		end
		if not owns(def.Id) then
			p.Color = p.Color:Lerp(Color3.fromRGB(20, 20, 30), 0.55)
		end
	end
	model:ScaleTo(0.18)
	model:PivotTo(CFrame.new(0, -0.5, 0))
	model.Parent = viewport
	previewModel = model
	previewCamera.CFrame = CFrame.lookAt(Vector3.new(14.5, 7, 19.5), Vector3.new(0, -0.8, 0))
end

------------------------------------------------------------------ train yard logic
local selected = Config.Trains[1]
local cards = {}

local function refreshTrainShop()
	local equipped = player:GetAttribute("EquippedTrain")
	for _, def in Config.Trains do
		local c = cards[def.Id]
		local owned = owns(def.Id)
		c.Price.Text = def.Id == equipped and "EQUIPPED" or owned and "TAP TO EQUIP" or price(def.Price)
		c.Price.TextColor3 = def.Id == equipped and GOOD or owned and C.Cyan or C.Yellow
		c.Icon.Text = owned and "🚇" or "🔒"
		c.Stroke.Color = def == selected and C.White or Config.Rarities[def.Rarity]
		c.Stroke.Thickness = def == selected and 4 or 2
	end

	local rarity = Config.Rarities[selected.Rarity]
	trainName.Text = selected.Name:upper()
	descriptionText.Text = selected.Description
	rarityText.Text = selected.Rarity:upper()
	rarityTag.BackgroundColor3 = rarity
	previewStroke.Color = rarity
	for _, f in previewRays.Parent:GetDescendants() do
		if f:IsA("Frame") then
			f.BackgroundColor3 = rarity:Lerp(C.Card, 0.35)
		end
	end
	local values = {
		["Max Speed"] = { selected.MaxSpeed / 70, selected.MaxSpeed .. " mph" },
		Acceleration = { selected.Accel / 6, tostring(selected.Accel) },
		Brakes = { selected.Brake / 12, tostring(selected.Brake) },
		["Build Quality"] = { Config.BuildQuality(selected) / 100, tostring(Config.BuildQuality(selected)) },
	}
	for stat, v in values do
		statBars[stat].Set(v[1], v[2])
	end

	if selected.Id == equipped then
		actionButton.Text = "EQUIPPED"
		actionButton.BackgroundColor3 = C.Grey
	elseif owns(selected.Id) then
		actionButton.Text = "EQUIP"
		actionButton.BackgroundColor3 = C.Blue
	else
		actionButton.Text = "BUY  " .. price(selected.Price)
		actionButton.BackgroundColor3 = tokens() >= selected.Price and C.Lime or C.Grey
	end
	buildPreview(selected)
end

for i, def in Config.Trains do
	local rarity = Config.Rarities[def.Rarity]
	local c = new("TextButton", { Size = UDim2.fromOffset(238, 68), Text = "", BackgroundColor3 = rarity:Lerp(C.Card, 0.72), LayoutOrder = i, Parent = list }, { UI.corner(12) })
	local s = UI.stroke(rarity, 2)
	s.Parent = c
	local icon = text({ Position = UDim2.fromOffset(6, 10), Size = UDim2.fromOffset(50, 48), Text = "", TextSize = 34, Outline = false, Parent = c })
	text({ Position = UDim2.fromOffset(62, 8), Size = UDim2.new(1, -70, 0, 26), Text = def.Name, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
	local price = text({ Position = UDim2.fromOffset(62, 36), Size = UDim2.new(1, -70, 0, 22), Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
	c.Activated:Connect(function()
		selected = def
		statusText.Text = ""
		refreshTrainShop()
	end)
	cards[def.Id] = { Price = price, Icon = icon, Stroke = s }
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
	statusText.TextColor3 = ok and GOOD or BAD
	busy = false
	if ok then
		UI.pop(previewBack)
	end
	refreshTrainShop()
end)

------------------------------------------------------------------ perk window
local perkWin = UI.window({ Title = "PERKS", Icon = "⭐", Width = 600, Height = 410, Parent = gui })
local perkBody = perkWin.Body
text({ Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(360, 32), Text = "Perks are yours forever, on every ride!", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = perkBody })
local perkStatus = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 24), Text = "", TextSize = 17, Parent = perkBody })
local perkGrid = new("Frame", { Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 0, 304), BackgroundTransparency = 1, Parent = perkBody }, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(272, 146), CellPadding = UDim2.fromOffset(16, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local perkCards = {}
for i, perk in Config.Perks do
	local c = new("Frame", { BackgroundColor3 = C.Card, LayoutOrder = i, Parent = perkGrid }, { UI.corner(14) })
	local s = UI.stroke(Color3.fromRGB(88, 90, 100), 2)
	s.Parent = c
	local bubble = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(44, 44), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(48, 44, 30), Parent = c }, { UI.corner(14), UI.stroke(C.Outline, 2) })
	UI.rays(bubble, Color3.fromRGB(200, 160, 50), 8)
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(56, 56), Text = perk.Icon, TextSize = 40, Outline = false, ZIndex = 2, Parent = bubble })
	text({ Position = UDim2.fromOffset(86, 12), Size = UDim2.new(1, -96, 0, 26), Text = perk.Name, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
	text({
		Position = UDim2.fromOffset(86, 38), Size = UDim2.new(1, -96, 0, 44), Text = perk.Description, TextSize = 15, TextWrapped = true,
		TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c,
	})
	local b = UI.button({ Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 0, 42), Text = "", TextSize = 20, Parent = c }, C.Lime)
	b.Activated:Connect(function()
		if busy or owns(perk.Id) then
			return
		end
		busy = true
		local ok, message = Remotes.ShopBuy:InvokeServer(perk.Id)
		perkStatus.Text = message or ""
		perkStatus.TextColor3 = ok and GOOD or BAD
		busy = false
		if ok then
			UI.pop(bubble)
		end
	end)
	perkCards[perk.Id] = { Button = b, Stroke = s }
end

local function refreshPerks()
	for _, perk in Config.Perks do
		local card = perkCards[perk.Id]
		if owns(perk.Id) then
			card.Button.Text = "OWNED"
			card.Button.BackgroundColor3 = C.Grey
			card.Stroke.Color = GOOD
		else
			card.Button.Text = "BUY  " .. price(perk.Price)
			card.Button.BackgroundColor3 = tokens() >= perk.Price and C.Lime or C.Grey
			card.Stroke.Color = Color3.fromRGB(88, 90, 100)
		end
	end
end

------------------------------------------------------------------ opening / closing
local function open(which)
	if player:GetAttribute("InRide") then
		return
	end
	statusText.Text = ""
	perkStatus.Text = ""
	if which == "Trains" then
		for _, def in Config.Trains do
			if def.Id == player:GetAttribute("EquippedTrain") then
				selected = def
			end
		end
		trainWin.Open()
		refreshTrainShop()
	else
		perkWin.Open()
		refreshPerks()
	end
end

local trainsButton, trainsBadge = UI.menuButton(2, "🚇", "TRAINS", C.Yellow)
local perksButton, perksBadge = UI.menuButton(3, "⭐", "PERKS", C.Green)
-- red "!" on TRAINS / PERKS while you can afford something you don't own yet
local function canAffordAny(list)
	local have = tokens()
	for _, def in list do
		if not owns(def.Id) and def.Price > 0 and have >= def.Price then
			return true
		end
	end
	return false
end
trainsButton.Activated:Connect(function()
	if trainWin.Frame.Visible then
		trainWin.Close()
	else
		open("Trains")
	end
end)
perksButton.Activated:Connect(function()
	if perkWin.Frame.Visible then
		perkWin.Close()
	else
		open("Perks")
	end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		open(prompt:GetAttribute("Shop"))
	end
end)

player.AttributeChanged:Connect(function(name)
	if name:sub(1, 6) == "Owned_" or name == "EquippedTrain" then
		if trainWin.Frame.Visible then
			refreshTrainShop()
		end
		if perkWin.Frame.Visible then
			refreshPerks()
		end
	end
end)

------------------------------------------------------------------ per frame: spin preview, hide in rides, Fast Hands perk
local fastHandsTimer = 0
RunService.RenderStepped:Connect(function(dt)
	if player:GetAttribute("InRide") == true then
		if trainWin.Frame.Visible then
			trainWin.Close()
		end
		if perkWin.Frame.Visible then
			perkWin.Close()
		end
	end
	if trainWin.Frame.Visible then
		previewRays.Rotation += dt * 12
		if previewModel then
			previewModel:PivotTo(previewModel:GetPivot() * CFrame.Angles(0, dt * 0.6, 0))
		end
	end

	fastHandsTimer += dt
	if fastHandsTimer >= 1 then
		fastHandsTimer = 0
		trainsBadge.Visible = canAffordAny(Config.Trains)
		perksBadge.Visible = canAffordAny(Config.Perks)
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
