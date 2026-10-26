-- Custom hotbar (replaces Roblox's backpack): 3 slots, 5 with Big Pockets.
-- Number keys or tapping a slot hold/put away the item. Q (or the DROP button) throws it away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local C = UI.Colors

-- turn off Roblox's own backpack bar (retry: it can fail while the game is still starting)
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(0.5)
	end
end)

local SLOT = 66
local GAP = 8
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

local gui = UI.new("ScreenGui", { Name = "Hotbar", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local bar = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(SLOT * 3 + GAP * 2, SLOT),
	BackgroundTransparency = 1, Parent = gui,
}, { UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }) })

local nameTag = UI.text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -SLOT - 18), Size = UDim2.fromOffset(300, 26), Text = "", TextSize = 22, TextTransparency = 1, Parent = gui })
nameTag:FindFirstChildOfClass("UIStroke").Transparency = 1
local dropButton = UI.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(74, 30), Text = "DROP (Q)", TextSize = 14, Visible = false, Parent = gui }, C.Red)

local slotViews = {}
local slots = {} -- slot index -> Tool
local capacity = Config.MaxCarry

local function makeSlot(i)
	local button = UI.new("TextButton", {
		Size = UDim2.fromOffset(SLOT, SLOT), Text = "", AutoButtonColor = false, BackgroundColor3 = C.Dark, BackgroundTransparency = 0.25, LayoutOrder = i, Parent = bar,
	})
	UI.corner(12).Parent = button
	local stroke = UI.stroke(C.Outline, 3)
	stroke.Parent = button
	local gloss = UI.gloss(button)
	local icon = UI.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.75, 0.75), Text = "", TextScaled = true, Outline = false, Parent = button })
	local number = UI.text({ Position = UDim2.fromOffset(5, 2), Size = UDim2.fromOffset(16, 18), Text = tostring(i), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = button })
	-- little green bar along the bottom, like the original's tool slots
	local bar2 = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -16, 0, 5), BackgroundColor3 = C.Green, Visible = false, Parent = button })
	UI.corner(3).Parent = bar2
	button.Activated:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local tool = slots[i]
		if not humanoid or not tool then
			return
		end
		if tool.Parent == character then
			humanoid:UnequipTools()
		else
			humanoid:EquipTool(tool)
		end
	end)
	slotViews[i] = { Button = button, Stroke = stroke, Icon = icon, Bar = bar2 }
end

local function setCapacity(n)
	capacity = n
	for i = 1, 5 do
		if i <= n and not slotViews[i] then
			makeSlot(i)
		end
		if slotViews[i] then
			slotViews[i].Button.Visible = i <= n
		end
	end
	bar.Size = UDim2.fromOffset(SLOT * n + GAP * (n - 1), SLOT)
	dropButton.Position = UDim2.new(0.5, bar.Size.X.Offset / 2 + 10, 1, -30)
end

local function allTools()
	local list = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					table.insert(list, child)
				end
			end
		end
	end
	return list
end

local lastEquipped
local function refresh()
	local tools = allTools()
	-- forget tools we no longer have
	for i = 1, 5 do
		if slots[i] and not table.find(tools, slots[i]) then
			slots[i] = nil
		end
	end
	-- new tools go in the first empty slot
	for _, tool in tools do
		if not table.find(slots, tool) then
			for i = 1, capacity do
				if not slots[i] then
					slots[i] = tool
					break
				end
			end
		end
	end
	local character = player.Character
	local equipped
	for i = 1, capacity do
		local view, tool = slotViews[i], slots[i]
		local held = tool ~= nil and tool.Parent == character
		if held then
			equipped = tool
		end
		view.Icon.Text = tool and (tool:GetAttribute("Icon") or "❓") or ""
		view.Bar.Visible = tool ~= nil
		view.Button.BackgroundColor3 = held and C.Cyan or (tool and C.Blue or C.Dark)
		view.Button.BackgroundTransparency = tool and 0 or 0.25
		view.Stroke.Color = held and C.White or C.Outline
		view.Stroke.Thickness = held and 4 or 3
		view.Button.Size = held and UDim2.fromOffset(SLOT + 6, SLOT + 6) or UDim2.fromOffset(SLOT, SLOT)
	end
	dropButton.Visible = equipped ~= nil
	if equipped and equipped ~= lastEquipped then
		nameTag.Text = equipped:GetAttribute("DisplayName") or equipped.Name
		nameTag.TextTransparency = 0
		local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.2)
		TweenService:Create(nameTag, fade, { TextTransparency = 1 }):Play()
		local outline = nameTag:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Transparency = 0
			TweenService:Create(outline, fade, { Transparency = 1 }):Play()
		end
	end
	lastEquipped = equipped
end

local connections = {}
local function watch(container)
	if container then
		table.insert(connections, container.ChildAdded:Connect(refresh))
		table.insert(connections, container.ChildRemoved:Connect(refresh))
	end
end
local function rebind()
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	watch(player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack"))
	watch(player.Character)
	refresh()
end
player.CharacterAdded:Connect(function()
	task.wait()
	rebind()
end)
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		rebind()
	end
end)

local function drop()
	if lastEquipped then
		Remotes.DropItem:FireServer()
	end
end
dropButton.Activated:Connect(drop)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		drop()
		return
	end
	local index = table.find(KEYS, input.KeyCode)
	if index and index <= capacity and slotViews[index] then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local tool = slots[index]
		if humanoid and tool then
			if tool.Parent == character then
				humanoid:UnequipTools()
			else
				humanoid:EquipTool(tool)
			end
		end
	end
end)

setCapacity(Config.MaxCarry)
rebind()

RunService.RenderStepped:Connect(function()
	local wanted = Config.MaxCarry + (player:GetAttribute("Owned_BigPockets") and 2 or 0)
	if wanted ~= capacity then
		setCapacity(wanted)
		refresh()
	end
	gui.Enabled = player:GetAttribute("InRide") == true
end)
