-- Lobby: QUESTS and REWARDS buttons (top right) and their windows.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local C = UI.Colors
local new, text = UI.new, UI.text
local TOKEN = "🎫"

local gui = new("ScreenGui", { Name = "QuestUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 6, Parent = player:WaitForChild("PlayerGui") })

local function decode(name)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(name) or "")
	return ok and type(value) == "table" and value or nil
end
local function today()
	return math.floor(workspace:GetServerTimeNow() / 86400)
end
local function questDef(id)
	for _, def in Config.Quests do
		if def.Id == id then
			return def
		end
	end
	return nil
end
local function dailyStatus()
	local daily = decode("DailyData") or { LastDay = 0, Streak = 0 }
	local canClaim = daily.LastDay ~= today()
	local streak = daily.Streak or 0
	local nextStreak = streak
	if canClaim then
		nextStreak = (daily.LastDay == today() - 1) and (streak % #Config.DailyRewards) + 1 or 1
	end
	return canClaim, nextStreak, streak
end

------------------------------------------------------------------ top-right buttons
local top = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(160, 76), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function topButton(order, icon, label, color)
	local b = UI.button({ Size = UDim2.fromOffset(72, 72), Text = icon .. "\n" .. label, TextSize = 15, LayoutOrder = order, Parent = top }, color)
	local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.Red, Visible = false, ZIndex = 3, Parent = b }, { UI.corner(10), UI.stroke(C.White, 2) })
	text({ Size = UDim2.fromScale(1, 1), Text = "!", TextSize = 14, ZIndex = 4, Parent = dot })
	return b, dot
end
local questsButton, questsDot = topButton(1, "📜", "QUESTS", C.Yellow)
local rewardsButton, rewardsDot = topButton(2, "🎁", "REWARDS", C.Purple)

------------------------------------------------------------------ window helper (yellow/purple header, light body, red X)
local function window(title, color, height)
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(440, height),
		BackgroundColor3 = Color3.fromRGB(240, 244, 252), Visible = false, Parent = gui,
	}, { UI.corner(16), UI.stroke(color, 4) })
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = color, Parent = frame }, { UI.corner(14) })
	UI.gloss(header)
	text({ Size = UDim2.fromScale(1, 1), Text = title, TextSize = 28, Font = UI.TitleFont, Outline = 3, Parent = header })
	local close = UI.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(38, 38), Text = "X", TextSize = 22, Parent = header }, C.Red)
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local scale = new("UIScale", { Parent = frame })
	return frame, scale
end

------------------------------------------------------------------ quests window
local questWin, questScale = window("📜 DAILY QUESTS", C.Yellow, 360)
local questCards = {}
for i = 1, Config.QuestsPerDay do
	local card = new("Frame", { Position = UDim2.fromOffset(14, 64 + (i - 1) * 88), Size = UDim2.new(1, -28, 0, 80), BackgroundColor3 = C.Navy, Parent = questWin }, { UI.corner(12), UI.stroke(C.Outline, 3) })
	local title = text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -140, 0, 24), Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, Parent = card })
	local reward = text({ Position = UDim2.fromOffset(12, 30), Size = UDim2.fromOffset(120, 18), Text = "", TextSize = 15, TextColor3 = C.Yellow, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local barBack = new("Frame", { Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -140, 0, 18), BackgroundColor3 = C.Dark, Parent = card }, { UI.corner(9), UI.stroke(C.White, 2) })
	local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Green, Parent = barBack }, { UI.corner(9) })
	local barText = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 13, ZIndex = 2, Parent = barBack })
	local claim = UI.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(110, 46), Text = "CLAIM", TextSize = 20, Parent = card }, C.Green)
	questCards[i] = { Title = title, Reward = reward, Fill = barFill, BarText = barText, Claim = claim }
end
local questFooter = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 20), Text = "", TextSize = 14, TextColor3 = Color3.fromRGB(60, 70, 100), Outline = false, Parent = questWin })
local questStatus = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 20), Text = "", TextSize = 16, Parent = questWin })

local busy = false
local currentQuests = {}
for i, card in questCards do
	card.Claim.Activated:Connect(function()
		local q = currentQuests[i]
		if busy or not q then
			return
		end
		busy = true
		local ok, message = Remotes.ClaimQuest:InvokeServer(q.Id)
		questStatus.Text = message or ""
		questStatus.TextColor3 = ok and C.Green or C.Red
		busy = false
	end)
end

