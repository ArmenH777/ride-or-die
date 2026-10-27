-- Lobby leaderboards: top 10 by wins and by tokens earned (refreshed every minute).
local Players = game:GetService("Players")

local Data = require(script.Parent.Data)

local Leaderboards = {}

local REFRESH = 60
local nameCache = {}

local function nameFor(userId)
	if not nameCache[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		nameCache[userId] = ok and name or ("Player " .. userId)
	end
	return nameCache[userId]
end

-- 4500 -> "4,500"
local function comma(n)
	local s = tostring(math.floor(n))
	repeat
		local count
		s, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return s
end

local RANK_COLORS = { Color3.fromRGB(255, 200, 40), Color3.fromRGB(200, 205, 215), Color3.fromRGB(215, 135, 70) }
local ROW_COLORS = { Color3.fromRGB(70, 56, 20), Color3.fromRGB(52, 56, 70), Color3.fromRGB(64, 42, 28) }

local function text(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		label[k] = v
	end
	return label
end

-- Fills a board's Rows frame. entries = { {Name, UserId, Value}, ... } or a message string.
-- Each row: rank badge (gold / silver / bronze for the top 3), avatar headshot, name, score.
local function render(board, entries, suffix)
	local rows = board.Display.Rows
	for _, child in rows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if type(entries) == "string" then
		text({ Size = UDim2.fromScale(1, 0.14), TextColor3 = Color3.fromRGB(200, 200, 220), Text = entries, Parent = rows })
		return
	end
	for i, entry in entries do
		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(1, 0.092)
		row.BackgroundColor3 = ROW_COLORS[i] or (i % 2 == 0 and Color3.fromRGB(34, 38, 64) or Color3.fromRGB(26, 30, 52))
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = rows
		Instance.new("UICorner").Parent = row
		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 6, 0.5, 0)
		badge.Size = UDim2.fromScale(0.8, 0.8)
		badge.SizeConstraint = Enum.SizeConstraint.RelativeYY
		badge.BackgroundColor3 = RANK_COLORS[i] or Color3.fromRGB(70, 74, 96)
		badge.Parent = row
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = badge
		text({ Size = UDim2.fromScale(1, 1), Text = tostring(i), TextColor3 = i <= 3 and Color3.fromRGB(30, 24, 10) or Color3.new(1, 1, 1), Parent = badge })
		local face = Instance.new("ImageLabel")
		face.AnchorPoint = Vector2.new(0, 0.5)
		face.Position = UDim2.new(0.1, 0, 0.5, 0)
		face.Size = UDim2.fromScale(0.86, 0.86)
		face.SizeConstraint = Enum.SizeConstraint.RelativeYY
		face.BackgroundColor3 = Color3.fromRGB(16, 18, 34)
		face.Image = entry.UserId and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", entry.UserId) or ""
		face.Parent = row
		local faceRound = Instance.new("UICorner")
		faceRound.CornerRadius = UDim.new(1, 0)
		faceRound.Parent = face
		text({
			Position = UDim2.fromScale(0.2, 0.1), Size = UDim2.fromScale(0.5, 0.8), Text = entry.Name,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
		})
		text({
			Position = UDim2.fromScale(0.7, 0.12), Size = UDim2.fromScale(0.28, 0.76), Text = comma(entry.Value) .. " " .. suffix,
			TextColor3 = i <= 3 and RANK_COLORS[i] or Color3.fromRGB(255, 215, 80), TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
		})
	end
	if #entries == 0 then
		render(board, "No riders yet. Be the first!", suffix)
	end
end

local function fetch(store)
	local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
	if not ok then
		return nil
	end
	local entries = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		table.insert(entries, { Name = nameFor(userId), UserId = userId, Value = item.value })
	end
	return entries
end

function Leaderboards.Init()
	local folder = workspace.Lobby:FindFirstChild("Leaderboards")
	if not folder then
		return
	end
	local boards = {
		{ Part = folder.WinsBoard, Store = Data.WinsBoard, Suffix = "wins" },
		{ Part = folder.EarnedBoard, Store = Data.EarnedBoard, Suffix = "tokens" },
	}
	task.spawn(function()
		while true do
			for _, b in boards do
				if not b.Store then
					render(b.Part, "Publish the game to see the leaderboard!", b.Suffix)
				else
					local entries = fetch(b.Store)
					render(b.Part, entries or "Leaderboard is loading...", b.Suffix)
				end
			end
			task.wait(REFRESH)
		end
	end)
end

return Leaderboards
