-- Lobby: Daily Quests list (right side) and the LOGIN REWARD window (REWARDS button on the left).
-- The reward window pops up by itself when you join and today's reward is ready.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local player = Players.LocalPlayer
local C = UI.Colors
local new, text = UI.new, UI.text

local gui = new("ScreenGui", { Name = "QuestUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 6, Parent = player:WaitForChild("PlayerGui") })

local function decode(name)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(name) or "")
	return ok and type(value) == "table" and value or nil
end
local function today()
	return math.floor(workspace:GetServerTimeNow() / 86400)
end
local function untilMidnight()
	local seconds = 86400 - (workspace:GetServerTimeNow() % 86400)
	return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
end
local comma = UI.comma
local function questDef(id)
	for _, def in Config.Quests do
		if def.Id == id then
			return def
		end
	end
	return nil
end
-- can they claim now? which day of the 7-day cycle is today's (or was just claimed)? days in a row?
local function dailyStatus()
	local daily = decode("DailyData") or { LastDay = 0, Streak = 0 }
	local streak = daily.Streak or 0
	if daily.LastDay ~= today() then
		local continuing = daily.LastDay == today() - 1
		return true, continuing and (streak % #Config.DailyRewards) + 1 or 1, continuing and (daily.Total or streak) or 0
	end
	return false, streak, daily.Total or streak
end
local function playSound(name)
	local sound = Sounds:FindFirstChild(name)
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end
-- middle of a GUI object, in this ScreenGui's pixels (for the floating "+50" text)
local function centerOf(object)
	return UDim2.fromOffset(object.AbsolutePosition.X + object.AbsoluteSize.X / 2, object.AbsolutePosition.Y + object.AbsoluteSize.Y / 2)
end

local refresh -- defined below
local busy = false

------------------------------------------------------------------ daily quests (right side)
local LIST_W = 320
-- on phones the jump button is in the bottom-right corner, so the list sits higher
local questList = new("Frame", {
	Name = "DailyQuests", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, UserInputService.TouchEnabled and 0.16 or 0.26, 0), Size = UDim2.fromOffset(LIST_W, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
local listScale = new("UIScale", { Parent = questList })

-- header: a round yellow fold button (arrow down = open, arrow right = folded) and the title; click it to fold the list.
-- Once every quest is claimed the list folds itself into a small "all done" line, until you open it again.
local header = new("TextButton", { Size = UDim2.fromOffset(LIST_W, 38), Text = "", BackgroundTransparency = 1, AutoButtonColor = false, LayoutOrder = 0, Parent = questList })
local fold = new("Frame", { Position = UDim2.fromOffset(2, 3), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = C.Yellow, Parent = header }, { UI.corner(16), UI.stroke(C.Outline, 2.5) })
UI.gloss(fold)
local chevron = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Parent = fold })
for _, s in { -1, 1 } do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, s * 3.5, 0.5, 1), Size = UDim2.fromOffset(12, 4.5), Rotation = -s * 45,
		BackgroundColor3 = C.Navy, BorderSizePixel = 0, Parent = chevron,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end
text({ Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(180, 38), Text = "Daily Quests", TextSize = 28, Outline = 2.5, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local doneTick = UI.check({ Position = UDim2.fromOffset(212, 4), Size = UDim2.fromOffset(30, 30), Visible = false, Parent = header })
local headerBadge = UI.badge(header)
headerBadge.Position = UDim2.fromOffset(222, 12)
local collapsed = nil -- nil = automatic (folds once everything is claimed)
local folded = false
header.Activated:Connect(function()
	collapsed = not folded
	refresh()
end)

local rows = {}
for i = 1, Config.QuestsPerDay do
	local row = new("Frame", { Size = UDim2.fromOffset(LIST_W, 68), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, LayoutOrder = i, Parent = questList }, { UI.corner(12) })
	local icon = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(34, 24), Size = UDim2.fromOffset(56, 44), Text = "💰", TextSize = 38, Outline = false, Parent = row })
	local reward = text({ Position = UDim2.fromOffset(0, 42), Size = UDim2.fromOffset(68, 22), Text = "", TextSize = 18, Parent = row })
	local title = text({ Position = UDim2.fromOffset(72, 6), Size = UDim2.new(1, -82, 0, 24), Text = "", TextScaled = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	new("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 10, Parent = title })
	local bar = UI.bar({ Position = UDim2.fromOffset(72, 38), Size = UDim2.new(1, -84, 0, 20), Parent = row })
	bar.Label.TextSize = 15
	local claim = UI.button({ Position = UDim2.fromOffset(72, 34), Size = UDim2.new(1, -84, 0, 28), Text = "CLAIM!", TextSize = 19, Visible = false, Parent = row }, C.Lime)
	rows[i] = { Frame = row, Icon = icon, Reward = reward, Title = title, Bar = bar, Claim = claim }
end
local footer = text({ Size = UDim2.fromOffset(LIST_W, 22), Text = "", TextSize = 15, TextColor3 = C.Muted, LayoutOrder = 99, Parent = questList })

local currentQuests = {}
for i, row in rows do
	row.Claim.Activated:Connect(function()
		local q = currentQuests[i]
		local def = q and questDef(q.Id)
		if busy or not def then
			return
		end
		busy = true
		local ok = Remotes.ClaimQuest:InvokeServer(q.Id)
		busy = false
		if ok then
			playSound("Coins")
			UI.pop(row.Icon)
			UI.popText(gui, centerOf(row.Frame), "+" .. comma(def.Reward) .. " 🎫")
		end
		refresh()
	end)
end

------------------------------------------------------------------ LOGIN REWARD window
local DAYS = #Config.DailyRewards
local CARD_W, CARD_H, GAP = 108, 172, 9
local W, H = DAYS * CARD_W + (DAYS - 1) * GAP + 50, 352
local rewardWin = UI.window({ Title = "LOGIN REWARD", Icon = "🎁", Width = W, Height = H, Parent = gui })
local body = rewardWin.Body
text({ Position = UDim2.fromOffset(26, 12), Size = UDim2.new(1, -320, 0, 34), Text = "Come back every day for free rewards!", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
local streakText = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, 12), Size = UDim2.fromOffset(280, 34), Text = "", RichText = true, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right, Parent = body })

local THEMES = {
	Normal = { Back = C.Card, Rays = Color3.fromRGB(90, 90, 102), Border = Color3.fromRGB(88, 90, 100) },
	Today = { Back = Color3.fromRGB(14, 58, 24), Rays = Color3.fromRGB(70, 210, 90), Border = C.Lime },
	Special = { Back = Color3.fromRGB(42, 16, 78), Rays = Color3.fromRGB(150, 80, 255), Border = Color3.fromRGB(165, 95, 255) },
}
local function rewardIcon(day, amount)
	return day == DAYS and "🎁" or "💰"
end

local cards = {}
for i, amount in Config.DailyRewards do
	local x = 25 + (i - 1) * (CARD_W + GAP)
	-- tab above the card: "Today" / "Tomorrow" / "Day 3"
	local tab = new("Frame", { Position = UDim2.fromOffset(x, 58), Size = UDim2.fromOffset(CARD_W, 30), BackgroundColor3 = C.Grey, Parent = body }, { UI.corner(4) })
	local tabStroke = UI.stroke(C.White, 2)
	tabStroke.Parent = tab
	local tabGradient = new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 120)), Parent = tab })
	local tabText = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 19, Parent = tab })
	-- the card: sunburst, big icon, amount, and a green tick once it's claimed
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + CARD_W / 2, 96 + CARD_H / 2), Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = C.Card, Parent = body,
	}, { UI.corner(14) })
	local cardStroke = UI.stroke(C.Grey, 2.5)
	cardStroke.Parent = card
	local rays = UI.rays(card, C.Grey, 10)
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(90, 76), Text = rewardIcon(i, amount), TextSize = 60, Outline = false, ZIndex = 2, Parent = card })
	text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -8, 0, 30), Text = "+" .. comma(amount), TextSize = 28, Outline = 2.5, ZIndex = 2, Parent = card })
	local done = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 3, Visible = false, Parent = card }, { UI.corner(14) })
	UI.check({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(72, 72), Parent = done })
	cards[i] = { Tab = tab, TabStroke = tabStroke, TabGradient = tabGradient, TabText = tabText, Frame = card, Stroke = cardStroke, Rays = rays, Done = done }
