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

-- Fills a board's Rows frame. entries = { {Name, Value}, ... } or a message string.
local function render(board, entries, suffix)
	local rows = board.Display.Rows
	for _, child in rows:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if type(entries) == "string" then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.3)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.fromRGB(200, 200, 220)
		label.Text = entries
		label.Parent = rows
		return
	end
	local medals = { "🥇", "🥈", "🥉" }
	for i, entry in entries do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.095)
		label.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(34, 38, 64) or Color3.fromRGB(26, 30, 52)
		label.BorderSizePixel = 0
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = i <= 3 and Color3.fromRGB(255, 215, 80) or Color3.new(1, 1, 1)
		label.Text = string.format("  %s %s  —  %d %s", medals[i] or (i .. "."), entry.Name, entry.Value, suffix)
		label.LayoutOrder = i
		label.Parent = rows
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
		table.insert(entries, { Name = nameFor(tonumber(item.key)), Value = item.value })
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
