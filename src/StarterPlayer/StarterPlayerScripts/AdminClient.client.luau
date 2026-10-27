-- Admin panel: typing /admin in chat opens it (only for admins; the server checks every button again).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = Remotes:WaitForChild("AdminAction")
local openRemote = Remotes:WaitForChild("AdminOpen")
local player = Players.LocalPlayer
local C = UI.Colors
local new, text = UI.new, UI.text

local gui = new("ScreenGui", { Name = "AdminUI", ResetOnSpawn = false, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local win = UI.window({ Name = "Admin", Title = "ADMIN PANEL", Icon = "🛠️", Width = 600, Height = 486, Parent = gui })
local list = new("Frame", { Position = UDim2.fromOffset(20, 18), Size = UDim2.new(1, -40, 1, -70), BackgroundTransparency = 1, Parent = win.Body }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local status = text({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -40, 0, 28),
	Text = "Ride buttons only work while a ride is going.", TextSize = 18, TextColor3 = C.Muted, Parent = win.Body,
})

local busy = false
local function run(action, value)
	if busy then
		return
	end
	busy = true
	local ok, message = actionRemote:InvokeServer(action, value)
	busy = false
	status.Text = message or (ok and "Done!" or "That didn't work")
	status.TextColor3 = ok and C.Lime or C.Red
	UI.pop(status)
end

-- a titled row of buttons: { label, colour, action, value }
local order = 0
local function row(title, buttons)
	order += 1
	local frame = new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
	text({ Size = UDim2.new(1, 0, 0, 22), Text = title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local holder = new("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = frame }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local n = #buttons
	for i, b in buttons do
		local button = UI.button({
			Size = UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), Text = b[1], TextSize = n > 5 and 15 or 19, LayoutOrder = i, Parent = holder,
		}, b[2])
		button.Activated:Connect(function()
			run(b[3], b[4])
		end)
	end
end

row("💰 TOKENS", {
	{ "+100", C.Yellow, "Tokens", 100 },
	{ "+1,000", C.Yellow, "Tokens", 1000 },
	{ "+10,000", C.Yellow, "Tokens", 10000 },
	{ "-1,000", C.Red, "Tokens", -1000 },
})
row("🎒 GIVE ME", {
	{ "Wrench", C.Blue, "Give", "Wrench" },
	{ "Tape", C.Blue, "Give", "DuctTape" },
	{ "Fire Ext.", C.Blue, "Give", "Extinguisher" },
	{ "Water", C.Cyan, "Give", "Water" },
	{ "Soda", C.Cyan, "Give", "Soda" },
	{ "Pretzel", C.Cyan, "Give", "Pretzel" },
	{ "Sandwich", C.Cyan, "Give", "Sandwich" },
})
row("⚠ BREAK SOMETHING", {
	{ "Window", C.Orange, "Break", "Window" },
	{ "Leak", C.Orange, "Break", "Leak" },
	{ "Door", C.Orange, "Break", "Door" },
	{ "Power", C.Orange, "Break", "Power" },
	{ "Fire", C.Red, "Break", "Fire" },
	{ "Random", C.Purple, "Break", "Random" },
})
row("🚇 RIDE", {
	{ "Fix all", C.Green, "FixAll" },
	{ "Calm all", C.Cyan, "Calm" },
	{ "Scare all", C.Purple, "Scare" },
	{ "Win now", C.Lime, "End", "Win" },
	{ "Lose now", C.Red, "End", "Lose" },
})
row("⏩ JUMP AHEAD", {
	{ "Mile 1", C.Blue, "Jump", 1 },
	{ "Mile 2", C.Blue, "Jump", 2 },
	{ "Mile 3", C.Blue, "Jump", 3 },
	{ "Almost there", C.Blue, "Jump", 3.9 },
})
row("📍 GO TO", {
	{ "Lobby", C.Grey, "Teleport", "Lobby" },
	{ "Train", C.Grey, "Teleport", "Train" },
	{ "Driver's cab", C.Grey, "Teleport", "Cab" },
})

openRemote.OnClientEvent:Connect(function()
	if win.Frame.Visible then
		win.Close()
	else
		status.Text = "Ride buttons only work while a ride is going."
		status.TextColor3 = C.Muted
		win.Open()
	end
end)