end

local function paint(card, theme)
	local t = THEMES[theme]
	card.Theme = theme
	card.Frame.BackgroundColor3 = t.Back
	card.Stroke.Color = t.Border
	card.Stroke.Thickness = theme == "Normal" and 2.5 or 3.5
	for _, f in card.Rays.Parent:GetDescendants() do
		if f:IsA("Frame") then
			f.BackgroundColor3 = t.Rays
		end
	end
end

local claimButton = UI.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 25, 1, -16), Size = UDim2.fromOffset(290, 58), Text = "", TextSize = 32, Parent = body }, C.Lime)
local tip = text({
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -26, 1, -20), Size = UDim2.fromOffset(330, 50), Text = "", TextSize = 20,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right, Parent = body,
})

claimButton.Activated:Connect(function()
	local canClaim, day = dailyStatus()
	if busy or not canClaim then
		return
	end
	busy = true
	local ok = Remotes.ClaimDaily:InvokeServer()
	busy = false
	if ok then
		playSound("Coins")
		UI.pop(cards[day].Frame)
		UI.popText(gui, centerOf(cards[day].Frame), "+" .. comma(Config.DailyRewards[day]) .. " 🎫")
	end
	refresh()
end)

local rewardsButton, rewardsBadge = UI.menuButton(1, "🎁", "REWARDS", C.Purple)
rewardsButton.Activated:Connect(function()
	if rewardWin.Frame.Visible then
		rewardWin.Close()
	else
		rewardWin.Open()
	end
	refresh()
end)
-- other screens (the Tokens "+" button) can open this window too
UI.Actions.OpenRewards = function()
	rewardWin.Open()
	refresh()