------------------------------------------------------------------ rewards window
local rewardWin, rewardScale = window("🎁 DAILY REWARDS", C.Purple, 300)
local dayTiles = {}
for i, amount in Config.DailyRewards do
	local col = (i - 1) % 4
	local row = math.floor((i - 1) / 4)
	local tile = new("Frame", { Position = UDim2.fromOffset(22 + col * 102, 66 + row * 84), Size = UDim2.fromOffset(92, 74), BackgroundColor3 = C.Navy, Parent = rewardWin }, { UI.corner(12) })
	local stroke = UI.stroke(C.Outline, 3)
	stroke.Parent = tile
	text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 20), Text = "DAY " .. i, TextSize = 16, Parent = tile })
	text({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 24), Text = TOKEN .. " " .. amount, TextSize = 18, TextColor3 = C.Yellow, Parent = tile })
	local check = text({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 20), Text = "", TextSize = 16, TextColor3 = C.Green, Parent = tile })
	dayTiles[i] = { Tile = tile, Stroke = stroke, Check = check }
end
local claimDaily = UI.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34), Size = UDim2.fromOffset(200, 44), Text = "CLAIM", TextSize = 22, Parent = rewardWin }, C.Green)
local rewardStatus = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 20), Text = "", TextSize = 15, Parent = rewardWin })
claimDaily.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	local ok, message = Remotes.ClaimDaily:InvokeServer()
	rewardStatus.Text = message or ""
	rewardStatus.TextColor3 = ok and C.Green or C.Red
	busy = false
end)

------------------------------------------------------------------ refresh
local function refresh()
	-- quests
	local data = decode("QuestData")
	currentQuests = data and data.List or {}
	local anyClaimable = false
	for i, card in questCards do
		local q = currentQuests[i]
		local def = q and questDef(q.Id)
		if def then
			card.Title.Text = def.Text
			card.Reward.Text = TOKEN .. " " .. def.Reward
			card.Fill.Size = UDim2.fromScale(math.clamp(q.Progress / def.Goal, 0, 1), 1)
			card.BarText.Text = q.Progress .. " / " .. def.Goal
			local done = q.Progress >= def.Goal
			if q.Claimed then
				card.Claim.Text = "DONE ✔"
				card.Claim.BackgroundColor3 = Color3.fromRGB(120, 125, 140)
			elseif done then
				card.Claim.Text = "CLAIM"
				card.Claim.BackgroundColor3 = C.Green
				anyClaimable = true
			else
				card.Claim.Text = "IN PROGRESS"
				card.Claim.TextSize = 14
				card.Claim.BackgroundColor3 = Color3.fromRGB(120, 125, 140)
			end
			if done or q.Claimed then
				card.Claim.TextSize = 20
			end
		else
			card.Title.Text = "Loading..."
		end
	end
	questsDot.Visible = anyClaimable
	local secondsLeft = 86400 - (workspace:GetServerTimeNow() % 86400)
	questFooter.Text = string.format("New quests in %dh %02dm", secondsLeft // 3600, (secondsLeft % 3600) // 60)

	-- daily rewards
	local canClaim, nextStreak, streak = dailyStatus()
	for i, tile in dayTiles do
		local claimedDay = (canClaim and i < nextStreak) or (not canClaim and i <= streak)
		local isNext = canClaim and i == nextStreak
		tile.Check.Text = claimedDay and "✔" or (isNext and "TODAY!" or "")
		tile.Check.TextColor3 = claimedDay and C.Green or C.Yellow
		tile.Stroke.Color = isNext and C.Yellow or C.Outline
		tile.Stroke.Thickness = isNext and 4 or 3
		tile.Tile.BackgroundColor3 = claimedDay and Color3.fromRGB(40, 70, 50) or C.Navy
	end
	claimDaily.Text = canClaim and ("CLAIM DAY " .. nextStreak) or "COME BACK TOMORROW"
	claimDaily.TextSize = canClaim and 22 or 15
	claimDaily.BackgroundColor3 = canClaim and C.Green or Color3.fromRGB(120, 125, 140)
	rewardsDot.Visible = canClaim
end

player.AttributeChanged:Connect(function(name)
	if name == "QuestData" or name == "DailyData" then
		refresh()
	end
end)

questsButton.Activated:Connect(function()
	rewardWin.Visible = false
	questWin.Visible = not questWin.Visible
	questStatus.Text = ""
	refresh()
end)
rewardsButton.Activated:Connect(function()
	questWin.Visible = false
	rewardWin.Visible = not rewardWin.Visible
	rewardStatus.Text = ""
	refresh()
end)

local timer = 0
RunService.RenderStepped:Connect(function(dt)
	local inRide = player:GetAttribute("InRide") == true
	gui.Enabled = not inRide
	local viewport = workspace.CurrentCamera.ViewportSize
	local s = math.min(1, (viewport.X - 24) / 440, (viewport.Y - 100) / 360)
	questScale.Scale = s
	rewardScale.Scale = s
	player:SetAttribute("QuestOpen", questWin.Visible or rewardWin.Visible)
	timer += dt
	if timer >= 1 then
		timer = 0
		refresh()
	end
end)
refresh()