end

------------------------------------------------------------------ refresh
local spinningRays
function refresh()
	-- quests
	local data = decode("QuestData")
	currentQuests = data and data.List or {}
	local anyClaimable, allDone = false, #currentQuests > 0
	for i, row in rows do
		local q = currentQuests[i]
		local def = q and questDef(q.Id)
		if def then
			local claimable = q.Progress >= def.Goal and not q.Claimed
			anyClaimable = anyClaimable or claimable
			allDone = allDone and q.Claimed == true
			row.Title.Text = (def.Hard and '<font color="#FF4A4A">[Hard]</font> ' or "") .. def.Text
			row.Reward.Text = "x" .. comma(def.Reward)
			row.Claim.Visible = claimable
			row.Bar.Frame.Visible = not claimable
			row.Bar.Fill.BackgroundColor3 = q.Claimed and C.Green or C.Yellow
			row.Bar.Set(q.Progress / def.Goal, q.Claimed and "DONE!" or (q.Progress .. " / " .. def.Goal))
			row.Frame.BackgroundTransparency = q.Claimed and 0.7 or 0.45
			row.Icon.TextTransparency = q.Claimed and 0.5 or 0
		end
	end
	folded = collapsed
	if folded == nil then
		folded = allDone
	end
	for i, row in rows do
		local q = currentQuests[i]
		row.Frame.Visible = q ~= nil and questDef(q.Id) ~= nil and not folded
	end
	chevron.Rotation = folded and -90 or 0
	doneTick.Visible = allDone and not anyClaimable
	headerBadge.Visible = folded and anyClaimable
	footer.Visible = not folded or allDone
	footer.Text = data and ((allDone and "All done! " or "") .. "New quests in " .. untilMidnight()) or "Loading quests..."

	-- login rewards
	local canClaim, day, streak = dailyStatus()
	streakText.Text = string.format('Your streak: <font color="#FFC21A">%d</font> 🔥', streak)
	for i, card in cards do
		local isToday = i == day
		local claimed = i < day or (isToday and not canClaim)
		local theme = isToday and "Today" or (i == DAYS and "Special" or "Normal")
		if card.Theme ~= theme then
			paint(card, theme)
		end
		card.Done.Visible = claimed
		card.TabText.Text = isToday and "Today" or (i == day + 1 and "Tomorrow" or ("Day " .. i))
		card.TabGradient.Enabled = theme == "Special"
		card.TabStroke.Enabled = theme == "Special"
		if isToday then
			card.Tab.BackgroundColor3 = C.Lime
		elseif theme == "Special" then
			card.Tab.BackgroundColor3 = Color3.fromRGB(110, 50, 220)
		else
			card.Tab.BackgroundColor3 = claimed and Color3.fromRGB(70, 72, 80) or C.Grey
		end
	end
	spinningRays = canClaim and cards[day] and cards[day].Rays or nil
	claimButton.Text = canClaim and "Claim Today!" or "Claimed!"
	claimButton.BackgroundColor3 = canClaim and C.Lime or C.Grey
	claimButton.AutoButtonColor = canClaim
	tip.Text = canClaim and "Miss a day and your streak starts over!" or ("Next reward in " .. untilMidnight() .. " ⏰")
	tip.TextColor3 = canClaim and C.Muted or C.White
	rewardsBadge.Visible = canClaim or anyClaimable
end

player.AttributeChanged:Connect(function(name)
	if name == "QuestData" or name == "DailyData" then
		refresh()
	end
end)

-- show the reward window when you join and today's reward is waiting
task.spawn(function()
	local waited = 0
	while not player:GetAttribute("DailyData") and waited < 30 do
		waited += task.wait(0.5)
	end
	task.wait(2)
	if dailyStatus() and player:GetAttribute("InRide") ~= true and not UI.anyWindowOpen() then
		rewardWin.Open()
		refresh()
	end
end)

local timer = 0
RunService.RenderStepped:Connect(function(dt)
	local inRide = player:GetAttribute("InRide") == true
	gui.Enabled = not inRide
	if inRide and rewardWin.Frame.Visible then
		rewardWin.Close()
	end
	questList.Visible = not UI.anyWindowOpen()
	listScale.Scale = math.clamp((workspace.CurrentCamera.ViewportSize.Y - 80) / 640, 0.55, 1)
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 5)
	for _, row in rows do
		if row.Claim.Visible then
			row.Claim.BackgroundColor3 = C.Lime:Lerp(C.White, 0.3 * pulse)
		end
	end
	if spinningRays and rewardWin.Frame.Visible then
		spinningRays.Rotation += dt * 25
	end
	timer += dt
	if timer >= 1 then
		timer = 0
		refresh()
	end
end)
refresh()
